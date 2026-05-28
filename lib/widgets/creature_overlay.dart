import 'dart:math' as math;
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 어비스리움 스타일 생물 오버레이
//   · 나비(lv 25+) · 꿀벌(lv 50+) · 무당벌레(lv 35+)
//   · 각각 독립적인 등장/퇴장 주기 + 이동 경로
//   · Canvas로 직접 그린 2D 캐릭터 (폴리곤 스타일 디테일)
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
    if (widget.growthLevel < 25) return const SizedBox.shrink();
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
  double _vis(double phaseOff, double onFrac) {
    final local = (t + phaseOff) % 1.0;
    const fw = 0.07;
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
      sz.width * 0.56 +
          sz.width * 0.13 * math.cos(a) +
          sz.width * 0.03 * math.cos(a * 3.0),
      sz.height * 0.25 +
          sz.height * 0.07 * math.sin(a) +
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

    // ── 무당벌레 (lv 35+) ────────────────────────────────────────────────────
    if (growthLevel >= 35) {
      final a = _vis(0.12, 0.62);
      if (a > 0.01) _drawLadybug(c, _ladybugPos(sz), sc, a);
    }

    // ── 나비 (lv 25+) ────────────────────────────────────────────────────────
    if (growthLevel >= 25) {
      final a = _vis(0.44, 0.52);
      if (a > 0.01) _drawButterfly(c, _butterflyPos(sz), sc, a);
    }

    // ── 꿀벌 (lv 50+) ────────────────────────────────────────────────────────
    if (growthLevel >= 50) {
      final a = _vis(0.72, 0.48);
      if (a > 0.01) _drawBee(c, _beePos(sz), sc, a);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 나비 그리기 — 호랑나비 (Tiger Swallowtail) 스타일
  // ═══════════════════════════════════════════════════════════════════════════
  void _drawButterfly(Canvas c, Offset pos, double sc, double alpha) {
    // 날갯짓 진동 (5.8× 속도, 위상 포함)
    final flapRaw = math.sin(t * math.pi * 2 * 5.8);
    final flapRawHind = math.sin(t * math.pi * 2 * 5.8 - 0.12);

    // 앞날개 각도: ±π*0.50
    final openFore = flapRaw * math.pi * 0.50;
    // 뒷날개 각도: 약간 위상 오프셋
    final openHind = flapRawHind * math.pi * 0.50;

    // 부드러운 후광
    c.drawCircle(
      pos,
      32 * sc,
      Paint()
        ..color = const Color(0xFFFFF9C4).withValues(alpha: alpha * 0.08)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16 * sc),
    );

    for (final side in [-1.0, 1.0]) {
      // ── 뒷날개 (먼저 그려서 앞날개 뒤에 위치)
      c.save();
      c.translate(pos.dx, pos.dy);
      c.rotate(side * openHind);

      final hindPath = Path()
        ..moveTo(0, 0)
        ..cubicTo(
            side * 4 * sc, -2 * sc, side * 20 * sc, 0, side * 22 * sc, 8 * sc)
        ..cubicTo(side * 22 * sc, 16 * sc, side * 16 * sc, 22 * sc,
            side * 10 * sc, 23 * sc)
        // 가리비 모양 바깥 가장자리
        ..cubicTo(side * 6 * sc, 23 * sc, side * 3 * sc, 20 * sc,
            side * 1 * sc, 18 * sc)
        ..cubicTo(side * (-1) * sc, 16 * sc, side * 0 * sc, 10 * sc, 0, 0);

      // 뒷날개 채우기 (크림 노랑)
      c.drawPath(
          hindPath,
          Paint()
            ..color =
                const Color(0xFFFFF9C4).withValues(alpha: alpha * 0.90));

      // 뒷날개 테두리
      c.drawPath(
          hindPath,
          Paint()
            ..color =
                const Color(0xFF212121).withValues(alpha: alpha * 0.80)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * sc
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);

      // 뒷날개 주황 초승달 무늬 (3~4개 타원)
      final orangeMark = Paint()
        ..color = const Color(0xFFFF6F00).withValues(alpha: alpha * 0.85);
      c.drawOval(
          Rect.fromCenter(
              center: Offset(side * 9 * sc, 19 * sc),
              width: 4.5 * sc,
              height: 3 * sc),
          orangeMark);
      c.drawOval(
          Rect.fromCenter(
              center: Offset(side * 14 * sc, 17 * sc),
              width: 4 * sc,
              height: 3 * sc),
          orangeMark);
      c.drawOval(
          Rect.fromCenter(
              center: Offset(side * 18 * sc, 12 * sc),
              width: 3.5 * sc,
              height: 3 * sc),
          orangeMark);

      // 뒷날개 바깥 가장자리 파란 무지개빛 점
      final blueIrid = Paint()
        ..color = const Color(0xFF1565C0).withValues(alpha: alpha * 0.70);
      c.drawCircle(Offset(side * 8 * sc, 20.5 * sc), 1.8 * sc, blueIrid);
      c.drawCircle(Offset(side * 13 * sc, 18.5 * sc), 1.6 * sc, blueIrid);
      c.drawCircle(Offset(side * 17 * sc, 13 * sc), 1.5 * sc, blueIrid);
      c.drawCircle(Offset(side * 20 * sc, 7 * sc), 1.4 * sc, blueIrid);

      c.restore();

      // ── 앞날개 (뒷날개 위에 그림)
      c.save();
      c.translate(pos.dx, pos.dy);
      c.rotate(side * openFore);

      // 앞날개 메인 형태 (삼각형 계열 큐빅 베지어)
      final forePath = Path()
        ..moveTo(0, -4 * sc)
        ..cubicTo(side * 5 * sc, -20 * sc, side * 24 * sc, -22 * sc,
            side * 30 * sc, -10 * sc)
        ..cubicTo(side * 32 * sc, -3 * sc, side * 28 * sc, 6 * sc,
            side * 20 * sc, 8 * sc)
        ..cubicTo(side * 10 * sc, 10 * sc, side * 3 * sc, 6 * sc, 0, -4 * sc);

      // 앞날개 채우기 (크림 노랑)
      c.drawPath(
          forePath,
          Paint()
            ..color =
                const Color(0xFFFFF9C4).withValues(alpha: alpha * 0.93));

      // 앞날개 테두리 (검은색)
      c.drawPath(
          forePath,
          Paint()
            ..color =
                const Color(0xFF212121).withValues(alpha: alpha * 0.82)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 * sc
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);

      // 앞날개 대각선 검은 줄무늬 (4개 좁은 경로)
      final stripePaint = Paint()
        ..color = const Color(0xFF212121).withValues(alpha: alpha * 0.55);

      // 줄무늬 1
      final s1 = Path()
        ..moveTo(side * 6 * sc, -18 * sc)
        ..lineTo(side * 8 * sc, -18 * sc)
        ..lineTo(side * 16 * sc, 6 * sc)
        ..lineTo(side * 14 * sc, 6 * sc)
        ..close();
      c.drawPath(s1, stripePaint);

      // 줄무늬 2
      final s2 = Path()
        ..moveTo(side * 12 * sc, -19 * sc)
        ..lineTo(side * 14 * sc, -19 * sc)
        ..lineTo(side * 22 * sc, 4 * sc)
        ..lineTo(side * 20 * sc, 5 * sc)
        ..close();
      c.drawPath(s2, stripePaint);

      // 줄무늬 3
      final s3 = Path()
        ..moveTo(side * 18 * sc, -17 * sc)
        ..lineTo(side * 20 * sc, -17 * sc)
        ..lineTo(side * 27 * sc, -2 * sc)
        ..lineTo(side * 25 * sc, -1 * sc)
        ..close();
      c.drawPath(s3, stripePaint);

      // 줄무늬 4 (짧은 가장자리)
      final s4 = Path()
        ..moveTo(side * 23 * sc, -13 * sc)
        ..lineTo(side * 25 * sc, -13 * sc)
        ..lineTo(side * 30 * sc, -6 * sc)
        ..lineTo(side * 28 * sc, -5 * sc)
        ..close();
      c.drawPath(s4, stripePaint);

      // 앞날개 바깥 가장자리 흰/크림 점 (4~5개)
      final spotPaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.72);
      c.drawCircle(Offset(side * 26 * sc, -14 * sc), 2.5 * sc, spotPaint);
      c.drawCircle(Offset(side * 29 * sc, -8 * sc), 2.8 * sc, spotPaint);
      c.drawCircle(Offset(side * 28 * sc, -1 * sc), 2.5 * sc, spotPaint);
      c.drawCircle(Offset(side * 22 * sc, 6 * sc), 3.0 * sc, spotPaint);
      c.drawCircle(Offset(side * 16 * sc, 8 * sc), 2.8 * sc, spotPaint);

      // 앞날개 안쪽 파란 무지개빛 점
      c.drawCircle(
          Offset(side * 4 * sc, -6 * sc),
          3.0 * sc,
          Paint()
            ..color =
                const Color(0xFF42A5F5).withValues(alpha: alpha * 0.75));

      c.restore();
    }

    // ── 몸통 (복부)
    c.save();
    c.translate(pos.dx, pos.dy);

    // 복부 어두운 타원
    c.drawOval(
      Rect.fromCenter(
          center: Offset.zero, width: 3.5 * sc, height: 14 * sc),
      Paint()
        ..color = const Color(0xFF212121).withValues(alpha: alpha * 0.92),
    );

    // 노란 줄무늬
    c.save();
    final bodyClip = Path()
      ..addOval(
          Rect.fromCenter(center: Offset.zero, width: 3.5 * sc, height: 14 * sc));
    c.clipPath(bodyClip);
    c.drawRect(
      Rect.fromCenter(center: Offset(0, 0), width: 4 * sc, height: 2.0 * sc),
      Paint()
        ..color = const Color(0xFFFFF176).withValues(alpha: alpha * 0.85),
    );
    c.restore();

    // 머리
    c.drawCircle(
        Offset(0, -9 * sc),
        3.0 * sc,
        Paint()
          ..color = const Color(0xFF212121).withValues(alpha: alpha * 0.92));

    // 겹눈 (작은 하늘색)
    c.drawCircle(
        Offset(-1.6 * sc, -9.5 * sc),
        1.1 * sc,
        Paint()
          ..color =
              const Color(0xFF4FC3F7).withValues(alpha: alpha * 0.80));
    c.drawCircle(
        Offset(1.6 * sc, -9.5 * sc),
        1.1 * sc,
        Paint()
          ..color =
              const Color(0xFF4FC3F7).withValues(alpha: alpha * 0.80));

    c.restore();

    // ── 더듬이
    final antennaLinePaint = Paint()
      ..color = const Color(0xFF212121).withValues(alpha: alpha * 0.80)
      ..strokeWidth = 1.2 * sc
      ..strokeCap = StrokeCap.round;

    // 왼쪽 더듬이
    c.drawLine(pos + Offset(-1.8 * sc, -11 * sc),
        pos + Offset(-9 * sc, -23 * sc), antennaLinePaint);
    // 오른쪽 더듬이
    c.drawLine(pos + Offset(1.8 * sc, -11 * sc),
        pos + Offset(9 * sc, -23 * sc), antennaLinePaint);

    // 더듬이 끝 구슬
    final clubPaint = Paint()
      ..color = const Color(0xFF212121).withValues(alpha: alpha * 0.90);
    c.drawCircle(pos + Offset(-9 * sc, -23 * sc), 2.0 * sc, clubPaint);
    c.drawCircle(pos + Offset(9 * sc, -23 * sc), 2.0 * sc, clubPaint);
    // 구슬 하이라이트
    c.drawCircle(
        pos + Offset(-8.3 * sc, -23.7 * sc),
        0.7 * sc,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.55));
    c.drawCircle(
        pos + Offset(9.7 * sc, -23.7 * sc),
        0.7 * sc,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.55));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 꿀벌 그리기 — Bumblebee 스타일
  // ═══════════════════════════════════════════════════════════════════════════
  void _drawBee(Canvas c, Offset pos, double sc, double alpha) {
    // 날개 진동 (22× 속도)
    final wingAngle = math.sin(t * math.pi * 2 * 22) * math.pi * 0.45;

    // 부드러운 후광
    c.drawCircle(
      pos,
      28 * sc,
      Paint()
        ..color = const Color(0xFFFFD600).withValues(alpha: alpha * 0.07)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 * sc),
    );

    // ── 복부 (Abdomen) ─────────────────────────────────────────────────────
    final abdomenRect =
        Rect.fromCenter(center: pos, width: 10 * sc, height: 14 * sc);
    final abdomenPath = Path()..addOval(abdomenRect);

    // 복부 노란 타원
    c.drawOval(
        abdomenRect,
        Paint()
          ..color =
              const Color(0xFFFFD600).withValues(alpha: alpha * 0.97));

    // 복부 검은 줄무늬 3개 (clipped)
    c.save();
    c.clipPath(abdomenPath);
    final stripePaint = Paint()
      ..color = const Color(0xFF212121).withValues(alpha: alpha * 0.85);
    // 25% 높이 (위)
    c.drawRect(
        Rect.fromCenter(
            center: pos + Offset(0, -3.5 * sc), width: 12 * sc, height: 2.5 * sc),
        stripePaint);
    // 50% 높이 (중간)
    c.drawRect(
        Rect.fromCenter(
            center: pos + Offset(0, 0), width: 12 * sc, height: 2.5 * sc),
        stripePaint);
    // 75% 높이 (아래)
    c.drawRect(
        Rect.fromCenter(
            center: pos + Offset(0, 3.5 * sc), width: 12 * sc, height: 2.5 * sc),
        stripePaint);
    c.restore();

    // 복부 하이라이트
    c.drawOval(
        Rect.fromCenter(
            center: pos + Offset(-2 * sc, -3 * sc),
            width: 4 * sc,
            height: 7 * sc),
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.18));

    // 침 (stinger) — 아래 삼각형
    final stingPath = Path()
      ..moveTo(pos.dx - 2 * sc, pos.dy + 7 * sc)
      ..lineTo(pos.dx + 2 * sc, pos.dy + 7 * sc)
      ..lineTo(pos.dx, pos.dy + 13 * sc)
      ..close();
    c.drawPath(
        stingPath,
        Paint()
          ..color =
              const Color(0xFF795548).withValues(alpha: alpha * 0.90));

    // ── 가슴 (Thorax) ───────────────────────────────────────────────────────
    final thoraxCenter = pos + Offset(0, -10 * sc);
    final thoraxRect = Rect.fromCenter(
        center: thoraxCenter, width: 8 * sc, height: 7 * sc);

    c.drawOval(
        thoraxRect,
        Paint()
          ..color =
              const Color(0xFFF9A825).withValues(alpha: alpha * 0.97));

    // 가슴 털 힌트 (작은 호)
    final hairPaint = Paint()
      ..color = const Color(0xFFFF8F00).withValues(alpha: alpha * 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * sc
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final hx = (-2.5 + i * 1.8) * sc;
      c.drawArc(
          Rect.fromCenter(
              center: thoraxCenter + Offset(hx, 0),
              width: 2.5 * sc,
              height: 3.5 * sc),
          -math.pi * 0.8,
          math.pi * 0.6,
          false,
          hairPaint);
    }

    // ── 날개 (Wings) ─────────────────────────────────────────────────────────
    for (final side in [-1.0, 1.0]) {
      c.save();
      c.translate(thoraxCenter.dx, thoraxCenter.dy);
      c.rotate(side * wingAngle);

      // 뒷날개 (hindwing) — 앞날개 뒤
      final hindWingRect = Rect.fromCenter(
          center: Offset(side * 9 * sc, -3 * sc),
          width: 10 * sc,
          height: 5 * sc);
      c.drawOval(
          hindWingRect,
          Paint()
            ..color =
                const Color(0x1890CAF9).withValues(alpha: alpha * 0.70));

      // 뒷날개 시맥
      final hindVeinPaint = Paint()
        ..color = const Color(0x60B3E5FC).withValues(alpha: alpha * 0.75)
        ..strokeWidth = 0.8 * sc
        ..strokeCap = StrokeCap.round;
      final hStart = Offset(side * 4 * sc, -3 * sc);
      final hEnd = Offset(side * 14 * sc, -3 * sc);
      c.drawLine(hStart, hEnd, hindVeinPaint);
      c.drawLine(Offset(side * 7 * sc, -3 * sc),
          Offset(side * 8 * sc, -5.5 * sc), hindVeinPaint);
      c.drawLine(Offset(side * 10 * sc, -3 * sc),
          Offset(side * 11 * sc, -5.5 * sc), hindVeinPaint);

      // 앞날개 (forewing) — 크고 투명
      final foreWingRect = Rect.fromCenter(
          center: Offset(side * 10 * sc, -6 * sc),
          width: 16 * sc,
          height: 7 * sc);
      c.drawOval(
          foreWingRect,
          Paint()
            ..color =
                const Color(0x2090CAF9).withValues(alpha: alpha * 0.85));

      // 앞날개 테두리
      c.drawOval(
          foreWingRect,
          Paint()
            ..color =
                const Color(0x50B3E5FC).withValues(alpha: alpha * 0.60)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7 * sc);

      // 앞날개 시맥 (4개)
      final veinPaint = Paint()
        ..color = const Color(0x60B3E5FC).withValues(alpha: alpha * 0.80)
        ..strokeWidth = 0.8 * sc
        ..strokeCap = StrokeCap.round;
      // 중심 시맥 (루트 → 끝)
      final vRoot = Offset(side * 2 * sc, -6 * sc);
      final vTip = Offset(side * 18 * sc, -6 * sc);
      c.drawLine(vRoot, vTip, veinPaint);
      // 가지 시맥 3개
      c.drawLine(Offset(side * 6 * sc, -6 * sc),
          Offset(side * 7 * sc, -9.5 * sc), veinPaint);
      c.drawLine(Offset(side * 10 * sc, -6 * sc),
          Offset(side * 11 * sc, -9.5 * sc), veinPaint);
      c.drawLine(Offset(side * 14 * sc, -6 * sc),
          Offset(side * 15 * sc, -9.2 * sc), veinPaint);

      c.restore();
    }

    // ── 머리 ───────────────────────────────────────────────────────────────
    final headCenter = thoraxCenter + Offset(0, -5.5 * sc);
    c.drawCircle(headCenter, 4.5 * sc,
        Paint()..color = const Color(0xFF212121).withValues(alpha: alpha));

    // 겹눈 (흰색 + 검은 동공)
    for (final side in [-1.0, 1.0]) {
      final eyeCenter = headCenter + Offset(side * 2.5 * sc, -0.5 * sc);
      c.drawOval(
          Rect.fromCenter(center: eyeCenter, width: 3.0 * sc, height: 2.5 * sc),
          Paint()..color = const Color(0xFFF5F5F5).withValues(alpha: alpha * 0.92));
      c.drawCircle(eyeCenter, 0.9 * sc,
          Paint()..color = const Color(0xFF212121).withValues(alpha: alpha));
    }

    // 더듬이
    final antPaint = Paint()
      ..color = const Color(0xFF212121).withValues(alpha: alpha * 0.85)
      ..strokeWidth = 1.0 * sc
      ..strokeCap = StrokeCap.round;
    // 왼쪽
    c.drawLine(headCenter + Offset(-1.8 * sc, -4 * sc),
        headCenter + Offset(-6 * sc, -11 * sc), antPaint);
    c.drawCircle(headCenter + Offset(-6 * sc, -11 * sc), 1.2 * sc,
        Paint()..color = const Color(0xFF212121).withValues(alpha: alpha));
    // 오른쪽
    c.drawLine(headCenter + Offset(1.8 * sc, -4 * sc),
        headCenter + Offset(6 * sc, -11 * sc), antPaint);
    c.drawCircle(headCenter + Offset(6 * sc, -11 * sc), 1.2 * sc,
        Paint()..color = const Color(0xFF212121).withValues(alpha: alpha));

    // ── 다리 (3쌍 6개) ────────────────────────────────────────────────────
    final legPaint = Paint()
      ..color = const Color(0xFF212121).withValues(alpha: alpha * 0.75)
      ..strokeWidth = 1.0 * sc
      ..strokeCap = StrokeCap.round;

    final legAttachY = [-9.5, -7.5, -5.5];
    for (int i = 0; i < 3; i++) {
      final attachY = legAttachY[i] * sc;
      for (final side in [-1.0, 1.0]) {
        final start = pos + Offset(side * 4 * sc, attachY);
        final mid = pos + Offset(side * 10 * sc, attachY + 3 * sc);
        final end = pos + Offset(side * 14 * sc, attachY + 9 * sc);
        final legPath = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(mid.dx, mid.dy)
          ..lineTo(end.dx, end.dy);
        c.drawPath(legPath, legPaint);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 무당벌레 그리기 — 칠성무당벌레 (7-spot ladybug) 리얼리스틱 스타일
  // ═══════════════════════════════════════════════════════════════════════════
  void _drawLadybug(Canvas c, Offset pos, double sc, double alpha) {
    // 그림자
    c.drawCircle(
      pos + Offset(2 * sc, 5 * sc),
      10 * sc,
      Paint()
        ..color = const Color(0x55000000).withValues(alpha: alpha * 0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * sc),
    );

    // ── 날개껍질 (Elytra) 몸통 ───────────────────────────────────────────────
    // 메인 빨간 돔
    c.drawCircle(pos, 9 * sc,
        Paint()..color = const Color(0xFFD32F2F).withValues(alpha: alpha));

    // 돔 셰이딩: 상단 하이라이트 느낌
    c.drawCircle(
        pos + Offset(-2.5 * sc, -2.5 * sc),
        5 * sc,
        Paint()
          ..color = const Color(0x40FF8A80).withValues(alpha: alpha * 0.65));

    // 하단 어두운 영역
    c.drawOval(
        Rect.fromCenter(
            center: pos + Offset(0, 4.5 * sc), width: 15 * sc, height: 7 * sc),
        Paint()
          ..color = const Color(0xFFB71C1C).withValues(alpha: alpha * 0.35));

    // 광택 하이라이트 (상단 좌)
    c.drawOval(
        Rect.fromCenter(
            center: pos + Offset(-3 * sc, -3 * sc),
            width: 4 * sc,
            height: 3 * sc),
        Paint()
          ..color =
              const Color(0x60FFFFFF).withValues(alpha: alpha * 0.70));

    // ── 중앙 날개 분할선 ──────────────────────────────────────────────────────
    c.drawLine(
      pos + Offset(0, -9 * sc),
      pos + Offset(0, 9 * sc),
      Paint()
        ..color = const Color(0xFFB71C1C).withValues(alpha: alpha * 0.75)
        ..strokeWidth = 1.2 * sc
        ..strokeCap = StrokeCap.round,
    );

    // ── 7개 점 (정확한 칠성 패턴) ─────────────────────────────────────────────
    final spotPositions = [
      // 왼쪽 3개
      Offset(-4.5 * sc, -2 * sc),
      Offset(-4 * sc, 2 * sc),
      Offset(-2.5 * sc, 5.5 * sc),
      // 오른쪽 3개
      Offset(4.5 * sc, -2 * sc),
      Offset(4 * sc, 2 * sc),
      Offset(2.5 * sc, 5.5 * sc),
      // 중앙 1개
      Offset(0, -5.5 * sc),
    ];

    for (final sp in spotPositions) {
      // 검은 점
      c.drawCircle(pos + sp, 1.8 * sc,
          Paint()..color = const Color(0xFF212121).withValues(alpha: alpha * 0.90));
      // 점 하이라이트 (반투명 흰색)
      c.drawCircle(
          pos + sp + Offset(0.5 * sc, -0.5 * sc),
          0.7 * sc,
          Paint()
            ..color = const Color(0x50FFFFFF).withValues(alpha: alpha * 0.60));
    }

    // ── 앞가슴판 (Pronotum) ──────────────────────────────────────────────────
    final pronPath = Path()
      ..moveTo(pos.dx - 6.5 * sc, pos.dy - 8.5 * sc)
      ..lineTo(pos.dx + 6.5 * sc, pos.dy - 8.5 * sc)
      ..lineTo(pos.dx + 4.5 * sc, pos.dy - 12 * sc)
      ..lineTo(pos.dx - 4.5 * sc, pos.dy - 12 * sc)
      ..close();
    c.drawPath(
        pronPath,
        Paint()
          ..color = const Color(0xFF212121).withValues(alpha: alpha * 0.92));

    // 앞가슴판 흰 볼 점 (2개)
    c.drawCircle(pos + Offset(-3.5 * sc, -10 * sc), 1.8 * sc,
        Paint()..color = const Color(0xFFF5F5F5).withValues(alpha: alpha * 0.85));
    c.drawCircle(pos + Offset(3.5 * sc, -10 * sc), 1.8 * sc,
        Paint()..color = const Color(0xFFF5F5F5).withValues(alpha: alpha * 0.85));

    // ── 머리 ─────────────────────────────────────────────────────────────────
    // 검은 반원
    c.drawArc(
      Rect.fromCenter(
          center: pos + Offset(0, -13.5 * sc), width: 8 * sc, height: 8 * sc),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF212121).withValues(alpha: alpha),
    );

    // 겹눈 (흰 점 2개)
    c.drawCircle(pos + Offset(-2.5 * sc, -13.5 * sc), 1.2 * sc,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.88));
    c.drawCircle(pos + Offset(2.5 * sc, -13.5 * sc), 1.2 * sc,
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.88));

    // ── 다리 (3쌍 6개) ────────────────────────────────────────────────────────
    final legPaint = Paint()
      ..color = const Color(0xFF212121).withValues(alpha: alpha * 0.65)
      ..strokeWidth = 1.0 * sc
      ..strokeCap = StrokeCap.round;

    final legYOffsets = [-3.0, 0.5, 4.0];
    for (int i = 0; i < 3; i++) {
      final ly = legYOffsets[i] * sc;
      for (final side in [-1.0, 1.0]) {
        // 2세그먼트 구부러진 다리
        final start = pos + Offset(side * 8.5 * sc, ly);
        final mid = pos + Offset(side * 13 * sc, ly + 2.5 * sc);
        final end = pos + Offset(side * 16 * sc, ly + 7 * sc);
        final legPath = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(mid.dx, mid.dy)
          ..lineTo(end.dx, end.dy);
        c.drawPath(legPath, legPaint);
      }
    }

    // ── 더듬이 (2개, 분절 느낌) ───────────────────────────────────────────────
    final antPaint = Paint()
      ..color = const Color(0xFF212121).withValues(alpha: alpha * 0.60)
      ..strokeWidth = 1.0 * sc
      ..strokeCap = StrokeCap.round;

    for (final side in [-1.0, 1.0]) {
      final base = pos + Offset(side * 2 * sc, -17.5 * sc);
      final mid = pos + Offset(side * 4.5 * sc, -21 * sc);
      final tip = pos + Offset(side * 6 * sc, -24 * sc);

      c.drawLine(base, mid, antPaint);
      c.drawLine(mid, tip, antPaint);

      // 분절 점 3개
      final segPaint = Paint()
        ..color = const Color(0xFF212121).withValues(alpha: alpha * 0.55);
      c.drawCircle(base, 0.8 * sc, segPaint);
      c.drawCircle(mid, 0.8 * sc, segPaint);
      c.drawCircle(tip, 0.8 * sc, segPaint);
    }
  }

  @override
  bool shouldRepaint(_CreaturePainter o) =>
      o.t != t || o.growthLevel != growthLevel;
}
