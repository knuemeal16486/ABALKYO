import 'dart:math' as math;
import 'package:flutter/material.dart';

// My Oasis · 어비스리움 스타일 마법 파티클
// 오브(빛방울) · 스타(반짝이) · 페탈(꽃잎) 세 종류가 부드럽게 떠오름
class SkyParticles extends StatefulWidget {
  final Color color;
  const SkyParticles({super.key, required this.color});
  @override
  State<SkyParticles> createState() => _SkyParticlesState();
}

class _SkyParticlesState extends State<SkyParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rng = math.Random();
  late List<_Spark> _sparks;

  @override
  void initState() {
    super.initState();
    _sparks = List.generate(40, (_) => _Spark(_rng));
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => CustomPaint(
          painter: _SparkPainter(_sparks, _ctrl.value, widget.color),
          size: Size.infinite,
        ),
      );
}

enum _SparkType { orb, star, petal }

class _Spark {
  double x, y, r, spd, ph, wobbleAmp, wobbleFreq;
  _SparkType type;
  Color color;

  static const _pastelColors = [
    Color(0xFFFFE4EE), // 소프트 핑크
    Color(0xFFE6F7F1), // 소프트 민트
    Color(0xFFFFF8E0), // 소프트 골드
    Color(0xFFECE6FF), // 소프트 라벤더
    Color(0xFFFFFFFF), // 화이트
    Color(0xFFE0F4FF), // 소프트 블루
  ];

  _Spark(math.Random g)
      : x = g.nextDouble(),
        y = g.nextDouble(),
        r = 1.8 + g.nextDouble() * 3.8,
        spd = 0.0018 + g.nextDouble() * 0.0035,
        ph = g.nextDouble() * math.pi * 2,
        wobbleAmp = 0.015 + g.nextDouble() * 0.025,
        wobbleFreq = 0.5 + g.nextDouble() * 0.8,
        type = _SparkType.values[g.nextInt(3)],
        color = _pastelColors[g.nextInt(_pastelColors.length)];
}

class _SparkPainter extends CustomPainter {
  final List<_Spark> sparks;
  final double t;
  final Color skyColor;

  _SparkPainter(this.sparks, this.t, this.skyColor);

  @override
  void paint(Canvas cv, Size sz) {
    for (final s in sparks) {
      // 부드러운 사인 페이드 (펭귄의 섬 스타일)
      final alpha = (0.15 + 0.60 * math.sin(t * math.pi * 2 + s.ph))
          .clamp(0.0, 1.0);

      // 위로 떠오르며 좌우로 흔들림
      final dy = (s.y - t * s.spd + 1.0) % 1.0;
      final dx = s.x +
          math.sin(t * math.pi * 2 * s.wobbleFreq + s.ph) * s.wobbleAmp;
      final cx = (dx % 1.0) * sz.width;
      final cy = dy * sz.height;

      switch (s.type) {
        case _SparkType.orb:
          _drawOrb(cv, Offset(cx, cy), s.r, s.color, alpha);
        case _SparkType.star:
          _drawStar(cv, Offset(cx, cy), s.r * 1.3, s.color, alpha);
        case _SparkType.petal:
          _drawPetal(
              cv, Offset(cx, cy), s.r, s.color, alpha, t * math.pi + s.ph);
      }
    }
  }

  // 어비스리움 스타일 빛방울 — 이중 글로우 + 코어
  void _drawOrb(Canvas c, Offset center, double r, Color color, double alpha) {
    c.drawCircle(
        center,
        r * 3.0,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.8));
    c.drawCircle(
        center,
        r * 1.5,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.7));
    c.drawCircle(center, r * 0.7,
        Paint()..color = color.withValues(alpha: alpha * 0.85));
  }

  // 펭귄의 섬 스타일 반짝이 별 — 십자 + 대각선
  void _drawStar(Canvas c, Offset center, double r, Color color, double alpha) {
    // 글로우 배경
    c.drawCircle(
        center,
        r * 1.4,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r));

    final mainPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.90)
      ..strokeWidth = r * 0.38
      ..strokeCap = StrokeCap.round;

    final diagPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.50)
      ..strokeWidth = r * 0.22
      ..strokeCap = StrokeCap.round;

    // 주축 (십자)
    c.drawLine(Offset(center.dx - r, center.dy),
        Offset(center.dx + r, center.dy), mainPaint);
    c.drawLine(Offset(center.dx, center.dy - r),
        Offset(center.dx, center.dy + r), mainPaint);

    // 대각선 (45° 짧게)
    final d = r * 0.60;
    c.drawLine(Offset(center.dx - d, center.dy - d),
        Offset(center.dx + d, center.dy + d), diagPaint);
    c.drawLine(Offset(center.dx + d, center.dy - d),
        Offset(center.dx - d, center.dy + d), diagPaint);

    // 중앙 코어 점
    c.drawCircle(center, r * 0.28,
        Paint()..color = color.withValues(alpha: alpha * 0.95));
  }

  // My Oasis 스타일 꽃잎 — 회전하는 작은 타원
  void _drawPetal(Canvas c, Offset center, double r, Color color, double alpha,
      double angle) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(angle);
    final path = Path()
      ..addOval(
          Rect.fromCenter(center: Offset.zero, width: r, height: r * 1.8));
    c.drawPath(path, Paint()..color = color.withValues(alpha: alpha * 0.65));
    // 꽃잎 중앙 하이라이트
    c.drawOval(
        Rect.fromCenter(
            center: const Offset(0, -r * 0.2), width: r * 0.4, height: r),
        Paint()..color = color.withValues(alpha: alpha * 0.30));
    c.restore();
  }

  @override
  bool shouldRepaint(_SparkPainter o) => true;
}
