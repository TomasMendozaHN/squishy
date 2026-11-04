import 'package:flutter_test/flutter_test.dart';
import 'package:squishy/core/jobs_controller.dart';
import 'package:squishy/core/models.dart';
import 'package:squishy/core/nas.dart';

JobSnapshot job(String id, JobStatus status, {double progress = 0}) => JobSnapshot(
      id: id,
      kind: 'compress',
      input: '/videos/$id.mp4',
      output: '/out/$id.mp4',
      status: status,
      progress: progress,
      error: null,
      inputSize: 100,
      outputSize: 0,
      estimatedBytes: 0,
      startedAt: 0,
      finishedAt: 0,
      qualityLabel: '480p',
    );

NasRunStatus nasRun(String status, {double overall = 0}) =>
    NasRunStatus.fromMap({'status': status, 'overall': overall, 'total': 10, 'index': 2});

void main() {
  group('combinedProgress', () {
    test('no NAS run: plain average over the local batch', () {
      expect(combinedProgress([job('a', JobStatus.running, progress: 0.4)], null), 0.4);
      expect(
        combinedProgress([job('a', JobStatus.done), job('b', JobStatus.running, progress: 0.2)], null),
        0.6,
      );
    });

    test('NAS-only run: the visual follows the NAS progress', () {
      expect(combinedProgress([], nasRun('running', overall: 0.25)), 0.25);
      expect(combinedProgress([], nasRun('scanning')), 0.0);
    });

    test('finished NAS run with an empty list keeps its final progress', () {
      expect(combinedProgress([], nasRun('done', overall: 1)), 1.0);
      expect(combinedProgress([], nasRun('failed', overall: 0.4)), 0.4);
    });

    test('local jobs done, NAS started: the visual is not pinned at 100 %', () {
      expect(combinedProgress([job('a', JobStatus.done)], nasRun('running', overall: 0.3)), 0.3);
    });

    test('NAS and a local job running at once: both count', () {
      expect(
        combinedProgress([job('a', JobStatus.running, progress: 0.6)], nasRun('running', overall: 0.2)),
        0.4,
      );
    });

    test('NAS finished while local work remains: local batch takes over', () {
      expect(
        combinedProgress([job('a', JobStatus.running, progress: 0.5)], nasRun('done', overall: 1)),
        0.5,
      );
    });

    test('nothing at all: zero, never a crash', () {
      expect(combinedProgress([], null), 0.0);
    });
  });
}
