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

  static List<DayStat> sampleDaily() {
    final now = DateTime.now();
    const mb = 1024 * 1024;
    const values = [120, 340, 90, 610, 280, 450, 720, 380, 520, 260, 840, 600, 410, 930];
    return [
      for (var i = 0; i < values.length; i++)
        DayStat(now.subtract(Duration(days: values.length - 1 - i)), values[i] * mb, 3),
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
      ChartStyle.bars => _bars(context),
      ChartStyle.line => _line(context, filled: false),
      ChartStyle.area => _line(context, filled: true),
      ChartStyle.donut => _donut(context),
    };
  }

  double _mb(int bytes) => bytes / (1024 * 1024);

  double get _dayInterval => math.max(1, (daily.length / 5).floorToDouble());

  static String _shortMb(double mb) {
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)}G';
    if (mb >= 10 || mb == 0) return '${mb.round()}M';
    return '${mb.toStringAsFixed(1)}M';
  }

  FlTitlesData _titles(BuildContext context) {
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
            return SideTitleWidget(meta: meta, child: Text(_shortMb(v), style: style));
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

  FlGridData _grid(BuildContext context) => FlGridData(
        show: !compact,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
          color: context.colors.onSurface.withValues(alpha: 0.06),
          strokeWidth: 1,
        ),
      );

  Widget _bars(BuildContext context) {
    final t = context.tokens;
    return BarChart(
      BarChartData(
        gridData: _grid(context),
        borderData: FlBorderData(show: false),
        titlesData: _titles(context),
        barTouchData: BarTouchData(
          enabled: !compact,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => context.colors.inverseSurface,
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              formatBytes((rod.toY * 1024 * 1024).round()),
              TextStyle(color: context.colors.onInverseSurface),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < daily.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: _mb(daily[i].savedBytes),
                width: compact ? 5 : 12,
                borderRadius: BorderRadius.circular(t.radiusSm),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [t.liquidA, t.liquidB],
                ),
              ),
            ]),
        ],
      ),
      duration: t.medium,
    );
  }

  Widget _line(BuildContext context, {required bool filled}) {
    final t = context.tokens;
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
            spots: [
              for (var i = 0; i < daily.length; i++) FlSpot(i.toDouble(), _mb(daily[i].savedBytes)),
            ],
            isCurved: true,
            preventCurveOverShooting: true,
            barWidth: compact ? 2.5 : 4,
            gradient: LinearGradient(colors: [t.liquidA, t.liquidB]),
            dotData: FlDotData(show: !compact && !filled),
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

  Widget _donut(BuildContext context) {
    final t = context.tokens;
    final entries = byQuality.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    final palette = [t.liquidA, t.liquidB, context.colors.secondary, context.colors.tertiary, t.warning];
    if (total == 0) {
      return Center(
        child: Text('Nothing saved yet', style: context.text.bodySmall),
      );
    }
    final chart = PieChart(
      PieChartData(
        sectionsSpace: compact ? 2 : 4,
        centerSpaceRadius: compact ? 18 : 56,
        sections: [
          for (var i = 0; i < entries.length; i++)
            PieChartSectionData(
              value: entries[i].value.toDouble(),
              color: palette[i % palette.length],
              radius: compact ? 14 : 34,
              title: compact ? '' : entries[i].key,
              titleStyle: context.text.labelSmall?.copyWith(
                color: context.colors.surface,
                fontWeight: FontWeight.w800,
              ),
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
        Column(
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
                      decoration: BoxDecoration(
                        color: palette[i % palette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: SquishyTokens.space2),
                    Text('${entries[i].key}  ${formatBytes(entries[i].value)}', style: context.text.labelMedium),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
