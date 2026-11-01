import 'package:flutter/services.dart';

/// A saved SMB share (the password stays on the native side).
class NasServerInfo {
  const NasServerInfo({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.share,
    required this.username,
    required this.domain,
    required this.hasPassword,
  });

  factory NasServerInfo.fromMap(Map<dynamic, dynamic> m) => NasServerInfo(
        id: m['id'] as String,
        name: m['name'] as String,
        host: m['host'] as String,
        port: (m['port'] as num?)?.toInt() ?? 445,
        share: m['share'] as String,
        username: m['username'] as String? ?? '',
        domain: m['domain'] as String? ?? '',
        hasPassword: m['hasPassword'] as bool? ?? false,
      );

  final String id;
  final String name;
  final String host;
  final int port;
  final String share;
  final String username;
  final String domain;
  final bool hasPassword;

  String get address => '\\\\$host${port == 445 ? '' : ':$port'}\\$share';
}

class NasEntry {
  const NasEntry(this.path, this.name, this.isDir, this.size);

  factory NasEntry.fromMap(Map<dynamic, dynamic> m) => NasEntry(
        m['path'] as String,
        m['name'] as String,
        m['isDir'] as bool,
        (m['size'] as num?)?.toInt() ?? 0,
      );

  final String path;
  final String name;
  final bool isDir;
  final int size;
}

class NasFolderStats {
  const NasFolderStats({
    required this.files,
    required this.saved,
    required this.inBytes,
    required this.failed,
    required this.skipped,
  });

  factory NasFolderStats.fromMap(Map<dynamic, dynamic> m) => NasFolderStats(
        files: (m['files'] as num?)?.toInt() ?? 0,
        saved: (m['saved'] as num?)?.toInt() ?? 0,
        inBytes: (m['inBytes'] as num?)?.toInt() ?? 0,
        failed: (m['failed'] as num?)?.toInt() ?? 0,
        skipped: (m['skipped'] as num?)?.toInt() ?? 0,
      );

  final int files;
  final int saved;
  final int inBytes;
  final int failed;
  final int skipped;

  double get reduction => inBytes > 0 ? saved / inBytes : 0;
}

/// Totals since the beginning, read from the ledger on the NAS itself.
class NasStats {
  const NasStats(this.files, this.saved, this.folders);

  factory NasStats.fromMap(Map<dynamic, dynamic> m) => NasStats(
        (m['files'] as num?)?.toInt() ?? 0,
        (m['saved'] as num?)?.toInt() ?? 0,
        {
          for (final e in ((m['folders'] as Map?) ?? const {}).entries)
            e.key as String: NasFolderStats.fromMap(e.value as Map),
        },
      );

  final int files;
  final int saved;
  final Map<String, NasFolderStats> folders;
}

/// Live state of the (single) NAS run.
class NasRunStatus {
  const NasRunStatus({
    required this.status,
    required this.serverName,
    required this.root,
    required this.found,
    required this.total,
    required this.index,
    required this.done,
    required this.failed,
    required this.skipped,
    required this.saved,
    required this.phase,
    required this.current,
    required this.fileProgress,
    required this.overall,
    required this.error,
  });

  factory NasRunStatus.fromMap(Map<dynamic, dynamic> m) => NasRunStatus(
        status: m['status'] as String? ?? '',
        serverName: m['serverName'] as String? ?? '',
        root: m['root'] as String? ?? '',
        found: (m['found'] as num?)?.toInt() ?? 0,
        total: (m['total'] as num?)?.toInt() ?? 0,
        index: (m['index'] as num?)?.toInt() ?? 0,
        done: (m['done'] as num?)?.toInt() ?? 0,
        failed: (m['failed'] as num?)?.toInt() ?? 0,
        skipped: (m['skipped'] as num?)?.toInt() ?? 0,
        saved: (m['saved'] as num?)?.toInt() ?? 0,
        phase: m['phase'] as String? ?? '',
        current: m['current'] as String? ?? '',
        fileProgress: (m['fileProgress'] as num?)?.toDouble() ?? 0,
        overall: (m['overall'] as num?)?.toDouble() ?? 0,
        error: m['error'] as String?,
      );

