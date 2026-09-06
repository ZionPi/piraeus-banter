import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_settings.dart';
import '../models/dialog_style.dart';
import '../models/project.dart';
import '../services/app_settings_repository.dart';
import '../services/audio_player.dart';
import '../services/dialog_style_repository.dart';
import '../services/document_text_service.dart';
import '../services/gemini_dialogue_service.dart';
import '../services/project_repository.dart';
import '../services/script_importer.dart';
import '../services/tts_service.dart';
import '../widgets/app_chrome.dart';
import '../widgets/bubble_card.dart';
import 'dialogue_text_screen.dart';
import 'merged_audio_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _DialogueInputMode { topic, file, url }

extension on _DialogueInputMode {
  String get label => switch (this) {
    _DialogueInputMode.topic => '关键词或话题',
    _DialogueInputMode.file => '上传文件',
    _DialogueInputMode.url => '网页链接',
  };

  String get description => switch (this) {
    _DialogueInputMode.topic => '输入一个主题，由 AI 主动展开对话',
    _DialogueInputMode.file => '从 EPUB、PDF、DOCX 等文档生成对话',
    _DialogueInputMode.url => '支持普通网页和微信公众号文章',
  };

  IconData get icon => switch (this) {
    _DialogueInputMode.topic => Icons.chat_bubble_outline_rounded,
    _DialogueInputMode.file => Icons.upload_file_rounded,
    _DialogueInputMode.url => Icons.link_rounded,
  };
}

class _DialogueGenerateRequest {
  const _DialogueGenerateRequest.topic({
    required this.input,
    required this.styleId,
  }) : mode = _DialogueInputMode.topic,
       filePath = null,
       fileName = null,
       url = null,
       additionalText = null;

  const _DialogueGenerateRequest.file({
    required this.filePath,
    required this.fileName,
    required this.additionalText,
    required this.styleId,
  }) : mode = _DialogueInputMode.file,
       input = null,
       url = null;

  const _DialogueGenerateRequest.url({required this.url, required this.styleId})
    : mode = _DialogueInputMode.url,
      input = null,
      filePath = null,
      fileName = null,
      additionalText = null;

