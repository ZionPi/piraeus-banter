import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/conversation_view_mode.dart';
import '../models/dialog_style.dart';
import '../models/project.dart';
import '../models/voice_preset.dart';
import '../services/dialog_style_repository.dart';
import '../services/gemini_dialogue_service.dart';
import '../services/voice_preset_repository.dart';
import '../widgets/app_chrome.dart';
import '../widgets/role_avatar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings, this.project});

  final AppSettings settings;
  final BanterProject? project;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _voiceRepository = VoicePresetRepository();
  final _styleRepository = DialogStyleRepository();
  late final TextEditingController _hostName;
  late final TextEditingController _guestName;
  late final TextEditingController _appKey;
  late final TextEditingController _token;
  late final TextEditingController _geminiApiKey;
  late String _geminiModel;
  late double _playbackSpeed;
  late bool _skipBlankOnPlayback;
  late String _hostVoiceId;
  late String _guestVoiceId;
  late String _dialogStyleId;
  late ConversationViewMode _conversationViewMode;
  late int _hostAvatarSeed;
  late int _guestAvatarSeed;
  late String _hostAvatarPath;
  late String _guestAvatarPath;
  List<VoicePreset> _voices = const [];
  List<DialogStyle> _styles = const [];
  bool _loadingVoices = true;
  bool _loadingStyles = true;
  bool _showGeminiApiKey = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _hostName = TextEditingController(text: settings.hostName);
    _guestName = TextEditingController(text: settings.guestName);
    _hostVoiceId = settings.hostVoiceId;
    _guestVoiceId = settings.guestVoiceId;
    _appKey = TextEditingController(text: settings.appKey);
    _token = TextEditingController(text: settings.accessToken);
    _geminiApiKey = TextEditingController(text: settings.geminiApiKey);
    _geminiModel = settings.geminiModel;
    _playbackSpeed = settings.playbackSpeed;
    _skipBlankOnPlayback = settings.skipBlankOnPlayback;
    _dialogStyleId = settings.dialogStyleId;
    _conversationViewMode = settings.conversationViewMode;
    _hostAvatarSeed = settings.hostAvatarSeed;
    _guestAvatarSeed = settings.guestAvatarSeed;
    _hostAvatarPath = settings.hostAvatarPath;
    _guestAvatarPath = settings.guestAvatarPath;
    _loadVoices();
    _loadStyles();
  }

  Future<void> _loadVoices() async {
    final voices = await _voiceRepository.load();
    if (!mounted) return;
    setState(() {
      _voices = voices;
      _loadingVoices = false;
    });
  }

  Future<void> _loadStyles() async {
    final styles = await _styleRepository.load();
    if (!mounted) return;
    setState(() {
      _styles = styles;
      _loadingStyles = false;
    });
  }

  Future<void> _createCustomStyle() async {
    final name = TextEditingController();
    final systemInstruction = TextEditingController();
    final userPrompt = TextEditingController(text: '输出中文。围绕输入主题生成双人对话。');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建风格'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '风格名称'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: systemInstruction,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: '系统提示词',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userPrompt,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: '用户提示词',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    final style = DialogStyle(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      name: name.text.trim(),
      description: '自定义风格',
      systemInstruction: systemInstruction.text.trim(),
      userPrompt: userPrompt.text.trim(),
      builtIn: false,
    );
    await _styleRepository.saveUserStyle(style);
    await _loadStyles();
    setState(() => _dialogStyleId = style.id);
  }

  @override
  void dispose() {
    _hostName.dispose();
    _guestName.dispose();
    _appKey.dispose();
    _token.dispose();
    _geminiApiKey.dispose();
    super.dispose();
  }

  String _voiceName(String id) {
    return _voices
            .where((voice) => voice.id == id)
            .map((voice) => voice.name)
            .firstOrNull ??
        id;
  }

  Future<void> _pickVoice({required bool host}) async {
    if (_loadingVoices) return;
    final selectedId = host ? _hostVoiceId : _guestVoiceId;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _VoicePickerSheet(
        title: host ? '选择主持人声音' : '选择嘉宾声音',
        voices: _voices,
        selectedId: selectedId,
      ),
    );
    if (result == null) return;
    setState(() {
      if (host) {
        _hostVoiceId = result;
      } else {
        _guestVoiceId = result;
      }
    });
  }

  void _randomizeAvatar({required bool host}) {
    var seed = AppSettings.newAvatarSeed();
    final otherSeed = host ? _guestAvatarSeed : _hostAvatarSeed;
    while (seed == otherSeed) {
      seed = AppSettings.newAvatarSeed();
    }
    setState(() {
      if (host) {
        _hostAvatarSeed = seed;
        _hostAvatarPath = '';
      } else {
        _guestAvatarSeed = seed;
        _guestAvatarPath = '';
      }
    });
  }

  Future<void> _pickAvatarImage({required bool host}) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final sourcePath = result?.files.single.path;
    if (sourcePath == null || sourcePath.isEmpty) return;
    final source = File(sourcePath);
    if (!await source.exists()) return;
    final documents = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${documents.path}/piraeus_banter/avatars');
    if (!await avatarDir.exists()) await avatarDir.create(recursive: true);
    final extension = result!.files.single.extension?.toLowerCase() ?? 'img';
    final role = host ? 'host' : 'guest';
    final target = File(
      '${avatarDir.path}/${role}_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    await source.copy(target.path);
    if (!mounted) return;
    setState(() {
      if (host) {
        _hostAvatarPath = target.path;
      } else {
        _guestAvatarPath = target.path;
      }
    });
  }

  Future<void> _editAvatar({required bool host}) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.casino_rounded),
              title: const Text('随机换一个'),
              onTap: () => Navigator.pop(context, 'random'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
          ],
        ),
      ),
    );
    if (action == 'random') {
      _randomizeAvatar(host: host);
    } else if (action == 'image') {
      await _pickAvatarImage(host: host);
    }
  }

  void _saveAndClose() {
    final settings = widget.settings;
    final hostVoiceChanged = settings.hostVoiceId != _hostVoiceId;
    final guestVoiceChanged = settings.guestVoiceId != _guestVoiceId;
    settings.hostName = _hostName.text.trim().isEmpty
        ? settings.hostName
        : _hostName.text.trim();
    settings.guestName = _guestName.text.trim().isEmpty
        ? settings.guestName
        : _guestName.text.trim();
    settings.hostVoiceId = _hostVoiceId;
    settings.guestVoiceId = _guestVoiceId;
    settings.appKey = _appKey.text.trim();
    settings.accessToken = _token.text.trim();
    settings.geminiApiKey = _geminiApiKey.text.trim();
    settings.geminiModel =
        GeminiDialogueService.supportedModels.contains(_geminiModel)
        ? _geminiModel
        : GeminiDialogueService.defaultModel;
    settings.playbackSpeed = _playbackSpeed;
    settings.skipBlankOnPlayback = _skipBlankOnPlayback;
    settings.dialogStyleId = _dialogStyleId;
    settings.conversationViewMode = _conversationViewMode;
    settings.hostAvatarSeed = _hostAvatarSeed;
    settings.guestAvatarSeed = _guestAvatarSeed;
    settings.hostAvatarPath = _hostAvatarPath;
    settings.guestAvatarPath = _guestAvatarPath;
    final project = widget.project;
    if (project != null) {
      settings.applyNamesTo(project);
      for (final bubble in project.bubbles) {
        final shouldReset =
            (hostVoiceChanged && bubble.role == BubbleRole.host) ||
            (guestVoiceChanged && bubble.role == BubbleRole.guest);
        if (!shouldReset) continue;
        bubble.status = BubbleStatus.idle;
        bubble.audioPath = null;
        bubble.errorMessage = null;
      }
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('声音与密钥'),
        actions: [
          IconButton(
            onPressed: _saveAndClose,
            icon: const Icon(Icons.save_rounded),
            tooltip: '保存设置',
          ),
        ],
      ),
      body: NeonScaffold(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
            children: [
              GlassPanel(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '角色声音',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .56),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '为角色挑选声音演员',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _RoleIdentityEditor(
                      label: '主持人',
                      controller: _hostName,
                      avatarSeed: _hostAvatarSeed,
                      avatarPath: _hostAvatarPath,
                      onEditAvatar: () => _editAvatar(host: true),
                    ),
                    const SizedBox(height: 12),
                    _VoiceSelectorTile(
                      label: '主持人声音',
                      name: _loadingVoices
                          ? '加载中...'
                          : _voiceName(_hostVoiceId),
                      id: _hostVoiceId,
                      hot: true,
                      onTap: () => _pickVoice(host: true),
                    ),
                    const SizedBox(height: 18),
                    _RoleIdentityEditor(
                      label: '嘉宾',
                      controller: _guestName,
                      avatarSeed: _guestAvatarSeed,
                      avatarPath: _guestAvatarPath,
                      onEditAvatar: () => _editAvatar(host: false),
                    ),
                    const SizedBox(height: 12),
                    _VoiceSelectorTile(
                      label: '嘉宾声音',
                      name: _loadingVoices
                          ? '加载中...'
                          : _voiceName(_guestVoiceId),
                      id: _guestVoiceId,
                      hot: false,
                      onTap: () => _pickVoice(host: false),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '头像风格灵感：Ugly Avatar · txstc55 · CC BY-NC 4.0',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .42),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassPanel(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.view_stream_rounded,
                          color: Color(0xFF67E8F9),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '显示样式',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final mode in ConversationViewMode.values)
                          ChoiceChip(
                            selected: _conversationViewMode == mode,
                            avatar: Icon(
                              mode == ConversationViewMode.chat
                                  ? Icons.chat_bubble_outline_rounded
                                  : Icons.dashboard_customize_rounded,
                              size: 18,
                            ),
                            label: Text(mode.label),
                            onSelected: (_) {
                              setState(() => _conversationViewMode = mode);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _conversationViewMode.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .56),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassPanel(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFFFF4FD8),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '对话生成',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _geminiApiKey,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Gemini API 密钥',
                        prefixIcon: const Icon(Icons.api_rounded),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => setState(
                                () => _showGeminiApiKey = !_showGeminiApiKey,
                              ),
                              icon: Icon(
                                _showGeminiApiKey
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                              tooltip: _showGeminiApiKey ? '隐藏密钥' : '显示密钥',
                            ),
                            IconButton(
                              onPressed: _geminiApiKey.clear,
                              icon: const Icon(Icons.close_rounded),
                              tooltip: '清空密钥',
                            ),
                          ],
                        ),
                      ),
                      obscureText: !_showGeminiApiKey,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue:
                          GeminiDialogueService.supportedModels.contains(
                            _geminiModel,
                          )
                          ? _geminiModel
                          : GeminiDialogueService.defaultModel,
                      decoration: const InputDecoration(
                        labelText: 'Gemini 模型',
                        prefixIcon: Icon(Icons.memory_rounded),
                      ),
                      items: GeminiDialogueService.supportedModels
                          .map(
                            (model) => DropdownMenuItem(
                              value: model,
                              child: Text(model),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _geminiModel = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue:
                                _styles.any(
                                  (style) => style.id == _dialogStyleId,
                                )
                                ? _dialogStyleId
                                : null,
                            decoration: const InputDecoration(
                              labelText: '默认对话风格',
                              prefixIcon: Icon(Icons.style_rounded),
                            ),
                            items: _styles
                                .map(
                                  (style) => DropdownMenuItem(
                                    value: style.id,
                                    child: Text(
                                      style.builtIn
                                          ? style.name
                                          : '${style.name}（自定义）',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _loadingStyles
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() => _dialogStyleId = value);
                                  },
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          onPressed: _createCustomStyle,
                          icon: const Icon(Icons.add_rounded),
                          tooltip: '新建风格',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassPanel(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.key_rounded, color: Color(0xFF22D3EE)),
                        const SizedBox(width: 8),
                        const Text(
                          '语音生成密钥',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _appKey,
                      decoration: const InputDecoration(
                        labelText: '字节跳动 AppKey',
                        prefixIcon: Icon(Icons.vpn_key_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _token,
                      decoration: const InputDecoration(
                        labelText: '访问令牌（保留字段）',
                        prefixIcon: Icon(Icons.lock_outline_rounded),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    _PlaybackSpeedPicker(
                      value: _playbackSpeed,
                      onChanged: (value) {
                        setState(() => _playbackSpeed = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.skip_next_rounded),
                      title: const Text('跳过空白'),
                      subtitle: const Text('播放全部时跳过没有可朗读内容或没有音频的条目'),
                      value: _skipBlankOnPlayback,
                      onChanged: (value) {
                        setState(() => _skipBlankOnPlayback = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '生成音频时会使用当前角色选中的声音 ID 与这里填写的 AppKey；播放速度只影响收听。',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .56),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleIdentityEditor extends StatelessWidget {
  const _RoleIdentityEditor({
    required this.label,
    required this.controller,
    required this.avatarSeed,
    required this.avatarPath,
    required this.onEditAvatar,
  });

  final String label;
  final TextEditingController controller;
  final int avatarSeed;
  final String avatarPath;
  final VoidCallback onEditAvatar;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onEditAvatar,
          tooltip: '修改$label头像',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 68, height: 68),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              RoleAvatar(seed: avatarSeed, imagePath: avatarPath, size: 62),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF17182D),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: '$label名称'),
          ),
        ),
      ],
    );
  }
}

class _VoiceSelectorTile extends StatelessWidget {
  const _VoiceSelectorTile({
    required this.label,
    required this.name,
    required this.id,
    required this.hot,
    required this.onTap,
  });

  final String label;
  final String name;
  final String id;
  final bool hot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = hot
        ? const [Color(0xFFFF4FD8), Color(0xFF8B5CF6)]
        : const [Color(0xFF22D3EE), Color(0xFF4F46E5)];
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              colors.first.withValues(alpha: .24),
              Colors.white.withValues(alpha: .06),
            ],
          ),
          border: Border.all(color: colors.first.withValues(alpha: .34)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: colors),
              ),
              child: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .58),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .45),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

