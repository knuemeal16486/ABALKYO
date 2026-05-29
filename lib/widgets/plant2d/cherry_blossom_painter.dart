import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

// ── Falling petal particle data ───────────────────────────────────────────────
class _FallingPetal {
  final double x;   // normalised [0,1] horizontal start
  final double y;   // normalised [0,1] vertical start (increases = falls)
  final double spd; // fall speed (normalised per cycle)
  final double freq;
  final double phase;
  final double amp;
  final double rot;

  const _FallingPetal({
    required this.x,
    required this.y,
    required this.spd,
    required this.freq,
    required this.phase,
    required this.amp,
    required this.rot,
  });
}

class CherryBlossomPainter extends CustomPainter {
  final double g, windPhase, windAmp, wiltFactor;
  final int seed;
  final int month; // 1–12

  CherryBlossomPainter({
    required this.g,
    required this.windPhase,
    required this.windAmp,
    required this.wiltFactor,
    required this.seed,
    required this.month,
  });

  @override
  bool shouldRepaint(CherryBlossomPainter o) =>
      o.g != g ||
      o.windPhase != windPhase ||
      o.windAmp != windAmp ||
      o.wiltFactor != wiltFactor ||
      o.month != month ||
      o.seed != seed;

  // ── Pre-build stable particle list from seed ──────────────────────────────
  List<_FallingPetal> _buildParticles() {
    final rng = math.Random(seed ^ 0xDEADBEEF);
    return List.generate(18, (_) {
      return _FallingPetal(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        spd: 0.18 + rng.nextDouble() * 0.22,
        freq: 0.8 + rng.nextDouble() * 1.4,
        phase: rng.nextDouble() * math.pi * 2,
        amp: 0.04 + rng.nextDouble() * 0.06,
        rot: rng.nextDouble() * math.pi * 2,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fit = size.height / 580;
    final cx = size.width / 2;
    final groundY = size.height - 65 * fit;
    final ground = Offset(cx, groundY);

    // Deterministic rng for branch geometry (consistent across frames)
    final rng = math.Random(seed);

    // ── Season flags ─────────────────────────────────────────────────────────
    final isSpring = month >= 3 && month <= 5;
    final isWinter = month == 12 || month <= 2;
    final isFall = month == 10 || month == 11;

    // ── Stage 1: seed only ───────────────────────────────────────────────────
    if (g < 0.07) {
      drawSeed(canvas, ground, fit, sstep(0.0, 0.07, g));
      realisticPot(canvas, ground, fit);
      drawWiltOverlay(canvas, size, wiltFactor);
      return;
    }

    // ── Trunk geometry ───────────────────────────────────────────────────────
    // Height grows from 0 to 220*fit over g 0.07→1.0
    final trunkH = lp(10, 220, sstep(0.07, 0.95, g)) * fit;
    // Trunk base is at ground, tip leans slightly right (+8 px) for realism
    final trunkBase = Offset(cx, groundY);
    final trunkTip = Offset(cx + 8 * fit, groundY - trunkH);

    // ── Stage 2: trunk ───────────────────────────────────────────────────────
    if (g >= 0.07 && g < 0.35) {
      _drawTrunk(canvas, trunkBase, trunkTip, fit, g, rng);
      realisticPot(canvas, ground, fit);
      drawWiltOverlay(canvas, size, wiltFactor);
      return;
    }

    // ── Stage 3+: trunk + branches (+ crown if g>0.60) ───────────────────────
    _drawTrunk(canvas, trunkBase, trunkTip, fit, g, rng);

    final branchTips = _drawBranches(canvas, trunkBase, trunkTip, trunkH, fit, cx, groundY, g, rng);

    // ── Stage 4: crown ───────────────────────────────────────────────────────
    if (g > 0.55) {
      final crownFrac = sstep(0.55, 0.90, g);

      // Compute crown centroid from branch tips
      if (branchTips.isNotEmpty) {
        double sx = 0, sy = 0;
        for (final t in branchTips) { sx += t.dx; sy += t.dy; }
        final crownCx = sx / branchTips.length;
        final crownCy = sy / branchTips.length - 10 * fit;
        final crownR  = lp(20, 105, crownFrac) * fit;

        if (isSpring) {
          // Dense pink blossom cloud filling the crown
          _drawBlossomCloud(canvas, Offset(crownCx, crownCy), crownR, fit, crownFrac, rng);
        } else if (!isWinter) {
          // Green/autumn leaf cloud
          _drawLeafCloud(canvas, Offset(crownCx, crownCy), crownR, fit, crownFrac, rng, isFall);
        }
      }

      // Additional individual flower clusters on top of the cloud (spring only)
      if (isSpring) {
        for (final tip in branchTips) {
          _drawBlossomCluster(canvas, tip, fit, crownFrac,
              math.Random(seed ^ tip.hashCode), windPhase);
        }
      } else if (!isWinter) {
        for (final tip in branchTips) {
          _drawLeafCluster(canvas, tip, fit, crownFrac,
              math.Random(seed ^ tip.hashCode), isFall);
        }
      }

      // Falling petals
      if (isSpring && g > 0.72) {
        _drawFallingPetals(canvas, size, fit);
      }
    }

    realisticPot(canvas, ground, fit);
    drawWiltOverlay(canvas, size, wiltFactor);
  }

  // ── Trunk: single smooth bezier path ─────────────────────────────────────
  void _drawTrunk(Canvas canvas, Offset base, Offset tip, double fit, double g, math.Random rng) {
    final growFrac = sstep(0.07, 0.35, g);
    if (growFrac <= 0.01) return;

    // Actual tip for current growth stage
    final actualTip = Offset(
      lp(base.dx, tip.dx, growFrac),
      lp(base.dy, tip.dy, growFrac),
    );

    final trunkH = (base.dy - actualTip.dy).abs();
    if (trunkH < 2.0) return;

    final halfBase = 9.0 * fit;
    final halfTop  = 4.0 * fit;
    // Mid control point — slight rightward bow for organic feel
    final midX = lp(base.dx, actualTip.dx, 0.50) + 2.0 * fit;
    final midY = lp(base.dy, actualTip.dy, 0.50);
    final halfMid = lp(halfBase, halfTop, 0.50);

    // Single smooth tapered trunk path
    final trunkPath = Path()..moveTo(base.dx - halfBase, base.dy);
    trunkPath.quadraticBezierTo(midX - halfMid, midY, actualTip.dx - halfTop, actualTip.dy);
    trunkPath.lineTo(actualTip.dx + halfTop, actualTip.dy);
    trunkPath.quadraticBezierTo(midX + halfMid, midY, base.dx + halfBase, base.dy);
    trunkPath.close();

    final rect = Rect.fromLTRB(
      base.dx - halfBase - 2, actualTip.dy - 2,
      base.dx + halfBase + 2, base.dy,
    );

    // Reddish-brown cherry bark with lateral gradient
    canvas.drawPath(
      trunkPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF2A0E04),
            Color(0xFF7A4030),
            Color(0xFF5A2818),
            Color(0xFF2A0E04),
          ],
          stops: [0.0, 0.28, 0.68, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(rect),
    );

    // Subtle gloss
    canvas.drawPath(
      trunkPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          begin: const Alignment(-0.4, -1.0),
          end: const Alignment(0.3, 1.0),
        ).createShader(rect),
    );

    // Cherry bark: horizontal lenticel bands (characteristic feature)
    final lRng = math.Random(rng.nextInt(0x7FFFFFFF));
    final lenticPaint = Paint()
      ..color = const Color(0xFF8D6B60).withValues(alpha: 0.55)
      ..strokeWidth = 1.0 * fit
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final lenticCount = (trunkH / (22.0 * fit)).floor().clamp(2, 8);
    for (int li = 0; li < lenticCount; li++) {
      final lFrac = (li + 0.5) / lenticCount;
      final lY = base.dy - lFrac * trunkH;
      final lW = halfBase * lp(1.0, 0.44, lFrac) * (0.45 + lRng.nextDouble() * 0.30);
      final lX = lp(base.dx, actualTip.dx, lFrac) + (lRng.nextDouble() - 0.5) * 3.0 * fit;
      canvas.drawLine(Offset(lX - lW, lY), Offset(lX + lW, lY), lenticPaint);
    }
  }

  // ── Branches: 7 primary, each with a secondary ─────────────────────────────
  // Returns a flat list of all branch tips (primary + secondary endpoints).
  List<Offset> _drawBranches(
    Canvas canvas,
    Offset trunkBase,
    Offset trunkTip,
    double trunkH,
    double fit,
    double cx,
    double groundY,
    double g,
    math.Random rng,
  ) {
    const Color barkLight = Color(0xFF6B3A2A);
    const Color barkDark = Color(0xFF3D1F0A);

    // Each entry: [side(-1/+1), trunkHeightFrac, primaryAngleOff, primaryLenScale]
    // 7 branches at heights 52%–93% of trunk
    final branchDefs = <List<double>>[
      [-1.0, 0.52, 0.95, 1.00],
      [ 1.0, 0.58, 0.88, 0.95],
      [-1.0, 0.67, 0.80, 0.88],
      [ 1.0, 0.73, 0.74, 0.82],
      [-1.0, 0.81, 0.64, 0.72],
      [ 1.0, 0.87, 0.55, 0.65],
      [ 0.0, 0.93, 0.12, 0.55], // near-vertical top branch
    ];

    // Branches start appearing at g=0.35, fully out by g=0.85
    final branchGrow = sstep(0.35, 0.85, g);
    final activeBranches = (branchGrow * branchDefs.length).floor().clamp(0, branchDefs.length);
    // Max primary branch length: up to 110*fit
    final maxLen = lp(0, 110, branchGrow) * fit;

    final tips = <Offset>[];

    for (int bi = 0; bi < activeBranches; bi++) {
      final def = branchDefs[bi];
      final side = def[0];
      final hFrac = def[1];
      final aOff = def[2];
      final lScale = def[3];

      // Attachment point on trunk
      final attach = Offset(
        lp(trunkBase.dx, trunkTip.dx, hFrac),
        lp(trunkBase.dy, trunkTip.dy, hFrac),
      );

      // Primary branch angle: side decides left/right from vertical
      final primaryAngle = -math.pi / 2 + side * lp(0.40, aOff, 1.0);
      final primaryLen = maxLen * lScale;

      // Wind sway applied as a canvas rotation around the attach point
      final sway = windSway(windPhase + bi * 0.13, hFrac, windAmp);

      final primaryTip = Offset(
        attach.dx + math.cos(primaryAngle + sway) * primaryLen,
        attach.dy + math.sin(primaryAngle + sway) * primaryLen,
      );

      // Primary branch: 8→4*fit thick
      barkBranch(
        canvas,
        attach,
        primaryTip,
        lp(8, 4, bi / (branchDefs.length - 1)) * fit,
        barkLight,
        barkDark,
        lenticels: true,
        rng: rng,
      );

      tips.add(primaryTip);

      // Secondary branch: spawns at 60% along the primary
      if (g > 0.50) {
        final secBase = Offset(
          lp(attach.dx, primaryTip.dx, 0.60),
          lp(attach.dy, primaryTip.dy, 0.60),
        );
        // Secondary splays outward from the primary, ±0.35 rad
        final secSide = (bi % 2 == 0) ? -1.0 : 1.0;
        final secAngle = primaryAngle + sway + secSide * 0.35;
        final secLen = primaryLen * 0.52;
        final secTip = Offset(
          secBase.dx + math.cos(secAngle) * secLen,
          secBase.dy + math.sin(secAngle) * secLen,
        );

        barkBranch(
          canvas,
          secBase,
          secTip,
          lp(4, 2, bi / (branchDefs.length - 1)) * fit,
          barkLight,
          barkDark,
          lenticels: true,
          rng: rng,
        );

        tips.add(secTip);
      }
    }

    return tips;
  }

  // ── Blossom cluster (spring) ───────────────────────────────────────────────
  void _drawBlossomCluster(
    Canvas canvas,
    Offset center,
    double fit,
    double bloomFrac,
    math.Random rng,
    double windPhase,
  ) {
    final clusterR = lp(6, 20, bloomFrac) * fit;
    // 3–6 flowers per cluster
    final flowerCount = (3 + (bloomFrac * 3).floor()).clamp(3, 6);

    for (int fi = 0; fi < flowerCount; fi++) {
      // Scatter position within cluster radius
      final scatterAngle = fi * math.pi * 2 / flowerCount + rng.nextDouble() * 0.6;
      final scatterDist = rng.nextDouble() * clusterR;
      final flowerCenter = Offset(
        center.dx + math.cos(scatterAngle) * scatterDist,
        center.dy + math.sin(scatterAngle) * scatterDist * 0.80,
      );

      // Per-flower wind sway
      final sway = windSway(windPhase + fi * 0.17, 0.8, windAmp);

      canvas.save();
      canvas.translate(flowerCenter.dx, flowerCenter.dy);
      canvas.rotate(sway);

      _drawCherryFlower(canvas, Offset.zero, fit, rng);

      canvas.restore();
    }
  }

  // ── Single cherry blossom: 5 petals via petal() + stamen dot ─────────────
  void _drawCherryFlower(Canvas canvas, Offset center, double fit, math.Random rng) {
    const petalLen = 9.0;
    const petalWidth = 8.5;
    const Color lightPink = Color(0xFFFFF0F5);
    const Color deepPink = Color(0xFFFFB7C5);

    // 5 petals at 0, 72, 144, 216, 288 degrees (converted to radians)
    for (int i = 0; i < 5; i++) {
      final angleDeg = i * 72.0;
      final angleRad = angleDeg * math.pi / 180.0;

      // Attach point sits slightly off center so petals radiate naturally
      final attachDist = petalWidth * 0.35 * fit;
      final attach = Offset(
        center.dx + math.cos(angleRad) * attachDist,
        center.dy + math.sin(angleRad) * attachDist,
      );

      petal(
        canvas,
        attach,
        petalLen * fit,
        petalWidth * fit,
        angleRad, // petal points outward from attach
        lightPink,
        deepPink,
      );
    }

    // Yellow-gold stamen dot at center
    canvas.drawCircle(
      center,
      2.5 * fit,
      Paint()..color = const Color(0xFFFFD700),
    );
    // Tiny white highlight on stamen
    canvas.drawCircle(
      Offset(center.dx - 0.6 * fit, center.dy - 0.6 * fit),
      0.9 * fit,
      Paint()..color = Colors.white.withValues(alpha: 0.70),
    );
  }

  // ── Leaf cluster (non-spring, non-winter) ─────────────────────────────────
  void _drawLeafCluster(
    Canvas canvas,
    Offset center,
    double fit,
    double growFrac,
    math.Random rng,
    bool isFall,
  ) {
    // Summer vs autumn colours
    final Color leafLight = isFall ? const Color(0xFFFFB300) : const Color(0xFF81C784);
    final Color leafDark = isFall ? const Color(0xFFE65100) : const Color(0xFF2E7D32);

    final clusterR = lp(10, 28, growFrac) * fit;
    // 2–4 leaves per cluster
    final leafCount = (2 + (growFrac * 2).floor()).clamp(2, 4);

    for (int li = 0; li < leafCount; li++) {
      final angle = li * math.pi * 2 / leafCount + rng.nextDouble() * 0.4;
      final leafBase = Offset(
        center.dx + math.cos(angle) * clusterR * 0.30,
        center.dy + math.sin(angle) * clusterR * 0.30,
      );
      final leafTip = Offset(
        center.dx + math.cos(angle) * clusterR,
        center.dy + math.sin(angle) * clusterR * 0.78,
      );
      final maxW = clusterR * (0.32 + rng.nextDouble() * 0.12);

      botanicalLeaf(
        canvas,
        leafBase,
        leafTip,
        maxW,
        leafLight,
        leafDark,
        vein: true,
        veinColor: leafDark.withValues(alpha: 0.50),
      );
    }
  }

  // ── Dense pink blossom cloud (spring crown fill) ──────────────────────────
  void _drawBlossomCloud(Canvas canvas, Offset center, double crownR,
      double fit, double frac, math.Random rng) {
    if (frac <= 0.01) return;

    const pinkShades = <Color>[
      Color(0xFFFFB7C5),
      Color(0xFFFF8FAB),
      Color(0xFFFFC8D4),
      Color(0xFFFF9EBA),
    ];

    final blobCount = (frac * 10).round().clamp(4, 10);
    final windLean  = windSway(windPhase, 1.0, windAmp) * 14;

    // Fully opaque base — eliminates all blob boundary artifacts
    final baseAlpha = frac.clamp(0.0, 1.0);
    canvas.drawCircle(
      center,
      crownR * 0.96,
      Paint()..color = const Color(0xFFFFB7C5).withValues(alpha: baseAlpha),
    );

    // Subtle blob texture layer (low overall alpha so base stays dominant)
    canvas.saveLayer(
      Rect.fromCircle(center: center, radius: crownR + 15),
      Paint()..color = Color.fromARGB((frac * 120).round(), 255, 255, 255),
    );

    for (int bi = 0; bi < blobCount; bi++) {
      final angle  = bi * math.pi * 2 / blobCount + rng.nextDouble() * 0.5 + seed * 0.07;
      final dist   = crownR * (0.04 + rng.nextDouble() * 0.38);
      final blobR  = crownR * (0.44 + rng.nextDouble() * 0.28);
      final bCenter = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist * 0.78,
      );
      foliageBlob(canvas, bCenter, blobR, pinkShades, rng, windLean);
    }

    canvas.restore();
  }

