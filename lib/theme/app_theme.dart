import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // 어비스리움 스타일 힐링 색상 팔레트
  static const Color deepForest     = Color(0xFF1B3A2D); // 진한 숲 초록 (배경)
  static const Color midForest      = Color(0xFF2D5A3D); // 중간 숲
  static const Color lightForest    = Color(0xFF4A8C5C); // 밝은 숲
  static const Color softMoss       = Color(0xFF7DB87A); // 이끼
  static const Color dawnGlow       = Color(0xFFC8E6C9); // 새벽 빛
  static const Color goldenHour     = Color(0xFFFFD082); // 황금빛 시간
  static const Color blossomPink    = Color(0xFFFFB3C6); // 꽃잎 핑크
  static const Color morningDew     = Color(0xFFB2DFDB); // 아침 이슬
  static const Color earthBrown     = Color(0xFF795548); // 흙
  static const Color terracotta     = Color(0xFFA1887F); // 토분
  static const Color skyDawn        = Color(0xFFE8F5E9); // 하늘빛 새벽
  static const Color softCloud      = Color(0xFFF1F8E9); // 구름

  // 텍스트 색상
  static const Color textOnDark     = Color(0xFFF1F8E9);
  static const Color textSubtle     = Color(0xFFA5D6A7);
  static const Color textDark       = Color(0xFF2E3D2F);

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
        displayColor: textOnDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textOnDark),
      ),
    );
  }
}
