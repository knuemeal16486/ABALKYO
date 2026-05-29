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

      for (final tip in branchTips) {
        if (isSpring) {
          _drawBlossomCluster(canvas, tip, fit, crownFrac, math.Random(seed ^ tip.hashCode), windPhase);
        } else if (!isWinter) {
          _drawLeafCluster(canvas, tip, fit, crownFrac, math.Random(seed ^ tip.hashCode), isFall);
        }
        // Winter: bare branches only — no crown drawn
      }

      // Falling petals
      if (isSpring && g > 0.72) {
        _drawFallingPetals(canvas, size, fit);
      }
    }

    realisticPot(canvas, ground, fit);
    drawWiltOverlay(canvas, size, wiltFactor);
  }

  // ── Trunk: multi-segment barkBranch with thick taper ─────────────────────
  void _drawTrunk(Canvas canvas, Offset base, Offset tip, double fit, double g, math.Random rng) {
    const int segs = 5;
    const Color barkLight = Color(0xFF2D1B0E);
    const Color barkDark = Color(0xFF1A0A05);

    for (int i = 0; i < segs; i++) {
      final t0 = i / segs;
      final t1 = (i + 1) / segs;
      // Taper thickness: 18*fit at base → 8*fit at top
      final thick0 = lp(18, 8, t0) * fit;
      // Only draw segments that have grown (g controls how high trunk reaches)
      final growFrac = sstep(0.07, 0.35, g);
      if (t0 > growFrac) break;

      final segFrom = Offset(
        lp(base.dx, tip.dx, t0),
        lp(base.dy, tip.dy, t0),
      );
      final segTo = Offset(
        lp(base.dx, tip.dx, math.min(t1, growFrac)),
        lp(base.dy, tip.dy, math.min(t1, growFrac)),
      );

      barkBranch(
        canvas,
        segFrom,
        segTo,
        thick0,
        barkLight,
        barkDark,
        lenticels: true,
        rng: rng,
      );
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
    const Color barkLight = Color(0xFF2D1B0E);
    const Color barkDark = Color(0xFF1A0A05);

    // Each entry: [side(-1/+1), trunkHeightFrac, primaryAngleOff, primaryLenScale]
    // 7 branches at heights 55%–92% of trunk
    final branchDefs = <List<double>>[
      [-1.0, 0.55, 0.52, 1.00],
      [ 1.0, 0.62, 0.48, 0.95],
      [-1.0, 0.70, 0.50, 0.88],
      [ 1.0, 0.76, 0.45, 0.82],
      [-1.0, 0.82, 0.42, 0.72],
      [ 1.0, 0.87, 0.40, 0.65],
      [ 0.0, 0.92, 0.10, 0.55], // near-vertical top branch
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
    const petalLen = 10.0;
    const petalWidth = 6.0;
    const Color lightPink = Color(0xFFFFF0F5);
    const Color deepPink = Color(0xFFFFB7C5);

    // 5 petals at 0, 72, 144, 216, 288 degrees (converted to radians)
    for (int i = 0; i < 5; i++) {
      final angleDeg = i * 72.0;
      final angleRad = angleDeg * math.pi / 180.0;

      // Attach point sits slightly off center so petals radiate naturally
      final attachDist = petalWidth * 0.5 * fit;
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
