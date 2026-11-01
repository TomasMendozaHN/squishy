import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../core/encoding_plan.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../widgets/common.dart';
import '../folder_picker/folder_picker_screen.dart';
import '../shell/home_shell.dart';

Future<void> showCompressSheet(BuildContext context, List<VideoFile> files, {VoidCallback? onStarted}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => CompressSheet(files: files, onStarted: onStarted),
  );
}

class CompressSheet extends StatefulWidget {
  const CompressSheet({super.key, required this.files, this.onStarted});

  final List<VideoFile> files;
  final VoidCallback? onStarted;

  @override
  State<CompressSheet> createState() => _CompressSheetState();
}

class _CompressSheetState extends State<CompressSheet> {
  late Quality _quality;
  late VideoCodec _codec;
  late bool _deleteOriginals;
  String? _outputDir;
  bool _probing = true;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final s = context.scope.settings;
    _quality = s.quality;
    _codec = context.scope.device.hevc ? s.codec : VideoCodec.avc;
    _deleteOriginals = s.deleteOriginals;
    _outputDir = s.customOutputDir;
    context.scope.probes.ensure(widget.files.map((f) => f.path)).whenComplete(() {
      if (mounted) setState(() => _probing = false);
    });
  }

  int get _originalBytes => widget.files.fold(0, (s, f) => s + f.sizeBytes);

  int _estimate(Quality q) {
    final probes = context.scope.probes;
    var total = 0;
    for (final f in widget.files) {
      final info = probes.info(f.path);
      if (info == null || !info.isValid) continue;
      total += planFor(info, q, _codec).estimatedBytes;
    }
    return total;
  }

  int get _unreadable =>
      widget.files.where((f) => !(context.scope.probes.info(f.path)?.isValid ?? false)).length;

  Future<void> _start() async {
    setState(() => _starting = true);
    final scope = context.scope;
    await scope.jobs.compress(
      files: widget.files,
      infos: {for (final f in widget.files) f.path: ?scope.probes.info(f.path)},
      quality: _quality,
      codec: _codec,
      deleteOriginals: _deleteOriginals,
      outputDir: _outputDir,
    );
    if (!mounted) return;
    Navigator.pop(context);
    widget.onStarted?.call();
    homeTab.value = HomeTab.squish.index;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final n = widget.files.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, 0, SquishyTokens.space4, SquishyTokens.space4),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              n == 1 ? 'Squish 1 video' : 'Squish $n videos',
              style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              '${formatBytes(_originalBytes)} right now',
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: SquishyTokens.space4),
            Text('Output quality', style: context.text.titleSmall),
            const SizedBox(height: SquishyTokens.space2),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: SquishyTokens.space2,
              crossAxisSpacing: SquishyTokens.space2,
              childAspectRatio: 1.9,
              children: [
                for (final (i, q) in Quality.values.indexed)
                  _QualityCard(
                    quality: q,
                    selected: q == _quality,
                    probing: _probing,
                    estimate: _probing ? 0 : _estimate(q),
                    original: _originalBytes,
                    onTap: () => setState(() => _quality = q),
                  ).animate(delay: (50 * i).ms).fadeIn(duration: t.medium).scaleXY(begin: 0.94, end: 1, curve: Curves.easeOutBack),
              ],
            ),
            if (!_probing && _unreadable > 0)
              Padding(
                padding: const EdgeInsets.only(top: SquishyTokens.space2),
                child: Text(
                  "$_unreadable file(s) can't be read and will be skipped.",
                  style: context.text.bodySmall?.copyWith(color: t.warning),
                ),
              ),
            const SizedBox(height: SquishyTokens.space4),
            Text('Codec', style: context.text.titleSmall),
            const SizedBox(height: SquishyTokens.space2),
            SegmentedButton<VideoCodec>(
              segments: [
                for (final c in VideoCodec.values)
                  ButtonSegment(
                    value: c,
                    enabled: c != VideoCodec.hevc || context.scope.device.hevc,
                    label: Text('${c.label} · ${c.hint}'),
                  ),
              ],
              selected: {_codec},
              onSelectionChanged: (s) => setState(() => _codec = s.first),
            ),
            const SizedBox(height: SquishyTokens.space4),
            Text('Save to', style: context.text.titleSmall),
            const SizedBox(height: SquishyTokens.space2),
            GlassCard(
              onTap: () async {
                final picked = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const FolderPickerScreen()),
                );
                if (picked != null) setState(() => _outputDir = picked);
              },
              child: Row(
                children: [
                  Icon(Icons.drive_folder_upload_rounded, color: t.liquidA),
                  const SizedBox(width: SquishyTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _outputDir == null ? '"compressed" folder next to each video' : _outputDir!.split('/').last,
                          style: context.text.titleSmall,
                        ),
                        Text(
                          _outputDir ?? 'Default',
                          style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_outputDir != null)
                    IconButton(
                      tooltip: 'Back to default',
                      icon: const Icon(Icons.restart_alt_rounded),
                      onPressed: () => setState(() => _outputDir = null),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: SquishyTokens.space2),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _deleteOriginals,
              onChanged: (v) => setState(() => _deleteOriginals = v),
              title: const Text('Delete originals when done'),
              subtitle: Text(
                'Only after the new file is verified (plays, right length, smaller). Permanent.',
                style: context.text.bodySmall?.copyWith(color: _deleteOriginals ? t.danger : null),
              ),
            ),
            const SizedBox(height: SquishyTokens.space3),
            GradientButton(
              label: _starting ? 'Starting…' : 'Start squishing',
              icon: Icons.compress_rounded,
              onPressed: _probing || _starting || _unreadable == n ? null : _start,
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({
    required this.quality,
    required this.selected,
    required this.probing,
    required this.estimate,
    required this.original,
    required this.onTap,
  });

  final Quality quality;
  final bool selected;
  final bool probing;
  final int estimate;
  final int original;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final saving = original > 0 && estimate > 0 ? 1 - estimate / original : 0.0;
    return GlassCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(SquishyTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(quality.label, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (quality == Quality.q480) Pill('default', color: t.liquidA),
            ],
          ),
          probing
              ? const LinearProgressIndicator()
              : Row(
                  children: [
                    Text('≈ ${formatBytes(estimate)}', style: context.text.bodyMedium),
                    const Spacer(),
                    if (saving > 0)
                      Text(
                        '−${(saving * 100).round()}%',
                        style: context.text.labelLarge?.copyWith(color: t.success, fontWeight: FontWeight.w800),
                      )
                    else
                      Text('no gain', style: context.text.labelSmall?.copyWith(color: t.warning)),
                  ],
                ),
        ],
      ),
    );
  }
}
