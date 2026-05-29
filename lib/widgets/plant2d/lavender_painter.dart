import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LavenderPainter — realistic botanical illustration
//
// Growth stages:
//   g < 0.08           seed + pot
//   0.08 – 0.40        grey-green rosette leaves radiate from groundY
//   0.40 – 0.65        wiry flower stems grow upward with tiny paired bracts
//   0.65 – 1.00        lavender flower spikes bloom floret-by-floret
//
// Canvas conventions:
//   fit     = size.height / 580
//   cx      = size.width / 2
//   groundY = size.height - 65 * fit      (top of pot soil)
//   y increases downward → "growing up" means decreasing y
// ─────────────────────────────────────────────────────────────────────────────

class LavenderPainter extends CustomPainter {
  final double g, windPhase, windAmp, wiltFactor;
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
      o.g != g ||
      o.windPhase != windPhase ||
      o.windAmp != windAmp ||
      o.wiltFactor != wiltFactor ||
      o.seed != seed;

  // ── Main paint entry ───────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final fit = size.height / 580.0;
    final cx = size.width / 2.0;
    final groundY = size.height - 65.0 * fit;
    final ground = Offset(cx, groundY);

    // ── Stage 0: seed ─────────────────────────────────────────────────────────
    if (g < 0.08) {
      drawSeed(canvas, ground, fit, sstep(0.0, 0.08, g));
      realisticPot(canvas, ground, fit);
      drawWiltOverlay(canvas, size, wiltFactor);
      return;
    }

    // ── Stages 1-3: rosette → stems → spikes, pot always drawn last ───────────

    _drawRosette(canvas, cx, groundY, fit);

    if (g > 0.40) {
      _drawAllStems(canvas, cx, groundY, fit);
    }

