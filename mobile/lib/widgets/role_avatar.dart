import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class RoleAvatar extends StatelessWidget {
  const RoleAvatar({
    super.key,
    required this.seed,
    this.imagePath = '',
    this.size = 40,
  });

  final int seed;
  final String imagePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = imagePath.trim();
    return Semantics(
      image: true,
      label: '角色头像',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .18),
        child: SizedBox.square(
          dimension: size,
          child: path.isEmpty
              ? CustomPaint(painter: GeneratedRoleAvatarPainter(seed))
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stackTrace) =>
                      CustomPaint(painter: GeneratedRoleAvatarPainter(seed)),
                ),
        ),
      ),
    );
  }
}

class GeneratedRoleAvatarPainter extends CustomPainter {
  GeneratedRoleAvatarPainter(this.seed);

  final int seed;

  static const backgrounds = [
    Color(0xFFF5F5DC),
    Color(0xFFB0E0E6),
    Color(0xFFD3D3D3),
    Color(0xFF98FB98),
    Color(0xFFFFFDD0),
    Color(0xFFE6E6FA),
    Color(0xFFBC8F8F),
    Color(0xFF87CEEB),
    Color(0xFFF5FFFA),
    Color(0xFFF5DEB3),
    Color(0xFFF08080),
    Color(0xFFFFDAB9),
  ];
  static const skins = [
    Color(0xFFFFE0BD),
    Color(0xFFFFCD94),
    Color(0xFFF1C27D),
    Color(0xFFE0AC69),
    Color(0xFFC68642),
    Color(0xFF8D5524),
  ];
  static const hairColors = [
    Color(0xFF161616),
    Color(0xFF4A2C21),
    Color(0xFF9B5D32),
    Color(0xFFD7A400),
    Color(0xFFD62828),
    Color(0xFF008B8B),
    Color(0xFF6A4C93),
    Color(0xFF264653),
    Color(0xFFFF1493),
  ];

  @override
  void paint(Canvas canvas, Size size) => paintGeneratedRoleAvatar(
    canvas,
    Offset.zero & size,
    seed,
    clipRadius: size.shortestSide * .18,
  );

  @override
  bool shouldRepaint(covariant GeneratedRoleAvatarPainter oldDelegate) =>
      oldDelegate.seed != seed;
}

void paintGeneratedRoleAvatar(
  Canvas canvas,
  Rect rect,
  int seed, {
  double clipRadius = 0,
}) {
  final random = Random(seed);
  canvas.save();
  canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(clipRadius)));
  canvas.translate(rect.left, rect.top);
  canvas.scale(rect.width / 200, rect.height / 200);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 200, 200),
    Paint()
      ..color =
          GeneratedRoleAvatarPainter.backgrounds[random.nextInt(
            GeneratedRoleAvatarPainter.backgrounds.length,
          )],
  );

  final center = Offset(
    100 + _between(random, -8, 8),
    108 + _between(random, -5, 8),
  );
  final faceWidth = _between(random, 105, 150);
  final faceHeight = _between(random, 128, 172);
  final facePoints = _facePoints(random, center, faceWidth, faceHeight);
  final face = _smoothClosedPath(facePoints);
  canvas.drawPath(
    face,
    Paint()
      ..color = GeneratedRoleAvatarPainter
          .skins[random.nextInt(GeneratedRoleAvatarPainter.skins.length)],
  );
  _drawRoughPath(canvas, face, width: 3.2);

  final eyeY = center.dy - faceHeight * _between(random, .12, .19);
  final eyeGap = faceWidth * _between(random, .17, .23);
  final gazeX = _between(random, -3.5, 3.5);
  _drawEye(
    canvas,
    random,
    Offset(center.dx - eyeGap, eyeY + _between(random, -5, 4)),
    _between(random, 23, 39),
    gazeX,
  );
  _drawEye(
    canvas,
    random,
    Offset(center.dx + eyeGap, eyeY + _between(random, -4, 6)),
    _between(random, 20, 42),
    gazeX,
  );
  _drawNose(canvas, random, center, faceHeight);
  _drawMouth(canvas, random, center, faceWidth, faceHeight);
  _drawHair(canvas, random, facePoints, center, faceWidth, faceHeight);
  canvas.restore();
}

