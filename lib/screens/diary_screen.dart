import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'ai_diary_result_screen.dart';

class DiaryScreen extends StatefulWidget {
  final VoidCallback? onSubmit;
  const DiaryScreen({super.key, this.onSubmit});
  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  String? _emotion;
  final _textCtrl = TextEditingController();
  XFile? _photo;
  final _picker = ImagePicker();
  bool _saving = false;

  // 아이들이 쓸 거리를 떠올리도록 돕는 글감 (날짜별로 고정)
  static const List<String> _prompts = [
    '오늘 가장 기억에 남는 순간은 언제였나요?',
    '오늘 누구와 어떤 이야기를 나눴나요?',
    '오늘 새롭게 알게 된 것이 있나요?',
    '오늘 나에게 칭찬해주고 싶은 일은 무엇인가요?',
    '오늘 고마웠던 사람이나 일이 있었나요?',
    '오늘 마음이 가장 크게 움직인 순간은?',
    '내일은 어떤 하루가 되면 좋겠나요?',
    '오늘 힘들었던 일을 누군가에게 말한다면 뭐라고 할까요?',
  ];

  String get _todayPrompt =>
      _prompts[DateTime.now().day % _prompts.length];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final img =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img != null) setState(() => _photo = img);
  }

  Future<void> _submit() async {
    if (_emotion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('오늘 기분을 먼저 선택해주세요 😊'),
          backgroundColor: AppTheme.midForest,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<AppProvider>();
    final emotion = _emotion!;
    final text = _textCtrl.text;
    final photoPath = _photo?.path;

    final entry = await provider.addDiaryEntry(
      emotion,
      text,
      sourcePhotoPath: photoPath,
    );
    if (!mounted) return;
    _textCtrl.clear();
    setState(() {
      _emotion = null;
      _photo = null;
      _saving = false;
    });

    // AI가 설정되어 있으면 그림일기 결과 화면을 보여준 뒤 정원으로 복귀
    if (provider.aiEnabled) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AiDiaryResultScreen(
          entryId: entry.id,
          childName: provider.studentName,
          emotionLabel: Emotions.labelOf(emotion),
          diaryText: text,
          childPhotoPath: entry.imageUrl,
        ),
      ));
    }
    widget.onSubmit?.call();
  }

  @override
  Widget build(BuildContext context) {
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
                        onTap: () => widget.onSubmit?.call(),
                        child: const Icon(Icons.arrow_back_ios_rounded,
                            color: AppTheme.dawnGlow, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text('오늘의 마음 일기',
                          style: TextStyle(
                              color: AppTheme.dawnGlow,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 감정 선택
                        const _SectionLabel(label: '오늘 기분이 어때요?'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: Emotions.all.map((e) {
                            final sel = _emotion == e.id;
                            return GestureDetector(
                              onTap: () => setState(() => _emotion = e.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? AppTheme.softMoss.withValues(alpha: 0.4)
                                      : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: sel
                                        ? AppTheme.softMoss
                                        : Colors.white.withValues(alpha: 0.12),
                                    width: sel ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(e.icon,
                                        style: const TextStyle(fontSize: 22)),
                                    const SizedBox(width: 6),
                                    Text(e.label,
                                        style: TextStyle(
                                            color: sel
                                                ? AppTheme.dawnGlow
                                                : AppTheme.textSubtle,
                                            fontWeight: sel
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            fontSize: 14)),
                                  ],
                                ),
                              ).animate(target: sel ? 1 : 0).scaleXY(
                                  begin: 1.0, end: 1.05, duration: 200.ms),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 28),

                        // 사진 추가 (한 장)
                        const _SectionLabel(label: '오늘 찍은 사진을 추가해요 (선택)'),
                        const SizedBox(height: 12),
                        _PhotoPicker(
                          photo: _photo,
                          onPick: _pickPhoto,
                          onRemove: () => setState(() => _photo = null),
                        ),

                        const SizedBox(height: 28),

                        // 오늘의 일기
                        const _SectionLabel(label: '오늘 있었던 일을 적어요'),
                        const SizedBox(height: 8),
                        _PromptChip(text: _todayPrompt),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10)),
                          ),
                          child: TextField(
                            controller: _textCtrl,
                            maxLines: 7,
                            style: const TextStyle(
                                color: AppTheme.dawnGlow,
                                fontSize: 15,
                                height: 1.7),
                            decoration: InputDecoration(
                              hintText:
                                  '오늘 하루 어떤 일이 있었나요?\n기쁜 일, 슬픈 일, 무슨 일이든 괜찮아요 🌿',
                              hintStyle: TextStyle(
                                  color: AppTheme.textSubtle
                                      .withValues(alpha: 0.6),
                                  fontSize: 14),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(18),
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // 제출 버튼
                        GestureDetector(
                          onTap: _saving ? null : _submit,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.softMoss,
                                  AppTheme.lightForest
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                    color: AppTheme.softMoss
                                        .withValues(alpha: 0.5),
                                    blurRadius: 20),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_saving)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            AppTheme.softCloud)),
                                  )
                                else
                                  const Text('💧',
                                      style: TextStyle(fontSize: 22)),
                                const SizedBox(width: 10),
                                Text(_saving ? '저장하는 중...' : '기록하고 식물에 물 주기',
                                    style: const TextStyle(
                                        color: AppTheme.softCloud,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
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

class _PhotoPicker extends StatelessWidget {
  final XFile? photo;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  const _PhotoPicker(
      {required this.photo, required this.onPick, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppTheme.softMoss.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_photo_alternate_rounded,
                  color: AppTheme.softMoss, size: 32),
              const SizedBox(height: 4),
              Text('사진 추가',
                  style: TextStyle(
                      color: AppTheme.textSubtle, fontSize: 11)),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        Container(
          width: 110,
          height: 110,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: Image.file(File(photo!.path), fit: BoxFit.cover),
        ).animate().scale(
            begin: const Offset(0.7, 0.7),
            duration: 300.ms,
            curve: Curves.elasticOut),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 15),
            ),
          ),
        ),
      ],
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String text;
  const _PromptChip({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.goldenHour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.goldenHour.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppTheme.goldenHour,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            color: AppTheme.textSubtle,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3));
  }
}
