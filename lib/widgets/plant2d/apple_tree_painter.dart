import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AppleTreePainter — botanical illustration style
//  Stages:
//    g < 0.06          : seed
//    0.06 – 0.20       : sprout (thin stem + cotyledons)
//    0.20 – 0.40       : young tree (trunk + 2 branches + botanical leaves)
//    0.40 – 0.65       : growing (more branches + leaf clusters)
//    0.65 – 1.00       : mature (foliageBlob canopy + blossoms or apples)
// ─────────────────────────────────────────────────────────────────────────────

class AppleTreePainter extends CustomPainter {
  final double g;          // 0.0–1.0 growth
  final double windPhase;  // 0.0–1.0 animation phase
  final double windAmp;    // amplitude multiplier ~4.0
  final double wiltFactor; // 0.0–1.0
  final int seed;
  final int month;         // 1–12 for seasonal appearance

  AppleTreePainter({
    required this.g,
    required this.windPhase,
    required this.windAmp,
    required this.wiltFactor,
    required this.seed,
    required this.month,
  });

  @override
  bool shouldRepaint(AppleTreePainter o) =>
      o.g != g || o.windPhase != windPhase || o.wiltFactor != wiltFactor;

  // ── Season helpers ──────────────────────────────────────────────────────────

  bool get _isSpring => month >= 3 && month <= 5;
  bool get _isFall   => month == 10 || month == 11;

  List<Color> get _foliageShades {
    if (_isSpring) {
      return const [Color(0xFF81C784), Color(0xFF66BB6A), Color(0xFF43A047)];
    }
    if (_isFall) {
      return const [Color(0xFFE65100), Color(0xFFF57F17), Color(0xFFBF360C)];
    }
    return const [Color(0xFF2E7D32), Color(0xFF388E3C), Color(0xFF4CAF50)];
  }

  // ── Branch definitions [angleRad, trunkPosFrac, lengthFrac] ────────────────
  //   angle is measured from straight-up (–π/2 on the canvas)
  static const List<List<double>> _branchDefs = [
    [-0.58, 0.58, 0.80],  // lower left
    [ 0.54, 0.62, 0.76],  // lower right
    [-0.38, 0.74, 0.62],  // mid left
    [ 0.42, 0.78, 0.58],  // mid right
    [ 0.05, 0.90, 0.44],  // near-top centre
  ];

  // ── Main paint ──────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final fit     = size.height / 580;
    final cx      = size.width / 2;
    final groundY = size.height - 65 * fit;
    final ground  = Offset(cx, groundY);
    final rng     = math.Random(seed);

    // ── Stage 0: seed ─────────────────────────────────────────────────────────
    if (g < 0.06) {
      drawSeed(canvas, ground, fit, sstep(0, 0.06, g));
      realisticPot(canvas, ground, fit);
      drawWiltOverlay(canvas, size, wiltFactor);
      return;
    }

    // ── Trunk geometry ────────────────────────────────────────────────────────
    // Full trunk height: 20 px (sprout) → 190 px (mature), scaled by fit.
    final trunkH = lp(20, 190, sstep(0.06, 0.90, g)) * fit;
    final trunkTopY = groundY - trunkH;

    _drawTrunk(canvas, cx, groundY, trunkH, fit, rng);

    // ── Stage 1: sprout ────────────────────────────────────────────────────────
    if (g < 0.20) {
      _drawCotyledons(canvas, cx, trunkTopY, fit, g);
      realisticPot(canvas, ground, fit);
      drawWiltOverlay(canvas, size, wiltFactor);
      return;
    }

    // ── Branches ───────────────────────────────────────────────────────────────
    final maxBranchLen = lp(0, 92, sstep(0.20, 0.85, g)) * fit;
    final branchCount  = ((g - 0.20) / 0.60 * _branchDefs.length)
        .clamp(0.0, _branchDefs.length.toDouble())
        .floor();

    // Collect canopy anchor points (branch tips + trunk top).
    final canopyAnchors = <Offset>[Offset(cx, trunkTopY)];