List<Offset> _facePoints(
  Random random,
  Offset center,
  double width,
  double height,
) {
  final points = <Offset>[];
  final squareBias = random.nextDouble() < .18
      ? _between(random, .35, .65)
      : 0.0;
  final taper = _between(random, -.22, .22);
  final phase = _between(random, 0, pi * 2);
  for (var i = 0; i < 72; i++) {
    final angle = i / 72 * pi * 2;
    final x = cos(angle);
    final y = sin(angle);
    final roundedX = x.sign * pow(x.abs(), 1 - squareBias).toDouble();
    final roundedY = y.sign * pow(y.abs(), 1 - squareBias).toDouble();
    final wobble =
        sin(angle * 3 + phase) * _between(random, 1.2, 3.6) +
        sin(angle * 7 - phase) * _between(random, .4, 1.8);
    points.add(
      Offset(
        center.dx + roundedX * width / 2 * (1 + taper * y) + wobble,
        center.dy + roundedY * height / 2 + _between(random, -1.3, 1.3),
      ),
    );
  }
  return points;
}

Path _smoothClosedPath(List<Offset> points) {
  final path = Path();
  final first = Offset.lerp(points.last, points.first, .5)!;
  path.moveTo(first.dx, first.dy);
  for (var i = 0; i < points.length; i++) {
    final point = points[i];
    final midpoint = Offset.lerp(point, points[(i + 1) % points.length], .5)!;
    path.quadraticBezierTo(point.dx, point.dy, midpoint.dx, midpoint.dy);
  }
  return path..close();
}

void _drawEye(
  Canvas canvas,
  Random random,
  Offset center,
  double width,
  double gazeX,
) {
  final left = Offset(
    center.dx - width / 2,
    center.dy + _between(random, -2, 2),
  );
  final right = Offset(
    center.dx + width / 2,
    center.dy + _between(random, -2, 2),
  );
  final upper = _between(random, 3, width * .42);
  final lower = _between(random, 3, width * .38);
  final eye = Path()
    ..moveTo(left.dx, left.dy)
    ..cubicTo(
      center.dx - width * _between(random, .05, .35),
      center.dy - upper,
      center.dx + width * _between(random, .05, .35),
      center.dy - upper * _between(random, .6, 1.2),
      right.dx,
      right.dy,
    )
    ..cubicTo(
      center.dx + width * _between(random, .05, .4),
      center.dy + lower,
      center.dx - width * _between(random, .05, .4),
      center.dy + lower * _between(random, .6, 1.2),
      left.dx,
      left.dy,
    )
    ..close();
  canvas.drawPath(eye, Paint()..color = const Color(0xFFFDFDFD));
  _drawRoughPath(canvas, eye, width: 2.5);
  final pupil = Offset(
    center.dx + gazeX + _between(random, -2, 2),
    center.dy + _between(random, -2, 3),
  );
  final radius = _between(random, 3.4, min(upper, lower) * .7 + 3);
  for (var i = 0; i < 6; i++) {
    canvas.drawCircle(
      pupil + Offset(_between(random, -1.2, 1.2), _between(random, -1.2, 1.2)),
      max(1.8, radius + _between(random, -1.2, 1.2)),
      Paint()
        ..color = const Color(0xFF161616).withValues(alpha: .52)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _between(random, .7, 1.5),
    );
  }
}

void _drawNose(Canvas canvas, Random random, Offset center, double height) {
  final y = center.dy + height * .04;
  if (random.nextBool()) {
    final nose = Path()
      ..moveTo(center.dx + _between(random, -5, 4), y - 4)
      ..quadraticBezierTo(
        center.dx + _between(random, -13, 11),
        y + height * .15,
        center.dx + _between(random, -5, 7),
        y + height * .18,
      );
    _drawRoughPath(canvas, nose, width: 2.1);
  } else {
    final paint = Paint()..color = const Color(0xFF161616);
    canvas.drawCircle(
      Offset(center.dx - _between(random, 2, 7), y + height * .16),
      _between(random, 1.4, 2.5),
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + _between(random, 2, 7), y + height * .16),
      _between(random, 1.4, 2.5),
      paint,
    );
  }
}

