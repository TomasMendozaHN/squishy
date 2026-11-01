import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/squishy_logo.dart';
import '../shell/home_shell.dart';
import '../welcome/welcome_screen.dart';

/// Animated intro shown after the system splash while the app warms up.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2100), _next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _next() {
    if (!mounted) return;
    final onboarded = context.scope.settings.onboarded;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 650),
      pageBuilder: (_, _, _) => onboarded ? const HomeShell() : const WelcomeScreen(),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 1.04, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const word = 'Squishy';
    return Scaffold(
      body: AmbientBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SquishyLogo(size: 150)
                  .animate()
                  .scale(begin: const Offset(0.2, 0.2), duration: 900.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 300.ms),
              const SizedBox(height: SquishyTokens.space5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < word.length; i++)
                    Text(
                      word[i],
                      style: context.text.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                    )
                        .animate(delay: (350 + i * 70).ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.8, end: 0, curve: Curves.easeOutBack, duration: 500.ms),
                ],
              ),
              const SizedBox(height: SquishyTokens.space2),
              Text(
                'Big videos in. Tiny videos out.',
                style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
              ).animate(delay: 900.ms).fadeIn(duration: 400.ms),
              const SizedBox(height: SquishyTokens.space6),
              SizedBox(
                width: 140,
                height: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Stack(
                    children: [
                      Container(color: context.colors.onSurface.withValues(alpha: 0.08)),
                      Container(decoration: BoxDecoration(gradient: t.liquidGradient))
                          .animate(delay: 700.ms)
                          .scaleX(begin: 0, end: 1, alignment: Alignment.centerLeft, duration: 1300.ms, curve: Curves.easeInOutCubic),
                    ],
                  ),
                ),
              ).animate(delay: 600.ms).fadeIn(),
            ],
          ),
        ),
      ),
    );
  }
}
