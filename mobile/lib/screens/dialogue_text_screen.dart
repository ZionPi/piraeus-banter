import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/project.dart';
import '../widgets/role_avatar.dart';

class DialogueTextScreen extends StatefulWidget {
  const DialogueTextScreen({
    super.key,
    required this.project,
    required this.exportTitle,
    required this.hostAvatarSeed,
    required this.guestAvatarSeed,
    this.hostAvatarPath = '',
    this.guestAvatarPath = '',
  });

  final BanterProject project;
  final String exportTitle;
  final int hostAvatarSeed;
  final int guestAvatarSeed;
  final String hostAvatarPath;
  final String guestAvatarPath;

  @override
  State<DialogueTextScreen> createState() => _DialogueTextScreenState();
}

class _DialogueTextScreenState extends State<DialogueTextScreen> {
  bool _creatingImages = false;

  List<DialogueBubble> get _bubbles => widget.project.bubbles
      .where((bubble) => bubble.content.trim().isNotEmpty)
      .toList();

  String get _plainText =>
      _bubbles.map((bubble) => bubble.content.trim()).join('\n\n');

  Future<void> _copyAll() async {
    if (_plainText.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _plainText));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制全部文本。')));
  }

  Future<void> _openImagePreview() async {
    if (_creatingImages || _bubbles.isEmpty) return;
    setState(() => _creatingImages = true);
    try {
      final files = await _renderChatImages();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DialogueImagePreviewScreen(
            files: files,
            projectName: widget.exportTitle,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('生成长图失败：$error')));
    } finally {
      if (mounted) setState(() => _creatingImages = false);
    }
  }

  Future<List<File>> _renderChatImages() async {
    const width = 1080.0;
    const topBarHeight = 132.0;
    const bottomPadding = 54.0;
    const maxHeight = 14000.0;
    const gap = 30.0;
    final hostImage = await _loadAvatarImage(widget.hostAvatarPath);
    final guestImage = await _loadAvatarImage(widget.guestAvatarPath);
    final layouts = _bubbles
        .map(
          (bubble) => _ChatBubbleLayout(
            bubble,
            avatarSeed: bubble.role == BubbleRole.host
                ? widget.hostAvatarSeed
                : widget.guestAvatarSeed,
            avatarImage: bubble.role == BubbleRole.host
                ? hostImage
                : guestImage,
          ),
        )
        .toList();
    final pages = <List<_ChatBubbleLayout>>[];
    var page = <_ChatBubbleLayout>[];
    var height = topBarHeight + bottomPadding;
    for (final layout in layouts) {
      final needed = layout.rowHeight + (page.isEmpty ? 18 : gap);
      if (page.isNotEmpty && height + needed > maxHeight) {
        pages.add(page);
        page = <_ChatBubbleLayout>[];
        height = topBarHeight + bottomPadding;
      }
      page.add(layout);
      height += layout.rowHeight + (page.length == 1 ? 18 : gap);
    }
    if (page.isNotEmpty) pages.add(page);

    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final files = <File>[];
    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final current = pages[pageIndex];
      final contentHeight = current.fold<double>(
        0,
        (sum, layout) => sum + layout.rowHeight,
      );
      final imageHeight =
          topBarHeight +
          18 +
          contentHeight +
          gap * (current.length - 1) +
          bottomPadding;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFFEDEDED), BlendMode.src);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, width, topBarHeight),
        Paint()..color = const Color(0xFFF7F7F7),
      );
      canvas.drawLine(
        const Offset(0, topBarHeight - 1),
        const Offset(width, topBarHeight - 1),
        Paint()..color = const Color(0xFFD8D8D8),
      );
      final title = TextPainter(
        text: TextSpan(
          text: widget.exportTitle,
          style: const TextStyle(
            color: Color(0xFF171717),
            fontSize: 42,
            fontWeight: FontWeight.w700,
          ),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 820);
      title.paint(
        canvas,
        Offset((width - title.width) / 2, (topBarHeight - title.height) / 2),
      );

      var y = topBarHeight + 18;
      for (final layout in current) {
        layout.paint(canvas, y, width);
        y += layout.rowHeight + gap;
      }
      if (pages.length > 1) {
        final pageLabel = TextPainter(
          text: TextSpan(
            text: '${pageIndex + 1} / ${pages.length}',
            style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 24),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        pageLabel.paint(
          canvas,
          Offset((width - pageLabel.width) / 2, imageHeight - 38),
        );
      }
      final image = await recorder.endRecording().toImage(
        width.toInt(),
        imageHeight.ceil(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('无法编码长图。');
      final file = File(
        '${tempDir.path}/dialogue_${stamp}_${pageIndex + 1}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      files.add(file);
    }
    hostImage?.dispose();
    guestImage?.dispose();
    return files;
  }

  Future<ui.Image?> _loadAvatarImage(String path) async {
    if (path.trim().isEmpty) return null;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F7),
        foregroundColor: const Color(0xFF171717),
        surfaceTintColor: Colors.transparent,
        title: Text(widget.project.name),
        actions: [
          IconButton(
            onPressed: _plainText.isEmpty ? null : _copyAll,
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: '复制全部文本',
          ),
          IconButton(
            onPressed: _bubbles.isEmpty || _creatingImages
                ? null
                : _openImagePreview,
            icon: _creatingImages
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_rounded),
            tooltip: '生成聊天长图',
          ),
        ],
      ),
      body: _bubbles.isEmpty
          ? const Center(
              child: Text(
                '当前项目还没有文本',
                style: TextStyle(color: Color(0xFF666666)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 32),
              itemCount: _bubbles.length,
              itemBuilder: (context, index) => _ChatRow(
                bubble: _bubbles[index],
                avatarSeed: _bubbles[index].role == BubbleRole.host
                    ? widget.hostAvatarSeed
                    : widget.guestAvatarSeed,
                avatarPath: _bubbles[index].role == BubbleRole.host
                    ? widget.hostAvatarPath
                    : widget.guestAvatarPath,
              ),
            ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.bubble,
    required this.avatarSeed,
    required this.avatarPath,
  });

  final DialogueBubble bubble;
  final int avatarSeed;
  final String avatarPath;

  @override
  Widget build(BuildContext context) {
    final right = bubble.role == BubbleRole.host;
    final avatar = RoleAvatar(
      seed: avatarSeed,
      imagePath: avatarPath,
      size: 42,
    );
    final chatBubble = Flexible(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: right ? const Color(0xFF95EC69) : Colors.white,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          bubble.content.trim(),
          style: const TextStyle(
            color: Color(0xFF171717),
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: right
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: right
            ? [
                chatBubble,
                const _ChatTail(right: true, color: Color(0xFF95EC69)),
                const SizedBox(width: 8),
                avatar,
              ]
            : [
                avatar,
                const SizedBox(width: 8),
                const _ChatTail(right: false, color: Colors.white),
                chatBubble,
              ],
      ),
    );
  }
}

