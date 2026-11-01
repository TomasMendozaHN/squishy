import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme_presets.dart';

/// The Squishy mascot. Geometry mirrors android/.../ic_launcher_foreground.xml
/// (108-unit viewport, content between 20 and 88).
class SquishyLogo extends StatefulWidget {
  const SquishyLogo({
    super.key,
    this.size = 96,
    this.playing = true,
    this.showArrows = true,
  });

  final double size;
  final bool playing;
  final bool showArrows;

  @override
  State<SquishyLogo> createState() => _SquishyLogoState();
}

class _SquishyLogoState extends State<SquishyLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _c.repeat();
  }

  @override
  void didUpdateWidget(SquishyLogo old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_c.isAnimating) _c.repeat();
    if (!widget.playing) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: SquishyLogoPainter(
            squish: widget.playing ? _squishCurve(_c.value) : 0,
            blink: widget.playing && _c.value > 0.9,
            showArrows: widget.showArrows,
          ),
        ),
      ),
    );
  }

  /// A squeeze-and-wobble: fast squash, springy release.
  double _squishCurve(double t) {
    if (t < 0.25) return Curves.easeOut.transform(t / 0.25);
    final r = (t - 0.25) / 0.75;
    return math.exp(-5 * r) * math.cos(r * math.pi * 3);
  }
}

class SquishyLogoPainter extends CustomPainter {
  SquishyLogoPainter({this.squish = 0, this.blink = false, this.showArrows = true});

  /// -1..1, positive = squashed flatter.
  final double squish;
  final bool blink;
  final bool showArrows;

  static Path body() => Path()
    ..moveTo(54, 37)
    ..cubicTo(66, 37, 73, 40.5, 75.5, 49)
    ..cubicTo(78, 58, 76.5, 70, 65, 74.5)
    ..cubicTo(60, 76.5, 48, 76.5, 43, 74.5)
    ..cubicTo(31.5, 70, 30, 58, 32.5, 49)
    ..cubicTo(35, 40.5, 42, 37, 54, 37)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 68;
    canvas.save();
    canvas.scale(s);
    canvas.translate(-20, -20);

    if (showArrows) {
      final shift = squish * 3;
      final arrow = Paint()..color = BrandColors.shine.withValues(alpha: 0.85);
      canvas.drawPath(
        Path()
          ..moveTo(29.5 + shift, 56)
          ..lineTo(23.5 + shift, 51.6)
          ..quadraticBezierTo(22.5 + shift, 51, 22.5 + shift, 52.2)
          ..lineTo(22.5 + shift, 59.8)
          ..quadraticBezierTo(22.5 + shift, 61, 23.5 + shift, 60.4)
          ..close(),
        arrow,
      );
      canvas.drawPath(
        Path()
          ..moveTo(78.5 - shift, 56)
          ..lineTo(84.5 - shift, 51.6)
          ..quadraticBezierTo(85.5 - shift, 51, 85.5 - shift, 52.2)
          ..lineTo(85.5 - shift, 59.8)
          ..quadraticBezierTo(85.5 - shift, 61, 84.5 - shift, 60.4)
          ..close(),
        arrow,
      );
    }

    // Squash around the bottom-center so the blob looks like it sits on a floor.
    canvas.translate(54, 76);
    canvas.scale(1 - squish * 0.10, 1 + squish * 0.12);
    canvas.translate(-54, -76);

    final bodyPath = body();
    canvas.drawShadow(bodyPath, BrandColors.blobBottom, 6, false);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [BrandColors.blobTop, BrandColors.blobBottom],
        ).createShader(const Rect.fromLTRB(30, 37, 78, 76)),
    );

    canvas.drawPath(
      Path()
        ..moveTo(39.5, 47.5)
        ..cubicTo(39.5, 43.8, 44, 41.6, 47.5, 42.6)
        ..cubicTo(49.6, 43.2, 48, 45.6, 45, 46.8)
        ..cubicTo(42.4, 47.9, 39.5, 49.4, 39.5, 47.5)
        ..close(),
      Paint()..color = BrandColors.shine.withValues(alpha: 0.75),
    );

    final cheek = Paint()..color = BrandColors.cheek.withValues(alpha: 0.7);
    canvas.drawOval(Rect.fromCenter(center: const Offset(41, 63), width: 6.4, height: 4.2), cheek);
    canvas.drawOval(Rect.fromCenter(center: const Offset(67, 63), width: 6.4, height: 4.2), cheek);

    final face = Paint()..color = BrandColors.face;
    if (blink) {
      final lid = Paint()
        ..color = BrandColors.face
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(43.5, 57), const Offset(49.5, 57), lid);
      canvas.drawLine(const Offset(58.5, 57), const Offset(64.5, 57), lid);
    } else {
      canvas.drawCircle(const Offset(46.5, 57), 3.6, face);
      canvas.drawCircle(const Offset(61.5, 57), 3.6, face);
      final sparkle = Paint()..color = BrandColors.shine;
      canvas.drawCircle(const Offset(47.7, 55.7), 1.2, sparkle);
      canvas.drawCircle(const Offset(62.7, 55.7), 1.2, sparkle);
    }

    canvas.drawPath(
      Path()
        ..moveTo(50.5, 64)
        ..quadraticBezierTo(54, 67.5 + squish * 1.5, 57.5, 64),
      Paint()
        ..color = BrandColors.face
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SquishyLogoPainter old) =>
      old.squish != squish || old.blink != blink || old.showArrows != showArrows;
}
