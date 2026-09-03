import 'dart:convert';

import '../models/project.dart';

class ScriptImporter {
  static List<DialogueBubble> parseDesktopJson(
    String raw,
    BanterProject project,
  ) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON 顶层必须是对象。');
    }

    if (decoded['bubbles'] is List) {
      return (decoded['bubbles'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(DialogueBubble.fromJson)
          .toList();
    }

    final list = decoded['dialogue_list'];
    if (list is! List) {
      throw const FormatException('JSON 中没有 dialogue_list 或 bubbles 数组。');
    }
    return list.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('dialogue_list 中的每一项都必须是对象。');
      }
      final data = item;
      final content = data['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw const FormatException('dialogue_list 中每一项都必须包含 content。');
      }
      final speaker = (data['speaker'] ?? '').toString().toLowerCase();
      final isHost =
          speaker.contains('speaker 2') ||
          speaker.contains('host') ||
          speaker.contains('主持');
      return DialogueBubble(
        id: '${data['id'] ?? DateTime.now().microsecondsSinceEpoch}',
        role: isHost ? BubbleRole.host : BubbleRole.guest,
        name: isHost ? project.hostName : project.guestName,
        content: content,
        isNonEssential: data['non_essential_speech'] as bool? ?? false,
        topicId: (data['topic_id'] as num?)?.toInt(),
      );
    }).toList();
  }
}
