import 'dart:async';

import 'package:flutter/foundation.dart';

import 'encoding_plan.dart';
import 'format.dart';
import 'models.dart';
import 'nas.dart';
import 'native.dart';
import 'settings.dart';

/// Mirrors the native queue and turns user choices into native job requests.
class JobsController extends ChangeNotifier {
  JobsController(this.settings) {
    _sub = SquishyNative.statusStream().listen((e) {
      final nasWasActive = nas?.active ?? false;
      final nasIndex = nas?.index;
      nas = e.$2;
      _onJobs(e.$1);
      // Each finished NAS file lands in the log too.
      if (nasWasActive && (nas?.index != nasIndex || !(nas?.active ?? false))) {
        _finishedController.add(null);
      }
    });
    settings.addListener(_syncScreen);
  }

  final AppSettings settings;
  late final StreamSubscription<(List<JobSnapshot>, NasRunStatus?)> _sub;
  List<JobSnapshot> jobs = const [];

  /// The NAS run, if one exists (running, finished or paused).
  NasRunStatus? nas;
  final _finishedController = StreamController<void>.broadcast();
  int _idCounter = 0;
  DateTime? _sessionStart;
  bool _screenOn = false;

  /// Fires whenever a job reaches a final state (for the history screen).
  Stream<void> get onFinished => _finishedController.stream;

  List<JobSnapshot> get active => jobs.where((j) => j.isActive).toList();
  List<JobSnapshot> get finished => jobs.where((j) => !j.isActive).toList();
  bool get isBusy => jobs.any((j) => j.isActive) || (nas?.active ?? false);
  int get runningCount => jobs.where((j) => j.status == JobStatus.running).length;

  /// Overall progress across everything the app is working on.
  double get overallProgress => combinedProgress(jobs, nas);

  Duration? get eta {
    final start = _sessionStart;
    final p = overallProgress;
    if (start == null || p < 0.02 || !isBusy) return null;
    final elapsed = DateTime.now().difference(start);
    return elapsed * ((1 - p) / p);
  }

  void _onJobs(List<JobSnapshot> next) {
    final before = {for (final j in jobs) j.id: j.status};
    final newlyFinished = next.any((j) => !j.isActive && before[j.id] != null && before[j.id] != j.status);
    if (next.any((j) => j.isActive) || (nas?.active ?? false)) {
      _sessionStart ??= DateTime.now();
    } else {
      _sessionStart = null;
    }
    jobs = next;
    notifyListeners();
    if (newlyFinished) _finishedController.add(null);
    _syncScreen();
  }

  void _syncScreen() {
    final want = settings.keepScreenOn && isBusy;
    if (want == _screenOn) return;
    _screenOn = want;
    SquishyNative.setKeepScreenOn(want);
  }

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  static String outputPathFor(String input, {String? customDir, String suffix = ''}) {
    final dir = customDir ?? '${parentDir(input)}/compressed';
    return '$dir/${stripExtension(baseName(input))}$suffix.mp4';
  }

  Future<void> compress({
    required List<VideoFile> files,
    required Map<String, VideoInfo> infos,
    required Quality quality,
    required VideoCodec codec,
    required bool deleteOriginals,
    required String? outputDir,
  }) async {
    final requests = <Map<String, Object?>>[];
    for (final f in files) {
      final info = infos[f.path];
      if (info == null || !info.isValid) continue;
      final plan = planFor(info, quality, codec);
      requests.add(_request(
        kind: 'compress',
        input: f.path,
        output: outputPathFor(f.path, customDir: outputDir),
        plan: plan,
        codec: codec,
        quality: quality,
        inputSize: f.sizeBytes,
        deleteOriginal: deleteOriginals,
        segments: const [],
      ));
    }
    if (requests.isEmpty) return;
    await _startBatch(requests);
  }

  Future<void> cut({
    required VideoFile file,
    required VideoInfo info,
    required List<Segment> segments,
    required Quality quality,
    required VideoCodec codec,
    required String? outputDir,
  }) async {
    final plan = planFor(info, quality, codec, durationMs: totalSegmentMs(segments));
    await _startBatch([
      _request(
        kind: 'cut',
        input: file.path,
        output: outputPathFor(file.path, customDir: outputDir, suffix: '_cut'),
        plan: plan,
        codec: codec,
        quality: quality,
        inputSize: file.sizeBytes,
        deleteOriginal: false,
        segments: segments,
      ),
    ]);
  }

  /// A new batch after an idle period starts with a clean board, so the
  /// overall progress and notification only count the new work.
  Future<void> _startBatch(List<Map<String, Object?>> requests) async {
    if (!isBusy) await SquishyNative.clearFinished();
    await SquishyNative.enqueue(requests, parallel: settings.parallel);
  }

  Map<String, Object?> _request({
    required String kind,
    required String input,
    required String output,
    required EncodingPlan plan,
    required VideoCodec codec,
    required Quality quality,
    required int inputSize,
    required bool deleteOriginal,
    required List<Segment> segments,
  }) =>
      {
        'id': _newId(),
        'kind': kind,
        'input': input,
        'output': output,
        'width': plan.width,
        'height': plan.height,
        'videoBitrate': plan.videoBitrate,
        'audioBitrate': plan.audioBitrate,
        'mime': codec.mime,
        'segments': segments.map((s) => s.toList()).toList(),
        'deleteOriginal': deleteOriginal,
        'inputSize': inputSize,
        'expectedDurationMs': plan.durationMs,
        'estimatedBytes': plan.estimatedBytes,
        'qualityLabel': quality.label,
        'codecLabel': codec.label,
      };

  Future<void> cancel(String id) => SquishyNative.cancel(id);
  Future<void> cancelAll() => SquishyNative.cancelAll();
  Future<void> clearFinished() => SquishyNative.clearFinished();

  @override
  void dispose() {
    _sub.cancel();
    settings.removeListener(_syncScreen);
    _finishedController.close();
    super.dispose();
  }
}

/// Overall progress across everything in flight.
///
/// While a NAS run is active it counts once, together with any local jobs
/// *still running* — finished local jobs must not pin the visual at 100 %
/// while the NAS work keeps going. With no NAS run it is the plain average
/// over the local batch (finished jobs count as 1).
double combinedProgress(List<JobSnapshot> jobs, NasRunStatus? nas) {
  if (nas != null && nas.active) {
    final running = jobs.where((j) => j.status == JobStatus.running).toList();
    if (running.isEmpty) return nas.overall;
    final localP = running.fold<double>(0, (sum, j) => sum + j.progress) / running.length;
    return (localP + nas.overall) / 2;
  }
  if (jobs.isEmpty) return nas?.overall ?? 0;
  final total = jobs.fold<double>(0, (sum, j) => sum + (j.isActive ? j.progress : 1));
  return total / jobs.length;
}
