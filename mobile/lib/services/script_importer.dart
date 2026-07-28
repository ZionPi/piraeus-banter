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
      final data = item as Map<String, dynamic>;
      final speaker = (data['speaker'] ?? '').toString().toLowerCase();
      final isHost = speaker.contains('speaker 2') || speaker.contains('host');
      return DialogueBubble(
        id: '${data['id'] ?? DateTime.now().microsecondsSinceEpoch}',
        role: isHost ? BubbleRole.host : BubbleRole.guest,
        name: isHost ? project.hostName : project.guestName,
        content: data['content'] as String? ?? '',
        isNonEssential: data['non_essential_speech'] as bool? ?? false,
        topicId: (data['topic_id'] as num?)?.toInt(),
      );
    }).toList();
  }
}