  // ── Green/autumn leaf cloud (non-spring crown fill) ───────────────────────
  void _drawLeafCloud(Canvas canvas, Offset center, double crownR,
      double fit, double frac, math.Random rng, bool isFall) {
    if (frac <= 0.01) return;

    final shades = isFall
        ? const <Color>[Color(0xFFE65100), Color(0xFFF57F17), Color(0xFFBF360C)]
        : const <Color>[Color(0xFF81C784), Color(0xFF4CAF50), Color(0xFF2E7D32)];

    final blobCount = (frac * 8).round().clamp(3, 8);
    final windLean  = windSway(windPhase, 1.0, windAmp) * 14;

    canvas.saveLayer(
      Rect.fromCircle(center: center, radius: crownR + 12),
      Paint()..color = Color.fromARGB((frac * 255).round(), 255, 255, 255),
    );
    for (int bi = 0; bi < blobCount; bi++) {
      final angle  = bi * math.pi * 2 / blobCount + rng.nextDouble() * 0.5;
      final dist   = crownR * (0.08 + rng.nextDouble() * 0.40);
      final blobR  = crownR * (0.35 + rng.nextDouble() * 0.25);
      final bc = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist * 0.80,
      );
      foliageBlob(canvas, bc, blobR, shades, rng, windLean);
    }
    canvas.restore();
  }

  // ── Falling petals (spring, g > 0.72) ────────────────────────────────────
  // IMPORTANT: y INCREASES over time so petals fall DOWNWARD.
  void _drawFallingPetals(Canvas canvas, Size size, double fit) {
    // How many petals to show: ramps from 0 to 18 as g goes from 0.72 → 1.0
    final maxPetals = ((g - 0.72) / 0.28 * 18).round().clamp(0, 18);
    if (maxPetals == 0) return;

    final particles = _buildParticles();
    final petalLen = 4.5 * fit;
    final petalWidth = 3.0 * fit;

    for (int i = 0; i < maxPetals; i++) {
      final s = particles[i];

      // y fraction INCREASES with windPhase (falls downward)
      // Use modulo so particles loop continuously from top to bottom
      final yFrac = (s.y + windPhase * s.spd) % 1.0;

      // Horizontal position: base position + sinusoidal wind drift
      final xFrac = s.x + math.sin(windPhase * math.pi * 2 * s.freq + s.phase) * s.amp;
      final px = xFrac * size.width;
      // Map yFrac to canvas: starts above canopy (10% from top) falls to 95% height
      final py = size.height * 0.10 + yFrac * size.height * 0.85;

      // Rotation tumbles as it falls
      final rot = s.rot + windPhase * math.pi * 4 + s.phase;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rot);

      // Draw as a single petal shape (small, semi-transparent)
      petal(
        canvas,
        Offset.zero,
        petalLen,
        petalWidth,
        0, // pointing up in local space; rotation applied by canvas.rotate
        const Color(0xCCFFF0F5),
        const Color(0xCCFFB7C5),
      );

      canvas.restore();
    }
  }
}
