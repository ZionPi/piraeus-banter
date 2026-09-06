import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_settings.dart';
import '../models/project.dart';
import '../services/audio_player.dart';
import '../services/project_repository.dart';
import '../widgets/app_chrome.dart';

class MergedAudioScreen extends StatefulWidget {
  const MergedAudioScreen({
    super.key,
    required this.project,
    required this.settings,
  });

  final BanterProject project;
  final AppSettings settings;

  @override
  State<MergedAudioScreen> createState() => _MergedAudioScreenState();
}

class _MergedAudioScreenState extends State<MergedAudioScreen> {
  static const _exportSpeeds = <double>[0.5, 1, 1.25, 1.5, 1.75, 2, 4];

  final _repository = ProjectRepository();
  final _audioPlayer = NativeAudioPlayer();

  List<MergedAudioExport> _items = const [];
  bool _loading = true;
  bool _merging = false;
  String? _playingPath;
  bool _playbackPaused = false;
  Timer? _playbackTimer;
  Duration _playbackRemaining = Duration.zero;
  DateTime? _playbackStartedAt;
  late double _exportSpeed;

  @override
  void initState() {
    super.initState();
    _exportSpeed = _exportSpeeds.contains(widget.settings.playbackSpeed)
        ? widget.settings.playbackSpeed
        : 1.0;
    _load();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _audioPlayer.stop();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _repository.listMergedAudioExports();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _mergeCurrentProject() async {
    if (_merging) return;
    setState(() => _merging = true);
    String? outputPath;
    try {
      final paths = await _repository.mergedAudioInputPaths(
        widget.project,
        skipBlank: widget.settings.skipBlankOnPlayback,
      );
      outputPath = await _repository.mergedAudioOutputPath(
        widget.project,
        speed: _exportSpeed,
      );
      await _audioPlayer.merge(paths, outputPath, speed: _exportSpeed);
      await _load();
    } catch (error) {
      if (outputPath != null) {
        try {
          await _repository.deleteMergedAudioExport(outputPath);
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('合成失败：$error')));
    } finally {
      if (mounted) setState(() => _merging = false);
    }
  }

  Future<void> _togglePlay(MergedAudioExport item) async {
    if (_playingPath == item.path) {
      if (_playbackPaused) {
        await _audioPlayer.resume();
        _startCompletionTimer();
        if (mounted) setState(() => _playbackPaused = false);
      } else {
        await _audioPlayer.pause();
        _pauseCompletionTimer();
        if (mounted) setState(() => _playbackPaused = true);
      }
      return;
    }
    await _stopPlayback();
    final duration = await _audioPlayer.duration(item.path);
    await _audioPlayer.play(item.path);
    _playbackRemaining = duration;
    _startCompletionTimer();
    if (mounted) {
      setState(() {
        _playingPath = item.path;
        _playbackPaused = false;
      });
    }
  }

  Future<void> _stopPlayback() async {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _playbackRemaining = Duration.zero;
    _playbackStartedAt = null;
    await _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _playingPath = null;
        _playbackPaused = false;
      });
    }
  }

  void _startCompletionTimer() {
    _playbackTimer?.cancel();
    _playbackStartedAt = DateTime.now();
    if (_playbackRemaining <= Duration.zero) return;
    _playbackTimer = Timer(_playbackRemaining, () {
      if (!mounted) return;
      setState(() {
        _playingPath = null;
        _playbackPaused = false;
      });
      _playbackRemaining = Duration.zero;
      _playbackStartedAt = null;
    });
  }

  void _pauseCompletionTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    final startedAt = _playbackStartedAt;
    if (startedAt != null) {
      _playbackRemaining -= DateTime.now().difference(startedAt);
      if (_playbackRemaining.isNegative) {
        _playbackRemaining = Duration.zero;
      }
    }
    _playbackStartedAt = null;
  }

  Future<void> _delete(MergedAudioExport item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除合并音频？'),
        content: Text('确定删除「${item.name}」吗？删除后无法恢复。'),
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
    if (confirmed != true) return;
    if (_playingPath == item.path) await _stopPlayback();
    try {
      await _repository.deleteMergedAudioExport(item.path);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
    }
  }

  Future<void> _share(MergedAudioExport item) async {
    await Share.shareXFiles([XFile(item.path)], text: '泊睿妙语合成音频');
  }

  String _sizeLabel(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('合并音频')),
      body: Stack(
        children: [
          NeonScaffold(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '导出速度',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .68),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _exportSpeeds.map((speed) {
                              final selected = _exportSpeed == speed;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text('${speed}x'),
                                  selected: selected,
                                  onSelected: _merging
                                      ? null
                                      : (_) => setState(
                                          () => _exportSpeed = speed,
                                        ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _merging ? null : _mergeCurrentProject,
                          icon: const Icon(Icons.graphic_eq_rounded),
                          label: Text('按 ${_exportSpeed}x 合成当前项目'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _items.isEmpty
                        ? const Center(
                            child: Text(
                              '还没有合并音频',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          )
                        : SlidableAutoCloseBehavior(
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: _items.length,
                              separatorBuilder: (_, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                final playing = _playingPath == item.path;
                                return Slidable(
                                  key: ValueKey(item.path),
                                  groupTag: 'merged-audio',
                                  endActionPane: ActionPane(
                                    extentRatio: .22,
                                    motion: const BehindMotion(),
                                    children: [
                                      SlidableAction(
                                        onPressed: (_) => _delete(item),
                                        backgroundColor: const Color(
                                          0xFFB4233C,
                                        ),
                                        foregroundColor: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        icon: Icons.delete_outline_rounded,
                                        label: '删除',
                                      ),
                                    ],
                                  ),
                                  child: GlassPanel(
                                    radius: 22,
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        IconButton.filledTonal(
                                          onPressed: () => _togglePlay(item),
                                          icon: Icon(
                                            playing && !_playbackPaused
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                          ),
                                          tooltip: playing && !_playbackPaused
                                              ? '暂停'
                                              : playing
                                              ? '继续'
                                              : '试听',
                                        ),
                                        if (playing) ...[
                                          const SizedBox(width: 4),
                                          IconButton(
                                            onPressed: _stopPlayback,
                                            icon: const Icon(
                                              Icons.stop_rounded,
                                            ),
                                            tooltip: '停止',
                                          ),
                                        ],
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${_sizeLabel(item.bytes)} · ${item.createdAt.toLocal().toString().substring(0, 16)}',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: .56),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => _share(item),
                                          icon: const Icon(
                                            Icons.ios_share_rounded,
                                          ),
                                          tooltip: '分享',
                                        ),
                                      ],
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
          if (_merging) const _MergingOverlay(),
        ],
      ),
    );
  }
}

class _MergingOverlay extends StatelessWidget {
  const _MergingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: ColoredBox(
          color: const Color(0xFF070817).withValues(alpha: .50),
          child: Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: const Color(0xFF15162A).withValues(alpha: .72),
                border: Border.all(color: Colors.white.withValues(alpha: .16)),
              ),
              child: const Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
