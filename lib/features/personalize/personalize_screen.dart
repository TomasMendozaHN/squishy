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

/// Every look-and-feel option, each shown as a live preview card, one tab per topic.
class PersonalizeScreen extends StatelessWidget {
  const PersonalizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, SquishyTokens.space4, SquishyTokens.space4, 0),
            child: Text('Make it yours', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(icon: Icon(Icons.palette_rounded), text: 'Colors'),
              Tab(icon: Icon(Icons.water_drop_rounded), text: 'Progress'),
              Tab(icon: Icon(Icons.insights_rounded), text: 'Charts'),
              Tab(icon: Icon(Icons.text_fields_rounded), text: 'Fonts'),
              Tab(icon: Icon(Icons.dashboard_customize_rounded), text: 'Layout'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [_ColorsTab(), _ProgressTab(), _ChartsTab(), _FontsTab(), _LayoutTab()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tab's scrolling grid of option cards; cards are built lazily as they scroll in.
class _OptionGrid extends StatelessWidget {
  const _OptionGrid({
    required this.count,
    required this.itemBuilder,
    this.header = const [],
    this.aspect = 0.82,
    this.minWidth = 190,
  });

  final int count;
  final Widget Function(BuildContext context, int i) itemBuilder;
  final List<Widget> header;
  final double aspect;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: context.scope.settings,
      builder: (context, _) => LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / minWidth).floor().clamp(2, 6);
        return CustomScrollView(
          slivers: [
            SliverList.list(children: header),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space4),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: SquishyTokens.space3,
                  crossAxisSpacing: SquishyTokens.space3,
                  childAspectRatio: aspect,
                ),
                itemCount: count,
                itemBuilder: (context, i) => itemBuilder(context, i)
                    .animate(delay: (25 * (i % 12)).ms)
                    .fadeIn(duration: context.tokens.medium)
                    .scaleXY(begin: 0.94, end: 1),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: SquishyTokens.space7)),
          ],
        );
      }),
    );
  }
}

enum _Shade { all, dark, light }

class _ColorsTab extends StatefulWidget {
  const _ColorsTab();

  @override
  State<_ColorsTab> createState() => _ColorsTabState();
}

class _ColorsTabState extends State<_ColorsTab> {
  var _shade = _Shade.all;

  @override
  Widget build(BuildContext context) {
    final s = context.scope.settings;
    final themes = Themes.all
        .where((t) => _shade == _Shade.all || t.isDark == (_shade == _Shade.dark))
        .toList();
    // Custom and Follow system come first.
    return _OptionGrid(
      count: themes.length + 2,
      aspect: 0.6,
      minWidth: 120,
      header: [
        SectionHeader('Theme', subtitle: '${Themes.all.length} palettes, or make your own'),
        Padding(
          padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, 0, SquishyTokens.space4, SquishyTokens.space3),
          child: SegmentedButton<_Shade>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _Shade.all, label: Text('All')),
              ButtonSegment(value: _Shade.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
              ButtonSegment(value: _Shade.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
            ],
            selected: {_shade},
            onSelectionChanged: (v) => setState(() => _shade = v.first),
          ),
        ),
      ],
      itemBuilder: (context, i) {
        if (i == 0) {
          return _ThemeCard(
            id: Themes.customId,
            label: 'Custom',
            palettes: [s.customPalette],
            selected: s.themeId == Themes.customId,
            onTap: () {
              s.themeId = Themes.customId;
              _showCustomEditor(context);
            },
            trailing: Icons.tune_rounded,
          );
        }
        if (i == 1) {
          return _ThemeCard(
            id: Themes.followSystemId,
            label: 'Follow system',
            palettes: [Themes.systemLight, Themes.systemDark],
            selected: s.followsSystem,
            onTap: () => s.themeId = Themes.followSystemId,
          );
        }
        final t = themes[i - 2];
        return _ThemeCard(
          id: t.id,
          label: t.label,
          palettes: [t.palette],
          selected: s.themeId == t.id,
          onTap: () => s.themeId = t.id,
        );
      },
    );
  }
}

