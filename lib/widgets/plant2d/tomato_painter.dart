import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TomatoPainter — botanical illustration style (bezier curves, gradients,
// proper plant anatomy)
//
// Growth stages:
//   g < 0.07           seed + pot
//   0.07 – 0.20        thin stem (20 px) + cotyledon pair + 2 wooden stakes
//   0.20 – 0.54        stem grows to 170 px (6 segments);
//                      compound pinnate leaf sets at every node
//   0.54 – 0.68        yellow star flowers (petal × 5, 1–4 flowers)
//   0.68 – 1.00        tomatoes ripen green→red (glossyFruit, 3–6 fruits)
//                      + bezier calyx sepals
//
// Canvas conventions (never change):
//   fit     = size.height / 580
//   cx      = size.width / 2
//   groundY = size.height - 65 * fit
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

    // Seeded RNG — used only for stake lenticels so its consumption is constant
    // regardless of growth stage, keeping all positions stable per seed value.
    final rng = math.Random(seed);

    // ── Seed stage ────────────────────────────────────────────────────────────
    if (g < 0.07) {
      drawSeed(canvas, ground, fit, sstep(0.0, 0.07, g));
      realisticPot(canvas, ground, fit);
      drawWiltOverlay(canvas, size, wiltFactor);
      return;
    }

    // ── Shared geometry ───────────────────────────────────────────────────────
    // Stem height: 20 px at g = 0.07, 170 px at g = 0.88+.
    final totalH = lp(20.0, 170.0, sstep(0.07, 0.88, g)) * fit;

    const maxSegs = 6;
    // segProgress ∈ [0, maxSegs]: floor = complete segments, fraction = growing
    // tip progress into the next segment.
    final segProgress =
        ((g - 0.07) / (0.88 - 0.07) * maxSegs)
            .clamp(0.0, maxSegs.toDouble());
    final visSegs = segProgress.floor();
    final partialFrac = (segProgress - visSegs).clamp(0.0, 1.0);

    // Stable per-node horizontal wobble using a sine pattern keyed to seed.
    // This gives the stem a natural zigzag without any RNG drain.
    final wobble = List<double>.generate(maxSegs + 1, (i) {
      return math.sin(i * 1.47 + seed * 0.31) * 5.0 * fit;
    });

    // World-space positions of each stem node (index 0 = ground level).
    final nodePos = List<Offset>.generate(maxSegs + 1, (i) {
      return Offset(cx + wobble[i], groundY - totalH * i / maxSegs);
    });

    // ── Support stakes ────────────────────────────────────────────────────────
    // Two thin wooden posts flank the plant from seedling onward.
    // They grow ahead of the stem height so they always visibly support it.
    {
      final stakeH = lp(25.0, 185.0, sstep(0.07, 0.88, g)) * fit;
      const stakeThick = 2.8;
      const stakeColor = Color(0xFF6D4C41);
      const stakeColorDark = Color(0xFF5D4037);

      for (final dxSign in [-1.0, 1.0]) {
        final sx = cx + dxSign * 28.0 * fit;
        barkBranch(
          canvas,
          Offset(sx, groundY),
          Offset(sx, groundY - stakeH),
          stakeThick * fit,
          stakeColor,
          stakeColorDark,
          lenticels: true,
          rng: rng,
        );
      }

      // Horizontal jute tie-bars: high tie at 60 %, low tie at 30 % (the
      // low bar only appears once the plant is tall enough to need it).
      if (g > 0.20) {
        final tiePaint = Paint()
          ..color = const Color(0xFF8D6E63)
          ..strokeWidth = 1.8 * fit
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(cx - 28.0 * fit, groundY - stakeH * 0.60),
          Offset(cx + 28.0 * fit, groundY - stakeH * 0.60),
          tiePaint,
        );
        if (g > 0.40) {
          canvas.drawLine(
            Offset(cx - 28.0 * fit, groundY - stakeH * 0.30),
            Offset(cx + 28.0 * fit, groundY - stakeH * 0.30),
            tiePaint,
          );
        }
      }
    }

    // ── Main stem ─────────────────────────────────────────────────────────────
    // barkBranch segments taper from 8 px (base) to 4 px (tip).
    {
      final stemThickBase = lp(4.0, 8.0, sstep(0.07, 0.88, g));

      for (int i = 0; i < visSegs; i++) {
        final frac = (i < visSegs - 1) ? 1.0 : partialFrac;
        final bot = nodePos[i];
        final fullTop = nodePos[i + 1];
        final top = Offset(
          lp(bot.dx, fullTop.dx, frac),
          lp(bot.dy, fullTop.dy, frac),
        );
        final thick =
            lp(stemThickBase, stemThickBase * 0.5, i / maxSegs) * fit;

        barkBranch(
          canvas,
          bot,
          top,
          thick,
          const Color(0xFF2E7D32),
          const Color(0xFF1B5E20),
        );
      }

      // Tender growing tip — slightly lighter green, thinner.
      if (visSegs < maxSegs && partialFrac > 0.02) {
        final bot = nodePos[visSegs];
        final nextIdx = (visSegs + 1).clamp(0, maxSegs);
        final tipPos = Offset(
          lp(bot.dx, nodePos[nextIdx].dx, partialFrac),
          lp(bot.dy, nodePos[nextIdx].dy, partialFrac),
        );
        final thick =
            lp(lp(4.0, 8.0, sstep(0.07, 0.88, g)), 2.5, 0.5) * fit;
        barkBranch(
          canvas,
          bot,
          tipPos,
          thick,
          const Color(0xFF43A047),
          const Color(0xFF2E7D32),
        );
      }
    }

    // ── Compound pinnate leaf sets at stem nodes ───────────────────────────────
    // Each set: one left arm + one right arm.  Each arm = a rachis bearing
    // 3 opposite leaflet pairs and a terminal leaflet (standard tomato anatomy).
    if (g > 0.14) {
      final leafSetCount = math.min(
        ((g - 0.14) / (0.54 - 0.14) * maxSegs).floor().clamp(0, maxSegs),
        visSegs,
      );
      final leafGrowth = sstep(0.14, 0.54, g);

      for (int li = 0; li < leafSetCount; li++) {
        final nodeIndex = (li + 1).clamp(1, maxSegs);
        final attach = nodePos[nodeIndex];
        final heightFrac = nodeIndex / maxSegs;
        final sway = windSway(windPhase + li * 0.17, heightFrac, windAmp);

        final leafletLen =
            lp(18.0, 34.0, leafGrowth * (li + 1) / maxSegs) * fit;
        final leafletW = lp(7.0, 12.0, leafGrowth) * fit;

        for (final side in [-1.0, 1.0]) {
          _drawCompoundLeafArm(
              canvas, attach, side, sway, leafletLen, leafletW, fit);
        }
      }
    }

    // ── Seedling cotyledons (fade in, then fade out as true leaves appear) ────
    if (g >= 0.07 && g < 0.30) {
      final alpha = sstep(0.07, 0.14, g) * (1.0 - sstep(0.22, 0.30, g));
      if (alpha > 0.01) {
        _drawCotyledons(canvas, nodePos[math.min(1, visSegs)], fit, alpha);
      }
    }

    // ── Flowers (g > 0.54) ────────────────────────────────────────────────────
    // Up to 4 star-shaped flowers appear near the upper stem nodes.
    // Per-element sub-RNGs (keyed by seed ^ index) guarantee stable positions
    // regardless of how many lenticel calls were consumed above.
    if (g > 0.54) {
      final flowerCount =
          ((g - 0.54) / (0.68 - 0.54) * 4).clamp(0.0, 4.0).floor();

      for (int fi = 0; fi < flowerCount; fi++) {
        final fr = math.Random(seed ^ (fi * 0x9e3779b9));
        final segIdx = (maxSegs - 1 - (fi % 3)).clamp(2, maxSegs - 1);
        final nodeAttach = nodePos[segIdx];
        final dx = (fr.nextDouble() - 0.5) * 30.0 * fit;
        final dy = -(fr.nextDouble() * 12.0 + 5.0) * fit;
        final fc = Offset(nodeAttach.dx + dx, nodeAttach.dy + dy);

        // Newest flower fades in; all older ones are fully opaque.
        final alpha = fi < flowerCount - 1
            ? 1.0
            : sstep(
                0.54 + fi * (0.14 / 4.0),
                0.54 + (fi + 1) * (0.14 / 4.0),
                g,
              );

        _drawTomatoFlower(canvas, fc, fit, alpha);
      }
    }

    // ── Tomato fruits (g > 0.68) ──────────────────────────────────────────────
    // Up to 6 fruits ripen from green to deep red; earlier-indexed fruits lead
    // ripeness by a fixed offset, mimicking natural sequential ripening.
    if (g > 0.68) {
      final fruitCount =
          ((g - 0.68) / (1.0 - 0.68) * 6).clamp(1.0, 6.0).ceil();
      final globalRipeness = ((g - 0.68) / 0.32).clamp(0.0, 1.0);

      for (int ri = 0; ri < fruitCount; ri++) {
        final fr = math.Random(seed ^ (ri * 0x6c62272e + 0xdeadbeef));
        final segIdx = (maxSegs - 1 - (ri % 3)).clamp(2, maxSegs - 1);
        final nodeAttach = nodePos[segIdx];
        final dx = (fr.nextDouble() - 0.5) * 36.0 * fit;
        final dy = -(fr.nextDouble() * 10.0 + 3.0) * fit;
        final rc = Offset(nodeAttach.dx + dx, nodeAttach.dy + dy);

        final fruitRipeness = (globalRipeness - ri * 0.13).clamp(0.0, 1.0);
        final fruitR = lp(5.0, 15.0, fruitRipeness) * fit;

        // Pedicel — thin green line connecting fruit to the vine.
        final pedicelTipX = rc.dx + (fr.nextDouble() - 0.5) * 3.0 * fit;
        final pedicelTipY = rc.dy - fruitR - 7.0 * fit;
        canvas.drawLine(
          Offset(rc.dx, rc.dy - fruitR),
          Offset(pedicelTipX, pedicelTipY),
          Paint()
            ..color = const Color(0xFF388E3C)
            ..strokeWidth = (1.3 * fit).clamp(0.7, 2.2)
            ..strokeCap = StrokeCap.round,
        );

        _drawTomato(canvas, rc, fruitR, fruitRipeness, fit);
      }
    }

    // ── Pot (drawn last so its rim covers the stem base cleanly) ─────────────
    realisticPot(canvas, ground, fit);

    // ── Wilt overlay ──────────────────────────────────────────────────────────
    drawWiltOverlay(canvas, size, wiltFactor);
  }

  // ── Compound leaf arm ─────────────────────────────────────────────────────
  // One directional arm (left or right) of a tomato compound leaf.
  // The rachis extends diagonally outward from the stem node; three opposite
  // leaflet pairs fan along it; a larger terminal leaflet caps the tip.

  void _drawCompoundLeafArm(
    Canvas canvas,
    Offset attach,
    double side,        // -1.0 = left, +1.0 = right
    double sway,        // wind sway angle in radians
    double leafletLen,  // leaflet length in px (already multiplied by fit)
    double leafletW,    // leaflet max-width in px (already multiplied by fit)
    double fit,
  ) {
    canvas.save();
    canvas.translate(attach.dx, attach.dy);
    // Both arms lean the same direction in the wind; multiplying sway by side
    // keeps the sign correct for either arm.
    canvas.rotate(sway * side * 1.6);

    // Rachis direction: ~69 ° from straight-up, opening toward the plant side.
    final rachisAngle = side * (math.pi * 0.38);
    final rachisLen = leafletLen * 1.65;
    // Canvas Y is downward, so "up" is -Y.  Rotating from the -Y axis:
    final rachisEnd = Offset(
      math.cos(rachisAngle - math.pi / 2) * rachisLen,
      math.sin(rachisAngle - math.pi / 2) * rachisLen,
    );

    // Draw the rachis as a slender green stalk.
    barkBranch(
      canvas,
      Offset.zero,
      rachisEnd,
      1.3 * fit,
      const Color(0xFF388E3C),
      const Color(0xFF1B5E20),
    );

    // t-positions of the three leaflet pairs along the rachis.
    const tValues = [0.28, 0.52, 0.76];
    final rachisDir = math.atan2(rachisEnd.dy, rachisEnd.dx);
    // The perpendicular direction pointing "above" the rachis (toward the sky).
    final perpUp = rachisDir - math.pi / 2;

    for (int pi = 0; pi < tValues.length; pi++) {
      final t = tValues[pi];
      final rachisPoint = Offset(rachisEnd.dx * t, rachisEnd.dy * t);

      // Fan angle: inner leaflets point more upright, outer ones spread wider.
      final fanAngle = perpUp + side * (pi - 1) * 0.22;
      final leafletTip = Offset(
        rachisPoint.dx + math.cos(fanAngle) * leafletLen,
        rachisPoint.dy + math.sin(fanAngle) * leafletLen,
      );

      botanicalLeaf(
        canvas,
        rachisPoint,
        leafletTip,
        leafletW,
        const Color(0xFF81C784),
        const Color(0xFF2E7D32),
        vein: true,
        veinColor: const Color(0xFF1B5E20),
      );
    }

    // Terminal leaflet at the rachis tip — largest, pointing toward the sky.
    final terminalDir = rachisDir - math.pi / 2;
    final terminalTip = Offset(
      rachisEnd.dx + math.cos(terminalDir) * leafletLen * 1.15,
      rachisEnd.dy + math.sin(terminalDir) * leafletLen * 1.15,
    );

    botanicalLeaf(
      canvas,
      rachisEnd,
      terminalTip,
      leafletW * 1.20,
      const Color(0xFF81C784),
      const Color(0xFF2E7D32),
      vein: true,
      veinColor: const Color(0xFF1B5E20),
    );

    canvas.restore();
  }

  // ── Seedling cotyledons ───────────────────────────────────────────────────
  // A pair of small oval seed-leaves flanking the young stem.

  void _drawCotyledons(
    Canvas canvas,
    Offset attach,
    double fit,
    double alpha,
  ) {
    for (final side in [-1.0, 1.0]) {
      final tip = Offset(
        attach.dx + side * 14.0 * fit,
        attach.dy - 8.0 * fit,
      );
      botanicalLeaf(
        canvas,
        attach,
        tip,
        5.0 * fit,
        Color(0xFF81C784).withValues(alpha: alpha),
        Color(0xFF388E3C).withValues(alpha: alpha),
        vein: false,
      );
    }
  }

  // ── Tomato flower ─────────────────────────────────────────────────────────
  // Five reflexed yellow petals (via petal()) with an orange stamen cone.

  void _drawTomatoFlower(
    Canvas canvas,
    Offset center,
    double fit,
    double alpha,
  ) {
    if (alpha <= 0.01) return;

    final petalLen = 9.5 * fit;
    final petalW = 5.0 * fit;

    for (int i = 0; i < 5; i++) {
      final angle = i * (math.pi * 2.0 / 5.0) - math.pi / 2.0;
      petal(
        canvas,
        center,
        petalLen,
        petalW,
        angle,
        Color(0xFFFFEE58).withValues(alpha: alpha),
        Color(0xFFFDD835).withValues(alpha: alpha),
      );
    }

    // Orange stamen cone body.
    canvas.drawCircle(
      center,
      3.2 * fit,
      Paint()..color = Color(0xFFFF8F00).withValues(alpha: alpha),
    );
    // Subtle rim highlight on the cone.
    canvas.drawCircle(
      center,
      3.2 * fit,
      Paint()
        ..color = Color(0xFFFFCC80).withValues(alpha: alpha * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * fit,
    );
    // Tiny specular dot.
    canvas.drawCircle(
      Offset(center.dx - 0.9 * fit, center.dy - 0.9 * fit),
      0.9 * fit,
      Paint()..color = Colors.white.withValues(alpha: alpha * 0.60),
    );
  }

  // ── Tomato fruit ──────────────────────────────────────────────────────────
  // A glossy sphere that ripens from green to deep red, capped by a 5-sepal
  // calyx rendered as filled bezier lobes with midrib veins.

  void _drawTomato(
    Canvas canvas,
    Offset center,
    double r,
    double ripeness,
    double fit,
  ) {
    // Colour lerp driven by ripeness (0 = unripe green, 1 = ripe deep red).
    final baseColor = Color.lerp(
      const Color(0xFF8BC34A),
      const Color(0xFFD32F2F),
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

    // Glossy sphere (radial gradient + specular highlight).
    glossyFruit(canvas, center, r, baseColor, shadowColor, hiColor);

    // ── Calyx: 5 bezier-triangle sepals at the blossom end ───────────────────
    // Each sepal is a quadratic-bezier lobe curling outward from the top of
    // the fruit, drawn filled then outlined, with a single midrib vein.
    final topY = center.dy - r; // canvas Y of the fruit's blossom end

    final calyxFill = Paint()
      ..color = const Color(0xFF388E3C)
      ..style = PaintingStyle.fill;
    final calyxStroke = Paint()
      ..color = const Color(0xFF1B5E20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (r * 0.09).clamp(0.5, 1.5)
      ..strokeCap = StrokeCap.round;
    final veinPaint = Paint()
      ..color = const Color(0xFF1B5E20).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (r * 0.07).clamp(0.4, 1.0)
      ..strokeCap = StrokeCap.round;

    for (int si = 0; si < 5; si++) {
      // Midline angle for this sepal; 0 = 12 o'clock in canvas space.
      final mid = si * (math.pi * 2.0 / 5.0) - math.pi / 2.0;

      // Attachment point near the blossom-end hole of the fruit.
      final sepalBaseR = r * 0.28;
      final bx = center.dx + math.cos(mid) * sepalBaseR;
      final by = topY + math.sin(mid).abs() * r * 0.10;

      // Tip of the sepal: extends radially and slightly above the fruit top.
      final tipR = r * 0.92;
      final tx = center.dx + math.cos(mid) * tipR;
      // Vertical offset of the tip — flatter at 3/9 o'clock, pointier at 12.
      final ty = topY -
          r * 0.54 * math.pow(math.cos(mid * 0.5).abs(), 0.6).toDouble();

      // Bezier control point — the outward bulge of the sepal lobe.
      final cx2 = center.dx + math.cos(mid) * (tipR * 0.55);
      final cy2 = topY - r * 0.14;

      // Half-width perpendicular to the sepal midline for the lobe base.
      final hw = r * 0.13;
      final px = -math.sin(mid) * hw;
      final py = math.cos(mid) * hw;

      final sepalPath = Path()
        ..moveTo(bx + px, by + py)
        ..quadraticBezierTo(cx2, cy2, tx, ty)
        ..quadraticBezierTo(cx2, cy2, bx - px, by - py)
        ..close();

      canvas.drawPath(sepalPath, calyxFill);
      canvas.drawPath(sepalPath, calyxStroke);

      // Midrib vein — runs 70 % of the way to the sepal tip.
      canvas.drawLine(
        Offset(bx, by),
        Offset(lp(bx, tx, 0.70), lp(by, ty, 0.70)),
        veinPaint,
      );
    }

    // Stubby pedicel attachment nub above the calyx.
    canvas.drawLine(
      Offset(center.dx, topY),
      Offset(center.dx + 1.5 * fit, topY - 5.0 * fit),
      Paint()
        ..color = const Color(0xFF2E7D32)
        ..strokeWidth = (1.4 * fit).clamp(0.6, 2.0)
        ..strokeCap = StrokeCap.round,
    );
  }
}
