import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';
import 'nas.dart';

class StorageRoot {
  const StorageRoot(this.path, this.label);
  final String path;
  final String label;
}

class DeviceInfo {
  const DeviceInfo({
    required this.manufacturer,
    required this.model,
    required this.sdk,
    required this.hevc,
    required this.ignoringBatteryOptimizations,
  });

  final String manufacturer;
  final String model;
  final int sdk;
  final bool hevc;
  final bool ignoringBatteryOptimizations;

  bool get isXiaomi => const {'xiaomi', 'redmi', 'poco'}.contains(manufacturer.toLowerCase());
}

/// Thin wrapper over the Kotlin side (MainActivity.kt).
abstract final class SquishyNative {
  static const _channel = MethodChannel('squishy/native');
  static const _jobs = EventChannel('squishy/jobs');

  /// Local jobs plus the NAS run (null when there is none).
  static Stream<(List<JobSnapshot>, NasRunStatus?)> statusStream() => _jobs.receiveBroadcastStream().map((event) {
        final m = event as Map;
        final jobs = (m['jobs'] as List).map((j) => JobSnapshot.fromMap(j as Map)).toList();
        final nas = m['nas'] == null ? null : NasRunStatus.fromMap(m['nas'] as Map);
        return (jobs, nas);
      });

  static Future<DeviceInfo> deviceInfo() async {
    final m = (await _channel.invokeMapMethod<String, dynamic>('deviceInfo'))!;
    return DeviceInfo(
      manufacturer: m['manufacturer'] as String,
      model: m['model'] as String,
      sdk: m['sdk'] as int,
      hevc: m['hevc'] as bool,
      ignoringBatteryOptimizations: m['ignoringBatteryOptimizations'] as bool,
    );
  }

  static Future<List<StorageRoot>> storageRoots() async {
    final list = await _channel.invokeListMethod<Map>('storageRoots') ?? [];
    return list.map((m) => StorageRoot(m['path'] as String, m['label'] as String)).toList();
  }

  /// Returns path → info; unreadable files are left out.
  static Future<Map<String, VideoInfo>> probe(List<String> paths) async {
    final list = await _channel.invokeListMethod<Map>('probe', {'paths': paths}) ?? [];
    return {
      for (final m in list)
        if (m['error'] == null) m['path'] as String: VideoInfo.fromMap(m),
    };
  }

  static Future<String?> thumbnail(String path, {int size = 320}) =>
      _channel.invokeMethod<String>('thumbnail', {'path': path, 'size': size});

  static Future<String?> frameAt(String path, int timeMs, {int size = 200}) =>
      _channel.invokeMethod<String>('frameAt', {'path': path, 'timeMs': timeMs, 'size': size});

  static Future<void> enqueue(List<Map<String, Object?>> jobs, {required int parallel}) =>
      _channel.invokeMethod('enqueue', {'jobs': jobs, 'parallel': parallel});

  static Future<void> setParallel(int value) =>
      _channel.invokeMethod('setParallel', {'value': value});

  static Future<List<JobSnapshot>> jobs() async {
    final list = await _channel.invokeListMethod<Map>('jobs') ?? [];
    return list.map(JobSnapshot.fromMap).toList();
  }

  static Future<void> cancel(String id) => _channel.invokeMethod('cancel', {'id': id});
  static Future<void> cancelAll() => _channel.invokeMethod('cancelAll');
  static Future<void> clearFinished() => _channel.invokeMethod('clearFinished');

  static Future<List<LogEntry>> log() async {
    final raw = await _channel.invokeMethod<String>('log') ?? '[]';
    return (jsonDecode(raw) as List)
        .map((e) => LogEntry.fromMap(e as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  static Future<void> clearLog() => _channel.invokeMethod('clearLog');

  static Future<void> setKeepScreenOn(bool on) =>
      _channel.invokeMethod('setKeepScreenOn', {'on': on});

  static Future<bool> requestIgnoreBatteryOptimizations() async =>
      await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations') ?? false;
  static Future<bool> openAutostart() async =>
      await _channel.invokeMethod<bool>('openAutostart') ?? false;
  static Future<bool> openBatterySaver() async =>
      await _channel.invokeMethod<bool>('openBatterySaver') ?? false;
  static Future<bool> openVideo(String path) async =>
      await _channel.invokeMethod<bool>('openVideo', {'path': path}) ?? false;

  /// [target]: 'whatsapp', 'gmail' or 'any' (system share sheet).
  static Future<bool> shareVideo(String path, String target) async =>
      await _channel.invokeMethod<bool>('shareVideo', {'path': path, 'target': target}) ?? false;

  static Future<bool> shareText(String text) async =>
      await _channel.invokeMethod<bool>('shareText', {'text': text}) ?? false;

  static Future<bool> openAppSettings() async =>
      await _channel.invokeMethod<bool>('openAppSettings') ?? false;
}
