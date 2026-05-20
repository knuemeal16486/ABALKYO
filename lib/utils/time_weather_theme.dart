import 'package:flutter/material.dart';

class SkyTheme {
  final List<Color> colors;
  final Color particleColor;
  final String label;
  const SkyTheme(this.colors, this.particleColor, this.label);
}

class TimeWeatherTheme {
  static SkyTheme get({bool rain = false}) {
    if (rain) { return const SkyTheme([Color(0xFFB0C4DE), Color(0xFFECF4FB)], Color(0xFF90A4AE), '🌧 비'); }
    final h = DateTime.now().hour;
    if (h < 6)  { return const SkyTheme([Color(0xFF6A5ACD), Color(0xFFF5CBA7)], Color(0xFFD7BDE2), '🌙 새벽'); }
    if (h < 10) { return const SkyTheme([Color(0xFFFFD4A3), Color(0xFFFFF9F0)], Color(0xFFFFCC80), '🌅 아침'); }
    if (h < 14) { return const SkyTheme([Color(0xFFAED6F1), Color(0xFFF0F9FF)], Color(0xFF81D4FA), '☀️ 낮'); }
    if (h < 17) { return const SkyTheme([Color(0xFFA8D8EA), Color(0xFFFEF9E7)], Color(0xFF80DEEA), '🌤 오후'); }
    if (h < 19) { return const SkyTheme([Color(0xFFFFAB76), Color(0xFFF7CAC9)], Color(0xFFFFD54F), '🌇 노을'); }
    if (h < 22) { return const SkyTheme([Color(0xFF8E6CC0), Color(0xFFD5C0E8)], Color(0xFFCE93D8), '🌆 저녁'); }
    return const SkyTheme([Color(0xFF2C3E7A), Color(0xFF7B7FAD)], Color(0xFF9FA8DA), '⭐ 밤');
  }
}
