import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 사과나무 — 풍성한 잎 + 자연스러운 3D 구조 (enhanced polygon graphics)
// ═══════════════════════════════════════════════════════════════════════════

class _Season {
  final double leaf, blossom, fruit;
  final Color leafColor;
  const _Season(this.leaf, this.blossom, this.fruit, this.leafColor);

  static _Season of(int m) => switch (m) {
        1 || 2 || 12 => const _Season(0.0, 0.0, 0.0, Color(0xFF8D6E63)),
        3  => const _Season(0.30, 0.0, 0.0, Color(0xFF81C784)),
        4  => const _Season(0.75, 1.0, 0.0, Color(0xFF66BB6A)),
        5  => const _Season(0.95, 0.35, 0.12, Color(0xFF43A047)),
        6  => const _Season(1.0, 0.0, 0.35, Color(0xFF388E3C)),
        7 || 8 => const _Season(1.0, 0.0, 0.65, Color(0xFF2E7D32)),
        9  => const _Season(0.90, 0.0, 0.90, Color(0xFF558B2F)),
        10 => const _Season(0.55, 0.0, 1.0, Color(0xFFE65100)),
        11 => const _Season(0.20, 0.0, 0.30, Color(0xFFBF360C)),
        _  => const _Season(0.70, 0.0, 0.0, Color(0xFF43A047)),
      };
}

void buildAppleTree(Scene scene, double g, int seed, int month) {
  _AppleBuilder(scene, g, _Season.of(month), math.Random(seed)).build();
}

class _AppleBuilder {
  final Scene scene;
  final double g;
  final _Season sn;
  final math.Random rng;
  static const int maxDepth = 5;

  _AppleBuilder(this.scene, this.g, this.sn, this.rng);

  void build() {
    _grow(const V3(0, 2, 0), const V3(0, 1, 0), 260, 24, 0, 0.0);
  }

  Color _bark(int d) {
    // Winter: darker more realistic bark; Spring/Summer: warm brown
    final isWinter = sn.leaf == 0.0 && sn.blossom == 0.0 && sn.fruit == 0.0;
    final darkBark = isWinter
        ? const Color(0xFF5D4037)
        : const Color(0xFF4A2810);
    return Color.lerp(darkBark, const Color(0xFF8B5A30),
        (d / maxDepth).clamp(0.0, 1.0))!;
  }

  Color _leafTint() {
    final t = (rng.nextDouble() - 0.5) * 0.24;
    // Autumn: push toward orange tones when leafColor has orange hue
    final leafR = sn.leafColor.r;
    final leafG = sn.leafColor.g;
    final isOrange = leafR > 0.7 && leafG < 0.55;
    if (isOrange) {
      final orangeT = rng.nextDouble() * 0.40;
      return Color.lerp(
          sn.leafColor,
          orangeT < 0.2
              ? const Color(0xFFFF8F00)
              : const Color(0xFFE65100),
          orangeT)!;
    }
    return Color.lerp(
        sn.leafColor,
        t < 0 ? const Color(0xFF1A5E20) : const Color(0xFFA5D6A7),
        t.abs())!;
  }

  /// Darken a color by multiplying channels by [factor].
  Color _darkenColor(Color c, double factor) {
    return Color.fromARGB(
      (c.a * 255).round(),
      ((c.r * 255) * factor).round().clamp(0, 255),
      ((c.g * 255) * factor).round().clamp(0, 255),
      ((c.b * 255) * factor).round().clamp(0, 255),
    );
  }

  V3 _addCurvedBranch(
      V3 pos, V3 dir, double len, double rad, int depth, double tBirth) {
    const segs = 3;
    V3 p = pos;
    V3 d = dir;
    final sl = len / segs;

    for (int i = 0; i < segs; i++) {
      final sideAxis = d.anyPerp;
      final wobbleAng = (rng.nextDouble() - 0.5) * 0.20;
      d = (d + sideAxis * wobbleAng).normalized;
      d = (d + const V3(0, 0.06, 0)).normalized;

      final t = i / segs;
      final end = p + d * sl;
      final r0 = rad * (1 - t * 0.08);
      final r1 = rad * (1 - (t + 1.0 / segs) * 0.08);
      scene.add(BranchPrim(p, end, r0, r1, _bark(depth)));
      p = end;
    }
    return p;
  }

