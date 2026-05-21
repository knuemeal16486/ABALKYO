import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 사과나무 — 자연스러운 3D 나무
//   · 줄기/주 가지: 3개 서브세그먼트로 자연스러운 굴곡
//   · 분기점: 관절 혹(SpherePrim) — 실제 나무의 마디
//   · 잎: 비대칭 + 중력 처짐 + 다양한 크기
//   · 수피 질감은 엔진(BranchPrim)이 자동 처리
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

  // 깊이별 수피 색 — 두꺼운 줄기일수록 짙은 적갈색
  Color _bark(int d) => Color.lerp(
      const Color(0xFF4A2810), const Color(0xFF8B5A30),
      (d / maxDepth).clamp(0, 1))!;

  // 잎 색 — 계절·개체 변이
  Color _leafTint() {
    final t = (rng.nextDouble() - 0.5) * 0.24;
    return Color.lerp(
        sn.leafColor,
        t < 0 ? const Color(0xFF1A5E20) : const Color(0xFFA5D6A7),
        t.abs())!;
  }

  // ── 굵은 줄기/가지: 3개 서브세그먼트로 자연 굴곡 ─────────────────────────
  V3 _addCurvedBranch(
      V3 pos, V3 dir, double len, double rad, int depth, double tBirth) {
    const segs = 3;
    V3 p = pos;
    V3 d = dir;
    final sl = len / segs;

    for (int i = 0; i < segs; i++) {
      // 각 세그먼트마다 방향 살짝 꺾기 (바람에 휜 나무 느낌)
      final sideAxis = d.anyPerp;
      final wobbleAng = (rng.nextDouble() - 0.5) * 0.20;
      d = (d + sideAxis * wobbleAng).normalized;
      // 약한 굴광성 (위를 향해 자라는 경향)
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
      // 주 줄기와 1차 굵은 가지 → 서브세그먼트로 자연 굴곡
      end = _addCurvedBranch(pos, dir, segLen, rad, depth, tBirth);
    } else {
      // 가는 가지: 단일 세그먼트 + 끝점 미세 흔들기
      final perp = dir.anyPerp;
      final wobble = (rng.nextDouble() - 0.5) * rad * 0.55;
      end = pos + dir * segLen + perp * wobble;
      scene.add(BranchPrim(pos, end, rad, rad * 0.68, _bark(depth)));
    }

    // 관절 혹 — 분기점의 자연스러운 팽창 (두꺼운 가지에만)
    if (depth <= 2 && g > 0.20) {
      scene.add(SpherePrim(
          end, rad * (0.78 + rng.nextDouble() * 0.15), _bark(depth),
          glossy: false));
    }

    // 중간 잎
    if (depth >= 2 && len > 48 && sn.leaf > 0) {
      final outDir =
          dir.rotateAxis(dir.anyPerp, 1.0 + rng.nextDouble() * 0.45);
      _addLeaf(
        pos + dir * (segLen * 0.52),
        outDir.normalized,
        lp(12, 21, sn.leaf),
        tBirth + 0.15,
      );
    }

    if (depth >= maxDepth || len < 20) {
      _terminal(end, dir, depth, tBirth + 0.11);
      return;
    }

    final side = dir.anyPerp;
    final childBirth = tBirth + 0.12;
    final n = depth == 0 ? 3 : (rng.nextDouble() < 0.38 ? 3 : 2);
    final phi0 = rng.nextDouble() * math.pi * 2;
    for (int i = 0; i < n; i++) {
      final ba = lp(0.40, 0.80, rng.nextDouble());
      final phi = phi0 + i * 2.39996 + (rng.nextDouble() - 0.5) * 0.45;
      var cd = dir.rotateAxis(side, ba).rotateAxis(dir, phi).normalized;
      cd = (cd + const V3(0, 0.28, 0)).normalized;
      final cpos = depth == 0
          ? pos + dir * (segLen * lp(0.30, 0.95, i / (n - 0.999)))
          : end;
      _grow(
        cpos, cd,
        len * lp(0.56, 0.72, rng.nextDouble()),
        (rad * (depth == 0 ? 0.58 : 0.62)) *
            lp(0.80, 1.0, rng.nextDouble()),
        depth + 1,
        childBirth + i * 0.014,
      );
    }
    // 정아 연장
    if (depth == 0) {
      _grow(end, dir.rotateAxis(side, 0.10).normalized, len * 0.64, rad * 0.62,
          1, childBirth);
    }
  }

  void _terminal(V3 pos, V3 dir, int depth, double tBirth) {
    // 잎 다발 (황금각 잎차례)
    if (sn.leaf > 0) {
      final cnt = 3 + rng.nextInt(4);
      for (int i = 0; i < cnt; i++) {
        final phi = i * 2.39996 + rng.nextDouble() * 0.5;
        final outDir = dir
            .rotateAxis(dir.anyPerp, lp(0.45, 1.30, rng.nextDouble()))
            .rotateAxis(dir, phi)
            .normalized;
        _addLeaf(
          pos,
          outDir,
          lp(11, 24, sn.leaf) * (0.72 + rng.nextDouble() * 0.56),
          tBirth + 0.036 * i,
        );
      }
    } else if (g > 0.3) {
      scene.add(SpherePrim(
          pos + dir * 3, 2.8, const Color(0xFF8D6E63), glossy: false));
    }

    // 개화 (봄)
    final fa = sn.blossom > 0.2 ? sstep(0.64, 0.80, g) * sn.blossom : 0.0;
    if (fa > 0.15 && rng.nextDouble() < 0.65) _blossom(pos + dir * 4, fa);

    // 결실
    final ra = sn.fruit > 0.2 ? sstep(0.78, 0.96, g) * sn.fruit : 0.0;
    if (ra > 0.2 && rng.nextDouble() < 0.55) {
      final ripe = sstep(0.85, 1.0, g);
      final col = Color.lerp(
          const Color(0xFF88CC66), const Color(0xFFD32F2F), ripe.clamp(0, 1))!;
      scene.add(SpherePrim(pos + dir * lp(2, 7, ra), lp(3, 12, ra), col));
    }
  }

  /// 비대칭 + 중력 처짐 잎
  void _addLeaf(V3 base, V3 outDir, double size, double tBirth) {
    final lg = sstep(tBirth, tBirth + 0.17, g);
    if (lg < 0.03) return;
    final s = size * lg;

    // 비대칭: 잎의 한쪽이 약간 더 넓음
    final asymm = (rng.nextDouble() - 0.5) * 0.22;
    final w = outDir.anyPerp;

    // 중력 처짐: 잎끝이 살짝 아래로 향함
    final droop = (rng.nextDouble() * 0.10 + 0.04);
    final tip = base + outDir * s + V3(0, -droop * s, 0);

    final normal = outDir.cross(w).normalized;
    final p1 = base + outDir * (s * (0.42 + asymm * 0.08)) +
        w * (s * (0.35 + asymm));
    final p2 = base + outDir * (s * (0.44 - asymm * 0.08)) -
        w * (s * (0.32 - asymm));

    scene.add(QuadPrim(
      [base, p1, tip, p2],
      normal,
      _leafTint(),
      veinColor: const Color(0xFF1A5E20),
    ));
  }

  // 벚꽃 스타일 꽃 (5장 꽃잎 + 황금 꽃술)
  void _blossom(V3 center, double a) {
    final w = const V3(0, 1, 0).anyPerp;
    final n2 = const V3(0, 1, 0);
    final sz = lp(5, 13, a);
    for (int i = 0; i < 5; i++) {
      final ang = i * 2 * math.pi / 5 + rng.nextDouble() * 0.28;
      final d = w.rotateAxis(n2, ang);
      final pw = d.anyPerp;
      final tip = center + d * sz;
      final petalCol = Color.lerp(
          const Color(0xFFFFB3C8), const Color(0xFFFFF0F5), i / 5.0)!;
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
