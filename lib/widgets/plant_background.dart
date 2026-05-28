import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../utils/time_weather_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 고정 야외 배경 (성장 단계 무관, 항상 같은 야외 씬)
//   하늘: TimeWeatherTheme (시간/날씨 반영)
//   구름: windPhase로 천천히 이동
//   원거리 산: 삼각형 폴리곤
//   수목선: 삼각형 나무들
//   초원: 폴리곤 3겹
//   들꽃: 가장자리 삼각형 꽃잎 + windPhase 흔들림
// ─────────────────────────────────────────────────────────────────────────────
class PlantBackground extends StatelessWidget {
  final int growthLevel; // API 호환 유지, 씬 선택에 미사용
  final double windPhase;
  const PlantBackground({
    super.key,
    required this.growthLevel,
    required this.windPhase,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OutdoorPainter(windPhase, TimeWeatherTheme.get()),
      size: Size.infinite,
    );
  }
}

class _OutdoorPainter extends CustomPainter {
  final double wt;
  final SkyTheme sky;
  _OutdoorPainter(this.wt, this.sky);

  @override
  bool shouldRepaint(_OutdoorPainter o) => o.wt != wt || o.sky != sky;

  static double _groundY(double h) {
    final fit = (h / 580).clamp(0.45, 2.0);
    return h - 65 * fit;
  }

