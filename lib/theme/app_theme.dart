import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── 식물 / 정원 고유 색 (plant renderer 등에서 그대로 사용) ─────────────────
  static const Color deepForest  = Color(0xFF1B3A2D);
  static const Color midForest   = Color(0xFF2D5A3D);
  static const Color lightForest = Color(0xFF4A8C5C);
  static const Color softMoss    = Color(0xFF7DB87A);

  // ── 따뜻한 파스텔 텍스트 색 ─────────────────────────────────────────────────
  /// 어두운 배경 위 주요 텍스트 — 따뜻한 크림 아이보리
  static const Color dawnGlow    = Color(0xFFF5E6CC);

  /// 보조 텍스트 — 따뜻한 탄
  static const Color textSubtle  = Color(0xFFCBAA80);

  /// 본문 텍스트 — 따뜻한 화이트
  static const Color textOnDark  = Color(0xFFFFF5E8);

  /// 밝은 배경 위 텍스트 (홈 화면 하늘 배경)
  static const Color textDark    = Color(0xFF3D2A1A);

  // ── 따뜻한 강조색 ────────────────────────────────────────────────────────────
  static const Color goldenHour   = Color(0xFFFFD082);
  static const Color blossomPink  = Color(0xFFFFB3C6);
  static const Color morningDew   = Color(0xFFB2DFDB);
  static const Color warmAmber    = Color(0xFFFFCC66);
  static const Color warmRose     = Color(0xFFFF9EBC);
  static const Color warmLavender = Color(0xFFDCC8F5);
  static const Color warmPeach    = Color(0xFFFFD4A3);

  // ── 기타 ─────────────────────────────────────────────────────────────────────
  static const Color earthBrown  = Color(0xFF795548);
  static const Color terracotta  = Color(0xFFA1887F);
  static const Color skyDawn     = Color(0xFFE8F5E9);
  static const Color softCloud   = Color(0xFFFFF8F0);

  static ThemeData get theme {
    return ThemeData(
      scaffoldBackgroundColor: deepForest,
      colorScheme: const ColorScheme.dark(
        primary: softMoss,
        secondary: blossomPink,
        surface: midForest,
      ),
      textTheme: GoogleFonts.notoSansKrTextTheme().apply(
        bodyColor: textOnDark,
        displayColor: dawnGlow,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textOnDark),
      ),
    );
  }
}
