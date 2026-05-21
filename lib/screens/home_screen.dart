import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/time_weather_theme.dart';
import '../widgets/animated_plant_widget.dart';
import '../widgets/plant_view.dart';
import '../widgets/seed_picker.dart';
import 'diary_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final PageController _page = PageController();

  void _toDiary() => _page.animateToPage(1,
      duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
  void _toPlant() => _page.animateToPage(0,
      duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _page,
        physics: const BouncingScrollPhysics(),
        children: [
          _PlantTab(onDiaryTap: _toDiary),
          DiaryScreen(onSubmit: _toPlant),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 식물 탭: 전체 화면 힐링 뷰
// ══════════════════════════════════════════════════════════════════════════════
class _PlantTab extends StatelessWidget {
  final VoidCallback onDiaryTap;
  const _PlantTab({required this.onDiaryTap});

  String _title(String name) =>
      name.isEmpty ? '나의 마음 정원' : '$name의 마음 정원';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isRaining = provider.isRaining;
    final plant = provider.currentPlant;
    final sky = TimeWeatherTheme.get(rain: isRaining);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 시간대별 파스텔 배경
        AnimatedContainer(
          duration: const Duration(seconds: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: sky.colors,
            ),
          ),
        ),

        // 2. 파티클
        Positioned.fill(
            child: IgnorePointer(
                child: SkyParticles(color: sky.particleColor))),

        // 3. 비 레이어
        if (isRaining)
          Positioned.fill(child: IgnorePointer(child: _RainLayer())),

        // 4. 하단 그라운드 그라데이션 (My Oasis 스타일 풍부한 바닥)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  sky.colors.last.withValues(alpha: 0.25),
                  sky.colors.last.withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // 4b. My Oasis 스타일 잔디/바닥 플랫폼 반사광
        Positioned(
          bottom: 155,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 280,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // 5. 메인 콘텐츠
        SafeArea(
          child: Column(
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_title(provider.studentName),
                              style: const TextStyle(
                                color: AppTheme.textDark,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              )),
                          Text('${sky.label}  ·  ${plant.species.name}',
                              style: const TextStyle(
                                  color: AppTheme.textDark, fontSize: 13)),
                        ],
                      ),
                    ),
                    // 개발용 배속 버튼 (디버그 빌드에서만 표시, 릴리스/시연에선 자동 숨김)
                    if (kDebugMode) ...[
                      _IconBtn(
                          icon: Icons.fast_forward_rounded,
                          color: AppTheme.textDark,
                          onTap: () =>
                              context.read<AppProvider>().devAdvanceGrowth()),
                      const SizedBox(width: 8),
                    ],
                    _IconBtn(
                        icon: Icons.calendar_month_rounded,
                        color: AppTheme.textDark,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CalendarScreen()))),
                    const SizedBox(width: 8),
                    _IconBtn(
                        icon: Icons.settings_rounded,
                        color: AppTheme.textDark,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen()))),
                  ],
                ),
              ),

              // 성장 단계 배지
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    key: ValueKey(plant.currentStageInfo.id),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.38),
                      borderRadius: BorderRadius.circular(24),
                      border:
                          Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.20),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      '${plant.species.emoji}  ${plant.currentStageInfo.name}  ·  ${plant.growthLevel}%',
                      style: const TextStyle(
                          color: AppTheme.textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3),
                    ),
                  ),
                ),
              ),

              // 식물 뷰
              Expanded(
                child: PlantView(
                  type: plant.type,
                  growthLevel: plant.growthLevel,
                  seed: plant.seed,
                ),
              ),

              if (isRaining)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    '슬픈 마음이\n따뜻한 비가 되어 식물을 키워요 🌧',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.textDark, fontSize: 14, height: 1.6),
                  ).animate().fade(duration: 600.ms).slideY(begin: 0.3, end: 0),
                ),

              const SizedBox(height: 10),
              _GrowthBar(level: plant.growthLevel),
              const SizedBox(height: 18),

              // 다 자랐으면 수확, 아니면 일기 쓰기
              if (plant.isFullyGrown)
                _HarvestButton()
              else
                _PrimaryButton(
                  emoji: '✏️',
                  label: '오늘의 마음 기록하기',
                  onTap: onDiaryTap,
                ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 일기 쓰기 / 수확 버튼 ─────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton(
      {required this.emoji, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 30),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
                color: Colors.white.withValues(alpha: 0.3),
                blurRadius: 16,
                spreadRadius: 1),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _HarvestButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _PrimaryButton(
      emoji: '🎉',
      label: '다 자랐어요! 수확하고 새 씨앗 심기',
      onTap: () => _showHarvestSheet(context),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
        duration: 1600.ms, color: Colors.white.withValues(alpha: 0.5));
  }
}

