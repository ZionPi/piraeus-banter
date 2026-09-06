import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

import '../models/project.dart';

class MergedAudioExport {
  MergedAudioExport({
    required this.path,
    required this.name,
    required this.createdAt,
    required this.bytes,
  });

  final String path;
  final String name;
  final DateTime createdAt;
  final int bytes;
}

class ProjectRepository {
  static const _selectedFileName = 'selected_project.txt';

  Future<Directory> get appDir async {
    final dir = await getApplicationDocumentsDirectory();
    final projectDir = Directory('${dir.path}/piraeus_banter');
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }
    return projectDir;
  }

  Future<Directory> get projectsDir async {
    final dir = Directory('${(await appDir).path}/projects');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> get _selectedFile async =>
      File('${(await appDir).path}/$_selectedFileName');

  String sanitizeFileName(String name) {
    final safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\u4e00-\u9fa5]'), '_');
    return safe.trim().isEmpty ? '新项目' : safe;
  }

  Future<String> uniqueProjectFileName(String projectName) async {
    final dir = await projectsDir;
    final base = sanitizeFileName(projectName);
    var candidate = '$base.json';
    var index = 2;
    while (await File('${dir.path}/$candidate').exists()) {
      candidate = '${base}_$index.json';
      index++;
    }
    return candidate;
  }

  Future<BanterProject?> loadCurrent({bool createIfMissing = true}) async {
    final selected = await _selectedFile;
    if (await selected.exists()) {
      final fileName = (await selected.readAsString()).trim();
      if (fileName.isNotEmpty) {
        final project = await loadByFileName(fileName);
        if (project != null) return project;
      }
    }

    final summaries = await listProjects();
    if (summaries.isNotEmpty) {
      return (await loadByFileName(summaries.first.fileName))!;
    }

    if (!createIfMissing) return null;

    final project = BanterProject.initial();
    await save(project, select: true);
    return project;
  }

  Future<BanterProject?> loadByFileName(
    String fileName, {
    bool select = true,
  }) async {
    final file = File('${(await projectsDir).path}/$fileName');
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    final project = BanterProject.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
      fileName: fileName,
    );
    if (select) await (await _selectedFile).writeAsString(fileName);
    return project;
  }

  Future<List<ProjectSummary>> listProjects() async {
    final dir = await projectsDir;
    final files = await dir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();
    final summaries = <ProjectSummary>[];
    for (final file in files) {
      try {
        final raw = await file.readAsString();
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final bubbles = json['bubbles'] as List<dynamic>? ?? const [];
        summaries.add(
          ProjectSummary(
            fileName: file.uri.pathSegments.last,
            name: json['name'] as String? ?? file.uri.pathSegments.last,
            updatedAt:
                DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
                await file.lastModified(),
            bubbleCount: bubbles.length,
          ),
        );
      } catch (_) {}
    }
    summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return summaries;
  }

  Future<void> save(BanterProject project, {bool select = false}) async {
    project.updatedAt = DateTime.now();
    project.fileName ??= await uniqueProjectFileName(project.name);
    final file = File('${(await projectsDir).path}/${project.fileName}');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(project.toJson()),
    );
    if (select) await (await _selectedFile).writeAsString(project.fileName!);
  }

  Future<void> deleteProject(String fileName) async {
    final file = File('${(await projectsDir).path}/$fileName');
    if (await file.exists()) await file.delete();
    final selected = await _selectedFile;
    if (await selected.exists() &&
        (await selected.readAsString()).trim() == fileName) {
      await selected.writeAsString('');
    }
  }

  Future<void> renameProjectFile(BanterProject project, String newName) async {
    final oldFileName = project.fileName;
    project.name = newName;
    final newFileName = await uniqueProjectFileName(newName);
    if (oldFileName != null) {
      final oldFile = File('${(await projectsDir).path}/$oldFileName');
      if (await oldFile.exists()) await oldFile.delete();
    }
    project.fileName = newFileName;
    await save(project, select: true);
  }

  Future<BanterProject> importProjectZip(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final projectEntry = archive.files
        .where((file) => file.name == 'project.json')
        .firstOrNull;
    if (projectEntry == null) {
      throw const FormatException('项目包中没有 project.json。');
    }
    final projectRaw = utf8.decode(projectEntry.content as List<int>);
    final project = BanterProject.fromJson(
      jsonDecode(projectRaw) as Map<String, dynamic>,
    );
    project.name = '${project.name}_imported';
    project.fileName = null;

    final audioDir = Directory('${(await appDir).path}/audio');
    if (!await audioDir.exists()) await audioDir.create(recursive: true);
    final audioEntries = <String, ArchiveFile>{};
    for (final file in archive.files) {
      if (file.isFile && file.name.startsWith('audio/')) {
        audioEntries[file.name.split('/').last] = file;
      }
    }
    for (final bubble in project.bubbles) {
      final oldPath = bubble.audioPath;
      if (oldPath == null || oldPath.isEmpty) continue;
      final basename = oldPath.split('/').last.split('\\').last;
      final entry = audioEntries[basename];
      if (entry == null) {
        bubble.audioPath = null;
        if (bubble.status == BubbleStatus.success) {
          bubble.status = BubbleStatus.idle;
        }
        continue;
      }
      final out = File('${audioDir.path}/$basename');
      await out.writeAsBytes(entry.content as List<int>);
      bubble.audioPath = out.path;
    }
    await save(project, select: true);
    return project;
  }

  Future<String> audioPathFor(String projectName, String bubbleId) async {
    final audioDir = Directory('${(await appDir).path}/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    final safeProject = sanitizeFileName(projectName);
    final safeBubble = bubbleId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return '${audioDir.path}/${safeProject}_$safeBubble.mp3';
  }

  Future<String> exportProjectZip(BanterProject project) async {
    await save(project, select: true);
    final exportDir = Directory('${(await appDir).path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final zipPath =
        '${exportDir.path}/${sanitizeFileName(project.name)}_${DateTime.now().millisecondsSinceEpoch}.zip';
    final encoder = ZipFileEncoder();
    encoder.create(zipPath, level: Deflate.BEST_SPEED);
    final projectBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(project.toJson()),
    );
    encoder.addArchiveFile(
      ArchiveFile('project.json', projectBytes.length, projectBytes),
    );
    for (final bubble in project.bubbles) {
      final path = bubble.audioPath;
      if (path == null) continue;
      final file = File(path);
      if (await file.exists()) {
        encoder.addFile(file, 'audio/${file.uri.pathSegments.last}');
      }
    }
    encoder.closeSync();
    return zipPath;
  }

  Future<List<String>> mergedAudioInputPaths(
    BanterProject project, {
    bool skipBlank = true,
  }) async {
    final paths = <String>[];
    for (final bubble in project.bubbles) {
      final path = bubble.audioPath;
      if (path == null || path.isEmpty) continue;
      if (skipBlank && !_hasValidSpeech(bubble.content)) continue;
      if (await File(path).exists()) paths.add(path);
    }
    if (paths.isEmpty) {
      throw Exception('没有可导出的音频，请先生成音频。');
    }
    return paths;
  }

  Future<String> mergedAudioOutputPath(
    BanterProject project, {
    required double speed,
  }) async {
    final exportDir = Directory('${(await appDir).path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    final speedLabel = speed
        .toStringAsFixed(speed % 1 == 0 ? 0 : 2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '${exportDir.path}/${sanitizeFileName(project.name)}_${speedLabel}x_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  Future<List<MergedAudioExport>> listMergedAudioExports() async {
    final exportDir = Directory('${(await appDir).path}/exports');
    if (!await exportDir.exists()) return const [];
    final files = await exportDir
        .list()
        .where(
          (entity) =>
              entity is File &&
              (entity.path.toLowerCase().endsWith('.mp3') ||
                  entity.path.toLowerCase().endsWith('.m4a')),
        )
        .cast<File>()
        .toList();
    final exports = <MergedAudioExport>[];
    for (final file in files) {
      try {
        final stat = await file.stat();
        exports.add(
          MergedAudioExport(
            path: file.path,
            name: file.uri.pathSegments.last,
            createdAt: stat.modified,
            bytes: stat.size,
          ),
        );
      } catch (_) {}
    }
    exports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return exports;
  }

  Future<void> deleteMergedAudioExport(String path) async {
    final exportDir = Directory('${(await appDir).path}/exports').absolute;
    final file = File(path).absolute;
    if (file.parent.path != exportDir.path ||
        !(file.path.toLowerCase().endsWith('.mp3') ||
            file.path.toLowerCase().endsWith('.m4a'))) {
      throw ArgumentError('无效的合并音频路径。');
    }
    if (await file.exists()) await file.delete();
  }

  bool _hasValidSpeech(String text) =>
      RegExp(r'[a-zA-Z0-9\u4e00-\u9fa5]').hasMatch(text);
}
