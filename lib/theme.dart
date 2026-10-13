// சிட்டை — நிறங்கள் (WhatsApp பாணி light / dark — index.html THEMES-ன் அதே மதிப்புகள்) + எழுத்துரு
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'state.dart';

class Pal {
  final Color bg, card, card2, card3, bd, text, mu, mu2, g, g2, gc, cyan, pink, or, red, hdr, hdr2;
  const Pal({
    required this.bg,
    required this.card,
    required this.card2,
    required this.card3,
    required this.bd,
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
  bg: Color(0xFFF5F7F8),
  card: Color(0xFFFFFFFF),
  card2: Color(0xFFF8FAFA),
  card3: Color(0xFFEEF3F1),
  bd: Color(0xFFE3EAE7),
  text: Color(0xFF17201D),
  mu: Color(0xFF6B7773), // முன்பு #87938F (3.2:1) → 4.65:1
  mu2: Color(0xFF64706C),
  g: Color(0xFF00A884),
  g2: Color(0xFF007A63),
  gc: Color(0xFFEAF8F3),
  cyan: Color(0xFF0891B2),
  pink: Color(0xFFDC2626),
  or: Color(0xFFD97706),
  red: Color(0xFFDC2626),
  hdr: Color(0xFF075E54),
  hdr2: Color(0xFF007A63),
);

const Pal kDark = Pal(
  bg: Color(0xFF111B21),
  card: Color(0xFF1F2C34),
  card2: Color(0xFF182229),
  card3: Color(0xFF0D1418),
  bd: Color(0xFF2A3942),
  text: Color(0xFFE9EDEF),
  mu: Color(0xFF8696A0),
  mu2: Color(0xFFAEBAC1),
  g: Color(0xFF00A884),
  g2: Color(0xFF008F72),
  gc: Color(0x2600A884),
  cyan: Color(0xFF53BDEB),
  pink: Color(0xFFEF9A9A),
  or: Color(0xFFFFB74D),
  red: Color(0xFFE53935),
  hdr: Color(0xFF1F2C34),
  hdr2: Color(0xFF182229),
);

// இப்போதைய நிறங்கள்
Pal get P => AppState.I.dark ? kDark : kLight;

// பச்சை header gradient (#075e54 → #00a884)
LinearGradient get kHeroGrad => AppState.I.dark
    ? const LinearGradient(colors: [Color(0xFF1F2C34), Color(0xFF182229)], begin: Alignment.topLeft, end: Alignment.bottomRight)
    : const LinearGradient(colors: [Color(0xFF075E54), Color(0xFF00A884)], begin: Alignment.topLeft, end: Alignment.bottomRight);

const LinearGradient kBtnGrad = LinearGradient(colors: [Color(0xFF008069), Color(0xFF006E5A)], begin: Alignment.topLeft, end: Alignment.bottomRight);

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

TextStyle pop(double size, {FontWeight w = FontWeight.w800, Color? c, TextDecoration? deco}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: w, color: c ?? P.text, decoration: deco, decorationColor: c);

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
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.g2, textStyle: const TextStyle(fontWeight: FontWeight.w800)),
    ),
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
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? const Color(0xFF00A884) : p.bd),
      trackOutlineColor: WidgetStatePropertyAll(p.bd),
    ),
  );
}
