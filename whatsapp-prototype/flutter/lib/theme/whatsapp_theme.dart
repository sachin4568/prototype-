import 'package:flutter/material.dart';

// ── Core WhatsApp Dark Palette (from wb-ui-clone, extended) ──────────────
const Color waBlack         = Color(0xFF0B0E10);   // deepest background
const Color waDarkGrey      = Color(0xFF111B21);   // chat/scaffold background
const Color waHeaderGrey    = Color(0xFF1F2C34);   // app bar / header
const Color waChatBg        = Color(0xFF0D1417);   // chat screen background
const Color waInputBg       = Color(0xFF1F2C34);   // message input bar
const Color waGreen         = Color(0xFF00A884);   // primary accent (new WA green)
const Color waGreenDark     = Color(0xFF005C4B);   // outgoing bubble
const Color waGreenLight    = Color(0xFF00A884);   // FAB / active
const Color waTeal          = Color(0xFF128C7E);   // secondary
const Color waWhite         = Color(0xFFE9EDEF);   // primary text
const Color waGrey          = Color(0xFF8696A0);   // secondary text / metadata
const Color waLightGrey     = Color(0xFF2A3942);   // incoming bubble
const Color waDivider       = Color(0xFF222D35);   // divider lines
const Color waVerifiedBlue  = Color(0xFF34B7F1);   // ✓ badge
const Color waSystemMsg     = Color(0xFF8696A0);   // system message text
const Color waSystemBg      = Color(0xFF1F2C34);   // system message background
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
  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: waDarkGrey,
    primaryColor: waGreen,
    colorScheme: const ColorScheme.dark(
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
