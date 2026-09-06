import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';
import '../models/dialog_style.dart';
import '../models/project.dart';
import 'script_importer.dart';

class DialogueGenerationResult {
  const DialogueGenerationResult({required this.title, required this.bubbles});

  final String title;
  final List<DialogueBubble> bubbles;
}

class GeminiApiException implements Exception {
  const GeminiApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  factory GeminiApiException.fromResponse(int statusCode, String body) {
    var reason = '';
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      final details = error?['details'] as List<dynamic>? ?? const [];
      for (final detail in details.whereType<Map<String, dynamic>>()) {
        reason = detail['reason']?.toString() ?? '';
        if (reason.isNotEmpty) break;
      }
    } catch (_) {}

    final message = switch ((statusCode, reason)) {
      (403, 'CONSUMER_SUSPENDED') => 'Gemini API Key 已停用，请更换后重试。',
      (401, _) => 'Gemini API Key 无效，请检查后重试。',
      (403, _) => 'Gemini API Key 没有调用权限，请检查项目设置。',
      (429, _) => 'Gemini 请求过于频繁或额度已用尽，请稍后重试。',
      (503, _) => 'Gemini 模型当前请求量过高，请稍后重试。',
      (500 || 502 || 504, _) => 'Gemini 服务暂时不可用，请稍后重试。',
      (400, _) => 'Gemini 拒绝了请求，请检查模型设置。',
      _ => 'Gemini 请求失败（$statusCode），请稍后重试。',
    };
    return GeminiApiException(statusCode, message);
  }

  @override
  String toString() => message;
}

class GeminiDialogueService {
  static const _maxChunkCharacters = 280000;
  static const defaultModel = 'gemini-3.6-flash';
  static const supportedModels = [
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-3.7-flash',
    'gemini-3.8-flash',
  ];

  Future<DialogueGenerationResult> generateDialogue({
    required String input,
    required DialogStyle style,
    required AppSettings settings,
    required BanterProject project,
    void Function(double progress)? onProgress,
  }) async {
    _requireApiKey(settings.geminiApiKey);
    final model = supportedModels.contains(settings.geminiModel)
        ? settings.geminiModel
        : defaultModel;
    final chunks = _splitInput(input.trim());
    final bubbles = <DialogueBubble>[];
    var title = '';
    for (var index = 0; index < chunks.length; index++) {
      final result = await _generateChunk(
        apiKey: settings.geminiApiKey,
        input: chunks[index],
        chunkIndex: index,
        chunkCount: chunks.length,
        style: style,
        model: model,
        project: project,
      );
      if (title.isEmpty) title = result.title;
      for (final bubble in result.bubbles) {
        if (bubbles.isNotEmpty &&
            bubbles.last.content.trim() == bubble.content.trim()) {
          continue;
        }
        bubbles.add(
          DialogueBubble(
            id: '${bubbles.length + 1}',
            role: bubble.role,
            name: bubble.name,
            content: bubble.content,
            isNonEssential: bubble.isNonEssential,
            topicId: bubble.topicId,
          ),
        );
      }
      onProgress?.call((index + 1) / chunks.length);
    }
    if (bubbles.isEmpty) throw Exception('Gemini 没有生成有效对话。');
    return DialogueGenerationResult(title: title, bubbles: bubbles);
  }

  Future<DialogueGenerationResult> generateDialogueFromImage({
    required String path,
    required String fileName,
    required String additionalText,
    required DialogStyle style,
    required AppSettings settings,
    required BanterProject project,
  }) async {
    final apiKey = _requireApiKey(settings.geminiApiKey);
    final file = File(path);
    if (!await file.exists()) throw Exception('所选图片已不存在，请重新选择。');
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('不能使用空图片。');
    if (bytes.length > 15 * 1024 * 1024) throw Exception('图片超过 15 MiB 限制。');
    final model = supportedModels.contains(settings.geminiModel)
        ? settings.geminiModel
        : defaultModel;
    final extra = additionalText.trim().isEmpty
        ? '请识别图片中的主要信息。'
        : '用户补充要求：${additionalText.trim()}';
    final prompt = _buildPrompt(
      input: '图片文件：$fileName\n$extra',
      isShortTopic: false,
      chunkNotice: '',
      style: style,
    );
    return _requestDialogue(
      apiKey: apiKey,
      model: model,
      style: style,
      project: project,
      requestParts: [
        {'text': prompt},
        {
          'inline_data': {
            'mime_type': _imageMimeType(fileName),
            'data': base64Encode(bytes),
          },
        },
      ],
    );
  }

  Future<DialogueGenerationResult> _generateChunk({
    required String apiKey,
    required String input,
    required int chunkIndex,
    required int chunkCount,
    required DialogStyle style,
    required String model,
    required BanterProject project,
  }) async {
    final isShortTopic =
        chunkCount == 1 && input.length <= 80 && !input.contains('\n');
    final chunkNotice = chunkCount == 1
        ? ''
        : '这是长文本的第 ${chunkIndex + 1}/$chunkCount 部分。只处理这一部分，保持上下文自然，不要重复固定开场和结束语。';
    final prompt = _buildPrompt(
      input: input,
      isShortTopic: isShortTopic,
      chunkNotice: chunkNotice,
      style: style,
    );
    return _requestDialogue(
      apiKey: _requireApiKey(apiKey),
      model: model,
      style: style,
      project: project,
      requestParts: [
        {'text': prompt},
      ],
    );
  }

