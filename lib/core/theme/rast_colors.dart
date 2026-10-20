import 'package:flutter/material.dart';

/// Semantic colour roles from `docs/06_DESIGN_SYSTEM.md` and
/// `design/tokens.json` (flutterRecommendations.semanticColors).
@immutable
class RastColors extends ThemeExtension<RastColors> {
  const RastColors({
    required this.canvas,
    required this.raised,
    required this.inputFill,
    required this.inputBorder,
    required this.sheet,
    required this.text,
    required this.body,
    required this.label,
    required this.menuDetail,
    required this.primary,
    required this.onPrimary,
    required this.primaryHover,
    required this.primaryDisabled,
    required this.onPrimaryDisabled,
    required this.accent,
    required this.accentContainer,
    required this.onAccentContainer,
    required this.outline,
    required this.navActive,
    required this.navInactive,
    required this.incomingBubble,
    required this.onIncomingBubble,
    required this.outgoingBubble,
    required this.onOutgoingBubble,
    required this.conversationCanvas,
    required this.error,
    required this.darkStage,
    required this.iconMuted,
    required this.statusActiveBg,
    required this.statusActiveFg,
    required this.plusGradientStart,
    required this.plusGradientEnd,
    required this.onPlusStrong,
    required this.onPlusSoft,
    required this.toastBg,
  });

  final Color canvas;
  final Color raised;
  final Color inputFill;
  final Color inputBorder;
  final Color sheet;
  final Color text;
  final Color body;
  final Color label;
  final Color menuDetail;
  final Color primary;
  final Color onPrimary;
  final Color primaryHover;
  final Color primaryDisabled;
  final Color onPrimaryDisabled;
  final Color accent;
  final Color accentContainer;
  final Color onAccentContainer;
  final Color outline;
  final Color navActive;
  final Color navInactive;
  final Color incomingBubble;
  final Color onIncomingBubble;
  final Color outgoingBubble;
  final Color onOutgoingBubble;
  final Color conversationCanvas;
  final Color error;

  /// Welcome and Match backgrounds: dark in both appearances.
  final Color darkStage;
  final Color iconMuted;
  final Color statusActiveBg;
  final Color statusActiveFg;
  final Color plusGradientStart;
  final Color plusGradientEnd;
  final Color onPlusStrong;
  final Color onPlusSoft;
  final Color toastBg;

  static const light = RastColors(
    canvas: Color(0xFFFFFFFF),
    raised: Color(0xFFF3F3F5),
    inputFill: Color(0xFFF7F7F9),
    inputBorder: Color(0xFFEEEEF2),
    sheet: Color(0xFFFFFFFF),
    text: Color(0xFF202124),
    body: Color(0xFF70707D),
    label: Color(0xFF41414D),
    menuDetail: Color(0xFF7C7C89),
    primary: Color(0xFFCF4131),
    onPrimary: Color(0xFFFFFFFF),
    primaryHover: Color(0xFFBA3628),
    primaryDisabled: Color(0xFFE9E2D8),
    onPrimaryDisabled: Color(0xFF8B8074),
    accent: Color(0xFFFA634F),
    accentContainer: Color(0xFFFFF0EC),
    onAccentContainer: Color(0xFFB43C2D),
    outline: Color(0xFFEBEBEE),
    navActive: Color(0xFFCD4937),
    navInactive: Color(0xFF7C7C89),
    incomingBubble: Color(0xFFF0F0F4),
    onIncomingBubble: Color(0xFF565662),
    outgoingBubble: Color(0xFFCF4131),
    onOutgoingBubble: Color(0xFFFFFFFF),
    conversationCanvas: Color(0xFFFCFCFD),
    error: Color(0xFFD7443D),
    darkStage: Color(0xFF202124),
    iconMuted: Color(0xFF9A9AA7),
    statusActiveBg: Color(0xFFECF8F0),
    statusActiveFg: Color(0xFF5FA57A),
    plusGradientStart: Color(0xFFFFE4D5),
    plusGradientEnd: Color(0xFFFFEFE4),
    onPlusStrong: Color(0xFF9B5035),
    onPlusSoft: Color(0xFFA4513F),
    toastBg: Color(0xFF282831),
  );

