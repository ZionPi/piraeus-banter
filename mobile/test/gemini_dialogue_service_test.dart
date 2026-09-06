import 'package:flutter_test/flutter_test.dart';
import 'package:piraeus_banter_mobile/models/project.dart';
import 'package:piraeus_banter_mobile/services/gemini_dialogue_service.dart';

void main() {
  final service = GeminiDialogueService();
  final project = BanterProject.initial();

  test('解析 Gemini 生成的标题和对话列表', () {
    final result = service.parseDialogueJson('''
      {
        "title": "《能量守恒入门》",
        "dialogue_list": [
          {
            "id": 1,
            "speaker": "Speaker 1",
            "content": "能量不会凭空产生。",
            "non_essential_speech": false,
            "topic_id": 1,
            "content_type": "other"
          }
        ]
      }
      ''', project);

    expect(result.title, '能量守恒入门');
    expect(result.bubbles, hasLength(1));
  });

  test('缺少生成标题时拒绝创建结果', () {
    expect(
      () => service.parseDialogueJson('''
        {
          "dialogue_list": [
            {
              "id": 1,
              "speaker": "Speaker 1",
              "content": "测试内容",
              "non_essential_speech": false,
              "topic_id": 1,
              "content_type": "other"
            }
          ]
        }
        ''', project),
      throwsFormatException,
    );
  });

  test('Gemini 临时错误转换为简短中文提示', () {
    final error = GeminiApiException.fromResponse(
      503,
      '{"error":{"status":"UNAVAILABLE","message":"high demand"}}',
    );

    expect(error.toString(), 'Gemini 模型当前请求量过高，请稍后重试。');
  });

  test('停用的 Key 不回显原始响应', () {
    final error = GeminiApiException.fromResponse(
      403,
      '''{"error":{"details":[{"reason":"CONSUMER_SUSPENDED"}],"message":"secret-key"}}''',
    );

    expect(error.toString(), 'Gemini API Key 已停用，请更换后重试。');
    expect(error.toString(), isNot(contains('secret-key')));
  });
}
