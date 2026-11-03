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
              ProgressStyle.battery => _BatteryPainter(p, time, palette),
              ProgressStyle.thermometer => _ThermometerPainter(p, time, palette),
              ProgressStyle.blob => _BlobPainter(p, time, palette),
              ProgressStyle.dotGrid => _DotGridPainter(p, time, palette),
              ProgressStyle.spiral => _SpiralPainter(p, time, palette),
              ProgressStyle.hourglass => _HourglassPainter(p, time, palette),
              ProgressStyle.orbit => _OrbitPainter(p, time, palette),
              ProgressStyle.radar => _RadarPainter(p, time, palette),
              ProgressStyle.ripple => _RipplePainter(p, time, palette),
              ProgressStyle.constellation => _ConstellationPainter(p, time, palette),
              ProgressStyle.clockHands => _ClockHandsPainter(p, time, palette),
              ProgressStyle.bloom => _BloomPainter(p, time, palette),
              ProgressStyle.waveform => _WaveformPainter(p, time, palette),
              ProgressStyle.minimalBar => _MinimalBarPainter(p, time, palette),
              ProgressStyle.confetti => _ConfettiPainter(p, time, palette),
              ProgressStyle.staircase => _StaircasePainter(p, time, palette),
              ProgressStyle.scribble => _ScribblePainter(p, time, palette),
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

/// A smooth closed curve through [pts], arranged around [center]: the usual way to draw an
/// organic "blob" outline without visible corners.
Path _smoothBlob(List<Offset> pts) {
  final mid0 = Offset.lerp(pts.last, pts.first, 0.5)!;
  final path = Path()..moveTo(mid0.dx, mid0.dy);
  for (var i = 0; i < pts.length; i++) {
    final cur = pts[i];
    final next = pts[(i + 1) % pts.length];
    final mid = Offset.lerp(cur, next, 0.5)!;
    path.quadraticBezierTo(cur.dx, cur.dy, mid.dx, mid.dy);
  }
  path.close();
  return path;
}

