import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'native.dart';

/// Caches video metadata and thumbnails by path. Probes are batched so a
/// folder with hundreds of videos becomes a handful of native calls.
class ProbeCache extends ChangeNotifier {
  final Map<String, VideoInfo> _info = {};
  final Set<String> _pending = {};
  final Map<String, Future<String?>> _thumbs = {};
  Timer? _flush;

  VideoInfo? info(String path) => _info[path];

  bool hasAll(Iterable<String> paths) => paths.every(_info.containsKey);

  void request(Iterable<String> paths) {
    final missing = paths.where((p) => !_info.containsKey(p) && !_pending.contains(p));
    if (missing.isEmpty) return;
    _pending.addAll(missing);
    _flush ??= Timer(const Duration(milliseconds: 60), _run);
  }

  Future<void> ensure(Iterable<String> paths) async {
    final missing = paths.where((p) => !_info.containsKey(p)).toList();
    if (missing.isEmpty) return;
    _info.addAll(await SquishyNative.probe(missing));
    notifyListeners();
  }

  Future<void> _run() async {
    _flush = null;
    final batch = _pending.toList();
    for (var i = 0; i < batch.length; i += 24) {
      final chunk = batch.sublist(i, i + 24 > batch.length ? batch.length : i + 24);
      try {
        _info.addAll(await SquishyNative.probe(chunk));
      } catch (_) {
        // Unreadable files simply stay without metadata.
      }
      _pending.removeAll(chunk);
      notifyListeners();
    }
  }

  Future<String?> thumbnail(String path) =>
      _thumbs.putIfAbsent(path, () => SquishyNative.thumbnail(path).catchError((_) => null));

  void forget(String path) {
    _info.remove(path);
    _thumbs.remove(path);
  }
}
