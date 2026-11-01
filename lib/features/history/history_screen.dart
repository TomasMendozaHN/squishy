import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/nas.dart';
import '../../widgets/common.dart';
import '../../widgets/share_actions.dart';
import '../../widgets/stats_chart.dart';

enum _Filter { all, squished, failed }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final scope = context.scope;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, SquishyTokens.space4, SquishyTokens.space2, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('History', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: 'Clear log',
                  icon: const Icon(Icons.delete_sweep_rounded),
                  onPressed: () => _confirmClear(context),
                ),
              ],
            ),
          ),
          const TabBar(tabs: [Tab(text: 'Log'), Tab(text: 'Stats')]),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([scope.history, scope.settings]),
              builder: (context, _) => TabBarView(
                children: [_log(context), _stats(context)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final history = context.scope.history;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear the log?'),
        content: const Text('This only forgets the history. Your videos are not touched.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) history.clear();
  }

  Widget _log(BuildContext context) {
    final history = context.scope.history;
    final entries = switch (_filter) {
      _Filter.all => history.entries,
      _Filter.squished => history.successes,
      _Filter.failed => history.failures,
    };
    return RefreshIndicator(
      onRefresh: history.reload,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(SquishyTokens.space4),
              child: SegmentedButton<_Filter>(
                segments: [
                  ButtonSegment(value: _Filter.all, label: Text('All ${history.entries.length}')),
                  ButtonSegment(value: _Filter.squished, label: Text('Squished ${history.successes.length}')),
                  ButtonSegment(value: _Filter.failed, label: Text('Failed ${history.failures.length}')),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ),
          ),
          if (entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icon(Icons.receipt_long_rounded, size: 64, color: context.tokens.liquidA),
                title: history.loading ? 'Loading…' : 'Nothing here yet',
                message: 'Every squished or failed video gets logged here.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, 0, SquishyTokens.space4, SquishyTokens.space6),
              sliver: SliverList.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: SquishyTokens.space2),
                itemBuilder: (context, i) => _LogTile(entry: entries[i])
                    .animate()
                    .fadeIn(delay: (25 * i.clamp(0, 14)).ms, duration: context.tokens.medium)
                    .slideX(begin: 0.05, end: 0),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stats(BuildContext context) {
    final scope = context.scope;
    final history = scope.history;
    final t = context.tokens;
    final tiles = [
      _StatTile(label: 'Squished', value: '${history.successes.length}', icon: Icons.check_circle_rounded, color: t.success),
      _StatTile(label: 'Space saved', value: formatBytes(history.savedBytes), icon: Icons.savings_rounded, color: t.liquidA),
      _StatTile(
        label: 'Avg. smaller',
        value: formatPercent(history.averageReduction),
        icon: Icons.compress_rounded,
        color: t.liquidB,
      ),
      _StatTile(label: 'Failed', value: '${history.failures.length}', icon: Icons.error_rounded, color: t.danger),
    ];
    return ListView(
      padding: const EdgeInsets.all(SquishyTokens.space4),
      children: [
        LayoutBuilder(
          builder: (context, c) => GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: c.maxWidth > 600 ? 4 : 2,
            mainAxisSpacing: SquishyTokens.space2,
            crossAxisSpacing: SquishyTokens.space2,
            childAspectRatio: 1.8,
            children: [
              for (var i = 0; i < tiles.length; i++)
                tiles[i].animate(delay: (60 * i).ms).fadeIn().scaleXY(begin: 0.9, end: 1, curve: Curves.easeOutBack),
            ],
          ),
        ),
        const SizedBox(height: SquishyTokens.space4),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(scope.settings.chartStyle.hint, style: context.text.titleMedium),
              Text(
                'Last 14 days · change the chart style in Style',
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: SquishyTokens.space4),
              SizedBox(
                height: 240,
                child: StatsChart(
                  style: scope.settings.chartStyle,
                  daily: history.daily(),
                  byQuality: history.savedByQuality(),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1, end: 0),
        const _NasStatsSection(),
      ],
    );
  }
}

/// All-time savings per NAS and per library folder, read from each NAS's ledger.
class _NasStatsSection extends StatelessWidget {
  const _NasStatsSection();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FutureBuilder<List<NasServerInfo>>(
      future: NasNative.servers(),
      builder: (context, snap) {
        final servers = snap.data ?? const [];
        if (servers.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: SquishyTokens.space4),
            Text('Network (NAS)', style: context.text.titleLarge),
            const SizedBox(height: SquishyTokens.space2),
            for (final s in servers)
              Padding(
                padding: const EdgeInsets.only(bottom: SquishyTokens.space3),
                child: GlassCard(
                  child: FutureBuilder<NasStats>(
                    future: NasNative.stats(s.id),
                    builder: (context, st) {
                      final stats = st.data;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.dns_rounded, color: t.liquidA),
                              const SizedBox(width: SquishyTokens.space2),
                              Expanded(child: Text(s.name, style: context.text.titleMedium)),
                              if (stats != null)
                                Text(formatBytes(stats.saved), style: context.text.titleMedium?.copyWith(color: t.success, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: SquishyTokens.space2),
                          if (st.hasError)
                            Text("Can't reach it right now", style: context.text.bodySmall?.copyWith(color: t.warning))
                          else if (stats == null)
                            const LinearProgressIndicator()
                          else if (stats.folders.isEmpty)
                            Text('Nothing squished yet', style: context.text.bodySmall)
                          else
                            for (final e in stats.folders.entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(e.key, style: context.text.bodyMedium)),
                                    Text(
                                      '${e.value.files} file${e.value.files == 1 ? '' : 's'} · ${formatBytes(e.value.saved)}'
                                      '${e.value.failed > 0 ? ' · ${e.value.failed} failed' : ''}',
                                      style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(SquishyTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: SquishyTokens.space1 + 2),
              Text(label, style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ok = entry.success;
    return GlassCard(
      // Squished videos play on tap; the info button shows the details.
      onTap: ok && File(entry.output).existsSync() ? () => playVideo(context, entry.output) : () => _details(context),
      padding: const EdgeInsets.all(SquishyTokens.space3),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (ok ? t.success : t.danger).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(t.radiusSm),
            ),
            child: Icon(
              !ok
                  ? Icons.close_rounded
                  : switch (entry.kind) {
                      'cut' => Icons.content_cut_rounded,
                      'nas' => Icons.dns_rounded,
                      _ => Icons.check_rounded,
                    },
              color: ok ? t.success : t.danger,
            ),
          ),
          const SizedBox(width: SquishyTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                Text(
                  ok
                      ? '${formatBytes(entry.inputSize)} → ${formatBytes(entry.outputSize)} · ${entry.qualityLabel}'
                      : entry.error ?? 'Failed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: ok ? context.colors.onSurfaceVariant : t.danger),
                ),
                Text(
                  formatDate(entry.finished),
                  style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (ok && entry.kind != 'cut')
            Pill('−${(entry.reduction * 100).round()}%', color: t.success),
          IconButton(
            tooltip: 'Details',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _details(context),
          ),
        ],
      ),
    );
  }

  void _details(BuildContext context) {
    final rows = <(String, String)>[
      ('Result', entry.success ? 'Squished' : 'Failed'),
      if (entry.error != null) ('Reason', entry.error!),
      ('Type', switch (entry.kind) { 'cut' => 'Cut & join', 'nas' => 'NAS (in place)', _ => 'Compress' }),
      ('Source', entry.input),
      if (entry.success) ('Output', entry.output),
      ('Quality', '${entry.qualityLabel} · ${entry.codecLabel}'),
      ('Size', entry.success ? '${formatBytes(entry.inputSize)} → ${formatBytes(entry.outputSize)}' : formatBytes(entry.inputSize)),
      if (entry.kind == 'compress' && entry.success) ('Original', entry.originalDeleted ? 'Deleted' : 'Kept'),
      if (entry.kind == 'nas' && entry.success) ('Original', 'Replaced by the compressed file (same name)'),
      ('Finished', formatDate(entry.finished)),
      ('Took', formatDuration(entry.took.inMilliseconds)),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, 0, SquishyTokens.space4, SquishyTokens.space4),
          children: [
            Text(entry.name, style: context.text.titleLarge),
            const SizedBox(height: SquishyTokens.space3),
            if (entry.success && File(entry.output).existsSync()) ...[
              ShareActions(path: entry.output),
              const SizedBox(height: SquishyTokens.space3),
            ],
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SquishyTokens.space1 + 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(k, style: context.text.labelLarge?.copyWith(color: context.colors.onSurfaceVariant)),
                    ),
                    Expanded(child: SelectableText(v, style: context.text.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
