import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme_presets.dart';
import 'models.dart';

enum ProgressStyle {
  waterTank('Water tank', 'Liquid rises with waves and bubbles'),
  liquidOrb('Liquid orb', 'A glass sphere slowly filling up'),
  glowRing('Glow ring', 'Neon ring with a sloshing core'),
  equalizer('Equalizer', 'Bars that light up as it squishes'),
  battery('Battery', 'Charges up like a phone battery'),
  thermometer('Thermometer', 'Liquid rises in a glass tube'),
  blob('Blob', 'A squishy jelly blob that grows'),
  dotGrid('Dot grid', 'Dots fill in one by one'),
  spiral('Spiral', 'A glowing line winds inward'),
  hourglass('Hourglass', 'Sand drains from top to bottom'),
  orbit('Orbit', 'A comet circles a filling ring'),
  radar('Radar', 'A sweeping scanner line'),
  ripple('Ripple', 'Rings ripple out from a growing core'),
  constellation('Constellation', 'Stars connect one by one'),
  clockHands('Clock', 'A hand sweeps around a dial'),
  bloom('Bloom', 'Petals open one at a time'),
  waveform('Waveform', 'An audio wave fills left to right'),
  minimalBar('Minimal bar', 'A clean capsule with a shimmer'),
  confetti('Confetti', 'Pieces fall and pile up'),
  staircase('Staircase', 'A ball climbs a staircase'),
  scribble('Scribble', 'A glowing doodle traces itself');

  const ProgressStyle(this.label, this.hint);
  final String label;
  final String hint;
}

enum ChartStyle {
  area('Area', 'Filled trend with glow'),
  line('Smooth line', 'Trend of space saved'),
  straight('Straight line', 'Point to point, with dots'),
  stepped('Steps', 'A staircase, day by day'),
  cumulative('Total', 'Everything saved so far'),
  bubbles('Bubbles', 'Bigger bubble, more saved'),
  bars('Bars', 'Space saved per day'),
  capsules('Capsules', 'Round bars on a track'),
  horizontal('Sideways', 'Bars as rows, one per day'),
  videos('Videos', 'How many squished per day'),
  heatmap('Heatmap', 'Calendar squares, brighter = more'),
  donut('Donut', 'Space saved by quality'),
  pie('Pie', 'Share of each quality'),
  gauge('Gauge', 'Half ring by quality'),
  radar('Radar', 'Qualities as a web');

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
  nunito('Nunito'),
  poppins('Poppins'),
  manrope('Manrope'),
  dmSans('DM Sans'),
  lexend('Lexend'),
  rubik('Rubik'),
  sora('Sora'),
  fredoka('Fredoka'),
  comfortaa('Comfortaa');

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
  /// A [ThemeChoice] id, [Themes.followSystemId] or [Themes.customId].
  String get themeId => _prefs.getString('theme') ?? Themes.defaultId;
  set themeId(String v) {
    _prefs.setString('theme', v);
    notifyListeners();
  }

  bool get followsSystem => themeId == Themes.followSystemId;

  // The custom theme: dark or light, plus a main and an accent color.
  bool get customDark => _prefs.getBool('customDark') ?? true;
  set customDark(bool v) => _setBool('customDark', v);

  Color get customMain => Color(_prefs.getInt('customMain') ?? Themes.swatches[8].toARGB32());
  set customMain(Color v) {
    _prefs.setInt('customMain', v.toARGB32());
    notifyListeners();
  }

  Color get customAccent => Color(_prefs.getInt('customAccent') ?? Themes.swatches[13].toARGB32());
  set customAccent(Color v) {
    _prefs.setInt('customAccent', v.toARGB32());
    notifyListeners();
  }

  PresetPalette get customPalette => PresetPalette.custom(
        brightness: customDark ? Brightness.dark : Brightness.light,
        main: customMain,
        accent: customAccent,
      );

  /// The palette to use; [platform] only matters for "Follow system".
  PresetPalette paletteFor(Brightness platform) => switch (themeId) {
        Themes.followSystemId => platform == Brightness.dark ? Themes.systemDark : Themes.systemLight,
        Themes.customId => customPalette,
        final id => Themes.byId(id).palette,
      };

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

  // NAS: output quality per library folder (e.g. MOVIES 1080p, TV SHOWS 720p).
  int? nasQuality(String serverId, String folder) => _prefs.getInt('nasQ:$serverId:$folder');
  void setNasQuality(String serverId, String folder, int height) {
    _prefs.setInt('nasQ:$serverId:$folder', height);
    notifyListeners();
  }

  bool get onboarded => _prefs.getBool('onboarded') ?? false;
  set onboarded(bool v) => _setBool('onboarded', v);
}
