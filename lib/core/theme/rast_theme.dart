import 'package:flutter/material.dart';

import 'rast_colors.dart';

const String rastFontFamily = 'PlusJakartaSans';

/// Motion references from the prototype CSS.
const Curve rastEase = Cubic(0.2, 0.75, 0.2, 1);
const Duration rastButtonDuration = Duration(milliseconds: 180);
const Duration rastPageDuration = Duration(milliseconds: 240);
const Duration rastSheetDuration = Duration(milliseconds: 280);

/// Spacing scale: 4, 8, 12, 16, 20, 24, 32.
abstract final class Space {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal page gutter. Every page, header and sheet aligns to it.
  static const double page = 24;
}

FontWeight _bucket(int weight) {
  if (weight < 350) return FontWeight.w300;
  if (weight < 450) return FontWeight.w400;
  if (weight < 550) return FontWeight.w500;
  if (weight < 650) return FontWeight.w600;
  if (weight < 750) return FontWeight.w700;
  return FontWeight.w800;
}

/// Plus Jakarta Sans at any variable weight 400–800. Never italic.
TextStyle rastStyle({
  required double size,
  required int weight,
  double? height,
  double? letterSpacing,
  Color? color,
}) {
  return TextStyle(
    fontFamily: rastFontFamily,
    fontSize: size,
    fontWeight: _bucket(weight),
    fontVariations: [FontVariation('wght', weight.toDouble())],
    fontStyle: FontStyle.normal,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
  );
}

/// Named text roles from the design system.
abstract final class RastText {
  static TextStyle sectionTitle(RastColors c) =>
      rastStyle(size: 31, weight: 800, height: 1.13, letterSpacing: -1.2, color: c.text);
  static TextStyle setupHeadline(RastColors c) =>
      rastStyle(size: 36, weight: 800, height: 1.13, letterSpacing: -1.55, color: c.text);
  static TextStyle body(RastColors c) =>
      rastStyle(size: 14, weight: 450, height: 1.65, color: c.body);
  static TextStyle bodySmall(RastColors c) =>
      rastStyle(size: 12, weight: 450, height: 1.7, color: c.body);
  static TextStyle action(RastColors c) =>
      rastStyle(size: 15, weight: 750, color: c.onPrimary);
  static TextStyle input(RastColors c) =>
      rastStyle(size: 16, weight: 500, color: c.text);
  static TextStyle fieldLabel(RastColors c) =>
      rastStyle(size: 14, weight: 750, color: c.label);
  static TextStyle menuLabel(RastColors c) =>
      rastStyle(size: 14, weight: 700, color: c.label);
  static TextStyle menuDetail(RastColors c) =>
      rastStyle(size: 12, weight: 450, height: 1.5, color: c.menuDetail);
  static TextStyle message(RastColors c) =>
      rastStyle(size: 14, weight: 450, height: 1.6, color: c.onIncomingBubble);
  static TextStyle navLabel(RastColors c) =>
      rastStyle(size: 10, weight: 700, letterSpacing: -0.1, color: c.navInactive);
  static TextStyle eyebrow(RastColors c, {Color? color}) =>
      rastStyle(size: 10, weight: 750, letterSpacing: 1.3, color: color ?? c.menuDetail);
  static TextStyle kicker(RastColors c) =>
      rastStyle(size: 10, weight: 800, letterSpacing: 1.7, color: c.isDark ? c.accent : const Color(0xFFC24533));
  static TextStyle help(RastColors c) =>
      rastStyle(size: 12, weight: 450, height: 1.8, color: c.isDark ? c.body : const Color(0xFF747480));
  static TextStyle error(RastColors c) =>
      rastStyle(size: 13, weight: 500, height: 1.65, color: c.error);
  static TextStyle tiny(RastColors c) =>
      rastStyle(size: 11, weight: 450, height: 1.8, color: c.isDark ? c.body : const Color(0xFF73737E));
  static TextStyle sheetTitle(RastColors c) =>
      rastStyle(size: 26, weight: 800, height: 1.2, letterSpacing: -0.9, color: c.isDark ? c.label : const Color(0xFF35353F));
  static TextStyle pageSubtitle(RastColors c) =>
      rastStyle(size: 12, weight: 450, height: 1.6, color: c.body);
  static TextStyle emptyTitle(RastColors c) =>
      rastStyle(size: 27, weight: 800, height: 1.12, letterSpacing: -1, color: c.text);
}

ThemeData rastTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? RastColors.dark : RastColors.light;
  final textTheme = TextTheme(
    displayLarge: RastText.setupHeadline(c),
    headlineMedium: RastText.sectionTitle(c),
    titleLarge: RastText.sheetTitle(c),
    titleMedium: RastText.menuLabel(c),
    bodyLarge: RastText.input(c),
    bodyMedium: RastText.body(c),
    bodySmall: RastText.bodySmall(c),
    labelLarge: RastText.action(c),
    labelMedium: RastText.fieldLabel(c),
    labelSmall: RastText.navLabel(c),
  );
  return ThemeData(
    useMaterial3: false,
    brightness: brightness,
    fontFamily: rastFontFamily,
    primaryColor: c.primary,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.accent,
      onSecondary: c.onPrimary,
      error: c.error,
      onError: c.onPrimary,
      surface: c.canvas,
      onSurface: c.text,
    ),
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.canvas,
    dividerColor: c.outline,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.accent),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.sheet,
      modalBackgroundColor: c.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
    ),
    iconTheme: IconThemeData(color: c.text, size: 22),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    extensions: [c],
  );
}
