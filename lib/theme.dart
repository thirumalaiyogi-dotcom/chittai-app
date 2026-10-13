// சிட்டை — நிறங்கள் (WhatsApp பாணி light / dark — index.html THEMES-ன் அதே மதிப்புகள்) + எழுத்துரு
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'state.dart';

// ═══ SITTA PRO v3 — நிறங்கள் ஒரே இடத்தில் ═══
class AppColors {
  AppColors._();
  static const Color brand = Color(0xFF14532D); // header, brand
  static const Color primary = Color(0xFF15803D); // பொத்தான்கள்
  static const Color primaryDark = Color(0xFF166534); // வெளிர் பச்சை மேல் எழுத்து
  static const Color tint = Color(0xFFECF6EF);
  static const Color bg = Color(0xFFF6F7F4);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF1C2420);
  static const Color muted = Color(0xFF6B7570);
  static const Color muted2 = Color(0xFF4D5752);
  static const Color border = Color(0xFFE4E9E5);
  static const Color inputBorder = Color(0xFFD6DDD8);
  // dark mode மட்டும்
  static const Color darkPrimary = Color(0xFF22A35A);
  static const Color darkPrimaryDark = Color(0xFF4ADE80);
  static const Color darkTint = Color(0x2922A35A); // primary 16%
  static const Color darkPrice = Color(0xFF86EFAC);
}

class Pal {
  final Color bg, card, card2, card3, bd, inputBd, text, mu, mu2, g, g2, gc, cyan, pink, or, red, hdr, hdr2;
  const Pal({
    required this.bg,
    required this.card,
    required this.card2,
    required this.card3,
    required this.bd,
    required this.inputBd,
    required this.text,
    required this.mu,
    required this.mu2,
    required this.g,
    required this.g2,
    required this.gc,
    required this.cyan,
    required this.pink,
    required this.or,
    required this.red,
    required this.hdr,
    required this.hdr2,
  });
}

const Pal kLight = Pal(
  bg: AppColors.bg,
  card: AppColors.card,
  card2: Color(0xFFF9FAF8),
  card3: Color(0xFFEFF3EF),
  bd: AppColors.border,
  inputBd: AppColors.inputBorder,
  text: AppColors.text,
  mu: AppColors.muted,
  mu2: AppColors.muted2,
  g: AppColors.primary,
  g2: AppColors.primaryDark,
  gc: AppColors.tint,
  cyan: Color(0xFF0891B2),
  pink: Color(0xFFDC2626),
  or: Color(0xFFD97706),
  red: Color(0xFFDC2626),
  hdr: AppColors.brand,
  hdr2: AppColors.primaryDark,
);

// dark: primary / primaryDark / tint மட்டும் மாறும்; மற்றவை முன்பு போல
const Pal kDark = Pal(
  bg: Color(0xFF111B21),
  card: Color(0xFF1F2C34),
  card2: Color(0xFF182229),
  card3: Color(0xFF0D1418),
  bd: Color(0xFF2A3942),
  inputBd: Color(0xFF2A3942),
  text: Color(0xFFE9EDEF),
  mu: Color(0xFF8696A0),
  mu2: Color(0xFFAEBAC1),
  g: AppColors.darkPrimary,
  g2: AppColors.darkPrimaryDark,
  gc: AppColors.darkTint,
  cyan: Color(0xFF53BDEB),
  pink: Color(0xFFEF9A9A),
  or: Color(0xFFFFB74D),
  red: Color(0xFFE53935),
  hdr: Color(0xFF1F2C34),
  hdr2: Color(0xFF182229),
);

// இப்போதைய நிறங்கள்
Pal get P => AppState.I.dark ? kDark : kLight;

// பச்சை header gradient (#14532d → #15803d)
LinearGradient get kHeroGrad => AppState.I.dark
    ? const LinearGradient(colors: [Color(0xFF1F2C34), Color(0xFF182229)], begin: Alignment.topLeft, end: Alignment.bottomRight)
    : const LinearGradient(colors: [Color(0xFF14532D), Color(0xFF15803D)], begin: Alignment.topLeft, end: Alignment.bottomRight);

const LinearGradient kBtnGrad = LinearGradient(colors: [Color(0xFF15803D), Color(0xFF166534)], begin: Alignment.topLeft, end: Alignment.bottomRight);

Color hexColor(String s, [Color fb = const Color(0xFFE3F3E6)]) {
  var h = s.trim().replaceAll('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null || h.length != 8 ? fb : Color(v);
}

// எழுத்து நடை
TextStyle ts(double size, {FontWeight w = FontWeight.w400, Color? c, double? h, TextDecoration? deco, double? ls}) =>
    TextStyle(fontSize: size, fontWeight: w, color: c ?? P.text, height: h, decoration: deco, decorationColor: c, letterSpacing: ls);

// விலை/மொத்தம்: எண்கள் ஒரே அகலம் (tabular), dark-ல் விலை #86EFAC
TextStyle pop(double size, {FontWeight w = FontWeight.w800, Color? c, TextDecoration? deco}) => GoogleFonts.poppins(
      fontSize: size,
      fontWeight: w,
      color: c ?? (AppState.I.dark ? AppColors.darkPrice : P.text),
      decoration: deco,
      decorationColor: c,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

// phone-ல் "அசைவுகளை நீக்கு" (Remove animations) இயக்கப்பட்டிருந்தால் true
bool get reducedMotion => WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;

// விசைப்பலகை / D-pad focus: 2.5px primary வெளிக்கோடு (தொடுதிரையில் சாதாரண அளவு)
double focusW() => FocusManager.instance.highlightMode == FocusHighlightMode.traditional ? 2.5 : 1.5;

const FontWeight w6 = FontWeight.w600, w7 = FontWeight.w700, w8 = FontWeight.w800, w9 = FontWeight.w900;

ThemeData buildTheme(bool dark) {
  final p = dark ? kDark : kLight;
  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.g,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: p.g,
      surface: p.card,
    ),
    splashFactory: InkRipple.splashFactory,
    dividerColor: p.bd,
  );
  return base.copyWith(
    textTheme: GoogleFonts.notoSansTamilTextTheme(base.textTheme).apply(bodyColor: p.text, displayColor: p.text),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.card, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(backgroundColor: p.card, surfaceTintColor: Colors.transparent),
    // HTML பொத்தான்கள்: radius 12, 1.5px எல்லை, w800 எழுத்து, Material நிழல்/tint இல்லை
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.mu2,
        backgroundColor: p.card,
        side: BorderSide(color: p.bd, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ).copyWith(
        side: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.focused) ? BorderSide(color: p.g, width: 2.5) : BorderSide(color: p.bd, width: 1.5)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.g2, textStyle: const TextStyle(fontWeight: FontWeight.w800)).copyWith(
        side: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.focused) ? BorderSide(color: p.g, width: 2.5) : null),
      ),
    ),
    focusColor: p.g.withValues(alpha: .18),
    // HTML .acc-row / பட்டியல் வரிசைகள்
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      minVerticalPadding: 13,
      iconColor: p.g2,
      textColor: p.text,
      titleTextStyle: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: p.text),
      subtitleTextStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.mu),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? const Color(0xFF15803D) : p.bd),
      trackOutlineColor: WidgetStatePropertyAll(p.bd),
    ),
  );
}
