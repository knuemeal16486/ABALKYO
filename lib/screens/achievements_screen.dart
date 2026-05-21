import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/achievement.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  bool _check(Achievement a, AppProvider p) => switch (a.id) {
        'first_diary' => p.totalEntries >= 1,
        'streak_3' => p.streakDays >= 3,
        'streak_7' => p.streakDays >= 7,
        'total_10' => p.totalEntries >= 10,
        'total_30' => p.totalEntries >= 30,
        'first_harvest' => p.collection.isNotEmpty,
        'two_harvest' => p.collection.length >= 2,
        'all_emotions' =>
          p.diaryEntries.map((e) => e.emotion).toSet().length >= 8,
        'comforting_5' =>
          p.diaryEntries
              .where((e) => Emotions.isComforting(e.emotion))
              .length >=
          5,
        'photo_diary' => p.diaryEntries.any((e) => e.imageUrl != null),
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final unlocked = kAchievements.where((a) => _check(a, provider)).length;

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
                        child: Text('나의 배지',
                            style: TextStyle(
                                color: AppTheme.dawnGlow,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          '$unlocked / ${kAchievements.length}',
                          style: const TextStyle(
                              color: AppTheme.dawnGlow,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                              begin: 0,
                              end: unlocked / kAchievements.length),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => LinearProgressIndicator(
                            value: v,
                            minHeight: 8,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            valueColor: const AlwaysStoppedAnimation(
                                AppTheme.softMoss),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('$unlocked개 획득',
                          style: const TextStyle(
                              color: AppTheme.textSubtle, fontSize: 11)),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: kAchievements.length,
                    itemBuilder: (context, i) {
                      final a = kAchievements[i];
                      final done = _check(a, provider);
                      return _BadgeCard(
                        achievement: a,
                        unlocked: done,
                        index: i,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final Achievement achievement;
  final bool unlocked;
  final int index;

  const _BadgeCard({
    required this.achievement,
    required this.unlocked,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final color = achievement.color;

    Widget card = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: unlocked
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.08),
                ],
              )
            : null,
        color: unlocked ? null : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: unlocked
              ? color.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: unlocked ? 1.5 : 1,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (unlocked)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.15),
                  ),
                ),
              Text(
                achievement.emoji,
                style: TextStyle(
                    fontSize: 36,
                    color: unlocked ? null : null),
              ),
              if (!unlocked)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: Colors.white54, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            achievement.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: unlocked ? AppTheme.dawnGlow : AppTheme.textSubtle,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            achievement.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unlocked
                  ? AppTheme.textOnDark
                  : AppTheme.textSubtle.withValues(alpha: 0.6),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );

    if (unlocked) {
      card = card
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(
              duration: 2800.ms,
              color: color.withValues(alpha: 0.25),
              delay: Duration(milliseconds: index * 300));
    }

    return card
        .animate(delay: Duration(milliseconds: 60 * index))
        .fadeIn(duration: 500.ms)
        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
  }
}
