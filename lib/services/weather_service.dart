import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════════════════
// WeatherService — Open-Meteo(무료·API키 불필요) + geolocator
//   · 현재 위치 → 날씨 코드 + 기온 → 감정 추천 + 일기 힌트 반환
//   · 위치 권한 거부 시 서울 기본값 사용, 오류 시 null 반환(조용히 실패)
// ═══════════════════════════════════════════════════════════════════════════

class WeatherInfo {
  final String emoji;
  final String label; // 맑음, 흐림, 비 …
  final double tempC;
  final String hint; // 날씨 기반 일기 힌트 문장
  final List<String> suggestedEmotions; // EmotionInfo.id 최대 2개

  const WeatherInfo({
    required this.emoji,
    required this.label,
    required this.tempC,
    required this.hint,
    required this.suggestedEmotions,
  });

  String get tempLabel => '${tempC.round()}°C';
}

class WeatherService {
  static const _apiBase = 'https://api.open-meteo.com/v1/forecast';
  // 위치 권한 거부 시 서울 기본값
  static const _seoulLat = 37.5665;
  static const _seoulLon = 126.9780;

  static Future<WeatherInfo?> fetch() async {
    try {
      final loc = await _location();
      final uri = Uri.parse(
        '$_apiBase?latitude=${loc.$1}&longitude=${loc.$2}'
        '&current=weather_code,temperature_2m&timezone=auto',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final cur = json['current'] as Map<String, dynamic>?;
      if (cur == null) return null;

      final code = (cur['weather_code'] as num).toInt();
      final temp = (cur['temperature_2m'] as num).toDouble();
      return _fromCode(code, temp);
    } catch (_) {
      return null;
    }
  }

  // ── 위치 취득 ─────────────────────────────────────────────────────────────
  static Future<(double, double)> _location() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return (_seoulLat, _seoulLon);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return (p.latitude, p.longitude);
    } catch (_) {
      return (_seoulLat, _seoulLon);
    }
  }

  // ── WMO 날씨 코드 → WeatherInfo ──────────────────────────────────────────
  static WeatherInfo _fromCode(int code, double temp) {
    // 기온 보조 힌트
    final tHint = temp >= 30
        ? ' 너무 덥지 않게 잘 지냈나요?'
        : temp <= 4
            ? ' 따뜻하게 보냈나요?'
            : '';

    if (code == 0) {
      return WeatherInfo(
        emoji: '☀️', label: '맑음', tempC: temp,
        hint: '햇살이 따사로운 하루예요!$tHint 오늘 가장 빛났던 순간은 언제였나요?',
        suggestedEmotions: ['happy', 'excited'],
      );
    }
    if (code <= 2) {
      return WeatherInfo(
        emoji: '🌤', label: '구름 조금', tempC: temp,
        hint: '구름 사이로 햇빛이 반짝이는 날이에요.$tHint 오늘 기분은 어떤 색이었나요?',
        suggestedEmotions: ['calm', 'thankful'],
      );
    }
    if (code == 3) {
      return WeatherInfo(
        emoji: '☁️', label: '흐림', tempC: temp,
        hint: '하늘이 흐린 날엔 어떤 생각이 드나요?$tHint',
        suggestedEmotions: ['calm', 'sad'],
      );
    }
    if (code <= 48) {
      return WeatherInfo(
        emoji: '🌫', label: '안개', tempC: temp,
        hint: '안개가 낀 신비로운 날이에요. 오늘 무언가 새롭게 느낀 게 있나요?',
        suggestedEmotions: ['calm', 'anxious'],
      );
    }
    if (code <= 67) {
      final heavy = code >= 63;
      return WeatherInfo(
        emoji: heavy ? '🌧' : '🌦', label: heavy ? '비' : '이슬비', tempC: temp,
        hint: '빗소리를 들으며 어떤 생각이 떠올랐나요? 오늘 나의 마음 날씨도 이야기해봐요.',
        suggestedEmotions: ['sad', 'calm'],
      );
    }
    if (code <= 77) {
      return WeatherInfo(
        emoji: '🌨', label: '눈', tempC: temp,
        hint: '눈이 내리는 특별한 날이에요!$tHint 눈을 보며 어떤 기분이었나요?',
        suggestedEmotions: ['excited', 'happy'],
      );
    }
    if (code <= 82) {
      return WeatherInfo(
        emoji: '🌦', label: '소나기', tempC: temp,
        hint: '갑자기 소나기가 왔네요! 오늘 예상치 못한 일이 있었나요?',
        suggestedEmotions: ['anxious', 'excited'],
      );
    }
    if (code <= 86) {
      return WeatherInfo(
        emoji: '❄️', label: '눈 소나기', tempC: temp,
        hint: '눈 소나기가 내린 설레는 날이에요! 어떤 일이 있었나요?',
        suggestedEmotions: ['excited', 'calm'],
      );
    }
    // 95+ 천둥번개
    return WeatherInfo(
      emoji: '⛈', label: '천둥번개', tempC: temp,
      hint: '천둥번개가 치는 날이에요. 무섭거나 신기하거나—어떤 기분이었나요?',
      suggestedEmotions: ['anxious', 'sad'],
    );
  }
}
