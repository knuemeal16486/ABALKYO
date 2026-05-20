import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D1F14), Color(0xFF1B3A2D)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // 헤더
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
                      const Text('마음 달력',
                          style: TextStyle(
                              color: AppTheme.dawnGlow,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      _StatsCard(provider: provider),
                      _buildCalendar(provider),
                      const Divider(color: Color(0xFF2D5A3D), height: 1),
                      _buildSelectedHeader(),
                      _buildEntries(provider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(AppProvider provider) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2035, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
      onDaySelected: (sel, foc) => setState(() {
        _selectedDay = sel;
        _focusedDay = foc;
      }),
      availableGestures: AvailableGestures.horizontalSwipe,
      calendarStyle: CalendarStyle(
        defaultTextStyle: const TextStyle(color: AppTheme.dawnGlow),
        weekendTextStyle:
            TextStyle(color: AppTheme.dawnGlow.withValues(alpha: 0.7)),
        outsideTextStyle:
            TextStyle(color: AppTheme.textSubtle.withValues(alpha: 0.4)),
        todayDecoration: BoxDecoration(
            color: AppTheme.softMoss.withValues(alpha: 0.5),
            shape: BoxShape.circle),
        selectedDecoration:
            const BoxDecoration(color: AppTheme.softMoss, shape: BoxShape.circle),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
            color: AppTheme.dawnGlow, fontSize: 16, fontWeight: FontWeight.bold),
        leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.textSubtle),
        rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.textSubtle),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          final entry = provider.diaryEntries
              .where((e) => isSameDay(e.date, date))
              .firstOrNull;
          if (entry == null) return null;
          return Positioned(
            bottom: 1,
            child: Text(entry.emotionInfo.icon,
                style: const TextStyle(fontSize: 10)),
          );
        },
      ),
    );
  }

  Widget _buildSelectedHeader() {
    if (_selectedDay == null) return const SizedBox.shrink();
    final df = DateFormat('M월 d일 (E)', 'ko_KR');
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(df.format(_selectedDay!),
          style: const TextStyle(
              color: AppTheme.textSubtle,
              fontSize: 13,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildEntries(AppProvider provider) {
    final entries = provider.diaryEntries;
    final selected = _selectedDay == null
        ? <EmotionEntry>[]
        : entries.where((e) => isSameDay(e.date, _selectedDay)).toList();

    if (_selectedDay == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Text('🌿', style: TextStyle(fontSize: 36)),
              SizedBox(height: 10),
              Text('날짜를 선택하면 그날의 기록을 볼 수 있어요',
                  style: TextStyle(color: AppTheme.textSubtle, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (selected.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Text('🌱', style: TextStyle(fontSize: 36)),
              SizedBox(height: 10),
              Text('이 날의 기록이 없어요',
                  style: TextStyle(color: AppTheme.textSubtle, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final tf = DateFormat('a h:mm', 'ko_KR');
    return Column(
      children: selected.map((e) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.softMoss.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(e.emotionInfo.icon,
                      style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 8),
                  Text(e.emotionInfo.label,
                      style: const TextStyle(
                          color: AppTheme.dawnGlow,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(tf.format(e.date),
                      style: const TextStyle(
                          color: AppTheme.textSubtle, fontSize: 11)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _confirmDelete(context, provider, e),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppTheme.textSubtle, size: 18),
                  ),
                ],
              ),
              if (e.diaryText.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(e.diaryText,
                    style: const TextStyle(
                        color: AppTheme.textOnDark,
                        fontSize: 14,
                        height: 1.6)),
              ],
              if (e.imageUrl != null && File(e.imageUrl!).existsSync()) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(e.imageUrl!),
                      height: 180, width: double.infinity, fit: BoxFit.cover),
                ),
              ],
              if (e.aiImageUrl != null && File(e.aiImageUrl!).existsSync()) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(e.aiImageUrl!),
                      width: double.infinity, fit: BoxFit.cover),
                ),
                const SizedBox(height: 4),
                Text('🎨 AI 그림일기',
                    style: TextStyle(
                        color: AppTheme.textSubtle, fontSize: 11)),
              ],
              if (e.aiNarration != null && e.aiNarration!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.softMoss.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('🌱 ${e.aiNarration}',
                      style: const TextStyle(
                          color: AppTheme.dawnGlow,
                          fontSize: 13,
                          height: 1.7)),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  void _confirmDelete(
      BuildContext context, AppProvider provider, EmotionEntry e) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.midForest,
        title: const Text('이 기록을 지울까요?',
            style: TextStyle(color: AppTheme.dawnGlow, fontSize: 18)),
        content: Text('지운 기록은 되돌릴 수 없어요.',
            style: TextStyle(color: AppTheme.textSubtle, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('취소',
                  style: TextStyle(color: AppTheme.textSubtle))),
          TextButton(
              onPressed: () {
                provider.deleteEntry(e.id);
                Navigator.pop(dialogCtx);
              },
              child: const Text('삭제',
                  style: TextStyle(
                      color: Color(0xFFE57373), fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

// ── 통계 요약 카드 ────────────────────────────────────────────────────────────
class _StatsCard extends StatelessWidget {
  final AppProvider provider;
  const _StatsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final counts = provider.emotionCounts(days: 30);
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.softMoss.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Stat(
                  emoji: '🔥',
                  value: '${provider.streakDays}일',
                  label: '연속 기록'),
              const SizedBox(width: 12),
              _Stat(
                  emoji: '📔',
                  value: '${provider.totalEntries}개',
                  label: '전체 기록'),
            ],
          ),
          const SizedBox(height: 16),
          const Text('최근 30일 마음',
              style: TextStyle(
                  color: AppTheme.textSubtle,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if (sorted.isEmpty)
            Text('아직 기록이 없어요',
                style: TextStyle(color: AppTheme.textSubtle, fontSize: 13))
          else
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: sorted.map((e) {
                final info = Emotions.byId(e.key);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('${info.icon} ${info.label} ${e.value}',
                      style: const TextStyle(
                          color: AppTheme.dawnGlow, fontSize: 13)),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  const _Stat(
      {required this.emoji, required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.softMoss.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: AppTheme.dawnGlow,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSubtle, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
