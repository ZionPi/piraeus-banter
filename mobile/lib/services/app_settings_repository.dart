import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_settings.dart';
import '../models/project.dart';

class AppSettingsRepository {
  static const _settingsFileName = 'app_settings.json';
  static const _geminiKeyName = 'gemini_api_key';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<File> get _settingsFile async {
    final dir = await getApplicationDocumentsDirectory();
    final appDir = Directory('${dir.path}/piraeus_banter');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return File('${appDir.path}/$_settingsFileName');
  }

  Future<AppSettings> load({BanterProject? legacyProject}) async {
    final file = await _settingsFile;
    if (!await file.exists()) {
      final settings = legacyProject == null
          ? AppSettings()
          : AppSettings.fromProject(legacyProject);
      await save(settings);
      return settings;
    }
    final raw = await file.readAsString();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final settings = AppSettings.fromJson(json);
    final legacyGeminiKey = settings.geminiApiKey.trim();
    try {
      final secureKey = await _secureStorage.read(key: _geminiKeyName);
      if (secureKey != null && secureKey.trim().isNotEmpty) {
        settings.geminiApiKey = secureKey.trim();
      } else if (legacyGeminiKey.isNotEmpty) {
        await _secureStorage.write(key: _geminiKeyName, value: legacyGeminiKey);
      }
    } on MissingPluginException {
      // Unit tests and non-Android hosts do not register secure storage.
    }
    var avatarSeedsChanged = false;
    if (settings.hostAvatarSeed == settings.guestAvatarSeed) {
      do {
        settings.guestAvatarSeed = AppSettings.newAvatarSeed();
      } while (settings.guestAvatarSeed == settings.hostAvatarSeed);
      avatarSeedsChanged = true;
    }
    if (!json.containsKey('hostAvatarSeed') ||
        !json.containsKey('guestAvatarSeed') ||
        json.containsKey('geminiApiKey') ||
        avatarSeedsChanged) {
      await save(settings);
    }
    return settings;
  }

  Future<void> save(AppSettings settings) async {
    try {
      if (settings.geminiApiKey.trim().isEmpty) {
        await _secureStorage.delete(key: _geminiKeyName);
      } else {
        await _secureStorage.write(
          key: _geminiKeyName,
          value: settings.geminiApiKey.trim(),
        );
      }
    } on MissingPluginException {
      // Unit tests and non-Android hosts do not register secure storage.
    }
    final file = await _settingsFile;
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }
}