  void _grow(
      V3 pos, V3 dir, double len, double rad, int depth, double tBirth) {
    final local = sstep(tBirth, tBirth + 0.22, g);
    if (local < 0.01) return;
    final segLen = len * local;
    if (segLen < 1.0) return;

    V3 end;
    if (depth <= 1 && segLen > 38) {
      end = _addCurvedBranch(pos, dir, segLen, rad, depth, tBirth);
    } else {
      final perp = dir.anyPerp;
      final wobble = (rng.nextDouble() - 0.5) * rad * 0.55;
      end = pos + dir * segLen + perp * wobble;
      scene.add(BranchPrim(pos, end, rad, rad * 0.68, _bark(depth)));
    }

    // Branch joint knobs — now at depth <= 3 (was <= 2), larger radius
    if (depth <= 3 && g > 0.20) {
      scene.add(SpherePrim(
          end,
          rad * (0.88 + rng.nextDouble() * 0.18),
          _bark(depth),
          glossy: false));
      // Mid-branch swelling knob at ~60% of segment
      if (depth <= 2 && segLen > 20) {
        final midPos = pos + dir * (segLen * 0.60);
        scene.add(SpherePrim(
            midPos, rad * 0.62, _bark(depth), glossy: false));
      }
    }

    // Mid-branch leaves
    if (depth >= 2 && len > 24 && sn.leaf > 0) {
      for (int li = 0; li < 2; li++) {
        final frac = 0.38 + li * 0.28;
        final rotAng = 1.0 + rng.nextDouble() * 0.55 + li * math.pi;
        final outDir = dir.rotateAxis(dir.anyPerp, rotAng);
        _addLeaf(
          pos + dir * (segLen * frac),
          outDir.normalized,
          lp(16, 28, sn.leaf),
          tBirth + 0.12 + li * 0.06,
        );
      }
    }

    if (depth >= maxDepth || len < 20) {
      _terminal(end, dir, depth, tBirth + 0.11);
      return;
    }

    final side = dir.anyPerp;
    final childBirth = tBirth + 0.12;
    final n = depth == 0
        ? 3
        : (depth == 1 ? 3 : (rng.nextDouble() < 0.65 ? 3 : 2));
    final phi0 = rng.nextDouble() * math.pi * 2;
    for (int i = 0; i < n; i++) {
      final ba  = lp(0.38, 0.78, rng.nextDouble());
      final phi = phi0 + i * 2.39996 + (rng.nextDouble() - 0.5) * 0.45;
      var cd = dir.rotateAxis(side, ba).rotateAxis(dir, phi).normalized;
      cd = (cd + const V3(0, 0.22, 0)).normalized;
      final cpos = depth == 0
          ? pos + dir * (segLen * lp(0.30, 0.95, i / (n - 0.999)))
          : end;
      _grow(
        cpos, cd,
        len * lp(0.60, 0.78, rng.nextDouble()),
        (rad * (depth == 0 ? 0.58 : 0.62)) *
            lp(0.80, 1.0, rng.nextDouble()),
        depth + 1,
        childBirth + i * 0.014,
      );
    }
    if (depth == 0) {
      _grow(end, dir.rotateAxis(side, 0.10).normalized, len * 0.66, rad * 0.62,
          1, childBirth);
    }
  }

  void _terminal(V3 pos, V3 dir, int depth, double tBirth) {
    if (sn.leaf > 0) {
      final cnt = 7 + rng.nextInt(6);
      for (int i = 0; i < cnt; i++) {
        final phi = i * 2.39996 + rng.nextDouble() * 0.5;
        final outDir = dir
            .rotateAxis(dir.anyPerp, lp(0.40, 1.45, rng.nextDouble()))
            .rotateAxis(dir, phi)
            .normalized;
        _addLeaf(
          pos + outDir * (lp(0, 6, rng.nextDouble())),
          outDir,
          lp(14, 30, sn.leaf) * (0.72 + rng.nextDouble() * 0.56),
          tBirth + 0.030 * i,
        );
      }
    } else if (g > 0.3) {
      scene.add(SpherePrim(
          pos + dir * 3, 2.8, const Color(0xFF8D6E63), glossy: false));
    }

    final fa = sn.blossom > 0.2 ? sstep(0.64, 0.80, g) * sn.blossom : 0.0;
    if (fa > 0.15 && rng.nextDouble() < 0.65) _blossom(pos + dir * 4, fa);

    final ra = sn.fruit > 0.2 ? sstep(0.78, 0.96, g) * sn.fruit : 0.0;
    if (ra > 0.2 && rng.nextDouble() < 0.55) {
      final ripe = sstep(0.85, 1.0, g);
      // More vibrant fruit colors: green -> red
      final col = Color.lerp(
          const Color(0xFF7CB342), const Color(0xFFD32F2F), ripe.clamp(0.0, 1.0))!;
      final fruitPos = pos + dir * lp(2, 7, ra);
      final fruitRad = lp(3, 12, ra);
      scene.add(SpherePrim(fruitPos, fruitRad, col));

      // White highlight sphere on top of apple
      final fit = ripe.clamp(0.3, 1.0);
      scene.add(SpherePrim(
          fruitPos + dir * lp(2, 7, ra) + V3(-1.5, 2.0, 1.0) * fit,
          lp(1, 3, ra),
          const Color(0xCCFFFFFF),
          glossy: false));

      // Calyx: 5 tiny dark-green BranchPrims radiating from bottom of apple
      if (ripe > 0.3 && fruitRad > 3.0) {
        final calyxBase = fruitPos - dir * (fruitRad * 0.7);
        final calyxAxis = dir.anyPerp;
        for (int ci = 0; ci < 5; ci++) {
          final calyxAng = ci * 2 * math.pi / 5;
          final calyxDir = calyxAxis
              .rotateAxis(dir, calyxAng)
              .rotateAxis(calyxAxis.rotateAxis(dir, calyxAng), 0.55)
              .normalized;
          final calyxTip = calyxBase + calyxDir * (fruitRad * 0.55);
          scene.add(BranchPrim(
              calyxBase, calyxTip, 0.6, 0.2, const Color(0xFF2E7D32)));
        }
      }
    }
  }

