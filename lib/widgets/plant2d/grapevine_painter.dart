import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GrapevinePainter — realistic botanical illustration
//
// Growth stages:
//   g < 0.08           seed + pot
//   0.08 – 0.30        trellis posts appear; thin gnarled vine climbs
//   0.30 – 0.55        heart-shaped 5-lobed grape leaves along vine
//   0.55 – 1.00        glossy grape clusters hang from top wire, ripening
//                      from green → deep purple
// ─────────────────────────────────────────────────────────────────────────────

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
      o.wiltFactor != wiltFactor ||
      o.seed != seed;

  // ── Main paint entry ────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final fit = size.height / 580;
    final cx = size.width / 2;
    final groundY = size.height - 65 * fit;
    final ground = Offset(cx, groundY);
    final rng = math.Random(seed);

    // ── Seed stage ─────────────────────────────────────────────────────────────
    if (g < 0.08) {
      drawSeed(canvas, ground, fit, sstep(0.0, 0.08, g));
      realisticPot(canvas, ground, fit);
      drawWiltOverlay(canvas, size, wiltFactor);
      return;
    }

    // ── Layout constants ───────────────────────────────────────────────────────
    final postSpread = 55.0 * fit;
    final postH = lp(20.0, 185.0, sstep(0.08, 0.88, g)) * fit;
    final postTopY = groundY - postH;
    final postAppear = sstep(0.08, 0.22, g);

    // ── Trellis posts ──────────────────────────────────────────────────────────
    for (final side in [-1.0, 1.0]) {
      final px = cx + side * postSpread;
      barkBranch(
        canvas,
        Offset(px, groundY),
        Offset(px, postTopY),
        8.0 * fit,
        Color.lerp(const Color(0xFF6D4C41), Colors.transparent, 1.0 - postAppear)!,
        Color.lerp(const Color(0xFF3E2723), Colors.transparent, 1.0 - postAppear)!,
        lenticels: g > 0.15,
        rng: rng,
      );

      // Post cap — small horizontal piece at each post top
      if (postAppear > 0.3) {
        canvas.drawLine(
          Offset(px - 4.0 * fit, postTopY),
          Offset(px + 4.0 * fit, postTopY),
          Paint()
            ..color = const Color(0xFF4E342E).withValues(alpha: postAppear)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9.0 * fit
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── Horizontal wire lines (35%, 60%, 85% of post height) ──────────────────
    final wirePaint = Paint()
      ..color = const Color(0xFF9E9E9E).withValues(alpha: postAppear)
      ..strokeWidth = 1.5 * fit
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    for (final frac in [0.35, 0.60, 0.85]) {
      final wy = groundY - postH * frac;
      // Slight catenary droop
      canvas.drawPath(
        Path()
          ..moveTo(cx - postSpread, wy)
          ..quadraticBezierTo(cx, wy + 3.0 * fit, cx + postSpread, wy),
        wirePaint,
      );

      // Tensioner dots at post attachment points
      if (postAppear > 0.5) {
        final dotPaint = Paint()
          ..color = const Color(0xFF757575).withValues(alpha: postAppear * 0.8);
        for (final dSide in [-1.0, 1.0]) {
          canvas.drawCircle(Offset(cx + dSide * postSpread, wy), 2.2 * fit, dotPaint);
        }
      }
    }

    // ── Vine stems climbing the posts ─────────────────────────────────────────
    if (g > 0.12) {
      final vineH = lp(0.0, postH * 0.98, sstep(0.12, 0.88, g));

      // Left vine — primary, thicker, climbs earlier
      _drawGnarledVine(
        canvas,
        Offset(cx - postSpread * 0.52, groundY),
        vineH, fit, -1.0,
        math.Random(seed + 1),
        thickBase: 5.5,
      );

      // Right vine — secondary, slightly thinner
      if (g > 0.18) {
        _drawGnarledVine(
          canvas,
          Offset(cx + postSpread * 0.52, groundY),
          lp(0.0, postH * 0.93, sstep(0.18, 0.88, g)),
          fit, 1.0,
          math.Random(seed + 2),
          thickBase: 4.5,
        );
      }

      // Central spur — thin vine rising from pot centre
      if (g > 0.28) {
        _drawGnarledVine(
          canvas,
          Offset(cx, groundY),
          postH * 0.25 * sstep(0.28, 0.55, g),
          fit, 0.0,
          math.Random(seed + 3),
          thickBase: 3.0,
        );
      }
    }

    // ── Heart-shaped grape leaves ──────────────────────────────────────────────
    if (g > 0.30) {
      final leafProgress = sstep(0.30, 0.82, g);
      const totalLeaves = 14;
      final leafCount =
          (leafProgress * totalLeaves).clamp(0.0, totalLeaves.toDouble()).floor();

      // [side(-1/+1), heightFrac, xOffsetUnscaled, leafSizeUnscaled]
      const attachDefs = <List<double>>[
        [-1.0, 0.22, 18.0, 24.0],
        [ 1.0, 0.28, -20.0, 22.0],
        [-1.0, 0.36, 26.0, 27.0],
        [ 1.0, 0.42, -24.0, 25.0],
        [-1.0, 0.50, 22.0, 32.0],
        [ 1.0, 0.55, -18.0, 30.0],
        [-1.0, 0.62, 28.0, 34.0],
        [ 1.0, 0.67, -26.0, 32.0],
        [-1.0, 0.72, 20.0, 29.0],
        [ 1.0, 0.76, -22.0, 28.0],
        [-1.0, 0.82, 16.0, 26.0],
        [ 1.0, 0.80, -18.0, 25.0],
        [-1.0, 0.88, 14.0, 22.0],
        [ 1.0, 0.86, -16.0, 21.0],
      ];

      for (int li = 0; li < leafCount; li++) {
        final def    = attachDefs[li];
        final side   = def[0];
        final hFrac  = def[1];
        final xOff   = def[2];
        final leafSz = def[3];

        final attach = Offset(
          cx + side * postSpread * 0.52 + xOff * fit,
          groundY - postH * hFrac,
        );
        final sway = windSway(windPhase + li * 0.19, hFrac, windAmp);
        final baseAngle = side < 0
            ? -(math.pi * 0.38 + li * 0.06)
            :  (math.pi * 0.38 + li * 0.06);
        final leafAlpha = (li == leafCount - 1 && leafProgress < 1.0)
            ? sstep(0.0, 1.0 / totalLeaves, (leafProgress * totalLeaves) % 1.0)
            : 1.0;

        _grapeLeaf(
          canvas, attach, leafSz * fit, baseAngle + sway,
          li.isEven ? const Color(0xFF66BB6A) : const Color(0xFF558B2F),
          li.isEven ? const Color(0xFF2E7D32) : const Color(0xFF1B5E20),
          alpha: leafAlpha,
        );
      }

      // Tendrils coiling around the lower wires (g > 0.40)
      if (g > 0.40) {
        final tendrilAlpha = sstep(0.40, 0.60, g);
        final trng = math.Random(seed + 99);
        for (final wireFrac in [0.35, 0.60]) {
          final wy = groundY - postH * wireFrac;
          for (final tSide in [-0.6, 0.6]) {
            _drawTendril(
              canvas,
              Offset(cx + tSide * postSpread, wy - 4.0 * fit),
              fit, trng, tendrilAlpha,
            );
          }
        }
      }
    }

    // ── Grape clusters hanging from top wire ───────────────────────────────────
    if (g > 0.55) {
      final ripeness = ((g - 0.55) * 2.2).clamp(0.0, 1.0);
      const topWireFrac   = 0.85;
      const clusterXFracs = <double>[-0.35, 0.35];

      final clusterCount =
          ((g - 0.55) / 0.45 * clusterXFracs.length)
              .clamp(1.0, clusterXFracs.length.toDouble())
              .floor();

      for (int ci = 0; ci < clusterCount; ci++) {
        final wireY = groundY - postH * topWireFrac + 2.0 * fit;
        _drawGrapeCluster(
          canvas,
          Offset(cx + clusterXFracs[ci] * postSpread, wireY),
          fit, ripeness,
          math.Random(seed + 10 + ci),
          windSway(windPhase + ci * 0.27, topWireFrac, windAmp),
          ci == 0
              ? sstep(0.55, 0.66, g)
              : sstep(0.55 + ci * 0.07, 0.72 + ci * 0.05, g),
        );
      }
    }

    // ── Pot ────────────────────────────────────────────────────────────────────
    realisticPot(canvas, ground, fit);
    drawWiltOverlay(canvas, size, wiltFactor);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // _drawGnarledVine
  // ────────────────────────────────────────────────────────────────────────────

  void _drawGnarledVine(
    Canvas c,
    Offset base,
    double height,
    double fit,
    double leanSide,
    math.Random rng, {
    double thickBase = 5.0,
  }) {
    if (height < 2.0) return;
    const segs = 12;
    var curX = base.dx;
    var curY = base.dy;

    for (int i = 0; i < segs; i++) {
      final tFrac = i / segs.toDouble();
      final segH  = height / segs;
      final range = (leanSide == 0 ? 6.0 : 9.0) * fit;
      final zigzag = leanSide * (rng.nextDouble() * range - range * 0.35);
      final nextX = curX + zigzag;
      final nextY = curY - segH;
      final thick = lp(thickBase, 1.5, tFrac) * fit;

      barkBranch(
        c,
        Offset(curX, curY),
        Offset(nextX, nextY),
        thick,
        const Color(0xFF5D4037),
        const Color(0xFF3E2723),
        lenticels: i < 4 && thick > 2.5,
        rng: rng,
      );
      curX = nextX;
      curY = nextY;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // _grapeLeaf: heart-shaped cordate grape leaf with veins and petiole
  //
  // Origin = petiole attachment point (canvas coords, +Y is down).
  // The leaf lobes rise into −Y; the petiole hangs into +Y.
  // ────────────────────────────────────────────────────────────────────────────

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

    // ── Silhouette: cordate (heart) shape ─────────────────────────────────
    final path = Path()..moveTo(0.0, r * 0.2);
    // Left lobe
    path.cubicTo(-r * 1.6, -r * 0.5, -r * 1.8, -r * 1.6, 0.0, -r * 1.4);
    // Right lobe
    path.cubicTo(r * 1.8, -r * 1.6, r * 1.6, -r * 0.5, 0.0, r * 0.2);
    path.close();

    final bounds = Rect.fromLTWH(-r * 1.85, -r * 1.65, r * 3.7, r * 1.95);

    // ── Fill: linear gradient for surface depth ───────────────────────────
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

    // ── Specular highlight (upper surface catching diffuse light) ─────────
    c.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.55),
          radius: 0.65,
          colors: [
            Colors.white.withValues(alpha: alpha * 0.18),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(bounds)
        ..blendMode = BlendMode.srcATop,
    );

    // ── Outline ────────────────────────────────────────────────────────────
    c.drawPath(
      path,
      Paint()
        ..color = dark.withValues(alpha: alpha * 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.032
        ..strokeJoin = StrokeJoin.round,
    );

    // ── Midrib (main vein, petiole end → leaf tip) ─────────────────────────
    c.drawLine(
      Offset(0.0, r * 0.15),
      Offset(0.0, -r * 1.3),
      Paint()
        ..color = dark.withValues(alpha: alpha * 0.62)
        ..strokeWidth = size * 0.042
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // ── Secondary veins: 5 pairs fanning toward lobe edges ────────────────
    final sVeinPaint = Paint()
      ..color = dark.withValues(alpha: alpha * 0.36)
      ..strokeWidth = size * 0.024
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // [tAlongMidrib, sideAngle, lengthFrac]
    // tAlong: 0 = base of midrib, 1 = tip; sideAngle in radians from +x axis
    const veinDefs = <List<double>>[
      [0.20, -0.90, 0.55],
      [0.20,  0.90, 0.55],
      [0.42, -1.05, 0.65],
      [0.42,  1.05, 0.65],
      [0.62, -1.15, 0.60],
      [0.62,  1.15, 0.60],
      [0.78, -1.30, 0.50],
      [0.78,  1.30, 0.50],
      [0.88, -1.55, 0.40],
      [0.88,  1.55, 0.40],
    ];

    // Midrib spans (0, r*0.15) → (0, -r*1.3): total = r*1.45
    for (final vd in veinDefs) {
      final tAlong = vd[0];
      final vAngle = vd[1];
      final vLen   = vd[2];
      final midY   = r * 0.15 - tAlong * r * 1.45;
      c.drawLine(
        Offset(0.0, midY),
        Offset(
          math.cos(vAngle - math.pi / 2) * r * vLen,
          midY + math.sin(vAngle - math.pi / 2) * r * vLen,
        ),
        sVeinPaint,
      );
    }

    // ── Petiole (leaf stalk below attachment) ──────────────────────────────
    c.drawLine(
      Offset(0.0, r * 0.20),
      Offset(0.0, r * 0.55),
      Paint()
        ..color = dark.withValues(alpha: alpha * 0.50)
        ..strokeWidth = size * 0.028
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    c.restore();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // _drawGrapeCluster
  // ────────────────────────────────────────────────────────────────────────────

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

    c.save();
    c.translate(wireAttach.dx, wireAttach.dy);
    c.rotate(sway);
    c.translate(-wireAttach.dx, -wireAttach.dy);

    // Peduncle: main stem from wire to bunch top
    final stemLen = 20.0 * fit;
    final stemEnd = Offset(wireAttach.dx, wireAttach.dy + stemLen);

    barkBranch(
      c, wireAttach, stemEnd, 1.8 * fit,
      const Color(0xFF6D4C41), const Color(0xFF3E2723),
    );

    // Sub-rachis branches for detail
    final branchSplit = Offset(stemEnd.dx, stemEnd.dy + 4.0 * fit);
    for (final bSide in [-1.0, 1.0]) {
      barkBranch(
        c,
        branchSplit,
        Offset(branchSplit.dx + bSide * 7.5 * fit, branchSplit.dy + 11.0 * fit),
        1.1 * fit,
        const Color(0xFF795548), const Color(0xFF3E2723),
      );
    }

    // Berry colour ramp: green (unripe) → deep purple (ripe)
    final baseColor   = Color.lerp(const Color(0xFF8BC34A), const Color(0xFF7B1FA2), ripeness)!;
    final shadowColor = Color.lerp(const Color(0xFF558B2F), const Color(0xFF4A148C), ripeness)!;
    final hiColor     = Color.lerp(const Color(0xFFDCEDC8), const Color(0xFFE1BEE7), ripeness)!;

    // Conical bunch: wide at top (attached to wire), narrow at bottom — natural grape shape
    const rowCounts   = <int>[4, 5, 5, 4, 3, 2, 1];
    const rowYOffsets = <double>[0.0, 9.0, 18.0, 27.0, 36.0, 44.0, 51.0];
    final grapeR   = 5.5 * fit;
    final spacingX = 11.5 * fit;

    for (int ri = 0; ri < rowCounts.length; ri++) {
      final count    = rowCounts[ri];
      final yOff     = rowYOffsets[ri] * fit;
      final rowWidth = (count - 1) * spacingX;
      final startX   = stemEnd.dx - rowWidth / 2.0;

      for (int gi = 0; gi < count; gi++) {
        final gCenter = Offset(
          startX + gi * spacingX + (rng.nextDouble() - 0.5) * 1.5 * fit,
          stemEnd.dy + yOff      + (rng.nextDouble() - 0.5) * 1.5 * fit,
        );

        // Per-berry tonal variation for organic realism
        final tone = (rng.nextDouble() - 0.5) * 0.15;
        final berryBase = Color.lerp(baseColor, shadowColor, tone.abs())!;

        glossyFruit(
          c, gCenter, grapeR,
          berryBase.withValues(alpha: alpha),
          shadowColor.withValues(alpha: alpha),
          hiColor.withValues(alpha: alpha),
        );

        // Pedicel visible on top three rows
        if (ri < 3) {
          c.drawLine(
            Offset(gCenter.dx, gCenter.dy - grapeR - 4.0 * fit),
            gCenter,
            Paint()
              ..color = const Color(0xFF795548).withValues(alpha: alpha * 0.55)
              ..strokeWidth = 0.7 * fit
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }

    // Tendril at cluster tip
    _drawTendril(
      c,
      Offset(stemEnd.dx, stemEnd.dy + rowYOffsets.last * fit + grapeR + 2.0 * fit),
      fit, rng, alpha * 0.85,
    );

    c.restore();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // _drawTendril: curling spiral vine tendril
  // ────────────────────────────────────────────────────────────────────────────

  void _drawTendril(
    Canvas c,
    Offset base,
    double fit,
    math.Random rng,
    double alpha,
  ) {
    if (alpha <= 0.01) return;

    final tendrPaint = Paint()
      ..color = const Color(0xFF5D4037).withValues(alpha: alpha * 0.68)
      ..strokeWidth = 0.85 * fit
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final sign = rng.nextBool() ? 1.0 : -1.0;
    final path = Path()..moveTo(base.dx, base.dy);

    for (int i = 1; i <= 16; i++) {
      final t = i / 16.0;
      final spiralR     = 7.0 * fit * (1.0 - t * 0.55);
      final spiralAngle = sign * t * math.pi * 2.8 + math.pi / 2;
      path.lineTo(
        base.dx + math.cos(spiralAngle) * spiralR * t,
        base.dy + math.sin(spiralAngle) * spiralR * t + 5.0 * fit * t,
      );
    }
    c.drawPath(path, tendrPaint);
  }
}
