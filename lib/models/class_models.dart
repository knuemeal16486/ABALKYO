// FILE: lib/models/class_models.dart

import 'app_models.dart';

/// 교사 대시보드에서 각 학생을 나타내는 요약 정보
class StudentSummary {
  final String studentUid;
  final String name;
  final int growthLevel; // 0–100
  final int health; // 0–100
  final DateTime? lastWateredDate;
  final String? plantType; // PlantType.name e.g. 'appleTree'
  final String? latestEmotion; // emotion id e.g. 'happy'
  final int streakDays;
  final int totalEntries;
  final bool wroteTodayDiary; // 오늘 일기를 작성했는지
  final List<EmotionEntry> recentEntries; // 최근 5개 일기

  const StudentSummary({
    required this.studentUid,
    required this.name,
    required this.growthLevel,
    required this.health,
    this.lastWateredDate,
    this.plantType,
    this.latestEmotion,
    required this.streakDays,
    required this.totalEntries,
    required this.wroteTodayDiary,
    required this.recentEntries,
  });

  factory StudentSummary.fromMap(String uid, Map<String, dynamic> data) {
    final rawRecent = data['recentEntries'] as List<dynamic>? ?? [];
    final recentEntries = rawRecent
        .whereType<Map<String, dynamic>>()
        .map(EmotionEntry.fromJson)
        .toList();

    DateTime? lastWatered;
    final lw = data['lastWateredDate'];
    if (lw is String) lastWatered = DateTime.tryParse(lw);

    return StudentSummary(
      studentUid: uid,
      name: data['name'] as String? ?? '이름 없음',
      growthLevel: (data['growthLevel'] as num?)?.toInt() ?? 0,
      health: (data['health'] as num?)?.toInt() ?? 100,
      lastWateredDate: lastWatered,
      plantType: data['plantType'] as String?,
      latestEmotion: data['latestEmotion'] as String?,
      streakDays: (data['streakDays'] as num?)?.toInt() ?? 0,
      totalEntries: (data['totalEntries'] as num?)?.toInt() ?? 0,
      wroteTodayDiary: data['wroteTodayDiary'] as bool? ?? false,
      recentEntries: recentEntries,
    );
  }
}

/// 교사 상세 화면에서 사용하는 학생의 전체 데이터
class StudentDetailData {
  final StudentSummary summary;
  final List<EmotionEntry> allEntries; // 날짜 내림차순 정렬

  const StudentDetailData({
    required this.summary,
    required this.allEntries,
  });
}
