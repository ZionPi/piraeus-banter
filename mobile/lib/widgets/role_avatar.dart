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
  canvas.save();
  canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(clipRadius)));
  canvas.translate(rect.left, rect.top);
  canvas.scale(rect.width / 200, rect.height / 200);
  canvas.drawPicture(_avatarPicture(seed));
  canvas.restore();
}

final _avatarPictures = <int, ui.Picture>{};

ui.Picture _avatarPicture(int seed) {
  final cached = _avatarPictures[seed];
  if (cached != null) return cached;
  if (_avatarPictures.length >= 24) {
    final oldest = _avatarPictures.keys.first;
    _avatarPictures.remove(oldest)?.dispose();
  }
  final recorder = ui.PictureRecorder();
  _paintAvatar(Canvas(recorder), seed);
  final picture = recorder.endRecording();
  _avatarPictures[seed] = picture;
  return picture;
}

void _paintAvatar(Canvas canvas, int seed) {
  final random = Random(seed);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 200, 200),
    Paint()
      ..color =
          GeneratedRoleAvatarPainter.backgrounds[random.nextInt(
            GeneratedRoleAvatarPainter.backgrounds.length,
          )],
  );

  // Adapted from txstc55/ugly-avatar: two independently generated contours
  // are rotated into each other. This is the main source of its wide variety.
  final geometry = _generateFaceGeometry(random);
  final center = const Offset(100, 100);
  final faceWidth = geometry.width;
  final faceHeight = geometry.height;
  final facePoints = geometry.points
      .map((point) => point + center)
      .toList(growable: false);
  final face = _polylinePath(facePoints, close: true);
  canvas.drawPath(face, Paint()..color = const Color(0xFFFFC9A9));
  _drawRoughPath(canvas, face, width: 3.2);

  final eyeY = center.dy - faceHeight * _between(random, .12, .18);
  final eyeGap = faceWidth * _between(random, .21, .25);
  final gazeX = _between(random, -3.5, 3.5);
  _drawEye(
    canvas,
    random,
    Offset(center.dx - eyeGap, eyeY + _between(random, -5, 4)),
    faceWidth * _between(random, .20, .34),
    gazeX,
  );
  _drawEye(
    canvas,
    random,
    Offset(center.dx + eyeGap, eyeY + _between(random, -4, 6)),
    faceWidth * _between(random, .16, .38),
    gazeX,
  );
  _drawNose(canvas, random, center, faceHeight);
  _drawMouth(canvas, random, center, faceWidth, faceHeight);
  _drawHair(canvas, random, facePoints, center, faceWidth, faceHeight);
}

class _FaceGeometry {
  const _FaceGeometry(this.points, this.width, this.height);

  final List<Offset> points;
  final double width;
  final double height;
}

_FaceGeometry _generateFaceGeometry(Random random) {
  const segments = 52;
  final first = _randomContour(
    random,
    width: _between(random, 50, 100),
    height: _between(random, 70, 100),
    rectangularChance: .10,
  );
  final second = _randomContour(
    random,
    width: _between(random, 70, 100),
    height: _between(random, 50, 80),
    rectangularChance: .30,
  );
  final firstShift = Offset(_between(random, -5, 5), _between(random, -15, 15));
  final secondShift = Offset(_between(random, -5, 25), _between(random, -5, 5));
  final quarter = segments;
  final points = <Offset>[];
  for (var index = 0; index < first.length; index++) {
    final a = first[index] + firstShift;
    final b = second[(index + quarter) % second.length] + secondShift;
    points.add(Offset(a.dx * .7 + b.dy * .3, a.dy * .7 - b.dx * .3));
  }
  final center = points.reduce((a, b) => a + b) / points.length.toDouble();
  final centered = points.map((point) => point - center).toList();
  final width = (centered.first.dx - centered[centered.length ~/ 2].dx).abs();
  final height =
      (centered[centered.length ~/ 4].dy -
              centered[centered.length * 3 ~/ 4].dy)
          .abs();
  return _FaceGeometry(centered, width, height);
}

List<Offset> _randomContour(
  Random random, {
  required double width,
  required double height,
  required double rectangularChance,
}) {
  if (random.nextDouble() < rectangularChance) {
    return _rectangularContour(random, width, height);
  }
  final taper = _between(random, .001, .005) * (random.nextBool() ? 1 : -1);
  return _eggContour(random, width, height, taper);
}

List<Offset> _eggContour(
  Random random,
  double width,
  double height,
  double taper,
) {
  const segments = 52;
  final points = <Offset>[];
  void addQuadrant(int xSign, int ySign, bool reverse) {
    for (var step = 0; step < segments; step++) {
      final index = reverse ? segments - step : step;
      final angle =
          pi / 2 / segments * index +
          _between(random, -pi / 1.1 / segments, pi / 1.1 / segments);
      final y = sin(angle) * height * ySign;
      final inside = ((1 - y * y / (height * height)) / (1 + taper * y)).clamp(
        0.0,
        double.infinity,
      );
      final x = sqrt(inside * width * width) * xSign;
      points.add(Offset(x + _between(random, -width / 200, width / 200), y));
    }
  }

  addQuadrant(1, 1, false);
  addQuadrant(-1, 1, true);
  addQuadrant(-1, -1, false);
  addQuadrant(1, -1, true);
  return points;
}

