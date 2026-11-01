import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/settings.dart';
import '../../widgets/common.dart';
import '../../widgets/progress_visuals.dart';
import '../../widgets/squishy_logo.dart';
import '../shell/home_shell.dart';

class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.jobs, scope.settings]),
      builder: (context, _) {
        final jobs = scope.jobs;
        if (jobs.jobs.isEmpty) {
          return EmptyState(
            icon: const SquishyLogo(size: 120),
            title: 'Nothing squishing',
            message: 'Pick some videos in Files and they will show up here with live progress.',
            action: GradientButton(
              label: 'Pick videos',
              icon: Icons.video_library_rounded,
              expand: false,
              onPressed: () => homeTab.value = HomeTab.files.index,
            ),
          );
        }
        return LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth > constraints.maxHeight && constraints.maxWidth > 600;
          final visualSize = math.min(wide ? constraints.maxHeight * 0.7 : constraints.maxWidth * 0.72, 320.0);
          final hero = _Hero(size: visualSize);
          final list = _JobList(jobs: jobs.jobs);
          if (wide) {
            return Row(
              children: [
                Expanded(child: Center(child: SingleChildScrollView(child: hero))),
                Expanded(child: CustomScrollView(slivers: [list])),
              ],
            );
          }
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: hero),
              list,
              const SliverToBoxAdapter(child: SizedBox(height: SquishyTokens.space6)),
            ],
          );
        });
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scope = context.scope;
    final jobs = scope.jobs;
    final settings = scope.settings;
    final done = jobs.jobs.where((j) => j.status == JobStatus.done).length;
    final failed = jobs.jobs.where((j) => j.status == JobStatus.failed).length;
    final total = jobs.jobs.length;
    final busy = jobs.isBusy;
    final eta = jobs.eta;
    final caption = busy ? '${done + failed} of $total done' : (failed > 0 ? '$done done · $failed failed' : 'All done!');
    return Padding(
      padding: const EdgeInsets.all(SquishyTokens.space4),
      child: Column(
        children: [
          Text(
            busy ? 'Squishing…' : 'Finished',
            style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            busy
                ? [
                    '${jobs.runningCount} running',
                    if (eta != null) formatEta(eta),
                  ].join(' · ')
                : 'Tap the visual to change its style',
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: SquishyTokens.space4),
          GestureDetector(
            onTap: () {
              final styles = ProgressStyle.values;
              settings.progressStyle = styles[(settings.progressStyle.index + 1) % styles.length];
            },
            child: AnimatedSwitcher(
              duration: context.tokens.medium,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: ProgressVisual(
                key: ValueKey(settings.progressStyle),
                style: settings.progressStyle,
                progress: jobs.overallProgress,
                size: size,
                caption: caption,
              ),
            ),
          ),
          const SizedBox(height: SquishyTokens.space4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: SquishyTokens.space2,
            runSpacing: SquishyTokens.space2,
            children: [
              FilterChip(
                avatar: Icon(settings.keepScreenOn ? Icons.light_mode_rounded : Icons.light_mode_outlined, size: 18),
                label: const Text('Keep screen on'),
                selected: settings.keepScreenOn,
                onSelected: (v) => settings.keepScreenOn = v,
              ),
              if (busy)
                ActionChip(
                  avatar: Icon(Icons.stop_circle_rounded, size: 18, color: context.tokens.danger),
                  label: const Text('Cancel all'),
                  onPressed: () => _confirmCancelAll(context),
                )
              else
                ActionChip(
                  avatar: const Icon(Icons.cleaning_services_rounded, size: 18),
                  label: const Text('Clear list'),
                  onPressed: jobs.clearFinished,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancelAll(BuildContext context) async {
    final jobs = context.scope.jobs;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel everything?'),
        content: const Text('Running and waiting videos stop. Originals are never touched when cancelling.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel all')),
        ],
      ),
    );
    if (ok == true) jobs.cancelAll();
  }
}

class _JobList extends StatelessWidget {
  const _JobList({required this.jobs});

  final List<JobSnapshot> jobs;

  @override
  Widget build(BuildContext context) {
    // Running first, then waiting, then finished.
    int rank(JobSnapshot j) => switch (j.status) {
          JobStatus.running => 0,
          JobStatus.queued => 1,
          _ => 2,
        };
    final sorted = [...jobs]..sort((a, b) => rank(a).compareTo(rank(b)));
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space4),
      sliver: SliverList.separated(
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(height: SquishyTokens.space2),
        itemBuilder: (context, i) => _JobCard(job: sorted[i])
            .animate(key: ValueKey(sorted[i].id))
            .fadeIn(duration: context.tokens.medium)
            .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final JobSnapshot job;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (icon, color) = switch (job.status) {
      JobStatus.queued => (Icons.hourglass_top_rounded, context.colors.onSurfaceVariant),
      JobStatus.running => (job.isCut ? Icons.content_cut_rounded : Icons.compress_rounded, t.liquidA),
      JobStatus.done => (Icons.check_circle_rounded, t.success),
      JobStatus.failed => (Icons.error_rounded, t.danger),
      JobStatus.cancelled => (Icons.block_rounded, t.warning),
    };
    final sizes = switch (job.status) {
      JobStatus.done => '${formatBytes(job.inputSize)} → ${formatBytes(job.outputSize)}'
          '${job.isCut ? '' : '  (−${((1 - job.outputSize / math.max(job.inputSize, 1)) * 100).round()}%)'}',
      JobStatus.failed || JobStatus.cancelled => job.error ?? 'Failed',
      _ => '${formatBytes(job.inputSize)} → ≈ ${formatBytes(job.estimatedBytes)}',
    };
    return GlassCard(
      padding: const EdgeInsets.all(SquishyTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: SquishyTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                    Text(
                      [job.qualityLabel, if (job.isCut) 'cut & join', sizes].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: job.status == JobStatus.failed ? t.danger : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (job.status == JobStatus.running)
                Text(
                  formatPercent(job.progress),
                  style: context.text.titleSmall?.copyWith(color: t.liquidA, fontWeight: FontWeight.w800),
                ),
              if (job.isActive)
                IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => context.scope.jobs.cancel(job.id),
                ),
            ],
          ),
          if (job.isActive) ...[
            const SizedBox(height: SquishyTokens.space2),
            _LiquidBar(progress: job.status == JobStatus.queued ? 0 : job.progress),
          ],
        ],
      ),
    );
  }
}

class _LiquidBar extends StatelessWidget {
  const _LiquidBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Container(color: context.colors.onSurface.withValues(alpha: 0.08)),
            TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v.clamp(0.0, 1.0),
                child: Container(decoration: BoxDecoration(gradient: t.liquidGradient))
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(duration: 1500.ms, color: context.colors.surface.withValues(alpha: 0.35)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
