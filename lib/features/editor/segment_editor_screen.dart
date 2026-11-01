import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../core/encoding_plan.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/native.dart';
import '../../widgets/common.dart';
import '../shell/home_shell.dart';

/// Pick any number of segments from one video; they are joined in list order
/// into a single output.
class SegmentEditorScreen extends StatefulWidget {
  const SegmentEditorScreen({super.key, required this.file});

  final VideoFile file;

  @override
  State<SegmentEditorScreen> createState() => _SegmentEditorScreenState();
}

class _SegmentEditorScreenState extends State<SegmentEditorScreen> {
  late final VideoPlayerController _player = VideoPlayerController.file(File(widget.file.path));
  VideoInfo? _info;
  bool _ready = false;
  RangeValues _draft = const RangeValues(0, 1);
  final List<Segment> _segments = [];
  late Quality _quality = context.scope.settings.quality;
  int? _stopAtMs;
  bool _exporting = false;

  int get _durationMs => _player.value.duration.inMilliseconds;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final probes = context.scope.probes;
    await Future.wait([_player.initialize(), probes.ensure([widget.file.path])]);
    if (!mounted) return;
    _player.addListener(_onTick);
    setState(() {
      _info = probes.info(widget.file.path);
      _ready = true;
      final d = _durationMs.toDouble();
      _draft = RangeValues(0, math.min(d, 10000));
    });
  }

  void _onTick() {
    final stop = _stopAtMs;
    if (stop != null && _player.value.position.inMilliseconds >= stop) {
      _player.pause();
      _stopAtMs = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _player.removeListener(_onTick);
    _player.dispose();
    super.dispose();
  }

  void _seek(int ms) => _player.seekTo(Duration(milliseconds: ms));

  void _previewRange(int start, int end) {
    _seek(start);
    _stopAtMs = end;
    _player.play();
  }

  void _addSegment() {
    final s = Segment(_draft.start.round(), _draft.end.round());
    if (s.lengthMs < 300) return;
    setState(() {
      _segments.add(s);
      // Next draft starts where this one ended — the common "keep cutting forward" flow.
      final next = math.min(s.endMs + 1000, _durationMs);
      _draft = RangeValues(next.toDouble(), math.min(next + 10000, _durationMs).toDouble());
    });
  }

  Future<void> _export() async {
    final info = _info;
    if (info == null || _segments.isEmpty) return;
    setState(() => _exporting = true);
    final scope = context.scope;
    await scope.jobs.cut(
      file: widget.file,
      info: info,
      segments: List.of(_segments),
      quality: _quality,
      codec: scope.device.hevc ? scope.settings.codec : VideoCodec.avc,
      outputDir: scope.settings.customOutputDir,
    );
    if (!mounted) return;
    homeTab.value = HomeTab.squish.index;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final totalMs = totalSegmentMs(_segments);
    final codec = context.scope.device.hevc ? context.scope.settings.codec : VideoCodec.avc;
    final estimate = _info == null || _segments.isEmpty ? 0 : planFor(_info!, _quality, codec, durationMs: totalMs).estimatedBytes;
    return Scaffold(
      appBar: AppBar(title: Text(widget.file.name, overflow: TextOverflow.ellipsis)),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(SquishyTokens.space4),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(t.radiusMd),
                  child: AspectRatio(
                    aspectRatio: _player.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_player),
                        GestureDetector(
                          onTap: () => _player.value.isPlaying ? _player.pause() : _player.play(),
                          child: AnimatedOpacity(
                            opacity: _player.value.isPlaying ? 0 : 1,
                            duration: t.fast,
                            child: Container(
                              padding: const EdgeInsets.all(SquishyTokens.space3),
                              decoration: BoxDecoration(
                                color: context.colors.scrim.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.play_arrow_rounded, size: 42, color: context.colors.surface),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn().scaleXY(begin: 0.96, end: 1),
                const SizedBox(height: SquishyTokens.space3),
                Row(
                  children: [
                    Text(
                      formatDurationPrecise(_player.value.position.inMilliseconds),
                      style: context.text.labelLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                    const Spacer(),
                    Text(formatDuration(_durationMs), style: context.text.labelLarge),
                  ],
                ),
                const SizedBox(height: SquishyTokens.space2),
                _Timeline(
                  path: widget.file.path,
                  durationMs: _durationMs,
                  positionMs: _player.value.position.inMilliseconds,
                  segments: _segments,
                  onSeek: _seek,
                ),
                RangeSlider(
                  min: 0,
                  max: math.max(_durationMs.toDouble(), 1),
                  values: _draft,
                  labels: RangeLabels(formatDurationPrecise(_draft.start.round()), formatDurationPrecise(_draft.end.round())),
                  divisions: math.max(1, _durationMs ~/ 100),
                  onChanged: (v) {
                    final movedStart = v.start != _draft.start;
                    setState(() => _draft = v);
                    _seek((movedStart ? v.start : v.end).round());
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _previewRange(_draft.start.round(), _draft.end.round()),
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: Text('Preview ${formatDuration((_draft.end - _draft.start).round())}'),
                      ),
                    ),
                    const SizedBox(width: SquishyTokens.space2),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _addSegment,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add segment'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SquishyTokens.space2),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _draft = RangeValues(
                            _player.value.position.inMilliseconds.toDouble().clamp(0, _draft.end - 100),
                            _draft.end,
                          )),
                      child: const Text('Start = now'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _draft = RangeValues(
                            _draft.start,
                            _player.value.position.inMilliseconds.toDouble().clamp(_draft.start + 100, _durationMs.toDouble()),
                          )),
                      child: const Text('End = now'),
                    ),
                  ],
                ),
                SectionHeader(
                  'Segments',
                  subtitle: _segments.isEmpty
                      ? 'Add the parts you want to keep. Drag to reorder.'
                      : '${_segments.length} · ${formatDuration(totalMs)} total · joined top to bottom',
                ),
                if (_segments.isNotEmpty)
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorderItem: (from, to) => setState(() {
                      _segments.insert(to, _segments.removeAt(from));
                    }),
                    children: [
                      for (var i = 0; i < _segments.length; i++)
                        Padding(
                          key: ObjectKey(_segments[i]),
                          padding: const EdgeInsets.only(bottom: SquishyTokens.space2),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space3, vertical: SquishyTokens.space1),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator_rounded)),
                                const SizedBox(width: SquishyTokens.space2),
                                CircleAvatar(
                                  radius: 13,
                                  backgroundColor: t.liquidA.withValues(alpha: 0.2),
                                  child: Text('${i + 1}', style: context.text.labelMedium?.copyWith(color: t.liquidA)),
                                ),
                                const SizedBox(width: SquishyTokens.space3),
                                Expanded(
                                  child: Text(
                                    '${formatDurationPrecise(_segments[i].startMs)} → ${formatDurationPrecise(_segments[i].endMs)}',
                                    style: context.text.bodyMedium,
                                  ),
                                ),
                                Text(formatDuration(_segments[i].lengthMs), style: context.text.labelMedium),
                                IconButton(
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  onPressed: () => _previewRange(_segments[i].startMs, _segments[i].endMs),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, color: t.danger),
                                  onPressed: () => setState(() => _segments.removeAt(i)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: SquishyTokens.space3),
                Text('Output quality', style: context.text.titleSmall),
                const SizedBox(height: SquishyTokens.space2),
                Wrap(
                  spacing: SquishyTokens.space2,
                  children: [
                    for (final q in Quality.values)
                      ChoiceChip(
                        label: Text(q.label),
                        selected: q == _quality,
                        onSelected: (_) => setState(() => _quality = q),
                      ),
                  ],
                ),
                const SizedBox(height: SquishyTokens.space2),
                if (_segments.isNotEmpty)
                  Text(
                    'Expected size ≈ ${formatBytes(estimate)} · original is kept',
                    style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                const SizedBox(height: SquishyTokens.space4),
                GradientButton(
                  label: _exporting ? 'Starting…' : 'Cut & join ${_segments.length} segment${_segments.length == 1 ? '' : 's'}',
                  icon: Icons.movie_creation_rounded,
                  onPressed: _segments.isEmpty || _exporting ? null : _export,
                ),
                const SizedBox(height: SquishyTokens.space6),
              ],
            ),
    );
  }
}

