import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_models.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import 'app_background.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DiaryWizard — 4-step child-friendly diary entry wizard
//   Step 0: 기분 선택   Step 1: 가이드 질문   Step 2: 일기 쓰기   Step 3: 사진
// ─────────────────────────────────────────────────────────────────────────────

class DiaryWizard extends StatefulWidget {
  final void Function(String emotion, String text, String? photoPath) onComplete;
  final VoidCallback onCancel;

  const DiaryWizard({
    super.key,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<DiaryWizard> createState() => _DiaryWizardState();
}

class _DiaryWizardState extends State<DiaryWizard>
    with SingleTickerProviderStateMixin {
  // ── Navigation ──────────────────────────────────────────────────────────────
  final PageController _pageController =
      PageController(initialPage: 0, keepPage: true);
  int _currentStep = 0;

  // ── Step 0 state ─────────────────────────────────────────────────────────
  String? _selectedEmotion; // EmotionInfo.id

  // ── Step 1 state ─────────────────────────────────────────────────────────
  static const List<String> _allPrompts = [
    '오늘 가장 재미있었던 일은 무엇이었나요? 🎉',
    '오늘 누군가에게 고마운 마음이 들었나요? 💛',
    '오늘 새롭게 배운 게 있었나요? 📚',
    '오늘 가장 행복했던 순간을 떠올려봐요 😊',
    '오늘 힘들었던 일이 있었나요? 어떻게 했나요? 💪',
    '오늘 친구들이랑 무슨 일이 있었나요? 👫',
    '오늘 집에서 가족이랑 뭘 했나요? 🏠',
    '오늘 맛있는 걸 먹었나요? 어떤 맛이었나요? 🍽️',
    '오늘 하고 싶었지만 못 한 게 있었나요? 🌙',
    '내일 하고 싶은 일이 있나요? 🌈',
    '오늘 내 마음이 꽃이라면 어떤 꽃이었을까요? 🌸',
    '오늘 제일 오래 기억에 남을 것 같은 장면은? 📸',
  ];

  WeatherInfo? _weatherInfo;
  bool _weatherLoading = true;
  String? _selectedQuestion; // question text chosen by user

  // ── Step 2 state ─────────────────────────────────────────────────────────
  final TextEditingController _diaryController = TextEditingController();
  final FocusNode _diaryFocusNode = FocusNode();
  bool _diaryPrefilled = false; // guard: prefill only once

  // ── Step 3 state ─────────────────────────────────────────────────────────
  String? _photoPath;
  final ImagePicker _picker = ImagePicker();

  // ── Next-button bounce animation ──────────────────────────────────────────
  late final AnimationController _nextBtnAnim;
  late final Animation<double> _nextBtnScale;

  @override
  void initState() {
    super.initState();
    _nextBtnAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 1.0,
    );
    _nextBtnScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _nextBtnAnim, curve: Curves.easeOut),
    );
    _loadWeather();
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

