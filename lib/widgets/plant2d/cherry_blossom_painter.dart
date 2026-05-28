import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

class CherryBlossomPainter extends CustomPainter {
  final double g;
  final double windPhase;
  final double windAmp;
  final double wiltFactor;
  final int seed;
  final int month;

  CherryBlossomPainter({
    required this.g,
    required this.windPhase,
    required this.windAmp,
    required this.wiltFactor,
    required this.seed,
    required this.month,
  });

  @override
  bool shouldRepaint(CherryBlossomPainter o) =>
    o.g != g || o.windPhase != windPhase || o.wiltFactor != wiltFactor || o.month != month;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = size.height / 580;
    final cx = size.width / 2;
    final groundY = size.height - 65 * fit;
    final ground = Offset(cx, groundY);
    final rng = math.Random(seed);

    if (g < 0.06) {
      drawSeed(canvas, ground, fit, sstep(0, 0.06, g));
      drawPot(canvas, ground, fit);
      drawWiltOverlay(canvas, size, wiltFactor);
      return;
    }

    final isSpring = month >= 3 && month <= 5;
    final isWinter = month == 12 || month == 1 || month == 2;

    // 줄기 높이
    final trunkH = lp(15, 200, sstep(0.06, 0.88, g)) * fit;
    final trunkW = lp(6, 18, sstep(0.06, 0.85, g)) * fit;

    // ── 메인 줄기 (수직, 약간 기울어짐) ───────────────────────────────────────
    final trunkTip = Offset(cx + 8 * fit, groundY - trunkH);
    trunkSegment(canvas, Offset(cx, groundY), trunkTip, trunkW, trunkW * 0.45);

    // ── 가지 분기 ─────────────────────────────────────────────────────────────
    final branchData = [
      // [side, posRatio, angleOffset, lengthRatio, depth]
      [-1.0, 0.55, 0.55, 0.75, 2],
      [ 1.0, 0.60, 0.50, 0.70, 2],
      [-1.0, 0.72, 0.48, 0.62, 2],
      [ 1.0, 0.75, 0.44, 0.58, 2],
      [-1.0, 0.85, 0.40, 0.48, 1],
      [ 1.0, 0.88, 0.38, 0.45, 1],
      [ 0.2, 0.92, 0.12, 0.38, 1],
    ];

    final branchCount = ((g - 0.22) / 0.66 * branchData.length).clamp(0, branchData.length.toDouble()).floor();
    final branchTips = <Offset>[];

    final maxBranchLen = lp(0, 105, sstep(0.22, 0.88, g)) * fit;

    for (int bi = 0; bi < branchCount; bi++) {
      final bd = branchData[bi];
      final side = bd[0] as double;
      final pos  = bd[1] as double;
      final aOff = bd[2] as double;
      final lFrac = bd[3] as double;
      final depth = (bd[4] as double).toInt();

      final bBase = Offset(
        cx + 8 * fit * pos,
        groundY - trunkH * pos,
      );
      final bAngle = -math.pi / 2 + side * aOff;
      final bLen = maxBranchLen * lFrac;
      final bTip = Offset(
        bBase.dx + math.cos(bAngle) * bLen,
        bBase.dy + math.sin(bAngle) * bLen,
      );
      branchTips.add(bTip);

      final sway = windSway(windPhase + bi * 0.12, pos, windAmp) * side;
      canvas.save();
      canvas.translate(bBase.dx, bBase.dy);
      canvas.rotate(sway);
      final bW = lp(trunkW * 0.55, 2 * fit, 0);
      trunkSegment(canvas, Offset.zero,
        Offset(bTip.dx - bBase.dx, bTip.dy - bBase.dy), bW, bW * 0.3);

      // 2차 가지
      if (depth >= 2 && g > 0.50) {
        final sub1Angle = bAngle - side * 0.4;
        final sub1Len = bLen * 0.5;
        final sub1Tip = Offset(
          (bTip.dx - bBase.dx) * 0.6 + math.cos(sub1Angle) * sub1Len,
          (bTip.dy - bBase.dy) * 0.6 + math.sin(sub1Angle) * sub1Len,
        );
        trunkSegment(canvas,
          Offset((bTip.dx - bBase.dx) * 0.6, (bTip.dy - bBase.dy) * 0.6),
          sub1Tip, bW * 0.35, bW * 0.12);
        branchTips.add(Offset(bBase.dx + sub1Tip.dx, bBase.dy + sub1Tip.dy));
      }
      canvas.restore();
    }

