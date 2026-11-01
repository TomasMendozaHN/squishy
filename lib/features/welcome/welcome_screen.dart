import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../core/settings.dart';
import '../../widgets/common.dart';
import '../../widgets/progress_visuals.dart';
import '../../widgets/squishy_logo.dart';
import '../shell/home_shell.dart';
import 'permissions_panel.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pager = PageController();
  int _page = 0;
  bool _storageGranted = false;
  static const _pages = 4;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages - 1) {
      _pager.nextPage(duration: context.tokens.slow, curve: Curves.easeInOutCubic);
      return;
    }
    context.scope.settings.onboarded = true;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(); // replayed from Settings
    } else {
      nav.pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages - 1;
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pager,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    const _IntroPage(
                      art: SquishyLogo(size: 190),
                      title: 'Meet Squishy',
                      body: 'Squeezes huge videos into tiny ones, without making them look squished.',
                    ),
                    const _IntroPage(
                      art: _LoopingTank(),
                      title: 'Fill it up',
                      body: 'Pick a whole folder and let it work. It keeps going in the background, '
                          'with the screen off, until every video is done.',
                    ),
                    _IntroPage(
                      art: _CutArt(),
                      title: 'Cut & stitch',
                      body: 'Keep only the good bits. Cut as many segments as you like and '
                          'Squishy joins them into one clean video.',
                    ),
                    _PermissionsPage(onStorageChanged: (v) => setState(() => _storageGranted = v)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(SquishyTokens.space5),
                child: Column(
                  children: [
                    _Dots(count: _pages, index: _page),
                    const SizedBox(height: SquishyTokens.space5),
                    GradientButton(
                      label: last ? "Let's squish" : 'Next',
                      icon: last ? Icons.compress_rounded : Icons.arrow_forward_rounded,
                      onPressed: last && !_storageGranted ? null : _next,
                    ),
                    if (last && !_storageGranted)
                      Padding(
                        padding: const EdgeInsets.only(top: SquishyTokens.space2),
                        child: Text(
                          'Grant "All files access" to continue',
                          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.art, required this.title, required this.body});

  final Widget art;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 240, child: Center(child: art))
              .animate()
              .scale(begin: const Offset(0.85, 0.85), duration: context.tokens.slow, curve: Curves.easeOutBack)
              .fadeIn(),
          const SizedBox(height: SquishyTokens.space6),
          Text(
            title,
            style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: SquishyTokens.space3),
          Text(
            body,
            style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ).animate(delay: 220.ms).fadeIn().slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }
}

class _PermissionsPage extends StatelessWidget {
  const _PermissionsPage({required this.onStorageChanged});

  final ValueChanged<bool> onStorageChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SquishyTokens.space5),
      children: [
        Text(
          'Never get killed',
          style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ).animate().fadeIn().slideY(begin: 0.3, end: 0),
        const SizedBox(height: SquishyTokens.space2),
        Text(
          'A few switches so Squishy can find your videos and keep working while you do other things.',
          style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: SquishyTokens.space5),
        PermissionsPanel(onStorageChanged: onStorageChanged),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: t.medium,
            curve: t.curve,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              gradient: i == index ? t.liquidGradient : null,
              color: i == index ? null : context.colors.onSurface.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ],
    );
  }
}

/// Water tank that keeps filling and draining, for the intro.
class _LoopingTank extends StatefulWidget {
  const _LoopingTank();

  @override
  State<_LoopingTank> createState() => _LoopingTankState();
}

class _LoopingTankState extends State<_LoopingTank> {
  double _p = 0.15;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      setState(() => _p = _p >= 0.95 ? 0.1 : _p + 0.12);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ProgressVisual(style: ProgressStyle.waterTank, progress: _p, size: 230);
}

class _CutArt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget clip(double w, Color c, int i) => Container(
          width: w,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(t.radiusSm),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .slideX(begin: i.isEven ? -0.15 : 0.15, end: 0, duration: 1200.ms, curve: Curves.easeInOut);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.content_cut_rounded, size: 64, color: t.liquidB)
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .rotate(begin: -0.04, end: 0.04, duration: 600.ms),
        const SizedBox(height: SquishyTokens.space5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            clip(60, t.liquidA, 0),
            clip(40, t.liquidB, 1),
            clip(72, t.liquidA.withValues(alpha: 0.7), 2),
          ],
        ),
      ],
    );
  }
}
