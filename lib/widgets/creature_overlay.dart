import 'dart:math' as math;
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 어비스리움 스타일 생물 오버레이
//   · 나비(lv 25+) · 꿀벌(lv 50+) · 무당벌레(lv 35+)
//   · 각각 독립적인 등장/퇴장 주기 + 이동 경로
//   · Canvas로 직접 그린 2D 캐릭터 (글로우 포함)
// ═══════════════════════════════════════════════════════════════════════════

class CreatureOverlay extends StatefulWidget {
  final int growthLevel;
  const CreatureOverlay({super.key, required this.growthLevel});

  @override
  State<CreatureOverlay> createState() => _CreatureOverlayState();
}

class _CreatureOverlayState extends State<CreatureOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.growthLevel < 0) return const SizedBox.shrink(); // 테스트: 항상 표시
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _CreaturePainter(_ctrl.value, widget.growthLevel),
        size: Size.infinite,
      ),
    );
  }
}

// ── 페인터 ───────────────────────────────────────────────────────────────────
class _CreaturePainter extends CustomPainter {
  final double t;
  final int growthLevel;
  _CreaturePainter(this.t, this.growthLevel);

  // ── 가시성 곡선 ────────────────────────────────────────────────────────────
  // phaseOff: 시작 위상(0~1), onFrac: 전체 주기 중 보이는 비율
  double _vis(double phaseOff, double onFrac) {
    final local = (t + phaseOff) % 1.0;
    const fw = 0.07; // 페이드 구간
    if (local < fw) return (local / fw).clamp(0.0, 1.0);
    if (local < onFrac - fw) return 1.0;
    if (local < onFrac) return ((onFrac - local) / fw).clamp(0.0, 1.0);
    return 0.0;
  }

  // ── 이동 경로 ──────────────────────────────────────────────────────────────

  // 나비: 8자(리사주) 궤도 — 상단 식물 영역
  Offset _butterflyPos(Size sz) {
    final s = (t * 2.6) % 1.0;
    final a = s * 2 * math.pi;
    return Offset(
      sz.width * 0.50 + sz.width * 0.30 * math.cos(a),
      sz.height * 0.34 + sz.height * 0.11 * math.sin(2 * a),
    );
  }

  // 꿀벌: 꽃 주변 타원 궤도 + 작은 진동
  Offset _beePos(Size sz) {
    final s = (t * 6.0) % 1.0;
    final a = s * 2 * math.pi;
    return Offset(
      sz.width * 0.56 + sz.width * 0.13 * math.cos(a) +
          sz.width * 0.03 * math.cos(a * 3.0),
      sz.height * 0.25 + sz.height * 0.07 * math.sin(a) +
          sz.height * 0.02 * math.sin(a * 3.0),
    );
  }

  // 무당벌레: 화분·잎 구간을 천천히 가로지름
  Offset _ladybugPos(Size sz) {
    final s = ((t * 0.42) % 1.0);
    return Offset(
      sz.width * (0.18 + 0.64 * s),
      sz.height * (0.70 + 0.05 * math.sin(s * math.pi * 5)),
    );
  }