/// Filmstrip with kept segments highlighted and a playhead. Tap/drag to seek.
class _Timeline extends StatefulWidget {
  const _Timeline({
    required this.path,
    required this.durationMs,
    required this.positionMs,
    required this.segments,
    required this.onSeek,
  });

  final String path;
  final int durationMs;
  final int positionMs;
  final List<Segment> segments;
  final ValueChanged<int> onSeek;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  static const _frames = 10;
  late final List<Future<String?>> _thumbs = [
    for (var i = 0; i < _frames; i++)
      // Stay clear of the very end, where some files have no decodable frame.
      SquishyNative.frameAt(widget.path, (widget.durationMs * 0.95 * i / (_frames - 1)).round()).catchError((_) => null),
  ];

  void _seekAt(double dx, double width) =>
      widget.onSeek((dx / width).clamp(0.0, 1.0) * widget.durationMs ~/ 1);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      double x(int ms) => widget.durationMs == 0 ? 0 : ms / widget.durationMs * w;
      return GestureDetector(
        onTapDown: (d) => _seekAt(d.localPosition.dx, w),
        onHorizontalDragUpdate: (d) => _seekAt(d.localPosition.dx, w),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(t.radiusSm),
          child: SizedBox(
            height: 56,
            child: Stack(
              children: [
                Row(
                  children: [
                    for (final f in _thumbs)
                      Expanded(
                        child: FutureBuilder<String?>(
                          future: f,
                          builder: (context, snap) => snap.data == null
                              ? Container(color: context.colors.onSurface.withValues(alpha: 0.08))
                              : Image.file(File(snap.data!), fit: BoxFit.cover, height: 56),
                        ),
                      ),
                  ],
                ),
                Container(color: context.colors.scrim.withValues(alpha: 0.35)),
                for (final s in widget.segments)
                  Positioned(
                    left: x(s.startMs),
                    width: math.max(2, x(s.endMs) - x(s.startMs)),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: t.liquidA.withValues(alpha: 0.35),
                        border: Border.all(color: t.liquidB, width: 2),
                      ),
                    ),
                  ),
                Positioned(
                  left: x(widget.positionMs) - 1.5,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 3, color: context.colors.surface),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
