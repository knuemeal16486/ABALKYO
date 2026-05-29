import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GrapevinePainter — free-standing bushy grapevine tree
//
// Growth stages:
//   g < 0.08           seed + pot
//   0.08 – 0.25        short gnarled trunk grows
//   0.15 – 0.68        4-5 primary branches fan out wide
//   0.25 – 0.82        dense round leaf crown fills in
//   0.55 – 1.00        grape clusters hang within the leaf mass, ripening
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
    final totalH = lp(20, 275, sstep(0.08, 0.92, g)) * fit;
    final trunkH = totalH * 0.28;
    final trunkTopY = groundY - trunkH;
    final crownR = lp(0, 138, sstep(0.20, 0.92, g)) * fit;
    final crownCY = trunkTopY - crownR * 0.62;

    // ── Primary branches (drawn BEHIND crown) ─────────────────────────────────
    if (g > 0.15) {
      _drawPrimaryBranches(canvas, cx, trunkTopY, crownR, crownCY, fit, g, rng);
    }

    // ── Trunk (on top of branch bases) ────────────────────────────────────────
    _drawTrunk(canvas, cx, groundY, trunkH, fit, rng);

    // ── Leaf crown ────────────────────────────────────────────────────────────
    if (g > 0.25) {
      _drawLeafCrown(canvas, cx, crownCY, crownR, fit, g, rng);
    }

    // ── Grape clusters ────────────────────────────────────────────────────────
    if (g > 0.55) {
      _drawGrapeClusters(canvas, cx, crownCY, crownR, fit, g, rng);
    }

    // ── Pot ────────────────────────────────────────────────────────────────────
    realisticPot(canvas, ground, fit);
    drawWiltOverlay(canvas, size, wiltFactor);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // _drawTrunk: short thick gnarled trunk with bark texture
  // ────────────────────────────────────────────────────────────────────────────

  void _drawTrunk(
    Canvas canvas,
    double cx,
    double groundY,
    double trunkH,
    double fit,
    math.Random rng,
  ) {
    if (trunkH < 2.0) return;

    // Gentle S-curve wobble based on seed
    final wobble = math.sin(seed * 0.31) * 4.0 * fit;
    final topX = cx + wobble;
    final topY = groundY - trunkH;
    final midX = cx + wobble * 0.45;
    final midY = groundY - trunkH * 0.52;

    final halfBase = 11.0 * fit;
    final halfMid = 8.0 * fit;
    final halfTop = 6.5 * fit;

    // Single smooth tapered bezier trunk path
    final trunkPath = Path()..moveTo(cx - halfBase, groundY);
    trunkPath.quadraticBezierTo(midX - halfMid, midY, topX - halfTop, topY);
    trunkPath.lineTo(topX + halfTop, topY);
    trunkPath.quadraticBezierTo(midX + halfMid, midY, cx + halfBase, groundY);
    trunkPath.close();

    // 4-stop lateral LinearGradient
    final rect = Rect.fromLTRB(
      cx - halfBase - 2,
      topY - 2,
      cx + halfBase + 2,
      groundY,
    );
    canvas.drawPath(
      trunkPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF1E0D04),
            Color(0xFF5A3A18),
            Color(0xFF3A2208),
            Color(0xFF1E0D04),
          ],
          stops: [0.0, 0.30, 0.68, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(rect),
    );

    // Horizontal bark texture lines (7 lines)
    final lRng = math.Random(seed ^ 0x5C7A);
    final lenticPaint = Paint()
      ..color = const Color(0xFF0D0602).withValues(alpha: 0.32)
      ..strokeWidth = 0.8 * fit
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int li = 0; li < 7; li++) {
      final lFrac = (li + 0.5) / 7.0;
      final lY = groundY - lFrac * trunkH;
      final lWide = halfBase * lp(1.0, 0.55, lFrac) * (0.35 + lRng.nextDouble() * 0.32);
      final lX = cx + wobble * lFrac + (lRng.nextDouble() - 0.5) * 3.0 * fit;
      canvas.drawLine(Offset(lX - lWide, lY), Offset(lX + lWide, lY), lenticPaint);
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // _drawPrimaryBranches: 5 wide-spreading branches from trunk top
  // ────────────────────────────────────────────────────────────────────────────

  List<Offset> _drawPrimaryBranches(
    Canvas canvas,
    double cx,
    double trunkTopY,
    double crownR,
    double crownCY,
    double fit,
    double g,
    math.Random rng,
  ) {
    final appear = sstep(0.15, 0.68, g);
    final count = (appear * 5).floor().clamp(0, 5);

    // Angle offsets from straight up (-PI/2)
    const angleOffsets = <double>[-0.82, -0.44, 0.04, 0.44, 0.80];
    final maxLen = crownR * 0.88;
    final tips = <Offset>[];

    final barkLight = const Color(0xFF5D3A1A);
    final barkDark = const Color(0xFF2E1A08);

    for (int bi = 0; bi < count; bi++) {
      final ao = angleOffsets[bi];
      final canvasAngle = -math.pi / 2 + ao;
      final thick = lp(7.0, 4.0, bi / 4.0) * fit;

      // Branch length fades in with appear
      final branchLen = maxLen * appear;
      final tipOffset = Offset(
        math.cos(canvasAngle) * branchLen,
        math.sin(canvasAngle) * branchLen,
      );
      final branchBase = Offset(cx, trunkTopY);
      final branchTip = branchBase + tipOffset;
      tips.add(branchTip);

      // Wind sway
      final sway = windSway(windPhase + bi * 0.17, 0.7, windAmp);
      canvas.save();
      canvas.translate(branchBase.dx, branchBase.dy);
      canvas.rotate(sway);

      barkBranch(
        canvas,
        Offset.zero,
        tipOffset,
        thick,
        barkLight,
        barkDark,
        lenticels: bi < 3 && thick > 3.0,
        rng: rng,
      );

      // Sub-branch at 55% along if g > 0.32
      if (g > 0.32) {
        final subAppear = sstep(0.32, 0.72, g);
        final subBase = tipOffset * 0.55;
        // Sub-branch veers outward
        final subSide = ao < 0 ? -1.0 : 1.0;
        final subAngle = canvasAngle + subSide * 0.52;
        final subLen = branchLen * 0.45 * subAppear;
        final subTip = Offset(
          subBase.dx + math.cos(subAngle) * subLen,
          subBase.dy + math.sin(subAngle) * subLen,
        );
        final subThick = thick * 0.58;
        barkBranch(
          canvas,
          subBase,
          subTip,
          subThick,
          barkLight,
          barkDark,
          lenticels: false,
          rng: rng,
        );
      }

      canvas.restore();
    }

    return tips;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // _drawLeafCrown: dense round canopy of large grape leaves
  // ────────────────────────────────────────────────────────────────────────────

  void _drawLeafCrown(
    Canvas canvas,
    double cx,
    double crownCY,
    double crownR,
    double fit,
    double g,
    math.Random rng,
  ) {
    final appear = sstep(0.25, 0.82, g);
    if (appear <= 0.01) return;

    final foliageShades = const <Color>[
      Color(0xFF43A047),
      Color(0xFF388E3C),
      Color(0xFF2E7D32),
      Color(0xFF1B5E20),
    ];

    final windLean = windSway(windPhase, 1.0, windAmp) * 18;

    // saveLayer for appear alpha
    final layerRect = Rect.fromCenter(
      center: Offset(cx, crownCY),
      width: (crownR + 30) * 2,
      height: (crownR + 30) * 2,
    );
    canvas.saveLayer(
      layerRect,
      Paint()..color = Color.fromARGB((appear * 255).round(), 255, 255, 255),
    );

    // 7-9 foliage blobs scattered in crown area
    final blobCount = 7 + rng.nextInt(3);
    for (int bi = 0; bi < blobCount; bi++) {
      final angle = bi * math.pi * 2 / blobCount +
          rng.nextDouble() * 0.5 +
          seed * 0.07;
      final dist = crownR * (0.12 + rng.nextDouble() * 0.45);
      final blobR = crownR * (0.36 + rng.nextDouble() * 0.28);
      final center = Offset(
        cx + math.cos(angle) * dist,
        crownCY + math.sin(angle) * dist * 0.82,
      );
      foliageBlob(canvas, center, blobR, foliageShades, rng, windLean);
    }

    // 12-18 individual grape leaves scattered in crown area
    final leafCount = 12 + rng.nextInt(7);
    final leafRng = math.Random(seed ^ 0xA3F1);
    for (int li = 0; li < leafCount; li++) {
      final angle = leafRng.nextDouble() * math.pi * 2;
      final dist = crownR * (0.05 + leafRng.nextDouble() * 0.72);
      final attach = Offset(
        cx + math.cos(angle) * dist,
        crownCY + math.sin(angle) * dist * 0.85,
      );
      final leafSz = (18.0 + leafRng.nextDouble() * 18.0) * fit;
      final sway = windSway(windPhase + li * 0.21, dist / crownR, windAmp);
      final leafAngle = angle + math.pi * 0.5 + sway;

      final useAlt = li.isEven;
      _grapeLeaf(
        canvas,
        attach,
        leafSz,
        leafAngle,
        useAlt ? const Color(0xFF66BB6A) : const Color(0xFF558B2F),
        useAlt ? const Color(0xFF2E7D32) : const Color(0xFF1B5E20),
      );
    }

    canvas.restore();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // _drawGrapeClusters: clusters hanging within the leaf mass
  // ────────────────────────────────────────────────────────────────────────────

  void _drawGrapeClusters(
    Canvas canvas,
    double cx,
    double crownCY,
    double crownR,
    double fit,
    double g,
    math.Random rng,
  ) {
    final ripeness = ((g - 0.55) * 2.2).clamp(0.0, 1.0);
    final clusterCount = ((g - 0.55) / 0.45 * 5).clamp(1.0, 5.0).floor();

    final clusterRng = math.Random(seed ^ 0x7F3C);

    for (int ci = 0; ci < clusterCount; ci++) {
      final angle = ci * math.pi * 2 / 5 + clusterRng.nextDouble() * 0.7;
      final dist = crownR * (0.18 + clusterRng.nextDouble() * 0.42);
      final wireAttach = Offset(
        cx + math.cos(angle) * dist,
        crownCY + math.sin(angle) * dist * 0.85,
      );

      final alpha = ci == 0
          ? sstep(0.55, 0.66, g)
          : sstep(0.55 + ci * 0.07, 0.72 + ci * 0.05, g);

      _drawGrapeCluster(
        canvas,
        wireAttach,
        fit,
        ripeness,
        math.Random(seed + 10 + ci),
        windSway(windPhase + ci * 0.27, 0.75, windAmp),
        alpha,
      );
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
