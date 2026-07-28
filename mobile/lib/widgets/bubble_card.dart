import 'package:flutter/material.dart';

import '../models/project.dart';
import 'app_chrome.dart';

class BubbleCard extends StatefulWidget {
  const BubbleCard({
    super.key,
    required this.bubble,
    required this.onChanged,
    required this.onRoleChanged,
    required this.onGenerate,
    required this.onPlay,
    required this.onDelete,
  });

  final DialogueBubble bubble;
  final ValueChanged<String> onChanged;
  final ValueChanged<BubbleRole> onRoleChanged;
  final VoidCallback onGenerate;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

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
    if (oldWidget.bubble.id != widget.bubble.id) {
      _controller.text = widget.bubble.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              border: Border.all(color: accent.withValues(alpha: .45)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: .16),
                  blurRadius: 30,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: gradient),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: .35),
                              blurRadius: 22,
                            ),
                          ],
                        ),
                        child: Icon(
                          isHost ? Icons.mic_rounded : Icons.person_rounded,
                          color: Colors.white,
                        ),
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
                      _RolePill(
                        value: bubble.role,
                        onChanged: widget.onRoleChanged,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _controller,
                    minLines: 2,
                    maxLines: 8,
                    onChanged: widget.onChanged,
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
                  Row(
                    children: [
                      _ActionChipButton(
                        label: '生成',
                        icon: Icons.auto_awesome_rounded,
                        colors: gradient,
                        onTap: widget.onGenerate,
                      ),
                      const SizedBox(width: 9),
                      _ActionChipButton(
                        label: '试听',
                        icon: Icons.play_arrow_rounded,
                        colors: const [Color(0xFF22C55E), Color(0xFF14B8A6)],
                        onTap: widget.onPlay,
                      ),
                      const Spacer(),
                      _IconGlassButton(
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFFF6B8A),
                        onTap: widget.onDelete,
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

class _IconGlassButton extends StatelessWidget {
  const _IconGlassButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: color.withValues(alpha: .12),
          border: Border.all(color: color.withValues(alpha: .32)),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.value, required this.onChanged});

  final BubbleRole value;
  final ValueChanged<BubbleRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<BubbleRole>(
      color: const Color(0xFF1B1D35),
      onSelected: onChanged,
      itemBuilder: (context) => BubbleRole.values
          .map(
            (role) => PopupMenuItem(value: role, child: Text(role.displayName)),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: Colors.white.withValues(alpha: .08),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.displayName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}