    for (int bi = 0; bi < branchCount; bi++) {
      final bd      = _branchDefs[bi];
      final angle   = bd[0];
      final posFrac = bd[1];
      final lenFrac = bd[2];

      final bLen  = maxBranchLen * lenFrac;
      final bBase = Offset(cx, groundY - trunkH * posFrac);

      // Canvas angle: straight-up = –π/2; offset by branch angle.
      final canvasAngle = -math.pi / 2 + angle;

      final localTip = Offset(
        math.cos(canvasAngle) * bLen,
        math.sin(canvasAngle) * bLen,
      );
      final worldTip = bBase + localTip;
      canopyAnchors.add(worldTip);

      // Wind sway pivots around the branch base.
      final sway = windSway(windPhase + bi * 0.13, posFrac, windAmp);
      canvas.save();
      canvas.translate(bBase.dx, bBase.dy);
      canvas.rotate(sway);

      // Thickness tapers: lower branches are fatter (8 px), upper are thinner (5 px).
      final bThickBase = lp(8, 5, bi / _branchDefs.length) * fit;

      // Primary branch.
      barkBranch(
        canvas,
        Offset.zero,
        localTip,
        bThickBase,
        const Color(0xFF7A5C3A),
        const Color(0xFF4A3020),
        lenticels: bi < 2,
        rng: rng,
      );

      // Botanical leaves along the branch (young / growing stage).
      if (g >= 0.20 && g < 0.65) {
        _drawBranchLeaves(canvas, localTip, bLen, fit, g, rng, angle < 0 ? -1 : 1);
      }

      canvas.restore();

      // Sub-branch (for the two lower main branches once growing).
      if (bi < 2 && g > 0.42) {
        _drawSubBranch(canvas, bBase, worldTip, angle, maxBranchLen, fit, rng, bi);
      }
    }

    // ── Foliage canopy (g > 0.48) ─────────────────────────────────────────────
    if (g > 0.48) {
      _drawCanopy(canvas, cx, trunkTopY, canopyAnchors, fit, g, rng);
    }

    // ── Blossoms / apples (mature) ────────────────────────────────────────────
    if (g >= 0.65) {
      _drawFruitOrBlossom(canvas, cx, trunkTopY, canopyAnchors, fit, g, rng);
    }

