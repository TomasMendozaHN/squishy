import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/settings.dart';

/// The big animated progress display. [progress] is 0..1.
class ProgressVisual extends StatefulWidget {
  const ProgressVisual({
    super.key,
    required this.style,
    required this.progress,
    this.size = 260,
    this.showLabel = true,
    this.caption,
  });

  final ProgressStyle style;
  final double progress;
  final double size;
  final bool showLabel;
  final String? caption;

  @override
  State<ProgressVisual> createState() => _ProgressVisualState();
}

class _ProgressVisualState extends State<ProgressVisual> with TickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  // Smoothly chases the real progress so 500 ms native ticks look continuous.
  late final AnimationController _level = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: widget.progress,
  );
  double _from = 0;
  double _to = 0;

  @override
  void initState() {
    super.initState();
    _from = _to = widget.progress;
  }

  @override
  void didUpdateWidget(ProgressVisual old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _from = _current;
      _to = widget.progress;
      _level.forward(from: 0);
    }
  }

  double get _current => _from + (_to - _from) * Curves.easeOutCubic.transform(_level.value);

  @override
  void dispose() {
    _clock.dispose();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduce = t.reduceMotion;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_clock, _level]),
          builder: (context, _) {
            final p = _current.clamp(0.0, 1.0);
            final time = reduce ? 0.0 : _clock.value;
            final palette = _VisualPalette(
              a: t.liquidA,
              b: t.liquidB,
              track: context.colors.onSurface.withValues(alpha: 0.08),
              glass: context.colors.onSurface.withValues(alpha: 0.12),
              shine: context.colors.surface,
            );
            final painter = switch (widget.style) {
              ProgressStyle.waterTank => _WaterTankPainter(p, time, palette),
              ProgressStyle.liquidOrb => _LiquidOrbPainter(p, time, palette),
              ProgressStyle.glowRing => _GlowRingPainter(p, time, palette),
              ProgressStyle.equalizer => _EqualizerPainter(p, time, palette),
            };
            return Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(size: Size.square(widget.size), painter: painter),
                if (widget.showLabel) _Label(progress: p, size: widget.size, caption: widget.caption),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.progress, required this.size, this.caption});

  final double progress;
  final double size;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.onSurface;
    final shadow = [Shadow(color: context.colors.surface.withValues(alpha: 0.7), blurRadius: 12)];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${(progress * 100).floor()}%',
          style: context.text.displayMedium?.copyWith(
            fontSize: size * 0.2,
            fontWeight: FontWeight.w800,
            color: color,
            shadows: shadow,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (caption != null)
          Text(
            caption!,
            style: context.text.labelLarge?.copyWith(color: color.withValues(alpha: 0.8), shadows: shadow),
          ),
      ],
    );
  }
}

class _VisualPalette {
  const _VisualPalette({
    required this.a,
    required this.b,
    required this.track,
    required this.glass,
    required this.shine,
  });

  final Color a;
  final Color b;
  final Color track;
  final Color glass;
  final Color shine;
}

Path _wavePath(Rect r, double level, double amp, double phase, double freq) {
  final path = Path()..moveTo(r.left, r.bottom);
  for (var x = 0.0; x <= r.width; x += 3) {
    final y = level + math.sin(x / r.width * 2 * math.pi * freq + phase) * amp;
    path.lineTo(r.left + x, y);
  }
  path
    ..lineTo(r.right, r.bottom)
    ..close();
  return path;
}

void _paintLiquid(Canvas canvas, Rect r, double p, double time, _VisualPalette c, {double ampScale = 1}) {
  final level = r.bottom - r.height * p;
  final amp = r.height * 0.025 * ampScale * (p > 0 && p < 1 ? 1 : 0.3);
  final phase = time * 2 * math.pi;
  final shader = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [c.b, c.a],
  ).createShader(r);
  canvas.drawPath(
    _wavePath(r, level, amp * 1.3, -phase * 2 + 1.2, 1.3),
    Paint()..color = c.a.withValues(alpha: 0.35),
  );
  canvas.drawPath(_wavePath(r, level, amp, phase * 2, 1.7), Paint()..shader = shader);

  // Bubbles rising through the liquid.
  final rnd = math.Random(7);
  final bubble = Paint()..color = c.shine.withValues(alpha: 0.35);
  for (var i = 0; i < 14; i++) {
    final x = r.left + r.width * (0.1 + rnd.nextDouble() * 0.8);
    final speed = 0.6 + rnd.nextDouble();
    final travel = ((time * speed + rnd.nextDouble()) % 1.0);
    final y = r.bottom - travel * (r.bottom - level);
    if (y < level + 4) continue;
    final radius = r.width * (0.008 + rnd.nextDouble() * 0.014);
    canvas.drawCircle(Offset(x + math.sin(time * 12 + i) * 3, y), radius, bubble);
  }
}

