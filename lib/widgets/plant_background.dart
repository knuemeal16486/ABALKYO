import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../utils/time_weather_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 3단계 배경 (성장 레벨 기반)
//  lv  0–38  실내 창가 (화분)
//  lv 28–68  화단 (정원 밭)
//  lv 58–100 드넓은 들판·정원
//
// groundY는 _ScenePainter와 동일한 공식으로 계산해 3D 식물 바닥과 정렬.
//   fit     = (h / 580).clamp(0.45, 2.0)
//   groundY = h - 65 * fit
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
  final double wt;  // wind phase 0–1
  final SkyTheme sky;

  _BgPainter(this.lv, this.wt, this.sky);

  // 3D 씬과 동일한 groundY 계산
  static double _groundY(double h) {
    final fit = (h / 580).clamp(0.45, 2.0);
    return h - 65 * fit;
  }

  @override
  void paint(Canvas c, Size s) {
    final a1 = _a1(lv);
    final a2 = _a2(lv);
    final a3 = _a3(lv);

    // 뒤에서 앞 순서로 그림
    if (a3 > 0.01) _drawLandscape(c, s, a3);
    if (a2 > 0.01) _drawGarden(c, s, a2);
    if (a1 > 0.01) _drawIndoor(c, s, a1);

    _drawMilestone(c, s);
  }

  // ── 하늘 그라데이션 (지평선까지만) ──────────────────────────────────────────
  void _sky(Canvas c, Size s, double alpha, double horizY) {
    final colors = sky.colors.map((col) => col.withValues(alpha: alpha)).toList();
    c.drawRect(
      Rect.fromLTWH(0, 0, s.width, horizY),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, horizY),
          colors,
          const [0.0, 0.5, 1.0],
        ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAGE 1 — 실내 창가
  //   groundY = 화분이 놓인 선반 윗면
  //   선반 아래 = 바닥
  //   선반 위   = 벽 + 창문
  // ─────────────────────────────────────────────────────────────────────────
  void _drawIndoor(Canvas c, Size s, double a) {
    final w  = s.width;
    final h  = s.height;
    final gy = _groundY(h); // 3D groundY와 동일

    // 벽 (전체)
    c.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0), Offset(0, h),
          [
            const Color(0xFFF5ECD7).withValues(alpha: a),
            const Color(0xFFEAD8B0).withValues(alpha: a),
          ],
        ),
    );

    // 창문 — 벽의 상단 70%를 차지, 좌우 여백
    final wWin  = w * 0.68;
    final hWin  = gy * 0.82; // groundY 기준으로 창문 높이 결정
    final wLeft = (w - wWin) / 2;
    final wTop  = h * 0.025;
    final winRect = Rect.fromLTWH(wLeft, wTop, wWin, hWin);

    // 창밖 하늘
    c.drawRect(
      winRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(wLeft, wTop), Offset(wLeft, wTop + hWin),
          [
            sky.colors[0].withValues(alpha: a),
            sky.colors[1].withValues(alpha: a),
            sky.colors[2].withValues(alpha: a),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // 창밖 언덕
    final horizY = wTop + hWin * 0.72;
    final hillPath = Path()
      ..moveTo(wLeft, h)
      ..lineTo(wLeft, horizY + hWin * 0.05)
      ..quadraticBezierTo(wLeft + wWin * 0.20, horizY - hWin * 0.12,
          wLeft + wWin * 0.50, horizY + hWin * 0.01)
      ..quadraticBezierTo(wLeft + wWin * 0.80, horizY + hWin * 0.13,
          wLeft + wWin, horizY + hWin * 0.03)
      ..lineTo(wLeft + wWin, h)
      ..close();
    c.drawPath(hillPath,
        Paint()..color = const Color(0xFF7CBF68).withValues(alpha: a));

    // 창틀 (목재)
    c.drawRect(
      winRect,
      Paint()
        ..color = const Color(0xFFB8906A).withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.026,
    );

    // 창문 십자 가로대
    final crossP = Paint()
      ..color = const Color(0xFFB8906A).withValues(alpha: a)
      ..strokeWidth = w * 0.014;
    c.drawLine(Offset(wLeft + wWin / 2, wTop),
        Offset(wLeft + wWin / 2, wTop + hWin), crossP);
    c.drawLine(Offset(wLeft, wTop + hWin / 2),
        Offset(wLeft + wWin, wTop + hWin / 2), crossP);

    // 커튼 (좌·우)
    _curtain(c, wLeft - w * 0.02, wLeft + w * 0.10,
        wTop, hWin, a, left: true);
    _curtain(c, wLeft + wWin - w * 0.10, wLeft + wWin + w * 0.02,
        wTop, hWin, a, left: false);

    // 선반/창틀 (groundY 위치) — 화분이 여기에 놓임
    final shelfH = h * 0.048;
    c.drawRect(
      Rect.fromLTWH(0, gy - shelfH * 0.1, w, shelfH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, gy), Offset(0, gy + shelfH),
          [
            const Color(0xFFD4A96A).withValues(alpha: a),
            const Color(0xFFC08850).withValues(alpha: a),
          ],
        ),
    );
    // 선반 앞면 (어두운 가장자리)
    c.drawRect(
      Rect.fromLTWH(0, gy + shelfH * 0.88, w, shelfH * 0.16),
      Paint()..color = const Color(0xFF9A6635).withValues(alpha: a),
    );

    // 바닥
    c.drawRect(
      Rect.fromLTWH(0, gy + shelfH, w, h - gy - shelfH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, gy + shelfH), Offset(0, h),
          [
            const Color(0xFFDEB887).withValues(alpha: a * 0.55),
            const Color(0xFFC49A6C).withValues(alpha: a * 0.25),
          ],
        ),
    );
  }

  void _curtain(Canvas c, double x0, double x1, double top, double len,
      double a, {required bool left}) {
    const waves = 4;
    final w = x1 - x0;
    final path = Path()..moveTo(x0, top);
    for (int i = 0; i < waves; i++) {
      final t1   = (i + 1) / waves;
      final yMid = top + len * ((i + 0.5) / waves);
      final xB   = left ? x1 + w * 0.28 : x0 - w * 0.28;
      path.quadraticBezierTo(xB, yMid, left ? x0 + w : x0, top + len * t1);
    }
    path
      ..lineTo(x1, top + len)
      ..lineTo(x1, top)
      ..close();
    c.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x0, top), Offset(x1, top),
          [
            const Color(0xFFF8E8D0).withValues(alpha: a * 0.95),
            const Color(0xFFE8C896).withValues(alpha: a * 0.95),
          ],
        ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAGE 2 — 화단
  //   groundY = 흙 표면 (식물 뿌리가 내려가는 곳)
  //   위 = 하늘 + 언덕 + 풀
  //   아래 = 화단 흙
  // ─────────────────────────────────────────────────────────────────────────
  void _drawGarden(Canvas c, Size s, double a) {
    final w  = s.width;
    final h  = s.height;
    final gy = _groundY(h);

    // 지평선 = groundY 위 30%
    final horizY = gy - h * 0.28;

    // 하늘
    _sky(c, s, a, horizY);

    // 언덕 (지평선~groundY)
    final hill = Path()
      ..moveTo(0, h)
      ..lineTo(0, horizY + h * 0.03)
      ..quadraticBezierTo(w * 0.25, horizY - h * 0.06,
          w * 0.52, horizY + h * 0.01)
      ..quadraticBezierTo(w * 0.78, horizY + h * 0.08,
          w, horizY + h * 0.02)
      ..lineTo(w, h)
      ..close();
    c.drawPath(
      hill,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizY), Offset(0, gy),
          [
            const Color(0xFF6BAF52).withValues(alpha: a),
            const Color(0xFF4E9830).withValues(alpha: a),
          ],
        ),
    );

    // 화단 흙 (groundY 아래)
    final bedPad = w * 0.05;
    // 테두리 나무판
    c.drawRect(
      Rect.fromLTWH(bedPad, gy - h * 0.015, w - bedPad * 2, h * 0.022),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, gy - h * 0.015), Offset(0, gy + h * 0.007),
          [
            const Color(0xFF8B5E3C).withValues(alpha: a),
            const Color(0xFF6B3D1E).withValues(alpha: a),
          ],
        ),
    );
    // 흙
    c.drawRect(
      Rect.fromLTWH(0, gy + h * 0.007, w, h - gy),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, gy), Offset(0, h),
          [
            const Color(0xFF5C3A1E).withValues(alpha: a),
            const Color(0xFF3D2210).withValues(alpha: a),
          ],
        ),
    );

    // 풀잎들 (지평선 부근)
    final rng = math.Random(42);
    for (int i = 0; i < 18; i++) {
      final gx = w * (i + 0.5) / 18.0 + (rng.nextDouble() - 0.5) * w * 0.025;
      final gy2 = horizY + h * 0.02 + (rng.nextDouble() - 0.5) * h * 0.01;
      _grass(c, Offset(gx, gy2),
          h * 0.055 * (0.6 + rng.nextDouble() * 0.9), a, rng);
    }

    // 화단 꽃들
    for (int i = 0; i < 7; i++) {
      final fx = bedPad + (w - bedPad * 2) * (i + 1) / 8.0;
      _miniFlower(c, Offset(fx, gy - h * 0.024), h * 0.07, a, rng);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAGE 3 — 드넓은 들판
  //   groundY = 초원 표면
  //   위 = 하늘 + 구름 + 산 + 수목선
  //   아래 = 초원 + 오솔길 + 들꽃
  // ─────────────────────────────────────────────────────────────────────────
  void _drawLandscape(Canvas c, Size s, double a) {
    final w  = s.width;
    final h  = s.height;
    final gy = _groundY(h);

    // 지평선 = groundY보다 훨씬 위 (멀리 보임)
    final horizY = gy - h * 0.38;

    // 하늘
    _sky(c, s, a, horizY + h * 0.05);

    // 구름 (windPhase로 천천히 이동)
    _clouds(c, s, a, horizY);

    // 먼 산 실루엣
    _mountains(c, w, horizY, a);

    // 수목선
    _treeline(c, w, horizY, a);

    // 초원 (horizY~h)
    final meadow = Path()
      ..moveTo(0, h)
      ..lineTo(0, horizY + h * 0.02)
      ..quadraticBezierTo(w * 0.30, horizY - h * 0.03,
          w * 0.58, horizY + h * 0.01)
      ..quadraticBezierTo(w * 0.82, horizY + h * 0.06,
          w, horizY)
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
          const [0.0, 0.45, 1.0],
        ),
    );

    // groundY 부근 흙 표면 띠 (화분이 묻힌 자리)
    c.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, gy + h * 0.008),
        width: w * 0.55,
        height: h * 0.028,
      ),
      Paint()..color = const Color(0xFF4A2E1A).withValues(alpha: a * 0.45),
    );

    // 오솔길
    _wPath(c, w, h, horizY, gy, a);

    // 들꽃
    final rng = math.Random(77);
    for (int i = 0; i < 20; i++) {
      final fx = w * (i + 0.3) / 20 + (rng.nextDouble() - 0.5) * w * 0.04;
      final fy = gy + h * 0.05 + rng.nextDouble() * (h - gy - h * 0.04);
      if ((fx - w / 2).abs() > w * 0.18) { // 식물 바로 아래 회피
        _miniFlower(c, Offset(fx, fy),
            h * 0.045 * (0.5 + rng.nextDouble() * 0.9), a, rng);
      }
    }
    // 풀잎
    for (int i = 0; i < 24; i++) {
      final gx = w * (i + 0.5) / 24.0;
      final gy2 = horizY + h * 0.04 + (rng.nextDouble() - 0.5) * h * 0.015;
      _grass(c, Offset(gx, gy2),
          h * 0.06 * (0.5 + rng.nextDouble()), a, rng);
    }
  }

  void _clouds(Canvas c, Size s, double a, double horizY) {
    final w = s.width;
    final cloudY = horizY * 0.42;
    final offsets = [
      Offset(w * 0.14 + w * 0.07 * math.sin(wt * math.pi * 2), cloudY),
      Offset(w * 0.56 + w * 0.05 * math.cos(wt * math.pi * 2 + 1.2), cloudY * 0.72),
      Offset(w * 0.83 + w * 0.06 * math.sin(wt * math.pi * 2 + 2.4), cloudY * 1.15),
    ];
    final scales = [0.95, 1.20, 0.70];
    for (int i = 0; i < offsets.length; i++) {
      _cloud(c, offsets[i], w * 0.13 * scales[i], a * 0.80);
    }
  }

  void _cloud(Canvas c, Offset center, double r, double a) {
    final p = Paint()..color = Colors.white.withValues(alpha: a);
    c.drawCircle(center, r, p);
    c.drawCircle(center + Offset(-r * 0.70, r * 0.12), r * 0.72, p);
    c.drawCircle(center + Offset(r * 0.70, r * 0.12), r * 0.72, p);
    c.drawCircle(center + Offset(-r * 1.26, r * 0.38), r * 0.50, p);
    c.drawCircle(center + Offset(r * 1.26, r * 0.38), r * 0.50, p);
  }

  void _mountains(Canvas c, double w, double horizY, double a) {
    // 뒤쪽 산 (연한 청회색)
    final back = Path()
      ..moveTo(0, horizY + 2)
      ..lineTo(w * 0.10, horizY - w * 0.085)
      ..lineTo(w * 0.26, horizY + 2)
      ..lineTo(w * 0.42, horizY - w * 0.12)
      ..lineTo(w * 0.55, horizY - w * 0.02)
      ..lineTo(w * 0.66, horizY - w * 0.075)
      ..lineTo(w * 0.82, horizY + 2)
      ..lineTo(w * 0.92, horizY - w * 0.058)
      ..lineTo(w, horizY + 2)
      ..close();
    c.drawPath(back,
        Paint()..color = const Color(0xFF90A4AE).withValues(alpha: a * 0.52));

    // 앞쪽 산 (청록)
    final front = Path()
      ..moveTo(0, horizY + 4)
      ..lineTo(w * 0.16, horizY - w * 0.05)
      ..lineTo(w * 0.32, horizY + 4)
      ..lineTo(w * 0.50, horizY - w * 0.08)
      ..lineTo(w * 0.68, horizY + 4)
      ..lineTo(w * 0.84, horizY - w * 0.04)
      ..lineTo(w, horizY + 4)
      ..close();
    c.drawPath(
      front,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizY - w * 0.08), Offset(0, horizY + 4),
          [
            const Color(0xFF5B8C5A).withValues(alpha: a * 0.78),
            const Color(0xFF3D6E3C).withValues(alpha: a * 0.78),
          ],
        ),
    );
  }

  void _treeline(Canvas c, double w, double horizY, double a) {
    final rng = math.Random(11);
    for (int i = 0; i < 20; i++) {
      final tx = w * (i + 0.5) / 20.0 + (rng.nextDouble() - 0.5) * w * 0.03;
      final th = w * (0.055 + rng.nextDouble() * 0.055);
      final top = horizY - th;
      final trunkW = w * 0.007;
      c.drawRect(
        Rect.fromCenter(center: Offset(tx, horizY - th * 0.15),
            width: trunkW, height: th * 0.35),
        Paint()..color = const Color(0xFF4A2E1A).withValues(alpha: a * 0.65),
      );
      c.drawCircle(
        Offset(tx, top + th * 0.42),
        th * 0.50,
        Paint()
          ..color = Color.lerp(const Color(0xFF2E7D32), const Color(0xFF558B2F),
              rng.nextDouble())!.withValues(alpha: a * 0.78),
      );
    }
  }

  void _wPath(Canvas c, double w, double h, double horizY, double gy, double a) {
    final path = Path()
      ..moveTo(w * 0.44, h)
      ..cubicTo(w * 0.43, h * 0.88, w * 0.49, gy + h * 0.14, w * 0.52, gy + h * 0.07)
      ..cubicTo(w * 0.54, gy + h * 0.04, w * 0.51, gy + h * 0.015, w * 0.49, horizY + h * 0.08);
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD4A96A).withValues(alpha: a * 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.052
        ..strokeCap = StrokeCap.round,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 공통 헬퍼
  // ─────────────────────────────────────────────────────────────────────────
  void _miniFlower(Canvas c, Offset pos, double sz, double a, math.Random rng) {
    const cols = [
      Color(0xFFFF6B9D), Color(0xFFFFD700),
      Color(0xFFFF8C42), Color(0xFFAD49E8), Color(0xFFFF4444),
    ];
    final col = cols[rng.nextInt(cols.length)];
    // 줄기 (위로)
    c.drawLine(
      pos, pos + Offset(0, sz * 0.55),
      Paint()
        ..color = const Color(0xFF4CAF50).withValues(alpha: a)
        ..strokeWidth = sz * 0.09
        ..strokeCap = StrokeCap.round,
    );
    // 꽃잎
    for (int p = 0; p < 5; p++) {
      final ang = p * 2 * math.pi / 5;
      final tip = pos + Offset(math.cos(ang) * sz * 0.50, math.sin(ang) * sz * 0.50);
      c.drawOval(
        Rect.fromCenter(
          center: Offset((pos.dx + tip.dx) / 2, (pos.dy + tip.dy) / 2),
          width: sz * 0.38, height: sz * 0.38,
        ),
        Paint()..color = col.withValues(alpha: a * 0.88),
      );
    }
    c.drawCircle(pos, sz * 0.17,
        Paint()..color = const Color(0xFFFFEB3B).withValues(alpha: a));
  }

  void _grass(Canvas c, Offset base, double len, double a, math.Random rng) {
    final sway = (rng.nextDouble() - 0.5) * 0.35;
    final ctrl = base + Offset(len * sway, -len * 0.52);
    final tip  = base + Offset(len * sway * 2, -len);
    c.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy),
      Paint()
        ..color = const Color(0xFF66BB6A).withValues(alpha: a * 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = len * 0.055
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
      text  = '🌱 씨앗을 심었어요';
      fadeA = ((8 - lv) / 8.0).clamp(0.0, 1.0) * 0.85;
    } else if (lv <= 20) {
      text  = '🌿 새싹이 돋아나고 있어요';
      final t = ((lv - 8) / 12.0).clamp(0.0, 1.0);
      fadeA   = (t < 0.5 ? t * 2 : (1 - t) * 2) * 0.85;
    } else if (lv >= 28 && lv <= 44) {
      text  = '🏡 화단으로 옮겨 심었어요';
      final t = ((lv - 28) / 16.0).clamp(0.0, 1.0);
      fadeA   = (t < 0.5 ? t * 2 : (1 - t) * 2) * 0.85;
    } else if (lv >= 48 && lv <= 62) {
      text  = '🪴 분갈이를 해줬어요';
      final t = ((lv - 48) / 14.0).clamp(0.0, 1.0);
      fadeA   = (t < 0.5 ? t * 2 : (1 - t) * 2) * 0.85;
    } else if (lv >= 60 && lv <= 76) {
      text  = '🌳 드넓은 정원으로 이사했어요';
      final t = ((lv - 60) / 16.0).clamp(0.0, 1.0);
      fadeA   = (t < 0.5 ? t * 2 : (1 - t) * 2) * 0.85;
    }

    if (text == null || fadeA < 0.02) return;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: s.width * 0.043,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: fadeA),
          shadows: [
            Shadow(
              blurRadius: 10,
              color: Colors.black.withValues(alpha: fadeA * 0.60),
              offset: const Offset(1, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: s.width * 0.85);

    tp.paint(c, Offset((s.width - tp.width) / 2, s.height * 0.11));
  }

  @override
  bool shouldRepaint(_BgPainter o) =>
      o.lv != lv || o.wt != wt || o.sky != sky;
}