    realisticPot(canvas, ground, fit);
    drawWiltOverlay(canvas, size, wiltFactor);
  }

  // ── Trunk: single smooth tapered bezier path ────────────────────────────────

  void _drawTrunk(Canvas canvas, double cx, double groundY, double trunkH,
      double fit, math.Random rng) {
    if (trunkH < 2.0) return;

    // Gentle S-curve lean based on seed
    final wobble = math.sin(seed * 0.31) * 5.0 * fit;
    final topX = cx + wobble;
    final topY = groundY - trunkH;
    final midX = cx + wobble * 0.45;
    final midY = groundY - trunkH * 0.52;

    final halfBase = 9.5 * fit;
    final halfMid  = 6.5 * fit;
    final halfTop  = 4.0 * fit;

    // Single smooth tapered bezier trunk path
    final trunkPath = Path()..moveTo(cx - halfBase, groundY);
    trunkPath.quadraticBezierTo(midX - halfMid, midY, topX - halfTop, topY);
    trunkPath.lineTo(topX + halfTop, topY);
    trunkPath.quadraticBezierTo(midX + halfMid, midY, cx + halfBase, groundY);
    trunkPath.close();

    // Lateral gradient: dark left → lighter centre → dark right
    final rect = Rect.fromLTRB(cx - halfBase - 2, topY - 2,
                                cx + halfBase + 2, groundY);
    canvas.drawPath(
      trunkPath,
      Paint()
        ..shader = LinearGradient(
          colors: const [
            Color(0xFF3A2010),
            Color(0xFF8A6040),
            Color(0xFF5A3A20),
            Color(0xFF3A2010),
          ],
          stops: const [0.0, 0.30, 0.68, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(rect),
    );

    // Subtle vertical gloss
    canvas.drawPath(
      trunkPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          begin: const Alignment(-0.5, -1.0),
          end: const Alignment(0.3, 1.0),
        ).createShader(rect),
    );

    // Horizontal lenticel marks (no visible segment breaks)
    final lRng = math.Random(seed ^ 0x2F9A);
    final lenticPaint = Paint()
      ..color = const Color(0xFF2A1408).withValues(alpha: 0.28)
      ..strokeWidth = 0.7 * fit
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int li = 0; li < 8; li++) {
      final lFrac = (li + 0.5) / 8.0;
      final lY = groundY - lFrac * trunkH;
      final lWide = halfBase * lp(1.0, 0.42, lFrac) *
          (0.35 + lRng.nextDouble() * 0.30);
      final lX = cx + (lRng.nextDouble() - 0.5) * 3.0 * fit;
      canvas.drawLine(Offset(lX - lWide, lY), Offset(lX + lWide, lY),
          lenticPaint);
    }
  }

  // ── Cotyledon leaves for the sprout stage ────────────────────────────────────

  void _drawCotyledons(Canvas canvas, double cx, double trunkTopY, double fit,
      double g) {
    final alpha = sstep(0.08, 0.20, g);
    if (alpha <= 0) return;

    // Two heart-shaped (oval) cotyledons, one each side.
    final size = lp(6, 14, alpha) * fit;
    final leafColors = [const Color(0xFF81C784), const Color(0xFF43A047)];

    for (final side in [-1.0, 1.0]) {
      final base = Offset(cx, trunkTopY + 2 * fit);
      final tip  = Offset(cx + side * size * 1.6, trunkTopY - size * 1.8);

      // Fade in with alpha via saveLayer.
      canvas.saveLayer(
        Rect.fromLTWH(tip.dx - size * 2, tip.dy - size * 2,
            size * 4, size * 4),
        Paint()..color = Color.fromARGB((alpha * 255).round(), 255, 255, 255),
      );
      botanicalLeaf(
        canvas, base, tip, size * 0.9,
        leafColors[0], leafColors[1],
        vein: true,
        veinColor: const Color(0xFF2E7D32).withValues(alpha: 0.5),
      );
      canvas.restore();
    }
  }

  // ── Botanical leaves distributed along a branch ──────────────────────────────

  void _drawBranchLeaves(Canvas canvas, Offset localTip, double bLen, double fit,
      double g, math.Random rng, int side) {
    final leafAlpha = sstep(0.22, 0.45, g);
    if (leafAlpha <= 0.05) return;

    final leafCount = (leafAlpha * 5 + 1).floor().clamp(1, 5);
    for (int li = 0; li < leafCount; li++) {
      final t         = (li + 1) / (leafCount + 1);
      final baseLocal = localTip * t;
      final leafAngle = -math.pi / 2 + side * (0.6 + li * 0.25);
      final leafLen   = lp(10, 18, leafAlpha) * fit;
      final tipLocal  = Offset(
        baseLocal.dx + math.cos(leafAngle) * leafLen,
        baseLocal.dy + math.sin(leafAngle) * leafLen,
      );

      canvas.saveLayer(
        Rect.fromLTWH(baseLocal.dx - leafLen, baseLocal.dy - leafLen,
            leafLen * 2.5, leafLen * 2.5),
        Paint()..color = Color.fromARGB((leafAlpha * 255).round(), 255, 255, 255),
      );
      botanicalLeaf(
        canvas,
        baseLocal,
        tipLocal,
        leafLen * 0.38,
        const Color(0xFF81C784),
        const Color(0xFF2E7D32),
        vein: true,
      );
      canvas.restore();
    }
  }

  // ── Sub-branch off a primary branch ─────────────────────────────────────────

  void _drawSubBranch(Canvas canvas, Offset bBase, Offset worldTip,
      double primaryAngle, double maxBranchLen, double fit,
      math.Random rng, int bi) {
    final subFrac  = 0.55 + bi * 0.05;
    final pivot    = Offset(
      lp(bBase.dx, worldTip.dx, subFrac),
      lp(bBase.dy, worldTip.dy, subFrac),
    );
    // Sub-branch veers the opposite horizontal direction.
    final subSide  = (primaryAngle < 0) ? 1 : -1;
    final subAngle = -math.pi / 2 + subSide * 0.30;
    final subLen   = maxBranchLen * 0.38;
    final subTip   = Offset(
      pivot.dx + math.cos(subAngle) * subLen,
      pivot.dy + math.sin(subAngle) * subLen,
    );
    final thick = 3.5 * fit;

    final sway = windSway(windPhase + bi * 0.2, subFrac, windAmp * 1.2);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(sway);
    barkBranch(
      canvas,
      Offset.zero,
      subTip - pivot,
      thick,
      const Color(0xFF7A5C3A),
      const Color(0xFF4A3020),
    );
    canvas.restore();
  }

  // ── Foliage canopy using foliageBlob ────────────────────────────────────────

  void _drawCanopy(Canvas canvas, double cx, double trunkTopY,
      List<Offset> anchors, double fit, double g, math.Random rng) {
    final shades     = _foliageShades;
    final leafAlpha  = sstep(0.48, 0.68, g);

    // Compute canopy centroid from branch tip anchors.
    double sx = 0, sy = 0;
    for (final a in anchors) { sx += a.dx; sy += a.dy; }
    final centroid = Offset(sx / anchors.length, sy / anchors.length - 12 * fit);

    // Canopy radius grows with g.
    final canopyR = lp(28, 98, sstep(0.48, 0.92, g)) * fit;

    // 5–8 overlapping foliage blobs arranged in a round crown.
    final blobCount = lp(5, 8, sstep(0.48, 0.90, g)).round();
    final windLean  = windSway(windPhase, 1.0, windAmp) * 18;

    canvas.saveLayer(
      Rect.fromLTWH(
          centroid.dx - canopyR - 20, centroid.dy - canopyR - 20,
          (canopyR + 20) * 2, (canopyR + 20) * 2),
      Paint()..color = Color.fromARGB((leafAlpha * 255).round(), 255, 255, 255),
    );

    for (int bi = 0; bi < blobCount; bi++) {
      // Spread blobs in an elliptical crown (wider than tall).
      final angle  = bi * math.pi * 2 / blobCount +
          rng.nextDouble() * 0.45 +
          // Slight rotation per rng seed for variety.
          seed * 0.07;
      final dist   = canopyR * (0.18 + rng.nextDouble() * 0.38);
      final blobR  = canopyR * (0.38 + rng.nextDouble() * 0.28);
      final center = Offset(
        centroid.dx + math.cos(angle) * dist,
        centroid.dy + math.sin(angle) * dist * 0.72,
      );

      foliageBlob(canvas, center, blobR, shades, rng, windLean);
    }

    canvas.restore();
  }

  // ── Blossoms (spring) or glossy apples (other seasons) ──────────────────────

  void _drawFruitOrBlossom(Canvas canvas, double cx, double trunkTopY,
      List<Offset> anchors, double fit, double g, math.Random rng) {
    // Canopy geometry (mirrors _drawCanopy for placement).
    double sx = 0, sy = 0;
    for (final a in anchors) { sx += a.dx; sy += a.dy; }
    final centroid = Offset(sx / anchors.length, sy / anchors.length - 12 * fit);
    final canopyR  = lp(28, 98, sstep(0.48, 0.92, g)) * fit;

    if (_isSpring && g > 0.72) {
      _drawBlossoms(canvas, centroid, canopyR, fit, g, rng);
    } else if (!_isSpring && g > 0.78) {
      _drawApples(canvas, centroid, canopyR, fit, g, rng);
    }
  }

  // ── Apple blossoms: clusters of 3–5 flowers ──────────────────────────────────

  void _drawBlossoms(Canvas canvas, Offset centroid, double canopyR,
      double fit, double g, math.Random rng) {
    final blossomAlpha = sstep(0.72, 0.88, g);
    final flowerCount  = lp(6, 22, blossomAlpha).round();

    for (int i = 0; i < flowerCount; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final dist  = rng.nextDouble() * canopyR * 0.80;
      final fc    = Offset(
        centroid.dx + math.cos(angle) * dist,
        centroid.dy + math.sin(angle) * dist * 0.72,
      );
      _drawSingleBlossom(canvas, fc, lp(4, 8, blossomAlpha) * fit, rng);
    }
  }

  void _drawSingleBlossom(Canvas canvas, Offset center, double r,
      math.Random rng) {
    // 5 petals via petal() utility; white to soft pink.
    for (int pi = 0; pi < 5; pi++) {
      final angle = pi * math.pi * 2 / 5 - math.pi / 2 +
          rng.nextDouble() * 0.18;
      petal(
        canvas,
        center,
        r * 1.9,
        r * 0.90,
        angle,
        const Color(0xFFFFF8FB),
        const Color(0xFFFFCDD2),
      );
    }
    // Stamen: yellow dot.
    canvas.drawCircle(
      center,
      r * 0.32,
      Paint()..color = const Color(0xFFFFD600),
    );
    // Tiny style filaments.
    final stamenPaint = Paint()
      ..color = const Color(0xFFFFD600).withValues(alpha: 0.75)
      ..strokeWidth = 0.7 * (r / 6).clamp(0.5, 1.2)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int si = 0; si < 5; si++) {
      final sa = si * math.pi * 2 / 5;
      canvas.drawLine(
        center,
        Offset(center.dx + math.cos(sa) * r * 0.55,
               center.dy + math.sin(sa) * r * 0.55),
        stamenPaint,
      );
    }
  }

  // ── Glossy red apples ────────────────────────────────────────────────────────

  void _drawApples(Canvas canvas, Offset centroid, double canopyR,
      double fit, double g, math.Random rng) {
    final appleAlpha = sstep(0.78, 0.94, g);
    final appleCount = lp(4, 7, appleAlpha).round();
    final appleR     = lp(4, 14, (g - 0.78) / 0.22) * fit;

    canvas.saveLayer(
      Rect.fromLTWH(
          centroid.dx - canopyR - appleR * 2,
          centroid.dy - canopyR - appleR * 2,
          (canopyR + appleR * 2) * 2,
          (canopyR + appleR * 2) * 2),
      Paint()..color = Color.fromARGB((appleAlpha * 255).round(), 255, 255, 255),
    );

    for (int i = 0; i < appleCount; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final dist  = rng.nextDouble() * canopyR * 0.68;
      final ac    = Offset(
        centroid.dx + math.cos(angle) * dist,
        centroid.dy + math.sin(angle) * dist * 0.72,
      );

      // Small stem above the apple.
      canvas.drawLine(
        Offset(ac.dx, ac.dy - appleR * 0.95),
        Offset(ac.dx + appleR * 0.35, ac.dy - appleR * 1.55),
        Paint()
          ..color = const Color(0xFF4A3020)
          ..strokeWidth = (appleR * 0.18).clamp(0.8, 2.5)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

      // Tiny leaf bract next to stem.
      if (appleR > 7 * fit) {
        botanicalLeaf(
          canvas,
          Offset(ac.dx, ac.dy - appleR),
          Offset(ac.dx + appleR * 0.9, ac.dy - appleR * 1.6),
          appleR * 0.28,
          const Color(0xFF66BB6A),
          const Color(0xFF2E7D32),
          vein: false,
        );
      }

      glossyFruit(
        canvas,
        ac,
        appleR,
        const Color(0xFFCC2200),
        const Color(0xFF8B0000),
        const Color(0xFFFF6B6B),
      );

      // Subtle apple-bottom dimple line.
      final dimplePaint = Paint()
        ..color = const Color(0xFF8B0000).withValues(alpha: 0.35)
        ..strokeWidth = (appleR * 0.13).clamp(0.5, 1.5)
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromCenter(center: ac, width: appleR * 1.1, height: appleR * 0.5),
        0.2,
        math.pi - 0.4,
        false,
        dimplePaint,
      );
    }

    canvas.restore();
  }
}
