import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/conversation_view_mode.dart';
import '../models/project.dart';
import 'app_chrome.dart';
import 'role_avatar.dart';

class BubbleCard extends StatefulWidget {
  const BubbleCard({
    super.key,
    required this.bubble,
    required this.onChanged,
    required this.onEditingFinished,
    required this.onGenerate,
    required this.onPlay,
    required this.onPlayFromHere,
    this.viewMode = ConversationViewMode.chat,
    this.active = false,
    this.sequence,
    this.hostAvatarSeed = 1,
    this.guestAvatarSeed = 2,
    this.hostAvatarPath = '',
    this.guestAvatarPath = '',
  });

  final DialogueBubble bubble;
  final ValueChanged<String> onChanged;
  final VoidCallback onEditingFinished;
  final VoidCallback onGenerate;
  final VoidCallback onPlay;
  final VoidCallback onPlayFromHere;
  final ConversationViewMode viewMode;
  final bool active;
  final int? sequence;
  final int hostAvatarSeed;
  final int guestAvatarSeed;
  final String hostAvatarPath;
  final String guestAvatarPath;

  @override
  State<BubbleCard> createState() => _BubbleCardState();
}

class _BubbleCardState extends State<BubbleCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.bubble.content);
  }

  @override
  void didUpdateWidget(covariant BubbleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.bubble.content) {
      _controller.value = TextEditingValue(
        text: widget.bubble.content,
        selection: TextSelection.collapsed(
          offset: widget.bubble.content.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.viewMode) {
      ConversationViewMode.chat => _buildChatView(context),
      ConversationViewMode.card => _buildCardView(context),
    };
  }

  Widget _buildChatView(BuildContext context) {
    final bubble = widget.bubble;
    final isHost = bubble.role == BubbleRole.host;
    final accent = isHost ? const Color(0xFFFF4FD8) : const Color(0xFF22D3EE);
    final bubbleMaxWidth = (MediaQuery.sizeOf(context).width * .70)
        .clamp(210.0, 520.0)
        .toDouble();
    final radius = BorderRadius.only(
      topLeft: Radius.circular(isHost ? 16 : 5),
      topRight: Radius.circular(isHost ? 5 : 16),
      bottomLeft: const Radius.circular(16),
      bottomRight: const Radius.circular(16),
    );
    final avatar = RoleAvatar(
      seed: isHost ? widget.hostAvatarSeed : widget.guestAvatarSeed,
      imagePath: isHost ? widget.hostAvatarPath : widget.guestAvatarPath,
      size: 36,
    );
    final message = Column(
      crossAxisAlignment: isHost
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isHost && widget.sequence != null) ...[
                _PlaybackSequence(
                  text: '#${widget.sequence}',
                  active: widget.active,
                  color: accent,
                  style: _sequenceStyle(),
                ),
                const SizedBox(width: 6),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: bubbleMaxWidth - 42),
                child: Text(
                  bubble.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .58),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isHost && widget.sequence != null) ...[
                const SizedBox(width: 6),
                _PlaybackSequence(
                  text: '#${widget.sequence}',
                  active: widget.active,
                  color: accent,
                  style: _sequenceStyle(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 5),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: radius,
              color: isHost ? const Color(0xFF4A2555) : const Color(0xFF17313B),
              border: Border.all(
                color: widget.active
                    ? accent.withValues(alpha: .82)
                    : Colors.white.withValues(alpha: .08),
                width: widget.active ? 1.5 : 1,
              ),
              boxShadow: widget.active
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: .18),
                        blurRadius: 18,
                      ),
                    ]
                  : null,
            ),
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: null,
              onChanged: widget.onChanged,
              onTapOutside: (_) {
                widget.onEditingFinished();
                FocusScope.of(context).unfocus();
              },
              style: const TextStyle(fontSize: 16, height: 1.5),
              decoration: InputDecoration(
                hintText: '输入对话内容...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: .34),
                ),
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _ChatActions(
          isHost: isHost,
          accent: accent,
          status: bubble.status,
          errorMessage: bubble.errorMessage,
          onGenerate: widget.onGenerate,
          onPlay: widget.onPlay,
          onPlayFromHere: widget.onPlayFromHere,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Row(
        mainAxisAlignment: isHost
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isHost
            ? [Flexible(child: message), const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), Flexible(child: message)],
      ),
    );
  }

  TextStyle _sequenceStyle() => TextStyle(
    color: Colors.white.withValues(alpha: .32),
    fontSize: 10,
    fontWeight: FontWeight.w700,
  );

  Widget _buildCardView(BuildContext context) {
    final bubble = widget.bubble;
    final isHost = bubble.role == BubbleRole.host;
    final accent = isHost ? const Color(0xFFFF4FD8) : const Color(0xFF22D3EE);
    final gradient = isHost
        ? const [Color(0xFFFF4FD8), Color(0xFF8B5CF6)]
        : const [Color(0xFF22D3EE), Color(0xFF4F46E5)];
    final status = _statusView(context, accent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Align(
        alignment: isHost ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: .32),
                  Colors.white.withValues(alpha: .07),
                ],
              ),
              border: Border.all(
                color: widget.active
                    ? Colors.white
                    : accent.withValues(alpha: .45),
                width: widget.active ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: widget.active ? .32 : .16),
                  blurRadius: widget.active ? 38 : 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(1),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(29),
                color: const Color(0xFF111226).withValues(alpha: .90),
              ),
              child: Stack(
                children: [
                  if (widget.sequence != null)
                    Positioned(
                      right: -4,
                      bottom: -20,
                      child: IgnorePointer(
                        child: _PlaybackSequence(
                          text: '${widget.sequence}',
                          active: widget.active,
                          color: accent,
                          style: TextStyle(
                            color: accent.withValues(
                              alpha: widget.active ? .14 : .08,
                            ),
                            fontSize: 112,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  Column(
                    children: [
                      Row(
                        children: [
                          RoleAvatar(
                            seed: isHost
                                ? widget.hostAvatarSeed
                                : widget.guestAvatarSeed,
                            imagePath: isHost
                                ? widget.hostAvatarPath
                                : widget.guestAvatarPath,
                            size: 42,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bubble.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  bubble.role.displayName,
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _RoleBadge(role: bubble.role, accent: accent),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _controller,
                        minLines: 2,
                        maxLines: 8,
                        onChanged: widget.onChanged,
                        onTapOutside: (_) {
                          widget.onEditingFinished();
                          FocusScope.of(context).unfocus();
                        },
                        style: const TextStyle(fontSize: 16, height: 1.45),
                        decoration: InputDecoration(
                          hintText: '输入对话内容...',
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: .20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ?status,
                      _ActionButtons(
                        gradient: gradient,
                        onGenerate: widget.onGenerate,
                        onPlay: widget.onPlay,
                        onPlayFromHere: widget.onPlayFromHere,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _statusView(BuildContext context, Color accent) {
    final bubble = widget.bubble;
    switch (bubble.status) {
      case BubbleStatus.loading:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassPanel(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('AI 正在生成声波...'),
              ],
            ),
          ),
        );
      case BubbleStatus.success:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF22C55E),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '音频已就绪',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .66),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      case BubbleStatus.error:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            bubble.errorMessage ?? '生成失败',
            style: const TextStyle(
              color: Color(0xFFFF6B8A),
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case BubbleStatus.idle:
        return null;
    }
  }
}

class _PlaybackSequence extends StatefulWidget {
  const _PlaybackSequence({
    required this.text,
    required this.active,
    required this.color,
    required this.style,
  });

  final String text;
  final bool active;
  final Color color;
  final TextStyle style;

  @override
  State<_PlaybackSequence> createState() => _PlaybackSequenceState();
}

class _PlaybackSequenceState extends State<_PlaybackSequence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PlaybackSequence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (widget.active) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = Curves.easeInOut.transform(_controller.value);
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (widget.active)
              Positioned.fill(
                left: -7,
                right: -7,
                top: -4,
                bottom: -4,
                child: Transform.scale(
                  scale: .92 + pulse * .22,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: 5 + pulse * 7,
                      sigmaY: 5 + pulse * 7,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.color.withValues(
                          alpha: .28 + pulse * .30,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            Text(
              widget.text,
              style: widget.style.copyWith(
                color: widget.active
                    ? widget.color.withValues(alpha: 1)
                    : widget.style.color,
                shadows: widget.active
                    ? [
                        Shadow(
                          color: widget.color.withValues(alpha: .75),
                          blurRadius: 5,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.accent});

  final BubbleRole role;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: accent.withValues(alpha: .12),
        border: Border.all(color: accent.withValues(alpha: .36)),
      ),
      child: Text(
        role.displayName,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ChatActions extends StatelessWidget {
  const _ChatActions({
    required this.isHost,
    required this.accent,
    required this.status,
    required this.errorMessage,
    required this.onGenerate,
    required this.onPlay,
    required this.onPlayFromHere,
  });

  final bool isHost;
  final Color accent;
  final BubbleStatus status;
  final String? errorMessage;
  final VoidCallback onGenerate;
  final VoidCallback onPlay;
  final VoidCallback onPlayFromHere;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      _ChatActionButton(
        tooltip: status == BubbleStatus.success ? '重新生成音频' : '生成音频',
        icon: Icons.auto_awesome_rounded,
        onTap: onGenerate,
      ),
      _ChatActionButton(
        tooltip: '试听这一条',
        icon: Icons.play_arrow_rounded,
        onTap: onPlay,
      ),
      _ChatActionButton(
        tooltip: '从这一条开始播放',
        icon: Icons.playlist_play_rounded,
        onTap: onPlayFromHere,
      ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isHost) ...[
          _statusIndicator(),
          const SizedBox(width: 4),
          ...actions,
        ] else ...[
          ...actions,
          const SizedBox(width: 4),
          _statusIndicator(),
        ],
      ],
    );
  }

  Widget _statusIndicator() {
    return switch (status) {
      BubbleStatus.loading => SizedBox(
        width: 28,
        height: 28,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: CircularProgressIndicator(strokeWidth: 2, color: accent),
        ),
      ),
      BubbleStatus.success => const Tooltip(
        message: '音频已就绪',
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: Color(0xFF22C55E),
          ),
        ),
      ),
      BubbleStatus.error => Tooltip(
        message: errorMessage ?? '生成失败',
        child: const SizedBox(
          width: 28,
          height: 28,
          child: Icon(Icons.error_rounded, size: 17, color: Color(0xFFFF6B8A)),
        ),
      ),
      BubbleStatus.idle => const SizedBox(width: 4, height: 28),
    };
  }
}

class _ChatActionButton extends StatelessWidget {
  const _ChatActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon),
        iconSize: 19,
        color: Colors.white.withValues(alpha: .68),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        padding: EdgeInsets.zero,
        splashRadius: 18,
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.gradient,
    required this.onGenerate,
    required this.onPlay,
    required this.onPlayFromHere,
  });

  final List<Color> gradient;
  final VoidCallback onGenerate;
  final VoidCallback onPlay;
  final VoidCallback onPlayFromHere;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ActionChipButton(
          label: '生成',
          icon: Icons.auto_awesome_rounded,
          colors: gradient,
          onTap: onGenerate,
        ),
        _ActionChipButton(
          label: '试听',
          icon: Icons.play_arrow_rounded,
          colors: const [Color(0xFF22C55E), Color(0xFF14B8A6)],
          onTap: onPlay,
        ),
        _ActionChipButton(
          label: '从此播放',
          icon: Icons.playlist_play_rounded,
          colors: const [Color(0xFFF59E0B), Color(0xFFEF4444)],
          onTap: onPlayFromHere,
        ),
      ],
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: LinearGradient(colors: colors),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: .24),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