  static const dark = RastColors(
    canvas: Color(0xFF18191D),
    raised: Color(0xFF24252B),
    inputFill: Color(0xFF24252B),
    inputBorder: Color(0xFF3C3B45),
    sheet: Color(0xFF1E1F24),
    text: Color(0xFFF5F3F1),
    body: Color(0xFFAAA8B2),
    label: Color(0xFFE5E0E4),
    menuDetail: Color(0xFFAAA8B2),
    primary: Color(0xFFCF4131),
    onPrimary: Color(0xFFFFFFFF),
    primaryHover: Color(0xFFB83829),
    primaryDisabled: Color(0xFF2B2C33),
    onPrimaryDisabled: Color(0xFF9895A1),
    accent: Color(0xFFFF907F),
    accentContainer: Color(0xFF372622),
    onAccentContainer: Color(0xFFFF907F),
    outline: Color(0xFF35353D),
    navActive: Color(0xFFFF907F),
    navInactive: Color(0xFFA7A1AE),
    incomingBubble: Color(0xFF2A272F),
    onIncomingBubble: Color(0xFFE1D9E4),
    outgoingBubble: Color(0xFFB93F30),
    onOutgoingBubble: Color(0xFFFFFFFF),
    conversationCanvas: Color(0xFF15161A),
    error: Color(0xFFFF9C91),
    darkStage: Color(0xFF151619),
    iconMuted: Color(0xFFAFA1B2),
    statusActiveBg: Color(0xFF25372B),
    statusActiveFg: Color(0xFF9CD5AD),
    plusGradientStart: Color(0xFF3E2B23),
    plusGradientEnd: Color(0xFF302325),
    onPlusStrong: Color(0xFFFFC0A5),
    onPlusSoft: Color(0xFFD9A694),
    toastBg: Color(0xFF39343D),
  );

  bool get isDark => canvas == dark.canvas;

  @override
  RastColors copyWith() => this;

  @override
  RastColors lerp(ThemeExtension<RastColors>? other, double t) {
    if (other is! RastColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return RastColors(
      canvas: l(canvas, other.canvas),
      raised: l(raised, other.raised),
      inputFill: l(inputFill, other.inputFill),
      inputBorder: l(inputBorder, other.inputBorder),
      sheet: l(sheet, other.sheet),
      text: l(text, other.text),
      body: l(body, other.body),
      label: l(label, other.label),
      menuDetail: l(menuDetail, other.menuDetail),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primaryHover: l(primaryHover, other.primaryHover),
      primaryDisabled: l(primaryDisabled, other.primaryDisabled),
      onPrimaryDisabled: l(onPrimaryDisabled, other.onPrimaryDisabled),
      accent: l(accent, other.accent),
      accentContainer: l(accentContainer, other.accentContainer),
      onAccentContainer: l(onAccentContainer, other.onAccentContainer),
      outline: l(outline, other.outline),
      navActive: l(navActive, other.navActive),
      navInactive: l(navInactive, other.navInactive),
      incomingBubble: l(incomingBubble, other.incomingBubble),
      onIncomingBubble: l(onIncomingBubble, other.onIncomingBubble),
      outgoingBubble: l(outgoingBubble, other.outgoingBubble),
      onOutgoingBubble: l(onOutgoingBubble, other.onOutgoingBubble),
      conversationCanvas: l(conversationCanvas, other.conversationCanvas),
      error: l(error, other.error),
      darkStage: l(darkStage, other.darkStage),
      iconMuted: l(iconMuted, other.iconMuted),
      statusActiveBg: l(statusActiveBg, other.statusActiveBg),
      statusActiveFg: l(statusActiveFg, other.statusActiveFg),
      plusGradientStart: l(plusGradientStart, other.plusGradientStart),
      plusGradientEnd: l(plusGradientEnd, other.plusGradientEnd),
      onPlusStrong: l(onPlusStrong, other.onPlusStrong),
      onPlusSoft: l(onPlusSoft, other.onPlusSoft),
      toastBg: l(toastBg, other.toastBg),
    );
  }
}

extension RastColorsContext on BuildContext {
  RastColors get colors =>
      Theme.of(this).extension<RastColors>() ?? RastColors.light;
}