  void _addLeaf(V3 base, V3 outDir, double size, double tBirth) {
    final lg = sstep(tBirth, tBirth + 0.17, g);
    if (lg < 0.03) return;
    final s = size * lg;

    // Increased asymmetry range to ±0.35
    final asymm = (rng.nextDouble() - 0.5) * 0.35;
    final w = outDir.anyPerp;
    final droop = rng.nextDouble() * 0.10 + 0.04;
    final tip = base + outDir * s + V3(0, -droop * s, 0);

    final normal = outDir.cross(w).normalized;
    final p1 = base + outDir * (s * (0.42 + asymm * 0.08)) +
        w * (s * (0.35 + asymm));
    final p2 = base + outDir * (s * (0.44 - asymm * 0.08)) -
        w * (s * (0.32 - asymm));

    final leafColor = _leafTint();

    // Front face
    scene.add(QuadPrim(
      [base, p1, tip, p2],
      normal,
      leafColor,
      veinColor: const Color(0xFF1A5C1A),
    ));

    // Back face: slightly darker, offset outward for volume/thickness
    final backNormal = normal * -1.0;
    final outOffset = outDir * 0.5;
    final backColor = _darkenColor(leafColor, 0.82);
    scene.add(QuadPrim(
      [
        base + outOffset,
        p1 + outOffset,
        tip + outOffset,
        p2 + outOffset,
      ],
      backNormal,
      backColor,
      veinColor: const Color(0xFF1A5C1A),
    ));

    // 3rd mid-lobe for larger leaves (leaf growth 0.40-0.85 range)
    if (lg > 0.40 && lg < 0.85) {
      final lobeMid = base + outDir * (s * 0.55);
      final lobeTip = base + outDir * (s * 0.78);
      final lobeLeft  = lobeMid + w * (s * 0.11);
      final lobeRight = lobeMid - w * (s * 0.11);
      scene.add(QuadPrim(
        [lobeMid - w * (s * 0.06), lobeLeft, lobeTip, lobeRight],
        normal,
        _darkenColor(leafColor, 0.92),
        veinColor: const Color(0xFF1A5C1A),
      ));
    }
  }

  void _blossom(V3 center, double a) {
    final w = const V3(0, 1, 0).anyPerp;
    final n2 = const V3(0, 1, 0);
    final sz = lp(5, 13, a);

    // 5 petals — wider than before
    for (int i = 0; i < 5; i++) {
      final ang = i * 2 * math.pi / 5 + rng.nextDouble() * 0.28;
      final d = w.rotateAxis(n2, ang);
      final pw = d.anyPerp;
      final tip = center + d * sz;
      final petalCol = Color.lerp(
          const Color(0xFFFFB3C8), const Color(0xFFFFF0F5), i / 5.0)!;
      scene.add(QuadPrim([
        center,
        center + d * (sz * 0.62) + pw * (sz * 0.42),
        tip,
        center + d * (sz * 0.62) - pw * (sz * 0.42),
      ], n2, petalCol));
    }

    // 5 stamens: tiny BranchPrims radiating from center
    for (int i = 0; i < 5; i++) {
      final ang = i * 2 * math.pi / 5 + math.pi / 5 + rng.nextDouble() * 0.15;
      final sd = w.rotateAxis(n2, ang);
      final stamenTip = center + sd * (sz * 0.3) + n2 * (sz * 0.18);
      scene.add(BranchPrim(
          center, stamenTip, 0.3, 0.15, const Color(0xFFFFD54F)));
      // Anther tip
      scene.add(SpherePrim(
          stamenTip, 0.8, const Color(0xFFFFEB3B), glossy: false));
    }

    // Center: golden sphere
    scene.add(SpherePrim(
        center, sz * 0.40, const Color(0xFFFFE566), glossy: true));
    // Tiny white highlight on center
    scene.add(SpherePrim(
        center + n2 * (sz * 0.28),
        sz * 0.12,
        const Color(0xCCFFFFFF),
        glossy: false));
  }
}
