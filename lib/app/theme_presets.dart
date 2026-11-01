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

enum ThemePreset {
  obsidianCyan('Obsidian Cyan', 'Near-black glass, glowing cyan water'),
  midnightViolet('Midnight Violet', 'Deep indigo with neon violet & pink'),
  sunsetCoral('Sunset Coral', 'Warm dusk tones, coral and gold'),
  oceanLight('Ocean Light', 'Clean, airy white with ocean blue'),
  mintFresh('Mint Fresh', 'Soft light mint with teal accents'),
  followSystem('Follow system', 'Obsidian at night, Ocean by day');

  const ThemePreset(this.label, this.hint);
  final String label;
  final String hint;

  PresetPalette palette(Brightness platform) => switch (this) {
        ThemePreset.obsidianCyan => _obsidian,
        ThemePreset.midnightViolet => _midnight,
        ThemePreset.sunsetCoral => _sunset,
        ThemePreset.oceanLight => _ocean,
        ThemePreset.mintFresh => _mint,
        ThemePreset.followSystem =>
          platform == Brightness.dark ? _obsidian : _ocean,
      };
}

const _obsidian = PresetPalette(
  brightness: Brightness.dark,
  primary: Color(0xFF22D3EE),
  secondary: Color(0xFF818CF8),
  tertiary: Color(0xFF2DD4BF),
  background: Color(0xFF07090D),
  surface: Color(0xFF10141B),
  liquidA: Color(0xFF06B6D4),
  liquidB: Color(0xFF5EEAD4),
  success: Color(0xFF34D399),
  danger: Color(0xFFFB7185),
  warning: Color(0xFFFBBF24),
);

const _midnight = PresetPalette(
  brightness: Brightness.dark,
  primary: Color(0xFFA78BFA),
  secondary: Color(0xFFF472B6),
  tertiary: Color(0xFF60A5FA),
  background: Color(0xFF0B0820),
  surface: Color(0xFF161233),
  liquidA: Color(0xFF8B5CF6),
  liquidB: Color(0xFFF472B6),
  success: Color(0xFF4ADE80),
  danger: Color(0xFFFB7185),
  warning: Color(0xFFFCD34D),
);

const _sunset = PresetPalette(
  brightness: Brightness.dark,
  primary: Color(0xFFFB923C),
  secondary: Color(0xFFF43F5E),
  tertiary: Color(0xFFFACC15),
  background: Color(0xFF140B0C),
  surface: Color(0xFF221416),
  liquidA: Color(0xFFF97316),
  liquidB: Color(0xFFFDE047),
  success: Color(0xFF86EFAC),
  danger: Color(0xFFFF6B81),
  warning: Color(0xFFFDE68A),
);

const _ocean = PresetPalette(
  brightness: Brightness.light,
  primary: Color(0xFF0369A1),
  secondary: Color(0xFF6366F1),
  tertiary: Color(0xFF0EA5E9),
  background: Color(0xFFF6F8FB),
  surface: Color(0xFFFFFFFF),
  liquidA: Color(0xFF0284C7),
  liquidB: Color(0xFF38BDF8),
  success: Color(0xFF059669),
  danger: Color(0xFFE11D48),
  warning: Color(0xFFD97706),
);

const _mint = PresetPalette(
  brightness: Brightness.light,
  primary: Color(0xFF0F766E),
  secondary: Color(0xFF65A30D),
  tertiary: Color(0xFF14B8A6),
  background: Color(0xFFF2FBF8),
  surface: Color(0xFFFFFFFF),
  liquidA: Color(0xFF14B8A6),
  liquidB: Color(0xFF86EFAC),
  success: Color(0xFF16A34A),
  danger: Color(0xFFDC2626),
  warning: Color(0xFFCA8A04),
);

/// Brand colors used by the logo regardless of theme.
abstract final class BrandColors {
  static const blobTop = Color(0xFF7DF9FF);
  static const blobBottom = Color(0xFF8B5CF6);
  static const face = Color(0xFF1B1035);
  static const shine = Color(0xFFFFFFFF);
  static const cheek = Color(0xFFFF8FB1);
}