List<Offset> _rectangularContour(Random random, double width, double height) {
  const segments = 52;
  final points = <Offset>[];
  void addQuadrant(int xSign, int ySign, bool reverse) {
    for (var step = 0; step < segments; step++) {
      final index = reverse ? segments - step : step;
      final angle =
          pi / 2 / segments * index +
          _between(random, -pi / 11 / segments, pi / 11 / segments);
      final slope = tan(angle.clamp(0, pi / 2));
      final yAtSide = slope * width;
      final point = yAtSide < height
          ? Offset(width, yAtSide)
          : Offset(slope.abs() < .0001 ? width : height / slope, height);
      points.add(Offset(point.dx * xSign, point.dy * ySign));
    }
  }

  addQuadrant(1, 1, false);
  addQuadrant(-1, 1, true);
  addQuadrant(-1, -1, false);
  addQuadrant(1, -1, true);
  return points;
}

Path _polylinePath(List<Offset> points, {bool close = false}) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  if (close) path.close();
  return path;
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
  final baseColor = GeneratedRoleAvatarPainter
      .hairColors[random.nextInt(GeneratedRoleAvatarPainter.hairColors.length)];
  final rainbow = random.nextDouble() < .1;
  final topStart = facePoints.length ~/ 2;
  final top = facePoints.sublist(topStart);
  Color strandColor() => rainbow
      ? GeneratedRoleAvatarPainter.hairColors[random.nextInt(
          GeneratedRoleAvatarPainter.hairColors.length,
        )]
      : baseColor;
  Offset rootAt(double portion) =>
      top[(portion.clamp(0.0, .999) * top.length).floor()];
  void stroke(Path path, {double? width}) {
    canvas.drawPath(
      path,
      Paint()
        ..color = strandColor().withValues(alpha: _between(random, .72, 1))
        ..style = PaintingStyle.stroke
        ..strokeWidth = width ?? _between(random, .7, 3.2)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  var drewHair = false;

  // Paired contour arcs: strands jump between distant roots on the head.
  if (random.nextDouble() > .3) {
    drewHair = true;
    final count = 10 + random.nextInt(48);
    for (var index = 0; index < count; index++) {
      final start = rootAt(_between(random, .04, .72));
      final end = rootAt(_between(random, .28, .96));
      final lift = _between(random, 8, faceHeight * .46);
      final sideways = _between(random, -faceWidth * .30, faceWidth * .30);
      stroke(
        Path()
          ..moveTo(start.dx, start.dy)
          ..quadraticBezierTo(
            (start.dx + end.dx) / 2 + sideways,
            min(start.dy, end.dy) - lift,
            end.dx,
            end.dy,
          ),
      );
    }
  }

  // Loose scribbles use unrelated contour points, matching the source's
  // high-order random Bezier family.
  if (random.nextDouble() > .3) {
    drewHair = true;
    final count = 8 + random.nextInt(30);
    for (var index = 0; index < count; index++) {
      final a = rootAt(random.nextDouble());
      final b = rootAt(random.nextDouble());
      final c = rootAt(random.nextDouble());
      final d = rootAt(random.nextDouble());
      stroke(
        Path()
          ..moveTo(a.dx, a.dy)
          ..cubicTo(
            b.dx + _between(random, -18, 18),
            b.dy - _between(random, 0, 28),
            c.dx + _between(random, -18, 18),
            c.dy - _between(random, 0, 28),
            d.dx,
            d.dy,
          ),
      );
    }
  }

  // Dense outward tufts can be short, long, reversed, or swept sideways.
  if (random.nextDouble() > .5 || !drewHair) {
    drewHair = true;
    final count = 14 + random.nextInt(82);
    final split = random.nextDouble();
    for (var index = 0; index < count; index++) {
      final portion = count == 1 ? .5 : index / (count - 1);
      final root = rootAt(portion);
      final outward = root - center;
      final direction = outward.distance == 0
          ? const Offset(0, -1)
          : outward / outward.distance;
      final sideways = Offset(-direction.dy, direction.dx);
      final length = _between(random, 8, faceHeight * .72);
      final sweep = portion < split ? -1.0 : 1.0;
      final tip =
          root +
          direction * length * _between(random, .55, 1.35) +
          sideways * length * _between(random, -.45, .85) * sweep;
      final control =
          Offset.lerp(root, tip, _between(random, .30, .72))! +
          sideways * _between(random, -faceWidth * .24, faceWidth * .24);
      stroke(
        Path()
          ..moveTo(root.dx, root.dy)
          ..quadraticBezierTo(control.dx, control.dy, tip.dx, tip.dy),
      );
    }
  }

  // A fourth family adds occasional long crossing locks independently.
  if (random.nextDouble() > .5) {
    final count = 8 + random.nextInt(38);
    for (var index = 0; index < count; index++) {
      final root = rootAt(random.nextDouble());
      final opposite = rootAt(1 - random.nextDouble());
      final tip = Offset(
        opposite.dx + _between(random, -faceWidth * .35, faceWidth * .35),
        opposite.dy + _between(random, -faceHeight * .55, faceHeight * .20),
      );
      stroke(
        Path()
          ..moveTo(root.dx, root.dy)
          ..quadraticBezierTo(
            center.dx + _between(random, -faceWidth * .65, faceWidth * .65),
            center.dy - _between(random, faceHeight * .18, faceHeight * .75),
            tip.dx,
            tip.dy,
          ),
        width: _between(random, .6, 2.8),
      );
    }
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