    // Pot is drawn AFTER plants so it naturally overlaps stem bases
    realisticPot(canvas, ground, fit);
    drawWiltOverlay(canvas, size, wiltFactor);
  }

  // ── Rosette leaves (g 0.08 → 0.40+) ─────────────────────────────────────────
  //
  // 8–16 narrow, grey-green botanicalLeaf() calls fanning out from just above
  // groundY.  Angles span the upper semicircle (–π to 0).  Each leaf gets an
  // individual wind sway and a deterministic lean for organic variety.

  void _drawRosette(Canvas canvas, double cx, double groundY, double fit) {
    // Leaf count grows from 8 to 16 as g climbs from 0.08 toward 1.0
    final leafCount =
        ((g - 0.08) / 0.52 * 8.0 + 8.0).clamp(8.0, 16.0).floor();

    // Length grows quickly in the early stage then levels off
    final leafLen = lp(20.0, 62.0, sstep(0.08, 0.60, g)) * fit;

    // Lavender leaves are characteristically very narrow (linear-lanceolate)
    final leafWidth = leafLen * 0.15;

    // Crown of the plant — leaves emerge a few px above the soil
    final base = Offset(cx, groundY - 5.0 * fit);

    for (int li = 0; li < leafCount; li++) {
      // t = 0..1 sweeps across the fan from left to right
      final t = leafCount > 1 ? li / (leafCount - 1).toDouble() : 0.5;

      // Fan spans from –π*0.85 (left-leaning) through –π/2 (upright) to
      // –π*0.15 (right-leaning).  This keeps the rosette compact and realistic
      // rather than spreading completely horizontal.
      final baseAngle = lp(-math.pi * 0.85, -math.pi * 0.15, t);

      // Individual wind sway — rosette is low so sway amplitude is small
      final sway = windSway(windPhase + li * 0.23, 0.15 + 0.05 * t, windAmp);

      // Deterministic per-leaf lean adds natural variety without frame drift
      final lean = (_pseudoRand(seed + li * 53) - 0.5) * 0.10;

      final totalAngle = baseAngle + sway + lean;

      final tip = Offset(
        base.dx + math.cos(totalAngle) * leafLen,
        base.dy + math.sin(totalAngle) * leafLen,
      );

      // Show veins on most leaves but skip a few for visual variation
      final showVein = li % 3 != 1;

      botanicalLeaf(
        canvas,
        base,
        tip,
        leafWidth,
        const Color(0xFFB0BEC5), // light grey-green
        const Color(0xFF607D8B), // dark grey-green
        vein: showVein,
        veinColor: const Color(0xFF455A64),
      );
    }
  }

  // ── All stems, bracts, and spikes (g > 0.40) ──────────────────────────────

  void _drawAllStems(Canvas canvas, double cx, double groundY, double fit) {
    final stemCount = ((g - 0.40) / 0.25 * 18.0).clamp(3.0, 18.0).floor();
    final totalMaxH = lp(0.0, 185.0, sstep(0.40, 1.0, g)) * fit;
    final spikeLen  = lp(0.0, 38.0, sstep(0.65, 1.0, g)) * fit;
    final stemH     = (totalMaxH - spikeLen).clamp(0.0, totalMaxH);
    final stemTopCeiling = groundY - 195.0 * fit;

    for (int si = 0; si < stemCount; si++) {
      // All stems emerge from a compact crown; lean angle drives the fountain spread
      final double baseXOff;
      final double leanAngle; // radians from vertical (0=straight up)
      if (si == 0) {
        baseXOff  = 0.0;
        leanAngle = 0.0;
      } else {
        final pair = (si + 1) ~/ 2; // 1,1,2,2,3,3,... symmetric pairs
        final sign = (si % 2 == 1) ? -1.0 : 1.0;
        baseXOff  = sign * pair * 2.5 * fit; // tight base — spread is from lean only
        // Fountain lean: pair 1→5°, pair 4→18°, pair 8→32° (max 0.55 rad ≈ 31.5°)
        leanAngle = sign * (pair * 0.07 + 0.02).clamp(0.0, 0.55);
      }

      final stemBase = Offset(cx + baseXOff, groundY);

      // Wind sway
      final swayRad = windSway(windPhase + si * 0.29, 1.0, windAmp);
      final totalAngle = leanAngle + swayRad;

      // Seed-stable extra lean
      final extraLean = (_pseudoRand(seed + si * 37) - 0.5) * 0.08;

      final finalAngle = totalAngle + extraLean;
      // Stem tip: apply lean angle
      final rawTipX = stemBase.dx + math.sin(finalAngle) * stemH;
      final rawTipY = stemBase.dy - math.cos(finalAngle) * stemH;
      final tipY    = rawTipY < stemTopCeiling ? stemTopCeiling : rawTipY;
      final stemTip = Offset(rawTipX, tipY);

      barkBranch(
        canvas,
        stemBase,
        stemTip,
        1.8 * fit,
        const Color(0xFF8D9E6A),
        const Color(0xFF5E6B3F),
      );

      _drawStemBracts(canvas, stemBase, stemTip, fit);

      if (g > 0.65 && spikeLen > 1.5 * fit) {
        final bloomFrac = sstep(0.65, 1.0, g);
        _drawLavenderSpike(canvas, stemTip, spikeLen, fit, bloomFrac, si);
      }
    }
  }

  // ── Paired bracts on stem ─────────────────────────────────────────────────
  //
  // Lavender has small linear bracts clasping the stem in opposite pairs.
  // We draw them with botanicalLeaf() at very small scale, perpendicular to
  // the stem direction.  Bracts are placed in the lower 85% of the stem so
  // the spike attachment zone remains uncluttered.

  void _drawStemBracts(
    Canvas canvas,
    Offset stemBase,
    Offset stemTip,
    double fit,
  ) {
    final stemVec = stemTip - stemBase;
    final stemLen = stemVec.distance;
    if (stemLen < 1.0) return;

    // One bract pair roughly every 20 logical pixels
    final pairCount = (stemLen / (28.0 * fit)).floor().clamp(0, 4);
    if (pairCount == 0) return;

    // Unit vectors: along stem and perpendicular (rotated 90° CW)
    final udx = stemVec.dx / stemLen;
    final udy = stemVec.dy / stemLen;
    final perpX = -udy;
    final perpY = udx;

    for (int pi = 0; pi < pairCount; pi++) {
      // Spread pairs evenly across the lower 85% of the stem
      final t = (pi + 0.5) / pairCount.toDouble() * 0.85;

      final attach = Offset(
        lp(stemBase.dx, stemTip.dx, t),
        lp(stemBase.dy, stemTip.dy, t),
      );

      // Bract dimensions: narrow (3 px) and short (12 px)
      const bracLen = 9.0;
      const bracW = 2.2;

      for (final side in [-1.0, 1.0]) {
        // Bract tip splays out perpendicular, with a slight upward angle
        final tipX = attach.dx
            + perpX * side * bracLen * fit
            - udx * bracLen * 0.25 * fit;
        final tipY = attach.dy
            + perpY * side * bracLen * fit
            - udy * bracLen * 0.25 * fit;

        canvas.saveLayer(
            null,
            Paint()..color = Colors.white.withValues(alpha: 0.35),
          );
        botanicalLeaf(
          canvas,
          attach,
          Offset(tipX, tipY),
          bracW * fit,
          const Color(0xFFB0BEC5),
          const Color(0xFF78909C),
          vein: false,
        );
        canvas.restore();
      }
    }
  }

  // ── Lavender flower spike ─────────────────────────────────────────────────
  //
  // A spike is a dense vertical raceme of small tubular florets.  We represent
  // each floret as a glossyFruit sphere, stacked bottom-to-top.  Lower florets
  // open first (bloomFrac gate).  An alternating ±2 px lateral offset mimics
  // the whorled arrangement of a real lavender spike.
  //
  // A small calyx-tip bud above the topmost open floret gives the spike its
  // characteristic pointed silhouette.

  void _drawLavenderSpike(
    Canvas canvas,
    Offset stemTip,
    double spikeLen,
    double fit,
    double bloomFrac,
    int stemIdx,
  ) {
    final actualLen = spikeLen * bloomFrac;
    if (actualLen < 2.0 * fit) return;

    final spikeSway = windSway(windPhase + stemIdx * 0.29, 1.15, windAmp);
    final swayDx = math.sin(spikeSway) * spikeLen * 0.12;
    final midX = stemTip.dx + swayDx * 0.5;
    final topY = stemTip.dy - actualLen;

    final spikeW = 2.8 * fit;
    final bodyLeft = midX - spikeW;
    final bodyRight = midX + spikeW;
    final bodyTop = topY - spikeW * 0.55;
    final bodyBottom = stemTip.dy;
    final bodyRect = Rect.fromLTRB(bodyLeft, bodyTop, bodyRight, bodyBottom);
    final bodyPath = Path()
      ..addRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(spikeW)));

    // Solid spike body with gradient
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFD1A3D8),
            Color(0xFF9C27B0),
            Color(0xFF6A1B9A),
          ],
          stops: [0.0, 0.40, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(bodyRect),
    );

    // Specular highlight
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.30, -0.40),
          radius: 0.65,
          colors: [
            Colors.white.withValues(alpha: 0.28),
            Colors.transparent,
          ],
        ).createShader(bodyRect)
        ..blendMode = BlendMode.srcATop,
    );

    // Floret texture: small circles in rows
    final rowCount = (actualLen / (3.2 * fit)).floor().clamp(4, 22);
    final floretR = 1.8 * fit;

    for (int ri = 0; ri < rowCount; ri++) {
      final t = ri / math.max(rowCount - 1, 1).toDouble();
      if (t > bloomFrac + 0.08) continue;
      final fade = t <= bloomFrac
          ? 1.0
          : (1.0 - (t - bloomFrac) / 0.08).clamp(0.0, 1.0);
      if (fade <= 0.01) continue;

      final ry = stemTip.dy - t * actualLen;
      final profileW = spikeW * 0.85 * math.sin(t * math.pi).clamp(0.20, 1.0);
      final nPerRow = (profileW / (2.8 * fit)).round().clamp(1, 3);

      final rowColor = Color.lerp(
        const Color(0xFF9C27B0),
        const Color(0xFFCE93D8),
        t,
      )!.withValues(alpha: fade * 0.80);

      for (int ci = 0; ci < nPerRow; ci++) {
        final xOff = nPerRow == 1
            ? 0.0
            : (ci - (nPerRow - 1) / 2.0) * 3.0 * fit;
        canvas.drawCircle(
          Offset(midX + xOff, ry),
          floretR,
          Paint()..color = rowColor,
        );
      }
    }

    // Tip bud
    if (bloomFrac > 0.55) {
      final tipAlpha = sstep(0.55, 0.75, bloomFrac);
      canvas.drawCircle(
        Offset(midX, bodyTop + spikeW * 0.25),
        2.0 * fit,
        Paint()
          ..color = const Color(0xFF7B1FA2).withValues(alpha: tipAlpha * 0.88),
      );
      canvas.drawCircle(
        Offset(midX - 0.4 * fit, bodyTop + spikeW * 0.25 - 0.4 * fit),
        0.7 * fit,
        Paint()..color = Colors.white.withValues(alpha: tipAlpha * 0.30),
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Deterministic pseudo-random value in [0, 1) for [key].
  ///
  /// Uses a simple integer hash so the result is stable across frames for a
  /// given seed+index pair, avoiding visible flickering.
  double _pseudoRand(int key) {
    int x = key;
    x = ((x >> 16) ^ x) * 0x45d9f3b;
    x = ((x >> 16) ^ x) * 0x45d9f3b;
    x = (x >> 16) ^ x;
    return (x & 0x7fffffff) / 0x7fffffff.toDouble();
  }
}
