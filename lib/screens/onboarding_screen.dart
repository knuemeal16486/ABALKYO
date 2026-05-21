import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/time_weather_theme.dart';
import '../widgets/seed_picker.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameCtrl = TextEditingController();
  PlantType? _selected;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canStart =>
      _nameCtrl.text.trim().isNotEmpty && _selected != null;

  void _start() {
    context
        .read<AppProvider>()
        .completeOnboarding(_nameCtrl.text, _selected!);
  }

  @override
  Widget build(BuildContext context) {
    final sky = TimeWeatherTheme.get();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 시간대별 따뜻한 배경
          AnimatedContainer(
            duration: const Duration(seconds: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: sky.warmColors,
              ),
            ),
          ),

          // 글로우 오브 1
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  sky.glowColor.withValues(alpha: 0.22),
                  sky.glowColor.withValues(alpha: 0.06),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // 글로우 오브 2
          Positioned(
            bottom: -40,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  sky.accentColor.withValues(alpha: 0.18),
                  sky.accentColor.withValues(alpha: 0.04),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 타이틀 영역
                  Center(
                    child: Column(
                      children: [
                        const Text('🌿', style: TextStyle(fontSize: 64))
                            .animate()
                            .scale(
                                begin: const Offset(0.5, 0.5),
                                end: const Offset(1, 1),
                                duration: 700.ms,
                                curve: Curves.elasticOut),
                        const SizedBox(height: 16),
                        const Text(
                          '마음 정원에\n오신 걸 환영해요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.dawnGlow,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              height: 1.3),
                        ).animate(delay: 200.ms).fadeIn(duration: 600.ms),
                        const SizedBox(height: 10),
                        Text(
                          '매일의 감정을 기록하면 나만의 식물이 자라나요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.textSubtle,
                              fontSize: 14,
                              height: 1.6),
                        )
                            .animate(delay: 350.ms)
                            .fadeIn(duration: 600.ms),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 이름 입력
                  Text('이름이 무엇인가요?',
                      style: TextStyle(
                          color: AppTheme.textSubtle,
                          fontSize: 13,
                          fontWeight: FontWeight.w600))
                      .animate(delay: 500.ms)
                      .fadeIn(duration: 500.ms),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20)),
                    ),
                    child: TextField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.done,
                      maxLength: 12,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                          color: AppTheme.dawnGlow, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: '예) 김초롱',
                        counterText: '',
                        hintStyle: TextStyle(
                            color:
                                AppTheme.textSubtle.withValues(alpha: 0.6)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                    ),
                  )
                      .animate(delay: 600.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 28),

                  // 씨앗 선택
                  Text('어떤 씨앗을 심을까요?',
                      style: TextStyle(
                          color: AppTheme.textSubtle,
                          fontSize: 13,
                          fontWeight: FontWeight.w600))
                      .animate(delay: 700.ms)
                      .fadeIn(duration: 500.ms),
                  const SizedBox(height: 12),
                  SeedPicker(
                    selected: _selected,
                    onSelect: (t) => setState(() => _selected = t),
                  )
                      .animate(delay: 800.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 36),

                  // 시작 버튼
                  AnimatedOpacity(
                    opacity: _canStart ? 1 : 0.4,
                    duration: const Duration(milliseconds: 300),
                    child: GestureDetector(
                      onTap: _canStart ? _start : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              sky.glowColor.withValues(alpha: 0.9),
                              sky.accentColor.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: sky.glowColor.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '정원 시작하기',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  )
                      .animate(delay: 900.ms)
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: 0.3, end: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
