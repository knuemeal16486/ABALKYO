import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 사과나무 — 3D L-system
//   · 굵은 줄기 + 재귀 분기 + 잎차례(황금각) 3D 배열
//   · 각 가지/잎의 tBirth로 끊김 없는 연속 성장
//   · 한국 계절(월) 반영: 잎색·개화·결실·낙엽
// ═══════════════════════════════════════════════════════════════════════════

class _Season {
  final double leaf, blossom, fruit;
  final Color leafColor;
  const _Season(this.leaf, this.blossom, this.fruit, this.leafColor);

  static _Season of(int m) => switch (m) {
        1 || 2 || 12 => const _Season(0.0, 0.0, 0.0, Color(0xFF8D6E63)),
        3 => const _Season(0.30, 0.0, 0.0, Color(0xFF81C784)),
        4 => const _Season(0.75, 1.0, 0.0, Color(0xFF66BB6A)),
        5 => const _Season(0.95, 0.35, 0.12, Color(0xFF43A047)),
        6 => const _Season(1.0, 0.0, 0.35, Color(0xFF388E3C)),
        7 || 8 => const _Season(1.0, 0.0, 0.65, Color(0xFF2E7D32)),
        9 => const _Season(0.90, 0.0, 0.90, Color(0xFF558B2F)),
        10 => const _Season(0.55, 0.0, 1.0, Color(0xFFE65100)),
        11 => const _Season(0.20, 0.0, 0.30, Color(0xFFBF360C)),
        _ => const _Season(0.70, 0.0, 0.0, Color(0xFF43A047)),
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
    // 더 굵고 키 큰 줄기 (radius 24, length 260)
    _grow(const V3(0, 2, 0), const V3(0, 1, 0), 260, 24, 0, 0.0);
  }

  // 따뜻한 적갈색 나무껍질 — 깊은 부분일수록 더 어두운 갈색
  Color _bark(int d) => Color.lerp(
      const Color(0xFF5C3317), const Color(0xFF9B6340),
      (d / maxDepth).clamp(0, 1))!;

  Color _leafTint() {
    final t = (rng.nextDouble() - 0.5) * 0.22;
    return Color.lerp(
        sn.leafColor,
        t < 0 ? const Color(0xFF1B5E20) : const Color(0xFFA5D6A7),
        t.abs())!;
  }

  void _grow(V3 pos, V3 dir, double len, double rad, int depth, double tBirth) {
    final local = sstep(tBirth, tBirth + 0.22, g);
    if (local < 0.01) return;
    final segLen = len * local;
    if (segLen < 1.0) return;
    final end = pos + dir * segLen;
    final endRad = rad * 0.68;
    scene.add(BranchPrim(pos, end, rad, endRad, _bark(depth)));

    // 가지 중간 잎
    if (depth >= 2 && len > 50 && sn.leaf > 0) {
      final outDir =
          dir.rotateAxis(dir.anyPerp, 1.0 + rng.nextDouble() * 0.5);
      _addLeaf(
        pos + dir * (segLen * 0.55),
        outDir.normalized,
        lp(12, 20, sn.leaf),
        tBirth + 0.15,
      );
    }

    if (depth >= maxDepth || len < 22) {
      _terminal(end, dir, depth, tBirth + 0.11);
      return;
    }

    final side = dir.anyPerp;
    final childBirth = tBirth + 0.12;
    final n = depth == 0 ? 3 : (rng.nextDouble() < 0.35 ? 3 : 2);
    final phi0 = rng.nextDouble() * math.pi * 2;
    for (int i = 0; i < n; i++) {
      final ba = lp(0.42, 0.78, rng.nextDouble());
      final phi = phi0 + i * 2.39996 + (rng.nextDouble() - 0.5) * 0.45;
      var cd = dir.rotateAxis(side, ba).rotateAxis(dir, phi).normalized;
      cd = (cd + const V3(0, 0.28, 0)).normalized;
      final cpos = depth == 0
          ? pos + dir * (segLen * lp(0.32, 0.95, i / (n - 0.999)))
          : end;
      _grow(
        cpos,
        cd,
        len * lp(0.58, 0.74, rng.nextDouble()),
        endRad * lp(0.52, 0.76, rng.nextDouble()),
        depth + 1,
        childBirth + i * 0.014,
      );
    }
    // 정아 연장
    if (depth == 0) {
      _grow(end, dir.rotateAxis(side, 0.10).normalized, len * 0.64, endRad,
          1, childBirth);
    }
  }

