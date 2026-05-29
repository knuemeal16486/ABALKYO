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

    // ── Seed stage ────────────────────────────────────────────────────────────
    if (g < 0.08) {
      drawSeed(canvas, ground, fit, sstep(0.0, 0.08, g));
      realisticPot(canvas, ground, fit);
      drawWiltOverlay(canvas, size, wiltFactor);
      return;
    }

    // ── Layout constants ──────────────────────────────────────────────────────
    final postSpread = 55.0 * fit;
    final postH = lp(20.0, 175.0, sstep(0.08, 0.85, g)) * fit;
    final postTopY = groundY - postH;

    // ── Trellis posts ─────────────────────────────────────────────────────────
    for (final side in [-1.0, 1.0]) {
      final px = cx + side * postSpread;
      barkBranch(
        canvas,
        Offset(px, groundY),
        Offset(px, postTopY),
        8.0 * fit,
        const Color(0xFF6D4C41),
        const Color(0xFF3E2723),
        lenticels: false,
        rng: rng,
      );
    }

    // ── Horizontal wire lines (3 wires at 35%, 60%, 85% of post height) ───────
    final wirePaint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..strokeWidth = 1.5 * fit
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final frac in [0.35, 0.60, 0.85]) {
      final wy = groundY - postH * frac;
      canvas.drawLine(
        Offset(cx - postSpread, wy),
        Offset(cx + postSpread, wy),
        wirePaint,
      );
    }

    // ── Vine stems climbing the posts ─────────────────────────────────────────
    if (g > 0.12) {
      final vineH = lp(0.0, postH * 0.97, sstep(0.12, 0.85, g));
      // Left vine
      _drawGnarledVine(
        canvas,
        Offset(cx - postSpread * 0.55, groundY),
        vineH,
        fit,
        -1.0,
        math.Random(seed + 1),
      );
      // Right vine (slightly shorter, appears a bit later)
      if (g > 0.20) {
        final rightVineH = lp(0.0, postH * 0.90, sstep(0.20, 0.85, g));
        _drawGnarledVine(
          canvas,
          Offset(cx + postSpread * 0.55, groundY),
          rightVineH,
          fit,
          1.0,
          math.Random(seed + 2),
        );
      }
    }

    // ── Heart-shaped grape leaves ──────────────────────────────────────────────
    if (g > 0.30) {
      final leafProgress = sstep(0.30, 0.75, g);
      final leafCount = (leafProgress * 8.0).clamp(0.0, 8.0).floor();

      // Pre-defined attach positions scattered along both vines at various heights
      final attachDefs = [
        // [side (-1 left / +1 right), heightFrac, xOffset, leafSize]
        [-1.0, 0.28, 18.0, 26.0],
        [ 1.0, 0.35, -20.0, 24.0],
        [-1.0, 0.52, 22.0, 30.0],
        [ 1.0, 0.55, -16.0, 28.0],
        [-1.0, 0.68, 14.0, 32.0],
        [ 1.0, 0.70, -22.0, 30.0],
        [-1.0, 0.82, 20.0, 28.0],
        [ 1.0, 0.80, -18.0, 26.0],
      ];

      for (int li = 0; li < leafCount; li++) {
        final def = attachDefs[li];
        final side = def[0];
        final hFrac = def[1];
        final xOff = def[2];
        final leafSz = def[3];

        final attachX = cx + side * postSpread * 0.55 + xOff * fit;
        final attachY = groundY - postH * hFrac;
        final attach = Offset(attachX, attachY);

        // Wind sway increases with height
        final sway = windSway(windPhase + li * 0.17, hFrac, windAmp);
        // Leaf angle: fan outward from vine
        final baseAngle = side * (math.pi / 4 + li * 0.08);
        final leafAlpha = li == leafCount - 1 && leafProgress < 1.0
            ? sstep(0.0, 1.0 / 8.0, leafProgress * 8.0 % 1.0)
            : 1.0;

        canvas.save();
        canvas.translate(attach.dx, attach.dy);
        canvas.rotate(sway);
        canvas.restore();

        _grapeLeaf(
          canvas,
          attach,
          leafSz * fit,
          baseAngle + sway,
          const Color(0xFF558B2F),
          const Color(0xFF1B5E20),
          alpha: leafAlpha,
        );
      }
    }

    // ── Grape clusters hanging from top wire ──────────────────────────────────
    if (g > 0.55) {
      final ripeness = ((g - 0.55) * 2.2).clamp(0.0, 1.0);
      // 2–4 clusters, positions spread across top wire
      final clusterDefs = [
        // [xFrac of postSpread, wireHeightFrac]
        [-0.50,  0.85],
        [ 0.50,  0.85],
        [-0.15,  0.85],
        [ 0.20,  0.85],
      ];
      final clusterCount =
          ((g - 0.55) / 0.45 * 4.0).clamp(1.0, 4.0).floor();

      for (int ci = 0; ci < clusterCount; ci++) {
        final def = clusterDefs[ci];
        final xFrac = def[0];
        final hFrac = def[1];
        final wireX = cx + xFrac * postSpread;
        final wireY = groundY - postH * hFrac;
        final hangPt = Offset(wireX, wireY);

        final sway = windSway(windPhase + ci * 0.23, hFrac, windAmp);
        final clusterAlpha = ci == 0
            ? sstep(0.55, 0.68, g)
            : sstep(0.55 + ci * 0.08, 0.75 + ci * 0.06, g);

        _drawGrapeCluster(
          canvas,
          hangPt,
          fit,
          ripeness,
          math.Random(seed + 10 + ci),
          sway,
          clusterAlpha,
        );
      }
    }

    // ── Pot ───────────────────────────────────────────────────────────────────
    realisticPot(canvas, ground, fit);
    drawWiltOverlay(canvas, size, wiltFactor);
  }

  // ── Gnarled vine climbing a post ────────────────────────────────────────────
  void _drawGnarledVine(
    Canvas c,
    Offset base,
    double height,
    double fit,
    double leanSide,
    math.Random rng,
  ) {
    if (height < 2.0) return;
    const segs = 10;
    var curX = base.dx;
    var curY = base.dy;

    for (int i = 0; i < segs; i++) {
      final segH = height / segs;
      // Zigzag horizontally — gnarled old vine character
      final zigzag = leanSide * (rng.nextDouble() * 10.0 - 3.5) * fit;
      final nextX = curX + zigzag;
      final nextY = curY - segH;
      final thick = lp(5.0, 2.0, i / segs) * fit;

      barkBranch(
        c,
        Offset(curX, curY),
        Offset(nextX, nextY),
        thick,
        const Color(0xFF5D4037),
        const Color(0xFF3E2723),
        lenticels: i < 3,
        rng: rng,
      );
      curX = nextX;
      curY = nextY;
    }
  }

  // ── Heart-shaped grape leaf ──────────────────────────────────────────────────
  void _grapeLeaf(
    Canvas c,
    Offset attach,
    double size,
    double angle,
    Color light,
    Color dark, {
    double alpha = 1.0,
  }) {
    if (alpha <= 0.01) return;
    c.save();
    c.translate(attach.dx, attach.dy);
    c.rotate(angle);

    final r = size * 0.5;

    // Heart-shaped bezier: base at bottom, two lobes spreading up
    final path = Path()..moveTo(0.0, r * 0.2);
    // Left lobe
    path.cubicTo(-r * 1.6, -r * 0.5, -r * 1.8, -r * 1.6, 0.0, -r * 1.4);
    // Right lobe
    path.cubicTo(r * 1.8, -r * 1.6, r * 1.6, -r * 0.5, 0.0, r * 0.2);
    path.close();

    // Leaf fill — radial gradient for leaf depth
    final bounds = Rect.fromLTWH(-r * 1.8, -r * 1.6, r * 3.6, r * 1.9);
    c.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            light.withValues(alpha: alpha),
            dark.withValues(alpha: alpha),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(bounds),
    );

    // Leaf outline
    c.drawPath(
      path,
      Paint()
        ..color = dark.withValues(alpha: alpha * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.035,
    );

    // Main vein (midrib)
    final veinPaint = Paint()
      ..color = dark.withValues(alpha: alpha * 0.60)
      ..strokeWidth = size * 0.04
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    c.drawLine(Offset(0.0, r * 0.15), Offset(0.0, -r * 1.3), veinPaint);

    // Secondary veins — 5 pairs fanning out
    final sVeinPaint = Paint()
      ..color = dark.withValues(alpha: alpha * 0.38)
      ..strokeWidth = size * 0.025
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final veinDefs = [
      // [startT along midrib, angle from midrib, length frac]
      [0.20, -0.90,  0.55],
      [0.20,  0.90,  0.55],
      [0.42, -1.05,  0.65],
      [0.42,  1.05,  0.65],
      [0.62, -1.15,  0.60],
      [0.62,  1.15,  0.60],
      [0.78, -1.30,  0.50],
      [0.78,  1.30,  0.50],
      // Lobes
      [0.88, -1.55,  0.40],
      [0.88,  1.55,  0.40],
    ];

    for (final vd in veinDefs) {
      final tAlong = vd[0];
      final vAngle = vd[1];
      final vLen = vd[2];
      // Midrib runs from (0, 0.15*r) to (0, -1.3*r)
      final midribY = r * 0.15 - tAlong * r * 1.45;
      final startPt = Offset(0.0, midribY);
      final endPt = Offset(
        math.cos(vAngle - math.pi / 2) * r * vLen,
        midribY + math.sin(vAngle - math.pi / 2) * r * vLen,
      );
      c.drawLine(startPt, endPt, sVeinPaint);
    }

    c.restore();
  }

  // ── Grape cluster hanging from wire ──────────────────────────────────────────
  void _drawGrapeCluster(
    Canvas c,
    Offset wireAttach,
    double fit,
    double ripeness,
    math.Random rng,
    double sway,
    double alpha,
  ) {
    if (alpha <= 0.01) return;

    // Cluster stem from wire to top of bunch
    final stemLen = 18.0 * fit;
    final stemEnd = Offset(wireAttach.dx, wireAttach.dy + stemLen);

    c.save();
    c.translate(wireAttach.dx, wireAttach.dy);
    c.rotate(sway);
    c.translate(-wireAttach.dx, -wireAttach.dy);

    barkBranch(
      c,
      wireAttach,
      stemEnd,
      1.5 * fit,
      const Color(0xFF5D4037),
      const Color(0xFF3E2723),
    );

    // Grape berry colors
    final baseColor = Color.lerp(
      const Color(0xFF8BC34A),
      const Color(0xFF7B1FA2),
      ripeness,
    )!;
    final shadowColor = Color.lerp(
      const Color(0xFF558B2F),
      const Color(0xFF4A148C),
      ripeness,
    )!;
    final hiColor = Color.lerp(
      const Color(0xFFDCEDC8),
      const Color(0xFFE1BEE7),
      ripeness,
    )!;

    // Triangular bunch layout: rows top→bottom: 2, 3, 4, 4, 3, 2
    // Each row: count of grapes and a slight horizontal jitter
    final rows = [
      [2, 0.0],
      [3, 8.5],
      [4, 17.0],
      [4, 25.5],
      [3, 34.0],
      [2, 42.5],
    ];
    final grapeR = 6.0 * fit;
    final spacingX = 12.5 * fit;

    for (int ri = 0; ri < rows.length; ri++) {
      final count = (rows[ri][0] as double).toInt();
      final yOff = (rows[ri][1] as double) * fit;
      final rowWidth = (count - 1) * spacingX;
      final startX = stemEnd.dx - rowWidth / 2;

      for (int gi = 0; gi < count; gi++) {
        final jitterX = (rng.nextDouble() - 0.5) * 1.5 * fit;
        final jitterY = (rng.nextDouble() - 0.5) * 1.5 * fit;
        final gCenter = Offset(
          startX + gi * spacingX + jitterX,
          stemEnd.dy + yOff + jitterY,
        );

        // Slight color variation per berry for organic look
        final hueShift = (rng.nextDouble() - 0.5) * 0.15;
        final berryBase = Color.lerp(baseColor, shadowColor, hueShift.abs())!;

        glossyFruit(
          c,
          gCenter,
          grapeR,
          berryBase.withValues(alpha: alpha),
          shadowColor.withValues(alpha: alpha),
          hiColor.withValues(alpha: alpha),
        );
      }
    }

    // Small tendril at tip of cluster
    final tipY = stemEnd.dy + 42.5 * fit + grapeR;
    _drawTendril(c, Offset(stemEnd.dx, tipY), fit, rng, alpha);

    c.restore();
  }

  // ── Curling tendril ──────────────────────────────────────────────────────────
  void _drawTendril(
    Canvas c,
    Offset base,
    double fit,
    math.Random rng,
    double alpha,
  ) {
    final tendrPaint = Paint()
      ..color = const Color(0xFF5D4037).withValues(alpha: alpha * 0.70)
      ..strokeWidth = 0.9 * fit
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(base.dx, base.dy);
    // A small spiral curl downward
    final sign = rng.nextBool() ? 1.0 : -1.0;
    for (int i = 1; i <= 12; i++) {
      final t = i / 12.0;
      final spiralR = 6.0 * fit * (1.0 - t * 0.5);
      final spiralAngle = sign * t * math.pi * 2.5 + math.pi / 2;
      final x = base.dx + math.cos(spiralAngle) * spiralR * t;
      final y = base.dy + math.sin(spiralAngle) * spiralR * t + 4.0 * fit * t;
      path.lineTo(x, y);
    }
    c.drawPath(path, tendrPaint);
  }
}