  void _tri(Canvas c, Offset a, Offset b, Offset pt, Color col) {
    c.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(pt.dx, pt.dy)
        ..close(),
      Paint()..color = col,
    );
  }

  void _poly(Canvas c, List<Offset> pts, Color col) {
    if (pts.length < 3) return;
    final p = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) p.lineTo(pts[i].dx, pts[i].dy);
    p.close();
    c.drawPath(p, Paint()..color = col);
  }

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final gy = _groundY(h);
    final horizY = gy - h * 0.36;

    // 1. 하늘
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizY + h * 0.05),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, horizY + h * 0.05),
          sky.colors,
          const [0.0, 0.5, 1.0],
        ),
    );

    // 2. 구름
    _drawClouds(canvas, w, horizY);

    // 3. 원거리 산 (청회색 삼각형들)
    _drawFarMountains(canvas, w, horizY);

    // 4. 근거리 산 (녹색 삼각형들)
    _drawNearMountains(canvas, w, horizY);

    // 5. 수목선 (삼각형 나무들)
    _drawTreeline(canvas, w, horizY);

    // 6. 초원 (폴리곤 3겹)
    _drawMeadow(canvas, s, horizY, gy);

    // 7. 바닥 풀 + 흙 영역
    _drawGroundGrass(canvas, s, gy);

    // 8. 들꽃 (양쪽 가장자리)
    _drawWildflowers(canvas, s, gy);
  }

  void _drawClouds(Canvas c, double w, double horizY) {
    final cloudY = horizY * 0.38;
    final clouds = [
      [w * 0.13 + w * 0.055 * math.sin(wt * math.pi * 2), cloudY, w * 0.062, 0.72],
      [w * 0.57 + w * 0.042 * math.cos(wt * math.pi * 2 + 1.1), cloudY * 0.68, w * 0.078, 0.82],
      [w * 0.84 + w * 0.048 * math.sin(wt * math.pi * 2 + 2.3), cloudY * 1.18, w * 0.052, 0.60],
    ];
    for (final cl in clouds) {
      final cx = cl[0] as double;
      final cy = cl[1] as double;
      final r = cl[2] as double;
      final a = cl[3] as double;
      final p = Paint()..color = Colors.white.withValues(alpha: a);
      c.drawCircle(Offset(cx, cy), r, p);
      c.drawCircle(Offset(cx - r * 0.72, cy + r * 0.12), r * 0.66, p);
      c.drawCircle(Offset(cx + r * 0.72, cy + r * 0.12), r * 0.66, p);
      c.drawCircle(Offset(cx - r * 1.25, cy + r * 0.36), r * 0.46, p);
      c.drawCircle(Offset(cx + r * 1.25, cy + r * 0.36), r * 0.46, p);
    }
  }

  void _drawFarMountains(Canvas c, double w, double horizY) {
    // 청회색 먼 산봉우리들 (삼각형 9개)
    final peaks = [
      [0.05, 0.090], [0.17, 0.058], [0.29, 0.080], [0.40, 0.042],
      [0.52, 0.070], [0.62, 0.048], [0.74, 0.078], [0.86, 0.052],
      [0.96, 0.065],
    ];
    for (int i = 0; i < peaks.length; i++) {
      final px = w * peaks[i][0];
      final ph = w * peaks[i][1];
      final span = w * 0.17;
      final col = i % 2 == 0 ? const Color(0xFFB0C4D8) : const Color(0xFF9AB6CC);
      _tri(c,
        Offset(px - span * 0.55, horizY + 2),
        Offset(px, horizY - ph),
        Offset(px + span * 0.55, horizY + 2),
        col,
      );
    }
  }

  void _drawNearMountains(Canvas c, double w, double horizY) {
    // 가까운 녹색 산 (삼각형 5개)
    const nearPeaks = [
      [0.0, 0.085, 0.30], [0.22, 0.130, 0.38],
      [0.50, 0.105, 0.32], [0.75, 0.140, 0.40],
      [1.0,  0.088, 0.28],
    ];
    for (final pk in nearPeaks) {
      final px = w * (pk[0] as double);
      final ph = w * (pk[1] as double);
      final span = w * (pk[2] as double);
      // 두 면 (명암)
      _tri(c,
        Offset(px - span * 0.5, horizY + 3),
        Offset(px, horizY - ph),
        Offset(px, horizY + 3),
        const Color(0xFF3D6E3D),
      );
      _tri(c,
        Offset(px, horizY + 3),
        Offset(px, horizY - ph),
        Offset(px + span * 0.5, horizY + 3),
        const Color(0xFF4A7A4A),
      );
    }
  }

  void _drawTreeline(Canvas c, double w, double horizY) {
    final rng = math.Random(31);
    final baseH = w * 0.072;
    for (int i = 0; i < 22; i++) {
      final tx = w * (i + 0.5) / 22.0 + (rng.nextDouble() - 0.5) * w * 0.022;
      final th = baseH * (0.60 + rng.nextDouble() * 0.70);
      final tw = th * 0.52;
      // 나무 삼각형 2개 (좌=어둠, 우=밝음)
      _tri(c,
        Offset(tx - tw * 0.5, horizY + 2),
        Offset(tx, horizY - th),
        Offset(tx, horizY + 2),
        const Color(0xFF2D5E2D),
      );
      _tri(c,
        Offset(tx, horizY + 2),
        Offset(tx, horizY - th),
        Offset(tx + tw * 0.5, horizY + 2),
        const Color(0xFF3B7A3B),
      );
    }
  }

  void _drawMeadow(Canvas c, Size s, double horizY, double gy) {
    final w = s.width;
    final h = s.height;

    // 뒤 (밝은 황록)
    _poly(c, [
      Offset(0, horizY + h * 0.015),
      Offset(w * 0.30, horizY - h * 0.022),
      Offset(w * 0.58, horizY + h * 0.008),
      Offset(w * 0.82, horizY + h * 0.030),
      Offset(w, horizY + h * 0.002),
      Offset(w, h),
      Offset(0, h),
    ], const Color(0xFF78BF54));

    // 중간
    _poly(c, [
      Offset(0, horizY + h * 0.058),
      Offset(w * 0.38, horizY + h * 0.012),
      Offset(w * 0.65, horizY + h * 0.048),
      Offset(w * 0.88, horizY + h * 0.018),
      Offset(w, horizY + h * 0.065),
      Offset(w, h),
      Offset(0, h),
    ], const Color(0xFF5A9E42));

    // 앞 (어두운 녹색)
    _poly(c, [
      Offset(0, gy - h * 0.048),
      Offset(w * 0.25, gy - h * 0.075),
      Offset(w * 0.50, gy - h * 0.058),
      Offset(w * 0.78, gy - h * 0.085),
      Offset(w, gy - h * 0.042),
      Offset(w, h),
      Offset(0, h),
    ], const Color(0xFF488635));
  }

  void _drawGroundGrass(Canvas c, Size s, double gy) {
    final w = s.width;
    final h = s.height;

    _poly(c, [
      Offset(0, gy),
      Offset(w, gy),
      Offset(w, h),
      Offset(0, h),
    ], const Color(0xFF2E6B20));

    // 화분 뒤 흙 그림자
    c.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, gy + h * 0.010),
        width: w * 0.50,
        height: h * 0.025,
      ),
      Paint()..color = const Color(0x553D2010),
    );
  }

  void _drawWildflowers(Canvas c, Size s, double gy) {
    final w = s.width;
    final h = s.height;
    final rng = math.Random(55);
    const flowerColors = [
      Color(0xFFFF6B9D), Color(0xFFFFD700), Color(0xFFFF8C42),
      Color(0xFFAD49E8), Color(0xFFFF4B6B),
    ];

    // 왼쪽, 오른쪽 가장자리에 들꽃
    for (int side = 0; side < 2; side++) {
      final xBase = side == 0 ? 0.0 : w * 0.72;
      final xRange = w * 0.24;
      for (int i = 0; i < 8; i++) {
        final fx = xBase + rng.nextDouble() * xRange;
        final fy = gy - h * 0.005 - rng.nextDouble() * h * 0.11;
        final r = h * 0.017 * (0.45 + rng.nextDouble() * 0.75);
        final col = flowerColors[rng.nextInt(flowerColors.length)];
        final sway = math.sin(wt * math.pi * 2 * 1.4 + i * 0.85 + side * 3.14) * 0.07;

        // 줄기
        c.drawLine(
          Offset(fx, fy),
          Offset(fx + (rng.nextDouble() - 0.5) * r, fy + r * 2.2),
          Paint()
            ..color = const Color(0xFF4CAF50)
            ..strokeWidth = r * 0.14
            ..strokeCap = StrokeCap.round,
        );

        // 꽃잎 삼각형 5개 (windPhase로 흔들림)
        for (int p = 0; p < 5; p++) {
          final ang = p * math.pi * 2 / 5 + sway;
          final tip = Offset(fx + math.cos(ang) * r * 1.7, fy + math.sin(ang) * r * 1.7);
          final a1 = ang - 0.30;
          final a2 = ang + 0.30;
          _tri(c,
            Offset(fx + math.cos(a1) * r * 0.5, fy + math.sin(a1) * r * 0.5),
            tip,
            Offset(fx + math.cos(a2) * r * 0.5, fy + math.sin(a2) * r * 0.5),
            col,
          );
        }

        // 꽃 중앙
        c.drawCircle(
          Offset(fx, fy),
          r * 0.40,
          Paint()..color = const Color(0xFFFFEB3B),
        );
      }
    }
  }
}