class _ChatTail extends StatelessWidget {
  const _ChatTail({required this.right, required this.color});

  final bool right;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CustomPaint(
        size: const Size(7, 14),
        painter: _ChatTailPainter(right: right, color: color),
      ),
    );
  }
}

class _ChatTailPainter extends CustomPainter {
  const _ChatTailPainter({required this.right, required this.color});

  final bool right;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (right) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height);
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height / 2)
        ..lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ChatTailPainter oldDelegate) =>
      oldDelegate.right != right || oldDelegate.color != color;
}

class _ChatBubbleLayout {
  _ChatBubbleLayout(
    this.bubble, {
    required this.avatarSeed,
    required this.avatarImage,
  }) {
    textPainter = TextPainter(
      text: TextSpan(
        text: bubble.content.trim(),
        style: const TextStyle(
          color: Color(0xFF171717),
          fontSize: 36,
          height: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 650);
  }

  final DialogueBubble bubble;
  final int avatarSeed;
  final ui.Image? avatarImage;
  late final TextPainter textPainter;

  double get bubbleWidth => (textPainter.width + 56).clamp(116, 706);
  double get bubbleHeight => textPainter.height + 42;
  double get rowHeight => bubbleHeight > 78 ? bubbleHeight : 78;

  void paint(Canvas canvas, double y, double canvasWidth) {
    const edge = 42.0;
    const avatarSize = 78.0;
    const avatarGap = 22.0;
    final right = bubble.role == BubbleRole.host;
    final avatarLeft = right ? canvasWidth - edge - avatarSize : edge;
    final bubbleLeft = right
        ? avatarLeft - avatarGap - bubbleWidth
        : avatarLeft + avatarSize + avatarGap;
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bubbleLeft, y, bubbleWidth, bubbleHeight),
      const Radius.circular(10),
    );
    final bubbleColor = right ? const Color(0xFF95EC69) : Colors.white;
    canvas.drawRRect(bubbleRect, Paint()..color = bubbleColor);
    final tail = Path();
    if (right) {
      tail
        ..moveTo(bubbleLeft + bubbleWidth, y + 26)
        ..lineTo(bubbleLeft + bubbleWidth + 16, y + 36)
        ..lineTo(bubbleLeft + bubbleWidth, y + 44);
    } else {
      tail
        ..moveTo(bubbleLeft, y + 26)
        ..lineTo(bubbleLeft - 16, y + 36)
        ..lineTo(bubbleLeft, y + 44);
    }
    tail.close();
    canvas.drawPath(tail, Paint()..color = bubbleColor);
    textPainter.paint(canvas, Offset(bubbleLeft + 28, y + 21));

    final avatarRect = Rect.fromLTWH(avatarLeft, y, avatarSize, avatarSize);
    if (avatarImage case final image?) {
      paintRoleAvatarImage(canvas, avatarRect, image);
    } else {
      paintGeneratedRoleAvatar(canvas, avatarRect, avatarSeed, clipRadius: 10);
    }
  }
}

class DialogueImagePreviewScreen extends StatefulWidget {
  const DialogueImagePreviewScreen({
    super.key,
    required this.files,
    required this.projectName,
  });

  final List<File> files;
  final String projectName;

  @override
  State<DialogueImagePreviewScreen> createState() =>
      _DialogueImagePreviewScreenState();
}

class _DialogueImagePreviewScreenState
    extends State<DialogueImagePreviewScreen> {
  int _page = 0;

  Future<void> _share() => Share.shareXFiles(
    widget.files.map((file) => XFile(file.path)).toList(),
    text: widget.projectName,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151515),
      appBar: AppBar(
        title: Text(
          widget.files.length == 1
              ? '长图预览'
              : '长图预览 ${_page + 1}/${widget.files.length}',
        ),
        actions: [
          IconButton(
            onPressed: _share,
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: '分享图片',
          ),
        ],
      ),
      body: PageView.builder(
        itemCount: widget.files.length,
        onPageChanged: (page) => setState(() => _page = page),
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Center(
            child: Image.file(
              widget.files[index],
              fit: BoxFit.contain,
              cacheWidth: 1080,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}
