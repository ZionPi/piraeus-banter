import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/voice_preset.dart';

class VoicePresetRepository {
  Future<List<VoicePreset>> load() async {
    final raw = await rootBundle.loadString('assets/data/voice_presets.json');
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(VoicePreset.fromJson)
        .where((voice) => voice.id.isNotEmpty)
        .toList();
  }
}
