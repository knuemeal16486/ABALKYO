import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 사과나무 — 3D L-system
//   · 재귀 분기 + 잎차례(황금각) 3D 배열, 시드별 개체 변이
//   · 각 가지/잎의 tBirth로 끊김 없는 연속 성장(씨앗→가지→잎→꽃→열매)
//   · 한국 계절(월) 반영: 잎색·개화·결실·낙엽
// ═══════════════════════════════════════════════════════════════════════════

class _Season {
  final double leaf, blossom, fruit; // 0~1
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
  static const int maxDepth = 4;

  _AppleBuilder(this.scene, this.g, this.sn, this.rng);

  void build() {
    _grow(const V3(0, 2, 0), const V3(0, 1, 0), 226, 15, 0, 0.0);
  }

  // My Oasis 스타일 — 따뜻한 나무껍질 톤
  Color _bark(int d) => Color.lerp(
      const Color(0xFF7B5544), const Color(0xFFA07855), (d / maxDepth).clamp(0, 1))!;

  Color _leafTint() {
    final t = (rng.nextDouble() - 0.5) * 0.20;
    return Color.lerp(sn.leafColor,
        t < 0 ? const Color(0xFF2E7D52) : const Color(0xFFB5EAB5), t.abs())!;
  }

  void _grow(V3 pos, V3 dir, double len, double rad, int depth, double tBirth) {
    final local = sstep(tBirth, tBirth + 0.24, g);
    if (local < 0.01) return;
    final segLen = len * local;
    if (segLen < 1.2) return;
    final end = pos + dir * segLen;
    final endRad = rad * 0.72;
    scene.add(BranchPrim(pos, end, rad, endRad, _bark(depth)));

    // 가지 중간 잎 (긴 가지)
    if (depth >= 2 && len > 48 && sn.leaf > 0) {
      final outDir = dir.rotateAxis(dir.anyPerp, 1.0 + rng.nextDouble() * 0.4);
      _addLeaf(pos + dir * (segLen * 0.55), outDir.normalized,
          lp(10, 16, sn.leaf), tBirth + 0.16);
    }

    if (depth >= maxDepth || len < 24) {
      _terminal(end, dir, depth, tBirth + 0.12);
      return;
    }

    final side = dir.anyPerp;
    final childBirth = tBirth + 0.13;
    final n = depth == 0 ? 3 : (rng.nextDouble() < 0.3 ? 3 : 2);
    final phi0 = rng.nextDouble() * math.pi * 2;
    for (int i = 0; i < n; i++) {
      final ba = lp(0.45, 0.82, rng.nextDouble()); // 부모와의 분기각
      final phi = phi0 + i * 2.39996 + (rng.nextDouble() - 0.5) * 0.5;
      var cd = dir.rotateAxis(side, ba).rotateAxis(dir, phi).normalized;
      // 위로 살짝 향성(굴광성)
      cd = (cd + const V3(0, 0.25, 0)).normalized;
      // 줄기(depth0)에선 가지를 줄기 따라 분산 배치
      final cpos = depth == 0
          ? pos + dir * (segLen * lp(0.35, 0.96, i / (n - 0.999)))
          : end;
      _grow(cpos, cd, len * lp(0.6, 0.76, rng.nextDouble()),
          endRad * lp(0.55, 0.78, rng.nextDouble()), depth + 1,
          childBirth + i * 0.015);
    }
    // 정아(중심 줄기 연장)
    if (depth == 0) {
      _grow(end, dir.rotateAxis(side, 0.1).normalized, len * 0.66, endRad,
          1, childBirth);
    }
  }

  void _terminal(V3 pos, V3 dir, int depth, double tBirth) {
    // 잎 다발 (잎차례)
    if (sn.leaf > 0) {
      final cnt = (3 + rng.nextInt(3));
      for (int i = 0; i < cnt; i++) {
        final phi = i * 2.39996 + rng.nextDouble();
        final outDir = dir
            .rotateAxis(dir.anyPerp, lp(0.5, 1.2, rng.nextDouble()))
            .rotateAxis(dir, phi)
            .normalized;
        _addLeaf(pos, outDir, lp(11, 18, sn.leaf) * (0.8 + rng.nextDouble() * 0.4),
            tBirth + 0.04 * i);
      }
    } else if (g > 0.3) {
      // 겨울 휴면아
      scene.add(SpherePrim(pos + dir * 3, 2.4,
          const Color(0xFF8D6E63), glossy: false));
    }

    // 개화 (봄)
    final fa = sn.blossom > 0.2 ? sstep(0.66, 0.8, g) * sn.blossom : 0.0;
    if (fa > 0.15 && rng.nextDouble() < 0.6) {
      _blossom(pos + dir * 4, fa);
    }
    // 결실 — My Oasis 스타일 루비레드 사과 (더 통통하고 윤기나게)
    final ra = sn.fruit > 0.2 ? sstep(0.8, 0.96, g) * sn.fruit : 0.0;
    if (ra > 0.2 && rng.nextDouble() < 0.5) {
      final ripe = sstep(0.86, 1.0, g);
      final col = Color.lerp(const Color(0xFF88CC66), const Color(0xFFE53935),
          ripe.clamp(0.0, 1.0))!;
      scene.add(SpherePrim(pos + dir * lp(2, 6, ra), lp(2.5, 10, ra), col));
    }
  }

  void _addLeaf(V3 base, V3 outDir, double size, double tBirth) {
    final lg = sstep(tBirth, tBirth + 0.18, g);
    if (lg < 0.03) return;
    final s = size * lg;
    final w = outDir.anyPerp;
    final normal = outDir.cross(w).normalized;
    final tip = base + outDir * s;
    final p1 = base + outDir * (s * 0.42) + w * (s * 0.34);
    final p2 = base + outDir * (s * 0.42) - w * (s * 0.34);
    scene.add(QuadPrim([base, p1, tip, p2], normal, _leafTint(),
        veinColor: const Color(0xFF2E7D32)));
  }

  // 어비스리움/My Oasis 스타일 꽃 — 파스텔 핑크 꽃잎 + 황금 꽃술
  void _blossom(V3 center, double a) {
    final w = const V3(0, 1, 0).anyPerp;
    final n2 = const V3(0, 1, 0);
    final sz = lp(4, 10, a);
    for (int i = 0; i < 5; i++) {
      final ang = i * 2 * math.pi / 5;
      final d = w.rotateAxis(n2, ang);
      final pw = d.anyPerp;
      final tip = center + d * sz;
      // 꽃잎: 바깥쪽으로 갈수록 더 밝아지는 핑크
      scene.add(QuadPrim([
        center,
        center + d * (sz * 0.5) + pw * (sz * 0.32),
        tip,
        center + d * (sz * 0.5) - pw * (sz * 0.32),
      ], n2, const Color(0xFFFFC8DB)));
    }
    // 꽃술 중앙 — 황금 글로우
    scene.add(SpherePrim(center, sz * 0.38, const Color(0xFFFFE040),
        glossy: true));
  }
}