  final _DialogueInputMode mode;
  final String? input;
  final String? filePath;
  final String? fileName;
  final String? url;
  final String? additionalText;
  final String styleId;
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _repository = ProjectRepository();
  final _settingsRepository = AppSettingsRepository();
  final _styleRepository = DialogStyleRepository();
  final _documentText = DocumentTextService();
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
  double? _dialogueProgress;
  String? _activeBubbleId;
  String? _lastSnackMessage;
  DateTime? _lastSnackAt;
  Timer? _editSaveTimer;
  BanterProject? _pendingEditProject;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _editSaveTimer?.cancel();
    final pending = _pendingEditProject;
    if (pending != null) {
      unawaited(_saveProject(pending, select: false, refresh: false));
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushPendingEditSave());
    }
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

  Future<void> _showProject(
    BanterProject? project, {
    List<ProjectSummary>? projects,
  }) async {
    if (!mounted) return;
    if (!identical(_project, project)) {
      await _flushPendingEditSave(select: false);
    }
    if (!mounted) return;
    _bubbleKeys.clear();
    setState(() {
      _project = project;
      _activeBubbleId = null;
      if (projects != null) _projects = projects;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  Future<void> _save() async {
    final project = _project;
    if (project == null) return;
    await _saveProject(project);
  }

  Future<void> _saveProject(
    BanterProject project, {
    bool select = true,
    bool refresh = true,
  }) async {
    final previous = _saveQueue;
    final completed = Completer<void>();
    _saveQueue = completed.future;
    try {
      await previous;
      await _repository.save(project, select: select);
    } finally {
      completed.complete();
    }
    if (refresh && mounted && identical(_project, project)) {
      await _refreshProjects();
    }
  }

  void _scheduleEditSave(BanterProject project) {
    _pendingEditProject = project;
    _editSaveTimer?.cancel();
    _editSaveTimer = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_flushPendingEditSave()),
    );
  }

  Future<void> _flushPendingEditSave({bool select = true}) async {
    _editSaveTimer?.cancel();
    _editSaveTimer = null;
    final project = _pendingEditProject;
    _pendingEditProject = null;
    if (project == null) return;
    await _saveProject(
      project,
      select: select && identical(_project, project),
      refresh: identical(_project, project),
    );
  }

  void _discardPendingEdit(BanterProject? project) {
    if (!identical(_pendingEditProject, project)) return;
    _editSaveTimer?.cancel();
    _editSaveTimer = null;
    _pendingEditProject = null;
  }

  void _snack(String message, {String? actionLabel, VoidCallback? onAction}) {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastSnackMessage == message &&
        _lastSnackAt != null &&
        now.difference(_lastSnackAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastSnackMessage = message;
    _lastSnackAt = now;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: onAction == null
            ? const Duration(seconds: 4)
            : const Duration(seconds: 10),
        action: onAction == null
            ? null
            : SnackBarAction(label: actionLabel!, onPressed: onAction),
      ),
    );
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

  Future<void> _toggleWorkspaceCollapsed() async {
    setState(() {
      _settings.workspaceCollapsed = !_settings.workspaceCollapsed;
    });
    await _settingsRepository.save(_settings);
  }

  Future<void> _showGenerateDialogueDialog() async {
    if (_styles.isEmpty || _dialogueGenerating) return;
    final current = _project ?? BanterProject.initial();
    var selectedStyleId = _settings.dialogStyleId;
    var selectedInputMode = _DialogueInputMode.values.firstWhere(
      (mode) => mode.name == _settings.dialogueInputMode,
      orElse: () => _DialogueInputMode.topic,
    );
    PlatformFile? selectedFile;
    final rememberedFilePath = _settings.lastDialogueFilePath.trim();
    if (rememberedFilePath.isNotEmpty) {
      final rememberedFile = File(rememberedFilePath);
      if (await rememberedFile.exists()) {
        final size = await rememberedFile.length();
        final name = _settings.lastDialogueFileName.trim().isEmpty
            ? rememberedFile.uri.pathSegments.last
            : _settings.lastDialogueFileName.trim();
        if (size > 0 && size <= DocumentTextService.maxUploadBytesFor(name)) {
          selectedFile = PlatformFile(
            name: name,
            size: size,
            path: rememberedFilePath,
          );
        }
      }
      if (selectedFile == null) {
        _settings.lastDialogueFilePath = '';
        _settings.lastDialogueFileName = '';
        _settings.lastDialogueFileSize = 0;
        await _settingsRepository.save(_settings);
      }
    }
    if (!mounted) return;
    final controller = TextEditingController(text: _settings.lastDialogueInput);
    final urlController = TextEditingController(
      text: _settings.lastDialogueUrl,
    );
    final additionalController = TextEditingController();
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
          Future<void> pasteInto(TextEditingController target) async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            final text = data?.text;
            if (text == null || text.isEmpty) return;
            target.value = TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            );
          }

          void submit() {
            if (selectedInputMode == _DialogueInputMode.topic) {
              final input = controller.text.trim();
              if (input.isEmpty) return;
              Navigator.pop(
                context,
                _DialogueGenerateRequest.topic(
                  input: input,
                  styleId: selectedStyleId,
                ),
              );
              return;
            }
            if (selectedInputMode == _DialogueInputMode.url) {
              final url = urlController.text.trim();
              final uri = Uri.tryParse(url);
              if (uri == null ||
                  !{'http', 'https'}.contains(uri.scheme) ||
                  uri.host.isEmpty) {
                _snack('请输入完整的 http 或 https 网页链接。');
                return;
              }
              Navigator.pop(
                context,
                _DialogueGenerateRequest.url(
                  url: url,
                  styleId: selectedStyleId,
                ),
              );
              return;
            }
            final file = selectedFile;
            if (file?.path == null) {
              _snack('请先选择一个文档或图片。');
              return;
            }
            Navigator.pop(
              context,
              _DialogueGenerateRequest.file(
                filePath: file!.path!,
                fileName: file.name,
                additionalText: additionalController.text.trim(),
                styleId: selectedStyleId,
              ),
            );
          }

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
                    FilledButton.icon(
                      onPressed: submit,
                      icon: Icon(
                        selectedInputMode == _DialogueInputMode.file
                            ? Icons.upload_rounded
                            : selectedInputMode == _DialogueInputMode.url
                            ? Icons.language_rounded
                            : Icons.auto_awesome_rounded,
                        size: 18,
                      ),
                      label: const Text('生成'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(84, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                    const SizedBox(width: 4),
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
                    final mode = await _pickDialogueInputMode(
                      selectedInputMode,
                    );
                    if (mode == null) return;
                    if (mode != _DialogueInputMode.topic) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    }
                    setDialogState(() => selectedInputMode = mode);
                    _settings.dialogueInputMode = mode.name;
                    await _settingsRepository.save(_settings);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '输入来源',
                      suffixIcon: Icon(Icons.expand_more_rounded),
                    ),
                    child: Row(
                      children: [
                        Icon(selectedInputMode.icon, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          selectedInputMode.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () async {
                    final style = await _pickDialogueStyle(selectedStyleId);
                    if (style == null) return;
                    setDialogState(() => selectedStyleId = style.id);
                    _settings.dialogStyleId = style.id;
                    await _settingsRepository.save(_settings);
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
                if (selectedInputMode == _DialogueInputMode.topic)
                  Stack(
                    children: [
                      TextField(
                        controller: controller,
                        autofocus: true,
                        minLines: 8,
                        maxLines: 14,
                        decoration: const InputDecoration(
                          labelText: '关键词或话题',
                          hintText: '例如：能量守恒',
                          alignLabelWithHint: true,
                          contentPadding: EdgeInsets.fromLTRB(16, 20, 96, 48),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => pasteInto(controller),
                              icon: const Icon(
                                Icons.content_paste_rounded,
                                size: 19,
                              ),
                              tooltip: '粘贴',
                              style: _inputActionButtonStyle(),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: controller.clear,
                              icon: const Icon(Icons.close_rounded, size: 20),
                              tooltip: '清空',
                              style: _inputActionButtonStyle(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else if (selectedInputMode == _DialogueInputMode.file)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions:
                                DocumentTextService.supportedExtensions,
                            allowMultiple: false,
                          );
                          final file = result?.files.single;
                          if (file == null) return;
                          if (file.path == null) {
                            _snack('无法读取这个文件，请从本机存储中重新选择。');
                            return;
                          }
                          if (file.size == 0) {
                            _snack('不能选择空文件。');
                            return;
                          }
                          if (file.size >
                              DocumentTextService.maxUploadBytesFor(
                                file.name,
                              )) {
                            _snack(
                              '文件超过 ${DocumentTextService.maxSizeLabel(file.name)} 上传限制。',
                            );
                            return;
                          }
                          setDialogState(() => selectedFile = file);
                          _settings.lastDialogueFilePath = file.path!;
                          _settings.lastDialogueFileName = file.name;
                          _settings.lastDialogueFileSize = file.size;
                          await _settingsRepository.save(_settings);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '文档或图片',
                            suffixIcon: Icon(Icons.file_open_rounded),
                          ),
                          child: SizedBox(
                            height: 116,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  selectedFile == null
                                      ? Icons.upload_file_rounded
                                      : DocumentTextService.isImage(
                                          selectedFile!.name,
                                        )
                                      ? Icons.image_rounded
                                      : Icons.description_rounded,
                                  size: 34,
                                  color: const Color(0xFF8B5CF6),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  selectedFile?.name ?? '选择文档或图片',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  selectedFile == null
                                      ? '文档最大 25 MiB，图片最大 15 MiB'
                                      : _fileSizeLabel(selectedFile!.size),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .50),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: additionalController,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: '补充说明（可选）',
                          hintText: '例如：重点讨论第二张图表',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  )
                else
                  Stack(
                    children: [
                      TextField(
                        controller: urlController,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: '网页链接',
                          hintText: 'https://mp.weixin.qq.com/s/...',
                          alignLabelWithHint: true,
                          contentPadding: EdgeInsets.fromLTRB(16, 20, 96, 48),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => pasteInto(urlController),
                              icon: const Icon(Icons.content_paste_rounded),
                              tooltip: '粘贴网址',
                            ),
                            IconButton(
                              onPressed: () {
                                urlController.clear();
                                _settings.lastDialogueUrl = '';
                                unawaited(_settingsRepository.save(_settings));
                              },
                              icon: const Icon(Icons.close_rounded),
                              tooltip: '清空网址',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
              ],
            ),
          );
        },
      ),
    );
    controller.dispose();
    urlController.dispose();
    additionalController.dispose();
    if (result == null) return;
    _settings.dialogueInputMode = result.mode.name;
    if (result.mode == _DialogueInputMode.topic) {
      _settings.lastDialogueInput = result.input!;
    } else if (result.mode == _DialogueInputMode.url) {
      _settings.lastDialogueUrl = result.url!;
    }
    await _settingsRepository.save(_settings);
    await _generateDialogue(
      request: result,
      styleId: result.styleId,
      baseProject: current,
    );
  }

  Future<_DialogueInputMode?> _pickDialogueInputMode(
    _DialogueInputMode selectedMode,
  ) {
    return showModalBottomSheet<_DialogueInputMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: _DialogueInputMode.values.length,
          separatorBuilder: (_, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final mode = _DialogueInputMode.values[index];
            final selected = mode == selectedMode;
            return ListTile(
              selected: selected,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              selectedTileColor: const Color(0xFF8B5CF6).withValues(alpha: .20),
              leading: Icon(mode.icon),
              title: Text(
                mode.label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(mode.description),
              trailing: selected
                  ? const Icon(Icons.check_circle_rounded)
                  : null,
              onTap: () => Navigator.pop(context, mode),
            );
          },
        ),
      ),
    );
  }

  String _fileSizeLabel(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MiB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KiB';
  }

  ButtonStyle _inputActionButtonStyle() => IconButton.styleFrom(
    minimumSize: const Size.square(36),
    maximumSize: const Size.square(36),
    padding: EdgeInsets.zero,
    backgroundColor: Colors.black26,
    foregroundColor: Colors.white70,
  );

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
    required _DialogueGenerateRequest request,
    required String styleId,
    required BanterProject baseProject,
  }) async {
    final style = _styles.firstWhere(
      (style) => style.id == styleId,
      orElse: () => _styles.first,
    );
    setState(() {
      _dialogueGenerating = true;
      _dialogueProgress = request.mode == _DialogueInputMode.file ? 0 : null;
    });
    Object? failure;
    try {
      late DialogueGenerationResult generated;
      switch (request.mode) {
        case _DialogueInputMode.file:
          if (DocumentTextService.isImage(request.fileName!)) {
            generated = await _geminiDialogue.generateDialogueFromImage(
              path: request.filePath!,
              fileName: request.fileName!,
              additionalText: request.additionalText ?? '',
              style: style,
              settings: _settings,
              project: baseProject,
            );
            if (mounted) setState(() => _dialogueProgress = 1);
            break;
          }
          var lastProgress = -1.0;
          final extractedText = await _documentText.convertFile(
            path: request.filePath!,
            fileName: request.fileName!,
            onUploadProgress: (progress) {
              if (!mounted || progress - lastProgress < .01) return;
              lastProgress = progress;
              setState(() => _dialogueProgress = progress);
            },
            onUploadFinished: () {
              if (mounted) setState(() => _dialogueProgress = null);
            },
          );
          final additionalText = request.additionalText?.trim() ?? '';
          final input = additionalText.isEmpty
              ? extractedText
              : '$extractedText\n\n用户补充要求：$additionalText';
          generated = await _geminiDialogue.generateDialogue(
            input: input,
            style: style,
            settings: _settings,
            project: baseProject,
            onProgress: (progress) {
              if (mounted) setState(() => _dialogueProgress = progress);
            },
          );
        case _DialogueInputMode.url:
          final input = await _documentText.convertUrl(request.url!);
          generated = await _geminiDialogue.generateDialogue(
            input: input,
            style: style,
            settings: _settings,
            project: baseProject,
            onProgress: (progress) {
              if (mounted) setState(() => _dialogueProgress = progress);
            },
          );
        case _DialogueInputMode.topic:
          generated = await _geminiDialogue.generateDialogue(
            input: request.input!.trim(),
            style: style,
            settings: _settings,
            project: baseProject,
            onProgress: (progress) {
              if (mounted) setState(() => _dialogueProgress = progress);
            },
          );
      }
      final project = BanterProject.initial(
        name: '${generated.title}_${style.name}',
      )..bubbles = generated.bubbles;
      _settings.dialogStyleId = style.id;
      _settings.applyNamesTo(project);
      await _settingsRepository.save(_settings);
      await _repository.save(project, select: true);
      final projects = await _repository.listProjects();
      if (!mounted) return;
      await _showProject(project, projects: projects);
      _snack('已生成 ${generated.bubbles.length} 条对话。');
    } catch (error) {
      failure = error;
    } finally {
      if (mounted) {
        setState(() {
          _dialogueGenerating = false;
          _dialogueProgress = null;
        });
      }
    }
    if (failure != null && mounted) {
      _snack(
        '生成对话失败：${_friendlyError(failure)}',
        actionLabel: '重试',
        onAction: () => unawaited(
          _generateDialogue(
            request: request,
            styleId: styleId,
            baseProject: baseProject,
          ),
        ),
      );
    }
  }

  String _friendlyError(Object? error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  Future<void> _play(DialogueBubble bubble) async {
    final path = bubble.audioPath;
    if (path == null || path.isEmpty) {
      _snack('这条还没有音频，请先生成。');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _activeBubbleId = bubble.id);
    await _scrollToBubble(bubble.id);
    await _audioPlayer.play(path, speed: _settings.playbackSpeed);
  }

  Future<void> _playAll({String? startBubbleId}) async {
    final project = _project;
    if (project == null || _playlistPlaying) return;
    final requestedStartIndex = startBubbleId == null
        ? 0
        : project.bubbles.indexWhere((bubble) => bubble.id == startBubbleId);
    final startIndex = requestedStartIndex < 0 ? 0 : requestedStartIndex;
    final source = project.bubbles.skip(startIndex);
    final canPlayOrWait = source.any(
      (bubble) =>
          bubble.audioPath?.isNotEmpty == true ||
          bubble.status == BubbleStatus.loading,
    );
    if (!canPlayOrWait && !_batchGenerating) {
      _snack('还没有可播放的音频，请先生成。');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _playlistPlaying = true;
      _playlistPaused = false;
      _playlistStopRequested = false;
    });
    try {
      for (var index = startIndex; index < project.bubbles.length; index++) {
        if (!mounted || _playlistStopRequested) break;
        if (!identical(_project, project)) break;
        final bubble = project.bubbles[index];
        if (_settings.skipBlankOnPlayback && !_hasValidSpeech(bubble.content)) {
          continue;
        }
        if (bubble.audioPath?.isNotEmpty != true) {
          await _waitForBubbleAudio(project, bubble);
        }
        if (!mounted || _playlistStopRequested) break;
        await _waitUntilPlaylistResumed();
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

  Future<void> _waitForBubbleAudio(
    BanterProject project,
    DialogueBubble bubble,
  ) async {
    while (mounted && !_playlistStopRequested) {
      if (!identical(_project, project) ||
          bubble.audioPath?.isNotEmpty == true ||
          bubble.status == BubbleStatus.error) {
        return;
      }
      if (!_batchGenerating && bubble.status != BubbleStatus.loading) return;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<void> _waitUntilPlaylistResumed() async {
    while (mounted && !_playlistStopRequested && _playlistPaused) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
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
    if (!mounted || !_scrollController.hasClients) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_scrollController.hasClients) return;
    var bubbleContext = _bubbleKeys[id]?.currentContext;
    if (bubbleContext == null) {
      final bubbles = _project?.bubbles ?? const <DialogueBubble>[];
      final index = bubbles.indexWhere((bubble) => bubble.id == id);
      if (index < 0) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      final target = bubbles.length <= 1
          ? 0.0
          : maxExtent * index / (bubbles.length - 1);
      await _scrollController.animateTo(
        target.clamp(0.0, maxExtent),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      bubbleContext = _bubbleKeys[id]?.currentContext;
    }
    if (bubbleContext == null || !bubbleContext.mounted) return;
    await Scrollable.ensureVisible(
      bubbleContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: .18,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
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
        await _showProject(project, projects: projects);
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
      await _showProject(project, projects: projects);
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

  Future<void> _openMergedAudioScreen() async {
    final project = _project;
    if (project == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MergedAudioScreen(project: project, settings: _settings),
      ),
    );
  }

  Future<void> _openDialogueTextScreen() async {
    final project = _project;
    if (project == null) return;
    var exportTitle = project.name;
    final styleNames = _styles.map((style) => style.name).toList()
      ..sort((left, right) => right.length.compareTo(left.length));
    for (final styleName in styleNames) {
      final suffix = '_$styleName';
      if (exportTitle.endsWith(suffix)) {
        exportTitle = exportTitle.substring(
          0,
          exportTitle.length - suffix.length,
        );
        break;
      }
    }
    await _flushPendingEditSave();
    if (!mounted || !identical(_project, project)) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DialogueTextScreen(
          project: project,
          exportTitle: exportTitle,
          hostAvatarSeed: _settings.hostAvatarSeed,
          guestAvatarSeed: _settings.guestAvatarSeed,
          hostAvatarPath: _settings.hostAvatarPath,
          guestAvatarPath: _settings.guestAvatarPath,
        ),
      ),
    );
  }

  Future<void> _newProject() async {
    final name = await _askName('新建项目', '新项目');
    if (name == null) return;
    final project = BanterProject.initial(name: name);
    _settings.applyNamesTo(project);
    await _repository.save(project, select: true);
    final projects = await _repository.listProjects();
    await _showProject(project, projects: projects);
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

  Future<bool> _confirmDeleteBubble(DialogueBubble bubble, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除这条对话？'),
        content: Text('确定删除第 ${index + 1} 条「${bubble.name}」吗？相关音频记录也会从项目中移除。'),
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
    return confirm == true;
  }

  Future<void> _selectProject(String fileName) async {
    final project = await _repository.loadByFileName(fileName);
    if (project == null) return;
    if (!mounted) return;
    Navigator.pop(context);
    await _showProject(project);
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
    final currentDeleted = _project?.fileName == summary.fileName;
    if (currentDeleted) _discardPendingEdit(_project);
    await _repository.deleteProject(summary.fileName);
    final projects = await _repository.listProjects();
    if (currentDeleted) {
      final next = projects.isEmpty
          ? null
          : await _repository.loadByFileName(projects.first.fileName);
      await _showProject(next, projects: projects);
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
    final totalCount = project?.bubbles.length ?? 0;
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
                child: SlidableAutoCloseBehavior(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final item = _projects[index];
                      final selected = item.fileName == project?.fileName;
                      return Slidable(
                        key: ValueKey(item.fileName),
                        groupTag: 'projects',
                        endActionPane: ActionPane(
                          extentRatio: .22,
                          motion: const BehindMotion(),
                          children: [
                            SlidableAction(
                              onPressed: (_) => _deleteProject(item),
                              backgroundColor: const Color(0xFFB4233C),
                              foregroundColor: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              icon: Icons.delete_outline_rounded,
                              label: '删除',
                            ),
                          ],
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              '${item.bubbleCount} 条 · ${item.updatedAt.toLocal().toString().substring(0, 16)}',
                            ),
                            onTap: () => _selectProject(item.fileName),
                          ),
                        ),
                      );
                    },
                  ),
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
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: '智能生成对话',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.import_export_rounded),
            tooltip: '导入与导出',
            color: const Color(0xFF1B1D35),
            onSelected: (value) {
              if (value == 'paste') {
                _showImportDialog();
              } else if (value == 'file') {
                _importFromFile();
              } else if (value == 'export_audio' && project != null) {
                _openMergedAudioScreen();
              } else if (value == 'plain_text' && project != null) {
                _openDialogueTextScreen();
              } else if (value == 'export' && project != null) {
                _exportAndShare();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'paste', child: Text('粘贴导入 JSON')),
              const PopupMenuItem(value: 'file', child: Text('从文件/ZIP 导入')),
              if (project != null)
                const PopupMenuItem(value: 'plain_text', child: Text('查看对话全文')),
              if (project != null)
                const PopupMenuItem(value: 'export_audio', child: Text('合并音频')),
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
      body: Stack(
        children: [
          NeonScaffold(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: GlassPanel(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _settings.workspaceCollapsed
                                      ? '灵感对话工作台'
                                      : '多角色播客生成台',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _settings.workspaceCollapsed
                                        ? Colors.white.withValues(alpha: .76)
                                        : Colors.white,
                                    fontSize: _settings.workspaceCollapsed
                                        ? 16
                                        : 22,
                                    fontWeight: FontWeight.w900,
                                  ),
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
                                  _settings.workspaceCollapsed
                                      ? '共 $totalCount 条'
                                      : '$doneCount/$totalCount',
                                  style: const TextStyle(
                                    color: Color(0xFF67E8F9),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: () =>
                                    unawaited(_toggleWorkspaceCollapsed()),
                                icon: AnimatedRotation(
                                  turns: _settings.workspaceCollapsed ? 0 : .5,
                                  duration: const Duration(milliseconds: 220),
                                  child: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                ),
                                tooltip: _settings.workspaceCollapsed
                                    ? '展开工作台'
                                    : '收起工作台',
                              ),
                            ],
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOutCubic,
                            alignment: Alignment.topCenter,
                            child: _settings.workspaceCollapsed
                                ? const SizedBox.shrink()
                                : Column(
                                    children: [
                                      const SizedBox(height: 14),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(99),
                                        child: LinearProgressIndicator(
                                          minHeight: 8,
                                          value:
                                              project == null ||
                                                  project.bubbles.isEmpty
                                              ? 0
                                              : doneCount /
                                                    project.bubbles.length,
                                          backgroundColor: Colors.white
                                              .withValues(alpha: .09),
                                          valueColor:
                                              const AlwaysStoppedAnimation(
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
                                                        ? Icons
                                                              .play_arrow_rounded
                                                        : Icons.pause_rounded)
                                                  : Icons.playlist_play_rounded,
                                            ),
                                            tooltip: _playlistPlaying
                                                ? (_playlistPaused
                                                      ? '继续播放'
                                                      : '暂停播放')
                                                : '播放全部',
                                          ),
                                          if (_playlistPlaying) ...[
                                            const SizedBox(width: 8),
                                            IconButton.filledTonal(
                                              onPressed: _stopPlayAll,
                                              icon: const Icon(
                                                Icons.stop_rounded,
                                              ),
                                              tooltip: '停止播放',
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
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
                        : SlidableAutoCloseBehavior(
                            child: ListView.builder(
                              key: ValueKey(
                                'conversation-${project.fileName ?? identityHashCode(project)}',
                              ),
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                0,
                                14,
                                112,
                              ),
                              itemCount: project.bubbles.length,
                              itemBuilder: (context, index) {
                                final bubble = project.bubbles[index];
                                final key = _bubbleKeys.putIfAbsent(
                                  bubble.id,
                                  GlobalKey.new,
                                );
                                return KeyedSubtree(
                                  key: key,
                                  child: Slidable(
                                    key: ValueKey('slide-${bubble.id}'),
                                    groupTag: 'bubbles',
                                    endActionPane: ActionPane(
                                      extentRatio: .20,
                                      motion: const BehindMotion(),
                                      children: [
                                        SlidableAction(
                                          onPressed: (_) async {
                                            final currentIndex = project.bubbles
                                                .indexWhere(
                                                  (item) =>
                                                      item.id == bubble.id,
                                                );
                                            if (currentIndex < 0) return;
                                            final confirmed =
                                                await _confirmDeleteBubble(
                                                  bubble,
                                                  currentIndex,
                                                );
                                            if (!confirmed || !mounted) return;
                                            _bubbleKeys.remove(bubble.id);
                                            setState(
                                              () => project.bubbles.removeWhere(
                                                (item) => item.id == bubble.id,
                                              ),
                                            );
                                            await _save();
                                          },
                                          backgroundColor: const Color(
                                            0xFFB4233C,
                                          ),
                                          foregroundColor: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          icon: Icons.delete_outline_rounded,
                                          label: '删除',
                                        ),
                                      ],
                                    ),
                                    child: BubbleCard(
                                      bubble: bubble,
                                      viewMode: _settings.conversationViewMode,
                                      sequence: index + 1,
                                      active: bubble.id == _activeBubbleId,
                                      hostAvatarSeed: _settings.hostAvatarSeed,
                                      guestAvatarSeed:
                                          _settings.guestAvatarSeed,
                                      hostAvatarPath: _settings.hostAvatarPath,
                                      guestAvatarPath:
                                          _settings.guestAvatarPath,
                                      onChanged: (value) {
                                        setState(() {
                                          bubble.content = value;
                                          bubble.status = BubbleStatus.idle;
                                          bubble.audioPath = null;
                                          bubble.errorMessage = null;
                                        });
                                        _scheduleEditSave(project);
                                      },
                                      onEditingFinished: () =>
                                          unawaited(_flushPendingEditSave()),
                                      onGenerate: () => _generate(bubble),
                                      onPlay: () => _play(bubble),
                                      onPlayFromHere: () =>
                                          _playAll(startBubbleId: bubble.id),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (_dialogueGenerating)
            _DialogueGeneratingOverlay(progress: _dialogueProgress),
        ],
      ),
      floatingActionButton: project == null || _dialogueGenerating
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

class _DialogueGeneratingOverlay extends StatefulWidget {
  const _DialogueGeneratingOverlay({this.progress});

  final double? progress;

  @override
  State<_DialogueGeneratingOverlay> createState() =>
      _DialogueGeneratingOverlayState();
}

class _DialogueGeneratingOverlayState extends State<_DialogueGeneratingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: ColoredBox(
          color: const Color(0xFF070817).withValues(alpha: .54),
          child: Center(
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: const Color(0xFF111326).withValues(alpha: .84),
                border: Border.all(color: Colors.white.withValues(alpha: .13)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF19D3FF).withValues(alpha: .24),
                    blurRadius: 56,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFF4FD8).withValues(alpha: .2),
                    blurRadius: 38,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => CustomPaint(
                  painter: _DialogueGeneratingPainter(
                    phase: _controller.value,
                    progress: widget.progress,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogueGeneratingPainter extends CustomPainter {
  const _DialogueGeneratingPainter({required this.phase, this.progress});

  final double phase;
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final pulse = .5 + .5 * math.sin(phase * math.pi * 2);
    final glow = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: .12 + pulse * .1)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 13 + pulse * 5);
    canvas.drawCircle(center, 31 + pulse * 4, glow);

    _arc(
      canvas,
      center,
      39,
      phase * math.pi * 2,
      math.pi * 1.05,
      const Color(0xFF19D3FF),
      3.2,
    );
    _arc(
      canvas,
      center,
      48,
      -phase * math.pi * 2.6 + .7,
      math.pi * .68,
      const Color(0xFFFF4FD8),
      2.5,
    );
    _arc(
      canvas,
      center,
      55,
      phase * math.pi * 1.5 + 2.1,
      math.pi * .32,
      Colors.white.withValues(alpha: .7),
      1.5,
    );

    final progressValue = progress;
    if (progressValue != null) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: 59),
        -math.pi / 2,
        math.pi * 2 * progressValue.clamp(0, 1),
        false,
        Paint()
          ..color = const Color(0xFFB6FF5C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(phase * math.pi / 2);
    final diamond = Path()
      ..moveTo(0, -15 - pulse * 2)
      ..lineTo(9 + pulse, 0)
      ..lineTo(0, 15 + pulse * 2)
      ..lineTo(-9 - pulse, 0)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFF19D3FF), Color(0xFFFF4FD8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(-12, -18, 24, 36)),
    );
    canvas.restore();

    for (var i = 0; i < 4; i++) {
      final angle = phase * math.pi * 2 + i * math.pi / 2;
      final radius = 25 + (i.isEven ? pulse * 4 : (1 - pulse) * 4);
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        1.4 + pulse,
        Paint()..color = Colors.white.withValues(alpha: .55 + pulse * .35),
      );
    }
  }

  void _arc(
    Canvas canvas,
    Offset center,
    double radius,
    double start,
    double sweep,
    Color color,
    double width,
  ) {
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DialogueGeneratingPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.progress != progress;
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
