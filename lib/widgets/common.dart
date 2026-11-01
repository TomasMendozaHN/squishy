import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app/theme.dart';

/// Frosted surface used for most cards.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SquishyTokens.space4),
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.radius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = BorderRadius.circular(radius ?? t.radiusMd);
    return AnimatedContainer(
      duration: t.fast,
      curve: t.curve,
      decoration: BoxDecoration(
        color: selected ? context.colors.primary.withValues(alpha: 0.12) : t.glass,
        borderRadius: r,
        border: Border.all(
          color: selected ? context.colors.primary : t.glassBorder,
          width: selected ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Primary call-to-action with the theme's liquid gradient and a press squish.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = widget.onPressed != null;
    final onLiquid = ThemeData.estimateBrightnessForColor(t.liquidA) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              widget.onPressed!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: t.fast,
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.45,
          duration: t.fast,
          child: Container(
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(
              horizontal: SquishyTokens.space5,
              vertical: SquishyTokens.space4,
            ),
            decoration: BoxDecoration(
              gradient: t.liquidGradient,
              borderRadius: BorderRadius.circular(t.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: t.liquidA.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: onLiquid, size: 20),
                  const SizedBox(width: SquishyTokens.space2),
                ],
                Text(
                  widget.label,
                  style: context.text.titleMedium?.copyWith(
                    color: onLiquid,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SquishyTokens.space4,
        SquishyTokens.space5,
        SquishyTokens.space4,
        SquishyTokens.space3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A big friendly empty/permission state.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final Widget icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SquishyTokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon.animate().scale(
                  begin: const Offset(0.6, 0.6),
                  duration: context.tokens.slow,
                  curve: Curves.elasticOut,
                ),
            const SizedBox(height: SquishyTokens.space5),
            Text(title, style: context.text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: SquishyTokens.space2),
            Text(
              message,
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: SquishyTokens.space5),
              action!,
            ],
          ],
        ).animate().fadeIn(duration: context.tokens.medium).slideY(begin: 0.08, end: 0),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space2, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 3),
          ],
          Text(label, style: context.text.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Soft gradient blobs drifting behind a screen.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduce = t.reduceMotion;
    Widget orb(Color c, double size) => IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [c.withValues(alpha: 0.22), c.withValues(alpha: 0)]),
            ),
          ),
        );
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -80,
          child: reduce
              ? orb(t.liquidA, 340)
              : orb(t.liquidA, 340)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .move(begin: Offset.zero, end: const Offset(-30, 40), duration: 7.seconds, curve: Curves.easeInOut),
        ),
        Positioned(
          bottom: -140,
          left: -100,
          child: reduce
              ? orb(t.liquidB, 380)
              : orb(t.liquidB, 380)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .move(begin: Offset.zero, end: const Offset(40, -30), duration: 9.seconds, curve: Curves.easeInOut),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
