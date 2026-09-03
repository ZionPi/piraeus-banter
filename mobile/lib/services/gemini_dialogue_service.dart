import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';
import '../models/dialog_style.dart';
import '../models/project.dart';
import 'script_importer.dart';

class GeminiDialogueService {
  static const model = 'gemini-3.8-flash';

  Future<List<DialogueBubble>> generateDialogue({
    required String input,
    required DialogStyle style,
    required AppSettings settings,
    required BanterProject project,
  }) async {
    final apiKey = settings.geminiApiKey.trim();
    if (apiKey.isEmpty) {
      throw Exception('缺少 Gemini API Key，请先在设置里填写。');
    }

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:generateContent',
      {'key': apiKey},
    );
    final prompt =
        '''
${style.userPrompt}

请把下面输入改写为双人对话，并严格输出 JSON。顶层必须是：
{"dialogue_list":[{"id":1,"speaker":"Speaker 1","content":"...","non_essential_speech":false,"topic_id":1,"content_type":"other"}]}

要求：
- 只输出 JSON，不要 Markdown，不要代码块。
- speaker 只能是 "Speaker 1" 或 "Speaker 2"。
- id 从 1 连续递增。
- content 使用中文，适合直接交给 TTS 朗读。
- 如果输入很短，把它当作“具体议题/关键词”，围绕它主动展开。
- 不要只解释词义，要生成可以直接播放的双人播客对话列表。

输入：
$input
''';

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': style.systemInstruction},
            ],
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
            'responseSchema': {
              'type': 'object',
              'properties': {
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
              'required': ['dialogue_list'],
            },
            'temperature': 0.8,
          },
        }),
      );

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Gemini API 错误 ${response.statusCode}: $body');
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

      return ScriptImporter.parseDesktopJson(_extractJson(text), project);
    } finally {
      client.close(force: true);
    }
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