class _VoicePickerSheet extends StatefulWidget {
  const _VoicePickerSheet({
    required this.title,
    required this.voices,
    required this.selectedId,
  });

  final String title;
  final List<VoicePreset> voices;
  final String selectedId;

  @override
  State<_VoicePickerSheet> createState() => _VoicePickerSheetState();
}

class _PlaybackSpeedPicker extends StatelessWidget {
  const _PlaybackSpeedPicker({required this.value, required this.onChanged});

  static const speeds = [0.5, 1.0, 1.25, 1.5, 1.75, 2.0, 4.0];

  final double value;
  final ValueChanged<double> onChanged;

  String _label(double speed) {
    if (speed == speed.roundToDouble()) return '${speed.toInt()}x';
    return '${speed}x';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Icon(Icons.speed_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '播放速度：${_label(value)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final speed in speeds)
                    ChoiceChip(
                      label: Text(_label(speed)),
                      selected: (value - speed).abs() < .01,
                      onSelected: (_) => onChanged(speed),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VoicePickerSheetState extends State<_VoicePickerSheet> {
  final _search = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voices = widget.voices
        .where(
          (voice) =>
              voice.name.toLowerCase().contains(_keyword.toLowerCase()) ||
              voice.id.toLowerCase().contains(_keyword.toLowerCase()),
        )
        .toList();
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF101126),
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.84,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.spatial_audio_off_rounded,
                          color: Color(0xFFFF4FD8),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: '搜索声音名称或 ID，例如：温柔、粤语、男声',
                      ),
                      onChanged: (value) => setState(() => _keyword = value),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 104,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: voices.length,
                  itemBuilder: (context, index) {
                    final voice = voices[index];
                    final selected = voice.id == widget.selectedId;
                    return InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => Navigator.pop(context, voice.id),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: selected
                              ? const Color(0xFF8B5CF6).withValues(alpha: .28)
                              : Colors.white.withValues(alpha: .06),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFFFF4FD8)
                                : Colors.white.withValues(alpha: .10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.record_voice_over_rounded,
                              color: selected
                                  ? const Color(0xFFFF4FD8)
                                  : const Color(0xFF22D3EE),
                            ),
                            const Spacer(),
                            Text(
                              voice.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              voice.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: .48),
                              ),
                            ),
                          ],
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
    );
  }
}
