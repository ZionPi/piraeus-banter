import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/voice_preset.dart';
import '../services/voice_preset_repository.dart';
import '../widgets/app_chrome.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.project});

  final BanterProject project;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _voiceRepository = VoicePresetRepository();
  late final TextEditingController _hostName;
  late final TextEditingController _guestName;
  late final TextEditingController _appKey;
  late final TextEditingController _token;
  late String _hostVoiceId;
  late String _guestVoiceId;
  List<VoicePreset> _voices = const [];
  bool _loadingVoices = true;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    _hostName = TextEditingController(text: project.hostName);
    _guestName = TextEditingController(text: project.guestName);
    _hostVoiceId = project.hostVoiceId;
    _guestVoiceId = project.guestVoiceId;
    _appKey = TextEditingController(text: project.appKey);
    _token = TextEditingController(text: project.accessToken);
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final voices = await _voiceRepository.load();
    if (!mounted) return;
    setState(() {
      _voices = voices;
      _loadingVoices = false;
    });
  }

  @override
  void dispose() {
    _hostName.dispose();
    _guestName.dispose();
    _appKey.dispose();
    _token.dispose();
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
    final project = widget.project;
    project.hostName = _hostName.text.trim().isEmpty
        ? project.hostName
        : _hostName.text.trim();
    project.guestName = _guestName.text.trim().isEmpty
        ? project.guestName
        : _guestName.text.trim();
    project.hostVoiceId = _hostVoiceId;
    project.guestVoiceId = _guestVoiceId;
    project.appKey = _appKey.text.trim();
    project.accessToken = _token.text.trim();
    for (final bubble in project.bubbles) {
      bubble.name = bubble.role == BubbleRole.host
          ? project.hostName
          : project.guestName;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('声音与密钥')),
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
                      'Voice Casting',
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
                        const Icon(Icons.key_rounded, color: Color(0xFF22D3EE)),
                        const SizedBox(width: 8),
                        const Text(
                          'Sami TTS Credentials',
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
                        labelText: 'ByteDance AppKey',
                        prefixIcon: Icon(Icons.vpn_key_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _token,
                      decoration: const InputDecoration(
                        labelText: 'Access Token（保留字段）',
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
              const SizedBox(height: 22),
              GradientButton(
                onPressed: _saveAndClose,
                icon: Icons.save_rounded,
                label: '保存设置',
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
