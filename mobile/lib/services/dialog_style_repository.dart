import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';

import '../models/dialog_style.dart';

class DialogStyleRepository {
  static const _userStylesFileName = 'dialog_styles.json';

  Future<File> get _userStylesFile async {
    final dir = await getApplicationDocumentsDirectory();
    final appDir = Directory('${dir.path}/piraeus_banter');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return File('${appDir.path}/$_userStylesFileName');
  }

  Future<List<DialogStyle>> load() async {
    final rawManifest = await rootBundle.loadString(
      'assets/dialog_configs/manifest.json',
    );
    final manifest = jsonDecode(rawManifest) as List<dynamic>;
    final styles = <DialogStyle>[];

    for (final item in manifest.whereType<Map<String, dynamic>>()) {
      final rawYaml = await rootBundle.loadString(item['path'] as String);
      final yaml = loadYaml(rawYaml) as YamlMap;
      styles.add(
        DialogStyle(
          id: item['id'] as String,
          name: item['name'] as String,
          description: item['description'] as String,
          systemInstruction: yaml['system_instruction']?.toString() ?? '',
          userPrompt: yaml['user_prompt_for_file_processing']?.toString() ?? '',
          builtIn: true,
        ),
      );
    }

    styles.addAll(await loadUserStyles());
    return styles;
  }

  Future<List<DialogStyle>> loadUserStyles() async {
    final file = await _userStylesFile;
    if (!await file.exists()) return const [];
    final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(DialogStyle.fromJson)
        .map((style) => style.copyWith(builtIn: false))
        .toList();
  }

  Future<void> saveUserStyle(DialogStyle style) async {
    final styles = await loadUserStyles();
    final custom = style.copyWith(
      id: style.id.startsWith('custom-')
          ? style.id
          : 'custom-${DateTime.now().millisecondsSinceEpoch}',
      builtIn: false,
    );
    final index = styles.indexWhere((item) => item.id == custom.id);
    if (index >= 0) {
      styles[index] = custom;
    } else {
      styles.add(custom);
    }
    await _writeUserStyles(styles);
  }

  Future<void> deleteUserStyle(String id) async {
    final styles = await loadUserStyles();
    styles.removeWhere((style) => style.id == id);
    await _writeUserStyles(styles);
  }

  Future<void> _writeUserStyles(List<DialogStyle> styles) async {
    final file = await _userStylesFile;
    await file.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(styles.map((style) => style.toJson()).toList()),
    );
  }
}
