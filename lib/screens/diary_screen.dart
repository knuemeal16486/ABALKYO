import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../services/ai_service.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
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

  // 날씨
  WeatherInfo? _weatherInfo;
  bool _weatherLoading = true;

  // 사진 AI 분석
  List<String> _photoPrompts = [];
  bool _photoAnalyzing = false;

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

  String get _todayPrompt => _prompts[DateTime.now().day % _prompts.length];

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    final info = await WeatherService.fetch();
    if (mounted) {
      setState(() {
        _weatherInfo = info;
        _weatherLoading = false;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final img =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;
    setState(() {
      _photo = img;
      _photoPrompts = [];
    });
    final provider = context.read<AppProvider>();
    if (provider.aiEnabled) {
      setState(() => _photoAnalyzing = true);
      final prompts = await AiService(provider.apiKey).analyzePhotoForPrompts(img.path);
      if (mounted) {
        setState(() {
          _photoPrompts = prompts ?? [];
          _photoAnalyzing = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_emotion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('오늘 기분을 먼저 선택해주세요 😊'),
          backgroundColor: AppTheme.midForest,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      _photoPrompts = [];
      _saving = false;
    });

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

  // 날씨 추천 감정 칩 탭 → 감정 선택
  void _onWeatherEmotionTap(String id) => setState(() => _emotion = id);

  // 사진 추천 질문 탭 → 텍스트 필드 시작 문구로 삽입
  void _onPromptTap(String text) {
    final cur = _textCtrl.text;
    if (cur.isEmpty) {
      _textCtrl.text = '$text\n';
    } else {
      _textCtrl.text = '$cur\n$text\n';
    }
    _textCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _textCtrl.text.length));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WarmBackground(
        child: SafeArea(
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
                        // ── 날씨 힌트 카드 ──────────────────────────────────
                        _WeatherCard(
                          loading: _weatherLoading,
                          info: _weatherInfo,
                          selectedEmotion: _emotion,
                          onEmotionTap: _onWeatherEmotionTap,
                        ),

                        const SizedBox(height: 20),

                        // ── 감정 선택 ────────────────────────────────────────
                        const _SectionLabel(label: '오늘 기분이 어때요?'),
                        const SizedBox(height: 12),
                        _EmotionGrid(
                          selected: _emotion,
                          suggestedIds: _weatherInfo?.suggestedEmotions ?? [],
                          onSelect: (id) => setState(() => _emotion = id),
                        ),

                        const SizedBox(height: 28),

                        // ── 사진 추가 ────────────────────────────────────────
                        const _SectionLabel(label: '오늘 찍은 사진을 추가해요 (선택)'),
                        const SizedBox(height: 12),
                        _PhotoPicker(
                          photo: _photo,
                          onPick: _pickPhoto,
                          onRemove: () => setState(() {
                            _photo = null;
                            _photoPrompts = [];
                          }),
                        ),

                        // ── 사진 AI 분석 결과 ────────────────────────────────
                        if (_photoAnalyzing) ...[
                          const SizedBox(height: 16),
                          const _PhotoAnalyzingCard(),
                        ] else if (_photoPrompts.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _PhotoPromptSection(
                            prompts: _photoPrompts,
                            onTap: _onPromptTap,
                          ),
                        ],

                        const SizedBox(height: 28),

                        // ── 오늘의 일기 텍스트 ───────────────────────────────
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

                        // ── 제출 버튼 ────────────────────────────────────────
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
                                  ]),
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
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 날씨 힌트 카드
// ══════════════════════════════════════════════════════════════════════════════
class _WeatherCard extends StatelessWidget {
  final bool loading;
  final WeatherInfo? info;
  final String? selectedEmotion;
  final ValueChanged<String> onEmotionTap;

  const _WeatherCard({
    required this.loading,
    required this.info,
    required this.selectedEmotion,
    required this.onEmotionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: _deco(),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                valueColor:
                    AlwaysStoppedAnimation(AppTheme.morningDew),
              ),
            ),
            const SizedBox(width: 12),
            Text('오늘 날씨를 불러오는 중…',
                style: TextStyle(
                    color: AppTheme.textSubtle.withValues(alpha: 0.7),
                    fontSize: 13)),
          ],
        ),
      );
    }
    if (info == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _deco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날씨 레이블 행
          Row(
            children: [
              Text(info!.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${info!.label}  ·  ${info!.tempLabel}',
                      style: const TextStyle(
                          color: AppTheme.goldenHour,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('오늘의 날씨',
                      style: TextStyle(
                          color: AppTheme.textSubtle.withValues(alpha: 0.7),
                          fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 힌트 텍스트
          Text(info!.hint,
              style: TextStyle(
                  color: AppTheme.dawnGlow.withValues(alpha: 0.88),
                  fontSize: 13,
                  height: 1.55)),
          const SizedBox(height: 12),
          // 추천 감정 칩
          Row(
            children: [
              Text('이런 날엔  ',
                  style: TextStyle(
                      color: AppTheme.textSubtle.withValues(alpha: 0.65),
                      fontSize: 12)),
              ...info!.suggestedEmotions.map((id) {
                final e = Emotions.byId(id);
                final isSel = selectedEmotion == id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onEmotionTap(id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppTheme.morningDew.withValues(alpha: 0.28)
                            : AppTheme.morningDew.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSel
                              ? AppTheme.morningDew.withValues(alpha: 0.7)
                              : AppTheme.morningDew.withValues(alpha: 0.25),
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(e.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 5),
                          Text(e.label,
                              style: TextStyle(
                                  color: isSel
                                      ? AppTheme.dawnGlow
                                      : AppTheme.textSubtle,
                                  fontSize: 12,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.08, end: 0);
  }

  BoxDecoration _deco() => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.goldenHour.withValues(alpha: 0.20),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// 감정 선택 (날씨 추천 강조 포함)
// ══════════════════════════════════════════════════════════════════════════════
class _EmotionGrid extends StatelessWidget {
  final String? selected;
  final List<String> suggestedIds;
  final ValueChanged<String> onSelect;

  const _EmotionGrid({
    required this.selected,
    required this.suggestedIds,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: Emotions.all.map((e) {
        final sel = selected == e.id;
        final suggested = suggestedIds.contains(e.id) && !sel;
        return GestureDetector(
          onTap: () => onSelect(e.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: sel
                  ? AppTheme.softMoss.withValues(alpha: 0.4)
                  : suggested
                      ? AppTheme.morningDew.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sel
                    ? AppTheme.softMoss
                    : suggested
                        ? AppTheme.morningDew.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.12),
                width: sel || suggested ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 6),
                Text(e.label,
                    style: TextStyle(
                        color: sel
                            ? AppTheme.dawnGlow
                            : suggested
                                ? AppTheme.morningDew
                                : AppTheme.textSubtle,
                        fontWeight:
                            sel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14)),
              ],
            ),
          ).animate(target: sel ? 1 : 0).scaleXY(
              begin: 1.0, end: 1.05, duration: 200.ms),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 사진 분석 중 카드
// ══════════════════════════════════════════════════════════════════════════════
class _PhotoAnalyzingCard extends StatelessWidget {
  const _PhotoAnalyzingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.blossomPink.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 1.8,
                valueColor: AlwaysStoppedAnimation(AppTheme.blossomPink)),
          ),
          const SizedBox(width: 12),
          Text('📸 사진을 살펴보는 중이에요…',
              style: TextStyle(
                  color: AppTheme.textSubtle.withValues(alpha: 0.8),
                  fontSize: 13)),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 사진 기반 AI 추천 주제 섹션
// ══════════════════════════════════════════════════════════════════════════════
class _PhotoPromptSection extends StatelessWidget {
  final List<String> prompts;
  final ValueChanged<String> onTap;

  const _PhotoPromptSection({required this.prompts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('📸', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text('사진을 보고 이야기해봐요',
                style: TextStyle(
                    color: AppTheme.blossomPink.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
          ],
        ),
        const SizedBox(height: 8),
        ...prompts.asMap().entries.map((entry) {
          final delay = entry.key * 80;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => onTap(entry.value),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AppTheme.blossomPink.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.blossomPink.withValues(alpha: 0.28)),
                ),
                child: Row(
                  children: [
                    Text('✨', style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(entry.value,
                          style: TextStyle(
                              color: AppTheme.blossomPink.withValues(alpha: 0.9),
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_note_rounded,
                        color: AppTheme.blossomPink.withValues(alpha: 0.45),
                        size: 16),
                  ],
                ),
              ),
            ).animate(delay: delay.ms).fadeIn(duration: 350.ms).slideX(begin: 0.06, end: 0),
          );
        }),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('✏️ 질문을 탭하면 일기 시작 문장으로 넣어드려요',
              style: TextStyle(
                  color: AppTheme.textSubtle.withValues(alpha: 0.5),
                  fontSize: 11)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 공통 위젯
// ══════════════════════════════════════════════════════════════════════════════
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
            border:
                Border.all(color: AppTheme.softMoss.withValues(alpha: 0.4)),
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
          decoration:
              BoxDecoration(borderRadius: BorderRadius.circular(16)),
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
              child:
                  const Icon(Icons.close, color: Colors.white, size: 15),
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
        border:
            Border.all(color: AppTheme.goldenHour.withValues(alpha: 0.3)),
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