  @override
  void paint(Canvas c, Size sz) {
    final sc = (sz.height / 520).clamp(0.55, 1.7);

    // 테스트: 임계값 0 → 항상 표시
    // ── 무당벌레 ────────────────────────────────────────────────────────────
    {
      final a = _vis(0.12, 0.62);
      if (a > 0.01) _drawLadybug(c, _ladybugPos(sz), sc, a);
    }

    // ── 나비 ────────────────────────────────────────────────────────────────
    {
      final a = _vis(0.44, 0.52);
      if (a > 0.01) _drawButterfly(c, _butterflyPos(sz), sc, a);
    }

    // ── 꿀벌 ────────────────────────────────────────────────────────────────
    {
      final a = _vis(0.72, 0.48);
      if (a > 0.01) _drawBee(c, _beePos(sz), sc, a);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 나비 그리기
  // ═══════════════════════════════════════════════════════════════════════════
  void _drawButterfly(Canvas c, Offset pos, double sc, double alpha) {
    // 날갯짓 (빠른 사인 진동 → 0=접힘, 1=활짝)
    final flap = (math.sin(t * math.pi * 2 * 5.8) * 0.5 + 0.5).clamp(0.0, 1.0);
    final openA = math.pi * 0.48 * flap;

    const wCol  = Color(0xFFFF8A65); // 주황 날개
    const wDark = Color(0xFFBF360C); // 날개 무늬
    const wLow  = Color(0xFFFFAB91); // 아랫날개

    // 어비스리움 스타일 후광 (날개 뒤)
    c.drawCircle(
      pos,
      30 * sc,
      Paint()
        ..color = wCol.withValues(alpha: alpha * 0.10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 * sc),
    );

    for (final side in [-1.0, 1.0]) {
      c.save();
      c.translate(pos.dx, pos.dy);
      c.rotate(side * openA);

      // ── 윗날개
      final uw = Paint()..color = wCol.withValues(alpha: alpha * 0.92);
      final uwP = Path()
        ..moveTo(0, -5 * sc)
        ..cubicTo(side * 6 * sc, -24 * sc, side * 30 * sc, -20 * sc,
            side * 28 * sc, -2 * sc)
        ..cubicTo(side * 22 * sc, 7 * sc, side * 4 * sc, 4 * sc, 0, -5 * sc);
      c.drawPath(uwP, uw);

      // 날개 무늬 (안쪽 어두운 패턴)
      final ip = Paint()..color = wDark.withValues(alpha: alpha * 0.38);
      final ipP = Path()
        ..moveTo(0, -5 * sc)
        ..cubicTo(side * 4 * sc, -15 * sc, side * 18 * sc, -14 * sc,
            side * 16 * sc, -3 * sc)
        ..cubicTo(side * 12 * sc, 3 * sc, side * 3 * sc, 1 * sc, 0, -5 * sc);
      c.drawPath(ipP, ip);

      // 흰 점무늬
      c.drawCircle(Offset(side * 22 * sc, -10 * sc), 2.2 * sc,
          Paint()..color = Colors.white.withValues(alpha: alpha * 0.55));

      // ── 아랫날개
      final lw = Paint()..color = wLow.withValues(alpha: alpha * 0.80);
      final lwP = Path()
        ..moveTo(0, -2 * sc)
        ..cubicTo(side * 12 * sc, 2 * sc, side * 22 * sc, 8 * sc,
            side * 18 * sc, 19 * sc)
        ..cubicTo(side * 8 * sc, 24 * sc, side * 1 * sc, 12 * sc, 0, -2 * sc);
      c.drawPath(lwP, lw);

      c.restore();
    }

    // 몸통
    c.drawOval(
      Rect.fromCenter(center: pos, width: 4.5 * sc, height: 19 * sc),
      Paint()..color = const Color(0xFF3E2723).withValues(alpha: alpha),
    );

    // 더듬이
    final ap = Paint()
      ..color = const Color(0xFF4E342E).withValues(alpha: alpha * 0.9)
      ..strokeWidth = 1.3 * sc
      ..strokeCap = StrokeCap.round;
    c.drawLine(pos + Offset(-2.2 * sc, -9 * sc),
        pos + Offset(-10 * sc, -22 * sc), ap);
    c.drawLine(pos + Offset(2.2 * sc, -9 * sc),
        pos + Offset(10 * sc, -22 * sc), ap);
    // 더듬이 끝 구슬
    c.drawCircle(pos + Offset(-10 * sc, -22 * sc), 2.4 * sc,
        Paint()..color = const Color(0xFF4E342E).withValues(alpha: alpha));
    c.drawCircle(pos + Offset(10 * sc, -22 * sc), 2.4 * sc,
        Paint()..color = const Color(0xFF4E342E).withValues(alpha: alpha));
    // 구슬 하이라이트
    c.drawCircle(pos + Offset(-9 * sc, -23 * sc), 0.8 * sc,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.6));
    c.drawCircle(pos + Offset(11 * sc, -23 * sc), 0.8 * sc,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.6));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 꿀벌 그리기
  // ═══════════════════════════════════════════════════════════════════════════
  void _drawBee(Canvas c, Offset pos, double sc, double alpha) {
    // 날개 진동 (아주 빠름)
    final wy = math.sin(t * math.pi * 2 * 22) * 2.8 * sc;

    // 어비스리움 스타일 후광
    c.drawCircle(
      pos,
      26 * sc,
      Paint()
        ..color = const Color(0xFFFFD600).withValues(alpha: alpha * 0.08)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * sc),
    );

    // 날개 (반투명 타원)
    final wP = Paint()
      ..color = const Color(0xFFE8F5E9).withValues(alpha: alpha * 0.72);
    c.drawOval(
        Rect.fromCenter(
            center: pos + Offset(-12 * sc, (-15 + wy) * sc),
            width: 17 * sc,
            height: 10 * sc),
        wP);
    c.drawOval(
        Rect.fromCenter(
            center: pos + Offset(12 * sc, (-15 + wy) * sc),
            width: 17 * sc,
            height: 10 * sc),
        wP);
    // 날개 테두리 광택
    final wEdge = Paint()
      ..color = Colors.white.withValues(alpha: alpha * 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * sc;
    c.drawOval(
        Rect.fromCenter(
            center: pos + Offset(-12 * sc, (-15 + wy) * sc),
            width: 17 * sc,
            height: 10 * sc),
        wEdge);
    c.drawOval(
        Rect.fromCenter(
            center: pos + Offset(12 * sc, (-15 + wy) * sc),
            width: 17 * sc,
            height: 10 * sc),
        wEdge);

    // 몸통 (노란 타원)
    c.drawOval(
      Rect.fromCenter(center: pos, width: 13 * sc, height: 18 * sc),
      Paint()..color = const Color(0xFFFFD600).withValues(alpha: alpha),
    );
    // 몸통 하이라이트
    c.drawOval(
      Rect.fromCenter(
          center: pos + Offset(-2.5 * sc, -4 * sc),
          width: 6 * sc,
          height: 10 * sc),
      Paint()..color = Colors.white.withValues(alpha: alpha * 0.22),
    );

    // 검은 줄무늬 (body clip 후 rect)
    c.save();
    c.clipPath(Path()
      ..addOval(
          Rect.fromCenter(center: pos, width: 13 * sc, height: 18 * sc)));
    for (int i = 0; i < 3; i++) {
      c.drawRect(
        Rect.fromCenter(
            center: pos + Offset(0, -5.5 * sc + i * 5.5 * sc),
            width: 15 * sc,
            height: 2.8 * sc),
        Paint()..color = const Color(0xFF212121).withValues(alpha: alpha * 0.82),
      );
    }
    c.restore();

    // 머리 (검은 원)
    c.drawCircle(pos + Offset(0, -12 * sc), 5.5 * sc,
        Paint()..color = const Color(0xFF212121).withValues(alpha: alpha));
    // 눈 (흰 점)
    c.drawCircle(pos + Offset(-2.2 * sc, -13 * sc), 1.5 * sc,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.9));
    c.drawCircle(pos + Offset(2.2 * sc, -13 * sc), 1.5 * sc,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.9));
    // 눈 하이라이트
    c.drawCircle(pos + Offset(-1.5 * sc, -13.6 * sc), 0.5 * sc,
        Paint()..color = const Color(0xFF1565C0).withValues(alpha: alpha * 0.7));
    c.drawCircle(pos + Offset(2.9 * sc, -13.6 * sc), 0.5 * sc,
        Paint()..color = const Color(0xFF1565C0).withValues(alpha: alpha * 0.7));

