import 'package:flutter/material.dart';
import '../models/weather_model.dart';

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
  // weather: 기상청 실측 데이터, emotionRain: 위로의 비(감정 일기 트리거)
  static SkyTheme get({WeatherData? weather, bool emotionRain = false}) {
    final h = DateTime.now().hour;
    final condition = weather?.condition;
    final isRainy   = emotionRain || (weather?.isRainy ?? false);

    // ── 비 ──────────────────────────────────────────────────────────────────
    if (isRainy) {
      // 시간대별 비 색조 (새벽·밤은 더 어둡게)
      final dark = h < 6 || h >= 22;
      return SkyTheme(
        colors: dark
            ? const [Color(0xFF374B5E), Color(0xFF4E6478), Color(0xFF7090A8)]
            : const [Color(0xFF9EB8D0), Color(0xFFBDD5E8), Color(0xFFE4F0F8)],
        warmColors: const [Color(0xFF182638), Color(0xFF243A52)],
        particleColor: const Color(0xFF90A4AE),
        label: '🌧 비',
        glowColor: const Color(0xFF78A9C8),
        accentColor: const Color(0xFFB0C8D8),
      );
    }

    // ── 흐림 / 구름많음 ────────────────────────────────────────────────────
    if (condition == WeatherCondition.overcast ||
        condition == WeatherCondition.cloudy) {
      // 시간대 기반 색을 채도 낮춘 회색톤으로 블렌드
      return _cloudyVariant(_timeTheme(h), condition == WeatherCondition.overcast);
    }

    // ── 구름조금: 시간대 테마를 약간만 부드럽게 ────────────────────────────
    if (condition == WeatherCondition.partlyCloudy) {
      return _timeTheme(h); // 거의 동일, label만 조정 가능
    }

    // ── 맑음 or 날씨 데이터 없음: 시간대 테마 그대로 ───────────────────────
    return _timeTheme(h);
  }

  static SkyTheme _cloudyVariant(SkyTheme base, bool heavy) {
    Color grey(Color c) {
      final t = heavy ? 0.48 : 0.28;
      final r = ((c.red   * 255) * (1 - t) + 180 * t).round().clamp(0, 255);
      final g = ((c.green * 255) * (1 - t) + 185 * t).round().clamp(0, 255);
      final b = ((c.blue  * 255) * (1 - t) + 195 * t).round().clamp(0, 255);
      return Color.fromARGB(255, r, g, b);
    }
    return SkyTheme(
      colors      : base.colors.map(grey).toList(),
      warmColors  : base.warmColors,
      particleColor: grey(base.particleColor),
      label       : heavy ? '☁️ 흐림' : '🌥 구름',
      glowColor   : grey(base.glowColor),
      accentColor : grey(base.accentColor),
    );
  }

  static SkyTheme _timeTheme(int h) {

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