void _showHarvestSheet(BuildContext context) {
  PlantType? picked;
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.deepForest,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text('🌳 수확하기',
                      style: TextStyle(
                          color: AppTheme.dawnGlow,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Text('다 키운 식물은 정원 도감에 보관돼요.\n다음엔 어떤 씨앗을 심을까요?',
                    style: TextStyle(
                        color: AppTheme.textSubtle, fontSize: 13, height: 1.5)),
                const SizedBox(height: 16),
                SeedPicker(
                  selected: picked,
                  onSelect: (t) => setSheet(() => picked = t),
                ),
                const SizedBox(height: 18),
                Opacity(
                  opacity: picked == null ? 0.4 : 1,
                  child: GestureDetector(
                    onTap: picked == null
                        ? null
                        : () {
                            context
                                .read<AppProvider>()
                                .harvestAndPlant(picked!);
                            Navigator.pop(sheetCtx);
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppTheme.softMoss, AppTheme.lightForest]),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Center(
                        child: Text('이 씨앗 심기',
                            style: TextStyle(
                                color: AppTheme.softCloud,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

// ── 성장 게이지 바 ────────────────────────────────────────────────────────────
class _GrowthBar extends StatelessWidget {
  final int level;
  const _GrowthBar({required this.level});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('성장 게이지',
                  style: TextStyle(color: AppTheme.textSubtle, fontSize: 11)),
              Text('$level / 100',
                  style: const TextStyle(
                      color: AppTheme.textSubtle, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: level / 100.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF7ECBA9)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _IconBtn({required this.icon, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: c, size: 20),
      ),
    );
  }
}

// ── 비 레이어 ────────────────────────────────────────────────────────────────
class _RainLayer extends StatefulWidget {
  @override
  State<_RainLayer> createState() => _RainLayerState();
}

class _RainLayerState extends State<_RainLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rng = math.Random();
  late List<_RainDrop> _drops;

  @override
  void initState() {
    super.initState();
    _drops = List.generate(60, (_) => _RainDrop(_rng));
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 16))
      ..addListener(() {
        for (final d in _drops) {
          d.y += d.speed;
          if (d.y > 1.0) {
            d.y = -0.1;
            d.x = _rng.nextDouble();
          }
        }
        setState(() {});
      })
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RainPainter(_drops), size: Size.infinite);
  }
}

class _RainDrop {
  double x, y, speed, length, opacity;
  _RainDrop(math.Random r)
      : x = r.nextDouble(),
        y = r.nextDouble(),
        speed = 0.004 + r.nextDouble() * 0.006,
        length = 0.02 + r.nextDouble() * 0.03,
        opacity = 0.2 + r.nextDouble() * 0.4;
}

class _RainPainter extends CustomPainter {
  final List<_RainDrop> drops;
  _RainPainter(this.drops);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (final d in drops) {
      p.color = const Color(0xFF90CAF9).withValues(alpha: d.opacity);
      canvas.drawLine(
          Offset(d.x * size.width, d.y * size.height),
          Offset(d.x * size.width - 2, (d.y + d.length) * size.height),
          p);
    }
  }

  @override
  bool shouldRepaint(_RainPainter _) => true;
}
