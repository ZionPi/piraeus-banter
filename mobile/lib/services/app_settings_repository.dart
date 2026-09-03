import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/project.dart';

class AppSettingsRepository {
  static const _settingsFileName = 'app_settings.json';

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
      return legacyProject == null
          ? AppSettings()
          : AppSettings.fromProject(legacyProject);
    }
    final raw = await file.readAsString();
    return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(AppSettings settings) async {
    final file = await _settingsFile;
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }
}
