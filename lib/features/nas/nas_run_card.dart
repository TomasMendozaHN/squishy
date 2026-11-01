import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/nas.dart';
import '../../widgets/common.dart';

/// The NAS run on the Squish screen: current file, phase, counts and controls.
class NasRunCard extends StatelessWidget {
  const NasRunCard({super.key, required this.run});

  final NasRunStatus run;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final title = switch (run.status) {
      'scanning' => 'Finding videos on ${run.serverName}',
      'running' => 'Squishing ${run.serverName}',
      'done' => '${run.serverName}: all done',
      'cancelled' => '${run.serverName}: paused',
      _ => '${run.serverName}: stopped',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, 0, SquishyTokens.space4, SquishyTokens.space3),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dns_rounded, color: t.liquidA),
                const SizedBox(width: SquishyTokens.space2),
                Expanded(child: Text(title, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
              ],
            ),
            Text(
              run.root.isEmpty ? 'Whole share' : run.root,
              style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            if (run.active) ...[
              const SizedBox(height: SquishyTokens.space3),
              Text(run.current, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
              Text(
                run.scanning ? '${run.found} videos found so far' : run.phase,
                style: context.text.bodySmall?.copyWith(color: t.liquidA),
              ),
              const SizedBox(height: SquishyTokens.space2),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: run.scanning ? null : run.fileProgress,
                  minHeight: 8,
                ),
              ),
            ],
            if (run.error != null && !run.active)
              Padding(
                padding: const EdgeInsets.only(top: SquishyTokens.space2),
                child: Text(run.error!, style: context.text.bodySmall?.copyWith(color: t.danger)),
              ),
            const SizedBox(height: SquishyTokens.space3),
            Wrap(
              spacing: SquishyTokens.space2,
              runSpacing: SquishyTokens.space1,
              children: [
                if (!run.scanning) Pill('${run.index} / ${run.total} files', icon: Icons.movie_rounded),
                Pill('${run.done} squished', icon: Icons.check_rounded, color: t.success),
                Pill('${formatBytes(run.saved)} saved', icon: Icons.savings_rounded, color: t.liquidA),
                if (run.skipped > 0) Pill('${run.skipped} skipped', color: t.warning),
                if (run.failed > 0) Pill('${run.failed} failed', icon: Icons.error_rounded, color: t.danger),
              ],
            ),
            const SizedBox(height: SquishyTokens.space2),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (run.active)
                  TextButton.icon(
                    onPressed: () => _confirmStop(context),
                    icon: Icon(Icons.pause_circle_rounded, color: t.danger),
                    label: const Text('Stop'),
                  ),
                if (run.canResume)
                  TextButton.icon(
                    onPressed: NasNative.resume,
                    icon: const Icon(Icons.play_circle_rounded),
                    label: const Text('Resume'),
                  ),
                if (!run.active)
                  TextButton.icon(
                    onPressed: NasNative.clear,
                    icon: const Icon(Icons.cleaning_services_rounded),
                    label: const Text('Dismiss'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: context.tokens.medium).slideY(begin: 0.1, end: 0);
  }

  Future<void> _confirmStop(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop the NAS run?'),
        content: const Text(
          'The current file is abandoned and its original stays as it was. You can resume later from the same file.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep going')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Stop')),
        ],
      ),
    );
    if (ok == true) NasNative.cancel();
  }
}
