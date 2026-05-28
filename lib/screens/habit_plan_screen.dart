import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';

class HabitPlanScreen extends StatefulWidget {
  const HabitPlanScreen({super.key});

  @override
  State<HabitPlanScreen> createState() => _HabitPlanScreenState();
}

class _HabitPlanScreenState extends State<HabitPlanScreen> {
  bool _loading = false;
  List<HabitSuggestion>? _habits;
  final Set<int> _checkedToday = {};

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final provider = context.read<AppProvider>();
    setState(() { _loading = true; });
    final svc = AiService(provider.apiKey);
    final habits = await svc.generateHabitPlan(
      childName: provider.studentName,
      entries: provider.diaryEntries,
    );
    if (!mounted) return;
    setState(() {
      _habits = habits;
      _loading = false;
      _checkedToday.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final name = provider.studentName.isEmpty ? '친구' : provider.studentName;

    return Scaffold(
      body: WarmBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.softCloud, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$name의 성장 습관',
                          style: const TextStyle(
                            color: AppTheme.softCloud,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'AI가 일기를 분석해서 만든 나만의 습관이야 🌱',
                          style: TextStyle(
                            color: AppTheme.softCloud.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '새로고침',
                      icon: _loading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(AppTheme.softCloud),
                              ),
                            )
                          : const Icon(Icons.refresh_rounded,
                              color: AppTheme.softCloud, size: 22),
                      onPressed: _loading ? null : _generate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading && _habits == null
                    ? _LoadingView()
                    : _HabitList(
                        habits: _habits ?? [],
                        checkedToday: _checkedToday,
                        onToggle: (i) => setState(() {
                          if (_checkedToday.contains(i)) {
                            _checkedToday.remove(i);
                          } else {
                            _checkedToday.add(i);
                          }
                        }),
                      ),
              ),
              // 오늘 달성 수 표시
              if (_habits != null && _habits!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: _DailyProgress(
                    checked: _checkedToday.length,
                    total: _habits!.length,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppTheme.softMoss),
          ),
          const SizedBox(height: 16),
          Text(
            'AI가 일기를 읽고 있어요...',
            style: TextStyle(
              color: AppTheme.softCloud.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitList extends StatelessWidget {
  final List<HabitSuggestion> habits;
  final Set<int> checkedToday;
  final void Function(int) onToggle;

  const _HabitList({
    required this.habits,
    required this.checkedToday,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      itemCount: habits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final h = habits[i];
        final checked = checkedToday.contains(i);
        return _HabitCard(
          habit: h,
          checked: checked,
          onTap: () => onToggle(i),
          index: i,
        );
      },
    );
  }
}

class _HabitCard extends StatelessWidget {
  final HabitSuggestion habit;
  final bool checked;
  final VoidCallback onTap;
  final int index;

  const _HabitCard({
    required this.habit,
    required this.checked,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: checked
              ? AppTheme.softMoss.withValues(alpha: 0.28)
              : AppTheme.deepForest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: checked
                ? AppTheme.softMoss.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.08),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이모지 + 체크
            SizedBox(
              width: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(habit.emoji, style: const TextStyle(fontSize: 36)),
                  if (checked)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppTheme.softMoss,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 12),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: TextStyle(
                      color: checked
                          ? AppTheme.softMoss
                          : AppTheme.softCloud,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      decoration: checked
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: AppTheme.softMoss,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded,
                          size: 13,
                          color: AppTheme.dawnGlow.withValues(alpha: 0.8)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          habit.action,
                          style: TextStyle(
                            color: AppTheme.softCloud.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '💬 ${habit.reason}',
                      style: TextStyle(
                        color: AppTheme.softCloud.withValues(alpha: 0.6),
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      )
          .animate(delay: Duration(milliseconds: index * 80))
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.12, end: 0),
    );
  }
}

class _DailyProgress extends StatelessWidget {
  final int checked;
  final int total;

  const _DailyProgress({required this.checked, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? checked / total : 0.0;
    final allDone = checked >= total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: allDone
            ? AppTheme.softMoss.withValues(alpha: 0.25)
            : AppTheme.deepForest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: allDone
              ? AppTheme.softMoss.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                allDone ? '🎉 오늘 습관 완료!' : '오늘 한 것: $checked / $total',
                style: TextStyle(
                  color: allDone ? AppTheme.softMoss : AppTheme.softCloud,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(ratio * 100).round()}%',
                style: TextStyle(
                  color: AppTheme.softCloud.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(
                allDone ? AppTheme.softMoss : AppTheme.dawnGlow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
