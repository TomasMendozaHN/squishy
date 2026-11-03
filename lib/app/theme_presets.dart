import 'package:flutter/material.dart';

/// The design-token map. This is the only file allowed to contain raw colors;
/// everything else reads them through [Theme] or [SquishyTokens].
class PresetPalette {
  const PresetPalette({
    required this.brightness,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.background,
    required this.surface,
    required this.liquidA,
    required this.liquidB,
    required this.success,
    required this.danger,
    required this.warning,
  });

  /// A dark palette with the standard status colors unless given.
  const PresetPalette.dark({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.background,
    required this.surface,
    required this.liquidA,
    required this.liquidB,
    this.success = const Color(0xFF4ADE80),
    this.danger = const Color(0xFFF87171),
    this.warning = const Color(0xFFFBBF24),
  }) : brightness = Brightness.dark;

  /// A light palette with the standard status colors unless given.
  const PresetPalette.light({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.background,
    required this.surface,
    required this.liquidA,
    required this.liquidB,
    this.success = const Color(0xFF15803D),
    this.danger = const Color(0xFFDC2626),
    this.warning = const Color(0xFFB45309),
  }) : brightness = Brightness.light;

  /// The user's own theme: a main and an accent color; everything else is derived so text
  /// stays readable whatever they pick.
  factory PresetPalette.custom({required Brightness brightness, required Color main, required Color accent}) {
    final dark = brightness == Brightness.dark;
    final background = Color.alphaBlend(main.withValues(alpha: 0.05), dark ? _darkBase : _lightBase);
    final surface = dark ? Color.alphaBlend(main.withValues(alpha: 0.09), _darkSurface) : _white;
    final primary = readableOn(main, surface);
    final secondary = readableOn(accent, surface);
    return PresetPalette(
      brightness: brightness,
      primary: primary,
      secondary: secondary,
      tertiary: Color.lerp(primary, secondary, 0.5)!,
      background: background,
      surface: surface,
      liquidA: main,
      liquidB: accent,
      success: dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      danger: dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
      warning: dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
    );
  }

  /// This palette with every color that's used for text (accents and status colors) nudged
  /// to at least 4.5:1 contrast with the surface.
  PresetPalette readable() => PresetPalette(
        brightness: brightness,
        primary: readableOn(primary, surface),
        secondary: readableOn(secondary, surface),
        tertiary: readableOn(tertiary, surface),
        background: background,
        surface: surface,
        liquidA: liquidA,
        liquidB: liquidB,
        success: readableOn(success, surface),
        danger: readableOn(danger, surface),
        warning: readableOn(warning, surface),
      );

  final Brightness brightness;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color background;
  final Color surface;
  final Color liquidA;
  final Color liquidB;
  final Color success;
  final Color danger;
  final Color warning;
}

const _darkBase = Color(0xFF08090C);
const _darkSurface = Color(0xFF12141A);
const _lightBase = Color(0xFFF6F7F9);
const _white = Color(0xFFFFFFFF);
const _black = Color(0xFF000000);

/// WCAG contrast ratio between two colors (1–21).
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

/// [color] lightened (on dark backgrounds) or darkened (on light ones) just enough to reach
/// a 4.5:1 contrast with [background], so it works as text.
Color readableOn(Color color, Color background) {
  final towards = background.computeLuminance() < 0.5 ? _white : _black;
  var c = color;
  for (var i = 0; i < 20 && contrast(c, background) < 4.5; i++) {
    c = Color.lerp(c, towards, 0.08)!;
  }
  return c;
}

/// One theme in the picker.
class ThemeChoice {
  const ThemeChoice(this.id, this.label, this.hint, this.palette);

  final String id;
  final String label;
  final String hint;
  final PresetPalette palette;

  bool get isDark => palette.brightness == Brightness.dark;
}

abstract final class Themes {
  static const followSystemId = 'followSystem';
  static const customId = 'custom';
  static const defaultId = 'obsidianCyan';

  static ThemeChoice byId(String id) => all.firstWhere((t) => t.id == id, orElse: () => all.first);