  void _terminal(V3 pos, V3 dir, int depth, double tBirth) {
    // 잎 다발 — 황금각 잎차례
    if (sn.leaf > 0) {
      final cnt = 3 + rng.nextInt(4);
      for (int i = 0; i < cnt; i++) {
        final phi = i * 2.39996 + rng.nextDouble();
        final outDir = dir
            .rotateAxis(dir.anyPerp, lp(0.48, 1.25, rng.nextDouble()))
            .rotateAxis(dir, phi)
            .normalized;
        _addLeaf(
          pos,
          outDir,
          lp(12, 22, sn.leaf) * (0.75 + rng.nextDouble() * 0.5),
          tBirth + 0.038 * i,
        );
      }
    } else if (g > 0.3) {
      scene.add(SpherePrim(
          pos + dir * 3, 2.8, const Color(0xFF8D6E63), glossy: false));
    }

    // 개화 (봄)
    final fa = sn.blossom > 0.2 ? sstep(0.64, 0.80, g) * sn.blossom : 0.0;
    if (fa > 0.15 && rng.nextDouble() < 0.65) {
      _blossom(pos + dir * 4, fa);
    }
    // 결실
    final ra = sn.fruit > 0.2 ? sstep(0.78, 0.96, g) * sn.fruit : 0.0;
    if (ra > 0.2 && rng.nextDouble() < 0.55) {
      final ripe = sstep(0.85, 1.0, g);
      final col = Color.lerp(
          const Color(0xFF88CC66), const Color(0xFFD32F2F), ripe.clamp(0, 1))!;
      scene.add(SpherePrim(
          pos + dir * lp(2, 7, ra), lp(3, 12, ra), col));
    }
  }

  void _addLeaf(V3 base, V3 outDir, double size, double tBirth) {
    final lg = sstep(tBirth, tBirth + 0.17, g);
    if (lg < 0.03) return;
    final s = size * lg;
    final w = outDir.anyPerp;
    final normal = outDir.cross(w).normalized;
    final tip = base + outDir * s;
    final p1 = base + outDir * (s * 0.44) + w * (s * 0.36);
    final p2 = base + outDir * (s * 0.44) - w * (s * 0.36);
    scene.add(QuadPrim(
      [base, p1, tip, p2],
      normal,
      _leafTint(),
      veinColor: const Color(0xFF1B5E20),
    ));
  }

  // 파스텔 벚꽃 스타일 꽃 — 5장 꽃잎 + 황금 꽃술
  void _blossom(V3 center, double a) {
    final w = const V3(0, 1, 0).anyPerp;
    final n2 = const V3(0, 1, 0);
    final sz = lp(5, 13, a);
    for (int i = 0; i < 5; i++) {
      final ang = i * 2 * math.pi / 5 + rng.nextDouble() * 0.3;
      final d = w.rotateAxis(n2, ang);
      final pw = d.anyPerp;
      final tip = center + d * sz;
      final petalCol = Color.lerp(
          const Color(0xFFFFB3C8),
          const Color(0xFFFFF0F5),
          i / 5.0)!;
      scene.add(QuadPrim([
        center,
        center + d * (sz * 0.52) + pw * (sz * 0.34),
        tip,
        center + d * (sz * 0.52) - pw * (sz * 0.34),
      ], n2, petalCol));
    }
    scene.add(SpherePrim(
        center, sz * 0.40, const Color(0xFFFFE066), glossy: true));
  }
}
