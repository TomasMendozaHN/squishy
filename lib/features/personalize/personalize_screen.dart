import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../app/theme_presets.dart';
import '../../core/settings.dart';
import '../../widgets/common.dart';
import '../../widgets/progress_visuals.dart';
import '../../widgets/stats_chart.dart';
import '../browser/browser_screen.dart';

/// Every look-and-feel option, each shown as a live preview card.
class PersonalizeScreen extends StatelessWidget {
  const PersonalizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.scope.settings;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / 190).floor().clamp(2, 5);
        Widget grid(List<Widget> children, {double aspect = 0.82}) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space4),
              crossAxisCount: cols,
              mainAxisSpacing: SquishyTokens.space3,
              crossAxisSpacing: SquishyTokens.space3,
              childAspectRatio: aspect,
              children: [
                for (var i = 0; i < children.length; i++)
                  children[i].animate(delay: (40 * i).ms).fadeIn(duration: context.tokens.medium).scaleXY(begin: 0.94, end: 1),
              ],
            );
        return ListView(
          padding: const EdgeInsets.only(bottom: SquishyTokens.space7),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, SquishyTokens.space4, SquishyTokens.space4, 0),
              child: Text('Make it yours', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SectionHeader('Theme', subtitle: 'Colors for the whole app'),
            grid([
              for (final p in ThemePreset.values)
                _ThemeCard(preset: p, selected: s.themePreset == p, onTap: () => s.themePreset = p),
            ], aspect: 0.62),
            const SectionHeader('Progress animation', subtitle: 'What you watch while it squishes'),
            grid([
              for (final p in ProgressStyle.values)
                _OptionCard(
                  selected: s.progressStyle == p,
                  onTap: () => s.progressStyle = p,
                  title: p.label,
                  hint: p.hint,
                  preview: FittedBox(child: ProgressVisual(style: p, progress: 0.62, size: 160, showLabel: false)),
                ),
            ]),
            const SectionHeader('Chart style', subtitle: 'How History › Stats looks'),
            grid([
              for (final c in ChartStyle.values)
                _OptionCard(
                  selected: s.chartStyle == c,
                  onTap: () => s.chartStyle = c,
                  title: c.label,
                  hint: c.hint,
                  preview: Padding(
                    padding: const EdgeInsets.all(SquishyTokens.space2),
                    child: StatsChart(
                      style: c,
                      daily: StatsChart.sampleDaily(),
                      byQuality: StatsChart.sampleByQuality,
                      compact: true,
                    ),
                  ),
                ),
            ]),
            const SectionHeader('File view', subtitle: 'How videos are listed in Files'),
            grid([
              for (final m in ViewMode.values)
                ViewModePreviewCard(mode: m, selected: s.viewMode == m, onTap: () => s.viewMode = m),
            ], aspect: 1.05),
            const SectionHeader('Font'),
            grid([
              for (final f in AppFont.values)
                _OptionCard(
                  selected: s.font == f,
                  onTap: () => s.font = f,
                  title: f.family,
                  hint: 'Squishy squeezes',
                  preview: Center(
                    child: Text(
                      'Aa',
                      style: GoogleFonts.getFont(f.family, fontSize: 44, fontWeight: FontWeight.w700, color: context.colors.onSurface),
                    ),
                  ),
                ),
            ], aspect: 1.05),
            const SectionHeader('Corners'),
            grid([
              for (final cs in CornerStyle.values)
                _OptionCard(
                  selected: s.corners == cs,
                  onTap: () => s.corners = cs,
                  title: cs.label,
                  hint: '${cs.base.round()} px radius',
                  preview: Center(
                    child: Container(
                      width: 70,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: context.tokens.liquidGradient,
                        borderRadius: BorderRadius.circular(cs.base),
                      ),
                    ),
                  ),
                ),
            ], aspect: 1.05),
            const SizedBox(height: SquishyTokens.space4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space4),
              child: GlassCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  value: s.reduceMotion,
                  onChanged: (v) => s.reduceMotion = v,
                  title: const Text('Reduce motion'),
                  subtitle: const Text('Calmer transitions, static liquids'),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.hint,
    required this.preview,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String hint;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(SquishyTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: IgnorePointer(child: preview)),
          const SizedBox(height: SquishyTokens.space2),
          Row(
            children: [
              Expanded(child: Text(title, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: context.tokens.fast,
                curve: Curves.easeOutBack,
                child: Icon(Icons.check_circle_rounded, size: 18, color: context.colors.primary),
              ),
            ],
          ),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A miniature of the real UI rendered with the preset's own theme.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.preset, required this.selected, required this.onTap});

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.scope.settings;
    ThemeData themeOf(Brightness b) => buildTheme(
          palette: preset.palette(b),
          corners: s.corners,
          font: s.font,
          reduceMotion: true,
        );
    final mock = preset == ThemePreset.followSystem
        ? Row(
            children: [
              Expanded(child: Theme(data: themeOf(Brightness.light), child: const _MiniMock())),
              Expanded(child: Theme(data: themeOf(Brightness.dark), child: const _MiniMock())),
            ],
          )
        : Theme(data: themeOf(Brightness.dark), child: const _MiniMock());
    return _OptionCard(
      selected: selected,
      onTap: onTap,
      title: preset.label,
      hint: preset.hint,
      preview: ClipRRect(borderRadius: BorderRadius.circular(context.tokens.radiusSm), child: mock),
    );
  }
}

class _MiniMock extends StatelessWidget {
  const _MiniMock();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bar = context.colors.onSurface.withValues(alpha: 0.14);
    Widget line(double w) => Container(
          width: w,
          height: 5,
          decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(3)),
        );
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(gradient: t.liquidGradient, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            line(36),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: t.glass,
                border: Border.all(color: t.glassBorder),
                borderRadius: BorderRadius.circular(t.radiusSm),
              ),
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.colors.onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(t.radiusSm * 0.6),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: 0.6,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [t.liquidA, t.liquidB],
                            ),
                            borderRadius: BorderRadius.circular(t.radiusSm * 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [line(18), const SizedBox(height: 4), line(12), const SizedBox(height: 4), line(16)],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 12,
            decoration: BoxDecoration(gradient: t.liquidGradient, borderRadius: BorderRadius.circular(t.radiusSm)),
          ),
        ],
      ),
    );
  }
}
