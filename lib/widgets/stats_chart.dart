import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/format.dart';
import '../core/history_controller.dart';
import '../core/settings.dart';

/// Space-saved chart in the user's chosen style. [compact] hides axes for the
/// small previews on the Personalization screen.
class StatsChart extends StatelessWidget {
  const StatsChart({
    super.key,
    required this.style,
    required this.daily,
    required this.byQuality,
    this.compact = false,
  });

  final ChartStyle style;
  final List<DayStat> daily;
  final Map<String, int> byQuality;
  final bool compact;

  static List<DayStat> sampleDaily({int days = 14}) {
    final now = DateTime.now();
    const mb = 1024 * 1024;
    const values = [120, 340, 90, 610, 280, 0, 720, 380, 520, 260, 840, 600, 0, 930];
    const counts = [1, 3, 1, 4, 2, 0, 5, 2, 4, 2, 6, 4, 0, 7];
    return [
      for (var i = 0; i < days; i++)
        DayStat(
          now.subtract(Duration(days: days - 1 - i)),
          values[(i * 5 + days) % values.length] * mb,
          counts[(i * 5 + days) % counts.length],
        ),
    ];
  }

  static const sampleByQuality = {
    '360p': 900 * 1024 * 1024,
    '480p': 2600 * 1024 * 1024,
    '720p': 1400 * 1024 * 1024,
    '1080p': 500 * 1024 * 1024,
  };

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      ChartStyle.area => _line(context, filled: true),
      ChartStyle.line => _line(context),
      ChartStyle.straight => _line(context, curved: false, dots: true),
      ChartStyle.stepped => _line(context, filled: true, stepped: true),
      ChartStyle.cumulative => _line(context, filled: true, cumulative: true),
      ChartStyle.bubbles => _bubbles(context),
      ChartStyle.bars => _bars(context),
      ChartStyle.capsules => _bars(context, capsules: true),
      ChartStyle.horizontal => _bars(context, sideways: true),
      ChartStyle.videos => _bars(context, videos: true),
      ChartStyle.heatmap => _Heatmap(daily: daily, compact: compact),
      ChartStyle.donut => _pie(context, hole: true),
      ChartStyle.pie => _pie(context, hole: false),
      ChartStyle.gauge => _pie(context, hole: true, half: true),
      ChartStyle.radar => byQuality.length >= 3 ? _radar(context) : _pie(context, hole: true),
    };
  }

  double _mb(int bytes) => bytes / (1024 * 1024);

  double get _dayInterval => math.max(1, (daily.length / 5).floorToDouble());

  static String _shortMb(double mb) {
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)}G';
    if (mb >= 10 || mb == 0) return '${mb.round()}M';
    return '${mb.toStringAsFixed(1)}M';
  }

  /// Quality slices, smallest resolution first.
  List<MapEntry<String, int>> get _qualities {
    int height(String q) => int.tryParse(q.replaceAll(RegExp(r'\D'), '')) ?? 0;
    return byQuality.entries.toList()..sort((a, b) => height(a.key).compareTo(height(b.key)));
  }

  List<Color> _palette(BuildContext context) {
    final t = context.tokens;
    return [t.liquidA, t.liquidB, context.colors.secondary, context.colors.tertiary, t.warning];
  }

  FlTitlesData _titles(BuildContext context, {bool counts = false}) {
    if (compact) return const FlTitlesData(show: false);
    final style = context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant);
    return FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (v, meta) {
            // The auto-added max label collides with the one below it.
            if (v == meta.max && v != 0 && v % meta.appliedInterval != 0) return const SizedBox.shrink();
            if (counts && v != v.roundToDouble()) return const SizedBox.shrink();
            return SideTitleWidget(meta: meta, child: Text(counts ? '${v.round()}' : _shortMb(v), style: style));
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: _dayInterval,
          getTitlesWidget: (v, meta) {
            final i = v.toInt();
            if (i < 0 || i >= daily.length || i % _dayInterval.toInt() != 0) return const SizedBox.shrink();
            final d = daily[i].day;
            return SideTitleWidget(meta: meta, child: Text('${d.day}/${d.month}', style: style));
          },
        ),
      ),
    );
  }

  FlGridData _grid(BuildContext context, {bool vertical = false}) => FlGridData(
        show: !compact,
        drawVerticalLine: vertical,
        drawHorizontalLine: !vertical,
        getDrawingHorizontalLine: (_) => FlLine(color: context.colors.onSurface.withValues(alpha: 0.06), strokeWidth: 1),
        getDrawingVerticalLine: (_) => FlLine(color: context.colors.onSurface.withValues(alpha: 0.06), strokeWidth: 1),
      );

  Widget _bars(BuildContext context, {bool capsules = false, bool sideways = false, bool videos = false}) {
    final t = context.tokens;
    final values = [for (final d in daily) videos ? d.count.toDouble() : _mb(d.savedBytes)];
    final top = values.fold<double>(0, math.max);
    final colors = videos ? [context.colors.secondary, context.colors.tertiary] : [t.liquidA, t.liquidB];
    final width = compact ? (capsules ? 6.0 : 5.0) : (capsules ? 14.0 : 12.0);
    return BarChart(
      BarChartData(
        rotationQuarterTurns: sideways ? 1 : 0,
        gridData: _grid(context),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context, counts: videos),
        maxY: capsules ? top * 1.05 : null,
        barTouchData: BarTouchData(
          enabled: !compact,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => context.colors.inverseSurface,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              videos ? '${rod.toY.round()} videos' : formatBytes((rod.toY * 1024 * 1024).round()),
              TextStyle(color: context.colors.onInverseSurface),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: values[i],
                width: width,
                borderRadius: BorderRadius.circular(capsules ? 99 : t.radiusSm),
                gradient: LinearGradient(
                  begin: sideways ? Alignment.centerLeft : Alignment.bottomCenter,
                  end: sideways ? Alignment.centerRight : Alignment.topCenter,
                  colors: colors,
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: capsules,
                  toY: top * 1.05,
                  color: context.colors.onSurface.withValues(alpha: 0.06),
                ),
              ),
            ]),
        ],
      ),
      duration: t.medium,
    );
  }

  Widget _line(
    BuildContext context, {
    bool filled = false,
    bool curved = true,
    bool dots = false,
    bool stepped = false,
    bool cumulative = false,
  }) {
    final t = context.tokens;
    var total = 0.0;
    final spots = [
      for (var i = 0; i < daily.length; i++)
        FlSpot(i.toDouble(), cumulative ? (total += _mb(daily[i].savedBytes)) : _mb(daily[i].savedBytes)),
    ];
    return LineChart(
      LineChartData(
        gridData: _grid(context),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context),
        minY: 0,
        lineTouchData: LineTouchData(
          enabled: !compact,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => context.colors.inverseSurface,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  formatBytes((s.y * 1024 * 1024).round()),
                  TextStyle(color: context.colors.onInverseSurface),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: curved && !stepped,
            isStepLineChart: stepped,
            preventCurveOverShooting: true,
            barWidth: compact ? 2.5 : 4,
            gradient: LinearGradient(colors: [t.liquidA, t.liquidB]),
            dotData: FlDotData(
              show: dots || (!compact && !filled),
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: compact ? 2.5 : 4,
                color: t.liquidB,
                strokeWidth: compact ? 0 : 2,
                strokeColor: context.colors.surface,
              ),
            ),
            shadow: Shadow(color: t.liquidA.withValues(alpha: 0.5), blurRadius: 10),
            belowBarData: BarAreaData(
              show: filled,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [t.liquidB.withValues(alpha: 0.45), t.liquidA.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ],
      ),
      duration: t.medium,
    );
  }

  Widget _bubbles(BuildContext context) {
    final t = context.tokens;
    final values = [for (final d in daily) _mb(d.savedBytes)];
    final top = math.max(1.0, values.fold<double>(0, math.max));
    final maxRadius = compact ? 7.0 : 16.0;
    return ScatterChart(
      ScatterChartData(
        minX: -0.8,
        maxX: daily.length - 0.2,
        minY: -top * 0.12,
        maxY: top * 1.15,
        gridData: _grid(context),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context),
        scatterTouchData: ScatterTouchData(enabled: false),
        scatterSpots: [
          for (var i = 0; i < values.length; i++)
            ScatterSpot(
              i.toDouble(),
              values[i],
              dotPainter: FlDotCirclePainter(
                radius: math.max(2, maxRadius * math.sqrt(values[i] / top)),
                color: Color.lerp(t.liquidA, t.liquidB, values[i] / top)!.withValues(alpha: 0.75),
                strokeWidth: compact ? 0 : 1.5,
                strokeColor: Color.lerp(t.liquidA, t.liquidB, values[i] / top)!,
              ),
            ),
        ],
      ),
      duration: t.medium,
    );
  }

  Widget _pie(BuildContext context, {required bool hole, bool half = false}) {
    final t = context.tokens;
    final entries = _qualities;
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    final palette = _palette(context);
    if (total == 0) {
      return Center(child: Text('Nothing saved yet', style: context.text.bodySmall));
    }
    final radius = compact ? (hole ? 14.0 : 34.0) : (hole ? 34.0 : 90.0);
    final chart = PieChart(
      PieChartData(
        sectionsSpace: compact ? 2 : 4,
        centerSpaceRadius: hole ? (compact ? 18 : 56) : 0,
        startDegreeOffset: half ? 180 : 270,
        sections: [
          for (var i = 0; i < entries.length; i++)
            PieChartSectionData(
              value: entries[i].value.toDouble(),
              color: palette[i % palette.length],
              radius: radius,
              title: compact
                  ? ''
                  : hole
                      ? entries[i].key
                      : '${entries[i].key}\n${(entries[i].value * 100 / total).round()}%',
              titleStyle: context.text.labelSmall?.copyWith(color: context.colors.surface, fontWeight: FontWeight.w800),
            ),
          // The gauge is a half ring: an invisible slice fills the bottom half.
          if (half) PieChartSectionData(value: total.toDouble(), color: Colors.transparent, radius: radius, title: ''),
        ],
      ),
      duration: t.medium,
    );
    final shaped = half
        ? ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 0.62,
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(alignment: Alignment.center, children: [
                  chart,
                  if (!compact)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        formatBytes(total),
                        style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                ]),
              ),
            ),
          )
        : chart;
    if (compact) return shaped;
    return Row(
      children: [
        Expanded(child: shaped),
        const SizedBox(width: SquishyTokens.space3),
        _Legend(entries: entries, palette: palette),
      ],
    );
  }

  Widget _radar(BuildContext context) {
    final t = context.tokens;
    final entries = _qualities;
    final line = context.colors.onSurface.withValues(alpha: 0.12);
    final chart = RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        radarBackgroundColor: Colors.transparent,
        radarBorderData: BorderSide(color: line),
        gridBorderData: BorderSide(color: line),
        tickBorderData: BorderSide(color: line),
        tickCount: 3,
        ticksTextStyle: const TextStyle(fontSize: 0),
        titlePositionPercentageOffset: 0.12,
        titleTextStyle: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
        getTitle: (i, angle) => RadarChartTitle(text: compact ? '' : entries[i].key),
        radarTouchData: RadarTouchData(enabled: false),
        dataSets: [
          RadarDataSet(
            dataEntries: [for (final e in entries) RadarEntry(value: _mb(e.value))],
            fillColor: t.liquidA.withValues(alpha: 0.3),
            borderColor: t.liquidB,
            borderWidth: compact ? 1.5 : 2.5,
            entryRadius: compact ? 2 : 4,
          ),
        ],
      ),
      duration: t.medium,
    );
    if (compact) return chart;
    return Row(
      children: [
        Expanded(child: chart),
        const SizedBox(width: SquishyTokens.space3),
        _Legend(entries: entries, palette: [t.liquidB]),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.entries, required this.palette});

  final List<MapEntry<String, int>> entries;
  final List<Color> palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: palette[i % palette.length], shape: BoxShape.circle),
                ),
                const SizedBox(width: SquishyTokens.space2),
                Text('${entries[i].key}  ${formatBytes(entries[i].value)}', style: context.text.labelMedium),
              ],
            ),
          ),
      ],
    );
  }
}

