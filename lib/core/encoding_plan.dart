import 'dart:math' as math;

import 'models.dart';

/// Target video bitrates (bits/s) for H.264. H.265 needs roughly 40 % less
/// for the same perceived quality.
const Map<Quality, int> _avcVideoBitrate = {
  Quality.q360: 700000,
  Quality.q480: 1200000,
  Quality.q720: 2500000,
  Quality.q1080: 5000000,
};
const double _hevcFactor = 0.6;
const double _containerOverhead = 1.02;

/// Everything the native encoder needs for one output, plus the size estimate
/// shown to the user. Dart is the single source of truth for these numbers.
class EncodingPlan {
  const EncodingPlan({
    required this.width,
    required this.height,
    required this.videoBitrate,
    required this.audioBitrate,
    required this.durationMs,
  });

  final int width;
  final int height;
  final int videoBitrate;
  final int audioBitrate;
  final int durationMs;

  int get estimatedBytes =>
      ((videoBitrate + audioBitrate) * durationMs / 1000 / 8 * _containerOverhead).round();
}

int _even(double v) => math.max(2, (v / 2).round() * 2);

EncodingPlan planFor(
  VideoInfo info,
  Quality quality,
  VideoCodec codec, {
  int? durationMs,
}) {
  final duration = durationMs ?? info.durationMs;
  var video = _avcVideoBitrate[quality]!;
  if (codec == VideoCodec.hevc) video = (video * _hevcFactor).round();
  final audio = !info.hasAudio
      ? 0
      : quality.height >= 720
          ? 128000
          : 96000;

  // Never ask for more bits than the source has; re-encoding can't add detail.
  if (info.bitrate > 0) {
    final sourceVideo = math.max(info.bitrate - audio, 150000);
    video = math.min(video, (sourceVideo * 0.8).round());
  }

  // Never upscale: the short side is capped at the source's short side.
  var w = info.displayWidth;
  var h = info.displayHeight;
  if (info.isValid) {
    final targetShort = math.min(quality.height, info.shortSide);
    final scale = targetShort / info.shortSide;
    w = _even(info.displayWidth * scale);
    h = _even(info.displayHeight * scale);
  }

  return EncodingPlan(
    width: w,
    height: h,
    videoBitrate: video,
    audioBitrate: audio,
    durationMs: duration,
  );
}

int totalSegmentMs(List<Segment> segments) =>
    segments.fold(0, (sum, s) => sum + s.lengthMs);
