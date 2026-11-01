import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme_presets.dart';
import 'models.dart';

enum ProgressStyle {
  waterTank('Water tank', 'Liquid rises with waves and bubbles'),
  liquidOrb('Liquid orb', 'A glass sphere slowly filling up'),
  glowRing('Glow ring', 'Neon ring with a sloshing core'),
  equalizer('Equalizer', 'Bars that light up as it squishes');

  const ProgressStyle(this.label, this.hint);
  final String label;
  final String hint;
}

enum ChartStyle {
  bars('Bars', 'Space saved per day'),
  line('Smooth line', 'Trend of space saved'),
  area('Area', 'Filled trend with glow'),
  donut('Donut', 'Space saved by quality');

  const ChartStyle(this.label, this.hint);
  final String label;
  final String hint;
}

enum ViewMode {
  grid('Grid', 'Thumbnails, 3 per row'),
  cards('Big cards', 'Large thumbnails with details'),
  list('List', 'Thumbnail + details'),
  compact('Compact', 'Names only, fits the most');

  const ViewMode(this.label, this.hint);
  final String label;
  final String hint;
}

enum CornerStyle {
  sharp('Sharp', 6),
  soft('Soft', 14),
  round('Round', 24);

  const CornerStyle(this.label, this.base);
  final String label;
  final double base;
}

enum AppFont {
  quicksand('Quicksand'),
  outfit('Outfit'),
  inter('Inter'),
  spaceGrotesk('Space Grotesk'),
  nunito('Nunito');

  const AppFont(this.family);
  final String family;
}

enum SortField {
  name('Name'),
  date('Date modified'),
  size('Size'),
  duration('Duration'),
  resolution('Resolution');

  const SortField(this.label);
  final String label;
}

/// User preferences, persisted in SharedPreferences.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  static Future<AppSettings> load() async =>
      AppSettings._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  T _enum<T extends Enum>(String key, List<T> values, T fallback) {
    final name = _prefs.getString(key);
    return values.where((v) => v.name == name).firstOrNull ?? fallback;
  }

  void _setEnum(String key, Enum value) {
    _prefs.setString(key, value.name);
    notifyListeners();
  }

  void _setBool(String key, bool value) {
    _prefs.setBool(key, value);
    notifyListeners();
  }

  // Personalization
  ThemePreset get themePreset => _enum('theme', ThemePreset.values, ThemePreset.obsidianCyan);
  set themePreset(ThemePreset v) => _setEnum('theme', v);

  ProgressStyle get progressStyle =>
      _enum('progressStyle', ProgressStyle.values, ProgressStyle.waterTank);
  set progressStyle(ProgressStyle v) => _setEnum('progressStyle', v);

  ChartStyle get chartStyle => _enum('chartStyle', ChartStyle.values, ChartStyle.area);
  set chartStyle(ChartStyle v) => _setEnum('chartStyle', v);

  ViewMode get viewMode => _enum('viewMode', ViewMode.values, ViewMode.grid);
  set viewMode(ViewMode v) => _setEnum('viewMode', v);

  CornerStyle get corners => _enum('corners', CornerStyle.values, CornerStyle.soft);
  set corners(CornerStyle v) => _setEnum('corners', v);

  AppFont get font => _enum('font', AppFont.values, AppFont.quicksand);
  set font(AppFont v) => _setEnum('font', v);

  bool get reduceMotion => _prefs.getBool('reduceMotion') ?? false;
  set reduceMotion(bool v) => _setBool('reduceMotion', v);

  // Compression defaults
  Quality get quality => Quality.fromHeight(_prefs.getInt('quality') ?? 480);
  set quality(Quality v) {
    _prefs.setInt('quality', v.height);
    notifyListeners();
  }

  VideoCodec get codec => _enum('codec', VideoCodec.values, VideoCodec.hevc);
  set codec(VideoCodec v) => _setEnum('codec', v);

  int get parallel => _prefs.getInt('parallel') ?? 1;
  set parallel(int v) {
    _prefs.setInt('parallel', v.clamp(1, 3));
    notifyListeners();
  }

  bool get deleteOriginals => _prefs.getBool('deleteOriginals') ?? true;
  set deleteOriginals(bool v) => _setBool('deleteOriginals', v);

  /// null = "compressed" folder next to each original.
  String? get customOutputDir => _prefs.getString('customOutputDir');
  set customOutputDir(String? v) {
    if (v == null) {
      _prefs.remove('customOutputDir');
    } else {
      _prefs.setString('customOutputDir', v);
    }
    notifyListeners();
  }

  bool get keepScreenOn => _prefs.getBool('keepScreenOn') ?? false;
  set keepScreenOn(bool v) => _setBool('keepScreenOn', v);

  // Browser
  bool get showHidden => _prefs.getBool('showHidden') ?? false;
  set showHidden(bool v) => _setBool('showHidden', v);

  SortField get sortField => _enum('sortField', SortField.values, SortField.date);
  set sortField(SortField v) => _setEnum('sortField', v);

  bool get sortAscending => _prefs.getBool('sortAscending') ?? false;
  set sortAscending(bool v) => _setBool('sortAscending', v);

  String? get lastFolder => _prefs.getString('lastFolder');
  set lastFolder(String? v) {
    if (v != null) _prefs.setString('lastFolder', v);
  }

  bool get onboarded => _prefs.getBool('onboarded') ?? false;
  set onboarded(bool v) => _setBool('onboarded', v);
}
