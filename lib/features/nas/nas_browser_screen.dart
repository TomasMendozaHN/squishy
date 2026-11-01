import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/nas.dart';
import '../../widgets/common.dart';
import '../shell/home_shell.dart';

const _videoExt = {'mkv', 'mp4', 'm4v', 'mov', 'avi', 'wmv', 'ts', 'm2ts', 'webm'};

/// Browse a NAS share, see per-library stats, pick a folder and squish it in place.
class NasBrowserScreen extends StatefulWidget {
  const NasBrowserScreen({super.key, required this.server, this.path = ''});

  final NasServerInfo server;
  final String path;

  @override
  State<NasBrowserScreen> createState() => _NasBrowserScreenState();
}

class _NasBrowserScreenState extends State<NasBrowserScreen> {
  List<NasEntry>? _entries;
  NasStats? _stats;
  String? _statsError;
  String? _error;

  bool get _atRoot => widget.path.isEmpty;
  String get _top => widget.path.split('/').first;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await NasNative.list(widget.server.id, widget.path);
      entries.sort((a, b) => a.isDir == b.isDir ? a.name.toLowerCase().compareTo(b.name.toLowerCase()) : (a.isDir ? -1 : 1));
      if (mounted) setState(() => _entries = entries);
      // Stats come from the ledger on the NAS; if it can't be read, say so instead of showing zeros.
      try {
        final stats = await NasNative.stats(widget.server.id);
        if (mounted) setState(() => _stats = stats);
      } on PlatformException catch (e) {
        if (mounted) setState(() => _statsError = e.message ?? 'unknown error');
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Could not open this folder');
    }
  }

  int _qualityFor(String folder) =>
      context.scope.settings.nasQuality(widget.server.id, folder) ?? defaultNasQuality(folder);

  Future<void> _start() async {
    final scope = context.scope;
    final folders = _atRoot ? _entries!.where((e) => e.isDir).map((e) => e.name).toList() : [_top];
    final qualities = {for (final f in folders) f: _qualityFor(f)};
    final codec = scope.device.hevc ? scope.settings.codec : VideoCodec.avc;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_atRoot ? 'Squish the whole share?' : 'Squish "${widget.path.split('/').last}"?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Every video in this folder and its subfolders is compressed and then replaces the original '
              'with the exact same name. Audio tracks, subtitles and chapters are copied untouched.',
            ),
            const SizedBox(height: SquishyTokens.space3),
            for (final e in qualities.entries) Text('• ${e.key}: ${e.value}p · ${codec.label}'),
            const SizedBox(height: SquishyTokens.space3),
            Text(
              'Keep the phone charging and on Wi-Fi. It can take hours for a big library.',
              style: context.text.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await NasNative.start(id: widget.server.id, path: widget.path, qualities: qualities, mime: codec.mime);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    homeTab.value = HomeTab.squish.index;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final jobs = context.scope.jobs;
    final entries = _entries;
    final title = _atRoot ? widget.server.name : widget.path.split('/').last;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text(
              _atRoot ? widget.server.address : widget.path,
              style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
      bottomNavigationBar: entries == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(SquishyTokens.space4),
                child: ListenableBuilder(
                  listenable: jobs,
                  builder: (context, _) {
                    final busy = jobs.nas?.active ?? false;
                    return GradientButton(
                      label: busy ? 'A NAS run is already going' : (_atRoot ? 'Squish everything' : 'Squish this folder'),
                      icon: Icons.compress_rounded,
                      onPressed: busy ? null : _start,
                    );
                  },
                ),
              ),
            ),
      body: _error != null
          ? EmptyState(
              icon: Icon(Icons.cloud_off_rounded, size: 64, color: t.danger),
              title: "Can't open this folder",
              message: _error!,
            )
          : entries == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: SquishyTokens.space5),
                    children: [
                      if (_atRoot) ..._libraries(context, entries),
                      if (!_atRoot) _libraryBanner(context),
                      SectionHeader(
                        _atRoot ? 'Folders' : 'Inside',
                        subtitle: () {
                          final vids = entries.where((e) => !e.isDir && _videoExt.contains(e.name.split('.').last.toLowerCase()));
                          final size = vids.fold(0, (s, e) => s + e.size);
                          return '${entries.where((e) => e.isDir).length} folders · ${vids.length} videos here (${formatBytes(size)})';
                        }(),
                      ),
                      for (final (i, e) in entries.indexed)
                        if (e.isDir || _videoExt.contains(e.name.split('.').last.toLowerCase()))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, 0, SquishyTokens.space4, SquishyTokens.space2),
                            child: GlassCard(
                              onTap: e.isDir
                                  ? () => Navigator.of(context).push(MaterialPageRoute(
                                        builder: (_) => NasBrowserScreen(server: widget.server, path: e.path),
                                      ))
                                  : null,
                              padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space3, vertical: SquishyTokens.space3),
                              child: Row(
                                children: [
                                  Icon(e.isDir ? Icons.folder_rounded : Icons.movie_rounded, color: e.isDir ? t.liquidA : t.liquidB),
                                  const SizedBox(width: SquishyTokens.space3),
                                  Expanded(child: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall)),
                                  if (!e.isDir) Text(formatBytes(e.size), style: context.text.labelSmall),
                                  if (e.isDir) const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: (15 * i.clamp(0, 20)).ms),
                    ],
                  ),
                ),
    );
  }

  /// Top-level folders = Plex libraries: stats since the beginning + quality per library.
  List<Widget> _libraries(BuildContext context, List<NasEntry> entries) {
    final t = context.tokens;
    final stats = _stats;
    final libs = entries.where((e) => e.isDir).toList();
    if (libs.isEmpty) return const [];
    return [
      SectionHeader(
        'Libraries',
        subtitle: stats != null
            ? '${formatBytes(stats.saved)} saved on this NAS · ${stats.files} videos squished'
            : (_statsError != null ? "Couldn't read the stats on the NAS ($_statsError). Pull down to retry." : 'Loading stats…'),
      ),
      for (final lib in libs)
        Padding(
          padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, 0, SquishyTokens.space4, SquishyTokens.space3),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.video_library_rounded, color: t.liquidA),
                    const SizedBox(width: SquishyTokens.space2),
                    Expanded(child: Text(lib.name, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                  ],
                ),
                const SizedBox(height: SquishyTokens.space2),
                () {
                  final f = stats?.folders[lib.name];
                  if (f == null) {
                    return Text('Nothing squished yet', style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant));
                  }
                  return Wrap(
                    spacing: SquishyTokens.space2,
                    runSpacing: SquishyTokens.space1,
                    children: [
                      Pill('${f.files} file${f.files == 1 ? '' : 's'}', icon: Icons.check_rounded, color: t.success),
                      Pill('${formatBytes(f.saved)} saved', icon: Icons.savings_rounded, color: t.liquidA),
                      if (f.inBytes > 0) Pill('−${(f.reduction * 100).round()}%', color: t.liquidB),
                      if (f.failed > 0) Pill('${f.failed} failed', icon: Icons.error_rounded, color: t.danger),
                      if (f.skipped > 0) Pill('${f.skipped} skipped', color: t.warning),
                    ],
                  );
                }(),
                const SizedBox(height: SquishyTokens.space3),
                _QualityPicker(
                  value: _qualityFor(lib.name),
                  onChanged: (h) {
                    context.scope.settings.setNasQuality(widget.server.id, lib.name, h);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _libraryBanner(BuildContext context) {
    final f = _stats?.folders[_top];
    return Padding(
      padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, SquishyTokens.space4, SquishyTokens.space4, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Library: $_top', style: context.text.titleSmall),
            if (f != null)
              Text(
                '${f.files} squished · ${formatBytes(f.saved)} saved',
                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            const SizedBox(height: SquishyTokens.space2),
            _QualityPicker(
              value: _qualityFor(_top),
              onChanged: (h) {
                context.scope.settings.setNasQuality(widget.server.id, _top, h);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityPicker extends StatelessWidget {
  const _QualityPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: [for (final q in Quality.values) ButtonSegment(value: q.height, label: Text(q.label))],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