    // 침
    final stingP = Path()
      ..moveTo(pos.dx - 2.5 * sc, pos.dy + 9 * sc)
      ..lineTo(pos.dx + 2.5 * sc, pos.dy + 9 * sc)
      ..lineTo(pos.dx, pos.dy + 15 * sc)
      ..close();
    c.drawPath(
        stingP,
        Paint()
          ..color = const Color(0xFFBF360C).withValues(alpha: alpha * 0.75));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 무당벌레 그리기
  // ═══════════════════════════════════════════════════════════════════════════
  void _drawLadybug(Canvas c, Offset pos, double sc, double alpha) {
    // 그림자
    c.drawCircle(
      pos + Offset(2 * sc, 4 * sc),
      10 * sc,
      Paint()
        ..color = const Color(0x55000000).withValues(alpha: alpha * 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * sc),
    );

    // 몸통 (빨간 원)
    c.drawCircle(
        pos, 11 * sc, Paint()..color = const Color(0xFFE53935).withValues(alpha: alpha));
    // 몸통 상단 하이라이트 (반구 느낌)
    c.drawCircle(
        pos + Offset(-3 * sc, -4.5 * sc),
        7 * sc,
        Paint()..color = const Color(0xFFEF9A9A).withValues(alpha: alpha * 0.32));
    // 하단 어두운 그라데이션 느낌
    c.drawOval(
      Rect.fromCenter(
          center: pos + Offset(0, 5 * sc), width: 18 * sc, height: 8 * sc),
      Paint()
        ..color = const Color(0xFFC62828).withValues(alpha: alpha * 0.40),
    );

    // 중앙 날개 분할선
    c.drawLine(
      pos + Offset(0, -10 * sc),
      pos + Offset(0, 10 * sc),
      Paint()
        ..color = const Color(0xFF212121).withValues(alpha: alpha * 0.70)
        ..strokeWidth = 1.6 * sc
        ..strokeCap = StrokeCap.round,
    );

    // 검은 점 (4개)
    for (final s in [
      Offset(-4 * sc, -4 * sc),
      Offset(4 * sc, -4 * sc),
      Offset(-4.2 * sc, 3.5 * sc),
      Offset(4.2 * sc, 3.5 * sc),
    ]) {
      c.drawCircle(pos + s, 2.5 * sc,
          Paint()..color = const Color(0xFF212121).withValues(alpha: alpha * 0.88));
    }

    // 머리
    c.drawCircle(pos + Offset(0, -13 * sc), 5.8 * sc,
        Paint()..color = const Color(0xFF212121).withValues(alpha: alpha));
    // 눈
    c.drawCircle(pos + Offset(-2.4 * sc, -14 * sc), 1.5 * sc,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.88));
    c.drawCircle(pos + Offset(2.4 * sc, -14 * sc), 1.5 * sc,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.88));
    // 눈동자
    c.drawCircle(pos + Offset(-2.4 * sc, -14 * sc), 0.7 * sc,
        Paint()..color = const Color(0xFF212121).withValues(alpha: alpha * 0.9));
    c.drawCircle(pos + Offset(2.4 * sc, -14 * sc), 0.7 * sc,
        Paint()..color = const Color(0xFF212121).withValues(alpha: alpha * 0.9));

    // 다리 (3쌍 6개)
    final legP = Paint()
      ..color = const Color(0xFF212121).withValues(alpha: alpha * 0.60)
      ..strokeWidth = 1.1 * sc
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final ly = (-3.5 + i * 4.0) * sc;
      // 왼쪽 다리
      c.drawLine(pos + Offset(-10 * sc, ly),
          pos + Offset(-17 * sc, ly - 4 * sc), legP);
      // 오른쪽 다리
      c.drawLine(pos + Offset(10 * sc, ly),
          pos + Offset(17 * sc, ly - 4 * sc), legP);
    }

    // 더듬이 (2개)
    final anP = Paint()
      ..color = const Color(0xFF212121).withValues(alpha: alpha * 0.55)
      ..strokeWidth = 1.0 * sc
      ..strokeCap = StrokeCap.round;
    c.drawLine(pos + Offset(-2 * sc, -17.5 * sc),
        pos + Offset(-6 * sc, -24 * sc), anP);
    c.drawLine(pos + Offset(2 * sc, -17.5 * sc),
        pos + Offset(6 * sc, -24 * sc), anP);
  }

  @override
  bool shouldRepaint(_CreaturePainter o) =>
      o.t != t || o.growthLevel != growthLevel;
}
