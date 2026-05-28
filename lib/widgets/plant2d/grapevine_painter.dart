import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

class GrapevinePainter extends CustomPainter {
  final double g;
  final double windPhase;
  final double windAmp;
  final double wiltFactor;
  final int seed;

  GrapevinePainter({
    required this.g,
    required this.windPhase,
    required this.windAmp,
    required this.wiltFactor,
    required this.seed,
  });

  @override
  bool shouldRepaint(GrapevinePainter o) =>
    o.g != g || o.windPhase != windPhase || o.wiltFactor != wiltFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = size.height / 580;
    final cx = size.width / 2;
    final groundY = size.height - 65 * fit;
    final ground = Offset(cx, groundY);
    final rng = math.Random(seed);

    if (g < 0.08) {
      drawSeed(canvas, ground, fit, sstep(0, 0.08, g));
      drawPot(canvas, ground, fit);
      drawWiltOverlay(canvas, size, wiltFactor);
      return;
    }

    // 트렐리스 포스트 높이
    final postH = lp(20, 175, sstep(0.08, 0.85, g)) * fit;
    final postSpread = 55 * fit;

    // 포스트 2개 (사다리꼴)
    for (final side in [-1.0, 1.0]) {
      final px = cx + side * postSpread;
      quad(canvas,
        Offset(px - 5 * fit, groundY - postH),
        Offset(px + 5 * fit, groundY - postH),
        Offset(px + 6 * fit, groundY),
        Offset(px - 6 * fit, groundY),
        const Color(0xFF795548));
      // 포스트 하이라이트
      tri(canvas,
        Offset(px - 5 * fit, groundY - postH),
        Offset(px - 1 * fit, groundY - postH),
        Offset(px - 6 * fit, groundY),
        const Color(0xFF9E7B5E));
    }

    // 가로 와이어 3개
    if (g > 0.18) {
      final wireCount = ((g - 0.18) / 0.6 * 3).clamp(0, 3).floor();
      for (int wi = 0; wi < wireCount; wi++) {
        final wy = groundY - postH * (0.35 + wi * 0.28);
        canvas.drawLine(
          Offset(cx - postSpread, wy),
          Offset(cx + postSpread, wy),
          Paint()..color = const Color(0xFF9E9E9E)..strokeWidth = 1.5 * fit);
      }
    }

    // 덩굴 줄기 (포스트를 타고 올라가는 지그재그)
    if (g > 0.12) {
      final vineH = lp(0, postH * 0.95, sstep(0.12, 0.85, g));
      _drawVine(canvas, cx - postSpread * 0.4, groundY, vineH, fit, -1.0, rng);
      if (g > 0.25) {
        _drawVine(canvas, cx + postSpread * 0.4, groundY, vineH * 0.85, fit, 1.0, rng);
      }
    }

    // 잎 (palmated, 5갈래)
    if (g > 0.32) {
      final leafCount = ((g - 0.32) / 0.52 * 8).clamp(0, 8).floor();
      final sway = windSway(windPhase, 0.7, windAmp);
      for (int li = 0; li < leafCount; li++) {
        final side = li % 2 == 0 ? -1.0 : 1.0;
        final attachX = cx + side * postSpread * (0.3 + (li ~/ 2) * 0.08);
        final attachY = groundY - postH * (0.25 + (li ~/ 2) * 0.17);
        canvas.save();
        canvas.translate(attachX, attachY);
        canvas.rotate(sway * side);
        _drawPalmateLeaf(canvas, fit, li, rng);
        canvas.restore();
      }
    }

    // 포도송이 (g > 0.58)
    if (g > 0.58) {
      final clusterCount = ((g - 0.58) / 0.42 * 4).clamp(0, 4).floor();
      for (int ci = 0; ci < clusterCount; ci++) {
        final side = ci % 2 == 0 ? -1.0 : 1.0;
        final hangX = cx + side * postSpread * (0.2 + ci * 0.1);
        final hangY = groundY - postH * (0.55 + (ci ~/ 2) * 0.18);
        final ripeness = ((g - 0.58) * 2.4).clamp(0, 1.0);
        _drawGrapeCluster(canvas, Offset(hangX, hangY), fit, ripeness, rng,
          windSway(windPhase + ci * 0.2, 0.75, windAmp));
      }
    }

    drawPot(canvas, ground, fit);
    drawWiltOverlay(canvas, size, wiltFactor);
  }

  void _drawVine(Canvas c, double startX, double startY, double height, double fit, double side, math.Random rng) {
    var curX = startX;
    var curY = startY;
    final segs = 8;
    for (int i = 0; i < segs; i++) {
      final segH = height / segs;
      final nextX = curX + side * (rng.nextDouble() * 12 - 4) * fit;
      final nextY = curY - segH;
      final w = lp(4, 1.5, i / segs) * fit;
      trunkSegment(c, Offset(curX, curY), Offset(nextX, nextY), w, w * 0.7);
      curX = nextX; curY = nextY;
    }
  }

  void _drawPalmateLeaf(Canvas c, double fit, int idx, math.Random rng) {
    final leafLen = lp(18, 38, idx / 7.0) * fit;
    // 5갈래 손바닥 잎
    for (int i = 0; i < 5; i++) {
      final angle = (i - 2) * math.pi / 5 - math.pi / 2;
      final tip = Offset(math.cos(angle) * leafLen, math.sin(angle) * leafLen);
      final lobeColors = [
        const Color(0xFF388E3C), const Color(0xFF558B2F), const Color(0xFF66BB6A),
        const Color(0xFF558B2F), const Color(0xFF388E3C),
      ];
      leafPoly(c, Offset.zero, tip, leafLen * 0.3,
        front: lobeColors[i],
        mid: const Color(0xFF43A047),
        back: const Color(0xFF2E7D32));
    }
  }

  void _drawGrapeCluster(Canvas c, Offset hangPt, double fit, double ripeness, math.Random rng, double sway) {
    final baseColor = Color.lerp(const Color(0xFFCE93D8), const Color(0xFF7B1FA2), ripeness)!;
    final darkColor = Color.lerp(const Color(0xFFAB47BC), const Color(0xFF4A148C), ripeness)!;
    final hiColor = Color.lerp(const Color(0xFFE1BEE7), const Color(0xFFCE93D8), ripeness)!;

    c.save();
    c.translate(hangPt.dx, hangPt.dy);
    c.rotate(sway);

    // 역삼각형 배열: 4행 (3,4,4,3)
    final rows = [[3, 0.0], [4, 8.5], [4, 17.0], [3, 25.5]];
    for (int ri = 0; ri < rows.length; ri++) {
      final count = (rows[ri][0] as double).toInt();
      final yOff = rows[ri][1] as double;
      final xStart = -(count - 1) * 9.0 / 2;
      for (int gi = 0; gi < count; gi++) {
        final gc = Offset((xStart + gi * 9.0) * fit, yOff * fit);
        final gr = 5.0 * fit;
        // 8각형 포도알
        for (int i = 0; i < 8; i++) {
          final a1 = i * math.pi / 4;
          final a2 = (i + 1) * math.pi / 4;
          final col = i == 7 ? hiColor : (i < 3 ? darkColor : baseColor);
          tri(c, gc,
            Offset(gc.dx + math.cos(a1) * gr, gc.dy + math.sin(a1) * gr),
            Offset(gc.dx + math.cos(a2) * gr, gc.dy + math.sin(a2) * gr),
            col);
        }
      }
    }
    c.restore();
  }
}
