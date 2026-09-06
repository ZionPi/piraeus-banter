import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'api_config.dart';

class DocumentTextService {
  static const supportedExtensions = [
    'epub',
    'html',
    'htm',
    'pdf',
    'docx',
    'odt',
    'rtf',
    'fb2',
    'md',
    'markdown',
    'txt',
    'png',
    'jpg',
    'jpeg',
    'webp',
  ];

  static const imageExtensions = {'png', 'jpg', 'jpeg', 'webp'};
  static const maxUploadBytes = 25 * 1024 * 1024;
  static const maxImageUploadBytes = 15 * 1024 * 1024;
  static const maxPromptBytes = 1400 * 1024;

  static bool isImage(String fileName) =>
      imageExtensions.contains(_extension(fileName));

  static int maxUploadBytesFor(String fileName) =>
      isImage(fileName) ? maxImageUploadBytes : maxUploadBytes;

  static String maxSizeLabel(String fileName) =>
      isImage(fileName) ? '15 MiB' : '25 MiB';

  Future<String> convertFile({
    required String path,
    required String fileName,
    void Function(double progress)? onUploadProgress,
    void Function()? onUploadFinished,
  }) async {
    final file = File(path);
    if (!await file.exists()) throw Exception('所选文件已不存在，请重新选择。');
    final bytes = await file.length();
    if (bytes == 0) throw Exception('不能上传空文件。');
    if (bytes > maxUploadBytesFor(fileName)) {
      throw Exception('文件超过 ${maxSizeLabel(fileName)} 上传限制。');
    }

    final extension = _extension(fileName);
    if (!supportedExtensions.contains(extension)) {
      throw Exception('不支持 .$extension 文件。');
    }
    if (imageExtensions.contains(extension)) {
      throw Exception('图片应直接交给 Gemini 识别。');
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    final boundary = 'piraeus-banter-${DateTime.now().microsecondsSinceEpoch}';
    var uploadFinished = false;
    try {
      final request = await client.postUrl(
        ApiConfig.uri('/api/convert-to-text'),
      );
      ApiConfig.authorize(request);
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        parameters: {'boundary': boundary},
      );
      final safeName = fileName.replaceAll(RegExp(r'[\r\n"]'), '_');
      request.add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="file"; filename="$safeName"\r\n'
          'Content-Type: ${_contentType(extension)}\r\n\r\n',
        ),
      );
      var sentBytes = 0;
      await request
          .addStream(
            file.openRead().map((chunk) {
              sentBytes += chunk.length;
              onUploadProgress?.call((sentBytes / bytes).clamp(0.0, 1.0));
              return chunk;
            }),
          )
          .timeout(const Duration(minutes: 2));
      request.add(utf8.encode('\r\n--$boundary--\r\n'));
      onUploadProgress?.call(1);
      onUploadFinished?.call();
      uploadFinished = true;

      final response = await request.close().timeout(
        const Duration(seconds: 135),
      );
      final body = await _readResponse(response, maxBytes: maxPromptBytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('文件提取失败 ${response.statusCode}：${_errorMessage(body)}');
      }
      if (body.trim().isEmpty) throw Exception('服务器返回的正文为空。');
      return body.trim();
    } on TimeoutException {
      throw Exception(uploadFinished ? '文件提取超时，请稍后重试。' : '文件上传超时，请检查网络后重试。');
    } finally {
      client.close(force: true);
    }
  }

  Future<String> convertUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw Exception('请输入完整的 http 或 https 网页链接。');
    }

    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        return await _convertUrlOnce(uri);
      } on HttpException {
        if (attempt == 2) {
          throw Exception('网页内容传输中断，请检查网络后重试。');
        }
      } on SocketException {
        if (attempt == 2) {
          throw Exception('无法连接网页提取服务，请检查网络后重试。');
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    throw Exception('网页提取失败，请稍后重试。');
  }

  Future<String> _convertUrlOnce(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(ApiConfig.uri('/api/url-to-text'));
      ApiConfig.authorize(request);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'url': uri.toString()}));
      final response = await request.close().timeout(
        const Duration(seconds: 75),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorBody = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 5));
        throw Exception(
          '网页提取失败 ${response.statusCode}：${_errorMessage(errorBody)}',
        );
      }
      return await _readTextResponse(
        response,
      ).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw Exception('网页提取超时，请稍后重试。');
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _readTextResponse(HttpClientResponse response) async {
    final text = await _readResponse(response, maxBytes: maxPromptBytes);
    if (text.trim().isEmpty) throw Exception('服务器返回的正文为空。');
    return text.trim();
  }

  Future<String> _readResponse(
    HttpClientResponse response, {
    required int maxBytes,
  }) async {
    final output = BytesBuilder(copy: false);
    var outputBytes = 0;
    await for (final chunk in response) {
      outputBytes += chunk.length;
      if (outputBytes > maxBytes) {
        throw Exception('服务器返回内容过长。');
      }
      output.add(chunk);
    }
    return utf8.decode(output.takeBytes(), allowMalformed: true);
  }

  static String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  static String _contentType(String extension) => switch (extension) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    'epub' => 'application/epub+zip',
    'txt' || 'md' || 'markdown' => 'text/plain; charset=utf-8',
    'html' || 'htm' => 'text/html; charset=utf-8',
    _ => 'application/octet-stream',
  };

  String _errorMessage(String body) {
    String message;
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      message = decoded['error']?.toString() ?? body;
    } catch (_) {
      message = body.trim().isEmpty ? '服务器没有返回错误详情' : body.trim();
    }
    return message.length > 300 ? '${message.substring(0, 300)}…' : message;
  }
}
