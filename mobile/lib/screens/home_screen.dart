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

class _HomeScreenState extends State<HomeScreen> {
  final _repository = ProjectRepository();
  final _settingsRepository = AppSettingsRepository();
  final _styleRepository = DialogStyleRepository();
  final _geminiDialogue = GeminiDialogueService();
  final _tts = TtsService();
  final _audioPlayer = NativeAudioPlayer();
  final _scrollController = ScrollController();

  BanterProject? _project;
  AppSettings _settings = AppSettings();
  List<ProjectSummary> _projects = const [];
  List<DialogStyle> _styles = const [];
  bool _loading = true;
  bool _batchGenerating = false;
  bool _batchStopRequested = false;
  bool _dialogueGenerating = false;

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

  Future<void> _generate(DialogueBubble bubble) async {
    final project = _project!;
    if (!_hasValidSpeech(bubble.content)) {
      setState(() {
        bubble.status = BubbleStatus.error;
        bubble.errorMessage = '没有可朗读内容';
      });
      await _save();
      return;
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
      _snack('已生成：${bubble.name}');
    } catch (error) {
      setState(() {
        bubble.status = BubbleStatus.error;
        bubble.errorMessage = error.toString();
      });
      await _save();
      _snack('生成失败：$error');
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
    for (final bubble in pending) {
      if (!mounted || _batchStopRequested) break;
      await _generate(bubble);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (mounted) {
      final stopped = _batchStopRequested;
      setState(() {
        _batchGenerating = false;
        _batchStopRequested = false;
      });
      if (stopped) _snack('已停止。下次会继续生成未完成条目。');
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
    final controller = TextEditingController();
    final shouldGenerate = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('AI 生成对话'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue:
                      _styles.any((style) => style.id == selectedStyleId)
                      ? selectedStyleId
                      : _styles.first.id,
                  decoration: const InputDecoration(
                    labelText: '对话风格',
                    prefixIcon: Icon(Icons.style_rounded),
                  ),
                  items: _styles
                      .map(
                        (style) => DropdownMenuItem(
                          value: style.id,
                          child: Text(style.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedStyleId = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: '关键词或话题',
                    hintText: '例如：能量守恒',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('生成对话'),
            ),
          ],
        ),
      ),
    );
    if (shouldGenerate != true || controller.text.trim().isEmpty) return;
    await _generateDialogue(
      input: controller.text.trim(),
      styleId: selectedStyleId,
      baseProject: current,
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
    await _audioPlayer.play(path);
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
                  '{"dialogue_list":[{"id":1,"speaker":"Speaker 1","content":"..."}]}',
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
            'Import_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
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

  Future<void> _newProject() async {
    final name = await _askName('新建项目', 'Mobile_Project');
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
              Text(
                project?.name ?? '项目库为空',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                project == null ? '新建或导入一个项目' : 'Tap to rename',
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
            tooltip: 'AI 生成对话',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share_rounded),
            color: const Color(0xFF1B1D35),
            onSelected: (value) {
              if (value == 'paste') {
                _showImportDialog();
              } else if (value == 'file') {
                _importFromFile();
              } else if (value == 'export' && project != null) {
                _exportAndShare();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'paste', child: Text('粘贴导入 JSON')),
              const PopupMenuItem(value: 'file', child: Text('从文件/ZIP 导入')),
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
                                  'Where Wisdom Plays',
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
                                    letterSpacing: -.5,
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
                                        : _generateAll),
                              icon: Icons.bolt_rounded,
                              label: _batchGenerating
                                  ? '停止生成'
                                  : '生成全部 ($pendingCount)',
                              busy: _batchGenerating,
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            onPressed: () => _audioPlayer.stop(),
                            icon: const Icon(Icons.stop_rounded),
                          ),
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
                          return BubbleCard(
                            key: ValueKey(bubble.id),
                            bubble: bubble,
                            onChanged: (value) {
                              setState(() {
                                bubble.content = value;
                                bubble.status = BubbleStatus.idle;
                              });
                              _save();
                            },
                            onGenerate: () => _generate(bubble),
                            onPlay: () => _play(bubble),
                            onDelete: () {
                              setState(() => project.bubbles.removeAt(index));
                              _save();
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: project == null
          ? FloatingActionButton.extended(
              onPressed: _newProject,
              icon: const Icon(Icons.add_rounded),
              label: const Text('新建项目'),
            )
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