class _WaterTankPainter extends CustomPainter {
  _WaterTankPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final tank = Rect.fromLTWH(w * 0.18, w * 0.08, w * 0.64, w * 0.84);
    final rr = RRect.fromRectAndRadius(tank, Radius.circular(w * 0.12));

    canvas.drawRRect(
      rr.inflate(w * 0.02),
      Paint()
        ..color = c.a.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06),
    );
    canvas.drawRRect(rr, Paint()..color = c.track);
    canvas.save();
    canvas.clipRRect(rr);
    _paintLiquid(canvas, tank, p, time, c);
    canvas.restore();

    // Measurement ticks.
    final tick = Paint()
      ..color = c.glass
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < 5; i++) {
      final y = tank.bottom - tank.height * i / 5;
      canvas.drawLine(Offset(tank.right - w * 0.08, y), Offset(tank.right - w * 0.03, y), tick);
    }
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..color = c.glass,
    );
    // Glass glare.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(tank.left + w * 0.05, tank.top + w * 0.07, w * 0.035, tank.height * 0.5),
        Radius.circular(w),
      ),
      Paint()..color = c.shine.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(_WaterTankPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _LiquidOrbPainter extends CustomPainter {
  _LiquidOrbPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    final radius = w * 0.4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius * 1.05,
      Paint()
        ..color = c.b.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.07),
    );
    canvas.drawCircle(center, radius, Paint()..color = c.track);
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    _paintLiquid(canvas, rect, p, time, c, ampScale: 1.4);
    canvas.restore();
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.014
        ..color = c.glass,
    );
    canvas.drawArc(
      rect.deflate(w * 0.05),
      math.pi * 1.1,
      math.pi * 0.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * 0.025
        ..color = c.shine.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_LiquidOrbPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _GlowRingPainter extends CustomPainter {
  _GlowRingPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    final radius = w * 0.4;
    final stroke = w * 0.06;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = c.track,
    );

    final sweep = math.max(p * 2 * math.pi, 0.001);
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: 2 * math.pi,
      colors: [c.a, c.b, c.a],
      transform: GradientRotation(-math.pi / 2 + time * 2 * math.pi),
    ).createShader(rect);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = gradient
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.03),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.8
        ..strokeCap = StrokeCap.round
        ..shader = gradient,
    );

    final head = center + Offset(math.cos(-math.pi / 2 + sweep), math.sin(-math.pi / 2 + sweep)) * radius;
    canvas.drawCircle(
      head,
      stroke * 0.9,
      Paint()
        ..color = c.b.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.6),
    );
    canvas.drawCircle(head, stroke * 0.32, Paint()..color = c.shine);

    // Sloshing core.
    final core = Rect.fromCircle(center: center, radius: radius * 0.62);
    canvas.save();
    canvas.clipPath(Path()..addOval(core));
    canvas.drawRect(core, Paint()..color = c.track);
    _paintLiquid(canvas, core, p, time, c, ampScale: 0.8);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlowRingPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _EqualizerPainter extends CustomPainter {
  _EqualizerPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const bars = 15;
    final area = Rect.fromLTWH(w * 0.06, w * 0.12, w * 0.88, w * 0.76);
    final gap = area.width * 0.018;
    final bw = (area.width - gap * (bars - 1)) / bars;
    final lit = p * bars;
    for (var i = 0; i < bars; i++) {
      final wave = 0.5 + 0.5 * math.sin(time * 2 * math.pi * 3 + i * 0.7);
      final envelope = 0.35 + 0.65 * math.sin(math.pi * (i + 0.5) / bars);
      final h = area.height * envelope * (0.55 + 0.45 * wave);
      final rect = Rect.fromLTWH(area.left + i * (bw + gap), area.center.dy - h / 2, bw, h);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(bw / 2));
      final fill = (lit - i).clamp(0.0, 1.0);
      canvas.drawRRect(rr, Paint()..color = c.track);
      if (fill > 0) {
        final shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [c.a, c.b],
        ).createShader(rect);
        canvas.drawRRect(
          rr,
          Paint()
            ..shader = shader
            ..color = Colors.black.withValues(alpha: fill),
        );
        if (fill >= 1) {
          canvas.drawRRect(
            rr,
            Paint()
              ..color = c.b.withValues(alpha: 0.3)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, bw * 0.6),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_EqualizerPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}
