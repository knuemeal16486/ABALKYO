enum PlantType {
  appleTree, // 사과나무 (장미과, 꽃·과실 중심)
  sunflower, // 해바라기 (쌍떡잎식물, 꽃 중심)
  succulent, // 다육식물 (영양생식, 로제트형 잎 중심)
  fern       // 양치식물 (포자번식, 프랙탈 기하학 잎)
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
      description: '사계절의 변화를 보여주며 꽃을 피우고 열매를 맺는 사과나무입니다.',
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
    PlantType.sunflower: PlantSpecies(
      type: PlantType.sunflower,
      name: '활달한 해바라기',
      emoji: '🌻',
      description: '슬픔을 먹고 크고 밝은 꽃을 피우는 해바라기입니다.',
      stages: [
        PlantStageInfo('seed', '씨앗 파종', 0),
        PlantStageInfo('germination', '발아 및 뿌리내림', 10),
        PlantStageInfo('cotyledon', '떡잎 출현', 25),
        PlantStageInfo('trueLeaves', '본잎 성장', 45),
        PlantStageInfo('budding', '화아분화 (꽃봉오리)', 65),
        PlantStageInfo('blooming', '만개 (꽃 피움)', 85),
        PlantStageInfo('seeding', '결실 (씨앗 맺힘)', 100),
      ],
    ),
    PlantType.succulent: PlantSpecies(
      type: PlantType.succulent,
      name: '묵묵한 다육식물',
      emoji: '🪴',
      description: '어려운 환경에서도 수분을 머금고 단단하게 자라납니다.',
      stages: [
        PlantStageInfo('leaf_cutting', '잎꽂이 (안착)', 0),
        PlantStageInfo('rooting', '잔뿌리 발달', 15),
        PlantStageInfo('pup', '자구(아기 다육) 발생', 30),
        PlantStageInfo('rosette', '로제트 형성', 50),
        PlantStageInfo('maturing', '영양 성장기 (다육질화)', 75),
        PlantStageInfo('coloring', '단풍 들기', 90),
        PlantStageInfo('rare_bloom', '희귀한 개화', 100),
      ],
    ),
    PlantType.fern: PlantSpecies(
      type: PlantType.fern,
      name: '포용력 있는 고사리',
      emoji: '🌿',
      description: '어두운 곳에서도 생명력을 뻗어내는 신비로운 양치식물입니다.',
      stages: [
        PlantStageInfo('spore', '포자 안착', 0),
        PlantStageInfo('prothallus', '전엽체 형성', 15),
        PlantStageInfo('fiddlehead', '크로지어(어린 잎) 출현', 35),
        PlantStageInfo('unrolling', '프랙탈 잎사귀 펼쳐짐', 55),
        PlantStageInfo('mature', '성숙한 양치잎', 80),
        PlantStageInfo('sporangia', '포자낭군 형성', 100),
      ],
    ),
  };

  static PlantSpecies of(PlantType type) => species[type]!;
}

class Plant {
  final PlantType type;
  final int growthLevel;
  final DateTime plantedAt;
  final int seed; // 같은 종이라도 개체마다 다른 모습이 되도록 하는 난수 시드

  Plant({
    required this.type,
    required this.growthLevel,
    required this.plantedAt,
    required this.seed,
  });

  Plant copyWith({
    PlantType? type,
    int? growthLevel,
    DateTime? plantedAt,
    int? seed,
  }) {
    return Plant(
      type: type ?? this.type,
      growthLevel: growthLevel ?? this.growthLevel,
      plantedAt: plantedAt ?? this.plantedAt,
      seed: seed ?? this.seed,
    );
  }

  PlantSpecies get species => PlantDictionary.species[type]!;

  bool get isFullyGrown => growthLevel >= 100;

  PlantStageInfo get currentStageInfo {
    // 현재 성장 수치에 맞는 가장 높은 단계를 반환
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
