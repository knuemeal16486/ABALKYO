import 'package:flutter/material.dart';

class SkyTheme {
  /// 홈 화면 하늘 그라데이션 (밝은, 3-stop)
  final List<Color> colors;

  /// 보조 화면 배경 (따뜻하고 어두운 버전)
  final List<Color> warmColors;

  final Color particleColor;
  final String label;

  /// 배경에 뿌려지는 주변광 글로우 색
  final Color glowColor;

  /// 강조·하이라이트 색 (두 번째 글로우 오브, 배지 등)
  final Color accentColor;

  const SkyTheme({
    required this.colors,
    required this.warmColors,
    required this.particleColor,
    required this.label,
    required this.glowColor,
    required this.accentColor,
  });
}

class TimeWeatherTheme {
  static SkyTheme get({bool rain = false}) {
    if (rain) {
      return const SkyTheme(
        colors: [Color(0xFF9EB8D0), Color(0xFFBDD5E8), Color(0xFFE4F0F8)],
        warmColors: [Color(0xFF182638), Color(0xFF243A52)],
        particleColor: Color(0xFF90A4AE),
        label: '🌧 비',
        glowColor: Color(0xFF78A9C8),
        accentColor: Color(0xFFB0C8D8),
      );
    }

    final h = DateTime.now().hour;

    // ── 새벽 0–5: 보라 → 장미 → 복숭아 크림 ─────────────────────────────
    if (h < 6) {
      return const SkyTheme(
        colors: [Color(0xFF3D1E60), Color(0xFF8B4A70), Color(0xFFFFD4A3)],
        warmColors: [Color(0xFF1A0D30), Color(0xFF2D1550)],
        particleColor: Color(0xFFD7BDE2),
        label: '🌙 새벽',
        glowColor: Color(0xFF9B59B6),
        accentColor: Color(0xFFFFB3C6),
      );
    }

    // ── 아침 6–9: 산호 → 황금 → 크림 ────────────────────────────────────
    if (h < 10) {
      return const SkyTheme(
        colors: [Color(0xFFFF8C69), Color(0xFFFFD4A3), Color(0xFFFFF5E6)],
        warmColors: [Color(0xFF3D1A0A), Color(0xFF5A2C14)],
        particleColor: Color(0xFFFFCC80),
        label: '🌅 아침',
        glowColor: Color(0xFFFF9F5A),
        accentColor: Color(0xFFFFD082),
      );
    }

    // ── 낮 10–13: 파스텔 하늘 → 연파랑 → 아이보리 ──────────────────────
    if (h < 14) {
      return const SkyTheme(
        colors: [Color(0xFF87CEEB), Color(0xFFB8E4FF), Color(0xFFF5FEFF)],
        warmColors: [Color(0xFF0A2240), Color(0xFF183A5C)],
        particleColor: Color(0xFF81D4FA),
        label: '☀️ 낮',
        glowColor: Color(0xFF5BB8E8),
        accentColor: Color(0xFFFFE082),
      );
    }

    // ── 오후 14–16: 따뜻한 청록 → 민트 → 아이보리 ──────────────────────
    if (h < 17) {
      return const SkyTheme(
        colors: [Color(0xFF5CBCAA), Color(0xFFA8DDD4), Color(0xFFFEF9E7)],
        warmColors: [Color(0xFF0A2E28), Color(0xFF184038)],
        particleColor: Color(0xFF80DEEA),
        label: '🌤 오후',
        glowColor: Color(0xFF4DB6AC),
        accentColor: Color(0xFFFFD082),
      );
    }

    // ── 노을 17–18: 딥 산호 → 황금 → 복숭아 핑크 ───────────────────────
    if (h < 19) {
      return const SkyTheme(
        colors: [Color(0xFFE8553A), Color(0xFFFF9F5A), Color(0xFFFFD4B0)],
        warmColors: [Color(0xFF3D1505), Color(0xFF5A2A10)],
        particleColor: Color(0xFFFFD54F),
        label: '🌇 노을',
        glowColor: Color(0xFFFF7043),
        accentColor: Color(0xFFFFCC80),
      );
    }

    // ── 저녁 19–21: 딥 보라 → 라벤더 → 핑크 장미 ───────────────────────
    if (h < 22) {
      return const SkyTheme(
        colors: [Color(0xFF4A2080), Color(0xFF9B6BB5), Color(0xFFE8C4D8)],
        warmColors: [Color(0xFF1E0A3D), Color(0xFF2E1552)],
        particleColor: Color(0xFFCE93D8),
        label: '🌆 저녁',
        glowColor: Color(0xFF8B5BA8),
        accentColor: Color(0xFFFFB3C6),
      );
    }

    // ── 밤 22–23: 딥 네이비 → 미드나잇 보라 ────────────────────────────
    return const SkyTheme(
      colors: [Color(0xFF0A0820), Color(0xFF1C1445), Color(0xFF2E2070)],
      warmColors: [Color(0xFF07051A), Color(0xFF100D30)],
      particleColor: Color(0xFF9FA8DA),
      label: '⭐ 밤',
      glowColor: Color(0xFF3D35A0),
      accentColor: Color(0xFFE8C4D8),
    );
  }
}
