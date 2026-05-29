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
    final leafLen = lp(15.0, 50.0, sstep(0.08, 0.60, g)) * fit;

    // Lavender leaves are characteristically very narrow (linear-lanceolate)
    final leafWidth = leafLen * 0.12;

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
    // Number of stems grows from 3 to 9 as g moves through 0.40→0.65
    final stemCount =
        ((g - 0.40) / 0.25 * 9.0).clamp(3.0, 9.0).floor();

    // X offsets from cx: centre first, then alternating ±22, ±44, ±66 (px)
    final stemXOffsets = _buildStemOffsets(stemCount, fit);

    // Total height budget (stem + spike) — starts at 0 and grows to 190 px
    final totalMaxH = lp(0.0, 190.0, sstep(0.40, 1.0, g)) * fit;

    // Spike length grows only after g = 0.65, reaches ~40 px at full bloom
    final spikeLen = lp(0.0, 40.0, sstep(0.65, 1.0, g)) * fit;

    // Stem height is the remainder of the budget once spike is accounted for
    final stemH = (totalMaxH - spikeLen).clamp(0.0, totalMaxH);

    // Absolute ceiling — stem tip must not exceed this y-value
    final stemTopCeiling = groundY - 200.0 * fit;

    for (int si = 0; si < stemCount; si++) {
      final stemX = cx + stemXOffsets[si];

      // Seed-stable lean so outer stems have a gentle natural splay
      final leanX = (_pseudoRand(seed + si * 37) - 0.5) * 10.0 * fit;

      // Wind sway angle — evaluated at full stem height fraction
      final stemSway = windSway(windPhase + si * 0.29, 1.0, windAmp);
      final swayDx = math.sin(stemSway) * stemH * 0.14;

      final stemBase = Offset(stemX, groundY);

      // Clamp tip so stem never clips above the safe ceiling
      final rawTipY = groundY - stemH;
      final tipY = rawTipY < stemTopCeiling ? stemTopCeiling : rawTipY;
      final stemTip = Offset(stemX + leanX + swayDx, tipY);

      // ── Stem body ─────────────────────────────────────────────────────────
      barkBranch(
        canvas,
        stemBase,
        stemTip,
        1.8 * fit,
        const Color(0xFF8D9E6A), // green-grey herb stem
        const Color(0xFF5E6B3F), // shadow side
      );

      // ── Paired bracts (tiny leaves) along the stem ────────────────────────
      _drawStemBracts(canvas, stemBase, stemTip, fit);

      // ── Flower spike at stem tip (g > 0.65) ───────────────────────────────
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
    final pairCount = (stemLen / (20.0 * fit)).floor().clamp(0, 7);
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
      const bracLen = 12.0;
      const bracW = 3.0;

      for (final side in [-1.0, 1.0]) {
        // Bract tip splays out perpendicular, with a slight upward angle
        final tipX = attach.dx
            + perpX * side * bracLen * fit
            - udx * bracLen * 0.25 * fit;
        final tipY = attach.dy
            + perpY * side * bracLen * fit
            - udy * bracLen * 0.25 * fit;

        botanicalLeaf(
          canvas,
          attach,
          Offset(tipX, tipY),
          bracW * fit,
          const Color(0xFFB0BEC5),
          const Color(0xFF78909C),
          vein: false,
        );
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
    // Floret count grows from 10 to 18 as bloom fraction rises
    final floretCount = lp(10.0, 18.0, bloomFrac).round().clamp(10, 18);

    // Spike sway is slightly amplified vs. stem because the tip is more flexible
    final spikeSway = windSway(windPhase + stemIdx * 0.29, 1.15, windAmp);
    final swayTipDx = math.sin(spikeSway) * spikeLen * 0.15;

    final r = 3.5 * fit;

    for (int fi = 0; fi < floretCount; fi++) {
      // t = 0 (bottom of spike) → 1 (top of spike)
      final t = floretCount > 1
          ? fi / (floretCount - 1).toDouble()
          : 0.0;

      // Skip florets that have not yet opened; lower florets open first
      if (t > bloomFrac + 0.08) continue;

      // Fade-in alpha for the opening frontier so the transition is smooth
      final rawAlpha = t <= bloomFrac
          ? 1.0
          : 1.0 - (t - bloomFrac) / 0.08;
      final floretAlpha = rawAlpha.clamp(0.0, 1.0);
      if (floretAlpha <= 0.01) continue;

      // Position: florets ascend from stemTip; lateral wind lean grows with t
      final floretX = stemTip.dx + swayTipDx * t;
      final floretY = stemTip.dy - spikeLen * t;

      // Alternating whorled offset (±2 px) for organic appearance
      final altOff = (fi % 2 == 0 ? 1.0 : -1.0) * 2.0 * fit;
      final center = Offset(floretX + altOff, floretY);

      // Lower florets are rich deep purple; upper are lighter mauve —
      // mirrors the natural colour gradient along a lavender spike.
      final baseColor = Color.lerp(
        const Color(0xFF9C27B0), // dark purple  — bottom florets
        const Color(0xFFBA68C8), // soft lilac   — upper florets
        t,
      )!;
      final shadowColor = Color.lerp(
        const Color(0xFF6A1B9A), // deep indigo shadow
        const Color(0xFF7B1FA2), // medium purple shadow
        t,
      )!;
      final hiColor = Color.lerp(
        const Color(0xFFCE93D8), // specular highlight — lower
        const Color(0xFFE1BEE7), // pale highlight     — upper
        t,
      )!;

      // Fade-in frontier florets using a temporary layer with reduced alpha
      if (floretAlpha < 0.99) {
        canvas.saveLayer(
          null,
          Paint()..color = Colors.white.withValues(alpha: floretAlpha),
        );
      }

      glossyFruit(canvas, center, r, baseColor, shadowColor, hiColor);

      if (floretAlpha < 0.99) canvas.restore();
    }

    // ── Spike calyx tip ───────────────────────────────────────────────────────
    // A tiny dark bud cluster above the topmost open floret completes the shape.
    if (bloomFrac > 0.70) {
      final tipAlpha = sstep(0.70, 0.90, bloomFrac);
      final tipCenter = Offset(
        stemTip.dx + swayTipDx,
        stemTip.dy - spikeLen - 3.0 * fit,
      );

      // Outer bud — dark purple
      canvas.drawCircle(
        tipCenter,
        2.0 * fit,
        Paint()
          ..color =
              const Color(0xFF6A1B9A).withValues(alpha: tipAlpha * 0.85),
      );

      // Inner specular — tiny closed bud highlight
      canvas.drawCircle(
        Offset(tipCenter.dx - 0.5 * fit, tipCenter.dy - 0.5 * fit),
        0.85 * fit,
        Paint()
          ..color = Colors.white.withValues(alpha: tipAlpha * 0.35),
      );
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns pixel x-offsets from cx for [count] stems.
  ///
  /// Pattern: stem 0 → 0, stem 1 → –22*fit, stem 2 → +22*fit,
  ///          stem 3 → –44*fit, stem 4 → +44*fit, stem 5 → –66*fit …
  List<double> _buildStemOffsets(int count, double fit) {
    final out = <double>[];
    for (int i = 0; i < count; i++) {
      if (i == 0) {
        out.add(0.0);
      } else {
        final pair = ((i + 1) / 2).ceil(); // 1,2→1  3,4→2  5,6→3 …
        final sign = (i % 2 == 1) ? -1.0 : 1.0;
        out.add(sign * pair * 22.0 * fit);
      }
    }
    return out;
  }

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