  /// Night and day themes for "Follow system".
  static PresetPalette get systemDark => all.first.palette;
  static PresetPalette get systemLight => byId('oceanLight').palette;

  /// Colors offered for the custom theme.
  static const swatches = <Color>[
    Color(0xFFEF4444), Color(0xFFF97316), Color(0xFFF59E0B), Color(0xFFEAB308),
    Color(0xFF84CC16), Color(0xFF22C55E), Color(0xFF10B981), Color(0xFF14B8A6),
    Color(0xFF06B6D4), Color(0xFF0EA5E9), Color(0xFF3B82F6), Color(0xFF6366F1),
    Color(0xFF8B5CF6), Color(0xFFA855F7), Color(0xFFD946EF), Color(0xFFEC4899),
    Color(0xFFF43F5E), Color(0xFFFB7185), Color(0xFFFDBA74), Color(0xFFFDE047),
    Color(0xFF86EFAC), Color(0xFF67E8F9), Color(0xFFA5B4FC), Color(0xFFF0ABFC),
    Color(0xFF78716C), Color(0xFF64748B), Color(0xFFA3A3A3), Color(0xFFE5E5E5),
  ];

  /// Many of these follow well-known editor color schemes, chosen because their colors are
  /// tried and tested for long reading sessions.
  static const all = <ThemeChoice>[
    // Dark
    ThemeChoice('obsidianCyan', 'Obsidian Cyan', 'Near-black glass, glowing cyan water', PresetPalette(
      brightness: Brightness.dark,
      primary: Color(0xFF22D3EE), secondary: Color(0xFF818CF8), tertiary: Color(0xFF2DD4BF),
      background: Color(0xFF07090D), surface: Color(0xFF10141B),
      liquidA: Color(0xFF06B6D4), liquidB: Color(0xFF5EEAD4),
      success: Color(0xFF34D399), danger: Color(0xFFFB7185), warning: Color(0xFFFBBF24),
    )),
    ThemeChoice('midnightViolet', 'Midnight Violet', 'Deep indigo with neon violet & pink', PresetPalette(
      brightness: Brightness.dark,
      primary: Color(0xFFA78BFA), secondary: Color(0xFFF472B6), tertiary: Color(0xFF60A5FA),
      background: Color(0xFF0B0820), surface: Color(0xFF161233),
      liquidA: Color(0xFF8B5CF6), liquidB: Color(0xFFF472B6),
      success: Color(0xFF4ADE80), danger: Color(0xFFFB7185), warning: Color(0xFFFCD34D),
    )),
    ThemeChoice('sunsetCoral', 'Sunset Coral', 'Warm dusk tones, coral and gold', PresetPalette(
      brightness: Brightness.dark,
      primary: Color(0xFFFB923C), secondary: Color(0xFFF43F5E), tertiary: Color(0xFFFACC15),
      background: Color(0xFF140B0C), surface: Color(0xFF221416),
      liquidA: Color(0xFFF97316), liquidB: Color(0xFFFDE047),
      success: Color(0xFF86EFAC), danger: Color(0xFFFF6B81), warning: Color(0xFFFDE68A),
    )),
    ThemeChoice('deepSea', 'Deep Sea', 'Navy depths with sky-blue light', PresetPalette.dark(
      primary: Color(0xFF38BDF8), secondary: Color(0xFF818CF8), tertiary: Color(0xFF2DD4BF),
      background: Color(0xFF020617), surface: Color(0xFF0F172A),
      liquidA: Color(0xFF0EA5E9), liquidB: Color(0xFF6366F1),
    )),
    ThemeChoice('aurora', 'Aurora', 'Northern lights: green into violet', PresetPalette.dark(
      primary: Color(0xFF34D399), secondary: Color(0xFFA78BFA), tertiary: Color(0xFF38BDF8),
      background: Color(0xFF050B14), surface: Color(0xFF0D1726),
      liquidA: Color(0xFF10B981), liquidB: Color(0xFF8B5CF6),
    )),
    ThemeChoice('forestNight', 'Forest Night', 'Moss and lime under a dark canopy', PresetPalette.dark(
      primary: Color(0xFF4ADE80), secondary: Color(0xFFA3E635), tertiary: Color(0xFF2DD4BF),
      background: Color(0xFF0B1410), surface: Color(0xFF13201A),
      liquidA: Color(0xFF22C55E), liquidB: Color(0xFFA3E635),
    )),
    ThemeChoice('ember', 'Ember', 'Glowing coals, red into amber', PresetPalette.dark(
      primary: Color(0xFFF87171), secondary: Color(0xFFFB923C), tertiary: Color(0xFFFBBF24),
      background: Color(0xFF120A08), surface: Color(0xFF1E1310),
      liquidA: Color(0xFFEF4444), liquidB: Color(0xFFF59E0B),
      danger: Color(0xFFFCA5A5),
    )),
    ThemeChoice('royalGold', 'Royal Gold', 'Gold leaf on midnight purple', PresetPalette.dark(
      primary: Color(0xFFFACC15), secondary: Color(0xFFA78BFA), tertiary: Color(0xFFF59E0B),
      background: Color(0xFF0C0A14), surface: Color(0xFF17142A),
      liquidA: Color(0xFFEAB308), liquidB: Color(0xFFFDE68A),
    )),
    ThemeChoice('sakuraNight', 'Sakura Night', 'Cherry blossoms after dark', PresetPalette.dark(
      primary: Color(0xFFF9A8D4), secondary: Color(0xFFFDA4AF), tertiary: Color(0xFFC4B5FD),
      background: Color(0xFF160B12), surface: Color(0xFF24131D),
      liquidA: Color(0xFFEC4899), liquidB: Color(0xFFF9A8D4),
    )),
    ThemeChoice('graphite', 'Graphite', 'Monochrome, calm and focused', PresetPalette.dark(
      primary: Color(0xFFE5E5E5), secondary: Color(0xFFA3A3A3), tertiary: Color(0xFFD4D4D4),
      background: Color(0xFF0A0A0A), surface: Color(0xFF171717),
      liquidA: Color(0xFF737373), liquidB: Color(0xFFF5F5F5),
    )),
    ThemeChoice('dracula', 'Dracula', 'The classic: purple, pink and cyan', PresetPalette.dark(
      primary: Color(0xFFBD93F9), secondary: Color(0xFFFF79C6), tertiary: Color(0xFF8BE9FD),
      background: Color(0xFF21222C), surface: Color(0xFF282A36),
      liquidA: Color(0xFFBD93F9), liquidB: Color(0xFFFF79C6),
      success: Color(0xFF50FA7B), danger: Color(0xFFFF5555), warning: Color(0xFFF1FA8C),
    )),
    ThemeChoice('nordNight', 'Nord', 'Arctic, north-bluish and quiet', PresetPalette.dark(
      primary: Color(0xFF88C0D0), secondary: Color(0xFF81A1C1), tertiary: Color(0xFFA3BE8C),
      background: Color(0xFF242933), surface: Color(0xFF2E3440),
      liquidA: Color(0xFF5E81AC), liquidB: Color(0xFF88C0D0),
      success: Color(0xFFA3BE8C), danger: Color(0xFFBF616A), warning: Color(0xFFEBCB8B),
    )),
    ThemeChoice('gruvbox', 'Gruvbox', 'Retro groove: warm yellows and oranges', PresetPalette.dark(
      primary: Color(0xFFFABD2F), secondary: Color(0xFFFE8019), tertiary: Color(0xFFB8BB26),
      background: Color(0xFF1D2021), surface: Color(0xFF282828),
      liquidA: Color(0xFFD79921), liquidB: Color(0xFFFE8019),
      success: Color(0xFFB8BB26), danger: Color(0xFFFB4934), warning: Color(0xFFFABD2F),
    )),
    ThemeChoice('solarizedDark', 'Solarized Dark', 'Precise teal-blue, easy on the eyes', PresetPalette.dark(
      primary: Color(0xFF2AA198), secondary: Color(0xFF268BD2), tertiary: Color(0xFFB58900),
      background: Color(0xFF002B36), surface: Color(0xFF073642),
      liquidA: Color(0xFF268BD2), liquidB: Color(0xFF2AA198),
      success: Color(0xFF859900), danger: Color(0xFFDC322F), warning: Color(0xFFB58900),
    )),
    ThemeChoice('catppuccinMocha', 'Catppuccin Mocha', 'Soothing pastels on dark', PresetPalette.dark(
      primary: Color(0xFFCBA6F7), secondary: Color(0xFFF5C2E7), tertiary: Color(0xFF89DCEB),
      background: Color(0xFF11111B), surface: Color(0xFF1E1E2E),
      liquidA: Color(0xFFCBA6F7), liquidB: Color(0xFF89B4FA),
      success: Color(0xFFA6E3A1), danger: Color(0xFFF38BA8), warning: Color(0xFFF9E2AF),
    )),
    ThemeChoice('catppuccinMacchiato', 'Catppuccin Macchiato', 'Pastels, a shade lighter', PresetPalette.dark(
      primary: Color(0xFF8AADF4), secondary: Color(0xFFF5BDE6), tertiary: Color(0xFF8BD5CA),
      background: Color(0xFF181926), surface: Color(0xFF24273A),
      liquidA: Color(0xFF8AADF4), liquidB: Color(0xFFC6A0F6),
      success: Color(0xFFA6DA95), danger: Color(0xFFED8796), warning: Color(0xFFEED49F),
    )),
    ThemeChoice('tokyoNight', 'Tokyo Night', 'Neon city lights in blue and violet', PresetPalette.dark(
      primary: Color(0xFF7AA2F7), secondary: Color(0xFFBB9AF7), tertiary: Color(0xFF7DCFFF),
      background: Color(0xFF16161E), surface: Color(0xFF1A1B26),
      liquidA: Color(0xFF7AA2F7), liquidB: Color(0xFFBB9AF7),
      success: Color(0xFF9ECE6A), danger: Color(0xFFF7768E), warning: Color(0xFFE0AF68),
    )),
    ThemeChoice('oneDark', 'One Dark', 'Balanced and familiar', PresetPalette.dark(
      primary: Color(0xFF61AFEF), secondary: Color(0xFFC678DD), tertiary: Color(0xFF98C379),
      background: Color(0xFF21252B), surface: Color(0xFF282C34),
      liquidA: Color(0xFF61AFEF), liquidB: Color(0xFF56B6C2),
      success: Color(0xFF98C379), danger: Color(0xFFE06C75), warning: Color(0xFFE5C07B),
    )),
    ThemeChoice('monokai', 'Monokai', 'Electric lime and hot pink', PresetPalette.dark(
      primary: Color(0xFFA6E22E), secondary: Color(0xFFF92672), tertiary: Color(0xFF66D9EF),
      background: Color(0xFF1E1F1C), surface: Color(0xFF272822),
      liquidA: Color(0xFFA6E22E), liquidB: Color(0xFFE6DB74),
      success: Color(0xFFA6E22E), danger: Color(0xFFF92672), warning: Color(0xFFFD971F),
    )),
    ThemeChoice('rosePine', 'Rosé Pine', 'All natural pine, faux fur and soho vibes', PresetPalette.dark(
      primary: Color(0xFFEBBCBA), secondary: Color(0xFFC4A7E7), tertiary: Color(0xFF9CCFD8),
      background: Color(0xFF191724), surface: Color(0xFF1F1D2E),
      liquidA: Color(0xFFEB6F92), liquidB: Color(0xFFEBBCBA),
      success: Color(0xFF9CCFD8), danger: Color(0xFFEB6F92), warning: Color(0xFFF6C177),
    )),
    ThemeChoice('everforest', 'Everforest', 'Soft greens, comfortable for hours', PresetPalette.dark(
      primary: Color(0xFFA7C080), secondary: Color(0xFF83C092), tertiary: Color(0xFFDBBC7F),
      background: Color(0xFF232A2E), surface: Color(0xFF2D353B),
      liquidA: Color(0xFF83C092), liquidB: Color(0xFFA7C080),
      success: Color(0xFFA7C080), danger: Color(0xFFE67E80), warning: Color(0xFFDBBC7F),
    )),
    ThemeChoice('kanagawa', 'Kanagawa', 'Ink-wash blues from the Great Wave', PresetPalette.dark(
      primary: Color(0xFF7E9CD8), secondary: Color(0xFF957FB8), tertiary: Color(0xFFE6C384),
      background: Color(0xFF16161D), surface: Color(0xFF1F1F28),
      liquidA: Color(0xFF7E9CD8), liquidB: Color(0xFF7FB4CA),
      success: Color(0xFF98BB6C), danger: Color(0xFFE46876), warning: Color(0xFFE6C384),
    )),
    ThemeChoice('ayuMirage', 'Ayu Mirage', 'Muted blue-grey with marigold', PresetPalette.dark(
      primary: Color(0xFFFFCC66), secondary: Color(0xFFF28779), tertiary: Color(0xFF73D0FF),
      background: Color(0xFF1F2430), surface: Color(0xFF242936),
      liquidA: Color(0xFFFFA759), liquidB: Color(0xFFFFCC66),
      success: Color(0xFFD5FF80), danger: Color(0xFFF28779), warning: Color(0xFFFFCC66),
    )),
    ThemeChoice('synthwave', 'Synthwave', '80s neon: magenta and cyan', PresetPalette.dark(
      primary: Color(0xFFFF7EDB), secondary: Color(0xFF36F9F6), tertiary: Color(0xFFFEDE5D),
      background: Color(0xFF1A1028), surface: Color(0xFF262335),
      liquidA: Color(0xFFFF7EDB), liquidB: Color(0xFF36F9F6),
      success: Color(0xFF72F1B8), danger: Color(0xFFFE4450), warning: Color(0xFFFEDE5D),
    )),
    ThemeChoice('nightOwl', 'Night Owl', 'Made for coding late at night', PresetPalette.dark(
      primary: Color(0xFF82AAFF), secondary: Color(0xFFC792EA), tertiary: Color(0xFF7FDBCA),
      background: Color(0xFF010E1A), surface: Color(0xFF011627),
      liquidA: Color(0xFF82AAFF), liquidB: Color(0xFF7FDBCA),
      success: Color(0xFF22DA6E), danger: Color(0xFFEF5350), warning: Color(0xFFFFCB8B),
    )),
    ThemeChoice('palenight', 'Palenight', 'Soft lilac and periwinkle', PresetPalette.dark(
      primary: Color(0xFFC792EA), secondary: Color(0xFF82AAFF), tertiary: Color(0xFF89DDFF),
      background: Color(0xFF202331), surface: Color(0xFF292D3E),
      liquidA: Color(0xFFC792EA), liquidB: Color(0xFF82AAFF),
      success: Color(0xFFC3E88D), danger: Color(0xFFF07178), warning: Color(0xFFFFCB6B),
    )),
    ThemeChoice('cobalt', 'Cobalt', 'Bold blue with sunny yellow', PresetPalette.dark(
      primary: Color(0xFFFFC600), secondary: Color(0xFFFF9D00), tertiary: Color(0xFF9EFFFF),
      background: Color(0xFF15232D), surface: Color(0xFF193549),
      liquidA: Color(0xFF0088FF), liquidB: Color(0xFFFFC600),
      success: Color(0xFF3AD900), danger: Color(0xFFFF628C), warning: Color(0xFFFFC600),
    )),
    ThemeChoice('poimandres', 'Poimandres', 'Minimal mint and ice', PresetPalette.dark(
      primary: Color(0xFF5DE4C7), secondary: Color(0xFFADD7FF), tertiary: Color(0xFFFCC5E9),
      background: Color(0xFF171922), surface: Color(0xFF1B1E28),
      liquidA: Color(0xFF5DE4C7), liquidB: Color(0xFF89DDFF),
      success: Color(0xFF5DE4C7), danger: Color(0xFFD0679D), warning: Color(0xFFFFFAC2),
    )),
    // Light
    ThemeChoice('oceanLight', 'Ocean Light', 'Clean, airy white with ocean blue', PresetPalette(
      brightness: Brightness.light,
      primary: Color(0xFF0369A1), secondary: Color(0xFF6366F1), tertiary: Color(0xFF0EA5E9),
      background: Color(0xFFF6F8FB), surface: Color(0xFFFFFFFF),
      liquidA: Color(0xFF0284C7), liquidB: Color(0xFF38BDF8),
      success: Color(0xFF059669), danger: Color(0xFFE11D48), warning: Color(0xFFD97706),
    )),
    ThemeChoice('mintFresh', 'Mint Fresh', 'Soft light mint with teal accents', PresetPalette(
      brightness: Brightness.light,
      primary: Color(0xFF0F766E), secondary: Color(0xFF65A30D), tertiary: Color(0xFF14B8A6),
      background: Color(0xFFF2FBF8), surface: Color(0xFFFFFFFF),
      liquidA: Color(0xFF14B8A6), liquidB: Color(0xFF86EFAC),
      success: Color(0xFF16A34A), danger: Color(0xFFDC2626), warning: Color(0xFFCA8A04),
    )),
    ThemeChoice('lavenderMist', 'Lavender Mist', 'Light violet with a pink blush', PresetPalette.light(
      primary: Color(0xFF6D28D9), secondary: Color(0xFFBE185D), tertiary: Color(0xFF2563EB),
      background: Color(0xFFF5F3FF), surface: Color(0xFFFFFFFF),
      liquidA: Color(0xFF8B5CF6), liquidB: Color(0xFFEC4899),
    )),
    ThemeChoice('sakura', 'Sakura', 'Cherry blossom pink in daylight', PresetPalette.light(
      primary: Color(0xFFBE185D), secondary: Color(0xFF9333EA), tertiary: Color(0xFFE11D48),
      background: Color(0xFFFFF1F5), surface: Color(0xFFFFFFFF),
      liquidA: Color(0xFFEC4899), liquidB: Color(0xFFF9A8D4),
    )),
    ThemeChoice('peachCream', 'Peach Cream', 'Warm apricot and rose', PresetPalette.light(
      primary: Color(0xFFC2410C), secondary: Color(0xFFBE185D), tertiary: Color(0xFFB45309),
      background: Color(0xFFFFF7ED), surface: Color(0xFFFFFFFF),
      liquidA: Color(0xFFF97316), liquidB: Color(0xFFFB7185),
    )),
    ThemeChoice('sandDune', 'Sand Dune', 'Desert gold and terracotta', PresetPalette.light(
      primary: Color(0xFF92400E), secondary: Color(0xFFB45309), tertiary: Color(0xFF0F766E),
      background: Color(0xFFFAF6EE), surface: Color(0xFFFFFFFF),
      liquidA: Color(0xFFD97706), liquidB: Color(0xFFFCD34D),
    )),
    ThemeChoice('meadow', 'Meadow', 'Fresh grass and morning sun', PresetPalette.light(
      primary: Color(0xFF15803D), secondary: Color(0xFF4D7C0F), tertiary: Color(0xFFA16207),
      background: Color(0xFFF4FBF2), surface: Color(0xFFFFFFFF),
      liquidA: Color(0xFF22C55E), liquidB: Color(0xFFFACC15),
    )),
    ThemeChoice('skyHigh', 'Sky High', 'Bright cyan and cloud white', PresetPalette.light(
      primary: Color(0xFF0E7490), secondary: Color(0xFF1D4ED8), tertiary: Color(0xFF0891B2),
      background: Color(0xFFF0FAFF), surface: Color(0xFFFFFFFF),
      liquidA: Color(0xFF06B6D4), liquidB: Color(0xFF60A5FA),
    )),
    ThemeChoice('paper', 'Paper', 'Ink on paper, no distractions', PresetPalette.light(
      primary: Color(0xFF1C1917), secondary: Color(0xFF57534E), tertiary: Color(0xFF44403C),
      background: Color(0xFFF5F5F4), surface: Color(0xFFFFFFFF),
      liquidA: Color(0xFF44403C), liquidB: Color(0xFFA8A29E),
    )),
    ThemeChoice('solarizedLight', 'Solarized Light', 'Warm parchment, precise colors', PresetPalette.light(
      primary: Color(0xFF1F6FA8), secondary: Color(0xFFB02A6B), tertiary: Color(0xFF1E7A73),
      background: Color(0xFFEEE8D5), surface: Color(0xFFFDF6E3),
      liquidA: Color(0xFF268BD2), liquidB: Color(0xFF2AA198),
      success: Color(0xFF5F6F00), danger: Color(0xFFC0281F), warning: Color(0xFF8A6800),
    )),
    ThemeChoice('catppuccinLatte', 'Catppuccin Latte', 'Pastel morning coffee', PresetPalette.light(
      primary: Color(0xFF8839EF), secondary: Color(0xFFC03D9E), tertiary: Color(0xFF1E66F5),
      background: Color(0xFFE6E9EF), surface: Color(0xFFEFF1F5),
      liquidA: Color(0xFF8839EF), liquidB: Color(0xFF1E66F5),
      success: Color(0xFF2E7D16), danger: Color(0xFFD20F39), warning: Color(0xFF9A5B00),
    )),
    ThemeChoice('rosePineDawn', 'Rosé Pine Dawn', 'Morning light on rosé', PresetPalette.light(
      primary: Color(0xFF7A6496), secondary: Color(0xFFB4637A), tertiary: Color(0xFF286983),
      background: Color(0xFFF2E9E1), surface: Color(0xFFFFFAF3),
      liquidA: Color(0xFFB4637A), liquidB: Color(0xFFD7827E),
      success: Color(0xFF286983), danger: Color(0xFFB4637A), warning: Color(0xFFA2620F),
    )),
    ThemeChoice('githubLight', 'GitHub Light', 'Crisp and familiar', PresetPalette.light(
      primary: Color(0xFF0969DA), secondary: Color(0xFF8250DF), tertiary: Color(0xFF1A7F37),
      background: Color(0xFFF6F8FA), surface: Color(0xFFFFFFFF),
      liquidA: Color(0xFF0969DA), liquidB: Color(0xFF54AEFF),
      success: Color(0xFF1A7F37), danger: Color(0xFFCF222E), warning: Color(0xFF9A6700),
    )),
    ThemeChoice('everforestLight', 'Everforest Light', 'Soft greens in daylight', PresetPalette.light(
      primary: Color(0xFF5C6A00), secondary: Color(0xFF2A7F5F), tertiary: Color(0xFF8A6400),
      background: Color(0xFFEFEBD4), surface: Color(0xFFFDF6E3),
      liquidA: Color(0xFF8DA101), liquidB: Color(0xFF35A77C),
      success: Color(0xFF5C6A00), danger: Color(0xFFC33B3B), warning: Color(0xFF8A6400),
    )),
    ThemeChoice('nordSnow', 'Nord Snow', 'Arctic frost in daylight', PresetPalette.light(
      primary: Color(0xFF4C6A92), secondary: Color(0xFF8A5F82), tertiary: Color(0xFF3F7473),
      background: Color(0xFFE5E9F0), surface: Color(0xFFECEFF4),
      liquidA: Color(0xFF5E81AC), liquidB: Color(0xFF88C0D0),
      success: Color(0xFF4F6B3A), danger: Color(0xFFA5424C), warning: Color(0xFF8A6A1C),
    )),
    ThemeChoice('ayuLight', 'Ayu Light', 'Bright and warm with orange', PresetPalette.light(
      primary: Color(0xFFB85A00), secondary: Color(0xFF1F6FB0), tertiary: Color(0xFF5C7A00),
      background: Color(0xFFF3F4F5), surface: Color(0xFFFCFCFC),
      liquidA: Color(0xFFFA8D3E), liquidB: Color(0xFFF2AE49),
    )),
  ];
}

/// Brand colors used by the logo regardless of theme.
abstract final class BrandColors {
  static const blobTop = Color(0xFF7DF9FF);
  static const blobBottom = Color(0xFF8B5CF6);
  static const face = Color(0xFF1B1035);
  static const shine = Color(0xFFFFFFFF);
  static const cheek = Color(0xFFFF8FB1);
}

/// Third-party brand colors for the share buttons.
abstract final class ShareColors {
  static const whatsapp = Color(0xFF25D366);
  static const gmail = Color(0xFFEA4335);
  static const onBrand = Color(0xFFFFFFFF);
}