  @override
  void dispose() {
    _pageController.dispose();
    _diaryController.dispose();
    _diaryFocusNode.dispose();
    _nextBtnAnim.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// 3 prompts rotated by day-of-week (Mon=0…Sun=6).
  List<String> get _todayPrompts {
    final dayIndex = DateTime.now().weekday - 1; // 0-based
    final base = (dayIndex * 3) % _allPrompts.length;
    return [
      _allPrompts[base % _allPrompts.length],
      _allPrompts[(base + 1) % _allPrompts.length],
      _allPrompts[(base + 2) % _allPrompts.length],
    ];
  }

  bool get _canProceed => _currentStep != 0 || _selectedEmotion != null;

  void _goNext() {
    FocusScope.of(context).unfocus();
    if (!_canProceed) {
      // Pulse rebuild so hint text animates in if not already visible
      setState(() {});
      return;
    }
    _nextBtnAnim.reverse().then((_) => _nextBtnAnim.forward());
    if (_currentStep < 3) {
      // Prefill diary text on entering step 2 (only once)
      if (_currentStep == 1 && !_diaryPrefilled) {
        _diaryPrefilled = true;
        if (_selectedQuestion != null) {
          _diaryController.text = _selectedQuestion!;
          _diaryController.selection = TextSelection.collapsed(
            offset: _diaryController.text.length,
          );
        }
      }
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _goBack() {
    FocusScope.of(context).unfocus();
    if (_currentStep == 0) {
      widget.onCancel();
    } else {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _skipToWrite() {
    setState(() => _selectedQuestion = null);
    _goNext();
  }

  void _complete() {
    widget.onComplete(
      _selectedEmotion ?? 'calm',
      _diaryController.text.trim(),
      _photoPath,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        setState(() => _photoPath = file.path);
      }
    } catch (_) {
      // Silently ignore permission errors or cancellations
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WarmBackground(
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressDots(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep0(),
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
            // Next button shown for steps 0-2; step 3 has its own CTA buttons
            if (_currentStep < 3) _buildNextButton(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 28),
            style: IconButton.styleFrom(foregroundColor: AppTheme.dawnGlow),
          ),
          const Spacer(),
          Text(
            _stepLabel(),
            style: const TextStyle(
              color: AppTheme.dawnGlow,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // balance back button
        ],
      ),
    );
  }

  String _stepLabel() {
    const labels = [
      '1 / 4  ·  기분 선택',
      '2 / 4  ·  오늘 이야기',
      '3 / 4  ·  일기 쓰기',
      '4 / 4  ·  오늘의 그림',
    ];
    return labels[_currentStep];
  }

  // ── Progress dots ─────────────────────────────────────────────────────────

  Widget _buildProgressDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) {
          final filled = i <= _currentStep;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: filled ? 26 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: filled
                  ? AppTheme.softMoss
                  : Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 0 — 기분 선택 "오늘 기분이 어때?"
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStep0() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Text('🌱', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 10),
          const Text(
            '오늘 기분이 어때?',
            style: TextStyle(
              color: AppTheme.dawnGlow,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            '마음속 감정을 하나 골라봐요 💛',
            style: TextStyle(color: AppTheme.textSubtle, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // 2×4 emotion grid (80 × 80 cards)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: Emotions.all.length, // exactly 8
            itemBuilder: (context, index) {
              final emotion = Emotions.all[index];
              return _EmotionCard(
                emotion: emotion,
                isSelected: _selectedEmotion == emotion.id,
                onTap: () => setState(() => _selectedEmotion = emotion.id),
              );
            },
          ),

          const SizedBox(height: 20),

          // Hint strip: visible when nothing is selected
          AnimatedOpacity(
            opacity: _selectedEmotion == null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: warmCardDeco(
                borderColor: AppTheme.goldenHour.withValues(alpha: 0.5),
                alphaBg: 0.12,
              ),
              child: const Text(
                '감정을 하나 선택해야 다음으로 갈 수 있어요 🌿',
                style: TextStyle(color: AppTheme.goldenHour, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1 — 가이드 질문 "오늘 뭔 일이 있었어?"
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStep1() {
    final prompts = _todayPrompts;
    final weatherKey = _weatherInfo != null
        ? '${_weatherInfo!.emoji} ${_weatherInfo!.hint}'
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          Row(
            children: [
              if (_selectedEmotion != null) ...[
                Text(
                  Emotions.iconOf(_selectedEmotion!),
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 8),
              ],
              const Flexible(
                child: Text(
                  '오늘 뭔 일이 있었어?',
                  style: TextStyle(
                    color: AppTheme.dawnGlow,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '아래 질문 중 하나를 골라봐요. 고르지 않아도 괜찮아요!',
            style: TextStyle(color: AppTheme.textSubtle, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Weather-based suggestion
          if (_weatherLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: warmCardDeco(),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.goldenHour,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      '오늘 날씨를 확인하는 중…',
                      style: TextStyle(
                        color: AppTheme.textSubtle,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_weatherInfo != null && weatherKey != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WeatherSuggestionCard(
                weatherInfo: _weatherInfo!,
                isSelected: _selectedQuestion == weatherKey,
                onTap: () => setState(() {
                  _selectedQuestion =
                      _selectedQuestion == weatherKey ? null : weatherKey;
                }),
              ),
            ),

          // 3 daily prompts
          ...prompts.map(
            (q) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QuestionCard(
                question: q,
                isSelected: _selectedQuestion == q,
                onTap: () => setState(() {
                  _selectedQuestion = _selectedQuestion == q ? null : q;
                }),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 직접 쓸게요 shortcut
          Center(
            child: TextButton.icon(
              onPressed: _skipToWrite,
              icon: const Text('✏️'),
              label: const Text(
                '직접 쓸게요',
                style: TextStyle(
                  color: AppTheme.textSubtle,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.textSubtle,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2 — 일기 쓰기
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStep2() {
    final emotionIcon =
        _selectedEmotion != null ? Emotions.iconOf(_selectedEmotion!) : '🌱';

    return GestureDetector(
      onTap: () => _diaryFocusNode.unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            Row(
              children: [
                Text(emotionIcon, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    '오늘 일기를 써봐요',
                    style: TextStyle(
                      color: AppTheme.dawnGlow,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Large diary text field
            Container(
              decoration: warmCardDeco(
                borderColor: AppTheme.softMoss.withValues(alpha: 0.45),
                radius: 20,
                alphaBg: 0.13,
              ),
              child: TextField(
                controller: _diaryController,
                focusNode: _diaryFocusNode,
                style: const TextStyle(
                  color: AppTheme.textOnDark,
                  fontSize: 18,
                  height: 1.65,
                ),
                decoration: InputDecoration(
                  hintText:
                      '오늘 하루 어떤 일이 있었는지 적어봐요.\n짧아도 괜찮아요! 🌿',
                  hintStyle: TextStyle(
                    color: AppTheme.textSubtle.withValues(alpha: 0.7),
                    fontSize: 16,
                    height: 1.65,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(18),
                ),
                minLines: 4,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
              ),
            ),

            const SizedBox(height: 16),

            // Quick emoji insert row
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: warmCardDeco(alphaBg: 0.08, radius: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '이모지 추가하기',
                    style: TextStyle(
                      color: AppTheme.textSubtle,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['😊', '🌟', '💖', '🎉', '😢', '❤️']
                        .map(
                          (e) => GestureDetector(
                            onTap: () => _insertEmoji(e),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _insertEmoji(String emoji) {
    final ctrl = _diaryController;
    final text = ctrl.text;
    final sel = ctrl.selection;
    final insertAt = (sel.isValid && sel.baseOffset >= 0)
        ? sel.baseOffset
        : text.length;
    final newText = text.substring(0, insertAt) +
        emoji +
        text.substring(insertAt);
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertAt + emoji.length),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 3 — 오늘의 그림 (사진)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Text('🎨', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 10),
          const Text(
            '오늘 사진을 추가해볼까요?',
            style: TextStyle(
              color: AppTheme.dawnGlow,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            '사진이 없어도 괜찮아요 💛',
            style: TextStyle(color: AppTheme.textSubtle, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Photo preview (when a photo is selected)
          if (_photoPath != null) ...[
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    File(_photoPath!),
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _photoPath = null),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close,
                        size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '사진이 선택되었어요! 변경하려면 아래를 눌러봐요.',
              style: TextStyle(color: AppTheme.textSubtle, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
          ],

          // 📸 사진 찍기
          _PhotoOptionButton(
            emoji: '📸',
            label: '사진 찍기',
            onTap: () => _pickImage(ImageSource.camera),
          ),
          const SizedBox(height: 14),

          // 🖼️ 갤러리에서 선택
          _PhotoOptionButton(
            emoji: '🖼️',
            label: '갤러리에서 선택',
            onTap: () => _pickImage(ImageSource.gallery),
          ),
          const SizedBox(height: 14),

          // 건너뛰기 (proceeds without photo)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _complete,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSubtle,
                side: BorderSide(
                    color: AppTheme.textSubtle.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                '건너뛰기 →',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 완료 button (always visible; highlighted when photo is attached)
          SizedBox(
            width: double.infinity,
            child: _GradientButton(
              label: _photoPath != null ? '완료! 🌱' : '사진 없이 완료 🌱',
              onTap: _complete,
            ),
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // ── Bottom "다음" button (steps 0-2) ─────────────────────────────────────

  Widget _buildNextButton() {
    final label = (_currentStep == 1 && _selectedQuestion != null)
        ? '이걸로 쓸게요 ✍️'
        : '다음 →';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: ScaleTransition(
        scale: _nextBtnScale,
        child: SizedBox(
          width: double.infinity,
          child: _GradientButton(
            label: label,
            onTap: _canProceed ? _goNext : () => setState(() {}),
            muted: !_canProceed,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmotionCard  (80 × 80 dp, 2×4 grid)
// ─────────────────────────────────────────────────────────────────────────────

class _EmotionCard extends StatelessWidget {
  final EmotionInfo emotion;
  final bool isSelected;
  final VoidCallback onTap;

  const _EmotionCard({
    required this.emotion,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        // Fixed 80 × 80 — GridView childAspectRatio=1.0 handles this,
        // but explicit constraints guard against unusual screen ratios.
        constraints: const BoxConstraints(
          minWidth: 72,
          minHeight: 72,
          maxWidth: 96,
          maxHeight: 96,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.softMoss.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppTheme.softMoss
                : Colors.white.withValues(alpha: 0.18),
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.softMoss.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emotion.icon, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 4),
            Text(
              emotion.label,
              style: TextStyle(
                color: isSelected ? AppTheme.dawnGlow : AppTheme.textSubtle,
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuestionCard
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final String question;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuestionCard({
    required this.question,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.goldenHour.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppTheme.goldenHour
                : Colors.white.withValues(alpha: 0.18),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                question,
                style: TextStyle(
                  color: isSelected ? AppTheme.dawnGlow : AppTheme.textSubtle,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.goldenHour,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WeatherSuggestionCard
// ─────────────────────────────────────────────────────────────────────────────

class _WeatherSuggestionCard extends StatelessWidget {
  final WeatherInfo weatherInfo;
  final bool isSelected;
  final VoidCallback onTap;

  const _WeatherSuggestionCard({
    required this.weatherInfo,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.blossomPink.withValues(alpha: 0.18)
              : AppTheme.morningDew.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppTheme.blossomPink
                : AppTheme.morningDew.withValues(alpha: 0.35),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weather icon + temperature
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(weatherInfo.emoji,
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 2),
                Text(
                  weatherInfo.tempLabel,
                  style: const TextStyle(
                    color: AppTheme.morningDew,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘 날씨: ${weatherInfo.label}',
                    style: const TextStyle(
                      color: AppTheme.dawnGlow,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    weatherInfo.hint,
                    style: const TextStyle(
                      color: AppTheme.textSubtle,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.blossomPink,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PhotoOptionButton
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoOptionButton extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _PhotoOptionButton({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.dawnGlow,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GradientButton  — primary CTA with softMoss gradient
// ─────────────────────────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool muted;

  const _GradientButton({
    required this.label,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: muted
                ? [
                    AppTheme.softMoss.withValues(alpha: 0.35),
                    AppTheme.softMoss.withValues(alpha: 0.20),
                  ]
                : [
                    AppTheme.softMoss,
                    AppTheme.softMoss.withValues(alpha: 0.75),
                  ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: muted
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.softMoss.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: muted ? AppTheme.textSubtle : AppTheme.dawnGlow,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}
