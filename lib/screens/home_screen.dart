import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../models/weather_model.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/time_weather_theme.dart';
import '../widgets/animated_plant_widget.dart';
import '../widgets/plant_view.dart';
import '../widgets/seed_picker.dart';
import 'diary_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

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
    final plant    = provider.currentPlant;
    final weather  = provider.weather;
    final sky = TimeWeatherTheme.get(
        weather: weather, emotionRain: isRaining);

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
                        icon: Icons.bar_chart_rounded,
                        color: AppTheme.textDark,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const StatsScreen()))),
                    const SizedBox(width: 8),
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

              const SizedBox(height: 8),

              // 날씨 정보 스트립
              if (weather != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  child: _WeatherStrip(weather: weather, sky: sky),
                ),

              const SizedBox(height: 4),

              // 오늘의 정원 한마디
              _DailyAffirmation(
                  growthLevel: plant.growthLevel,
                  entries: provider.diaryEntries),

              // 식물 뷰 (탭하면 상세 팝업)
              Expanded(
                child: GestureDetector(
                  onTap: () => _showPlantInfoSheet(context, plant, provider),
                  child: PlantView(
                    type: plant.type,
                    growthLevel: plant.growthLevel,
                    seed: plant.seed,
                    wiltFactor: plant.wiltFactor,
                    windAmp: weather?.windAmp ?? 4.0,
                  ),
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
          color: Colors.white.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
                color: Colors.white.withValues(alpha: 0.22),
                blurRadius: 20,
                spreadRadius: 2),
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

// ── 오늘의 정원 한마디 ───────────────────────────────────────────────────────
class _DailyAffirmation extends StatelessWidget {
  final int growthLevel;
  final List<EmotionEntry> entries;
  const _DailyAffirmation(
      {required this.growthLevel, required this.entries});

  String get _message {
    // 최근 3개 중 위로 감정이 많으면 응원 메시지 우선
    final recent = entries.length > 3 ? entries.sublist(entries.length - 3) : entries;
    final comfortingCount =
        recent.where((e) => Emotions.isComforting(e.emotion)).length;
    if (comfortingCount >= 2) {
      return '힘든 마음도 정원을 자라게 하는 소중한 거름이에요 🌧';
    }
    if (growthLevel == 0) return '씨앗을 심었어요. 오늘의 마음을 기록해봐요 🌱';
    if (growthLevel < 25) return '조금씩 싹이 트고 있어요. 매일 기록이 힘이 돼요 🌿';
    if (growthLevel < 55) return '식물이 쑥쑥 자라고 있어요! 잘하고 있어요 🌱';
    if (growthLevel < 80) return '꽃을 피울 준비를 하고 있어요. 거의 다 왔어요 🌸';
    if (growthLevel < 100) return '수확이 얼마 남지 않았어요! 조금만 더 기록해봐요 🎉';
    return '다 자랐어요! 새 씨앗을 심을 시간이에요 🌳';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: Container(
          key: ValueKey(_message),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Text(
            _message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppTheme.textDark, fontSize: 12, height: 1.4),
          ),
        ),
      ),
    );
  }
}

// ── 식물 상세 팝업 ───────────────────────────────────────────────────────────
void _showPlantInfoSheet(
    BuildContext context, Plant plant, AppProvider provider) {
  final days =
      DateTime.now().difference(plant.plantedAt).inDays;
  final species = plant.species;
  final stage = plant.currentStageInfo;

  // 다음 단계 찾기
  final nextStage = species.stages.firstWhere(
    (s) => s.requiredGrowth > plant.growthLevel,
    orElse: () => stage,
  );
  final toNext = nextStage == stage
      ? 0
      : nextStage.requiredGrowth - plant.growthLevel;
  final entriesNeeded =
      (toNext / AppProvider.growthPerEntry).ceil();

  // 이 식물이 소화한 일기 수
  final absorbed = provider.diaryEntries
      .where((e) => e.date
          .isAfter(plant.plantedAt.subtract(const Duration(minutes: 1))))
      .length;

  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.deepForest,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(species.emoji,
              style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 10),
          Text(species.name,
              style: const TextStyle(
                  color: AppTheme.dawnGlow,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(stage.name,
              style: const TextStyle(
                  color: AppTheme.softMoss, fontSize: 14)),
          const SizedBox(height: 24),
          _InfoRow(
              icon: '📅',
              label: '심은 지',
              value: days == 0 ? '오늘' : '$days일 째'),
          const SizedBox(height: 12),
          _InfoRow(
              icon: '📔',
              label: '기록한 일기',
              value: '$absorbed개'),
          const SizedBox(height: 12),
          _InfoRow(
              icon: '🌱',
              label: '성장',
              value: '${plant.growthLevel}%'),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: plant.growthLevel / 100.0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: Colors.white12,
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFF7ECBA9)),
              ),
            ),
          ),
          if (toNext > 0) ...[
            const SizedBox(height: 12),
            Text(
              '다음 단계 "${nextStage.name}"까지 일기 $entriesNeeded번 더 써요',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textSubtle, fontSize: 12, height: 1.5),
            ),
          ],
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSubtle, fontSize: 14)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: AppTheme.dawnGlow,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
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

// ── 날씨 스트립 ──────────────────────────────────────────────────────────────
class _WeatherStrip extends StatelessWidget {
  final WeatherData weather;
  final SkyTheme sky;
  const _WeatherStrip({required this.weather, required this.sky});

  @override
  Widget build(BuildContext context) {
    final temp   = weather.displayTemp;
    final emoji  = weather.conditionEmoji;
    final label  = weather.conditionLabel;
    final city   = weather.stationName;
    final humid  = weather.humidity;
    final wind   = weather.windSpeed;
    final rain   = weather.rainfall;

    final parts = <String>[
      '$emoji $label',
      '🌡 ${temp.round()}°C',
      if (humid != null) '💧 ${humid.round()}%',
      if (wind != null) '🌬 ${wind.toStringAsFixed(1)}m/s',
      if (rain != null && rain > 0) '☔ ${rain.toStringAsFixed(1)}mm',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '📍 $city',
            style: const TextStyle(
                color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: Colors.white24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              parts.join('  ·  '),
              style: const TextStyle(color: Colors.white, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