  final String status;
  final String serverName;
  final String root;
  final int found;
  final int total;
  final int index;
  final int done;
  final int failed;
  final int skipped;
  final int saved;
  final String phase;
  final String current;
  final double fileProgress;
  final double overall;
  final String? error;

  bool get active => status == 'scanning' || status == 'running';
  bool get scanning => status == 'scanning';
  bool get canResume => status == 'cancelled' || status == 'failed';
}

/// One video found by a recursive scan, with what the ledger knows about it.
class NasScanEntry {
  const NasScanEntry({
    required this.path,
    required this.name,
    required this.size,
    required this.top,
    required this.status,
    required this.reason,
  });

  factory NasScanEntry.fromMap(Map<dynamic, dynamic> m) => NasScanEntry(
        path: m['path'] as String,
        name: m['name'] as String,
        size: (m['size'] as num).toInt(),
        top: m['top'] as String? ?? '',
        status: m['status'] as String? ?? 'new',
        reason: m['reason'] as String?,
      );

  final String path;
  final String name;
  final int size;

  /// Library (top-level folder) it belongs to.
  final String top;

  /// 'new', 'done', 'skipped' or 'failed'.
  final String status;
  final String? reason;

  bool get done => status == 'done';

  /// Folder path below the library, for display.
  String get folder {
    final i = path.lastIndexOf('/');
    return i > 0 ? path.substring(0, i) : '';
  }
}

abstract final class NasNative {
  static const _channel = MethodChannel('squishy/native');

  static Future<List<NasServerInfo>> servers() async =>
      ((await _channel.invokeListMethod<Map>('nasServers')) ?? []).map(NasServerInfo.fromMap).toList();

  static Future<NasServerInfo> save(Map<String, Object?> fields) async =>
      NasServerInfo.fromMap((await _channel.invokeMapMethod('nasSave', fields))!);

  static Future<void> delete(String id) => _channel.invokeMethod('nasDelete', {'id': id});

  /// Throws a [PlatformException] with the SMB error when it can't connect.
  static Future<void> test(Map<String, Object?> fields) => _channel.invokeMethod('nasTest', fields);

  static Future<List<NasEntry>> list(String id, String path) async =>
      ((await _channel.invokeListMethod<Map>('nasList', {'id': id, 'path': path})) ?? [])
          .map(NasEntry.fromMap)
          .toList();

  static Future<NasStats> stats(String id) async =>
      NasStats.fromMap((await _channel.invokeMapMethod('nasStats', {'id': id}))!);

  /// Every video below [path] (all subfolders), biggest first.
  static Future<List<NasScanEntry>> scan(String id, String path) async =>
      ((await _channel.invokeListMethod<Map>('nasScan', {'id': id, 'path': path})) ?? [])
          .map(NasScanEntry.fromMap)
          .toList();

  /// Returns an error message, or null when the run started. With [files], only
  /// those videos are processed (no folder scan).
  static Future<String?> start({
    required String id,
    required String path,
    required Map<String, int> qualities,
    required String mime,
    List<NasScanEntry>? files,
  }) =>
      _channel.invokeMethod<String>('nasStart', {
        'id': id,
        'path': path,
        'qualities': qualities,
        'mime': mime,
        if (files != null) 'files': [for (final f in files) {'path': f.path, 'size': f.size}],
      });

  static Future<void> cancel() => _channel.invokeMethod('nasCancel');
  static Future<void> resume() => _channel.invokeMethod('nasResume');
  static Future<void> clear() => _channel.invokeMethod('nasClear');
}

/// Default quality for a library folder, from its name: Movies 1080p, TV 720p.
int defaultNasQuality(String folder) {
  final f = folder.toLowerCase();
  if (RegExp(r'\btv\b|show|serie|episod|anime').hasMatch(f)) return 720;
  return 1080;
}
