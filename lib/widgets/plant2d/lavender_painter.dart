import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

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
      o.wiltFactor != wiltFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = size.height / 580;
    final cx = size.width / 2;
    final groundY = size.height - 65 * fit;
    final ground = Offset(cx, groundY);
    final rng = math.Random(seed);

    // ── Stage 0: Seed ────────────────────────────────────────────────────────
    if (g < 0.08) {
      drawSeed(canvas, ground, fit, sstep(0.0, 0.08, g));
      realisticPot(canvas, ground, fit);
      drawWiltOverlay(canvas, size, wiltFactor);
      return;
    }

    // ── Stage 1 & 2 & 3: Draw rosette, then stems, then pot on top ──────────

    // ── Rosette leaves (g > 0.08) ────────────────────────────────────────────
    // 8–16 narrow grey-green leaves radiating in a semicircle from groundY
    final leafCount = ((g - 0.08) / 0.52 * 8.0 + 8.0).clamp(8.0, 16.0).floor();
    final leafLen = lp(15.0, 50.0, sstep(0.08, 0.60, g)) * fit;
    final leafWidth = leafLen * 0.12;

    for (int li = 0; li < leafCount; li++) {
      // Evenly spread across the lower semicircle: angles from -π (left) to 0 (right)
      // We also tilt them slightly upward, so we use -π to 0 but shift so they all
      // lean upward. The semicircle from left-horizontal to right-horizontal means
      // angle = -π + li/(leafCount-1) * π, then rotate -π/2 to tilt upward from ground.
      // In canvas coords y-up means angle 0 points right, angle -π/2 points up.
      final t = leafCount > 1 ? li / (leafCount - 1).toDouble() : 0.5;
      // Map t=0..1 to angles spanning a 180° fan pointing upward-ish:
      // from -π (pointing left) through -π/2 (pointing up) to 0 (pointing right)
      // Fan from -π to 0, centred at -π/2 (pointing up)
      final angle = -math.pi + t * math.pi;

      // Per-leaf wind sway
      final sway = windSway(windPhase + li * 0.23, 0.18, windAmp);

      final baseOffset = Offset(cx, groundY - 4.0 * fit);
      final tipOffset = Offset(
        baseOffset.dx + math.cos(angle + sway) * leafLen,
        baseOffset.dy + math.sin(angle + sway) * leafLen,
      );

      botanicalLeaf(
        canvas,
        baseOffset,
        tipOffset,
        leafWidth,
        const Color(0xFFB0BEC5), // light grey-green
        const Color(0xFF607D8B), // dark grey-green
        vein: true,
        veinColor: const Color(0xFF455A64),
      );
    }

    // ── Flower stems & spikes (g > 0.40) ────────────────────────────────────
    if (g > 0.40) {
      final stemCount = ((g - 0.40) / 0.25 * 9.0).clamp(3.0, 9.0).floor();

      // Build x-offsets: centre=0, then ±22, ±44, ±66 * fit in alternating order
      final stemOffsets = <double>[];
      for (int si = 0; si < stemCount; si++) {
        if (si == 0) {
          stemOffsets.add(0.0);
        } else if (si % 2 == 1) {
          stemOffsets.add(-(si + 1) / 2 * 22.0);
        } else {
          stemOffsets.add(si / 2 * 22.0);
        }
      }

      // Total height budget: stem + spike ≤ lp(0, 190, sstep(0.40, 1.0, g)) * fit
      // Spike occupies 35–45 * fit at top.
      final totalMaxH = lp(0.0, 190.0, sstep(0.40, 1.0, g)) * fit;
      final spikeLen = lp(0.0, 40.0, sstep(0.65, 1.0, g)) * fit;
      // Stem height = total budget minus spike, so top of stem ≤ groundY - totalMaxH
      final stemH = (totalMaxH - spikeLen).clamp(0.0, totalMaxH);

      // Hard ceiling: stem top must not exceed groundY - 200*fit
      final maxStemTop = groundY - 200.0 * fit;

      for (int si = 0; si < stemCount; si++) {
        final stemX = cx + stemOffsets[si] * fit;

        // Per-stem slight random lean (seeded)
        final leanSeed = math.Random(seed + si * 37);
        final leanX = (leanSeed.nextDouble() - 0.5) * 8.0 * fit;

        // Wind sway on stem (height fraction 1.0 = top of stem)
        final stemSway = windSway(windPhase + si * 0.29, 1.0, windAmp);

        final stemBase = Offset(stemX, groundY);
        // Apply gentle arc: tip leans with wind + slight seed-based lean
        var stemTipY = groundY - stemH;
        if (stemTipY < maxStemTop) stemTipY = maxStemTop;
        final stemTip = Offset(
          stemX + leanX + math.sin(stemSway) * stemH * 0.15,
          stemTipY,
        );

        // Draw stem using barkBranch
        barkBranch(
          canvas,
          stemBase,
          stemTip,
          1.8 * fit,
          const Color(0xFF8D9E6A), // green-gray bark
          const Color(0xFF5E6B3F), // darker green bark
        );

        // Tiny paired leaves on stem every ~20px
        final stemActualLen = (stemBase - stemTip).distance;
        final leafPairCount = (stemActualLen / (20.0 * fit)).floor().clamp(0, 6);
        for (int pi = 0; pi < leafPairCount; pi++) {
          final t = (pi + 0.5) / leafPairCount.toDouble().clamp(1.0, 99.0);
          final attachPt = Offset(
            lp(stemBase.dx, stemTip.dx, t),
            lp(stemBase.dy, stemTip.dy, t),
          );

          // Stem direction vector
          final sdx = stemTip.dx - stemBase.dx;
          final sdy = stemTip.dy - stemBase.dy;
          final slen = math.sqrt(sdx * sdx + sdy * sdy).clamp(0.001, 99999.0);
          // Perpendicular (left/right)
          final perpX = -sdy / slen;
          final perpY = sdx / slen;

          // Small paired leaves: one each side
          for (final side in [-1.0, 1.0]) {
            final leafTipX = attachPt.dx + perpX * side * 10.0 * fit + sdx / slen * (-4.0 * fit);
            final leafTipY = attachPt.dy + perpY * side * 10.0 * fit + sdy / slen * (-4.0 * fit);
            botanicalLeaf(
              canvas,
              attachPt,
              Offset(leafTipX, leafTipY),
              3.0 * fit,  // very narrow width
              const Color(0xFFB0BEC5),
              const Color(0xFF607D8B),
              vein: false,
            );
          }
        }

        // ── Flower spike at top of stem (g > 0.65) ──────────────────────────
        if (g > 0.65 && spikeLen > 2.0 * fit) {
          final bloomFrac = sstep(0.65, 1.0, g);
          _drawLavenderSpike(
            canvas,
            stemTip,
            spikeLen,
            fit,
            bloomFrac,
            si,
            rng,
          );
        }
      }
    }

    // Pot is drawn AFTER plants so it overlaps the stem bases naturally
    realisticPot(canvas, ground, fit);
    drawWiltOverlay(canvas, size, wiltFactor);
  }

  /// Draws a lavender flower spike at [stemTip], growing upward for [spikeLen].
  void _drawLavenderSpike(
    Canvas canvas,
    Offset stemTip,
    double spikeLen,
    double fit,
    double bloomFrac,
    int stemIdx,
    math.Random rng,
  ) {
    // Number of florets: 10–18, scaled by bloom progress
    final floretCount = lp(10.0, 18.0, bloomFrac).round().clamp(10, 18);

    // Wind sway offset for the entire spike (applied at tip height)
    final spikeSway = windSway(windPhase + stemIdx * 0.29, 1.0, windAmp);
    final swayX = math.sin(spikeSway) * spikeLen * 0.12;

    for (int fi = 0; fi < floretCount; fi++) {
      // t=0 is bottom of spike (just above stem tip), t=1 is top
      final t = fi / (floretCount - 1).toDouble().clamp(1.0, 99.0);

      // Only show florets that have bloomed so far (lower florets open first)
      if (t > bloomFrac) continue;

      // y position: florets go upward from stemTip
      final floretY = stemTip.dy - spikeLen * t;
      // Slight horizontal wind lean increases with height
      final floretX = stemTip.dx + swayX * t;

      // Alternating left/right offset for organic look
      final altOffset = (fi % 2 == 0 ? 1.0 : -1.0) * 2.0 * fit;

      final center = Offset(floretX + altOffset, floretY);
      final r = 3.5 * fit;

      // Lower florets are darker, upper are lighter
      final baseColor = Color.lerp(
        const Color(0xFF9C27B0), // dark purple (bottom)
        const Color(0xFFBA68C8), // lighter purple (top)
        t,
      )!;
      final shadowColor = Color.lerp(
        const Color(0xFF6A1B9A), // deep shadow at bottom
        const Color(0xFF7B1FA2), // lighter shadow at top
        t,
      )!;
      final hiColor = Color.lerp(
        const Color(0xFFCE93D8), // highlight bottom
        const Color(0xFFE1BEE7), // highlight top
        t,
      )!;

      glossyFruit(canvas, center, r, baseColor, shadowColor, hiColor);
    }

    // Spike tip: a tiny pointed calyx extending above the topmost floret
    if (bloomFrac > 0.75) {
      final tipAlpha = sstep(0.75, 1.0, bloomFrac);
      final tipCenter = Offset(
        stemTip.dx + swayX,
        stemTip.dy - spikeLen - 3.5 * fit,
      );
      canvas.drawCircle(
        tipCenter,
        1.8 * fit,
        Paint()
          ..color = const Color(0xFF6A1B9A).withValues(alpha: tipAlpha),
      );
    }
  }
}