    // ── 수관 (봄: 꽃, 여름: 잎) ───────────────────────────────────────────────
    if (g > 0.45) {
      for (final tip in branchTips) {
        if (isSpring || !isWinter) {
          // 꽃봉오리 또는 만개 꽃
          final bloomFrac = isSpring ? sstep(0.45, 0.80, g) : 0.0;
          if (bloomFrac > 0.05 && isSpring) {
            _drawBlossomCluster(canvas, tip, fit, bloomFrac, rng, windPhase);
          } else if (!isSpring && !isWinter && g > 0.55) {
            // 초록 잎 클러스터
            _drawLeafCluster(canvas, tip, fit, sstep(0.55, 0.88, g), rng);
          }
        }
      }

      // 봄 낙화 효과
      if (isSpring && g > 0.75) {
        _drawFallingPetals(canvas, size, fit, g, windPhase);
      }
    }

    drawPot(canvas, ground, fit);
    drawWiltOverlay(canvas, size, wiltFactor);
  }

  void _drawBlossomCluster(Canvas c, Offset center, double fit, double bloom, math.Random rng, double windPhase) {
    final clusterR = lp(8, 32, bloom) * fit;
    final flowerCount = (bloom * 8 + 2).floor().clamp(2, 9);

    for (int fi = 0; fi < flowerCount; fi++) {
      final angle = fi * math.pi * 2 / flowerCount + rng.nextDouble() * 0.5;
      final dist = rng.nextDouble() * clusterR * 0.7;
      final fc = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist * 0.75,
      );
      _drawCherryFlower(c, fc, lp(4, 9, bloom) * fit, rng);
    }
  }

  void _drawCherryFlower(Canvas c, Offset center, double r, math.Random rng) {
    // 5장 꽃잎 삼각형 (분홍 계열 3가지 음영)
    final petalColors = [
      const Color(0xFFFFB7C5),
      const Color(0xFFFF8FAB),
      const Color(0xFFFFF0F5),
      const Color(0xFFFFB7C5),
      const Color(0xFFFFCDD2),
    ];
    for (int i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5 - math.pi / 2;
      final tip = Offset(center.dx + math.cos(a) * r * 2.2, center.dy + math.sin(a) * r * 2.2);
      final a1 = a - 0.32, a2 = a + 0.32;
      tri(c,
        Offset(center.dx + math.cos(a1) * r * 0.7, center.dy + math.sin(a1) * r * 0.7),
        tip,
        Offset(center.dx + math.cos(a2) * r * 0.7, center.dy + math.sin(a2) * r * 0.7),
        petalColors[i]);
    }
    // 수술 (노란 6각형)
    ngon(c, center, r * 0.55, 6, const Color(0xFFFFD700));
  }

  void _drawLeafCluster(Canvas c, Offset center, double fit, double alpha, math.Random rng) {
    final leafCount = (alpha * 5 + 2).floor().clamp(2, 6);
    final clusterR = lp(12, 28, alpha) * fit;
    for (int li = 0; li < leafCount; li++) {
      final angle = li * math.pi * 2 / leafCount;
      final base = Offset(center.dx + math.cos(angle) * clusterR * 0.4,
                          center.dy + math.sin(angle) * clusterR * 0.4);
      final tip = Offset(center.dx + math.cos(angle) * clusterR,
                         center.dy + math.sin(angle) * clusterR * 0.75);
      leafPoly(c, base, tip, clusterR * 0.35,
        front: const Color(0xFF66BB6A),
        mid: const Color(0xFF43A047),
        back: const Color(0xFF2E7D32));
    }
  }

  void _drawFallingPetals(Canvas c, Size size, double fit, double g, double windPhase) {
    final count = ((g - 0.75) * 20).clamp(0, 15).floor();
    for (int i = 0; i < count; i++) {
      final t = (windPhase * 1.3 + i / 15.0) % 1.0;
      final px = size.width * 0.2 + (math.sin(windPhase * math.pi * 2 * 0.7 + i * 1.1) * 0.5 + 0.5) * size.width * 0.6;
      final py = size.height * 0.1 + t * size.height * 0.75;
      final r = 3.5 * fit;
      final rot = windPhase * math.pi * 3 + i * 1.2;

      c.save();
      c.translate(px, py);
      c.rotate(rot);
      tri(c, Offset(0, -r * 1.8), Offset(-r, r), Offset(r, r),
        const Color(0xCCFFB7C5));
      c.restore();
    }
  }
}
