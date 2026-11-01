import 'dart:math' as math;

/// Output resolutions offered to the user. The number is the short side of the
/// frame, so portrait and landscape videos get the same treatment.
enum Quality {
  q360(360),
  q480(480),
  q720(720),
  q1080(1080);

  const Quality(this.height);
  final int height;

  String get label => '${height}p';

  static Quality fromHeight(int h) =>
      Quality.values.firstWhere((q) => q.height == h, orElse: () => Quality.q480);
}

enum VideoCodec {
  hevc('video/hevc', 'H.265', 'Smaller files'),
  avc('video/avc', 'H.264', 'Plays everywhere');

  const VideoCodec(this.mime, this.label, this.hint);
  final String mime;
  final String label;
  final String hint;
}

class VideoFile {
  const VideoFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.modified,
  });

  final String path;
  final String name;
  final int sizeBytes;
  final DateTime modified;
}

/// Metadata read natively with MediaMetadataRetriever.
class VideoInfo {
  const VideoInfo({
    required this.durationMs,
    required this.width,
    required this.height,
    required this.rotation,
    required this.bitrate,
    required this.hasAudio,
  });

  factory VideoInfo.fromMap(Map<dynamic, dynamic> m) => VideoInfo(
        durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
        width: (m['width'] as num?)?.toInt() ?? 0,
        height: (m['height'] as num?)?.toInt() ?? 0,
        rotation: (m['rotation'] as num?)?.toInt() ?? 0,
        bitrate: (m['bitrate'] as num?)?.toInt() ?? 0,
        hasAudio: m['hasAudio'] as bool? ?? true,
      );

  final int durationMs;
  final int width;
  final int height;
  final int rotation;
  final int bitrate;
  final bool hasAudio;

  bool get isRotated => rotation % 180 != 0;
  int get displayWidth => isRotated ? height : width;
  int get displayHeight => isRotated ? width : height;
  int get shortSide => math.min(width, height);
  bool get isValid => width > 0 && height > 0;

  String get resolutionLabel => isValid ? '${shortSide}p' : '—';
}

class Segment {
  const Segment(this.startMs, this.endMs);

  final int startMs;
  final int endMs;

  int get lengthMs => endMs - startMs;

  List<int> toList() => [startMs, endMs];
}

enum JobStatus { queued, running, done, failed, cancelled }

/// Live state of a job owned by the native foreground service.
class JobSnapshot {
  const JobSnapshot({
    required this.id,
    required this.kind,
    required this.input,
    required this.output,
    required this.status,
    required this.progress,
    required this.error,
    required this.inputSize,
    required this.outputSize,
    required this.estimatedBytes,
    required this.startedAt,
    required this.finishedAt,
    required this.qualityLabel,
  });

  factory JobSnapshot.fromMap(Map<dynamic, dynamic> m) => JobSnapshot(
        id: m['id'] as String,
        kind: m['kind'] as String? ?? 'compress',
        input: m['input'] as String? ?? '',
        output: m['output'] as String? ?? '',
        status: JobStatus.values.byName(m['status'] as String? ?? 'queued'),
        progress: (m['progress'] as num?)?.toDouble() ?? 0,
        error: m['error'] as String?,
        inputSize: (m['inputSize'] as num?)?.toInt() ?? 0,
        outputSize: (m['outputSize'] as num?)?.toInt() ?? 0,
        estimatedBytes: (m['estimatedBytes'] as num?)?.toInt() ?? 0,
        startedAt: (m['startedAt'] as num?)?.toInt() ?? 0,
        finishedAt: (m['finishedAt'] as num?)?.toInt() ?? 0,
        qualityLabel: m['qualityLabel'] as String? ?? '',
      );

  final String id;
  final String kind;
  final String input;
  final String output;
  final JobStatus status;

  /// 0.0 – 1.0
  final double progress;
  final String? error;
  final int inputSize;
  final int outputSize;
  final int estimatedBytes;
  final int startedAt;
  final int finishedAt;
  final String qualityLabel;

  String get name => input.split('/').last;
  bool get isActive => status == JobStatus.queued || status == JobStatus.running;
  bool get isCut => kind == 'cut';
}

/// One finished job, persisted natively in log.json.
class LogEntry {
  const LogEntry({
    required this.id,
    required this.kind,
    required this.input,
    required this.output,
    required this.success,
    required this.error,
    required this.inputSize,
    required this.outputSize,
    required this.startedAt,
    required this.finishedAt,
    required this.qualityLabel,
    required this.codecLabel,
    required this.originalDeleted,
  });

  factory LogEntry.fromMap(Map<String, dynamic> m) => LogEntry(
        id: m['id'] as String? ?? '',
        kind: m['kind'] as String? ?? 'compress',
        input: m['input'] as String? ?? '',
        output: m['output'] as String? ?? '',
        success: m['success'] as bool? ?? false,
        error: m['error'] as String?,
        inputSize: (m['inputSize'] as num?)?.toInt() ?? 0,
        outputSize: (m['outputSize'] as num?)?.toInt() ?? 0,
        startedAt: (m['startedAt'] as num?)?.toInt() ?? 0,
        finishedAt: (m['finishedAt'] as num?)?.toInt() ?? 0,
        qualityLabel: m['qualityLabel'] as String? ?? '',
        codecLabel: m['codecLabel'] as String? ?? '',
        originalDeleted: m['originalDeleted'] as bool? ?? false,
      );

  final String id;
  final String kind;
  final String input;
  final String output;
  final bool success;
  final String? error;
  final int inputSize;
  final int outputSize;
  final int startedAt;
  final int finishedAt;
  final String qualityLabel;
  final String codecLabel;
  final bool originalDeleted;

  String get name => input.split('/').last;
  int get savedBytes => success && kind != 'cut' ? inputSize - outputSize : 0;
  double get reduction => inputSize > 0 && success ? 1 - outputSize / inputSize : 0;
  DateTime get finished => DateTime.fromMillisecondsSinceEpoch(finishedAt);
  Duration get took => Duration(milliseconds: math.max(0, finishedAt - startedAt));
}