void _showCustomEditor(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _CustomThemeEditor(),
  );
}

class _CustomThemeEditor extends StatelessWidget {
  const _CustomThemeEditor();

  @override
  Widget build(BuildContext context) {
    final s = context.scope.settings;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        Widget swatches(Color selected, ValueChanged<Color> onPick) => Wrap(
              spacing: SquishyTokens.space2,
              runSpacing: SquishyTokens.space2,
              children: [
                for (final c in Themes.swatches)
                  Semantics(
                    button: true,
                    selected: c == selected,
                    child: InkWell(
                      onTap: () => onPick(c),
                      customBorder: const CircleBorder(),
                      child: AnimatedContainer(
                        duration: context.tokens.fast,
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c == selected ? context.colors.onSurface : context.tokens.glassBorder,
                            width: c == selected ? 3 : 1,
                          ),
                        ),
                        child: c == selected
                            ? Icon(Icons.check_rounded, size: 18, color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                            : null,
                      ),
                    ),
                  ),
              ],
            );
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, 0, SquishyTokens.space4, SquishyTokens.space5),
          children: [
            Text('Your own theme', style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: SquishyTokens.space1),
            Text(
              'Squishy works out the rest so text stays readable.',
              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: SquishyTokens.space4),
            SizedBox(
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(context.tokens.radiusMd),
                child: Theme(data: _themeFor(context, 'custom-live', s.customPalette), child: const _MiniMock()),
              ),
            ),
            const SizedBox(height: SquishyTokens.space4),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
                ButtonSegment(value: false, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
              ],
              selected: {s.customDark},
              onSelectionChanged: (v) => s.customDark = v.first,
            ),
            const SizedBox(height: SquishyTokens.space4),
            Text('Main color', style: context.text.titleSmall),
            const SizedBox(height: SquishyTokens.space2),
            swatches(s.customMain, (c) => s.customMain = c),
            const SizedBox(height: SquishyTokens.space4),
            Text('Accent color', style: context.text.titleSmall),
            const SizedBox(height: SquishyTokens.space2),
            swatches(s.customAccent, (c) => s.customAccent = c),
          ],
        );
      },
    );
  }
}

/// Theme previews are cached: building a ThemeData (with its Google Font) per card on every
/// rebuild would make the 40+ card grid stutter.
final _themeCache = <String, ThemeData>{};

ThemeData _themeFor(BuildContext context, String id, PresetPalette palette) {
  final s = context.scope.settings;
  if (id.startsWith('custom')) {
    return buildTheme(palette: palette, corners: s.corners, font: s.font, reduceMotion: true);
  }
  final key = '$id|${palette.brightness.name}|${s.corners.name}|${s.font.name}';
  return _themeCache[key] ??= buildTheme(palette: palette, corners: s.corners, font: s.font, reduceMotion: true);
}

class _ProgressTab extends StatelessWidget {
  const _ProgressTab();

  @override
  Widget build(BuildContext context) {
    final s = context.scope.settings;
    return _OptionGrid(
      count: ProgressStyle.values.length,
      header: const [SectionHeader('Progress animation', subtitle: 'What you watch while it squishes')],
      itemBuilder: (context, i) {
        final p = ProgressStyle.values[i];
        return _OptionCard(
          selected: s.progressStyle == p,
          onTap: () => s.progressStyle = p,
          title: p.label,
          hint: p.hint,
          preview: FittedBox(child: ProgressVisual(style: p, progress: 0.62, size: 160, showLabel: false)),
        );
      },
    );
  }
}

class _ChartsTab extends StatelessWidget {
  const _ChartsTab();

