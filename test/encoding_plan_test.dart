import 'package:flutter_test/flutter_test.dart';
import 'package:squishy/core/encoding_plan.dart';
import 'package:squishy/core/format.dart';
import 'package:squishy/core/jobs_controller.dart';
import 'package:squishy/core/models.dart';

const _landscape1080 = VideoInfo(
  durationMs: 60000,
  width: 1920,
  height: 1080,
  rotation: 0,
  bitrate: 17000000,
  hasAudio: true,
);

void main() {
  group('planFor', () {
    test('scales the short side to the chosen quality and keeps aspect', () {
      final p = planFor(_landscape1080, Quality.q480, VideoCodec.avc);
      expect(p.height, 480);
      expect(p.width, 854);
      expect(p.videoBitrate, 1200000);
    });

    test('portrait (rotated) video keeps portrait output', () {
      const portrait = VideoInfo(
        durationMs: 10000,
        width: 1920,
        height: 1080,
        rotation: 90,
        bitrate: 17000000,
        hasAudio: true,
      );
      final p = planFor(portrait, Quality.q720, VideoCodec.avc);
      expect(p.width, 720);
      expect(p.height, 1280);
    });

    test('never upscales and never exceeds the source bitrate', () {
      const small = VideoInfo(
        durationMs: 10000,
        width: 640,
        height: 360,
        rotation: 0,
        bitrate: 600000,
        hasAudio: true,
      );
      final p = planFor(small, Quality.q1080, VideoCodec.avc);
      expect(p.height, 360);
      expect(p.videoBitrate, lessThan(600000));
    });

    test('H.265 uses fewer bits than H.264', () {
      final avc = planFor(_landscape1080, Quality.q720, VideoCodec.avc);
      final hevc = planFor(_landscape1080, Quality.q720, VideoCodec.hevc);
      expect(hevc.estimatedBytes, lessThan(avc.estimatedBytes));
    });

    test('estimate follows duration', () {
      final full = planFor(_landscape1080, Quality.q480, VideoCodec.avc);
      final half = planFor(_landscape1080, Quality.q480, VideoCodec.avc, durationMs: 30000);
      expect(half.estimatedBytes * 2, closeTo(full.estimatedBytes, 2));
    });
  });

  test('segments add up', () {
    expect(totalSegmentMs(const [Segment(0, 1000), Segment(5000, 7500)]), 3500);
  });

  test('default output goes to a "compressed" folder next to the original', () {
    expect(
      JobsController.outputPathFor('/storage/emulated/0/DCIM/Camera/VID_1.mov'),
      '/storage/emulated/0/DCIM/Camera/compressed/VID_1.mp4',
    );
    expect(
      JobsController.outputPathFor('/sd/a.mp4', customDir: '/sd/out', suffix: '_cut'),
      '/sd/out/a_cut.mp4',
    );
  });

  test('formatting', () {
    expect(formatBytes(1536), '1.5 KB');
    expect(formatDuration(3723000), '1:02:03');
    expect(formatDuration(65000), '1:05');
  });
}
