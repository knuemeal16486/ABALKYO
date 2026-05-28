// 기상청 API에서 받아온 일 관측 데이터
class WeatherData {
  final double? tempAvg;
  final double? tempMax;
  final double? tempMin;
  final double? humidity;
  final double? windSpeed;   // m/s
  final double? rainfall;   // mm (당일 누적)
  final double? cloudCover; // 0–10
  final DateTime fetchedAt;
  final int stationId;
  final String stationName;

  const WeatherData({
    this.tempAvg,
    this.tempMax,
    this.tempMin,
    this.humidity,
    this.windSpeed,
    this.rainfall,
    this.cloudCover,
    required this.fetchedAt,
    required this.stationId,
    this.stationName = '서울',
  });

  // 실제 풍속 → 3D 식물 바람 진폭 (잔잔 1.5 ~ 강풍 9.0)
  double get windAmp {
    final ws = windSpeed ?? 2.0;
    return (1.5 + ws * 0.65).clamp(1.5, 9.0);
  }

  bool get isRainy => (rainfall ?? 0) > 0.3;

  WeatherCondition get condition {
    if (isRainy) return WeatherCondition.rainy;
    final cc = cloudCover ?? 5;
    if (cc >= 8) return WeatherCondition.overcast;
    if (cc >= 5) return WeatherCondition.cloudy;
    if (cc >= 2) return WeatherCondition.partlyCloudy;
    return WeatherCondition.sunny;
  }

  double get displayTemp => tempMax ?? tempAvg ?? tempMin ?? 20.0;

  String get conditionLabel {
    switch (condition) {
      case WeatherCondition.rainy:       return '비';
      case WeatherCondition.overcast:    return '흐림';
      case WeatherCondition.cloudy:      return '구름많음';
      case WeatherCondition.partlyCloudy:return '구름조금';
      case WeatherCondition.sunny:       return '맑음';
    }
  }

  String get conditionEmoji {
    switch (condition) {
      case WeatherCondition.rainy:       return '🌧';
      case WeatherCondition.overcast:    return '☁️';
      case WeatherCondition.cloudy:      return '🌥';
      case WeatherCondition.partlyCloudy:return '⛅';
      case WeatherCondition.sunny:       return '☀️';
    }
  }

  Map<String, dynamic> toJson() => {
    'tempAvg'    : tempAvg,
    'tempMax'    : tempMax,
    'tempMin'    : tempMin,
    'humidity'   : humidity,
    'windSpeed'  : windSpeed,
    'rainfall'   : rainfall,
    'cloudCover' : cloudCover,
    'fetchedAt'  : fetchedAt.toIso8601String(),
    'stationId'  : stationId,
    'stationName': stationName,
  };

  factory WeatherData.fromJson(Map<String, dynamic> j) => WeatherData(
    tempAvg    : (j['tempAvg']     as num?)?.toDouble(),
    tempMax    : (j['tempMax']     as num?)?.toDouble(),
    tempMin    : (j['tempMin']     as num?)?.toDouble(),
    humidity   : (j['humidity']    as num?)?.toDouble(),
    windSpeed  : (j['windSpeed']   as num?)?.toDouble(),
    rainfall   : (j['rainfall']    as num?)?.toDouble(),
    cloudCover : (j['cloudCover']  as num?)?.toDouble(),
    fetchedAt  : DateTime.tryParse(j['fetchedAt'] as String? ?? '') ?? DateTime.now(),
    stationId  : (j['stationId']   as num?)?.toInt() ?? 108,
    stationName: j['stationName']  as String? ?? '서울',
  );
}

enum WeatherCondition { sunny, partlyCloudy, cloudy, overcast, rainy }
