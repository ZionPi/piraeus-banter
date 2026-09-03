import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/dialog_style.dart';
import '../models/project.dart';
import '../models/voice_preset.dart';
import '../services/dialog_style_repository.dart';
import '../services/gemini_dialogue_service.dart';
import '../services/voice_preset_repository.dart';
import '../widgets/app_chrome.dart';

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
  late String _hostVoiceId;
  late String _guestVoiceId;
  late String _dialogStyleId;
  List<VoicePreset> _voices = const [];
  List<DialogStyle> _styles = const [];
  bool _loadingVoices = true;
  bool _loadingStyles = true;

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
    _dialogStyleId = settings.dialogStyleId;
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

  void _saveAndClose() {
    final settings = widget.settings;
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
    settings.dialogStyleId = _dialogStyleId;
    final project = widget.project;
    if (project != null) settings.applyNamesTo(project);
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
                    TextField(
                      controller: _hostName,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.mic_rounded),
                        labelText: '主持人名称',
                      ),
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
                    TextField(
                      controller: _guestName,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_rounded),
                        labelText: '嘉宾名称',
                      ),
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
                      decoration: const InputDecoration(
                        labelText: 'Gemini API 密钥',
                        prefixIcon: Icon(Icons.api_rounded),
                      ),
                      obscureText: true,
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
                    Text(
                      '生成音频时会使用当前角色选中的声音 ID 与这里填写的 AppKey。',
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
