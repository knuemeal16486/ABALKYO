enum PlantType {
  appleTree,     // 사과나무 (장미과, 계절 변화 · 꽃 · 과실)
  tomato,        // 토마토 (꽃→열매, 아이들에게 친숙)
  grapevine,     // 포도나무 (덩굴 · 포도송이, 독특한 실루엣)
  cherryBlossom, // 벚꽃나무 (한국 봄 정서, 분홍 만개)
  lavender,      // 라벤더 (보라 수직 이삭, 허브)
}

PlantType plantTypeFromName(String? name) =>
    PlantType.values.firstWhere((t) => t.name == name,
        orElse: () => PlantType.appleTree);

class PlantStageInfo {
  final String id;
  final String name;
  final int requiredGrowth; // 0 to 100

  const PlantStageInfo(this.id, this.name, this.requiredGrowth);
}

class PlantSpecies {
  final PlantType type;
  final String name;
  final String emoji;
  final String description;
  final List<PlantStageInfo> stages;

  const PlantSpecies({
    required this.type,
    required this.name,
    required this.emoji,
    required this.description,
    required this.stages,
  });
}

// 식물 도감 (종류별 생물학적 성장 단계 정의)
class PlantDictionary {
  static const Map<PlantType, PlantSpecies> species = {
    PlantType.appleTree: PlantSpecies(
      type: PlantType.appleTree,
      name: '마음의 사과나무',
      emoji: '🍎',
      description: '사계절의 변화를 보여주며 꽃을 피우고 빨간 열매를 맺는 사과나무입니다.',
      stages: [
        PlantStageInfo('seed', '씨앗 파종', 0),
        PlantStageInfo('germination', '발아', 8),
        PlantStageInfo('seedling', '묘목', 15),
        PlantStageInfo('sapling', '유목 (가지 형성)', 30),
        PlantStageInfo('mature', '성목', 55),
        PlantStageInfo('flowering', '개화 (꽃 피움)', 72),
        PlantStageInfo('fruiting', '결실 · 수확', 90),
      ],
    ),
    PlantType.tomato: PlantSpecies(
      type: PlantType.tomato,
      name: '씩씩한 토마토',
      emoji: '🍅',
      description: '노란 꽃을 피우고 초록에서 빨간 열매로 익어가는 토마토입니다.',
      stages: [
        PlantStageInfo('seed', '씨앗 파종', 0),
        PlantStageInfo('germination', '발아', 10),
        PlantStageInfo('trueLeaves', '본잎 성장', 25),
        PlantStageInfo('stemGrowth', '줄기 성장', 42),
        PlantStageInfo('flowering', '노란 꽃 개화', 60),
        PlantStageInfo('greenFruit', '초록 열매 형성', 76),
        PlantStageInfo('ripening', '빨간 토마토 수확', 92),
      ],
    ),
    PlantType.grapevine: PlantSpecies(
      type: PlantType.grapevine,
      name: '풍성한 포도나무',
      emoji: '🍇',
      description: '덩굴을 뻗으며 자라나 탐스러운 포도송이를 매달리는 포도나무입니다.',
      stages: [
        PlantStageInfo('cutting', '삽목 발근', 0),
        PlantStageInfo('newShoot', '새순 돋움', 12),
        PlantStageInfo('vining', '덩굴 뻗기', 28),
        PlantStageInfo('lushLeaves', '잎 무성', 45),
        PlantStageInfo('flowerCluster', '꽃송이 형성', 62),
        PlantStageInfo('greenGrapes', '초록 포도 열림', 78),
        PlantStageInfo('harvest', '자주빛 포도 수확', 95),
      ],
    ),
    PlantType.cherryBlossom: PlantSpecies(
      type: PlantType.cherryBlossom,
      name: '봄의 벚꽃나무',
      emoji: '🌸',
      description: '봄이 되면 분홍 꽃이 눈처럼 만발하는 아름다운 벚꽃나무입니다.',
      stages: [
        PlantStageInfo('seed', '씨앗 파종', 0),
        PlantStageInfo('germination', '발아', 8),
        PlantStageInfo('seedling', '묘목', 18),
        PlantStageInfo('youngTree', '어린나무', 35),
        PlantStageInfo('mature', '성목', 58),
        PlantStageInfo('budding', '꽃봉오리', 76),
        PlantStageInfo('fullBloom', '만개 (벚꽃)', 90),
      ],
    ),
    PlantType.lavender: PlantSpecies(
      type: PlantType.lavender,
      name: '향기로운 라벤더',
      emoji: '💜',
      description: '보라색 꽃이삭이 바람에 흔들리며 달콤한 향기를 내뿜는 라벤더입니다.',
      stages: [
        PlantStageInfo('seed', '씨앗 파종', 0),
        PlantStageInfo('germination', '발아', 10),
        PlantStageInfo('rosette', '로제트 잎 형성', 25),
        PlantStageInfo('stemGrowth', '줄기 형성', 42),
        PlantStageInfo('spikeEmergence', '꽃대 출현', 62),
        PlantStageInfo('blooming', '보라 꽃 개화', 78),
        PlantStageInfo('fullBloom', '만개 · 향기 절정', 95),
      ],
    ),
  };

  static PlantSpecies of(PlantType type) => species[type]!;
}

class Plant {
  final PlantType type;
  final int growthLevel;
  final DateTime plantedAt;
  final int seed;
  final int health;               // 0–100: 수분 상태 (100=촉촉, 0=시들시들)
  final DateTime lastWateredDate; // 마지막으로 일기 쓴 날

  Plant({
    required this.type,
    required this.growthLevel,
    required this.plantedAt,
    required this.seed,
    this.health = 100,
    DateTime? lastWateredDate,
  }) : lastWateredDate = lastWateredDate ?? plantedAt;

