import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/models.dart';
import '../../core/native.dart';
import '../../core/probe_cache.dart';
import '../../core/settings.dart';

const videoExtensions = {'mp4', 'm4v', 'mov', 'mkv', 'webm', '3gp', '3g2', 'avi', 'ts'};

bool isVideoPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return false;
  if (path.contains('.squishy-tmp.')) return false;
  return videoExtensions.contains(path.substring(dot + 1).toLowerCase());
}

class QuickFolder {
  const QuickFolder(this.label, this.relative);
  final String label;
  final String relative;
}

const quickFolders = [
  QuickFolder('Camera', 'DCIM/Camera'),
  QuickFolder('Screen recordings', 'DCIM/ScreenRecorder'),
  QuickFolder('Movies', 'Movies'),
  QuickFolder('Downloads', 'Download'),
  QuickFolder('WhatsApp', 'Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video'),
  QuickFolder('Telegram', 'Android/media/org.telegram.messenger/Telegram/Telegram Video'),
  QuickFolder('Telegram', 'Telegram/Telegram Video'),
];

class BrowserController extends ChangeNotifier {
  BrowserController(this.settings, this.probes) {
    settings.addListener(_onSettings);
    probes.addListener(_onProbes);
  }

  final AppSettings settings;
  final ProbeCache probes;

  List<StorageRoot> roots = const [];
  StorageRoot? root;
  String? dir;
  List<String> folders = const [];
  List<VideoFile> _videos = const [];
  List<QuickFolder> availableQuick = const [];
  bool loading = true;
  String? error;
  final Set<String> selected = {};

  SortField _lastSort = SortField.date;
  bool _lastAsc = false;
  bool _lastHidden = false;

  List<VideoFile> get videos => _sorted;
  List<VideoFile> _sorted = const [];

  bool get canGoUp => root != null && dir != null && dir != root!.path;
  bool get selecting => selected.isNotEmpty;
  List<VideoFile> get selectedFiles => _videos.where((v) => selected.contains(v.path)).toList();
  int get selectedBytes => selectedFiles.fold(0, (s, v) => s + v.sizeBytes);

  Future<void> init() async {
    roots = await SquishyNative.storageRoots();
    if (roots.isEmpty) {
      roots = const [StorageRoot('/storage/emulated/0', 'Internal storage')];
    }
    root = roots.first;
    final last = settings.lastFolder;
    final start = last != null && await Directory(last).exists() ? last : root!.path;
    root = roots.firstWhere((r) => start.startsWith(r.path), orElse: () => roots.first);
    _lastSort = settings.sortField;
    _lastAsc = settings.sortAscending;
    _lastHidden = settings.showHidden;
    await _scanQuick();
    await open(start);
  }

  Future<void> _scanQuick() async {
    final base = root?.path;
    if (base == null) return;
    final found = <QuickFolder>[];
    final seen = <String>{};
    for (final q in quickFolders) {
      if (seen.contains(q.label)) continue;
      if (await Directory('$base/${q.relative}').exists()) {
        found.add(q);
        seen.add(q.label);
      }
    }
    availableQuick = found;
  }

  Future<void> switchRoot(StorageRoot r) async {
    root = r;
    await _scanQuick();
    await open(r.path);
  }

  Future<void> openQuick(QuickFolder q) => open('${root!.path}/${q.relative}');

  Future<void> open(String path) async {
    loading = true;
    error = null;
    dir = path;
    selected.clear();
    notifyListeners();
    final dirs = <String>[];
    final vids = <VideoFile>[];
    try {
      await for (final e in Directory(path).list(followLinks: false)) {
        final name = e.path.split('/').last;
        if (!settings.showHidden && name.startsWith('.')) continue;
        if (e is Directory) {
          dirs.add(e.path);
        } else if (e is File && isVideoPath(e.path)) {
          try {
            final stat = await e.stat();
            vids.add(VideoFile(path: e.path, name: name, sizeBytes: stat.size, modified: stat.modified));
          } catch (_) {}
        }
      }
    } on FileSystemException catch (e) {
      error = e.osError?.message ?? e.message;
    }
    if (dir != path) return; // user already navigated elsewhere
    dirs.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    folders = dirs;
    _videos = vids;
    _resort();
    loading = false;
    settings.lastFolder = path;
    notifyListeners();
    probes.request(vids.map((v) => v.path));
  }

  Future<void> refresh() async {
    for (final v in _videos) {
      probes.forget(v.path);
    }
    if (dir != null) await open(dir!);
  }

  Future<bool> up() async {
    if (!canGoUp) return false;
    final parent = dir!.substring(0, dir!.lastIndexOf('/'));
    await open(parent.length < root!.path.length ? root!.path : parent);
    return true;
  }

  /// Breadcrumb segments as (label, absolutePath).
  List<(String, String)> get crumbs {
    if (root == null || dir == null) return const [];
    final out = <(String, String)>[(root!.label, root!.path)];
    final rest = dir!.substring(root!.path.length).split('/').where((s) => s.isNotEmpty);
    var acc = root!.path;
    for (final s in rest) {
      acc = '$acc/$s';
      out.add((s, acc));
    }
    return out;
  }

  void toggle(String path) {
    selected.contains(path) ? selected.remove(path) : selected.add(path);
    notifyListeners();
  }

  void selectAll() {
    selected.addAll(_videos.map((v) => v.path));
    notifyListeners();
  }

  void clearSelection() {
    selected.clear();
    notifyListeners();
  }

  void _onSettings() {
    if (settings.showHidden != _lastHidden) {
      _lastHidden = settings.showHidden;
      if (dir != null) open(dir!);
      return;
    }
    if (settings.sortField != _lastSort || settings.sortAscending != _lastAsc) {
      _lastSort = settings.sortField;
      _lastAsc = settings.sortAscending;
      _resort();
      notifyListeners();
    }
  }

  void _onProbes() {
    if (settings.sortField == SortField.duration || settings.sortField == SortField.resolution) {
      _resort();
      notifyListeners();
    }
  }

  void _resort() {
    final list = [..._videos];
    int cmp(VideoFile a, VideoFile b) {
      switch (settings.sortField) {
        case SortField.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case SortField.date:
          return a.modified.compareTo(b.modified);
        case SortField.size:
          return a.sizeBytes.compareTo(b.sizeBytes);
        case SortField.duration:
          return (probes.info(a.path)?.durationMs ?? -1).compareTo(probes.info(b.path)?.durationMs ?? -1);
        case SortField.resolution:
          return (probes.info(a.path)?.shortSide ?? -1).compareTo(probes.info(b.path)?.shortSide ?? -1);
      }
    }

    list.sort((a, b) {
      final c = cmp(a, b);
      final tie = c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return settings.sortAscending ? tie : -tie;
    });
    _sorted = list;
  }

  @override
  void dispose() {
    settings.removeListener(_onSettings);
    probes.removeListener(_onProbes);
    super.dispose();
  }
}
