import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';

/// 교사용: 아동의 최근 감정 일기를 AI로 분석해 정서 리포트 + 감정 패턴을 보여준다.
class TeacherReportScreen extends StatefulWidget {
  const TeacherReportScreen({super.key});
  @override
  State<TeacherReportScreen> createState() => _TeacherReportScreenState();
}

class _TeacherReportScreenState extends State<TeacherReportScreen> {
  bool _loading = false;
  String? _report;
  String? _error;

  Future<void> _generate() async {
    final provider = context.read<AppProvider>();
    setState(() {
      _loading = true;
      _error = null;
      _report = null;
    });
    try {
      final svc = AiService(provider.apiKey);
      final report = await svc.analyzeChild(
        childName: provider.studentName,
        entries: provider.diaryEntries,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final name =
        provider.studentName.isEmpty ? '학생' : provider.studentName;

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
                      Expanded(
                        child: Text('$name의 마음 리포트',
                            style: const TextStyle(
                                color: AppTheme.dawnGlow,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _caveat(),
                      const SizedBox(height: 16),
                      _statsLine(provider),
                      const SizedBox(height: 20),
                      if (_loading)
                        _loadingBox()
                      else if (_error != null)
                        _errorBox(_error!)
                      else if (_report != null)
                        _ReportBody(report: _report!)
                      else
                        _emptyHint(provider.totalEntries),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                _generateButton(provider.totalEntries),
              ],
            ),
          ),
        ),
    );
  }

  Widget _caveat() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.goldenHour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.goldenHour.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppTheme.goldenHour, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI 분석은 교사의 이해를 돕는 참고 자료이며, 의학적·심리학적 진단이 아닙니다. '
              '아이에 대한 판단은 교사의 직접 관찰과 함께 신중히 해주세요.',
              style: TextStyle(
                  color: AppTheme.goldenHour, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsLine(AppProvider p) {
    final counts = p.emotionCounts(days: 30);
    return Text(
      '최근 30일 · 총 ${p.totalEntries}개 기록 · 연속 ${p.streakDays}일 · 감정 종류 ${counts.length}가지',
      style: const TextStyle(color: AppTheme.textSubtle, fontSize: 12),
    );
  }

  Widget _emptyHint(int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const Text('📋', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
                total == 0
                    ? '아직 기록이 없어요.\n일기를 작성한 뒤 분석할 수 있어요.'
                    : '아래 버튼을 눌러 AI 분석을 시작하세요.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSubtle, fontSize: 14, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _loadingBox() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(AppTheme.softMoss)),
            ),
            SizedBox(height: 16),
            Text('AI가 기록을 살펴보고 있어요...',
                style: TextStyle(color: AppTheme.textSubtle, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE57373).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(msg,
          style: const TextStyle(
              color: AppTheme.dawnGlow, fontSize: 14, height: 1.5)),
    );
  }

  Widget _generateButton(int total) {
    final disabled = _loading || total == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: GestureDetector(
        onTap: disabled ? null : _generate,
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.softMoss, AppTheme.lightForest]),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: Text(_report == null ? 'AI 리포트 생성' : '다시 분석하기',
                  style: const TextStyle(
                      color: AppTheme.softCloud,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}

/// AI가 돌려준 마크다운풍 텍스트를 가볍게 렌더링 (## 헤더 굵게).
class _ReportBody extends StatelessWidget {
  final String report;
  const _ReportBody({required this.report});

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
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(line.substring(3).trim(),
              style: const TextStyle(
                  color: AppTheme.softMoss,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ));
      } else if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(line.substring(2).trim(),
              style: const TextStyle(
                  color: AppTheme.dawnGlow,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ));
      } else {
        final clean = line.replaceAll('**', '').replaceFirst(RegExp(r'^[-*]\s*'), '· ');
        widgets.add(Text(clean,
            style: const TextStyle(
                color: AppTheme.textOnDark, fontSize: 14, height: 1.7)));
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.softMoss.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }
}
