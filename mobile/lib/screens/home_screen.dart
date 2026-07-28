import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/project.dart';
import '../services/audio_player.dart';
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
  final _tts = TtsService();
  final _audioPlayer = NativeAudioPlayer();
  final _scrollController = ScrollController();

  BanterProject? _project;
  List<ProjectSummary> _projects = const [];
  bool _loading = true;
  bool _batchGenerating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final project = await _repository.loadCurrent();
    final projects = await _repository.listProjects();
    setState(() {
      _project = project;
      _projects = projects;
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
          ? project.hostVoiceId
          : project.guestVoiceId;
      await _tts.saveAudioToFile(
        text: bubble.content,
        speaker: voice,
        outputPath: path,
        appKey: project.appKey,
        accessToken: project.accessToken,
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
    setState(() => _batchGenerating = true);
    for (final bubble in pending) {
      if (!mounted) break;
      await _generate(bubble);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (mounted) setState(() => _batchGenerating = false);
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
    final project = _project!;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SettingsScreen(project: project)));
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
      final imported = ScriptImporter.parseDesktopJson(raw, _project!);
      final project = BanterProject.initial(
        name:
            'Import_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      )..bubbles = imported;
      project.hostName = _project!.hostName;
      project.guestName = _project!.guestName;
      project.hostVoiceId = _project!.hostVoiceId;
      project.guestVoiceId = _project!.guestVoiceId;
      project.appKey = _project!.appKey;
      project.accessToken = _project!.accessToken;
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
    if (currentDeleted) {
      final next = await _repository.loadCurrent();
      setState(() => _project = next);
    }
    await _refreshProjects();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final project = _project!;
    final doneCount = project.bubbles
        .where((b) => b.status == BubbleStatus.success)
        .length;
    final pendingCount = project.bubbles
        .where(
          (b) =>
              b.status == BubbleStatus.idle || b.status == BubbleStatus.error,
        )
        .length;
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
                    final selected = item.fileName == project.fileName;
                    return Container(
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
                          onPressed: () => _deleteProject(item),
                          icon: const Icon(Icons.delete_outline),
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
          onTap: _renameProject,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                'Tap to rename',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: .55),
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share_rounded),
            color: const Color(0xFF1B1D35),
            onSelected: (value) {
              if (value == 'paste') {
                _showImportDialog();
              } else if (value == 'file') {
                _importFromFile();
              } else if (value == 'export') {
                _exportAndShare();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'paste', child: Text('粘贴导入 JSON')),
              PopupMenuItem(value: 'file', child: Text('从文件/ZIP 导入')),
              PopupMenuItem(value: 'export', child: Text('导出/分享项目包')),
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
                              '$doneCount/${project.bubbles.length}',
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
                          value: project.bubbles.isEmpty
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
                              onPressed: _batchGenerating ? null : _generateAll,
                              icon: Icons.bolt_rounded,
                              label: _batchGenerating
                                  ? '批量生成中...'
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
                child: ListView.builder(
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
                      onRoleChanged: (role) {
                        setState(() {
                          bubble.role = role;
                          bubble.name = role == BubbleRole.host
                              ? project.hostName
                              : project.guestName;
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
      floatingActionButton: Container(
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
              child: const Icon(Icons.person_add_alt, color: Color(0xFF07111F)),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              heroTag: 'host',
              backgroundColor: const Color(0xFFFF4FD8),
              onPressed: () => _addBubble(BubbleRole.host),
              child: const Icon(Icons.record_voice_over, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