  @override
  Widget build(BuildContext context) {
    final s = context.scope.settings;
    return _OptionGrid(
      count: ChartStyle.values.length,
      minWidth: 120,
      aspect: 0.78,
      header: [
        SectionHeader('Chart style', subtitle: '${ChartStyle.values.length} ways to see History › Stats'),
      ],
      itemBuilder: (context, i) {
        final c = ChartStyle.values[i];
        return _OptionCard(
          selected: s.chartStyle == c,
          onTap: () => s.chartStyle = c,
          title: c.label,
          hint: c.hint,
          preview: Padding(
            padding: const EdgeInsets.all(SquishyTokens.space2),
            child: StatsChart(
              style: c,
              daily: StatsChart.sampleDaily(days: c == ChartStyle.heatmap ? 42 : 14),
              byQuality: StatsChart.sampleByQuality,
              compact: true,
            ),
          ),
        );
      },
    );
  }
}

class _FontsTab extends StatelessWidget {
  const _FontsTab();

  @override
  Widget build(BuildContext context) {
    final s = context.scope.settings;
    return _OptionGrid(
      count: AppFont.values.length,
      aspect: 1.05,
      header: const [SectionHeader('Font', subtitle: 'Used everywhere in the app')],
      itemBuilder: (context, i) {
        final f = AppFont.values[i];
        return _OptionCard(
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
        );
      },
    );
  }
}

class _LayoutTab extends StatelessWidget {
  const _LayoutTab();

  @override
  Widget build(BuildContext context) {
    final s = context.scope.settings;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / 190).floor().clamp(2, 5);
        Widget grid(List<Widget> children) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space4),
              crossAxisCount: cols,
              mainAxisSpacing: SquishyTokens.space3,
              crossAxisSpacing: SquishyTokens.space3,
              childAspectRatio: 1.05,
              children: [
                for (var i = 0; i < children.length; i++)
                  children[i].animate(delay: (40 * i).ms).fadeIn(duration: context.tokens.medium).scaleXY(begin: 0.94, end: 1),
              ],
            );
        return ListView(
          padding: const EdgeInsets.only(bottom: SquishyTokens.space7),
          children: [
            const SectionHeader('File view', subtitle: 'How videos are listed in Files'),
            grid([
              for (final m in ViewMode.values)
                ViewModePreviewCard(mode: m, selected: s.viewMode == m, onTap: () => s.viewMode = m),
            ]),
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
            ]),
            const SectionHeader('Motion'),
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
    this.hint,
    required this.preview,
    this.trailing,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;

  /// Without a hint the title may take two lines (theme names in a dense grid).
  final String? hint;
  final Widget preview;
  final IconData? trailing;

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
              Expanded(
                child: Text(
                  title,
                  style: hint == null ? context.text.labelLarge : context.text.titleSmall,
                  maxLines: hint == null ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) Icon(trailing, size: 18, color: context.colors.onSurfaceVariant),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: context.tokens.fast,
                curve: Curves.easeOutBack,
                child: Icon(Icons.check_circle_rounded, size: 18, color: context.colors.primary),
              ),
            ],
          ),
          if (hint != null)
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// A miniature of the real UI rendered with the theme's own colors. Two palettes (light and
/// dark) are shown side by side.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.id,
    required this.label,
    required this.palettes,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String id;
  final String label;
  final List<PresetPalette> palettes;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final mock = Row(
      children: [
        for (final p in palettes)
          Expanded(child: Theme(data: _themeFor(context, id, p), child: const _MiniMock())),
      ],
    );
    return _OptionCard(
      selected: selected,
      onTap: onTap,
      title: label,
      trailing: trailing,
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
            Flexible(child: line(36)),
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
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [line(18), const SizedBox(height: 4), line(12), const SizedBox(height: 4), line(16)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(gradient: t.liquidGradient, borderRadius: BorderRadius.circular(t.radiusSm)),
                ),
              ),
              const SizedBox(width: 4),
              Container(width: 12, height: 12, decoration: BoxDecoration(color: context.colors.secondary, shape: BoxShape.circle)),
            ],
          ),
        ],
      ),
    );
  }
}
