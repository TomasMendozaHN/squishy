import 'dart:async';

import 'package:flutter/foundation.dart';

import 'jobs_controller.dart';
import 'models.dart';
import 'native.dart';

class DayStat {
  const DayStat(this.day, this.savedBytes, this.count);
  final DateTime day;
  final int savedBytes;
  final int count;
}

/// The persistent success/failure log plus the numbers behind the charts.
class HistoryController extends ChangeNotifier {
  HistoryController(JobsController jobs) {
    _sub = jobs.onFinished.listen((_) => reload());
    reload();
  }

  late final StreamSubscription<void> _sub;
  List<LogEntry> entries = const [];
  bool loading = true;

  Future<void> reload() async {
    try {
      entries = await SquishyNative.log();
    } catch (_) {
      entries = const [];
    }
    loading = false;
    notifyListeners();
  }

  Future<void> clear() async {
    await SquishyNative.clearLog();
    await reload();
  }

  List<LogEntry> get successes => entries.where((e) => e.success).toList();
  List<LogEntry> get failures => entries.where((e) => !e.success).toList();
  int get savedBytes => entries.fold(0, (s, e) => s + e.savedBytes);

  double get averageReduction {
    final ok = successes.where((e) => e.kind != 'cut').toList();
    if (ok.isEmpty) return 0;
    return ok.fold<double>(0, (s, e) => s + e.reduction) / ok.length;
  }

  /// Space saved per calendar day for the last [days] days (oldest first).
  List<DayStat> daily({int days = 14, DateTime? now}) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final map = <DateTime, (int, int)>{};
    for (final e in successes) {
      final d = DateUtils.dateOnly(e.finished);
      final (saved, count) = map[d] ?? (0, 0);
      map[d] = (saved + e.savedBytes, count + 1);
    }
    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final d = today.subtract(Duration(days: i));
          final (saved, count) = map[d] ?? (0, 0);
          return DayStat(d, saved, count);
        }(),
    ];
  }

  /// Space saved per output quality, for the donut chart.
  Map<String, int> savedByQuality() {
    final out = <String, int>{};
    for (final e in successes) {
      if (e.savedBytes <= 0) continue;
      out[e.qualityLabel] = (out[e.qualityLabel] ?? 0) + e.savedBytes;
    }
    return out;
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Small local copy so the controller stays free of material imports.
abstract final class DateUtils {
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