  // 시들음 정도 0.0(건강)~1.0(완전 시듦) — 3D 렌더러에 전달
  double get wiltFactor => health < 60 ? ((60 - health) / 60.0).clamp(0.0, 1.0) : 0.0;

  bool get isWilting => health < 30;

  int get daysSinceWatered {
    final today = DateTime.now();
    final last = DateTime(lastWateredDate.year, lastWateredDate.month, lastWateredDate.day);
    final now  = DateTime(today.year, today.month, today.day);
    return now.difference(last).inDays;
  }

  Plant copyWith({
    PlantType? type,
    int? growthLevel,
    DateTime? plantedAt,
    int? seed,
    int? health,
    DateTime? lastWateredDate,
  }) {
    return Plant(
      type: type ?? this.type,
      growthLevel: growthLevel ?? this.growthLevel,
      plantedAt: plantedAt ?? this.plantedAt,
      seed: seed ?? this.seed,
      health: health ?? this.health,
      lastWateredDate: lastWateredDate ?? this.lastWateredDate,
    );
  }

  PlantSpecies get species => PlantDictionary.species[type]!;

  bool get isFullyGrown => growthLevel >= 100;

  PlantStageInfo get currentStageInfo {
    return species.stages.reversed.firstWhere(
      (s) => growthLevel >= s.requiredGrowth,
      orElse: () => species.stages.first,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'growthLevel': growthLevel,
        'plantedAt': plantedAt.toIso8601String(),
        'seed': seed,
        'health': health,
        'lastWateredDate': lastWateredDate.toIso8601String(),
      };

  factory Plant.fromJson(Map<String, dynamic> j) {
    final planted =
        DateTime.tryParse(j['plantedAt'] as String? ?? '') ?? DateTime.now();
    return Plant(
      type: plantTypeFromName(j['type'] as String?),
      growthLevel: (j['growthLevel'] as num?)?.toInt() ?? 0,
      plantedAt: planted,
      seed: (j['seed'] as num?)?.toInt() ??
          (planted.millisecondsSinceEpoch & 0x7fffffff),
      health: (j['health'] as num?)?.toInt() ?? 100,
      lastWateredDate:
          DateTime.tryParse(j['lastWateredDate'] as String? ?? '') ?? planted,
    );
  }
}

// 다 키운 식물 (정원 도감에 보관)
class HarvestedPlant {
  final PlantType type;
  final DateTime harvestedAt;

  const HarvestedPlant({required this.type, required this.harvestedAt});

  PlantSpecies get species => PlantDictionary.species[type]!;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'harvestedAt': harvestedAt.toIso8601String(),
      };

  factory HarvestedPlant.fromJson(Map<String, dynamic> j) => HarvestedPlant(
        type: plantTypeFromName(j['type'] as String?),
        harvestedAt: DateTime.tryParse(j['harvestedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ── 감정 정의 (앱 전체에서 공유) ────────────────────────────────────────────
class EmotionInfo {
  final String id;
  final String icon;
  final String label;
  final bool comforting; // 어려운 감정 → 위로의 비 연출

  const EmotionInfo(this.id, this.icon, this.label, {this.comforting = false});
}

class Emotions {
  static const List<EmotionInfo> all = [
    EmotionInfo('happy', '😄', '기쁨'),
    EmotionInfo('excited', '🤩', '신남'),
    EmotionInfo('calm', '😌', '평온'),
    EmotionInfo('thankful', '🥰', '고마움'),
    EmotionInfo('sad', '😢', '슬픔', comforting: true),
    EmotionInfo('anxious', '😰', '불안', comforting: true),
    EmotionInfo('angry', '😡', '화남', comforting: true),
    EmotionInfo('depressed', '🌧️', '우울', comforting: true),
  ];

  static EmotionInfo byId(String id) =>
      all.firstWhere((e) => e.id == id, orElse: () => all.first);

  static String iconOf(String id) => byId(id).icon;
  static String labelOf(String id) => byId(id).label;
  static bool isComforting(String id) => byId(id).comforting;
}

class EmotionEntry {
  final String id;
  final DateTime date;
  final String emotion;
  final String diaryText;
  final String? imageUrl; // 아이가 첨부한 사진
  final String? aiNarration; // AI 그림일기 서술 + 공감 답글
  final String? aiImageUrl; // AI가 생성한 그림 (가능한 경우)

  EmotionEntry({
    required this.id,
    required this.date,
    required this.emotion,
    required this.diaryText,
    this.imageUrl,
    this.aiNarration,
    this.aiImageUrl,
  });

  EmotionInfo get emotionInfo => Emotions.byId(emotion);

  EmotionEntry copyWith({String? aiNarration, String? aiImageUrl}) =>
      EmotionEntry(
        id: id,
        date: date,
        emotion: emotion,
        diaryText: diaryText,
        imageUrl: imageUrl,
        aiNarration: aiNarration ?? this.aiNarration,
        aiImageUrl: aiImageUrl ?? this.aiImageUrl,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'emotion': emotion,
        'diaryText': diaryText,
        'imageUrl': imageUrl,
        'aiNarration': aiNarration,
        'aiImageUrl': aiImageUrl,
      };

  factory EmotionEntry.fromJson(Map<String, dynamic> j) => EmotionEntry(
        id: j['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        emotion: j['emotion'] as String? ?? 'calm',
        diaryText: j['diaryText'] as String? ?? '',
        imageUrl: j['imageUrl'] as String?,
        aiNarration: j['aiNarration'] as String?,
        aiImageUrl: j['aiImageUrl'] as String?,
      );
}
