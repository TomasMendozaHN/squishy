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

/// Every video below a NAS folder (all subfolders), biggest first. Tick the ones
/// worth squishing and run just those, in place.
class NasPickScreen extends StatefulWidget {
  const NasPickScreen({super.key, required this.server, required this.path});

  final NasServerInfo server;
  final String path;

  @override
  State<NasPickScreen> createState() => _NasPickScreenState();
}

class _NasPickScreenState extends State<NasPickScreen> {
  List<NasScanEntry>? _all;
  String? _error;
  bool _hideDone = true;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _all = null;
      _error = null;
    });
    try {
      final list = await NasNative.scan(widget.server.id, widget.path);
      if (mounted) setState(() => _all = list);
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Scan failed');
    }
  }

  List<NasScanEntry> get _visible => (_all ?? const []).where((e) => !_hideDone || !e.done).toList();

  List<NasScanEntry> get _picked => (_all ?? const []).where((e) => _selected.contains(e.path)).toList();

  int _qualityFor(String library) =>
      context.scope.settings.nasQuality(widget.server.id, library) ?? defaultNasQuality(library);

  Future<void> _start() async {
    final scope = context.scope;
    final picked = _picked;
    final qualities = {for (final e in picked) e.top: _qualityFor(e.top)};
    final codec = scope.device.hevc ? scope.settings.codec : VideoCodec.avc;
    final error = await NasNative.start(
      id: widget.server.id,
      path: widget.path,
      qualities: qualities,
      mime: codec.mime,
      files: picked,
    );
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
    final all = _all;
    final visible = _visible;
    final picked = _picked;
    final pickedBytes = picked.fold(0, (s, e) => s + e.size);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pick videos'),
            Text(
              widget.path.isEmpty ? '${widget.server.name} · everything' : widget.path,
              style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          if (all != null)
            TextButton(
              onPressed: () => setState(() {
                final candidates = visible.where((e) => !e.done).map((e) => e.path);
                if (_selected.length == candidates.length) {
                  _selected.clear();
                } else {
                  _selected.addAll(candidates);
                }
              }),
              child: Text(_selected.isEmpty ? 'Select all' : 'Clear'),
            ),
        ],
      ),
      bottomNavigationBar: picked.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(SquishyTokens.space4),
                child: ListenableBuilder(
                  listenable: context.scope.jobs,
                  builder: (context, _) {
                    final busy = context.scope.jobs.nas?.active ?? false;
                    return GradientButton(
                      label: busy
                          ? 'A NAS run is already going'
                          : 'Squish ${picked.length} video${picked.length == 1 ? '' : 's'} · ${formatBytes(pickedBytes)}',
                      icon: Icons.compress_rounded,
                      onPressed: busy ? null : _start,
                    );
                  },
                ),
              ),
            ).animate().slideY(begin: 1, end: 0, duration: t.medium, curve: Curves.easeOutCubic),
      body: _error != null
          ? EmptyState(
              icon: Icon(Icons.cloud_off_rounded, size: 64, color: t.danger),
              title: "Couldn't scan this folder",
              message: _error!,
              action: OutlinedButton(onPressed: _scan, child: const Text('Try again')),
            )
          : all == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: SquishyTokens.space4),
                      Text('Looking through every subfolder…', style: context.text.bodyMedium),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _scan,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: SquishyTokens.space5),
                    children: [
                      SectionHeader(
                        '${visible.length} video${visible.length == 1 ? '' : 's'} · biggest first',
                        subtitle: () {
                          final total = visible.fold(0, (s, e) => s + e.size);
                          final done = all.where((e) => e.done).length;
                          return '${formatBytes(total)}${done > 0 ? ' · $done already squished' : ''}';
                        }(),
                        trailing: FilterChip(
                          label: const Text('Hide squished'),
                          selected: _hideDone,
                          onSelected: (v) => setState(() => _hideDone = v),
                        ),
                      ),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(SquishyTokens.space6),
                          child: Text(
                            all.isEmpty ? 'No videos in this folder.' : 'Everything here is already squished.',
                            textAlign: TextAlign.center,
                            style: context.text.bodyMedium,
                          ),
                        ),
                      for (final (i, e) in visible.indexed)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, 0, SquishyTokens.space4, SquishyTokens.space2),
                          child: _PickTile(
                            entry: e,
                            quality: e.top.isEmpty ? null : _qualityFor(e.top),
                            selected: _selected.contains(e.path),
                            onTap: e.done
                                ? null
                                : () => setState(() {
                                      _selected.contains(e.path) ? _selected.remove(e.path) : _selected.add(e.path);
                                    }),
                          ),
                        ).animate().fadeIn(delay: (12 * i.clamp(0, 25)).ms),
                    ],
                  ),
                ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({required this.entry, required this.quality, required this.selected, required this.onTap});

  final NasScanEntry entry;
  final int? quality;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (statusLabel, statusColor) = switch (entry.status) {
      'done' => ('squished', t.success),
      'skipped' => ('skipped before', t.warning),
      'failed' => ('failed before', t.danger),
      _ => (null, null),
    };
    return GlassCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space3, vertical: SquishyTokens.space3),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: t.fast,
            child: Icon(
              entry.done
                  ? Icons.check_circle_rounded
                  : (selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded),
              key: ValueKey('${entry.done}$selected'),
              color: entry.done ? t.success : (selected ? context.colors.primary : context.colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: SquishyTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                Text(
                  entry.folder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: SquishyTokens.space1 + 2,
                  runSpacing: 4,
                  children: [
                    if (entry.top.isNotEmpty) Pill(quality == null ? entry.top : '${entry.top} · ${quality}p', color: t.liquidB),
                    if (statusLabel != null) Pill(statusLabel, color: statusColor),
                  ],
                ),
                if (entry.reason != null && !entry.done)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      entry.reason!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: statusColor),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: SquishyTokens.space2),
          Text(formatBytes(entry.size), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
