import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/settings.dart';
import 'theme_presets.dart';

/// Spacing, radii, motion and effect colors. Read with `context.tokens`.
@immutable
class SquishyTokens extends ThemeExtension<SquishyTokens> {
  const SquishyTokens({
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.liquidA,
    required this.liquidB,
    required this.glass,
    required this.glassBorder,
    required this.success,
    required this.danger,
    required this.warning,
    required this.reduceMotion,
  });

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 24;
  static const double space6 = 32;
  static const double space7 = 48;

  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final Color liquidA;
  final Color liquidB;
  final Color glass;
  final Color glassBorder;
  final Color success;
  final Color danger;
  final Color warning;
  final bool reduceMotion;

  Duration get fast => reduceMotion ? Duration.zero : const Duration(milliseconds: 180);
  Duration get medium => reduceMotion ? Duration.zero : const Duration(milliseconds: 320);
  Duration get slow => reduceMotion ? Duration.zero : const Duration(milliseconds: 600);
  Curve get curve => Curves.easeOutCubic;

  LinearGradient get liquidGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [liquidA, liquidB],
      );

  @override
  SquishyTokens copyWith({bool? reduceMotion}) => SquishyTokens(
        radiusSm: radiusSm,
        radiusMd: radiusMd,
        radiusLg: radiusLg,
        liquidA: liquidA,
        liquidB: liquidB,
        glass: glass,
        glassBorder: glassBorder,
        success: success,
        danger: danger,
        warning: warning,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );

  @override
  SquishyTokens lerp(SquishyTokens? other, double t) {
    if (other == null) return this;
    double l(double a, double b) => a + (b - a) * t;
    return SquishyTokens(
      radiusSm: l(radiusSm, other.radiusSm),
      radiusMd: l(radiusMd, other.radiusMd),
      radiusLg: l(radiusLg, other.radiusLg),
      liquidA: Color.lerp(liquidA, other.liquidA, t)!,
      liquidB: Color.lerp(liquidB, other.liquidB, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      reduceMotion: t < 0.5 ? reduceMotion : other.reduceMotion,
    );
  }
}

extension TokensContext on BuildContext {
  SquishyTokens get tokens => Theme.of(this).extension<SquishyTokens>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

SquishyTokens tokensFor(PresetPalette p, CornerStyle corners, bool reduceMotion) {
  final dark = p.brightness == Brightness.dark;
  final ink = dark ? Colors.white : Colors.black;
  return SquishyTokens(
    radiusSm: corners.base * 0.6,
    radiusMd: corners.base,
    radiusLg: corners.base * 1.6,
    liquidA: p.liquidA,
    liquidB: p.liquidB,
    glass: Color.alphaBlend(ink.withValues(alpha: dark ? 0.04 : 0.02), p.surface),
    glassBorder: ink.withValues(alpha: dark ? 0.08 : 0.07),
    success: p.success,
    danger: p.danger,
    warning: p.warning,
    reduceMotion: reduceMotion,
  );
}

ThemeData buildTheme({
  required PresetPalette palette,
  required CornerStyle corners,
  required AppFont font,
  required bool reduceMotion,
}) {
  final colors = FlexSchemeColor(
    primary: palette.primary,
    primaryContainer: Color.alphaBlend(
      palette.primary.withValues(alpha: 0.22),
      palette.surface,
    ),
    secondary: palette.secondary,
    secondaryContainer: Color.alphaBlend(
      palette.secondary.withValues(alpha: 0.22),
      palette.surface,
    ),
    tertiary: palette.tertiary,
    tertiaryContainer: Color.alphaBlend(
      palette.tertiary.withValues(alpha: 0.22),
      palette.surface,
    ),
    error: palette.danger,
  );
  final sub = FlexSubThemesData(
    defaultRadius: corners.base,
    blendOnLevel: 12,
    inputDecoratorIsFilled: true,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    inputDecoratorUnfocusedHasBorder: false,
    navigationBarIndicatorOpacity: 0.18,
    navigationBarLabelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
    bottomSheetRadius: corners.base * 1.6,
    cardElevation: 0,
    chipRadius: corners.base,
  );
  final dark = palette.brightness == Brightness.dark;
  final base = dark
      ? FlexThemeData.dark(
          colors: colors,
          surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
          blendLevel: 6,
          subThemesData: sub,
          visualDensity: VisualDensity.standard,
        )
      : FlexThemeData.light(
          colors: colors,
          surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
          blendLevel: 4,
          subThemesData: sub,
          visualDensity: VisualDensity.standard,
        );

  final scheme = base.colorScheme.copyWith(surface: palette.surface);
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: GoogleFonts.getTextTheme(font.family, base.textTheme),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    extensions: [tokensFor(palette, corners, reduceMotion)],
  );
}
