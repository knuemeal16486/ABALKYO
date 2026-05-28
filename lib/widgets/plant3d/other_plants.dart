import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 마음 정원 — 토마토 / 포도나무 / 벚꽃 / 라벤더
// ═══════════════════════════════════════════════════════════════════════════

// ── 공통 잎 헬퍼 ─────────────────────────────────────────────────────────────
void _leafQuad(
  Scene scene,
  V3 base,
  V3 dir,
  double len,
  double width,
  Color color, {
  Color? tip,
  double tipFrac = 0.0,
  Color? veinColor,
  double asymm = 0.0,
  double droop = 0.0,
}) {
  if (len < 1) return;
  final w     = dir.anyPerp;
  final vc    = veinColor ?? const Color(0x55143A1E);
  final tipPt = base + dir * len + V3(0, -droop * len, 0);
  final normal = dir.cross(w).normalized;
  scene.add(QuadPrim([
    base,
    base + dir * (len * (0.44 + asymm * 0.06)) + w * (width * (0.5 + asymm)),
    tipPt,
    base + dir * (len * (0.44 - asymm * 0.06)) - w * (width * (0.5 - asymm)),
  ], normal, color, veinColor: vc));

  if (tip != null && tipFrac > 0.02) {
    scene.add(QuadPrim([
      base + dir * (len * 0.72),
      base + dir * (len * 0.87) + w * (width * 0.22),
      tipPt,
      base + dir * (len * 0.87) - w * (width * 0.22),
    ], normal, tip.withValues(alpha: tipFrac.clamp(0.0, 1.0))));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. 토마토
// ═══════════════════════════════════════════════════════════════════════════

void buildTomato(Scene scene, double g, int seed) {
  final rng  = math.Random(seed);
  final grow = sstep(0.0, 0.85, g);

  final numSegs = 6 + rng.nextInt(3); // 6-8
  final totalH  = lp(15, 200, grow);
  final segLen  = totalH / numSegs;
  final baseRad = lp(2.0, 9.0, grow);
  final topRad  = lp(1.5, 4.5, grow);

  // Collect stem node positions
  final stemNodes = <V3>[];
  var pos = const V3(0, 0, 0);
  var dir = const V3(0, 1, 0);

  // ── Main stem ──────────────────────────────────────────────────────────
  for (int i = 0; i < numSegs; i++) {
    final t   = i / numSegs;
    final r0  = lp(baseRad, topRad, t);
    final r1  = lp(baseRad, topRad, (i + 1) / numSegs);
    final col = Color.lerp(
      const Color(0xFF4CAF50),
      const Color(0xFF81C784),
      t,
    )!;

    // Natural wobble
    final perp = dir.anyPerp;
    final wob  = (rng.nextDouble() - 0.5) * 0.18;
    dir = (dir + perp * wob).normalized;

    stemNodes.add(pos);
    final end = pos + dir * segLen;
    scene.add(BranchPrim(pos, end, r0, r1, col));
    pos = end;
  }
  stemNodes.add(pos); // top node

  // ── Side branches + compound leaves ───────────────────────────────────
  for (int i = 0; i < stemNodes.length; i++) {
    final nodePos = stemNodes[i];
    final t       = i / (stemNodes.length - 1).toDouble();

    // Side branches at every other node
    if (i % 2 == 0 && i < stemNodes.length - 1) {
      final phi      = i * 2.39996;
      final stemDir2 = (i + 1 < stemNodes.length)
          ? (stemNodes[i + 1] - stemNodes[i]).normalized
          : const V3(0, 1, 0);
      final perpRotated = stemDir2.anyPerp.rotateAxis(stemDir2, phi);
      final sideDir     = (perpRotated + const V3(0, 0.5, 0)).normalized;

      final bLen  = segLen * lp(0.35, 0.55, rng.nextDouble());
      final brEnd = nodePos + sideDir * bLen;
      scene.add(BranchPrim(
        nodePos, brEnd,
        lp(0.8, 3.5, grow),
        lp(0.5, 2.0, grow),
        const Color(0xFF66BB6A),
      ));

      // Compound leaf at branch tip
      _tomatoCompoundLeaf(scene, rng, brEnd, sideDir, grow, t);
    }

    // Compound leaves at stem nodes (g > 0.15)
    if (g > 0.15 && i > 0) {
      final phi2   = i * 2.39996 + math.pi;
      final up     = (i < stemNodes.length - 1)
          ? (stemNodes[i + 1] - stemNodes[i]).normalized
          : const V3(0, 1, 0);
      final lDir   = (up.anyPerp.rotateAxis(up, phi2 + 1.2) + const V3(0, 0.3, 0)).normalized;
      _tomatoCompoundLeaf(scene, rng, nodePos, lDir, grow, t);
    }
  }

  // ── Flowers (g >= 0.55) ────────────────────────────────────────────────
  final flowerAlpha = sstep(0.55, 0.68, g);
  if (flowerAlpha > 0.02) {
    for (int i = 1; i < stemNodes.length - 1; i += 2) {
      if (rng.nextDouble() < 0.60) {
        _tomatoFlower(scene, rng, stemNodes[i], flowerAlpha);
      }
    }
  }

  // ── Fruits (g >= 0.70) ────────────────────────────────────────────────
  if (g >= 0.70) {
    final fruitGrow = sstep(0.70, 0.95, g);
    for (int i = 0; i < stemNodes.length - 1; i += 2) {
      if (rng.nextDouble() < 0.65) {
        final count  = 2 + rng.nextInt(3); // 2-4
        final anchor = stemNodes[i];
        for (int fi = 0; fi < count; fi++) {
          final phi  = fi * 2.39996 + rng.nextDouble() * 0.4;
          final spread = lp(6, 22, fruitGrow);
          final off  = V3(
            math.cos(phi) * spread,
            lp(2, 8, rng.nextDouble()),
            math.sin(phi) * spread,
          );
          final fPos = anchor + off;
          final fRad = lp(4, 16, fruitGrow);

          // Color: green → red
          final ripe = sstep(0.82, 0.90, g);
          final fCol = Color.lerp(
            const Color(0xFF66BB6A),
            const Color(0xFFE53935),
            ripe,
          )!;
          final isGlossy = g >= 0.82;
          scene.add(SpherePrim(fPos, fRad, fCol, glossy: isGlossy));

          // Calyx (꼭지) when ripe
          if (g >= 0.82 && fRad > 5) {
            final calyxBase = fPos + V3(0, fRad * 0.8, 0);
            for (int ci = 0; ci < 5; ci++) {
              final ca = ci * 2 * math.pi / 5;
              final cd = V3(math.cos(ca) * 0.7, 1.0, math.sin(ca) * 0.7).normalized;
              scene.add(BranchPrim(
                calyxBase,
                calyxBase + cd * lp(3, 4, rng.nextDouble()),
                0.5, 0.2,
                const Color(0xFF2E7D32),
              ));
            }
          }

          // White highlight on ripe tomato
          if (g >= 0.82) {
            scene.add(SpherePrim(
              fPos + V3(-1, 2, 1) * 0.5,
              fRad * 0.18,
              const Color(0xCCFFFFFF),
              glossy: false,
            ));
          }
        }
      }
    }
  }
}

/// Compound tomato leaf: petiole + 3 opposite pairs + 1 terminal = 7 leaflets
void _tomatoCompoundLeaf(
  Scene scene,
  math.Random rng,
  V3 base,
  V3 dir,
  double grow,
  double t,
) {
  if (grow < 0.05) return;
  final petLen = lp(12, 18, grow) * (0.7 + rng.nextDouble() * 0.3);
  final petEnd = base + dir * petLen;
  scene.add(BranchPrim(base, petEnd, 1.2, 0.8, const Color(0xFF4CAF50)));

  const leafColor = Color(0xFF388E3C);
  const veinColor = Color(0xFF1B5E20);
  final leafSz    = lp(8, 22, grow) * (1 - t * 0.1).clamp(0.4, 1.0);
  final sidePerp  = dir.anyPerp;

  // 3 opposite pairs
  for (int pair = 0; pair < 3; pair++) {
    final frac  = (pair + 1) / 4.0;
    final pNode = base + dir * (petLen * frac);
    for (final sign in [-1.0, 1.0]) {
      final lDir = (sidePerp * sign + dir * 0.25 + V3(0, -0.1, 0)).normalized;
      _leafQuad(
        scene, pNode, lDir,
        leafSz * (1 - pair * 0.12),
        leafSz * 0.45,
        leafColor,
        veinColor: veinColor,
        droop: 0.06 + rng.nextDouble() * 0.06,
        asymm: (rng.nextDouble() - 0.5) * 0.2,
      );
    }
  }

  // Terminal leaflet
  _leafQuad(
    scene, petEnd, (dir + const V3(0, -0.08, 0)).normalized,
    leafSz * 1.1, leafSz * 0.50,
    leafColor,
    veinColor: veinColor,
    droop: 0.08,
  );
}

/// Small 5-petal tomato flower
void _tomatoFlower(
  Scene scene,
  math.Random rng,
  V3 center,
  double alpha,
) {
  final sz = 4.5 + rng.nextDouble() * 2;
  final up = const V3(0, 1, 0);
  final w  = up.anyPerp;
  for (int i = 0; i < 5; i++) {
    final ang = i * 2 * math.pi / 5 + rng.nextDouble() * 0.2;
    final d   = w.rotateAxis(up, ang);
    final tip = center + d * sz;
    final pw  = d.anyPerp;
    scene.add(QuadPrim([
      center,
      center + d * (sz * 0.55) + pw * (sz * 0.28),
      tip,
      center + d * (sz * 0.55) - pw * (sz * 0.28),
    ], up, const Color(0xFFFDD835).withValues(alpha: alpha)));
  }
  scene.add(SpherePrim(
    center + up * 1.5,
    lp(2, 3, alpha),
    const Color(0xFFF9A825),
    glossy: false,
  ));
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. 포도나무 (Grapevine)
// ═══════════════════════════════════════════════════════════════════════════

void buildGrapevine(Scene scene, double g, int seed) {
  final rng  = math.Random(seed);
  final grow = sstep(0.0, 0.88, g);

  final postH = lp(30, 180, grow);

  // ── Support posts (기둥) ──────────────────────────────────────────────
  for (final px in [-22.0, 22.0]) {
    scene.add(BranchPrim(
      V3(px, 0, 0), V3(px, postH, 0),
      3.5, 3.0,
      const Color(0xFF795548),
    ));
  }

  // Crossbar (횡목)
  scene.add(BranchPrim(
    V3(-22, postH, 0), V3(22, postH, 0),
    2.5, 2.5,
    const Color(0xFF795548),
  ));

  // 2 wire lines at 1/3 and 2/3 heights
  for (final frac in [1 / 3.0, 2 / 3.0]) {
    final wy = postH * frac;
    scene.add(BranchPrim(
      V3(-22, wy, 0), V3(22, wy, 0),
      0.6, 0.6,
      const Color(0xFF9E9E9E),
    ));
  }

  // ── Main vines (덩굴) ─────────────────────────────────────────────────
  final vineXOffsets = [-8.0, 0.0, 10.0];
  for (int vi = 0; vi < 3; vi++) {
    final xOff     = vineXOffsets[vi];
    final numSegs  = 8 + rng.nextInt(3);
    final vineNodes = <V3>[];
    var   vPos     = V3(xOff, 5, 0);
    var   vDir     = const V3(0, 1, 0);

    for (int si = 0; si < numSegs; si++) {
      final t   = si / numSegs;
      final r0  = lp(3.5, 1.5, t);
      final r1  = lp(3.5, 1.5, (si + 1) / numSegs);

      // Gentle wind & spread toward crossbar edges
      final wobble   = (rng.nextDouble() - 0.5) * 0.22;
      final xDrift   = (xOff > 0 ? 0.04 : -0.04);
      vDir = (vDir + vDir.anyPerp * wobble + V3(xDrift, 0, 0)).normalized;

      vineNodes.add(vPos);
      final segH = postH / numSegs;
      final vEnd = vPos + vDir * segH;
      scene.add(BranchPrim(vPos, vEnd, r0, r1, const Color(0xFF558B2F)));
      vPos = vEnd;
    }
    vineNodes.add(vPos);

    // Tendrils (덩굴손) at vine tip
    _grapeTendrils(scene, rng, vPos, grow);

    // Leaves + clusters at each vine node
    for (int ni = 0; ni < vineNodes.length; ni++) {
      final nPos = vineNodes[ni];

      // Leaf at each node (g > 0.20, ni > 0)
      if (g > 0.20 && ni > 0) {
        final phi  = ni * 2.39996 + vi * 1.2;
        final up   = (ni < vineNodes.length - 1)
            ? (vineNodes[ni + 1] - vineNodes[ni]).normalized
            : const V3(0, 1, 0);
        final lDir = (up.anyPerp.rotateAxis(up, phi) + const V3(0, 0.15, 0)).normalized;
        _grapeLeaf(scene, rng, nPos, lDir, grow, g);
      }

      // Grape clusters (g >= 0.60), 1-2 bunches per node (g >= 0.78)
      if (g >= 0.60 && ni > 0 && ni < vineNodes.length - 1 && rng.nextDouble() < 0.55) {
        final bunches = (g >= 0.78 && rng.nextDouble() < 0.55) ? 2 : 1;
        for (int bi = 0; bi < bunches; bi++) {
          final bOff = V3(
            (rng.nextDouble() - 0.5) * 10,
            0,
            (rng.nextDouble() - 0.5) * 8,
          );
          _grapeCluster(scene, rng, nPos + bOff, g);
        }
      }
    }
  }
}

/// 5-lobed palmate grape leaf
void _grapeLeaf(
  Scene scene,
  math.Random rng,
  V3 node,
  V3 leafDir,
  double grow,
  double g,
) {
  final petLen = lp(8, 14, grow) * (0.8 + rng.nextDouble() * 0.4);
  final center = node + leafDir * petLen;
  scene.add(BranchPrim(node, center, 1.5, 0.8, const Color(0xFF4CAF50)));

  final lobeSz   = lp(12, 36, grow) * (0.7 + rng.nextDouble() * 0.3);
  final isAutumn = g > 0.88;
  final autumnT  = isAutumn ? sstep(0.88, 1.0, g) : 0.0;

  for (int li = 0; li < 5; li++) {
    final ang  = li * 2 * math.pi / 5;
    // Rotate around the leaf direction axis to fan lobes out
    final lDir = leafDir.anyPerp
        .rotateAxis(leafDir, ang)
        .rotateAxis(leafDir.anyPerp.rotateAxis(leafDir, ang), 0.45)
        .normalized;
    final leafC = isAutumn
        ? Color.lerp(const Color(0xFF4CAF50), const Color(0xFFE65100), autumnT)!
        : const Color(0xFF4CAF50);
    _leafQuad(
      scene, center, lDir,
      lobeSz * (li == 0 ? 1.0 : 0.75),
      lobeSz * 0.40,
      leafC,
      veinColor: const Color(0xFF1B5E20),
      droop: 0.05 + rng.nextDouble() * 0.05,
      asymm: (rng.nextDouble() - 0.5) * 0.15,
    );
  }
}

/// Coiling tendrils (덩굴손) at vine tips
void _grapeTendrils(
  Scene scene,
  math.Random rng,
  V3 tip,
  double grow,
) {
  if (grow < 0.15) return;
  final count = 4 + rng.nextInt(3); // 4-6
  for (int ti = 0; ti < count; ti++) {
    final t   = ti / count;
    final ang = ti * 2.1 + rng.nextDouble() * 0.5;
    final r   = lp(3, 8, t);
    final h   = lp(0, 12, t);
    final pos = tip + V3(math.cos(ang) * r, h, math.sin(ang) * r);
    scene.add(SpherePrim(
      pos,
      lp(1.2, 2.0, rng.nextDouble()),
      const Color(0xFF9CCC65),
      glossy: false,
    ));
  }
}

/// Grape cluster — inverse-triangle arrangement hanging DOWN
void _grapeCluster(
  Scene scene,
  math.Random rng,
  V3 hangPoint,
  double g,
) {
  final clusterGrow = sstep(0.60, 0.95, g);
  final grapeR      = lp(3, 7, clusterGrow);
  final clusterH    = grapeR * 8;

  // Bunch stem
  final topPos = hangPoint - V3(0, clusterH * 0.2, 0);
  scene.add(BranchPrim(hangPoint, topPos, 1.2, 0.8, const Color(0xFF558B2F)));

  // Row layout: 4, 5, 5, 4, 3
  final rowSizes = [4, 5, 5, 4, 3];
  final isGlossy = g >= 0.80;
  final ripe     = sstep(0.80, 0.90, g);
  final grapeCol = Color.lerp(
    const Color(0xFF9CCC65),
    const Color(0xFF7B1FA2),
    ripe,
  )!;

  final botY = topPos.y - clusterH;

  for (int row = 0; row < rowSizes.length; row++) {
    final n    = rowSizes[row];
    // Row 0 = top, row 4 = bottom
    final rowY = lp(topPos.y, botY, row / (rowSizes.length - 1.0));
    final rowW = (n - 1) * grapeR * 2.1;

    for (int gi = 0; gi < n; gi++) {
      final gx   = n > 1 ? (gi / (n - 1.0) - 0.5) * rowW : 0.0;
      final jitZ = (rng.nextDouble() - 0.5) * grapeR;
      final gPos = V3(topPos.x + gx, rowY, topPos.z + jitZ);

      scene.add(SpherePrim(gPos, grapeR, grapeCol, glossy: isGlossy));

      // Highlight
      scene.add(SpherePrim(
        gPos + V3(-0.4, 0.4, 0.3) * grapeR,
        grapeR * 0.35,
        const Color(0xAAFFFFFF),
        glossy: false,
      ));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. 벚꽃 (Cherry Blossom)
// ═══════════════════════════════════════════════════════════════════════════

void buildCherryBlossom(Scene scene, double g, int seed, int month) {
  final sn = _CherrySeasonInfo.of(month);
  _CherryBuilder(scene, g, sn, math.Random(seed), month).build();
}

/// Month-based season data for cherry blossom
class _CherrySeasonInfo {
  final double leaf;
  final double blossomBoost; // >1 means extra bloom multiplier

  const _CherrySeasonInfo(this.leaf, this.blossomBoost);

  static _CherrySeasonInfo of(int month) => switch (month) {
        3 || 4 => const _CherrySeasonInfo(0.0, 1.3),        // bare + peak bloom
        5 || 6 || 7 || 8 || 9 => const _CherrySeasonInfo(1.0, 0.0),
        10 => const _CherrySeasonInfo(0.5, 0.0),            // autumn half-leaf
        _ => const _CherrySeasonInfo(0.0, 0.0),             // winter bare
      };
}

class _CherryBuilder {
  final Scene             scene;
  final double            g;
  final _CherrySeasonInfo sn;
  final math.Random       rng;
  final int               month;

  static const int maxDepth = 4;

  _CherryBuilder(this.scene, this.g, this.sn, this.rng, this.month);

  void build() {
    _grow(const V3(0, 2, 0), const V3(0, 1, 0), 180, 15, 0, 0.0);
  }

  Color _bark(int depth) => Color.lerp(
    const Color(0xFF6D5B4E),
    const Color(0xFF9E8B7A),
    (depth / maxDepth).clamp(0.0, 1.0),
  )!;

  void _grow(V3 pos, V3 dir, double len, double rad, int depth, double tBirth) {
    final local  = sstep(tBirth, tBirth + 0.22, g);
    if (local < 0.01) return;
    final segLen = len * local;
    if (segLen < 1.0) return;

    // Slight natural curve
    final wob  = (rng.nextDouble() - 0.5) * 0.18;
    final dEnd = (dir + dir.anyPerp * wob + const V3(0, 0.05, 0)).normalized;
    final end  = pos + dEnd * segLen;

    scene.add(BranchPrim(pos, end, rad, rad * 0.70, _bark(depth)));

    // Bark knob at joints (characteristic sakura ring marks)
    if (depth <= 3 && g > 0.18) {
      scene.add(SpherePrim(
        end,
        rad * 0.75,
        const Color(0xFF5D4037),
        glossy: false,
      ));
    }

    if (depth >= maxDepth || len < 18) {
      _terminal(end, dEnd, depth, tBirth + 0.10);
      return;
    }

    final childBirth = tBirth + 0.11;
    final n    = depth == 0 ? 3 : (rng.nextDouble() < 0.60 ? 3 : 2);
    final phi0 = rng.nextDouble() * math.pi * 2;
    final side = dir.anyPerp;

    for (int i = 0; i < n; i++) {
      final ba  = lp(0.40, 0.72, rng.nextDouble());
      final phi = phi0 + i * 2.39996 + (rng.nextDouble() - 0.5) * 0.40;
      var cd    = dir.rotateAxis(side, ba).rotateAxis(dir, phi).normalized;
      cd = (cd + const V3(0, 0.18, 0)).normalized;
      final cPos = depth == 0
          ? pos + dEnd * (segLen * lp(0.30, 0.95, i / (n - 0.999)))
          : end;

      _grow(
        cPos, cd,
        len * lp(0.55, 0.72, rng.nextDouble()),
        rad * lp(0.55, 0.68, rng.nextDouble()),
        depth + 1,
        childBirth + i * 0.016,
      );
    }
  }

  void _terminal(V3 pos, V3 dir, int depth, double tBirth) {
    // Leaves — only when g > 0.50 and season allows; cherry blooms BEFORE leaves
    if (g > 0.50 && sn.leaf > 0) {
      final cnt = 4 + rng.nextInt(4);
      for (int li = 0; li < cnt; li++) {
        final leafG = sstep(tBirth + 0.02 * li, tBirth + 0.14 + 0.02 * li, g);
        if (leafG < 0.02) continue;
        final phi    = li * 2.39996 + rng.nextDouble() * 0.5;
        final outDir = dir
            .rotateAxis(dir.anyPerp, lp(0.35, 1.30, rng.nextDouble()))
            .rotateAxis(dir, phi)
            .normalized;
        final leafSz = lp(8, 18, sn.leaf) * leafG * (0.7 + rng.nextDouble() * 0.5);
        _leafQuad(
          scene,
          pos + outDir * (rng.nextDouble() * 5),
          outDir,
          leafSz, leafSz * 0.40,
          const Color(0xFF2E7D32),
          veinColor: const Color(0xFF1B5E20),
          droop: 0.05 + rng.nextDouble() * 0.07,
        );
      }
    }

    // Buds (g 0.30-0.65)
    if (g >= 0.30 && g < 0.65) {
      final budA = sstep(0.30, 0.50, g);
      if (budA > 0.05 && rng.nextDouble() < 0.65) {
        scene.add(SpherePrim(
          pos + dir * 3,
          lp(2, 4, budA),
          const Color(0xFFFFB7C5).withValues(alpha: budA),
          glossy: false,
        ));
      }
    }

    // Blossoms (g >= 0.65) — most important visual
    final rawBloom = sstep(0.65, 0.92, g);
    final bloom    = (rawBloom * sn.blossomBoost.clamp(1.0, 1.3)).clamp(0.0, 1.0);
    if (bloom > 0.08) {
      final clusterCount = 4 + rng.nextInt(3);
      for (int ci = 0; ci < clusterCount; ci++) {
        final clusterOff = pos
            + dir * (3 + rng.nextDouble() * 5)
            + dir.anyPerp.rotateAxis(dir, ci * 2.39996) * (rng.nextDouble() * 6);
        final flowers = 1 + rng.nextInt(3);
        for (int fi = 0; fi < flowers; fi++) {
          final fOff = clusterOff + V3(
            (rng.nextDouble() - 0.5) * 4,
            rng.nextDouble() * 3,
            (rng.nextDouble() - 0.5) * 4,
          );
          _cherryFlower(fOff, bloom);
        }
      }
    }

    // Petal fall (month==4, g >= 0.88)
    if (month == 4 && g >= 0.88) {
      final fallCount = 6 + rng.nextInt(5); // 6-10
      for (int pi = 0; pi < fallCount; pi++) {
        final drift = V3(
          (rng.nextDouble() - 0.5) * 30,
          -(rng.nextDouble() * 25 + 5),
          (rng.nextDouble() - 0.5) * 20,
        );
        final pPos   = pos + drift;
        final pDir   = V3(
          (rng.nextDouble() - 0.5) * 0.8,
          -0.3 - rng.nextDouble() * 0.5,
          (rng.nextDouble() - 0.5) * 0.8,
        ).normalized;
        final pw     = pDir.anyPerp;
        final psz    = lp(5, 10, rng.nextDouble());
        final normal = pDir.cross(pw).normalized;
        scene.add(QuadPrim([
          pPos,
          pPos + pDir * (psz * 0.55) + pw * (psz * 0.38),
          pPos + pDir * psz,
          pPos + pDir * (psz * 0.55) - pw * (psz * 0.38),
        ], normal, const Color(0xCCFFB7C5)));
      }
    }
  }

  void _cherryFlower(V3 center, double bloom) {
    final sz  = lp(5, 13, bloom) * (0.8 + rng.nextDouble() * 0.4);
    final up  = const V3(0, 1, 0);
    final w   = up.anyPerp.rotateAxis(up, rng.nextDouble() * math.pi * 2);

    // 5 petals — wider than apple blossom
    for (int i = 0; i < 5; i++) {
      final ang  = i * 2 * math.pi / 5 + rng.nextDouble() * 0.18;
      final pDir = w.rotateAxis(up, ang);
      final pw   = pDir.anyPerp;
      final tip  = center + pDir * sz;
      final pCol = Color.lerp(
        const Color(0xFFFFB7C5),
        const Color(0xFFFFF0F5),
        i / 5.0,
      )!;
      scene.add(QuadPrim([
        center,
        center + pDir * (sz * 0.58) + pw * (sz * 0.50),
        tip,
        center + pDir * (sz * 0.58) - pw * (sz * 0.50),
      ], up, pCol));
    }

    // 5 stamen tips
    for (int si = 0; si < 5; si++) {
      final sa  = si * 2 * math.pi / 5 + math.pi / 5;
      final sd  = w.rotateAxis(up, sa);
      scene.add(SpherePrim(
        center + sd * (sz * 0.25) + up * (sz * 0.15),
        1.0,
        const Color(0xFFFFD600),
        glossy: false,
      ));
    }

    // Golden center sphere
    scene.add(SpherePrim(
      center + up * (sz * 0.10),
      sz * 0.30,
      const Color(0xFFFFE082),
      glossy: false,
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. 라벤더 (Lavender)
// ═══════════════════════════════════════════════════════════════════════════

void buildLavender(Scene scene, double g, int seed) {
  final rng  = math.Random(seed);
  final grow = sstep(0.0, 0.90, g);

  // ── Base rosette leaves ───────────────────────────────────────────────
  final rosetteCount = 14 + rng.nextInt(7); // 14-20
  for (int i = 0; i < rosetteCount; i++) {
    final phi = i * 2.39996;
    final h   = V3(math.cos(phi), 0, math.sin(phi));
    final dir = (h + const V3(0, 0.15, 0)).normalized;
    final len = lp(20, 50, grow) * (0.7 + rng.nextDouble() * 0.4);
    final col = Color.lerp(
      const Color(0xFF78909C),
      const Color(0xFF9CCC65),
      rng.nextDouble() * 0.5,
    )!;
    _leafQuad(
      scene,
      const V3(0, 2, 0),
      dir,
      len, len * 0.12,
      col,
      veinColor: const Color(0xFF546E7A),
      droop: 0.04 + rng.nextDouble() * 0.06,
    );
  }

  if (g < 0.40) return;

  // ── Flower stems (g >= 0.40) ──────────────────────────────────────────
  final spikeGrow = sstep(0.40, 0.95, g);
  final stemCount = 5 + rng.nextInt(5); // 5-9

  for (int si = 0; si < stemCount; si++) {
    // Fan spread of stems in x
    final xFrac = stemCount > 1 ? si / (stemCount - 1.0) : 0.5;
    final xPos  = (xFrac - 0.5) * lp(0, 28, xFrac);
    final zOff  = (rng.nextDouble() - 0.5) * 12;
    final base  = V3(xPos, 2, zOff);
    final stemH = lp(25, 160, spikeGrow) * (0.8 + rng.nextDouble() * 0.2);

    final sideOff = V3(
      (rng.nextDouble() - 0.5) * 0.12,
      0,
      (rng.nextDouble() - 0.5) * 0.12,
    );
    final stemDir  = (const V3(0, 1, 0) + sideOff).normalized;
    final stemTop  = base + stemDir * stemH;
    final stemPerp = stemDir.anyPerp;

    scene.add(BranchPrim(base, stemTop, 1.8, 1.0, const Color(0xFF558B2F)));

    // Spike leaves along lower 60% of stem (4-6 pairs)
    final spikeLeavesCount = 4 + rng.nextInt(3);
    for (int sli = 0; sli < spikeLeavesCount; sli++) {
      final frac  = (sli + 1) / (spikeLeavesCount + 1.0);
      final sNode = base + stemDir * (stemH * frac * 0.60);
      final slLen = lp(6, 12, 1 - frac);
      for (final sign in [-1.0, 1.0]) {
        final slDir = (stemPerp * sign + stemDir * 0.15).normalized;
        _leafQuad(
          scene, sNode, slDir,
          slLen, slLen * 0.12,
          const Color(0xFF78909C),
          droop: 0.02,
        );
      }
    }

    if (g < 0.58) continue;

    // ── Flower spike (꽃이삭) — top 38% of stem ─────────────────────────
    final spikeStartY = base + stemDir * (stemH * 0.62);
    final spikeLen    = stemH * 0.38;
    final whorlCount  = 14 + rng.nextInt(5); // 14-18

    for (int wi = 0; wi < whorlCount; wi++) {
      final wt    = wi / (whorlCount - 1.0);
      final wPos  = spikeStartY + stemDir * (spikeLen * wt);
      final wCol  = Color.lerp(
        const Color(0xFF9C27B0),
        const Color(0xFFCE93D8),
        wt,
      )!;
      final bloomAlpha = sstep(0.58, 0.80, g);
      final wColA = wCol.withValues(alpha: bloomAlpha);

      // 4 tiny petals in cross arrangement
      for (int pi = 0; pi < 4; pi++) {
        final pa    = pi * math.pi / 2 + rng.nextDouble() * 0.15;
        final pDir  = stemPerp.rotateAxis(stemDir, pa);
        final pw    = pDir.anyPerp;
        final psz   = lp(3, 6, sstep(0.58, 0.90, g));
        if (psz < 0.5) continue;
        final pTip  = wPos + pDir * psz + stemDir * (psz * 0.20);
        final n2    = pDir.cross(stemDir).normalized;

        scene.add(QuadPrim([
          wPos,
          wPos + pDir * (psz * 0.55) + pw * (psz * 0.32),
          pTip,
          wPos + pDir * (psz * 0.55) - pw * (psz * 0.32),
        ], n2, wColA));

        // Calyx (꽃받침): tiny gray quad behind each petal cluster
        final calyxN = (n2 * -0.3 + stemDir * 0.7).normalized;
        scene.add(QuadPrim([
          wPos - stemDir * 0.8,
          wPos + pDir * (psz * 0.35) + pw * (psz * 0.20) - stemDir * 0.4,
          wPos + pDir * (psz * 0.35) - stemDir * 1.2,
          wPos + pDir * (psz * 0.35) - pw * (psz * 0.20) - stemDir * 0.4,
        ], calyxN, const Color(0xAA78909C)));
      }

      // White interior shimmer (g >= 0.92)
      if (g >= 0.92) {
        scene.add(SpherePrim(
          wPos,
          1.5,
          const Color(0xAAFFFFFF),
          glossy: false,
        ));
      }
    }
  }
}
