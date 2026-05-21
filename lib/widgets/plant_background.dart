import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../utils/time_weather_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 3단계 배경 (성장 레벨 기반)
//  lv  0–38  실내 창가 (화분)
//  lv 28–68  화단 (정원 밭)
//  lv 58–100 드넓은 들판·정원
// ─────────────────────────────────────────────────────────────────────────────

class PlantBackground extends StatelessWidget {
  final int growthLevel;
  final double windPhase; // 0–1, AnimationController.value
  const PlantBackground({
    super.key,
    required this.growthLevel,
    required this.windPhase,
  });

  @override
  Widget build(BuildContext context) {
    final sky = TimeWeatherTheme.get();
    return CustomPaint(
      painter: _BgPainter(growthLevel, windPhase, sky),
      size: Size.infinite,
    );
  }
}

// ─── Stage alphas ────────────────────────────────────────────────────────────
double _a1(int lv) => ((38 - lv) / 12.0).clamp(0.0, 1.0); // indoor
double _a2(int lv) {
  final fadeIn  = ((lv - 26) / 12.0).clamp(0.0, 1.0);
  final fadeOut = ((70 - lv) / 12.0).clamp(0.0, 1.0);
  return math.min(fadeIn, fadeOut); // garden
}
double _a3(int lv) => ((lv - 56) / 14.0).clamp(0.0, 1.0); // landscape

// ─────────────────────────────────────────────────────────────────────────────
class _BgPainter extends CustomPainter {
  final int lv;
  final double wt;  // wind phase
  final SkyTheme sky;
  const _BgPainter(this.lv, this.wt, this.sky);

  @override
  void paint(Canvas c, Size s) {
    final a1 = _a1(lv);
    final a2 = _a2(lv);
    final a3 = _a3(lv);

    if (a3 > 0.01) _drawLandscape(c, s, a3);
    if (a2 > 0.01) _drawGarden(c, s, a2);
    if (a1 > 0.01) _drawIndoor(c, s, a1);

    _drawMilestone(c, s);
  }

