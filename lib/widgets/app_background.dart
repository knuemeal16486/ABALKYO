import 'package:flutter/material.dart';
import '../utils/time_weather_theme.dart';

/// 모든 보조 화면에서 사용하는 시간대별 따뜻한 배경.
///
/// - 시간대에 따라 warmColors 그라데이션 적용
/// - 두 개의 부드러운 주변광 글로우 오브 추가
/// - AnimatedContainer로 3초 전환
class WarmBackground extends StatelessWidget {
  final Widget child;

  const WarmBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final sky = TimeWeatherTheme.get();

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── 시간대별 따뜻한 그라데이션 배경 ─────────────────────────────
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

        // ── 주변광 글로우 오브 1 (오른쪽 위) ────────────────────────────
        Positioned(
          top: -80,
          right: -60,
          child: _GlowOrb(color: sky.glowColor, size: 280),
        ),

        // ── 주변광 글로우 오브 2 (왼쪽 아래) ────────────────────────────
        Positioned(
          bottom: 20,
          left: -90,
          child: _GlowOrb(color: sky.accentColor, size: 260),
        ),

        // ── 콘텐츠 ──────────────────────────────────────────────────────
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.20),
            color.withValues(alpha: 0.07),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

/// 카드·컨테이너의 공통 glassmorphism 데코
BoxDecoration warmCardDeco({
  Color? borderColor,
  double radius = 18,
  double alphaBg = 0.09,
  double alphaBorder = 0.20,
}) =>
    BoxDecoration(
      color: Colors.white.withValues(alpha: alphaBg),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: alphaBorder),
      ),
    );
