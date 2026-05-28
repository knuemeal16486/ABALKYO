import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

class AppleTreePainter extends CustomPainter {
  final double g;          // 0.0–1.0
  final double windPhase;  // 0.0–1.0
  final double windAmp;    // 0.0–9.0
  final double wiltFactor;
  final int seed;
  final int month;

  AppleTreePainter({
    required this.g,
    required this.windPhase,
    required this.windAmp,
    required this.wiltFactor,
    required this.seed,
    required this.month,
  });

  @override
  bool shouldRepaint(AppleTreePainter o) =>
    o.g != g || o.windPhase != windPhase || o.wiltFactor != wiltFactor || o.windAmp != windAmp;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = size.height / 580;
    final cx = size.width / 2;
    final groundY = size.height - 65 * fit;
    final ground = Offset(cx, groundY);
    final rng = math.Random(seed);

    // ── 씨앗 단계 ────────────────────────────────────────────────────────────
    if (g < 0.06) {
      drawSeed(canvas, ground, fit, sstep(0, 0.06, g) * 1.0);
      drawPot(canvas, ground, fit);
      drawWiltOverlay(canvas, size, wiltFactor);
      return;
    }

    // ── 줄기 성장 계산 ────────────────────────────────────────────────────────
    final totalTrunkH = lp(18, 180, sstep(0.06, 0.85, g)) * fit;
    final trunkSegs = 7;
    final visibleSegs = ((g - 0.06) / (0.85 - 0.06) * trunkSegs).clamp(0, trunkSegs).floor();
    final partialFrac = (((g - 0.06) / (0.85 - 0.06) * trunkSegs) % 1.0).clamp(0.0, 1.0);
    final trunkTopY = groundY - totalTrunkH;

    // ── 줄기 그리기 ───────────────────────────────────────────────────────────
    for (int i = 0; i < visibleSegs; i++) {
      final frac = i < visibleSegs - 1 ? 1.0 : partialFrac;
      final bot = Offset(cx, groundY - totalTrunkH * i / trunkSegs);
      final top = Offset(cx + math.sin(i * 0.7 + seed) * 4 * fit,
                         groundY - totalTrunkH * (i + frac) / trunkSegs);
      final wB = lp(20, 8, i / trunkSegs) * fit;
      final wT = lp(20, 8, (i + 1) / trunkSegs) * fit;
      trunkSegment(canvas, bot, top, wB, wT);
    }

    // ── 가지 분기 ─────────────────────────────────────────────────────────────
    // 가지 정보: [방향각도, 가지 위치 비율, 길이 비율]
    final branchDefs = [
      [-0.55, 0.72, 0.82],   // 좌 큰 가지
      [ 0.52, 0.68, 0.78],   // 우 큰 가지
      [-0.35, 0.88, 0.55],   // 좌 위 가지
      [ 0.38, 0.85, 0.52],   // 우 위 가지
      [ 0.0,  0.95, 0.45],   // 중앙 상단 가지
    ];
    final branchCount = ((g - 0.28) / 0.5 * branchDefs.length).clamp(0, branchDefs.length.toDouble()).floor();
    final branchMaxLen = lp(0, 80, sstep(0.28, 0.78, g)) * fit;

    final branchTips = <Offset>[];
    for (int bi = 0; bi < branchCount; bi++) {
      final bd = branchDefs[bi];
      final angle = bd[0] as double;
      final pos   = bd[1] as double;
      final lenFrac = bd[2] as double;
      final brLen = branchMaxLen * lenFrac;
      final bBase = Offset(cx, groundY - totalTrunkH * pos);
      final bTip = Offset(
        bBase.dx + math.sin(angle + math.pi / 2) * brLen,
        bBase.dy - math.cos(angle + math.pi / 2) * brLen,
      );
      branchTips.add(bTip);
      final sway = windSway(windPhase + bi * 0.1, pos, windAmp);
      canvas.save();
      canvas.translate(bBase.dx, bBase.dy);
      canvas.rotate(sway);
      trunkSegment(canvas, Offset.zero,
        Offset(bTip.dx - bBase.dx, bTip.dy - bBase.dy),
        lp(10, 4, 0) * fit, lp(10, 4, 1) * fit);
      canvas.restore();
    }

    // ── 잎 클러스터 (수관) ────────────────────────────────────────────────────
    if (g > 0.48) {
      final season = _season(month);
      final leafAlpha = sstep(0.48, 0.65, g);
      final leafColors = _leafColors(month);

      // 수관 중심: 가지 끝들의 무게중심
      Offset canopyCenter = Offset(cx, trunkTopY - 20 * fit);
      if (branchTips.isNotEmpty) {
        double sx = 0, sy = 0;
        for (final t in branchTips) { sx += t.dx; sy += t.dy; }
        canopyCenter = Offset(sx / branchTips.length, sy / branchTips.length - 15 * fit);
      }

      final canopyR = lp(30, 95, sstep(0.48, 0.90, g)) * fit;
      final clusterCount = ((g - 0.48) / 0.42 * 9 + 3).clamp(3, 12).floor();

      canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Color.fromARGB((leafAlpha * 255).round(), 255, 255, 255));

