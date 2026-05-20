import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🌱', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 12),
                  const Text('마음 정원에 오신 걸 환영해요',
                      style: TextStyle(
                          color: AppTheme.dawnGlow,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('매일의 감정을 기록하면 나만의 식물이 자라나요.',
                      style: TextStyle(
                          color: AppTheme.textSubtle,
                          fontSize: 14,
                          height: 1.5)),
                  const SizedBox(height: 32),

                  // 이름
                  Text('이름이 무엇인가요?',
                      style: TextStyle(
                          color: AppTheme.textSubtle,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
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
                            color: AppTheme.textSubtle.withValues(alpha: 0.6)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 씨앗 선택
                  Text('어떤 씨앗을 심을까요?',
                      style: TextStyle(
                          color: AppTheme.textSubtle,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SeedPicker(
                    selected: _selected,
                    onSelect: (t) => setState(() => _selected = t),
                  ),
                  const SizedBox(height: 32),

                  // 시작 버튼
                  Opacity(
                    opacity: _canStart ? 1 : 0.4,
                    child: GestureDetector(
                      onTap: _canStart ? _start : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.softMoss, AppTheme.lightForest],
                          ),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Center(
                          child: Text('정원 시작하기',
                              style: TextStyle(
                                  color: AppTheme.softCloud,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
