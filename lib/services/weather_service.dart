import 'dart:convert';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_model.dart';

// ═══════════════════════════════════════════════════════════════════════════
// WeatherService — 기상청 지상관측 일자료(kma_sfcdd) 연동
//   · GPS → 최근접 기상관측소 자동 선택 (실패 시 서울 108번)
//   · 당일 실측 데이터: 최고/최저기온, 강수량, 풍속, 습도, 전운량
//   · 30분 캐시 (SharedPreferences)
//   · WeatherInfo (diary_wizard 호환) + WeatherData (홈 화면) 동시 제공
// ═══════════════════════════════════════════════════════════════════════════

// diary_wizard.dart 호환: 일기 작성 유도 문구 + 감정 추천
class WeatherInfo {
  final String emoji;
  final String label;
  final double tempC;
  final String hint;
  final List<String> suggestedEmotions;

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
  static const _authKey  = '1ixozr3eQUmsaM693vFJ5g';
  static const _baseUrl  = 'https://apihub.kma.go.kr/api/typ01/url/kma_sfcdd.php';
  static const _cacheKey = 'kma_weather_v2';
  static const _stnKey   = 'kma_station_id';

  // 주요 지상관측 지점 {지점번호: [위도, 경도, 도시명]}
  static const Map<int, List<dynamic>> _stations = {
    108: [37.57, 126.97, '서울'],
    112: [37.48, 126.63, '인천'],
    119: [37.27, 126.99, '수원'],
    159: [35.10, 129.03, '부산'],
    143: [35.88, 128.65, '대구'],
    133: [36.37, 127.37, '대전'],
    156: [35.17, 126.89, '광주'],
    146: [35.55, 129.32, '울산'],
    184: [33.51, 126.52, '제주'],
    101: [37.90, 127.74, '춘천'],
    105: [37.75, 128.89, '강릉'],
    138: [35.97, 126.72, '군산'],
    131: [36.64, 127.44, '청주'],
    168: [35.17, 128.57, '창원'],
    136: [36.42, 128.29, '상주'],
    130: [36.99, 129.41, '울진'],
  };

  static int _nearest(double lat, double lon) {
    int best = 108;
    double bestDist = double.infinity;
    for (final e in _stations.entries) {
      final dlat = (e.value[0] as double) - lat;
      final dlon = (e.value[1] as double) - lon;
      final d = math.sqrt(dlat * dlat + dlon * dlon);
      if (d < bestDist) { bestDist = d; best = e.key; }
    }
    return best;
  }

  static String _dateStr(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  // ── GPS → 최근접 관측소 ───────────────────────────────────────────────────
  static Future<int> resolveStation() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getInt(_stnKey);
    if (cached != null) return cached;
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 6),
          ),
        );
        final stn = _nearest(pos.latitude, pos.longitude);
        await prefs.setInt(_stnKey, stn);
        return stn;
      }
    } catch (_) {}
    return 108;
  }

  // ── CSV 파싱 ─────────────────────────────────────────────────────────────
  // 기상청 결측치(-9, -9.0, -99.0 등)를 null로 처리
  static double? _f(List<String> row, int i) {
    if (i >= row.length) return null;
    final v = double.tryParse(row[i].trim());
    if (v == null || v <= -9) return null;
    return v;
  }

  static WeatherData? _parse(String body, int stn) {
    for (final raw in body.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final f = line.split(',');
      if (f.length < 40) continue;
      if (int.tryParse(f[1].trim()) != stn) continue;
      // 컬럼 순서 (help=1 헤더 참고):
      // 0:날짜  1:지점  2:WS_AVG  10:TA_AVG  11:TA_MAX  13:TA_MIN
      // 18:HM_AVG  31:CA_TOT(전운량0-10)  38:RN_DAY(강수량mm)
      return WeatherData(
        windSpeed  : _f(f, 2),
        tempAvg    : _f(f, 10),
        tempMax    : _f(f, 11),
        tempMin    : _f(f, 13),
        humidity   : _f(f, 18),
        cloudCover : _f(f, 31),
        rainfall   : _f(f, 38),
        fetchedAt  : DateTime.now(),
        stationId  : stn,
        stationName: _stations[stn]?[2] as String? ?? '서울',
      );
    }
    return null;
  }

  // ── 날씨 취득 메인 (30분 캐시) ───────────────────────────────────────────
  static Future<WeatherData?> fetchData({int? stationId}) async {
    final prefs = await SharedPreferences.getInstance();

    // 캐시 확인 (30분)
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      try {
        final w = WeatherData.fromJson(jsonDecode(cached));
        if (DateTime.now().difference(w.fetchedAt).inMinutes < 30) return w;
      } catch (_) {}
    }

    final stn  = stationId ?? await resolveStation();
    final date = _dateStr(DateTime.now());

    try {
      final uri = Uri.parse(
          '$_baseUrl?tm=$date&stn=$stn&help=0&authKey=$_authKey');
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;

      // 응답 본문은 EUC-KR이지만, 데이터 행은 ASCII 숫자로만 구성되어
      // latin1 디코딩으로 충분히 파싱 가능
      final body = latin1.decode(resp.bodyBytes);
      final data = _parse(body, stn);
      if (data != null) {
        await prefs.setString(_cacheKey, jsonEncode(data.toJson()));
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  // ── diary_wizard 호환: WeatherData → WeatherInfo ──────────────────────────
  static Future<WeatherInfo?> fetch() async {
    final data = await fetchData();
    if (data == null) return null;

    final temp = data.displayTemp;
    final tHint = temp >= 30
        ? ' 더운 날씨에 잘 지냈나요?'
        : temp <= 4
            ? ' 추운 날씨에 따뜻하게 보냈나요?'
            : '';

    switch (data.condition) {
      case WeatherCondition.sunny:
        return WeatherInfo(
          emoji: '☀️', label: '맑음', tempC: temp,
          hint: '햇살이 따사로운 하루예요!$tHint 오늘 가장 빛났던 순간은 언제였나요?',
          suggestedEmotions: ['happy', 'excited'],
        );
      case WeatherCondition.partlyCloudy:
        return WeatherInfo(
          emoji: '⛅', label: '구름조금', tempC: temp,
          hint: '구름 사이로 햇빛이 반짝이는 날이에요.$tHint 오늘 기분은 어떤 색이었나요?',
          suggestedEmotions: ['calm', 'thankful'],
        );
      case WeatherCondition.cloudy:
        return WeatherInfo(
          emoji: '🌥', label: '구름많음', tempC: temp,
          hint: '구름이 많은 날이에요.$tHint 오늘 마음은 어땠나요?',
          suggestedEmotions: ['calm', 'sad'],
        );
      case WeatherCondition.overcast:
        return WeatherInfo(
          emoji: '☁️', label: '흐림', tempC: temp,
          hint: '하늘이 잔뜩 흐린 날이에요.$tHint 그래도 오늘 좋았던 일이 하나쯤 있지 않았나요?',
          suggestedEmotions: ['calm', 'sad'],
        );
      case WeatherCondition.rainy:
        final rf = data.rainfall ?? 0;
        final heavy = rf > 10;
        return WeatherInfo(
          emoji: heavy ? '🌧' : '🌦',
          label: heavy ? '비' : '이슬비',
          tempC: temp,
          hint: '빗소리를 들으며 오늘 어떤 생각이 떠올랐나요? 나의 마음 날씨도 이야기해봐요.',
          suggestedEmotions: ['sad', 'calm'],
        );
    }
  }
}
