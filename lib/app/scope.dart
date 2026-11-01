import 'package:flutter/widgets.dart';

import '../core/history_controller.dart';
import '../core/jobs_controller.dart';
import '../core/native.dart';
import '../core/probe_cache.dart';
import '../core/settings.dart';

/// Hands the app-wide controllers down the tree.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.settings,
    required this.jobs,
    required this.history,
    required this.probes,
    required this.device,
    required super.child,
  });

  final AppSettings settings;
  final JobsController jobs;
  final HistoryController history;
  final ProbeCache probes;
  final DeviceInfo device;

  static AppScope of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}

extension ScopeContext on BuildContext {
  AppScope get scope => AppScope.of(this);
}
