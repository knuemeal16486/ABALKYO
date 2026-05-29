import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TomatoPainter — botanical illustration style
// Growth stages:
//   g < 0.07           seed + pot
//   0.07 – 0.20        thin stem + 2 small leaves + 2 wooden support stakes
//   0.20 – 0.54        stem grows (6 segments), compound pinnate leaves at nodes
//   0.54 – 0.68        yellow star flowers (petal × 5, up to 4 flowers)
//   0.68 – 1.00        red tomatoes ripen (glossyFruit, 3–6 fruits) + calyx
// ─────────────────────────────────────────────────────────────────────────────

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
      o.g != g ||
      o.windPhase != windPhase ||
      o.windAmp != windAmp ||
      o.wiltFactor != wiltFactor ||
      o.seed != seed;

  // ── Main paint entry ───────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final fit = size.height / 580;
    final cx = size.width / 2;
    final groundY = size.height - 65 * fit;
    final ground = Offset(cx, groundY);
    final rng = math.Random(seed);

    // ── Seed stage ────────────────────────────────────────────────────────────
    if (g < 0.07) {
      drawSeed(canvas, ground, fit, sstep(0, 0.07, g));
      realisticPot(canvas, ground, fit);
      drawWiltOverlay(canvas, size, wiltFactor);
      return;
    }

    // ── Shared geometry ───────────────────────────────────────────────────────
    // Stem height: 20px at g=0.07, 170px at g=0.88+
    final totalH = lp(20, 170, sstep(0.07, 0.88, g)) * fit;

    // Number of visible segments (max 6)
    const maxSegs = 6;
    final segProgress = ((g - 0.07) / (0.88 - 0.07) * maxSegs).clamp(0.0, maxSegs.toDouble());
    final visSegs = segProgress.floor();
    final partialFrac = (segProgress - visSegs).clamp(0.0, 1.0);

    // Per-segment horizontal wobble offsets (seeded, stable)
    final wobble = List.generate(maxSegs + 1, (i) {
      // Use seed-stable offsets with a sine pattern
      return math.sin(i * 1.47 + seed * 0.31) * 5.0 * fit;
    });

    // Stem node positions (world coords)
    List<Offset> nodePos = List.generate(maxSegs + 1, (i) {
      return Offset(cx + wobble[i], groundY - totalH * i / maxSegs);
    });

    // ── Support stakes (g > 0.07) ─────────────────────────────────────────────
    // Stakes grow alongside the plant from the seedling stage onward
    {
      final stakeH = lp(0, 175, sstep(0.07, 0.88, g)) * fit;
      final stakeThick = 2.8 * fit;
      for (final dxSign in [-1.0, 1.0]) {
        final sx = cx + dxSign * 28.0 * fit;
        barkBranch(
          canvas,
          Offset(sx, groundY),
          Offset(sx, groundY - stakeH),
          stakeThick,
          const Color(0xFF6D4C41),
          const Color(0xFF5D4037),
          lenticels: true,
          rng: rng,
        );
      }
      // Horizontal tie bar connecting the two stakes at ~60% stake height
      if (g > 0.20) {
        final tieY = groundY - stakeH * 0.60;
        canvas.drawLine(
          Offset(cx - 28.0 * fit, tieY),
          Offset(cx + 28.0 * fit, tieY),
          Paint()
            ..color = const Color(0xFF795548)
            ..strokeWidth = 1.8 * fit
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── Main stem segments ────────────────────────────────────────────────────
    // Thickness tapers from 8px (base) to 4px (tip)
    final stemThickBase = lp(4.0, 8.0, sstep(0.07, 0.88, g));
    for (int i = 0; i < visSegs; i++) {
      final frac = (i < visSegs - 1) ? 1.0 : partialFrac;
      final bot = nodePos[i];
      // Interpolate the tip position for a partial top segment
      final fullTop = nodePos[i + 1];
      final top = Offset(
        lp(bot.dx, fullTop.dx, frac),
        lp(bot.dy, fullTop.dy, frac),
      );
      final thickBot = lp(stemThickBase, stemThickBase * 0.5, i / maxSegs) * fit;
      barkBranch(
        canvas,
        bot,
        top,
        thickBot,
        const Color(0xFF2E7D32),
        const Color(0xFF1B5E20),
      );
      // Narrow the tip call — barkBranch already tapers internally, but we pass
      // average so the taper is visible across segments
      // thickTop used implicitly via barkBranch taper logic above
    }

    // ── Compound pinnate leaf sets at each stem node ──────────────────────────
    // Leaves appear once g > 0.14; one set per node up to visSegs
    if (g > 0.14) {
      final leafSetCount = math.min(
        ((g - 0.14) / (0.54 - 0.14) * maxSegs).floor().clamp(0, maxSegs),
        visSegs,
      );

      for (int li = 0; li < leafSetCount; li++) {
        final nodeIndex = li + 1; // attach at node above ground (skip node 0)
        if (nodeIndex > maxSegs) break;

        final attach = nodePos[nodeIndex];
        final heightFrac = nodeIndex / maxSegs;
        final sway = windSway(windPhase + li * 0.17, heightFrac, windAmp);

        // Size grows as plant matures
        final leafGrowth = sstep(0.14, 0.54, g);
        final leafletLen = lp(20.0, 35.0, leafGrowth * (li + 1) / maxSegs.toDouble()) * fit;
        final leafletW = lp(8.0, 12.0, leafGrowth) * fit;

        // Draw left and right compound leaf arm
        for (final side in [-1.0, 1.0]) {
          canvas.save();
          canvas.translate(attach.dx, attach.dy);
          // Wind sway applied directionally per side
          canvas.rotate(sway * side * 1.8);

          // Rachis (central stalk of compound leaf) going sideways + slightly up
          final rachisLen = leafletLen * 1.6;
          final rachisEnd = Offset(side * rachisLen, -leafletLen * 0.3);

          barkBranch(
            canvas,
            Offset.zero,
            rachisEnd,
            1.4 * fit,
            const Color(0xFF388E3C),
            const Color(0xFF1B5E20),
          );

          // 3 pairs of leaflets along the rachis
          for (int pi = 0; pi < 3; pi++) {
            final t = (pi + 1) / 4.0; // positions at 25%, 50%, 75% of rachis
            final rachisAttach = Offset(rachisEnd.dx * t, rachisEnd.dy * t);

            // Each leaflet angled upward from the rachis
            final leafletAngleUp = -math.pi / 2 + (pi - 1) * 0.18;
            final leafletTip = Offset(
              rachisAttach.dx + math.cos(leafletAngleUp + side * 0.3) * leafletLen,
              rachisAttach.dy + math.sin(leafletAngleUp + side * 0.3) * leafletLen,
            );

            botanicalLeaf(
              canvas,
              rachisAttach,
              leafletTip,
              leafletW,
              const Color(0xFF81C784),
              const Color(0xFF2E7D32),
              vein: true,
              veinColor: const Color(0xFF1B5E20),
            );
          }

          // Terminal leaflet at rachis tip (slightly larger)
          final terminalTip = Offset(
            rachisEnd.dx + side * leafletLen * 0.9,
            rachisEnd.dy - leafletLen * 0.8,
          );
          botanicalLeaf(
            canvas,
            rachisEnd,
            terminalTip,
            leafletW * 1.15,
            const Color(0xFF81C784),
            const Color(0xFF2E7D32),
            vein: true,
            veinColor: const Color(0xFF1B5E20),
          );

          canvas.restore();
        }
      }
    }

    // ── Flowers (g > 0.54) ────────────────────────────────────────────────────
    if (g > 0.54) {
      // 1–4 flowers appearing incrementally
      final flowerCount = ((g - 0.54) / (0.68 - 0.54) * 4).clamp(0, 4).floor();
      for (int fi = 0; fi < flowerCount; fi++) {
        // Place flowers near upper stem nodes with slight random offset
        final segIdx = (maxSegs - 1 - (fi % 3)).clamp(1, maxSegs - 1);
        final nodeAttach = nodePos[segIdx];
        // Use seeded RNG offsets for stable positions
        final dx = (rng.nextDouble() - 0.5) * 28.0 * fit;
        final dy = -(rng.nextDouble() * 10.0 + 4.0) * fit;
        final fc = Offset(nodeAttach.dx + dx, nodeAttach.dy + dy);

        _drawTomatoFlower(canvas, fc, fit);
      }
    }

    // ── Tomato fruits (g > 0.68) ──────────────────────────────────────────────
    if (g > 0.68) {
      // 3–6 fruits appearing and ripening
      final fruitCount = ((g - 0.68) / (1.0 - 0.68) * 6).clamp(1, 6).ceil();
      final ripeness = ((g - 0.68) / 0.32).clamp(0.0, 1.0);

      for (int ri = 0; ri < fruitCount; ri++) {
        final segIdx = (maxSegs - 1 - (ri % 3)).clamp(1, maxSegs - 1);
        final nodeAttach = nodePos[segIdx];
        final dx = (rng.nextDouble() - 0.5) * 34.0 * fit;
        final dy = -(rng.nextDouble() * 8.0 + 2.0) * fit;
        final rc = Offset(nodeAttach.dx + dx, nodeAttach.dy + dy);

        // Each fruit has its own ripeness stage, earlier fruits are riper
        final fruitRipeness = (ripeness - ri * 0.12).clamp(0.0, 1.0);
        final fruitR = lp(5.0, 15.0, fruitRipeness) * fit;

        _drawTomato(canvas, rc, fruitR, fruitRipeness);
      }
    }

    // ── Pot (always on top of soil, below plant) ──────────────────────────────
    realisticPot(canvas, ground, fit);

    // ── Wilt overlay ──────────────────────────────────────────────────────────
    drawWiltOverlay(canvas, size, wiltFactor);
  }

  // ── Flower helper ──────────────────────────────────────────────────────────
  // 5-petal star tomato flower with stamen dot

  void _drawTomatoFlower(Canvas canvas, Offset center, double fit) {
    final petalLen = 9.0 * fit;
    final petalW = 5.5 * fit;

    for (int i = 0; i < 5; i++) {
      // Petals point outward, rotate 72° each; offset from 12 o'clock
      final angle = i * math.pi * 2 / 5 - math.pi / 2;
      petal(
        canvas,
        center,
        petalLen,
        petalW,
        angle,
        const Color(0xFFFFEE58), // light yellow
        const Color(0xFFFDD835), // darker yellow
      );
    }

    // Central stamen cluster — orange dot
    canvas.drawCircle(
      center,
      3.0 * fit,
      Paint()
        ..color = const Color(0xFFFF8F00)
        ..style = PaintingStyle.fill,
    );
    // Tiny specular on stamen
    canvas.drawCircle(
      Offset(center.dx - 0.8 * fit, center.dy - 0.8 * fit),
      0.9 * fit,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  // ── Tomato fruit helper ────────────────────────────────────────────────────
  // Glossy sphere + green calyx of 5 sepals

  void _drawTomato(Canvas canvas, Offset center, double r, double ripeness) {
    final baseColor = Color.lerp(
      const Color(0xFF8BC34A), // unripe green
      const Color(0xFFD32F2F), // ripe deep red
      ripeness,
    )!;
    final shadowColor = Color.lerp(
      const Color(0xFF558B2F),
      const Color(0xFF8B0000),
      ripeness,
    )!;
    final hiColor = Color.lerp(
      const Color(0xFFC5E1A5),
      const Color(0xFFFF8A80),
      ripeness,
    )!;

    // Fruit body
    glossyFruit(canvas, center, r, baseColor, shadowColor, hiColor);

    // Stem nub at top
    canvas.drawLine(
      Offset(center.dx, center.dy - r),
      Offset(center.dx + 1.5 * (r / 8), center.dy - r - 4.0 * (r / 8)),
      Paint()
        ..color = const Color(0xFF2E7D32)
        ..strokeWidth = 1.5 * (r / 8).clamp(0.8, 2.0)
        ..strokeCap = StrokeCap.round,
    );

    // Calyx: 5 thin triangular sepals radiating from the top of the fruit
    final calyxPaint = Paint()
      ..color = const Color(0xFF388E3C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (r * 0.13).clamp(0.7, 2.0)
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5 - math.pi / 2;
      // Base of sepal sits at the top of the fruit sphere
      final baseX = center.dx + math.cos(angle) * r * 0.35;
      final baseY = (center.dy - r) + math.sin(angle).abs() * r * 0.1;
      // Tip of sepal extends outward-upward
      final tipX = center.dx + math.cos(angle) * r * 0.80;
      final tipY = center.dy - r - math.sin(math.pi / 2 + angle.abs() * 0.3) * r * 0.45;

      canvas.drawLine(
        Offset(baseX, baseY),
        Offset(tipX, tipY),
        calyxPaint,
      );
    }
  }
}