void _drawMouth(
  Canvas canvas,
  Random random,
  Offset center,
  double faceWidth,
  double faceHeight,
) {
  final y = center.dy + faceHeight * _between(random, .23, .31);
  final width = faceWidth * _between(random, .16, .35);
  final open = random.nextDouble() > .3;
  final mouth = Path()..moveTo(center.dx - width / 2, y);
  if (open) {
    mouth
      ..cubicTo(
        center.dx - width * .15,
        y - _between(random, 1, 8),
        center.dx + width * .2,
        y - _between(random, 0, 7),
        center.dx + width / 2,
        y + _between(random, -2, 3),
      )
      ..cubicTo(
        center.dx + width * .25,
        y + _between(random, 5, 17),
        center.dx - width * .2,
        y + _between(random, 5, 17),
        center.dx - width / 2,
        y,
      )
      ..close();
    canvas.drawPath(mouth, Paint()..color = const Color(0xFFF27B91));
  } else {
    mouth.cubicTo(
      center.dx - width * .2,
      y + _between(random, -9, 10),
      center.dx + width * .25,
      y + _between(random, -9, 10),
      center.dx + width / 2,
      y + _between(random, -3, 3),
    );
  }
  _drawRoughPath(canvas, mouth, width: 2.7);
}

void _drawHair(
  Canvas canvas,
  Random random,
  List<Offset> facePoints,
  Offset center,
  double faceWidth,
  double faceHeight,
) {
  final color = GeneratedRoleAvatarPainter
      .hairColors[random.nextInt(GeneratedRoleAvatarPainter.hairColors.length)];
  final style = random.nextInt(5);
  final count = switch (style) {
    0 => 8 + random.nextInt(9),
    1 => 22 + random.nextInt(18),
    2 => 5 + random.nextInt(6),
    3 => 35 + random.nextInt(24),
    _ => 12 + random.nextInt(14),
  };
  for (var i = 0; i < count; i++) {
    final angle = _between(random, pi * 1.03, pi * 1.97);
    final root =
        facePoints[((angle / (pi * 2)) * facePoints.length).floor() %
            facePoints.length];
    final length = switch (style) {
      0 => _between(random, 20, 58),
      1 => _between(random, 8, 27),
      2 => _between(random, 38, 80),
      3 => _between(random, 4, 14),
      _ => _between(random, 14, 44),
    };
    final outward = root - center;
    final direction = outward.distance == 0
        ? const Offset(0, -1)
        : outward / outward.distance;
    final sideways = Offset(-direction.dy, direction.dx);
    final tip =
        root +
        direction * length +
        sideways * _between(random, -length * .65, length * .65);
    final control =
        Offset.lerp(root, tip, .55)! +
        sideways * _between(random, -faceWidth * .18, faceWidth * .18);
    canvas.drawPath(
      Path()
        ..moveTo(root.dx, root.dy)
        ..quadraticBezierTo(control.dx, control.dy, tip.dx, tip.dy),
      Paint()
        ..color = color.withValues(alpha: _between(random, .72, 1))
        ..style = PaintingStyle.stroke
        ..strokeWidth = _between(random, 1.6, style == 3 ? 3.1 : 4.5)
        ..strokeCap = StrokeCap.round,
    );
  }
  if (style == 4) {
    final fringe = Path()
      ..moveTo(center.dx - faceWidth * .38, center.dy - faceHeight * .34)
      ..quadraticBezierTo(
        center.dx - faceWidth * .05,
        center.dy - faceHeight * .58,
        center.dx + faceWidth * .37,
        center.dy - faceHeight * .3,
      );
    _drawRoughPath(canvas, fringe, width: 5, color: color);
  }
}

void _drawRoughPath(
  Canvas canvas,
  Path path, {
  required double width,
  Color color = const Color(0xFF161616),
}) {
  canvas.drawPath(
    path,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.save();
  canvas.translate(.7, -.45);
  canvas.drawPath(
    path,
    Paint()
      ..color = color.withValues(alpha: .2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(.8, width * .55)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.restore();
}

double _between(Random random, double min, double max) =>
    min + random.nextDouble() * (max - min);

void paintRoleAvatarImage(Canvas canvas, Rect rect, ui.Image image) {
  canvas.save();
  canvas.clipRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide * .18)),
  );
  paintImage(canvas: canvas, rect: rect, image: image, fit: BoxFit.cover);
  canvas.restore();
}
