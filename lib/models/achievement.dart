import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String emoji;
  final String name;
  final String description;
  final Color color;

  const Achievement({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.color,
  });
}

const List<Achievement> kAchievements = [
  Achievement(
    id: 'first_diary',
    emoji: '🌱',
    name: '첫 씨앗',
    description: '처음으로 마음을 기록했어요',
    color: Color(0xFF81C784),
  ),
  Achievement(
    id: 'streak_3',
    emoji: '✨',
    name: '싹이 텄어요',
    description: '3일 연속으로 감정을 기록했어요',
    color: Color(0xFFFFD54F),
  ),
  Achievement(
    id: 'streak_7',
    emoji: '🔥',
    name: '한 주의 정원사',
    description: '7일 연속 기록을 달성했어요',
    color: Color(0xFFFF8A65),
  ),
  Achievement(
    id: 'total_10',
    emoji: '📔',
    name: '꾸준한 기록가',
    description: '일기를 10번 이상 써봤어요',
    color: Color(0xFF64B5F6),
  ),
  Achievement(
    id: 'total_30',
    emoji: '📚',
    name: '일기 달인',
    description: '일기를 30번 이상 써봤어요',
    color: Color(0xFFBA68C8),
  ),
  Achievement(
    id: 'first_harvest',
    emoji: '🎉',
    name: '첫 수확',
    description: '식물을 처음으로 완전히 키워냈어요',
    color: Color(0xFFFFD54F),
  ),
  Achievement(
    id: 'two_harvest',
    emoji: '🏡',
    name: '나만의 정원',
    description: '식물 두 종류를 키워냈어요',
    color: Color(0xFF4DB6AC),
  ),
  Achievement(
    id: 'all_emotions',
    emoji: '🎭',
    name: '감정 탐험가',
    description: '8가지 감정을 모두 한 번씩 기록했어요',
    color: Color(0xFFF06292),
  ),
  Achievement(
    id: 'comforting_5',
    emoji: '🌧',
    name: '마음의 비',
    description: '힘든 감정을 5번 이상 솔직하게 표현했어요',
    color: Color(0xFF90CAF9),
  ),
  Achievement(
    id: 'photo_diary',
    emoji: '📸',
    name: '사진 일기',
    description: '사진과 함께 일기를 작성했어요',
    color: Color(0xFFFFB74D),
  ),
];
