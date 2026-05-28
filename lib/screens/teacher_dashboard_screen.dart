// FILE: lib/screens/teacher_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_models.dart';
import '../models/class_models.dart';
import '../services/class_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import 'student_detail_screen.dart';
import '../services/ai_service.dart';

class TeacherDashboardScreen extends StatelessWidget {
  final String classCode;
  final String apiKey;

  const TeacherDashboardScreen({
    super.key,
    required this.classCode,
    required this.apiKey,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeader(classCode: classCode),
              Expanded(
                child: StreamBuilder<List<StudentSummary>>(
                  stream: ClassService.watchStudents(classCode),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation(AppTheme.softMoss),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _ErrorView(error: snapshot.error.toString());
                    }
                    final students = snapshot.data ?? [];
                    if (students.isEmpty) {
                      return const _EmptyClassView();
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.80,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        return _StudentCard(
                          summary: students[index],
                          classCode: classCode,
                          apiKey: apiKey,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'ai_report',
            backgroundColor: const Color(0xFF7B5EA7),
            foregroundColor: Colors.white,
            onPressed: () => _showClassReport(context, classCode, apiKey),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('학급 AI 리포트',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'class_code',
            backgroundColor: AppTheme.softMoss,
            foregroundColor: AppTheme.softCloud,
            onPressed: () => _showClassCodeDialog(context),
            icon: const Text('📋', style: TextStyle(fontSize: 20)),
            label: const Text('학급 코드',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showClassReport(BuildContext context, String classCode, String apiKey) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClassReportSheet(
        classCode: classCode,
        apiKey: apiKey,
      ),
    );
  }

  void _showClassCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.deepForest.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.softMoss.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🌱 학급 참여 코드',
                style: TextStyle(
                  color: AppTheme.dawnGlow,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '학생들에게 이 코드를 알려주세요',
                style: TextStyle(color: AppTheme.textSubtle, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.softMoss.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.softMoss.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  classCode,
                  style: const TextStyle(
                    color: AppTheme.warmAmber,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: classCode));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('코드가 복사됐어요!')),
                      );
                    },
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: AppTheme.textSubtle,
                      size: 18,
                    ),
                    label: const Text(
                      '복사하기',
                      style:
                          TextStyle(color: AppTheme.textSubtle, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      '닫기',
                      style:
                          TextStyle(color: AppTheme.softMoss, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 헤더 ──────────────────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final String classCode;
  const _DashboardHeader({required this.classCode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: const Icon(
                  Icons.arrow_back_ios_rounded,
                  color: AppTheme.dawnGlow,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '🧑‍🏫 우리 반 정원',
                style: TextStyle(
                  color: AppTheme.dawnGlow,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(
              '학급 코드: $classCode',
              style: const TextStyle(
                color: AppTheme.textSubtle,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 학생 카드 ─────────────────────────────────────────────────────────────────

class _StudentCard extends StatelessWidget {
  final StudentSummary summary;
  final String classCode;
  final String apiKey;

  const _StudentCard({
    required this.summary,
    required this.classCode,
    required this.apiKey,
  });

  bool get _isWilting {
    if (summary.health < 30) return true;
    final last = summary.lastWateredDate;
    if (last == null) return true;
    return DateTime.now().difference(last).inDays >= 3;
  }

  @override
  Widget build(BuildContext context) {
    final wilting = _isWilting;
    final plantType = plantTypeFromName(summary.plantType);
    final species = PlantDictionary.species[plantType]!;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentDetailScreen(
              studentUid: summary.studentUid,
              classCode: classCode,
              apiKey: apiKey,
              studentName: summary.name,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: wilting ? 0.06 : 0.09),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: wilting
                ? const Color(0xFFE57373).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.18),
            width: wilting ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이름 + 최신 감정 아이콘
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.name,
                    style: const TextStyle(
                      color: AppTheme.dawnGlow,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (summary.latestEmotion != null)
                  Text(
                    Emotions.byId(summary.latestEmotion!).icon,
                    style: const TextStyle(fontSize: 18),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // 식물 이모지 + 성장률
            Row(
              children: [
                Text(species.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 6),
                Text(
                  '${summary.growthLevel}%',
                  style: const TextStyle(
                    color: AppTheme.warmAmber,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // 성장 바
            _MiniBar(
              value: summary.growthLevel / 100.0,
              color: AppTheme.softMoss,
            ),

            const SizedBox(height: 4),

            // 수분(체력) 바
            _MiniBar(
              value: summary.health / 100.0,
              color: summary.health > 60
                  ? AppTheme.softMoss
                  : summary.health > 30
                      ? AppTheme.warmAmber
                      : const Color(0xFFE57373),
            ),

            const SizedBox(height: 8),

            // 오늘 일기 작성 여부
            Text(
              summary.wroteTodayDiary ? '💧 물 줬어요' : '⏳ 오늘 미작성',
              style: TextStyle(
                color: summary.wroteTodayDiary
                    ? AppTheme.softMoss
                    : AppTheme.warmAmber,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 4),

            // 연속 기록
            Text(
              '🔥 ${summary.streakDays}일',
              style: const TextStyle(
                color: AppTheme.textSubtle,
                fontSize: 11,
              ),
            ),

            // 시들어요 경고
            if (wilting) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE57373).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '❗시들어요',
                  style: TextStyle(
                    color: Color(0xFFEF9A9A),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 미니 바 ───────────────────────────────────────────────────────────────────

class _MiniBar extends StatelessWidget {
  final double value; // 0.0 – 1.0
  final Color color;

  const _MiniBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 5,
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }
}

// ── 빈 화면 ───────────────────────────────────────────────────────────────────

class _EmptyClassView extends StatelessWidget {
  const _EmptyClassView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('🌱', style: TextStyle(fontSize: 56)),
            SizedBox(height: 16),
            Text(
              '아직 학생이 없어요',
              style: TextStyle(
                color: AppTheme.dawnGlow,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '학급 코드를 학생들에게 알려주면\n학생들이 반에 참여할 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSubtle,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 오류 화면 ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😢', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(
              '데이터를 불러오는 중 문제가 생겼어요.\n$error',
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

// ── 학급 AI 리포트 시트 ────────────────────────────────────────────────────────

class _ClassReportSheet extends StatefulWidget {
  final String classCode;
  final String apiKey;
  const _ClassReportSheet({required this.classCode, required this.apiKey});

  @override
  State<_ClassReportSheet> createState() => _ClassReportSheetState();
}

class _ClassReportSheetState extends State<_ClassReportSheet> {
  bool _loading = true;
  String? _report;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; _report = null; });
    try {
      // 최신 학생 목록을 Firestore에서 한 번만 읽어옴
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classCode)
          .collection('students')
          .get();

      final students = snapshot.docs.map((doc) {
        final data = doc.data();
        final rawEmotions = (data['recentEntries'] as List<dynamic>? ?? [])
            .take(5)
            .map((e) {
              final emotion = (e as Map<String, dynamic>)['emotion'] as String? ?? '';
              return emotion;
            })
            .where((e) => e.isNotEmpty)
            .toList();
        return StudentSummaryData(
          name: data['name'] as String? ?? '이름 없음',
          recentEmotions: rawEmotions,
          streakDays: (data['streakDays'] as num?)?.toInt() ?? 0,
          wroteTodayDiary: data['wroteTodayDiary'] as bool? ?? false,
          health: (data['health'] as num?)?.toInt() ?? 100,
        );
      }).toList();

      final svc = AiService(widget.apiKey);
      final report = await svc.generateClassSummary(
        classCode: widget.classCode,
        students: students,
      );
      if (!mounted) return;
      setState(() { _report = report; _loading = false; });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1035),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: Color(0xFFCE93D8), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '학급 AI 리포트',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: _loading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Color(0xFFCE93D8)),
                            ),
                          )
                        : const Icon(Icons.refresh_rounded,
                            color: Colors.white60, size: 20),
                    onPressed: _loading ? null : _generate,
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: _loading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Color(0xFFCE93D8)),
                          ),
                          SizedBox(height: 16),
                          Text('AI가 학급 현황을 분석 중이에요...',
                              style: TextStyle(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: Colors.redAccent, fontSize: 14),
                                textAlign: TextAlign.center),
                          ),
                        )
                      : SingleChildScrollView(
                          controller: ctrl,
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                          child: _MarkdownReport(text: _report ?? ''),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkdownReport extends StatelessWidget {
  final String text;
  const _MarkdownReport({required this.text});

  @override
  Widget build(BuildContext context) {
    final sections = text.split(RegExp(r'(?=^## )', multiLine: true));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((section) {
        if (section.trim().isEmpty) return const SizedBox.shrink();
        final lines = section.trim().split('\n');
        final title = lines.first.replaceAll('## ', '').trim();
        final body = lines.skip(1).join('\n').trim();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B5EA7).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFCE93D8),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                  height: 1.6,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