      for (int ci = 0; ci < clusterCount; ci++) {
        final angle = ci * math.pi * 2 / clusterCount + rng.nextDouble() * 0.4;
        final dist = rng.nextDouble() * canopyR * 0.55;
        final center = Offset(
          canopyCenter.dx + math.cos(angle) * dist,
          canopyCenter.dy + math.sin(angle) * dist * 0.7,
        );
        final r = (canopyR * (0.45 + rng.nextDouble() * 0.35)).clamp(12.0 * fit, canopyR);
        final col = leafColors[ci % leafColors.length];

        // 수관 삼각형 클러스터 (6–8개 삼각형)
        final facets = 7;
        for (int fi = 0; fi < facets; fi++) {
          final a1 = fi * math.pi * 2 / facets;
          final a2 = (fi + 1) * math.pi * 2 / facets;
          final r1 = r * (0.7 + rng.nextDouble() * 0.35);
          final r2 = r * (0.7 + rng.nextDouble() * 0.35);
          final p1 = Offset(center.dx + math.cos(a1) * r1, center.dy + math.sin(a1) * r1 * 0.8);
          final p2 = Offset(center.dx + math.cos(a2) * r2, center.dy + math.sin(a2) * r2 * 0.8);
          final shade = _shadeLeaf(col, fi, facets);
          tri(canvas, center, p1, p2, shade);
        }
      }
      canvas.restore();

      // ── 계절별 꽃 ──────────────────────────────────────────────────────────
      if (season == 'blossom' && g > 0.65) {
        final blossomCount = ((g - 0.65) * 18).clamp(0, 14).floor();
        for (int i = 0; i < blossomCount; i++) {
          final angle = rng.nextDouble() * math.pi * 2;
          final dist = rng.nextDouble() * canopyR * 0.72;
          final bc = Offset(
            canopyCenter.dx + math.cos(angle) * dist,
            canopyCenter.dy + math.sin(angle) * dist * 0.7,
          );
          _drawFlower(canvas, bc, lp(5, 9, g) * fit, rng);
        }
      }

      // ── 사과 열매 ──────────────────────────────────────────────────────────
      if (season != 'blossom' && g > 0.82) {
        final appleCount = ((g - 0.82) * 22).clamp(0, 14).floor();
        for (int i = 0; i < appleCount; i++) {
          final angle = rng.nextDouble() * math.pi * 2;
          final dist = rng.nextDouble() * canopyR * 0.65;
          final ac = Offset(
            canopyCenter.dx + math.cos(angle) * dist,
            canopyCenter.dy + math.sin(angle) * dist * 0.7,
          );
          _drawApple(canvas, ac, lp(6, 11, (g - 0.82) * 5) * fit, rng);
        }
      }
    }

    drawPot(canvas, ground, fit);
    drawWiltOverlay(canvas, size, wiltFactor);
  }

  String _season(int month) {
    if (month == 3 || month == 4 || month == 5) return 'blossom';
    if (month == 1 || month == 2 || month == 12) return 'winter';
    return 'summer';
  }

  List<Color> _leafColors(int month) {
    if (month == 10) return [const Color(0xFFE65100), const Color(0xFFF57F17), const Color(0xFFBF360C), const Color(0xFF4CAF50)];
    if (month == 11) return [const Color(0xFF8D6E63), const Color(0xFFBF360C), const Color(0xFFE65100)];
    if (month == 3 || month == 4 || month == 5) return [const Color(0xFF81C784), const Color(0xFF66BB6A), const Color(0xFF43A047)];
    return [const Color(0xFF2E7D32), const Color(0xFF388E3C), const Color(0xFF43A047), const Color(0xFF1B5E20)];
  }

  Color _shadeLeaf(Color base, int fi, int total) {
    final t = (fi / total * 2 - 1).abs();
    return Color.lerp(base, fi < total ~/ 2 ? Colors.black : Colors.white, t * 0.22)!;
  }

  void _drawFlower(Canvas c, Offset center, double r, math.Random rng) {
    // 5장 꽃잎 삼각형
    for (int i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5 - math.pi / 2;
      final tip = Offset(center.dx + math.cos(a) * r * 1.8, center.dy + math.sin(a) * r * 1.8);
      final a1 = a - 0.35;
      final a2 = a + 0.35;
      final p1 = Offset(center.dx + math.cos(a1) * r * 0.6, center.dy + math.sin(a1) * r * 0.6);
      final p2 = Offset(center.dx + math.cos(a2) * r * 0.6, center.dy + math.sin(a2) * r * 0.6);
      tri(c, p1, tip, p2, const Color(0xFFFFB7C5));
    }
    // 수술
    ngon(c, center, r * 0.55, 6, const Color(0xFFFFD700));
  }

  void _drawApple(Canvas c, Offset center, double r, math.Random rng) {
    // 8각형 사과 (3가지 빨강 음영)
    final colors = [
      const Color(0xFFE53935), const Color(0xFFD32F2F), const Color(0xFFB71C1C),
      const Color(0xFFEF5350), const Color(0xFFD32F2F), const Color(0xFFB71C1C),
      const Color(0xFFE53935), const Color(0xFFEF9A9A),
    ];
    for (int i = 0; i < 8; i++) {
      final a1 = i * math.pi / 4 - math.pi / 8;
      final a2 = (i + 1) * math.pi / 4 - math.pi / 8;
      tri(c, center,
        Offset(center.dx + math.cos(a1) * r, center.dy + math.sin(a1) * r),
        Offset(center.dx + math.cos(a2) * r, center.dy + math.sin(a2) * r),
        colors[i]);
    }
    // 꼭지
    tri(c, Offset(center.dx, center.dy - r),
      Offset(center.dx - 1.5, center.dy - r * 1.5),
      Offset(center.dx + 1.5, center.dy - r * 1.55),
      const Color(0xFF4A2810));
  }
}
