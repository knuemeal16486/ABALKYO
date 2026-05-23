import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import 'achievements_screen.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      body: WarmBackground(
        child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios_rounded,
                            color: AppTheme.dawnGlow, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('나의 감정 이야기',
                            style: TextStyle(
                                color: AppTheme.dawnGlow,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AchievementsScreen())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            children: [
                              Text('🏅', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 6),
                              Text('배지',
                                  style: TextStyle(
                                      color: AppTheme.dawnGlow, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    children: [
                      _StreakCard(provider: provider),
                      const SizedBox(height: 20),
                      _WeekMoodRow(provider: provider),
                      const SizedBox(height: 20),
                      _EmotionDistribution(provider: provider),
                      const SizedBox(height: 20),
                      _EmotionPersonality(provider: provider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

// ─── 스트릭 + 총 기록 ─────────────────────────────────────────────────────────
class _StreakCard extends StatelessWidget {
  final AppProvider provider;
  const _StreakCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final streak = provider.streakDays;
    final total = provider.totalEntries;
    final streakEmoji = streak == 0 ? '🌱' : (streak >= 7 ? '🔥' : '✨');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(streakEmoji, style: const TextStyle(fontSize: 38))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.12, 1.12),
                        duration: 1400.ms),
                const SizedBox(height: 10),
                Text('$streak일',
                    style: const TextStyle(
                        color: AppTheme.dawnGlow,
                        fontSize: 30,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                const Text('연속 기록',
                    style: TextStyle(color: AppTheme.textSubtle, fontSize: 12)),
              ],
            ),
          ),
          Container(
              width: 1,
              height: 70,
              color: AppTheme.softMoss.withValues(alpha: 0.3)),
          Expanded(
            child: Column(
              children: [
                const Text('📔', style: TextStyle(fontSize: 38)),
                const SizedBox(height: 10),
                Text('$total개',
                    style: const TextStyle(
                        color: AppTheme.dawnGlow,
                        fontSize: 30,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                const Text('총 기록',
                    style: TextStyle(color: AppTheme.textSubtle, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }
}

// ─── 최근 7일 무드 ────────────────────────────────────────────────────────────
class _WeekMoodRow extends StatelessWidget {
  final AppProvider provider;
  const _WeekMoodRow({required this.provider});

  static const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  String? _dominantEmotion(List<EmotionEntry> entries, DateTime day) {
    final dayEntries = entries
        .where((e) =>
            DateTime(e.date.year, e.date.month, e.date.day) == day)
        .toList();
    if (dayEntries.isEmpty) return null;
    final counts = <String, int>{};
    for (final e in dayEntries) {
      counts[e.emotion] = (counts[e.emotion] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(
        7, (i) => today.subtract(Duration(days: 6 - i)));
    final entries = provider.diaryEntries;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.softMoss.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('최근 7일 감정',
              style: TextStyle(
                  color: AppTheme.dawnGlow,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final day = days[i];
              final emotion = _dominantEmotion(entries, day);
              final isToday = day == today;
              final wd = (day.weekday - 1) % 7;

              return Column(
                children: [
                  Text(_weekdayLabels[wd],
                      style: TextStyle(
                          color: isToday
                              ? AppTheme.morningDew
                              : AppTheme.textSubtle,
                          fontSize: 11,
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal)),
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: emotion != null
                          ? _emotionColor(emotion).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isToday
                            ? AppTheme.morningDew
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: emotion != null
                          ? Text(Emotions.iconOf(emotion),
                              style: const TextStyle(fontSize: 18))
                          : Text('${day.day}',
                              style: const TextStyle(
                                  color: AppTheme.textSubtle, fontSize: 11)),
                    ),
                  ),
                ],
              )
                  .animate(delay: (i * 70).ms)
                  .fadeIn(duration: 400.ms)
                  .scale(
                      begin: const Offset(0.6, 0.6),
                      end: const Offset(1, 1));
            }),
          ),
        ],
      ),
    ).animate(delay: 150.ms).fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Color _emotionColor(String id) => switch (id) {
        'happy' => const Color(0xFFFFD54F),
        'excited' => const Color(0xFFFF8A65),
        'calm' => const Color(0xFF81C784),
        'thankful' => const Color(0xFFF06292),
        'sad' => const Color(0xFF64B5F6),
        'anxious' => const Color(0xFFBA68C8),
        'angry' => const Color(0xFFE57373),
        'depressed' => const Color(0xFF90A4AE),
        _ => AppTheme.softMoss,
      };
}

// ─── 감정 분포 차트 ───────────────────────────────────────────────────────────
class _EmotionDistribution extends StatelessWidget {
  final AppProvider provider;
  const _EmotionDistribution({required this.provider});

  Color _color(String id) => switch (id) {
        'happy' => const Color(0xFFFFD54F),
        'excited' => const Color(0xFFFF8A65),
        'calm' => const Color(0xFF81C784),
        'thankful' => const Color(0xFFF06292),
        'sad' => const Color(0xFF64B5F6),
        'anxious' => const Color(0xFFBA68C8),
        'angry' => const Color(0xFFE57373),
        'depressed' => const Color(0xFF90A4AE),
        _ => AppTheme.softMoss,
      };

  @override
  Widget build(BuildContext context) {
    final counts = provider.emotionCounts(days: 30);
    final total = counts.values.fold(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.softMoss.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('이달의 감정 분포',
              style: TextStyle(
                  color: AppTheme.dawnGlow,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          const Text('최근 30일',
              style: TextStyle(color: AppTheme.textSubtle, fontSize: 11)),
          const SizedBox(height: 16),
          if (total == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '아직 기록이 없어요. 오늘 첫 일기를 써봐요! 🌱',
                  style: TextStyle(color: AppTheme.textSubtle, fontSize: 13),
                ),
              ),
            )
          else
            ...() {
              final sorted = Emotions.all
                  .map((e) => (e, counts[e.id] ?? 0))
                  .where((pair) => pair.$2 > 0)
                  .toList()
                ..sort((a, b) => b.$2.compareTo(a.$2));
              return sorted.asMap().entries.map((entry) {
                final i = entry.key;
                final (emotion, count) = entry.value;
                final ratio = count / total;
                final color = _color(emotion.id);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Text(emotion.icon,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 38,
                        child: Text(emotion.label,
                            style: const TextStyle(
                                color: AppTheme.textOnDark, fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: ratio),
                            duration:
                                Duration(milliseconds: 700 + i * 80),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => LinearProgressIndicator(
                              value: v,
                              minHeight: 11,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.08),
                              valueColor:
                                  AlwaysStoppedAnimation(color),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 24,
                        child: Text('$count',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
                    .animate(delay: (i * 60).ms)
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: 0.2, end: 0);
              });
            }(),
        ],
      ),
    )
        .animate(delay: 300.ms)
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.2, end: 0);
  }
}

// ─── 이달의 감정 친구 ─────────────────────────────────────────────────────────
class _EmotionPersonality extends StatelessWidget {
  final AppProvider provider;
  const _EmotionPersonality({required this.provider});

  static const _messages = {
    'happy': '기쁜 마음이 가득한 달이었어요! 그 에너지가 정원을 환하게 밝혀줘요.',
    'excited': '신나는 일이 많았던 달이에요! 활기찬 마음이 식물에게 전해져요.',
    'calm': '평온하고 차분한 달을 보냈네요. 고요한 마음이 정원을 키워요.',
    'thankful': '감사한 마음이 넘치는 달이었어요. 감사함이 꽃을 피워요.',
    'sad': '힘든 감정도 잘 표현했어요. 슬픔을 마주하는 용기가 대단해요.',
    'anxious': '불안한 마음을 솔직하게 적었어요. 표현하는 것만으로도 마음이 가벼워져요.',
    'angry': '화난 감정도 일기로 표현했어요. 감정을 알아채는 것이 첫 걸음이에요.',
    'depressed': '힘든 날도 기록으로 남겼어요. 기록하는 것만으로도 충분히 훌륭해요.',
  };

  Color _color(String id) => switch (id) {
        'happy' => const Color(0xFFFFD54F),
        'excited' => const Color(0xFFFF8A65),
        'calm' => const Color(0xFF81C784),
        'thankful' => const Color(0xFFF06292),
        'sad' => const Color(0xFF64B5F6),
        'anxious' => const Color(0xFFBA68C8),
        'angry' => const Color(0xFFE57373),
        'depressed' => const Color(0xFF90A4AE),
        _ => AppTheme.softMoss,
      };

  @override
  Widget build(BuildContext context) {
    final counts = provider.emotionCounts(days: 30);
    if (counts.isEmpty) {
      return const SizedBox.shrink();
    }

    final dominant =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final emotion = Emotions.byId(dominant);
    final color = _color(dominant);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            Colors.black.withValues(alpha: 0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          const Text('이달의 감정 친구',
              style:
                  TextStyle(color: AppTheme.textSubtle, fontSize: 12)),
          const SizedBox(height: 14),
          Text(emotion.icon, style: const TextStyle(fontSize: 56))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.08, 1.08),
                  duration: 1600.ms),
          const SizedBox(height: 10),
          Text(emotion.label,
              style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Text(
            _messages[dominant] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppTheme.textOnDark, fontSize: 13, height: 1.7),
          ),
        ],
      ),
    )
        .animate(delay: 500.ms)
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.2, end: 0);
  }
}