  // ── 배경 하늘 그라데이션 ──────────────────────────────────────────────────
  void _sky(Canvas c, Size s, double alpha) {
    final stops  = sky.colors;
    final colors = stops.map((col) => col.withValues(alpha: alpha)).toList();
    c.drawRect(
      Rect.fromLTWH(0, 0, s.width, s.height),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0),
          Offset(0, s.height),
          colors,
          const [0.0, 0.5, 1.0],
        ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAGE 1 — 실내 창가
  // ─────────────────────────────────────────────────────────────────────────
  void _drawIndoor(Canvas c, Size s, double a) {
    final w = s.width;
    final h = s.height;

    // 따뜻한 베이지 벽
    c.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, 0), Offset(0, h),
          [
            const Color(0xFFF5ECD7).withValues(alpha: a),
            const Color(0xFFEAD8B0).withValues(alpha: a),
          ],
        ),
    );

    // 창문 (상단 중앙)
    final wWin   = w * 0.70;
    final hWin   = h * 0.52;
    final wLeft  = (w - wWin) / 2;
    final wTop   = h * 0.02;
    final winRect = Rect.fromLTWH(wLeft, wTop, wWin, hWin);

    // 창문 하늘 (외부)
    final skyColors = sky.colors;
    c.drawRect(
      winRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, wTop), Offset(0, wTop + hWin),
          [
            skyColors[0].withValues(alpha: a),
            skyColors[1].withValues(alpha: a),
            skyColors[2].withValues(alpha: a),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );

    // 창문 밖 간단한 풍경 — 지평선 녹색 언덕
    final horizY = wTop + hWin * 0.70;
    final hillPath = Path()
      ..moveTo(wLeft, h)
      ..lineTo(wLeft, horizY + hWin * 0.06)
      ..quadraticBezierTo(wLeft + wWin * 0.22, horizY - hWin * 0.10,
          wLeft + wWin * 0.50, horizY + hWin * 0.02)
      ..quadraticBezierTo(wLeft + wWin * 0.78, horizY + hWin * 0.12,
          wLeft + wWin, horizY + hWin * 0.04)
      ..lineTo(wLeft + wWin, h)
      ..close();
    c.drawPath(
      hillPath,
      Paint()..color = const Color(0xFF7CBF68).withValues(alpha: a),
    );

    // 창문 테두리 (목재 느낌)
    final framePaint = Paint()
      ..color = const Color(0xFFB8906A).withValues(alpha: a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.028;
    c.drawRect(winRect, framePaint);

    // 창문 십자 가로대
    final crossPaint = Paint()
      ..color = const Color(0xFFB8906A).withValues(alpha: a)
      ..strokeWidth = w * 0.016;
    final midX = wLeft + wWin / 2;
    final midY = wTop + hWin / 2;
    c.drawLine(Offset(midX, wTop), Offset(midX, wTop + hWin), crossPaint);
    c.drawLine(Offset(wLeft, midY), Offset(wLeft + wWin, midY), crossPaint);

    // 커튼 (좌·우)
    _curtain(c, s, wLeft - w * 0.04, wLeft + w * 0.09, wTop, hWin, a, left: true);
    _curtain(c, s, wLeft + wWin - w * 0.09, wLeft + wWin + w * 0.04, wTop, hWin, a, left: false);

    // 창틀 아래 선반/테이블
    final tableTop = wTop + hWin + w * 0.025;
    final tableH   = h * 0.09;
    c.drawRect(
      Rect.fromLTWH(0, tableTop, w, tableH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, tableTop), Offset(0, tableTop + tableH),
          [
            const Color(0xFFD4A96A).withValues(alpha: a),
            const Color(0xFFC08850).withValues(alpha: a),
          ],
        ),
    );
    // 테이블 앞면
    c.drawRect(
      Rect.fromLTWH(0, tableTop + tableH, w, h * 0.015),
      Paint()..color = const Color(0xFF9A6635).withValues(alpha: a),
    );

    // 바닥
    c.drawRect(
      Rect.fromLTWH(0, tableTop + tableH + h * 0.015, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, tableTop + tableH), Offset(0, h),
          [
            const Color(0xFFDEB887).withValues(alpha: a * 0.6),
            const Color(0xFFC49A6C).withValues(alpha: a * 0.3),
          ],
        ),
    );
  }

  void _curtain(Canvas c, Size s, double x0, double x1, double top, double len,
      double a, {required bool left}) {
    final w = x1 - x0;
    final path = Path()..moveTo(x0, top);
    // 물결 모양 커튼
    const waves = 4;
    for (int i = 0; i < waves; i++) {
      final t0 = i / waves;
      final t1 = (i + 1) / waves;
      final yMid = top + len * (t0 + t1) / 2;
      final xBulge = left ? x1 + w * 0.22 : x0 - w * 0.22;
      path.quadraticBezierTo(xBulge, yMid, x0 + (left ? w : 0), top + len * t1);
    }
    path..lineTo(x1, top + len)..lineTo(x1, top)..close();
    c.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x0, top), Offset(x1, top),
          [
            const Color(0xFFF8E8D0).withValues(alpha: a),
            const Color(0xFFE8C896).withValues(alpha: a),
          ],
        ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAGE 2 — 화단
  // ─────────────────────────────────────────────────────────────────────────
  void _drawGarden(Canvas c, Size s, double a) {
    final w = s.width;
    final h = s.height;
    final groundY = h * 0.72;

    // 하늘
    _sky(c, s, a);

    // 완만한 언덕
    final hill = Path()
      ..moveTo(0, h)
      ..lineTo(0, groundY + h * 0.04)
      ..quadraticBezierTo(w * 0.28, groundY - h * 0.08, w * 0.55, groundY + h * 0.02)
      ..quadraticBezierTo(w * 0.78, groundY + h * 0.09, w, groundY + h * 0.03)
      ..lineTo(w, h)
      ..close();
    c.drawPath(
      hill,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, groundY), Offset(0, h),
          [
            const Color(0xFF6BAF52).withValues(alpha: a),
            const Color(0xFF4A8A38).withValues(alpha: a),
          ],
        ),
    );

    // 화단 (나무 테두리)
    final bedTop   = h * 0.75;
    final bedH     = h * 0.14;
    final bedPad   = w * 0.06;
    c.drawRect(
      Rect.fromLTWH(bedPad, bedTop, w - bedPad * 2, bedH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, bedTop), Offset(0, bedTop + bedH),
          [
            const Color(0xFF5C3A1E).withValues(alpha: a),
            const Color(0xFF3D2210).withValues(alpha: a),
          ],
        ),
    );
    // 나무 테두리
    final borderPaint = Paint()
      ..color = const Color(0xFF8B5E3C).withValues(alpha: a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.022;
    c.drawRect(
      Rect.fromLTWH(bedPad, bedTop, w - bedPad * 2, bedH),
      borderPaint,
    );
    // 흙
    c.drawRect(
      Rect.fromLTWH(bedPad + 3, bedTop + 3, w - bedPad * 2 - 6, bedH - 6),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, bedTop), Offset(0, bedTop + bedH),
          [
            const Color(0xFF5E3A18).withValues(alpha: a),
            const Color(0xFF3A2010).withValues(alpha: a),
          ],
        ),
    );

    // 작은 꽃들 (화단 옆)
    final rng = math.Random(42);
    for (int i = 0; i < 8; i++) {
      final fx = bedPad + (w - bedPad * 2) * (i + 1) / 9.0;
      _miniFlower(c, Offset(fx, bedTop - h * 0.01), h * 0.06, a, rng);
    }

    // 풀잎들
    for (int i = 0; i < 14; i++) {
      final gx = w * (i + 0.5) / 14.0;
      final gy = groundY + h * 0.02 + (rng.nextDouble() - 0.5) * h * 0.01;
      _grass(c, Offset(gx, gy), h * 0.06 * (0.6 + rng.nextDouble() * 0.8),
          a, rng);
    }
  }

  void _miniFlower(Canvas c, Offset pos, double sz, double a, math.Random rng) {
    final cols = [
      const Color(0xFFFF6B9D),
      const Color(0xFFFFD700),
      const Color(0xFFFF8C42),
      const Color(0xFFAD49E8),
      const Color(0xFFFF4444),
    ];
    final col = cols[rng.nextInt(cols.length)];
    // 줄기
    c.drawLine(
      pos,
      pos + Offset(0, sz),
      Paint()
        ..color = const Color(0xFF4CAF50).withValues(alpha: a)
        ..strokeWidth = sz * 0.08,
    );
    // 꽃잎
    for (int p = 0; p < 5; p++) {
      final ang = p * 2 * math.pi / 5;
      final tip = pos + Offset(math.cos(ang) * sz * 0.52, math.sin(ang) * sz * 0.52);
      c.drawOval(
        Rect.fromCenter(
          center: Offset((pos.dx + tip.dx) / 2, (pos.dy + tip.dy) / 2),
          width: sz * 0.36,
          height: sz * 0.36,
        ),
        Paint()..color = col.withValues(alpha: a * 0.9),
      );
    }
    // 꽃심
    c.drawCircle(pos, sz * 0.18,
        Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: a));
  }

  void _grass(Canvas c, Offset base, double h, double a, math.Random rng) {
    final sway = (rng.nextDouble() - 0.5) * 0.3;
    final ctrl = base + Offset(h * sway, -h * 0.5);
    final tip  = base + Offset(h * sway * 2, -h);
    final path = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy);
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF66BB6A).withValues(alpha: a * 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.05
        ..strokeCap = StrokeCap.round,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAGE 3 — 드넓은 들판
  // ─────────────────────────────────────────────────────────────────────────
  void _drawLandscape(Canvas c, Size s, double a) {
    final w = s.width;
    final h = s.height;
    final horizY = h * 0.58;

    // 하늘
    _sky(c, s, a);

    // 구름 (windPhase로 천천히 이동)
    _clouds(c, s, a);

    // 먼 산 실루엣
    _mountains(c, w, h, horizY, a);

    // 수목선 (지평선 언덕)
    _treeline(c, w, horizY, a);

    // 초원 (녹색 경사)
    final meadow = Path()
      ..moveTo(0, h)
      ..lineTo(0, horizY + h * 0.03)
      ..quadraticBezierTo(w * 0.35, horizY - h * 0.04,
          w * 0.60, horizY + h * 0.02)
      ..quadraticBezierTo(w * 0.82, horizY + h * 0.07,
          w, horizY + h * 0.01)
      ..lineTo(w, h)
      ..close();
    c.drawPath(
      meadow,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizY), Offset(0, h),
          [
            const Color(0xFF7DC455).withValues(alpha: a),
            const Color(0xFF4E9028).withValues(alpha: a),
            const Color(0xFF3A7020).withValues(alpha: a),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );

    // 구불구불한 오솔길
    _path(c, w, h, horizY, a);

    // 들꽃
    final rng = math.Random(77);
    for (int i = 0; i < 18; i++) {
      final fx = w * (i + 0.3) / 18 + (rng.nextDouble() - 0.5) * w * 0.04;
      final fy = horizY + h * 0.15 + rng.nextDouble() * h * 0.18;
      _miniFlower(c, Offset(fx, fy), h * 0.05 * (0.5 + rng.nextDouble() * 0.8),
          a, rng);
    }

    // 풀잎들
    for (int i = 0; i < 22; i++) {
      final gx = w * (i + 0.5) / 22.0;
      final gy = horizY + h * 0.08 + (rng.nextDouble() - 0.5) * h * 0.02;
      _grass(c, Offset(gx, gy), h * 0.07 * (0.6 + rng.nextDouble() * 0.9),
          a, rng);
    }
  }

  void _clouds(Canvas c, Size s, double a) {
    final w = s.width;
    final h = s.height;
    // 구름 3개 — windPhase로 좌우 이동 (느리게)
    final offsets = [
      Offset(w * 0.15 + w * 0.08 * math.sin(wt * math.pi * 2), h * 0.10),
      Offset(w * 0.55 + w * 0.06 * math.cos(wt * math.pi * 2 + 1.0), h * 0.07),
      Offset(w * 0.82 + w * 0.05 * math.sin(wt * math.pi * 2 + 2.0), h * 0.13),
    ];
    final scales = [0.9, 1.15, 0.75];
    for (int i = 0; i < offsets.length; i++) {
      _cloud(c, offsets[i], w * 0.14 * scales[i], a * 0.82);
    }
  }

  void _cloud(Canvas c, Offset center, double r, double a) {
    final paint = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a);
    c.drawCircle(center, r, paint);
    c.drawCircle(center + Offset(-r * 0.72, r * 0.1), r * 0.72, paint);
    c.drawCircle(center + Offset(r * 0.72, r * 0.1), r * 0.72, paint);
    c.drawCircle(center + Offset(-r * 1.28, r * 0.35), r * 0.52, paint);
    c.drawCircle(center + Offset(r * 1.28, r * 0.35), r * 0.52, paint);
  }

  void _mountains(Canvas c, double w, double h, double horizY, double a) {
    // 뒷 산 (연한 청회색)
    final back = Path()
      ..moveTo(0, horizY + h * 0.02)
      ..lineTo(w * 0.10, horizY - h * 0.20)
      ..lineTo(w * 0.28, horizY + h * 0.01)
      ..lineTo(w * 0.42, horizY - h * 0.28)
      ..lineTo(w * 0.55, horizY - h * 0.06)
      ..lineTo(w * 0.65, horizY - h * 0.18)
      ..lineTo(w * 0.80, horizY + h * 0.02)
      ..lineTo(w * 0.92, horizY - h * 0.14)
      ..lineTo(w, horizY + h * 0.01)
      ..lineTo(w, horizY + h * 0.06)
      ..lineTo(0, horizY + h * 0.06)
      ..close();
    c.drawPath(back,
        Paint()..color = const Color(0xFF90A4AE).withValues(alpha: a * 0.55));

    // 앞 산 (청록)
    final front = Path()
      ..moveTo(0, horizY + h * 0.04)
      ..lineTo(w * 0.18, horizY - h * 0.12)
      ..lineTo(w * 0.32, horizY + h * 0.02)
      ..lineTo(w * 0.50, horizY - h * 0.18)
      ..lineTo(w * 0.68, horizY + h * 0.01)
      ..lineTo(w * 0.84, horizY - h * 0.09)
      ..lineTo(w, horizY + h * 0.04)
      ..close();
    c.drawPath(
      front,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizY - h * 0.18), Offset(0, horizY + h * 0.04),
          [
            const Color(0xFF5B8C5A).withValues(alpha: a * 0.80),
            const Color(0xFF3D6E3C).withValues(alpha: a * 0.80),
          ],
        ),
    );
  }

  void _treeline(Canvas c, double w, double horizY, double a) {
    final rng = math.Random(11);
    for (int i = 0; i < 18; i++) {
      final tx  = w * (i + 0.5) / 18.0 + (rng.nextDouble() - 0.5) * w * 0.04;
      final th  = 0.06 + rng.nextDouble() * 0.06;
      final top = horizY - w * th;
      final trunkW = w * 0.008;
      // 나무 몸통
      c.drawRect(
        Rect.fromCenter(center: Offset(tx, horizY), width: trunkW, height: horizY - top),
        Paint()..color = const Color(0xFF4A2E1A).withValues(alpha: a * 0.7),
      );
      // 나무 왕관
      c.drawCircle(
        Offset(tx, top + w * th * 0.4),
        w * th * 0.48,
        Paint()
          ..color = Color.lerp(
            const Color(0xFF2E7D32),
            const Color(0xFF558B2F),
            rng.nextDouble(),
          )!.withValues(alpha: a * 0.80),
      );
    }
  }

  void _path(Canvas c, double w, double h, double horizY, double a) {
    final path = Path()
      ..moveTo(w * 0.46, h)
      ..cubicTo(
        w * 0.44, h * 0.86,
        w * 0.50, h * 0.78,
        w * 0.53, horizY + h * 0.18,
      )
      ..cubicTo(
        w * 0.55, horizY + h * 0.10,
        w * 0.52, horizY + h * 0.06,
        w * 0.50, horizY + h * 0.04,
      );
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD4A96A).withValues(alpha: a * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.055
        ..strokeCap = StrokeCap.round,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 마일스톤 텍스트 오버레이
  // ─────────────────────────────────────────────────────────────────────────
  void _drawMilestone(Canvas c, Size s) {
    String? text;
    double fadeA = 0;

    if (lv <= 8) {
      text = '🌱 씨앗을 심었어요';
      fadeA = (1 - lv / 8.0).clamp(0.0, 1.0) * 0.9;
    } else if (lv <= 18) {
      text = '🌿 새싹이 돋아나고 있어요';
      final t = ((lv - 8) / 10.0).clamp(0.0, 1.0);
      fadeA = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0) * 0.9;
    } else if (lv >= 28 && lv <= 42) {
      text = '🏡 화단으로 옮겨 심었어요';
      final t = ((lv - 28) / 14.0).clamp(0.0, 1.0);
      fadeA = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0) * 0.9;
    } else if (lv >= 48 && lv <= 62) {
      text = '🪴 분갈이를 해줬어요';
      final t = ((lv - 48) / 14.0).clamp(0.0, 1.0);
      fadeA = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0) * 0.9;
    } else if (lv >= 60 && lv <= 74) {
      text = '🌳 드넓은 정원으로 이사했어요';
      final t = ((lv - 60) / 14.0).clamp(0.0, 1.0);
      fadeA = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0) * 0.9;
    }

    if (text == null || fadeA < 0.02) return;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: s.width * 0.042,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: fadeA),
          shadows: [
            Shadow(
              blurRadius: 8,
              color: Colors.black.withValues(alpha: fadeA * 0.55),
              offset: const Offset(1, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: s.width * 0.85);

    tp.paint(
      c,
      Offset((s.width - tp.width) / 2, s.height * 0.12),
    );
  }

  @override
  bool shouldRepaint(_BgPainter o) =>
      o.lv != lv || o.wt != wt;
}
