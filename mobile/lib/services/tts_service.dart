import 'dart:async';
import 'dart:convert';
import 'dart:io';

class TtsService {
  static const apiUrl = 'wss://sami.bytedance.com/internal/api/v2/ws';

  Future<void> saveAudioToFile({
    required String text,
    required String speaker,
    required String outputPath,
    required String appKey,
    String accessToken = '',
  }) async {
    if (appKey.trim().isEmpty) {
      throw Exception('缺少 ByteDance AppKey，请先在设置里填写。');
    }

    final output = File(outputPath);
    await output.parent.create(recursive: true);

    final payload = {
      'text': text,
      'speaker': speaker,
      'audio_config': {
        'format': 'mp3',
        'bit_rate': 128000,
        'speech_rate': 0,
        'enable_timestamp': false,
        'sample_rate': 24000,
      },
    };

    final startReq = {
      'appkey': appKey,
      'namespace': 'TTS',
      'event': 'StartTask',
      'payload': jsonEncode(payload),
    };
    final finishReq = {
      'appkey': appKey,
      'namespace': 'TTS',
      'event': 'FinishTask',
      'payload': '',
    };

    IOSink? sink;
    WebSocket? socket;
    try {
      sink = output.openWrite();
      socket = await WebSocket.connect(
        apiUrl,
      ).timeout(const Duration(seconds: 15));
      socket.pingInterval = null;
      socket.add(jsonEncode(startReq));
      socket.add(jsonEncode(finishReq));

      await for (final data in socket.timeout(const Duration(seconds: 60))) {
        if (data is String) {
          final body = jsonDecode(data) as Map<String, dynamic>;
          final audioData = body['data'] as String?;
          if (audioData != null && audioData.isNotEmpty) {
            sink.add(base64Decode(audioData));
          }
          final statusCode = body['status_code'];
          if (statusCode != null && statusCode != 20000000) {
            throw Exception(body['status_text'] ?? 'TTS API 错误：$statusCode');
          }
          if (body['event'] == 'TaskFinished') {
            break;
          }
        } else if (data is List<int>) {
          sink.add(data);
        }
      }
    } catch (error) {
      try {
        await output.delete();
      } catch (_) {}
      rethrow;
    } finally {
      await sink?.flush();
      await sink?.close();
      await socket?.close();
    }

    if (!await output.exists() || await output.length() == 0) {
      throw Exception('TTS 没有返回有效音频。');
    }
  }
}
