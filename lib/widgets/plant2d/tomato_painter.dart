import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

class TomatoPainter extends CustomPainter {
  final double g;
  final double windPhase;
  final double windAmp;
  final double wiltFactor;
  final int seed;

  TomatoPainter({
    required this.g,
    required this.windPhase,
    required this.windAmp,
    required this.wiltFactor,
    required this.seed,
  });

  @override
  bool shouldRepaint(TomatoPainter o) =>
    o.g != g || o.windPhase != windPhase || o.wiltFactor != wiltFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = size.height / 580;
    final cx = size.width / 2;
    final groundY = size.height - 65 * fit;
    final ground = Offset(cx, groundY);
    final rng = math.Random(seed);

    if (g < 0.07) {
      drawSeed(canvas, ground, fit, sstep(0, 0.07, g));
      drawPot(canvas, ground, fit);
      drawWiltOverlay(canvas, size, wiltFactor);
      return;
    }

    // 지지대 (나무 막대)
    if (g > 0.20) {
      final stakeH = lp(0, 160, sstep(0.20, 0.85, g)) * fit;
      for (final dx in [-28.0, 28.0]) {
        quad(canvas,
          Offset(cx + dx * fit - 3 * fit, groundY - stakeH),
          Offset(cx + dx * fit + 3 * fit, groundY - stakeH),
          Offset(cx + dx * fit + 3 * fit, groundY),
          Offset(cx + dx * fit - 3 * fit, groundY),
          const Color(0xFF8D6E63));
      }
    }

    // 줄기 마디 수 계산
    final maxSegs = 7;
    final totalH = lp(12, 170, sstep(0.07, 0.88, g)) * fit;
    final visSegs = ((g - 0.07) / 0.81 * maxSegs).clamp(0, maxSegs.toDouble()).floor();
    final partialFrac = ((g - 0.07) / 0.81 * maxSegs % 1.0).clamp(0.0, 1.0);

    // 줄기 세그먼트
    for (int i = 0; i < visSegs; i++) {
      final frac = i < visSegs - 1 ? 1.0 : partialFrac;
      final wobX = math.sin(i * 1.3 + seed * 0.1) * 6 * fit;
      final bot = Offset(cx + wobX, groundY - totalH * i / maxSegs);
      final top = Offset(cx + wobX + math.sin(i * 2.1 + seed) * 4 * fit,
                         groundY - totalH * (i + frac) / maxSegs);
      trunkSegment(canvas, bot, top,
        lp(7, 3, i / maxSegs) * fit,
        lp(7, 3, (i + frac) / maxSegs) * fit);
    }

    // 복엽 (각 마디에서 잎 세트)
    final leafSetCount = ((g - 0.14) / 0.74 * 5).clamp(0, 5).floor();
    for (int li = 0; li < leafSetCount; li++) {
      final seg = li + 1;
      final attachY = groundY - totalH * seg / maxSegs;
      final wobX = math.sin(seg * 1.3 + seed * 0.1) * 6 * fit;
      final attachPt = Offset(cx + wobX, attachY);

      // 좌우 잎 쌍
      for (final side in [-1.0, 1.0]) {
        final sway = windSway(windPhase + li * 0.15, seg / maxSegs, windAmp);
        canvas.save();
        canvas.translate(attachPt.dx, attachPt.dy);
        canvas.rotate(sway * side * 1.5);

        final leafLen = lp(18, 40, (li / 4.0)) * fit;
        final leafBase = Offset.zero;
        final leafTip = Offset(side * leafLen * 0.8, -leafLen);
        leafPoly(canvas, leafBase, leafTip, leafLen * 0.42,
          front: const Color(0xFF66BB6A),
          mid: const Color(0xFF43A047),
          back: const Color(0xFF2E7D32));
        // 소엽 추가
        leafPoly(canvas,
          Offset(side * leafLen * 0.3, -leafLen * 0.4),
          Offset(side * leafLen * 1.2, -leafLen * 0.6),
          leafLen * 0.25,
          front: const Color(0xFF81C784),
          mid: const Color(0xFF66BB6A),
          back: const Color(0xFF388E3C));
        canvas.restore();
      }
    }

    // 꽃 (g > 0.54)
    if (g > 0.54) {
      final flowerCount = ((g - 0.54) * 10).clamp(0, 6).floor();
      for (int fi = 0; fi < flowerCount; fi++) {
        final seg = fi + 2;
        final wobX = math.sin(seg * 1.3 + seed * 0.1) * 6 * fit;
        final fc = Offset(cx + wobX + (rng.nextDouble() - 0.5) * 30 * fit,
                          groundY - totalH * seg / maxSegs + 8 * fit);
        _drawTomatoFlower(canvas, fc, 6 * fit);
      }
    }

    // 열매 (g > 0.68)
    if (g > 0.68) {
      final fruitCount = ((g - 0.68) * 12).clamp(0, 6).floor();
      for (int ri = 0; ri < fruitCount; ri++) {
        final seg = ri + 2;
        final wobX = math.sin(seg * 1.3 + seed * 0.1) * 6 * fit;
        final rc = Offset(cx + wobX + (rng.nextDouble() - 0.5) * 35 * fit,
                          groundY - totalH * seg / maxSegs - 4 * fit);
        final tomatoG = ((g - 0.68) * 3.3).clamp(0, 1.0);
        _drawTomato(canvas, rc, lp(6, 13, tomatoG) * fit, tomatoG);
      }
    }

    drawPot(canvas, ground, fit);
    drawWiltOverlay(canvas, size, wiltFactor);
  }

  void _drawTomatoFlower(Canvas c, Offset center, double r) {
    for (int i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5 - math.pi / 2;
      final tip = Offset(center.dx + math.cos(a) * r * 2.0, center.dy + math.sin(a) * r * 2.0);
      final a1 = a - 0.3, a2 = a + 0.3;
      tri(c,
        Offset(center.dx + math.cos(a1) * r * 0.5, center.dy + math.sin(a1) * r * 0.5),
        tip,
        Offset(center.dx + math.cos(a2) * r * 0.5, center.dy + math.sin(a2) * r * 0.5),
        const Color(0xFFFFD700));
    }
    ngon(c, center, r * 0.55, 6, const Color(0xFFFFA000));
  }

  void _drawTomato(Canvas c, Offset center, double r, double ripeness) {
    final baseCol = Color.lerp(const Color(0xFF8BC34A), const Color(0xFFE53935), ripeness)!;
    final shadeCol = Color.lerp(const Color(0xFF558B2F), const Color(0xFFB71C1C), ripeness)!;
    final hiCol = Color.lerp(const Color(0xFFC5E1A5), const Color(0xFFFF8A80), ripeness)!;

    // 8각형 토마토
    for (int i = 0; i < 8; i++) {
      final a1 = i * math.pi / 4;
      final a2 = (i + 1) * math.pi / 4;
      final col = i < 3 ? shadeCol : (i > 5 ? hiCol : baseCol);
      tri(c, center,
        Offset(center.dx + math.cos(a1) * r, center.dy + math.sin(a1) * r),
        Offset(center.dx + math.cos(a2) * r, center.dy + math.sin(a2) * r),
        col);
    }
    // 꼭지 (calyx)
    for (int i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5 - math.pi / 2;
      tri(c, Offset(center.dx, center.dy - r * 0.7),
        Offset(center.dx + math.cos(a) * r * 0.55, center.dy - r + math.sin(a) * r * 0.3),
        Offset(center.dx + math.cos(a + 0.4) * r * 0.4, center.dy - r * 0.6),
        const Color(0xFF2E7D32));
    }
  }
}
