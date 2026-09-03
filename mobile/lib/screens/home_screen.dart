import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_settings.dart';
import '../models/dialog_style.dart';
import '../models/project.dart';
import '../services/app_settings_repository.dart';
import '../services/audio_player.dart';
import '../services/dialog_style_repository.dart';
import '../services/gemini_dialogue_service.dart';
import '../services/project_repository.dart';
import '../services/script_importer.dart';
import '../services/tts_service.dart';
import '../widgets/app_chrome.dart';
import '../widgets/bubble_card.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _DialogueGenerateRequest {
  const _DialogueGenerateRequest({required this.input, required this.styleId});

  final String input;
  final String styleId;
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = ProjectRepository();
  final _settingsRepository = AppSettingsRepository();
  final _styleRepository = DialogStyleRepository();
  final _geminiDialogue = GeminiDialogueService();
  final _tts = TtsService();
  final _audioPlayer = NativeAudioPlayer();
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _bubbleKeys = {};

  BanterProject? _project;
  AppSettings _settings = AppSettings();
  List<ProjectSummary> _projects = const [];
  List<DialogStyle> _styles = const [];
  bool _loading = true;
  bool _batchGenerating = false;
  bool _batchStopRequested = false;
  bool _dialogueGenerating = false;
  bool _playlistPlaying = false;
  bool _playlistPaused = false;
  bool _playlistStopRequested = false;
  String? _activeBubbleId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final project = await _repository.loadCurrent(createIfMissing: false);
    final projects = await _repository.listProjects();
    final settings = await _settingsRepository.load(legacyProject: project);
    final styles = await _styleRepository.load();
    setState(() {
      _project = project;
      _settings = settings;
      _projects = projects;
      _styles = styles;
      _loading = false;
    });
  }

  Future<void> _refreshProjects() async {
    _projects = await _repository.listProjects();
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final project = _project;
    if (project != null) {
      await _repository.save(project, select: true);
      await _refreshProjects();
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _hasValidSpeech(String text) =>
      RegExp(r'[a-zA-Z0-9\u4e00-\u9fa5]').hasMatch(text);

  Future<bool> _generate(
    DialogueBubble bubble, {
    bool showSuccessSnack = true,
    bool showErrorSnack = true,
  }) async {
    final project = _project!;
    if (!_hasValidSpeech(bubble.content)) {
      setState(() {
        bubble.status = BubbleStatus.error;
        bubble.errorMessage = '没有可朗读内容';
      });
      await _save();
      if (showErrorSnack) _snack('生成失败：没有可朗读内容');
      return false;
    }

    setState(() {
      bubble.status = BubbleStatus.loading;
      bubble.errorMessage = null;
    });

    try {
      final path = await _repository.audioPathFor(project.name, bubble.id);
      final voice = bubble.role == BubbleRole.host
          ? _settings.hostVoiceId
          : _settings.guestVoiceId;
      await _tts.saveAudioToFile(
        text: bubble.content,
        speaker: voice,
        outputPath: path,
        appKey: _settings.appKey,
        accessToken: _settings.accessToken,
      );
      setState(() {
        bubble.status = BubbleStatus.success;
        bubble.audioPath = path;
      });
      await _save();
      if (showSuccessSnack) _snack('已生成：${bubble.name}');
      return true;
    } catch (error) {
      setState(() {
        bubble.status = BubbleStatus.error;
        bubble.errorMessage = error.toString();
      });
      await _save();
      if (showErrorSnack) _snack('生成失败：$error');
      return false;
    }
  }

  Future<void> _generateAll() async {
    final project = _project!;
    final pending = project.bubbles
        .where(
          (b) =>
              b.status != BubbleStatus.success &&
              b.status != BubbleStatus.loading,
        )
        .toList();
    if (pending.isEmpty || _batchGenerating) return;
    setState(() {
      _batchGenerating = true;
      _batchStopRequested = false;
    });
    var generated = 0;
    var failed = 0;
    try {
      for (final bubble in pending) {
        if (!mounted || _batchStopRequested) break;
        final ok = await _generate(
          bubble,
          showSuccessSnack: false,
          showErrorSnack: false,
        );
        if (ok) {
          generated++;
        } else {
          failed++;
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    } finally {
      if (mounted) {
        final stopped = _batchStopRequested;
        setState(() {
          _batchGenerating = false;
          _batchStopRequested = false;
        });
        if (stopped) {
          _snack('已停止。已生成 $generated 条，下次会继续未完成条目。');
        } else if (failed > 0) {
          _snack('批量生成完成：成功 $generated 条，失败 $failed 条。');
        } else {
          _snack('全部音频已生成。');
        }
      }
    }
  }

  void _stopGenerateAll() {
    if (!_batchGenerating) return;
    setState(() => _batchStopRequested = true);
    _snack('正在停止，当前条目完成后暂停。');
  }

  Future<void> _showGenerateDialogueDialog() async {
    if (_styles.isEmpty || _dialogueGenerating) return;
    final current = _project ?? BanterProject.initial();
    var selectedStyleId = _settings.dialogStyleId;
    final controller = TextEditingController(text: _settings.lastDialogueInput);
    final result = await showModalBottomSheet<_DialogueGenerateRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedStyle = _styles.firstWhere(
            (style) => style.id == selectedStyleId,
            orElse: () => _styles.first,
          );
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '智能生成对话',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () async {
                    final style = await _pickDialogueStyle(selectedStyleId);
                    if (style == null) return;
                    setDialogState(() => selectedStyleId = style.id);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '对话风格',
                      prefixIcon: Icon(Icons.style_rounded),
                      suffixIcon: Icon(Icons.expand_more_rounded),
                    ),
                    child: Text(
                      selectedStyle.builtIn
                          ? selectedStyle.name
                          : '${selectedStyle.name}（自定义）',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 8,
                  maxLines: 14,
                  decoration: InputDecoration(
                    labelText: '关键词或话题',
                    hintText: '例如：能量守恒',
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    suffixIcon: IconButton(
                      onPressed: controller.clear,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: '清空',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {
                    final input = controller.text.trim();
                    if (input.isEmpty) return;
                    Navigator.pop(
                      context,
                      _DialogueGenerateRequest(
                        input: input,
                        styleId: selectedStyleId,
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('生成对话'),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (result == null) return;
    _settings.lastDialogueInput = result.input;
    await _settingsRepository.save(_settings);
    await _generateDialogue(
      input: result.input,
      styleId: result.styleId,
      baseProject: current,
    );
  }

  Future<DialogStyle?> _pickDialogueStyle(String selectedStyleId) {
    return showModalBottomSheet<DialogStyle>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: _styles.length,
          separatorBuilder: (_, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final style = _styles[index];
            final selected = style.id == selectedStyleId;
            return ListTile(
              selected: selected,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              selectedTileColor: const Color(0xFF8B5CF6).withValues(alpha: .20),
              leading: Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
              ),
              title: Text(
                style.builtIn ? style.name : '${style.name}（自定义）',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: style.description.isEmpty
                  ? null
                  : Text(
                      style.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => Navigator.pop(context, style),
            );
          },
        ),
      ),
    );
  }

  Future<void> _generateDialogue({
    required String input,
    required String styleId,
    required BanterProject baseProject,
  }) async {
    final style = _styles.firstWhere(
      (style) => style.id == styleId,
      orElse: () => _styles.first,
    );
    if (_settings.geminiApiKey.trim().isEmpty) {
      _snack('请先在设置里填写 Gemini API Key。');
      return;
    }

    setState(() => _dialogueGenerating = true);
    try {
      final bubbles = await _geminiDialogue.generateDialogue(
        input: input.trim(),
        style: style,
        settings: _settings,
        project: baseProject,
      );
      final project = BanterProject.initial(
        name: '${style.name}_${input.trim()}',
      )..bubbles = bubbles;
      _settings.dialogStyleId = style.id;
      _settings.applyNamesTo(project);
      await _settingsRepository.save(_settings);
      await _repository.save(project, select: true);
      final projects = await _repository.listProjects();
      if (!mounted) return;
      setState(() {
        _project = project;
        _projects = projects;
      });
      _snack('已生成 ${bubbles.length} 条对话。');
    } catch (error) {
      _snack('生成对话失败：$error');
    } finally {
      if (mounted) setState(() => _dialogueGenerating = false);
    }
  }

  Future<void> _play(DialogueBubble bubble) async {
    final path = bubble.audioPath;
    if (path == null || path.isEmpty) {
      _snack('这条还没有音频，请先生成。');
      return;
    }
    setState(() => _activeBubbleId = bubble.id);
    await _scrollToBubble(bubble.id);
    await _audioPlayer.play(path, speed: _settings.playbackSpeed);
  }

  Future<void> _playAll({String? startBubbleId}) async {
    final project = _project;
    if (project == null || _playlistPlaying) return;
    final startIndex = startBubbleId == null
        ? 0
        : project.bubbles.indexWhere((bubble) => bubble.id == startBubbleId);
    final source = startIndex <= 0
        ? project.bubbles
        : project.bubbles.skip(startIndex);
    final ready = source.where((bubble) {
      if (_settings.skipBlankOnPlayback && !_hasValidSpeech(bubble.content)) {
        return false;
      }
      return bubble.audioPath?.isNotEmpty == true;
    }).toList();
    if (ready.isEmpty) {
      _snack('还没有可播放的音频，请先生成。');
      return;
    }
    setState(() {
      _playlistPlaying = true;
      _playlistPaused = false;
      _playlistStopRequested = false;
    });
    try {
      for (final bubble in ready) {
        if (!mounted || _playlistStopRequested) break;
        final path = bubble.audioPath;
        if (path == null || path.isEmpty) continue;
        setState(() => _activeBubbleId = bubble.id);
        await _scrollToBubble(bubble.id);
        final duration = await _audioPlayer.duration(path);
        await _audioPlayer.play(path, speed: _settings.playbackSpeed);
        await _waitForPlayback(duration, speed: _settings.playbackSpeed);
      }
    } finally {
      await _audioPlayer.stop();
      if (mounted) {
        final stopped = _playlistStopRequested;
        setState(() {
          _playlistPlaying = false;
          _playlistPaused = false;
          _playlistStopRequested = false;
          _activeBubbleId = null;
        });
        if (stopped) {
          _snack('已停止播放。');
        } else {
          _snack('已播放完毕。');
        }
      }
    }
  }

  Future<void> _stopPlayAll() async {
    if (!_playlistPlaying) return;
    setState(() {
      _playlistStopRequested = true;
      _playlistPaused = false;
    });
    await _audioPlayer.stop();
  }

  Future<void> _pausePlayAll() async {
    if (!_playlistPlaying || _playlistPaused) return;
    setState(() => _playlistPaused = true);
    await _audioPlayer.pause();
  }

  Future<void> _resumePlayAll() async {
    if (!_playlistPlaying || !_playlistPaused) return;
    setState(() => _playlistPaused = false);
    await _audioPlayer.resume();
  }

  Future<void> _waitForPlayback(
    Duration duration, {
    required double speed,
  }) async {
    final safeSpeed = speed.clamp(0.5, 4.0);
    var remainingMs = duration.inMilliseconds > 0
        ? (duration.inMilliseconds / safeSpeed).round() + 250
        : 3000;
    while (mounted && !_playlistStopRequested && remainingMs > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!_playlistPaused) remainingMs -= 150;
    }
  }

  Future<void> _scrollToBubble(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (!mounted) return;
    final bubbleContext = _bubbleKeys[id]?.currentContext;
    if (bubbleContext == null || !bubbleContext.mounted) return;
    await Scrollable.ensureVisible(
      bubbleContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: .25,
    );
  }

  Future<void> _openSettings() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(settings: _settings, project: _project),
      ),
    );
    if (saved != true) return;
    await _settingsRepository.save(_settings);
    setState(() {});
    await _save();
  }

  Future<void> _importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt', 'zip'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    if (path.toLowerCase().endsWith('.zip')) {
      try {
        final project = await _repository.importProjectZip(path);
        _settings.applyNamesTo(project);
        await _repository.save(project, select: true);
        final projects = await _repository.listProjects();
        setState(() {
          _project = project;
          _projects = projects;
        });
        _snack('已导入项目包：${project.name}');
      } catch (error) {
        _snack('导入项目包失败：$error');
      }
      return;
    }
    final raw = await File(path).readAsString();
    await _importJson(raw);
  }

  Future<void> _showImportDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('粘贴导入 JSON 剧本'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(
              hintText:
                  '{"dialogue_list":[{"id":1,"speaker":"嘉宾","content":"示例内容"}]}',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    await _importJson(result);
  }

  Future<void> _importJson(String raw) async {
    try {
      final baseProject = _project ?? BanterProject.initial();
      _settings.applyNamesTo(baseProject);
      final imported = ScriptImporter.parseDesktopJson(raw, baseProject);
      final project = BanterProject.initial(
        name:
            '导入_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      )..bubbles = imported;
      _settings.applyNamesTo(project);
      await _repository.save(project, select: true);
      final projects = await _repository.listProjects();
      setState(() {
        _project = project;
        _projects = projects;
      });
      _snack('已导入 ${imported.length} 条对话');
    } catch (error) {
      _snack('导入失败：$error');
    }
  }

  Future<void> _exportAndShare() async {
    final project = _project!;
    try {
      final zipPath = await _repository.exportProjectZip(project);
      await Share.shareXFiles([
        XFile(zipPath),
      ], text: '泊睿妙语项目包：${project.name}');
    } catch (error) {
      _snack('导出失败：$error');
    }
  }

  Future<void> _exportMergedAudioAndShare() async {
    final project = _project!;
    try {
      final audioPath = await _repository.exportMergedAudio(
        project,
        skipBlank: _settings.skipBlankOnPlayback,
      );
      await Share.shareXFiles([
        XFile(audioPath),
      ], text: '泊睿妙语合成音频：${project.name}');
    } catch (error) {
      _snack('导出合成音频失败：$error');
    }
  }

  Future<void> _newProject() async {
    final name = await _askName('新建项目', '新项目');
    if (name == null) return;
    final project = BanterProject.initial(name: name);
    _settings.applyNamesTo(project);
    await _repository.save(project, select: true);
    final projects = await _repository.listProjects();
    setState(() {
      _project = project;
      _projects = projects;
    });
  }

  Future<String?> _askName(String title, String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return null;
    return result.trim();
  }

  void _addBubble(BubbleRole role) {
    final project = _project!;
    setState(() {
      project.bubbles.add(
        DialogueBubble(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          role: role,
          name: role == BubbleRole.host ? project.hostName : project.guestName,
          content: '',
        ),
      );
    });
    _save();
    scheduleMicrotask(() {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 180,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _renameProject() async {
    final result = await _askName('项目名称', _project!.name);
    if (result == null) return;
    await _repository.renameProjectFile(_project!, result);
    await _refreshProjects();
  }

  Future<void> _selectProject(String fileName) async {
    final project = await _repository.loadByFileName(fileName);
    if (project == null) return;
    if (!mounted) return;
    Navigator.pop(context);
    setState(() => _project = project);
  }

  Future<void> _deleteProject(ProjectSummary summary) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除项目？'),
        content: Text('确定删除「${summary.name}」吗？此操作不会删除已导出的 zip。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _repository.deleteProject(summary.fileName);
    final currentDeleted = _project?.fileName == summary.fileName;
    final projects = await _repository.listProjects();
    if (currentDeleted) {
      final next = projects.isEmpty
          ? null
          : await _repository.loadByFileName(projects.first.fileName);
      setState(() {
        _project = next;
        _projects = projects;
      });
    } else {
      setState(() => _projects = projects);
    }
    _snack('已删除：${summary.name}');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final project = _project;
    final doneCount =
        project?.bubbles
            .where((b) => b.status == BubbleStatus.success)
            .length ??
        0;
    final pendingCount =
        project?.bubbles
            .where(
              (b) =>
                  b.status == BubbleStatus.idle ||
                  b.status == BubbleStatus.error,
            )
            .length ??
        0;
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: Drawer(
        backgroundColor: const Color(0xFF111226),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFFF4FD8)],
                          ),
                        ),
                        child: const Icon(
                          Icons.graphic_eq,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '项目库',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${_projects.length} 个创作项目',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .58),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _newProject,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final item = _projects[index];
                    final selected = item.fileName == project?.fileName;
                    return Dismissible(
                      key: ValueKey(item.fileName),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        await _deleteProject(item);
                        return false;
                      },
                      background: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: const Color(0xFFEF4444).withValues(alpha: .85),
                        ),
                        child: const Icon(Icons.delete_rounded),
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: selected
                              ? const Color(0xFF8B5CF6).withValues(alpha: .22)
                              : Colors.white.withValues(alpha: .04),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF8B5CF6)
                                : Colors.white.withValues(alpha: .08),
                          ),
                        ),
                        child: ListTile(
                          leading: Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.article_outlined,
                          ),
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${item.bubbleCount} 条 · ${item.updatedAt.toLocal().toString().substring(0, 16)}',
                          ),
                          onTap: () => _selectProject(item.fileName),
                          trailing: IconButton(
                            tooltip: '删除项目',
                            color: const Color(0xFFFCA5A5),
                            onPressed: () => _deleteProject(item),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: GestureDetector(
          onTap: project == null ? null : _renameProject,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScrollingTitle(
                text: project?.name ?? '项目库为空',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                project == null ? '新建或导入一个项目' : '点击重命名',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: .55),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: _dialogueGenerating ? null : _showGenerateDialogueDialog,
            icon: _dialogueGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded),
            tooltip: '智能生成对话',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: '导入/导出项目',
            color: const Color(0xFF1B1D35),
            onSelected: (value) {
              if (value == 'paste') {
                _showImportDialog();
              } else if (value == 'file') {
                _importFromFile();
              } else if (value == 'export_audio' && project != null) {
                _exportMergedAudioAndShare();
              } else if (value == 'export' && project != null) {
                _exportAndShare();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'paste', child: Text('粘贴导入 JSON')),
              const PopupMenuItem(value: 'file', child: Text('从文件/ZIP 导入')),
              if (project != null)
                const PopupMenuItem(
                  value: 'export_audio',
                  child: Text('导出合成音频'),
                ),
              if (project != null)
                const PopupMenuItem(value: 'export', child: Text('导出/分享项目包')),
            ],
          ),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded),
            tooltip: '设置',
          ),
        ],
      ),
      body: NeonScaffold(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '灵感对话工作台',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .58),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  '多角色播客生成台',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: const Color(
                                0xFF22D3EE,
                              ).withValues(alpha: .14),
                            ),
                            child: Text(
                              '$doneCount/${project?.bubbles.length ?? 0}',
                              style: const TextStyle(
                                color: Color(0xFF67E8F9),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: project == null || project.bubbles.isEmpty
                              ? 0
                              : doneCount / project.bubbles.length,
                          backgroundColor: Colors.white.withValues(alpha: .09),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFFFF4FD8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: GradientButton(
                              onPressed: project == null
                                  ? null
                                  : (_batchGenerating
                                        ? _stopGenerateAll
                                        : pendingCount == 0
                                        ? null
                                        : _generateAll),
                              icon: Icons.bolt_rounded,
                              label: _batchGenerating
                                  ? '停止生成'
                                  : pendingCount == 0
                                  ? '全部已生成'
                                  : '生成全部 ($pendingCount)',
                              busy: _batchGenerating,
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            onPressed: project == null
                                ? null
                                : (_playlistPlaying
                                      ? (_playlistPaused
                                            ? _resumePlayAll
                                            : _pausePlayAll)
                                      : () => _playAll()),
                            icon: Icon(
                              _playlistPlaying
                                  ? (_playlistPaused
                                        ? Icons.play_arrow_rounded
                                        : Icons.pause_rounded)
                                  : Icons.playlist_play_rounded,
                            ),
                            tooltip: _playlistPlaying
                                ? (_playlistPaused ? '继续播放' : '暂停播放')
                                : '播放全部',
                          ),
                          if (_playlistPlaying) ...[
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _stopPlayAll,
                              icon: const Icon(Icons.stop_rounded),
                              tooltip: '停止播放',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: project == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: GlassPanel(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.library_add_rounded,
                                  size: 42,
                                  color: Color(0xFF67E8F9),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  '还没有项目',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                FilledButton.icon(
                                  onPressed: _newProject,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('新建项目'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 112),
                        itemCount: project.bubbles.length,
                        itemBuilder: (context, index) {
                          final bubble = project.bubbles[index];
                          final key = _bubbleKeys.putIfAbsent(
                            bubble.id,
                            GlobalKey.new,
                          );
                          return KeyedSubtree(
                            key: key,
                            child: BubbleCard(
                              bubble: bubble,
                              sequence: index + 1,
                              active: bubble.id == _activeBubbleId,
                              onChanged: (value) {
                                setState(() {
                                  bubble.content = value;
                                  bubble.status = BubbleStatus.idle;
                                });
                                _save();
                              },
                              onGenerate: () => _generate(bubble),
                              onPlay: () => _play(bubble),
                              onPlayFromHere: () =>
                                  _playAll(startBubbleId: bubble.id),
                              onDelete: () {
                                _bubbleKeys.remove(bubble.id);
                                setState(() => project.bubbles.removeAt(index));
                                _save();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: project == null
          ? null
          : Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: const Color(0xFF101126).withValues(alpha: .92),
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'guest',
                    backgroundColor: const Color(0xFF22D3EE),
                    onPressed: () => _addBubble(BubbleRole.guest),
                    child: const Icon(
                      Icons.person_add_alt,
                      color: Color(0xFF07111F),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    heroTag: 'host',
                    backgroundColor: const Color(0xFFFF4FD8),
                    onPressed: () => _addBubble(BubbleRole.host),
                    child: const Icon(
                      Icons.record_voice_over,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ScrollingTitle extends StatefulWidget {
  const _ScrollingTitle({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_ScrollingTitle> createState() => _ScrollingTitleState();
}

class _ScrollingTitleState extends State<_ScrollingTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String? _configuredText;
  double? _configuredWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final style = defaultStyle.merge(widget.style);
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width * .52;
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: textDirection,
        )..layout();
        final textWidth = painter.width;
        final shouldScroll = textWidth > availableWidth;

        if (!shouldScroll) {
          if (_controller.isAnimating) _controller.stop();
          return Text(widget.text, maxLines: 1, style: widget.style);
        }

        if (_configuredText != widget.text ||
            _configuredWidth != availableWidth ||
            !_controller.isAnimating) {
          _configuredText = widget.text;
          _configuredWidth = availableWidth;
          final distance = textWidth + 36;
          final durationMs = (distance / 28 * 1000).round().clamp(4500, 12000);
          _controller
            ..duration = Duration(milliseconds: durationMs)
            ..repeat();
        }

        const gap = SizedBox(width: 36);
        return ClipRect(
          child: SizedBox(
            width: availableWidth,
            height: painter.height,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final offset = -_controller.value * (textWidth + 36);
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.text, maxLines: 1, style: widget.style),
                  gap,
                  Text(widget.text, maxLines: 1, style: widget.style),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
