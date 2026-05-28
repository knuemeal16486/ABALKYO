import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

class LavenderPainter extends CustomPainter {
  final double g;
  final double windPhase;
  final double windAmp;
  final double wiltFactor;
  final int seed;

  LavenderPainter({
    required this.g,
    required this.windPhase,
    required this.windAmp,
    required this.wiltFactor,
    required this.seed,
  });

  @override
  bool shouldRepaint(LavenderPainter o) =>
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

    // ── 기저 로제트 잎 ────────────────────────────────────────────────────────
    final leafCount = ((g - 0.08) / 0.72 * 14 + 6).clamp(6, 18).floor();
    for (int li = 0; li < leafCount; li++) {
      final angle = li * math.pi * 2 / leafCount;
      final leafLen = lp(15, 55, sstep(0.08, 0.65, g)) * fit;
      final sway = windSway(windPhase + li * 0.18, 0.15, windAmp);

      canvas.save();
      canvas.translate(cx, groundY - 5 * fit);
      canvas.rotate(angle + sway);

      // 좁고 긴 삼각형 잎 (라벤더 특유의 좁은 잎)
      final base = Offset(0, 0);
      final tip = Offset(0, -leafLen);
      final w = leafLen * 0.15;
      // 삼각형 2개로 앞뒤 면
      tri(canvas, base, Offset(-w, -leafLen * 0.55), tip, const Color(0xFF78909C));
      tri(canvas, base, Offset(w, -leafLen * 0.55), tip, const Color(0xFF90A4AE));

      canvas.restore();
    }

    // ── 꽃대 ─────────────────────────────────────────────────────────────────
    if (g > 0.40) {
      final spikeCount = ((g - 0.40) / 0.45 * 6 + 3).clamp(3, 9).floor();
      final spikeH = lp(0, 165, sstep(0.40, 0.95, g)) * fit;

      // 꽃대를 중심 기준 대칭 배치
      final spikeOffsets = <double>[];
      for (int si = 0; si < spikeCount; si++) {
        if (si == 0) spikeOffsets.add(0);
        else if (si % 2 == 1) spikeOffsets.add(-(si + 1) / 2 * 22.0);
        else spikeOffsets.add((si) / 2 * 22.0);
      }

      for (int si = 0; si < spikeCount; si++) {
        final spikeX = cx + spikeOffsets[si] * fit;
        final spikeSway = windSway(windPhase + si * 0.25, 1.0, windAmp);

        canvas.save();
        canvas.translate(spikeX, groundY);
        canvas.rotate(spikeSway);

        // 꽃대 줄기 (얇은 사다리꼴)
        trunkSegment(canvas, Offset.zero, Offset(0, -spikeH), 2.5 * fit, 1.5 * fit);

        // 꽃이삭 (상단 40%)
        final spikeTop = -spikeH;
        final spikeLen = spikeH * 0.42;
        final spikeStart = spikeTop + spikeLen;
        _drawLavenderSpike(canvas, Offset(0, spikeStart), spikeLen, fit, g, si, rng);

        canvas.restore();
      }
    }

    drawPot(canvas, ground, fit);
    drawWiltOverlay(canvas, size, wiltFactor);
  }

  void _drawLavenderSpike(Canvas c, Offset top, double spikeLen, double fit, double g, int idx, math.Random rng) {
    // 꽃이삭 = 작은 육각형들의 세로 배열
    final whorls = ((g - 0.55) * 16 + 4).clamp(4, 16).floor();
    for (int wi = 0; wi < whorls; wi++) {
      final t = wi / (whorls - 1).clamp(1, 99);
      final wy = top.dy - spikeLen * t;
      final wr = lp(5, 3, t) * fit;
      // 각 whorl: 타원형 6각형
      final col = Color.lerp(
        const Color(0xFF9C27B0),
        g > 0.88 ? const Color(0xFFBA68C8) : const Color(0xFFCE93D8),
        t,
      )!;
      ngon(c, Offset(top.dx, wy), wr, 6, col, startAngle: math.pi / 6);
      // 꽃받침: 작은 삼각형
      tri(c,
        Offset(top.dx, wy - wr * 0.6),
        Offset(top.dx - wr * 0.7, wy),
        Offset(top.dx + wr * 0.7, wy),
        const Color(0xFF78909C));
    }
    // 이삭 끝 포인트
    if (g > 0.75) {
      ngon(c, Offset(top.dx, top.dy - spikeLen - 3 * fit), 2.5 * fit, 5,
        const Color(0xFF6A1B9A));
    }
  }
}