class _BatteryPainter extends CustomPainter {
  _BatteryPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final body = Rect.fromLTWH(w * 0.14, w * 0.14, w * 0.62, w * 0.72);
    final nub = Rect.fromLTWH(body.right - 1, body.center.dy - w * 0.09, w * 0.06, w * 0.18);
    final rr = RRect.fromRectAndRadius(body, Radius.circular(w * 0.08));
    canvas.drawRRect(
      rr.inflate(w * 0.02),
      Paint()
        ..color = c.a.withValues(alpha: 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
    );
    canvas.drawRRect(rr, Paint()..color = c.track);
    canvas.drawRRect(RRect.fromRectAndRadius(nub, Radius.circular(w * 0.02)), Paint()..color = c.glass);
    canvas.save();
    canvas.clipRRect(rr);
    _paintLiquid(canvas, body, p, time, c, ampScale: 0.7);
    canvas.restore();
    canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.012..color = c.glass);
  }

  @override
  bool shouldRepaint(_BatteryPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _ThermometerPainter extends CustomPainter {
  _ThermometerPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final bulbR = w * 0.15;
    final bulbCenter = Offset(w / 2, w * 0.82);
    final tube = Rect.fromLTWH(w / 2 - w * 0.065, w * 0.08, w * 0.13, bulbCenter.dy - w * 0.08);
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius(tube, Radius.circular(w * 0.065)))
      ..addOval(Rect.fromCircle(center: bulbCenter, radius: bulbR));
    canvas.drawPath(
      outline,
      Paint()
        ..color = c.a.withValues(alpha: 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
    );
    canvas.drawPath(outline, Paint()..color = c.track);
    canvas.save();
    canvas.clipPath(outline);
    canvas.drawCircle(
      bulbCenter,
      bulbR,
      Paint()..shader = LinearGradient(colors: [c.b, c.a]).createShader(Rect.fromCircle(center: bulbCenter, radius: bulbR)),
    );
    _paintLiquid(canvas, Rect.fromLTRB(tube.left, tube.top, tube.right, bulbCenter.dy), p, time, c, ampScale: 0.4);
    canvas.restore();
    canvas.drawPath(outline, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.01..color = c.glass);
  }

  @override
  bool shouldRepaint(_ThermometerPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    final baseR = w * (0.14 + 0.28 * p);
    final squashT = time * 2 * math.pi;
    final sx = 1 + 0.06 * math.sin(squashT);
    final sy = 1 - 0.06 * math.sin(squashT);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(sx, sy);
    canvas.translate(-center.dx, -center.dy);
    const pts = 10;
    final outline = [
      for (var i = 0; i < pts; i++)
        () {
          final a = i / pts * 2 * math.pi;
          final wobble = 1 + 0.06 * math.sin(a * 3 + time * 4 * math.pi);
          return center + Offset(math.cos(a), math.sin(a)) * baseR * wobble;
        }(),
    ];
    final path = _smoothBlob(outline);
    canvas.drawPath(
      path,
      Paint()
        ..color = c.a.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.a, c.b])
            .createShader(Rect.fromCircle(center: center, radius: baseR * 1.2)),
    );
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.01..color = c.glass);
    canvas.drawCircle(center + Offset(-baseR * 0.35, -baseR * 0.4), baseR * 0.18, Paint()..color = c.shine.withValues(alpha: 0.35));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const cols = 6, rows = 6;
    final area = Rect.fromLTWH(w * 0.1, w * 0.1, w * 0.8, w * 0.8);
    final cellW = area.width / cols, cellH = area.height / rows;
    const total = cols * rows;
    final litExact = p * total;
    final lit = litExact.floor();
    final r = math.min(cellW, cellH) * 0.3;
    for (var i = 0; i < total; i++) {
      final row = i ~/ cols, col = i % cols;
      final center = Offset(area.left + cellW * (col + 0.5), area.top + cellH * (row + 0.5));
      if (i < lit) {
        canvas.drawCircle(center, r, Paint()..color = Color.lerp(c.a, c.b, i / total)!);
      } else if (i == lit && lit < total) {
        final partial = litExact - lit;
        final pulse = 0.85 + 0.15 * math.sin(time * 2 * math.pi * 3);
        canvas.drawCircle(center, r * (0.35 + 0.65 * partial) * pulse, Paint()..color = Color.lerp(c.a, c.b, i / total)!);
        canvas.drawCircle(center, r, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.006..color = c.glass);
      } else {
        canvas.drawCircle(center, r, Paint()..color = c.track);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _SpiralPainter extends CustomPainter {
  _SpiralPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    const turns = 3.0;
    const steps = 220;
    final maxR = w * 0.42;
    final pts = [
      for (var i = 0; i <= steps; i++)
        () {
          final t = i / steps;
          final a = t * turns * 2 * math.pi + time * 2 * math.pi * 0.15;
          return center + Offset(math.cos(a), math.sin(a)) * maxR * t;
        }(),
    ];
    final track = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (final o in pts.skip(1)) {
      track.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.018
        ..strokeCap = StrokeCap.round
        ..color = c.track,
    );
    final cut = (pts.length * p).clamp(0, pts.length).floor();
    if (cut > 1) {
      final filled = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < cut; i++) {
        filled.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(
        filled,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.018
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(colors: [c.a, c.b]).createShader(Rect.fromCircle(center: center, radius: maxR)),
      );
      final head = pts[cut - 1];
      canvas.drawCircle(
        head,
        w * 0.03,
        Paint()
          ..color = c.b.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.02),
      );
      canvas.drawCircle(head, w * 0.014, Paint()..color = c.shine);
    }
  }

  @override
  bool shouldRepaint(_SpiralPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _HourglassPainter extends CustomPainter {
  _HourglassPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final top = w * 0.14, bottom = w * 0.86, midY = w * 0.5;
    final left = w * 0.22, right = w * 0.78, neckHalf = w * 0.028;
    final outline = Path()
      ..moveTo(left, top)
      ..lineTo(right, top)
      ..lineTo(w / 2 + neckHalf, midY)
      ..lineTo(right, bottom)
      ..lineTo(left, bottom)
      ..lineTo(w / 2 - neckHalf, midY)
      ..close();
    canvas.drawPath(
      outline,
      Paint()
        ..color = c.a.withValues(alpha: 0.14)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
    );
    canvas.drawPath(outline, Paint()..color = c.glass);
    canvas.save();
    canvas.clipPath(outline);
    // Sand resting at the bottom of the lower bulb, growing as it drains.
    final pileTop = bottom - p * (bottom - midY);
    canvas.drawRect(
      Rect.fromLTRB(0, pileTop, w, bottom + 4),
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.b, c.a])
            .createShader(Rect.fromLTRB(0, pileTop, w, bottom + 4)),
    );
    // Sand left in the upper bulb, resting against the neck, shrinking as it drains.
    final topSandTop = midY - (1 - p) * (midY - top);
    canvas.drawRect(Rect.fromLTRB(0, topSandTop, w, midY + 2), Paint()..color = c.a.withValues(alpha: 0.55));
    if (p > 0.02 && p < 0.98) {
      final rnd = math.Random(3);
      for (var i = 0; i < 6; i++) {
        final speed = 0.8 + rnd.nextDouble() * 0.6;
        final travel = (time * speed + rnd.nextDouble()) % 1.0;
        final y = midY - 7 + travel * 14;
        final x = w / 2 + (rnd.nextDouble() - 0.5) * neckHalf * 1.6;
        canvas.drawCircle(Offset(x, y), w * 0.006, Paint()..color = c.shine.withValues(alpha: 0.8));
      }
    }
    canvas.restore();
    canvas.drawPath(outline, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.022..color = c.glass);
  }

  @override
  bool shouldRepaint(_HourglassPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    final radius = w * 0.36;
    final stroke = w * 0.045;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = c.track);
    final sweep = math.max(p * 2 * math.pi, 0.0001);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: [c.a, c.b]).createShader(rect),
    );
    final angle = time * 2 * math.pi;
    for (var i = 0; i < 8; i++) {
      final trailA = angle - i * 0.12;
      final o = center + Offset(math.cos(trailA), math.sin(trailA)) * radius;
      canvas.drawCircle(o, stroke * 0.5 * (1 - i / 10), Paint()..color = c.shine.withValues(alpha: (1 - i / 8) * 0.5));
    }
    final head = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawCircle(
      head,
      stroke * 0.7,
      Paint()
        ..color = c.b.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.5),
    );
    canvas.drawCircle(head, stroke * 0.34, Paint()..color = c.shine);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    final radius = w * 0.4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.01..color = c.track);
    for (final f in [0.33, 0.66, 1.0]) {
      canvas.drawCircle(center, radius * f, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = c.glass.withValues(alpha: 0.5));
    }
    final progressSweep = math.max(p * 2 * math.pi, 0.0001);
    canvas.drawArc(rect, -math.pi / 2, progressSweep, true, Paint()..color = c.a.withValues(alpha: 0.14));
    final angle = time * 2 * math.pi;
    const trail = 0.5;
    canvas.drawArc(
      rect,
      angle - trail,
      trail,
      true,
      Paint()
        ..shader = SweepGradient(
          colors: [c.b.withValues(alpha: 0), c.b.withValues(alpha: 0.35)],
          startAngle: angle - trail,
          endAngle: angle,
        ).createShader(rect),
    );
    canvas.drawLine(center, center + Offset(math.cos(angle), math.sin(angle)) * radius, Paint()..strokeWidth = w * 0.012..color = c.b);
    canvas.drawCircle(center, w * 0.02, Paint()..color = c.shine);
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    final coreR = w * (0.1 + 0.22 * p);
    final maxR = w * 0.44;
    for (var i = 0; i < 3; i++) {
      final t = (time + i / 3) % 1.0;
      final r = coreR + (maxR - coreR) * t;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.012
          ..color = Color.lerp(c.a, c.b, t)!.withValues(alpha: (1 - t) * 0.4),
      );
    }
    canvas.drawCircle(
      center,
      coreR * 1.1,
      Paint()
        ..color = c.a.withValues(alpha: 0.2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
    );
    canvas.drawCircle(
      center,
      coreR,
      Paint()..shader = RadialGradient(colors: [c.b, c.a]).createShader(Rect.fromCircle(center: center, radius: coreR)),
    );
    canvas.drawCircle(center, coreR, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.01..color = c.glass);
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    final radius = w * 0.36;
    const n = 8;
    final pts = [
      for (var i = 0; i < n; i++) center + Offset(math.cos(-math.pi / 2 + i / n * 2 * math.pi), math.sin(-math.pi / 2 + i / n * 2 * math.pi)) * radius,
    ];
    final litSegments = (p * n).floor();
    for (var i = 0; i < n; i++) {
      final next = (i + 1) % n;
      if (i < litSegments) {
        canvas.drawLine(
          pts[i],
          pts[next],
          Paint()
            ..strokeWidth = w * 0.01
            ..shader = LinearGradient(colors: [c.a, c.b]).createShader(Rect.fromPoints(pts[i], pts[next])),
        );
      } else {
        canvas.drawLine(pts[i], pts[next], Paint()..strokeWidth = w * 0.006..color = c.track);
      }
    }
    for (var i = 0; i < n; i++) {
      final lit = i <= litSegments;
      final twinkle = 0.7 + 0.3 * math.sin(time * 2 * math.pi * 2 + i * 1.7);
      final r = w * (lit ? 0.018 : 0.01) * (lit ? twinkle : 1);
      if (lit) {
        canvas.drawCircle(
          pts[i],
          r * 2,
          Paint()
            ..color = c.b.withValues(alpha: 0.3)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.5),
        );
      }
      canvas.drawCircle(pts[i], r, Paint()..color = lit ? c.shine : c.glass);
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _ClockHandsPainter extends CustomPainter {
  _ClockHandsPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    final radius = w * 0.4;
    canvas.drawCircle(center, radius, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.012..color = c.track);
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * 2 * math.pi;
      final inner = center + Offset(math.cos(a), math.sin(a)) * radius * 0.86;
      final outer = center + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.drawLine(inner, outer, Paint()..strokeWidth = w * 0.01..color = c.glass);
    }
    final angle = -math.pi / 2 + p * 2 * math.pi;
    final tip = center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.78;
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..strokeWidth = w * 0.022
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: [c.a, c.b]).createShader(Rect.fromPoints(center, tip)),
    );
    canvas.drawCircle(
      tip,
      w * 0.03,
      Paint()
        ..color = c.b.withValues(alpha: 0.5 + 0.2 * math.sin(time * 2 * math.pi * 3))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.025),
    );
    canvas.drawCircle(center, w * 0.025, Paint()..color = c.shine);
  }

  @override
  bool shouldRepaint(_ClockHandsPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _BloomPainter extends CustomPainter {
  _BloomPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    const n = 8;
    final maxLen = w * 0.36;
    final rot = time * 2 * math.pi * 0.05;
    for (var i = 0; i < n; i++) {
      final a = i / n * 2 * math.pi + rot;
      final petalP = (p * n - i).clamp(0.0, 1.0);
      if (petalP <= 0) {
        final bud = center + Offset(math.cos(a), math.sin(a)) * maxLen * 0.18;
        canvas.drawCircle(bud, w * 0.012, Paint()..color = c.track);
        continue;
      }
      final len = maxLen * (0.22 + 0.78 * petalP);
      final tip = center + Offset(math.cos(a), math.sin(a)) * len;
      final perp = Offset(-math.sin(a), math.cos(a)) * w * 0.05 * petalP;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(center.dx + perp.dx, center.dy + perp.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(center.dx - perp.dx, center.dy - perp.dy, center.dx, center.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()..shader = LinearGradient(colors: [c.a, c.b]).createShader(Rect.fromCircle(center: center, radius: len)),
      );
    }
    canvas.drawCircle(center, w * 0.05, Paint()..color = c.shine.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_BloomPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const bars = 40;
    final area = Rect.fromLTWH(w * 0.05, w * 0.3, w * 0.9, w * 0.4);
    final gap = area.width * 0.006;
    final bw = (area.width - gap * (bars - 1)) / bars;
    final rnd = math.Random(11);
    final heights = [for (var i = 0; i < bars; i++) 0.25 + rnd.nextDouble() * 0.75];
    final cutX = area.left + area.width * p;
    for (var i = 0; i < bars; i++) {
      final x = area.left + i * (bw + gap);
      final wobble = 1 + 0.06 * math.sin(time * 2 * math.pi * 2 + i * 0.5);
      final h = area.height * heights[i] * wobble;
      final rect = Rect.fromLTWH(x, area.center.dy - h / 2, bw, h);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(bw / 2));
      final filled = x + bw / 2 <= cutX;
      canvas.drawRRect(rr, Paint()..color = filled ? Color.lerp(c.a, c.b, i / bars)! : c.track);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _MinimalBarPainter extends CustomPainter {
  _MinimalBarPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final track = Rect.fromLTWH(w * 0.08, w * 0.46, w * 0.84, w * 0.08);
    final rr = RRect.fromRectAndRadius(track, Radius.circular(track.height / 2));
    canvas.drawRRect(rr, Paint()..color = c.track);
    final fillW = track.width * p;
    if (fillW > 1) {
      final fillRect = Rect.fromLTWH(track.left, track.top, fillW, track.height);
      final frr = RRect.fromRectAndRadius(fillRect, Radius.circular(track.height / 2));
      canvas.drawRRect(frr, Paint()..shader = LinearGradient(colors: [c.a, c.b]).createShader(fillRect));
      canvas.save();
      canvas.clipRRect(frr);
      final shimmerX = track.left + (track.width + track.height) * (time % 1.0) - track.height;
      canvas.drawRect(
        Rect.fromLTWH(shimmerX, track.top - 4, track.height * 0.5, track.height + 8),
        Paint()..color = c.shine.withValues(alpha: 0.4),
      );
      canvas.restore();
      canvas.drawCircle(
        Offset(fillRect.right, track.center.dy),
        track.height * 0.6,
        Paint()
          ..color = c.b.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, track.height * 0.5),
      );
    }
    canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.006..color = c.glass);
  }

  @override
  bool shouldRepaint(_MinimalBarPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final container = Rect.fromLTWH(w * 0.1, w * 0.08, w * 0.8, w * 0.84);
    final rr = RRect.fromRectAndRadius(container, Radius.circular(w * 0.08));
    canvas.drawRRect(rr, Paint()..color = c.track);
    canvas.save();
    canvas.clipRRect(rr);
    final pileTop = container.bottom - container.height * p;
    canvas.drawRect(
      Rect.fromLTRB(container.left, pileTop, container.right, container.bottom),
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.b, c.a])
            .createShader(Rect.fromLTRB(container.left, pileTop, container.right, container.bottom)),
    );
    final rnd = math.Random(5);
    for (var i = 0; i < 16; i++) {
      final speed = 0.4 + rnd.nextDouble() * 0.5;
      final seedX = container.left + container.width * rnd.nextDouble();
      final seedOffset = rnd.nextDouble();
      final travel = (time * speed + seedOffset) % 1.0;
      final y = container.top + travel * container.height;
      if (y > pileTop - 2) continue;
      canvas.save();
      canvas.translate(seedX, y);
      canvas.rotate(time * 6 + i);
      final sz = w * 0.025;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: sz, height: sz * 0.5), Radius.circular(sz * 0.15)),
        Paint()..color = Color.lerp(c.a, c.b, seedOffset)!.withValues(alpha: 0.85),
      );
      canvas.restore();
    }
    canvas.restore();
    canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.01..color = c.glass);
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _StaircasePainter extends CustomPainter {
  _StaircasePainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const steps = 6;
    final area = Rect.fromLTWH(w * 0.12, w * 0.12, w * 0.76, w * 0.76);
    final stepW = area.width / steps, stepH = area.height / steps;
    final pts = <Offset>[Offset(area.left, area.bottom)];
    for (var i = 0; i < steps; i++) {
      final prev = pts.last;
      pts.add(Offset(prev.dx, prev.dy - stepH));
      pts.add(Offset(prev.dx + stepW, prev.dy - stepH));
    }
    final track = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (final o in pts.skip(1)) {
      track.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.022
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = c.track,
    );
    final segLens = <double>[];
    var total = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final d = (pts[i] - pts[i - 1]).distance;
      segLens.add(d);
      total += d;
    }
    var target = total * p;
    var pos = pts[0];
    var i = 0;
    final filled = Path()..moveTo(pts[0].dx, pts[0].dy);
    while (i < segLens.length && target > 0) {
      final segLen = segLens[i];
      if (target >= segLen) {
        pos = pts[i + 1];
        filled.lineTo(pos.dx, pos.dy);
        target -= segLen;
        i++;
      } else {
        pos = Offset.lerp(pts[i], pts[i + 1], target / segLen)!;
        filled.lineTo(pos.dx, pos.dy);
        target = 0;
      }
    }
    canvas.drawPath(
      filled,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.022
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(colors: [c.a, c.b]).createShader(area),
    );
    final bounce = math.sin(time * 2 * math.pi * 2) * w * 0.012;
    final ball = pos + Offset(0, bounce - w * 0.03);
    canvas.drawCircle(
      ball,
      w * 0.035,
      Paint()
        ..color = c.b.withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.02),
    );
    canvas.drawCircle(ball, w * 0.022, Paint()..color = c.shine);
  }

  @override
  bool shouldRepaint(_StaircasePainter old) => old.p != p || old.time != time || old.c.a != c.a;
}