/// GitHub-style calendar: one square per day, a column per week, brighter = more saved.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.daily, required this.compact});

  final List<DayStat> daily;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (daily.isEmpty) return const SizedBox.shrink();
    final top = math.max(1, daily.fold<int>(0, (m, d) => math.max(m, d.savedBytes)));
    // Rows are weekdays (Mon–Sun); the first column starts on the first day's weekday.
    final offset = daily.first.day.weekday - 1;
    final weeks = ((offset + daily.length) / 7).ceil();
    final empty = context.colors.onSurface.withValues(alpha: 0.06);
    Color colorFor(DayStat d) => d.savedBytes == 0
        ? empty
        : Color.lerp(t.liquidA, t.liquidB, d.savedBytes / top)!.withValues(alpha: 0.25 + 0.75 * d.savedBytes / top);
    final grid = LayoutBuilder(builder: (context, c) {
      final gap = compact ? 2.0 : 4.0;
      final cell = math.min((c.maxWidth - gap * (weeks - 1)) / weeks, (c.maxHeight - gap * 6) / 7);
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var w = 0; w < weeks; w++) ...[
              if (w > 0) SizedBox(width: gap),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var d = 0; d < 7; d++) ...[
                    if (d > 0) SizedBox(height: gap),
                    Builder(builder: (context) {
                      final i = w * 7 + d - offset;
                      final day = i >= 0 && i < daily.length ? daily[i] : null;
                      final box = Container(
                        width: cell,
                        height: cell,
                        decoration: BoxDecoration(
                          color: day == null ? Colors.transparent : colorFor(day),
                          borderRadius: BorderRadius.circular(cell * 0.25),
                        ),
                      );
                      if (day == null || compact) return box;
                      return Tooltip(
                        message: '${day.day.day}/${day.day.month}: ${formatBytes(day.savedBytes)} · ${day.count} videos',
                        child: box,
                      );
                    }),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    });
    if (compact) return grid;
    final label = context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant);
    return Column(
      children: [
        Expanded(child: grid),
        const SizedBox(height: SquishyTokens.space2),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less', style: label),
            const SizedBox(width: SquishyTokens.space1),
            for (final f in [0.0, 0.33, 0.66, 1.0])
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: f == 0 ? empty : Color.lerp(t.liquidA, t.liquidB, f)!.withValues(alpha: 0.25 + 0.75 * f),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: SquishyTokens.space1),
            Text('More', style: label),
          ],
        ),
      ],
    );
  }
}
