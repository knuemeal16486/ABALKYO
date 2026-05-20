import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'teacher_report_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final df = DateFormat('M월 d일', 'ko_KR');

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
                      const Text('설정',
                          style: TextStyle(
                              color: AppTheme.dawnGlow,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _SectionTitle('내 이름'),
                      _NameTile(name: provider.studentName),
                      const SizedBox(height: 24),

                      _SectionTitle('교사용 AI 설정'),
                      _ApiKeyTile(hasKey: provider.aiEnabled),
                      const SizedBox(height: 12),
                      _ReportTile(enabled: provider.aiEnabled),
                      const SizedBox(height: 24),

                      _SectionTitle('정원 도감 (다 키운 식물)'),
                      _CollectionCard(provider: provider, df: df),
                      const SizedBox(height: 24),

                      _SectionTitle('마음 정원 소개'),
                      _InfoCard(),
                      const SizedBox(height: 24),

                      _SectionTitle('다음 사람을 위해'),
                      _ResetTile(),
                      const SizedBox(height: 40),
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
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.textSubtle,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      );
}

BoxDecoration _cardDeco() => BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.softMoss.withValues(alpha: 0.2)),
    );

class _NameTile extends StatelessWidget {
  final String name;
  const _NameTile({required this.name});

  void _edit(BuildContext context) {
    final ctrl = TextEditingController(text: name);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.midForest,
        title: const Text('이름 바꾸기',
            style: TextStyle(color: AppTheme.dawnGlow)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 12,
          style: const TextStyle(color: AppTheme.dawnGlow),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '이름',
            hintStyle: TextStyle(color: AppTheme.textSubtle),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('취소',
                  style: TextStyle(color: AppTheme.textSubtle))),
          TextButton(
              onPressed: () {
                context.read<AppProvider>().setStudentName(ctrl.text);
                Navigator.pop(dialogCtx);
              },
              child: const Text('저장',
                  style: TextStyle(color: AppTheme.softMoss))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _edit(context),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDeco(),
        child: Row(
          children: [
            Expanded(
              child: Text(name.isEmpty ? '이름을 정해주세요' : name,
                  style: TextStyle(
                      color:
                          name.isEmpty ? AppTheme.textSubtle : AppTheme.dawnGlow,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.edit_rounded, color: AppTheme.softMoss, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ApiKeyTile extends StatelessWidget {
  final bool hasKey;
  const _ApiKeyTile({required this.hasKey});

  void _edit(BuildContext context) {
    final ctrl =
        TextEditingController(text: context.read<AppProvider>().apiKey);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.midForest,
        title: const Text('Gemini API 키',
            style: TextStyle(color: AppTheme.dawnGlow, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI 그림일기와 마음 리포트를 사용하려면 키가 필요해요. '
              'Google AI Studio(aistudio.google.com/app/apikey)에서 무료로 발급할 수 있어요. '
              '키는 이 기기에만 저장됩니다.',
              style: TextStyle(
                  color: AppTheme.textSubtle, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              obscureText: true,
              style: const TextStyle(color: AppTheme.dawnGlow, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'API 키 붙여넣기',
                hintStyle: TextStyle(color: AppTheme.textSubtle),
              ),
            ),
          ],
        ),
        actions: [
          if (context.read<AppProvider>().aiEnabled)
            TextButton(
                onPressed: () {
                  context.read<AppProvider>().setApiKey('');
                  Navigator.pop(dialogCtx);
                },
                child: const Text('키 삭제',
                    style: TextStyle(color: Color(0xFFE57373)))),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('취소',
                  style: TextStyle(color: AppTheme.textSubtle))),
          TextButton(
              onPressed: () {
                context.read<AppProvider>().setApiKey(ctrl.text);
                Navigator.pop(dialogCtx);
              },
              child: const Text('저장',
                  style: TextStyle(color: AppTheme.softMoss))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _edit(context),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDeco(),
        child: Row(
          children: [
            Icon(hasKey ? Icons.check_circle_rounded : Icons.key_rounded,
                color: hasKey ? AppTheme.softMoss : AppTheme.textSubtle,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hasKey ? 'AI 연결됨' : 'API 키 미설정',
                      style: const TextStyle(
                          color: AppTheme.dawnGlow,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(hasKey ? '그림일기·리포트 사용 가능' : '탭하여 키를 입력하세요',
                      style: const TextStyle(
                          color: AppTheme.textSubtle, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.edit_rounded, color: AppTheme.softMoss, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final bool enabled;
  const _ReportTile({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!enabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('먼저 위에서 Gemini API 키를 입력해주세요.'),
              backgroundColor: AppTheme.midForest,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
          return;
        }
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TeacherReportScreen()));
      },
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDeco(),
          child: Row(
            children: [
              const Text('🧑‍🏫', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('마음 리포트 (교사용 AI 분석)',
                        style: TextStyle(
                            color: AppTheme.dawnGlow,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('정서 요약과 감정 패턴을 AI로 분석',
                        style: const TextStyle(
                            color: AppTheme.textSubtle, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSubtle, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final AppProvider provider;
  final DateFormat df;
  const _CollectionCard({required this.provider, required this.df});
  @override
  Widget build(BuildContext context) {
    final items = provider.collection;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(),
      child: items.isEmpty
          ? Row(
              children: [
                const Text('🌱', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('아직 다 키운 식물이 없어요.\n매일 기록하며 첫 식물을 키워보세요!',
                      style: TextStyle(
                          color: AppTheme.textSubtle,
                          fontSize: 13,
                          height: 1.5)),
                ),
              ],
            )
          : Wrap(
              spacing: 14,
              runSpacing: 14,
              children: items
                  .map((h) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(h.species.emoji,
                              style: const TextStyle(fontSize: 34)),
                          const SizedBox(height: 4),
                          Text(df.format(h.harvestedAt),
                              style: const TextStyle(
                                  color: AppTheme.textSubtle, fontSize: 11)),
                        ],
                      ))
                  .toList(),
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '매일의 감정을 솔직하게 기록하면 나만의 식물이 자라나요. '
            '기쁨도 슬픔도 모두 식물을 키우는 소중한 거름이 됩니다. '
            '슬프거나 힘든 날엔 따뜻한 비가 내려 식물을 더 보살펴줘요.',
            style: TextStyle(
                color: AppTheme.textOnDark, fontSize: 13, height: 1.7),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.lock_rounded,
                  color: AppTheme.softMoss, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '모든 기록과 사진은 이 기기에만 저장되며, 외부로 전송되지 않아요.',
                  style: TextStyle(
                      color: AppTheme.textSubtle, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResetTile extends StatelessWidget {
  void _confirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.midForest,
        title: const Text('정원을 초기화할까요?',
            style: TextStyle(color: AppTheme.dawnGlow, fontSize: 18)),
        content: Text(
          '모든 일기와 사진, 키우던 식물이 사라지고 처음 화면으로 돌아가요. '
          '여러 친구가 함께 쓰는 태블릿이라면, 다음 친구를 위해 사용하세요. '
          '이 작업은 되돌릴 수 없어요.',
          style: TextStyle(
              color: AppTheme.textSubtle, fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('취소',
                  style: TextStyle(color: AppTheme.textSubtle))),
          TextButton(
              onPressed: () {
                context.read<AppProvider>().resetAll();
                // 온보딩으로 돌아가도록 모든 화면 pop
                Navigator.of(dialogCtx).popUntil((r) => r.isFirst);
              },
              child: const Text('초기화',
                  style: TextStyle(
                      color: Color(0xFFE57373), fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirm(context),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFE57373).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE57373).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.restart_alt_rounded,
                color: Color(0xFFE57373), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('새로 시작하기 (정원 초기화)',
                  style: TextStyle(
                      color: AppTheme.textOnDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
