import 'package:flutter/material.dart';

// ── Core WhatsApp Light Palette (white surfaces, greens unchanged) ─────────
const Color waBlack         = Color(0xFF0B0E10);   // deepest background (kept for API compat)
const Color waDarkGrey      = Color(0xFFFFFFFF);   // main/scaffold background → white
const Color waHeaderGrey    = Color(0xFFFFFFFF);   // app bar / header → white
const Color waChatBg        = Color(0xFFEFEAE2);   // chat screen background (authentic WA light chat wallpaper)
const Color waInputBg       = Color(0xFFFFFFFF);   // message input bar → white
const Color waGreen         = Color(0xFF00A884);   // primary accent (new WA green)
const Color waGreenDark     = Color(0xFFD9FDD3);   // outgoing bubble (WA light green; greens untouched)
const Color waGreenLight    = Color(0xFF00A884);   // FAB / active
const Color waTeal          = Color(0xFF128C7E);   // secondary
const Color waWhite         = Color(0xFF111B21);   // primary text → near-black (readable on white)
const Color waGrey          = Color(0xFF667781);   // secondary text / metadata (WA light grey)
const Color waLightGrey     = Color(0xFFFFFFFF);   // incoming bubble → white
const Color waDivider       = Color(0xFFE9EDEF);   // divider lines → light
const Color waVerifiedBlue  = Color(0xFF34B7F1);   // ✓ badge
const Color waSystemMsg     = Color(0xFF54656F);   // system message text (WA light)
const Color waSystemBg      = Color(0xFFFFF3C9);   // system message background (WA light yellow pill)
const Color waAgentOrange   = Color(0xFFFFB300);   // agent request badge
const Color waDelivered     = Color(0xFF53BDEB);   // double-tick delivered
const Color waRead          = Color(0xFF53BDEB);   // double-tick read

// ── Text Styles ───────────────────────────────────────────────────────────
const TextStyle tsTitle = TextStyle(
  color: waWhite,
  fontSize: 17,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.1,
);

const TextStyle tsSubtitle = TextStyle(
  color: waGrey,
  fontSize: 13,
  fontWeight: FontWeight.w400,
);

const TextStyle tsMeta = TextStyle(
  color: waGrey,
  fontSize: 11,
  fontWeight: FontWeight.w400,
);

const TextStyle tsBody = TextStyle(
  color: waWhite,
  fontSize: 14.5,
  height: 1.4,
);

const TextStyle tsBubble = TextStyle(
  color: waWhite,
  fontSize: 14.5,
  height: 1.45,
);

// ── ThemeData factory ─────────────────────────────────────────────────────
ThemeData buildWhatsAppTheme() {
  return ThemeData.light().copyWith(
    scaffoldBackgroundColor: waDarkGrey,
    primaryColor: waGreen,
    colorScheme: const ColorScheme.light(
      primary: waGreen,
      secondary: waTeal,
      surface: waHeaderGrey,
      background: waDarkGrey,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: waHeaderGrey,
      foregroundColor: waWhite,
      elevation: 0,
      titleTextStyle: tsTitle,
      iconTheme: IconThemeData(color: waGrey),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: waHeaderGrey,
      selectedItemColor: waGreen,
      unselectedItemColor: waGrey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    dividerColor: waDivider,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: waLightGrey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      hintStyle: const TextStyle(color: waGrey, fontSize: 15),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: waGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      ),
    ),
  );
}