class _ScribblePainter extends CustomPainter {
  _ScribblePainter(this.p, this.time, this.c);

  final double p;
  final double time;
  final _VisualPalette c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    final r = w * 0.32;
    const steps = 160;
    // A Lissajous-style loop: unlike Spiral, it doesn't grow outward with t, it fills a fixed
    // area and crosses over itself, which is what makes it read as a doodle, not a spiral.
    final drift = time * 2 * math.pi * 0.1;
    final pts = [
      for (var i = 0; i <= steps; i++)
        () {
          final t = i / steps * 2 * math.pi * 2.5;
          final x = center.dx + r * 0.85 * math.sin(t + drift);
          final y = center.dy + r * 0.6 * math.sin(t * 1.6 + 0.9 + drift);
          return Offset(x, y);
        }(),
    ];
    final track = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (final o in pts.skip(1)) {
      track.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(track, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.01..color = c.track);
    final cut = (pts.length * p).clamp(0, pts.length).floor();
    if (cut > 1) {
      final filled = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < cut; i++) {
        filled.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(
        filled,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.016
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = LinearGradient(colors: [c.a, c.b]).createShader(Rect.fromCircle(center: center, radius: r)),
      );
      final head = pts[cut - 1];
      canvas.drawCircle(
        head,
        w * 0.03,
        Paint()
          ..color = c.b.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.02),
      );
      canvas.drawCircle(head, w * 0.015, Paint()..color = c.shine);
    }
  }

  @override
  bool shouldRepaint(_ScribblePainter old) => old.p != p || old.time != time || old.c.a != c.a;
}