  String _buildPrompt({
    required String input,
    required bool isShortTopic,
    required String chunkNotice,
    required DialogStyle style,
  }) =>
      '''
${style.userPrompt}

请把下面输入改写为双人对话，并严格输出 JSON。顶层必须是：
{"title":"简短标题","dialogue_list":[{"id":1,"speaker":"Speaker 1","content":"...","non_essential_speech":false,"topic_id":1,"content_type":"other"}]}

要求：
- 只输出 JSON，不要 Markdown，不要代码块。
- title 使用 4 至 20 个中文字符概括输入，不带书名号、引号或风格名称。
- speaker 只能是 "Speaker 1" 或 "Speaker 2"。
- id 从 1 连续递增。
- content 使用中文，适合直接交给 TTS 朗读。
- ${isShortTopic ? '输入是简短话题，围绕它主动展开。' : '输入是用户提供的原文，应忠于原文事实和论点，不要把它误当成一个关键词。'}
- 不要只解释词义，要生成可以直接播放的双人播客对话列表。
$chunkNotice

输入：
$input
''';

  Future<DialogueGenerationResult> _requestDialogue({
    required String apiKey,
    required String model,
    required DialogStyle style,
    required BanterProject project,
    required List<Map<String, dynamic>> requestParts,
  }) async {
    final payload = {
      'systemInstruction': {
        'parts': [
          {'text': style.systemInstruction},
        ],
      },
      'contents': [
        {'role': 'user', 'parts': requestParts},
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'dialogue_list': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'id': {'type': 'integer'},
                  'speaker': {
                    'type': 'string',
                    'enum': ['Speaker 1', 'Speaker 2'],
                  },
                  'content': {'type': 'string'},
                  'non_essential_speech': {'type': 'boolean'},
                  'topic_id': {'type': 'integer'},
                  'content_type': {
                    'type': 'string',
                    'enum': ['question', 'answer', 'other'],
                  },
                },
                'required': [
                  'id',
                  'speaker',
                  'content',
                  'non_essential_speech',
                  'topic_id',
                  'content_type',
                ],
              },
            },
          },
          'required': ['title', 'dialogue_list'],
        },
        'temperature': 0.8,
      },
    };
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:generateContent',
    );
    late String body;
    for (var attempt = 0; attempt < 3; attempt++) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20);
      try {
        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.headers.set('X-Goog-Api-Key', apiKey);
        request.write(jsonEncode(payload));
        final response = await request.close().timeout(
          const Duration(seconds: 120),
        );
        body = await response
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 30));
        if (response.statusCode >= 200 && response.statusCode < 300) break;
        final error = GeminiApiException.fromResponse(
          response.statusCode,
          body,
        );
        if (!_retryableStatus(response.statusCode) || attempt == 2) throw error;
      } on GeminiApiException {
        rethrow;
      } on SocketException catch (error) {
        if (attempt == 2) throw Exception('无法连接 Gemini：${error.message}');
      } on HttpException catch (error) {
        if (attempt == 2) throw Exception('Gemini 连接中断：${error.message}');
      } on TimeoutException {
        if (attempt == 2) throw Exception('Gemini 请求超时，请稍后重试。');
      } finally {
        client.close(force: true);
      }
      await Future<void>.delayed(Duration(seconds: 1 << attempt));
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) {
      throw Exception('Gemini 没有返回候选结果。');
    }
    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    final text = parts
        .whereType<Map<String, dynamic>>()
        .map((part) => part['text']?.toString() ?? '')
        .join()
        .trim();
    if (text.isEmpty) {
      throw Exception('Gemini 返回了空内容。');
    }

    return parseDialogueJson(text, project);
  }

  String _requireApiKey(String value) {
    final apiKey = value.trim();
    if (apiKey.isEmpty) throw Exception('请先在设置中填写 Gemini API 密钥。');
    return apiKey;
  }

  bool _retryableStatus(int status) =>
      status == 408 || status == 429 || status >= 500;

  String _imageMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  DialogueGenerationResult parseDialogueJson(
    String text,
    BanterProject project,
  ) {
    final rawJson = _extractJson(text);
    final result = jsonDecode(rawJson) as Map<String, dynamic>;
    final title = _cleanTitle(result['title']?.toString() ?? '');
    if (title.isEmpty) throw const FormatException('Gemini 没有生成标题。');
    final bubbles = ScriptImporter.parseDesktopJson(rawJson, project);
    if (bubbles.isEmpty) throw const FormatException('Gemini 没有生成有效对话。');
    return DialogueGenerationResult(title: title, bubbles: bubbles);
  }

  List<String> _splitInput(String input) {
    if (input.length <= _maxChunkCharacters) return [input];
    final chunks = <String>[];
    var current = StringBuffer();
    for (final paragraph in input.split(RegExp(r'\n{2,}'))) {
      if (paragraph.length > _maxChunkCharacters) {
        if (current.isNotEmpty) {
          chunks.add(current.toString().trim());
          current = StringBuffer();
        }
        for (var start = 0; start < paragraph.length;) {
          final end = (start + _maxChunkCharacters).clamp(0, paragraph.length);
          chunks.add(paragraph.substring(start, end).trim());
          start = end;
        }
        continue;
      }
      if (current.length + paragraph.length + 2 > _maxChunkCharacters) {
        chunks.add(current.toString().trim());
        current = StringBuffer();
      }
      if (current.isNotEmpty) current.write('\n\n');
      current.write(paragraph);
    }
    if (current.isNotEmpty) chunks.add(current.toString().trim());
    return chunks.where((chunk) => chunk.isNotEmpty).toList();
  }

  String _cleanTitle(String title) {
    final clean = title
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAll(RegExp("[《》“”\"']"), '')
        .trim();
    return clean.length <= 24 ? clean : clean.substring(0, 24);
  }

  String _extractJson(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) return trimmed;
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return trimmed.substring(start, end + 1);
    }
    throw const FormatException('Gemini 输出不是 JSON。');
  }
}
