// FILE: lib/screens/student_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../models/class_models.dart';
import '../services/ai_service.dart';
import '../services/class_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentUid;
  final String classCode;
  final String apiKey;
  final String studentName;

  const StudentDetailScreen({
    super.key,
    required this.studentUid,
    required this.classCode,
    required this.apiKey,
    required this.studentName,
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  bool _analyzingAi = false;

  // ── AI 분석 바텀 시트 ────────────────────────────────────────────────────
  Future<void> _showAiReport(
    BuildContext context,
    List<EmotionEntry> entries,
  ) async {
    setState(() => _analyzingAi = true);
    String? report;
    String? errorMsg;

    try {
      final svc = AiService(widget.apiKey);
      report = await svc.analyzeChild(
        childName: widget.studentName,
        entries: entries,
      );
    } on AiException catch (e) {
      errorMsg = e.message;
    } catch (e) {
      errorMsg = 'AI 분석 중 문제가 생겼어요. 잠시 후 다시 시도해주세요.';
    } finally {
      if (mounted) setState(() => _analyzingAi = false);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiReportSheet(
        studentName: widget.studentName,
        report: report,
        error: errorMsg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.studentName,
          style: const TextStyle(
            color: AppTheme.dawnGlow,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppTheme.dawnGlow),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: WarmBackground(
        child: StreamBuilder<StudentDetailData>(
          stream:
              ClassService.watchStudentDetail(widget.classCode, widget.studentUid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.softMoss),
                ),
              );
            }
            if (snapshot.hasError) {
              return _ErrorBody(error: snapshot.error.toString());
            }
            final data = snapshot.data;
            if (data == null) {
              return const _ErrorBody(error: '학생 데이터를 불러올 수 없어요.');
            }
            return _DetailBody(
              data: data,
              analyzingAi: _analyzingAi,
              onAiTap: () => _showAiReport(context, data.allEntries),
            );
          },
        ),
      ),
    );
  }
}

// ── 본문 ─────────────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  final StudentDetailData data;
  final bool analyzingAi;
  final VoidCallback onAiTap;

  const _DetailBody({
    required this.data,
    required this.analyzingAi,
    required this.onAiTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = data.summary;
    final entries = data.allEntries;

    // 최근 30일 감정 분포 계산
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent30 = entries.where((e) => e.date.isAfter(cutoff)).toList();
    final Map<String, int> emotionCounts = {};
    for (final e in recent30) {
      emotionCounts[e.emotion] = (emotionCounts[e.emotion] ?? 0) + 1;
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ── 식물 카드 ────────────────────────────────────────────────
          _PlantCard(summary: s),

          const SizedBox(height: 16),

          // ── 통계 행 ──────────────────────────────────────────────────
          _StatsRow(summary: s),

          const SizedBox(height: 16),

          // ── 감정 분포 ────────────────────────────────────────────────
          _SectionCard(
            title: '📊 최근 30일 감정 분포',
            child: _EmotionDistributionChart(
              emotionCounts: emotionCounts,
              total: recent30.length,
            ),
          ),

          const SizedBox(height: 16),

          // ── 최근 일기 목록 ────────────────────────────────────────────
          _SectionCard(
            title: '📔 최근 일기',
            child: entries.isEmpty
                ? const _EmptyEntries()
                : Column(
                    children: entries
                        .take(10)
                        .map((e) => _DiaryEntryTile(entry: e))
                        .toList(),
                  ),
          ),

          const SizedBox(height: 24),

          // ── AI 분석 버튼 ──────────────────────────────────────────────
          _AiAnalysisButton(
            loading: analyzingAi,
            disabled: entries.isEmpty,
            onTap: onAiTap,
          ),
        ],
      ),
    );
  }
}

// ── 식물 카드 ─────────────────────────────────────────────────────────────────

class _PlantCard extends StatelessWidget {
  final StudentSummary summary;
  const _PlantCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final plantType = plantTypeFromName(summary.plantType);
    final species = PlantDictionary.species[plantType]!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: warmCardDeco(radius: 20),
      child: Row(
        children: [
          // 식물 이모지
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.softMoss.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                species.emoji,
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  species.name,
                  style: const TextStyle(
                    color: AppTheme.dawnGlow,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                // 성장 바
                _LabeledBar(
                  label: '🌱 성장',
                  value: summary.growthLevel / 100.0,
                  percent: summary.growthLevel,
                  color: AppTheme.softMoss,
                ),

                const SizedBox(height: 8),

                // 수분 바
                _LabeledBar(
                  label: '💧 수분 상태',
                  value: summary.health / 100.0,
                  percent: summary.health,
                  color: summary.health > 60
                      ? AppTheme.morningDew
                      : summary.health > 30
                          ? AppTheme.warmAmber
                          : const Color(0xFFEF9A9A),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledBar extends StatelessWidget {
  final String label;
  final double value;
  final int percent;
  final Color color;

  const _LabeledBar({
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSubtle,
                fontSize: 11,
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 7,
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 통계 행 ───────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final StudentSummary summary;
  const _StatsRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          icon: '📝',
          label: '총 일기',
          value: '${summary.totalEntries}개',
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: '🔥',
          label: '연속 기록',
          value: '${summary.streakDays}일',
        ),
        const SizedBox(width: 10),
        _StatChip(
          icon: summary.wroteTodayDiary ? '✅' : '⏳',
          label: '오늘 작성',
          value: summary.wroteTodayDiary ? '완료' : '미작성',
          valueColor: summary.wroteTodayDiary
              ? AppTheme.softMoss
              : AppTheme.warmAmber,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: warmCardDeco(radius: 16),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppTheme.dawnGlow,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSubtle,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 감정 분포 차트 ────────────────────────────────────────────────────────────

class _EmotionDistributionChart extends StatelessWidget {
  final Map<String, int> emotionCounts;
  final int total;

  const _EmotionDistributionChart({
    required this.emotionCounts,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            '최근 30일 기록이 없어요',
            style: TextStyle(color: AppTheme.textSubtle, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: Emotions.all.map((emotion) {
        final count = emotionCounts[emotion.id] ?? 0;
        final ratio = total > 0 ? count / total : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // 감정 아이콘 + 레이블
              SizedBox(
                width: 72,
                child: Row(
                  children: [
                    Text(emotion.icon,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        emotion.label,
                        style: const TextStyle(
                          color: AppTheme.textSubtle,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // 바 차트
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 14,
                    child: Stack(
                      children: [
                        // 배경
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // 값 바
                        FractionallySizedBox(
                          widthFactor: ratio.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: emotion.comforting
                                  ? AppTheme.warmAmber.withValues(alpha: 0.6)
                                  : AppTheme.softMoss.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // 횟수
              SizedBox(
                width: 24,
                child: Text(
                  '$count',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppTheme.dawnGlow,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── 일기 항목 타일 ────────────────────────────────────────────────────────────

class _DiaryEntryTile extends StatelessWidget {
  final EmotionEntry entry;
  const _DiaryEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('M월 d일', 'ko_KR');
    final preview = entry.diaryText.trim().isEmpty
        ? '(내용 없음)'
        : entry.diaryText.trim().length > 60
            ? '${entry.diaryText.trim().substring(0, 60)}…'
            : entry.diaryText.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 감정 아이콘
          Text(
            entry.emotionInfo.icon,
            style: const TextStyle(fontSize: 22),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 + AI 배지
                Row(
                  children: [
                    Text(
                      df.format(entry.date),
                      style: const TextStyle(
                        color: AppTheme.textSubtle,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entry.emotionInfo.label,
                      style: const TextStyle(
                        color: AppTheme.textSubtle,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    if (entry.aiNarration != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.warmLavender.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '✨ AI 일기 있음',
                          style: TextStyle(
                            color: AppTheme.warmLavender,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 4),

                // 일기 미리보기
                Text(
                  preview,
                  style: const TextStyle(
                    color: AppTheme.dawnGlow,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI 분석 버튼 ──────────────────────────────────────────────────────────────

class _AiAnalysisButton extends StatelessWidget {
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;

  const _AiAnalysisButton({
    required this.loading,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = loading || disabled;

    return GestureDetector(
      onTap: inactive ? null : onTap,
      child: Opacity(
        opacity: inactive ? 0.45 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.softMoss, AppTheme.lightForest],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.softMoss.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation(AppTheme.softCloud),
                    ),
                  )
                : const Text(
                    '🤖 AI 분석 리포트 보기',
                    style: TextStyle(
                      color: AppTheme.softCloud,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── AI 리포트 바텀 시트 ───────────────────────────────────────────────────────

class _AiReportSheet extends StatelessWidget {
  final String studentName;
  final String? report;
  final String? error;

  const _AiReportSheet({
    required this.studentName,
    this.report,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.deepForest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: AppTheme.softMoss.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // 드래그 핸들
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text('🤖', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$studentName AI 분석 리포트',
                            style: const TextStyle(
                              color: AppTheme.dawnGlow,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '이 분석은 교사의 이해를 돕는 참고 자료입니다',
                            style: TextStyle(
                              color: AppTheme.textSubtle,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.textSubtle,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(
                color: Colors.white12,
                height: 20,
                indent: 20,
                endIndent: 20,
              ),

              // 내용
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  children: [
                    if (error != null)
                      _ErrorBody(error: error!)
                    else if (report != null)
                      _ReportMarkdown(report: report!)
                    else
                      const Center(
                        child: Text(
                          '분석 결과가 없어요.',
                          style: TextStyle(
                            color: AppTheme.textSubtle,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── 리포트 마크다운 렌더러 ────────────────────────────────────────────────────

class _ReportMarkdown extends StatelessWidget {
  final String report;
  const _ReportMarkdown({required this.report});

  @override
  Widget build(BuildContext context) {
    final lines = report.split('\n');
    final widgets = <Widget>[];

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(
            line.substring(3).trim(),
            style: const TextStyle(
              color: AppTheme.softMoss,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ));
      } else if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            line.substring(2).trim(),
            style: const TextStyle(
              color: AppTheme.dawnGlow,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ));
      } else {
        final clean = line
            .replaceAll('**', '')
            .replaceFirst(RegExp(r'^[-*]\s*'), '· ');
        widgets.add(Text(
          clean,
          style: const TextStyle(
            color: AppTheme.textOnDark,
            fontSize: 14,
            height: 1.7,
          ),
        ));
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.softMoss.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }
}

// ── 섹션 카드 래퍼 ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: warmCardDeco(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.dawnGlow,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── 빈 일기 ───────────────────────────────────────────────────────────────────

class _EmptyEntries extends StatelessWidget {
  const _EmptyEntries();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          children: [
            Text('📔', style: TextStyle(fontSize: 32)),
            SizedBox(height: 8),
            Text(
              '아직 일기가 없어요',
              style: TextStyle(
                color: AppTheme.textSubtle,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 오류 본문 ─────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String error;
  const _ErrorBody({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😢', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSubtle,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
