import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 사과나무 — 완전한 생육 주기
//   씨앗 → 가지 → 잎 → 꽃눈 → 개화 → 낙화(꽃잎 떨어짐) → 유과 → 성숙 → 완숙
// ═══════════════════════════════════════════════════════════════════════════

class _Season {
  final double leaf, blossom, fruit;
  final Color leafColor;
  const _Season(this.leaf, this.blossom, this.fruit, this.leafColor);

  static _Season of(int m) => switch (m) {
        1 || 2    => const _Season(0.0, 0.0,  0.0,  Color(0xFF8D6E63)),
        3         => const _Season(0.30, 0.22, 0.0,  Color(0xFF81C784)), // 꽃눈 팽창
        4         => const _Season(0.75, 1.0,  0.0,  Color(0xFF66BB6A)), // 만개
        5         => const _Season(0.95, 0.30, 0.10, Color(0xFF43A047)), // 낙화·유과
        6         => const _Season(1.0,  0.0,  0.38, Color(0xFF388E3C)), // 유과 성장
        7 || 8    => const _Season(1.0,  0.0,  0.68, Color(0xFF2E7D32)), // 성숙
        9         => const _Season(0.90, 0.0,  0.92, Color(0xFF558B2F)), // 착색 시작
        10        => const _Season(0.55, 0.0,  1.0,  Color(0xFFE65100)), // 완숙·수확
        11        => const _Season(0.18, 0.0,  0.24, Color(0xFFBF360C)),
        12        => const _Season(0.0,  0.0,  0.0,  Color(0xFF8D6E63)),
        _         => const _Season(0.70, 0.0,  0.0,  Color(0xFF43A047)),
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

  Color _bark(int d) => Color.lerp(
      const Color(0xFF5D4037), const Color(0xFF8D6E63),
      (d / maxDepth).clamp(0, 1))!;

  Color _leafTint() {
    final t = (rng.nextDouble() - 0.5) * 0.18;
    return Color.lerp(sn.leafColor,
        t < 0 ? const Color(0xFF1B5E20) : const Color(0xFFC5E1A5), t.abs())!;
  }

  // ── 가지 성장 ──────────────────────────────────────────────────────────────
  void _grow(V3 pos, V3 dir, double len, double rad, int depth, double tBirth) {
    final local = sstep(tBirth, tBirth + 0.24, g);
    if (local < 0.01) return;
    final segLen = len * local;
    if (segLen < 1.2) return;
    final end = pos + dir * segLen;
    final endRad = rad * 0.72;
    scene.add(BranchPrim(pos, end, rad, endRad, _bark(depth)));

    if (depth >= 1 && sn.leaf > 0 && segLen > 18) {
      final leafCount = (depth >= 3 || len < 55) ? 2 : 3;
      for (int li = 0; li < leafCount; li++) {
        final frac = 0.22 + li * (0.55 / math.max(leafCount - 0.999, 1));
        final lPhi = rng.nextDouble() * math.pi * 2 + li * 2.094;
        final outDir = dir
            .rotateAxis(dir.anyPerp, 0.82 + rng.nextDouble() * 0.58)
            .rotateAxis(dir, lPhi)
            .normalized;
        _addLeaf(pos + dir * (segLen * frac), outDir,
            lp(11, 19, sn.leaf), tBirth + 0.13 + li * 0.022);
      }
    }

    if (depth >= maxDepth || len < 24) {
      _terminal(end, dir, depth, tBirth + 0.12);
      return;
    }

    final side = dir.anyPerp;
    final childBirth = tBirth + 0.13;
    // 줄기(depth=0): 5개 분기, 나머지: 3개(50%) / 2개(50%) → 평균 2.5
    final n = depth == 0 ? 5 : (rng.nextDouble() < 0.5 ? 3 : 2);
    final phi0 = rng.nextDouble() * math.pi * 2;
    for (int i = 0; i < n; i++) {
      final ba = lp(0.42, 0.78, rng.nextDouble());
      final phi = phi0 + i * 2.39996 + (rng.nextDouble() - 0.5) * 0.5;
      var cd = dir.rotateAxis(side, ba).rotateAxis(dir, phi).normalized;
      final gravity = (len * len) * 0.00002 * (depth + 1);
      cd = (cd + const V3(0, 0.25, 0) - V3(0, gravity, 0)).normalized;
      final cpos = depth == 0
          ? pos + dir * (segLen * lp(0.28, 0.96, i / (n - 0.999)))
          : end;
      _grow(cpos, cd, len * lp(0.58, 0.74, rng.nextDouble()),
          endRad * lp(0.52, 0.76, rng.nextDouble()), depth + 1,
          childBirth + i * 0.012);
    }
    if (depth == 0) {
      _grow(end, dir.rotateAxis(side, 0.08).normalized, len * 0.62, endRad,
          1, childBirth);
    }
  }

  // ── 끝마디 ────────────────────────────────────────────────────────────────
  void _terminal(V3 pos, V3 dir, int depth, double tBirth) {
    // 잎 다발
    if (sn.leaf > 0) {
      final cnt = 6 + rng.nextInt(6);
      for (int i = 0; i < cnt; i++) {
        final phi = i * 2.39996 + rng.nextDouble() * 0.6;
        final outDir = dir
            .rotateAxis(dir.anyPerp, lp(0.45, 1.25, rng.nextDouble()))
            .rotateAxis(dir, phi)
            .normalized;
        _addLeaf(pos, outDir,
            lp(13, 23, sn.leaf) * (0.75 + rng.nextDouble() * 0.5),
            tBirth + 0.035 * i);
      }
    } else if (g > 0.3) {
      // 겨울 휴면아
      scene.add(SpherePrim(pos + dir * 2.8, 2.4,
          const Color(0xFF6D4C41), glossy: false));
    }

    // 꽃/열매 — 성목 이후(g > 0.64) 계절에 맞게 표시
    final bloomG = sstep(0.50, 0.68, g);
    final fruitG = sstep(0.62, 0.82, g);
    final flAmt = sn.blossom * bloomG;
    final frAmt = sn.fruit * fruitG;

    if (flAmt > 0.04 && rng.nextDouble() < 0.82) {
      _flowerCluster(pos, dir, flAmt);
    } else if (frAmt > 0.04 && rng.nextDouble() < 0.78) {
      _fruitCluster(pos, dir, frAmt);
    }
  }

  void _addLeaf(V3 base, V3 outDir, double size, double tBirth) {
    final lg = sstep(tBirth, tBirth + 0.18, g);
    if (lg < 0.03) return;
    final s = size * lg;
    final w = outDir.anyPerp;
    final normal = outDir.cross(w).normalized;
    final tip = base + outDir * s;
    scene.add(LeafPrim(base, tip, normal, s * 0.65, _leafTint(),
        veinColor: const Color(0xFF2E7D32), shininess: 8.0, specIntensity: 0.15));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 꽃 시스템
  // ══════════════════════════════════════════════════════════════════════════

  void _flowerCluster(V3 pos, V3 dir, double flAmt) {
    // 잎 클러스터 바깥에 배치: 잎이 10~23 유닛이므로 꽃은 dir 방향으로 더 멀리
    final cnt = flAmt < 0.3 ? 1
        : flAmt < 0.65 ? (2 + rng.nextInt(2))
        : (3 + rng.nextInt(3));
    final up = dir.anyPerp;

    for (int fi = 0; fi < cnt; fi++) {
      final phi = fi * 2.094 + rng.nextDouble() * 0.4;
      final offset = up.rotateAxis(dir, phi);
      final stalkLen = lp(3.0, 7.0, flAmt);
      // dir 방향으로 10~16 유닛 → 잎 바깥에 꽃 배치
      final flCenter = pos + dir * lp(10, 16, flAmt)
          + offset * stalkLen
          + dir * (fi * 2.5);
      final flFacing = (offset * 0.55 + dir * 0.70).normalized;
      _singleFlower(flCenter, flFacing, flAmt);
    }

    // 낙화 — sn.blossom 0.05~0.54 구간: 꽃잎이 흩날리는 중
    if (sn.blossom > 0.05 && sn.blossom < 0.55) {
      final fallFrac = 1.0 - (sn.blossom - 0.05) / 0.49;
      _fallingPetals(pos, dir, up, fallFrac);
    }
  }

  void _singleFlower(V3 center, V3 facing, double flAmt) {
    final u = facing.anyPerp;
    final v = facing.cross(u).normalized;

    // 꽃눈(tight) → 만개(open)
    final openAngle = lp(0.08, math.pi * 0.50, flAmt.clamp(0.0, 1.0));
    final petalLen = lp(6.0, 16.0, flAmt.clamp(0.0, 1.0));

    // 낙화 단계에서는 꽃잎 수 감소 (3~5장)
    final petalCount = sn.blossom >= 0.55 ? 5 : (2 + rng.nextInt(4)).clamp(2, 5);

    // 꽃봉오리(진분홍) → 반개(분홍) → 만개(흰분홍)
    final petalColor = Color.lerp(
      const Color(0xFFE91E8C),
      const Color(0xFFFFF0F8),
      flAmt.clamp(0.0, 1.0),
    )!;

    for (int i = 0; i < petalCount; i++) {
      final ang = i * 2 * math.pi / 5;
      final d = (u * math.cos(ang) + v * math.sin(ang)).normalized;
      final tipDir = (d + facing * openAngle).normalized;
      final pw = d.cross(facing).normalized;
      final tip = center + tipDir * petalLen;
      scene.add(QuadPrim([
        center,
        center + tipDir * (petalLen * 0.46) + pw * (petalLen * 0.30),
        tip,
        center + tipDir * (petalLen * 0.46) - pw * (petalLen * 0.30),
      ], facing, petalColor));
    }

    // 수술 (황금색)
    scene.add(SpherePrim(
        center + facing * (petalLen * 0.20),
        petalLen * 0.28,
        const Color(0xFFFFD740),
        glossy: false));

    // 꽃받침 (꽃눈 ~ 반개 단계에서만 뚜렷)
    if (flAmt < 0.55) {
      scene.add(SpherePrim(
          center - facing * (petalLen * 0.32),
          lp(1.4, 2.2, 1.0 - flAmt),
          const Color(0xFF558B2F),
          glossy: false));
    }
  }

  // 흩날리는 꽃잎 — 낙화 연출
  void _fallingPetals(V3 pos, V3 dir, V3 up, double fallFrac) {
    final cnt = (fallFrac * 5).round().clamp(1, 5);
    for (int pi = 0; pi < cnt; pi++) {
      final phi = rng.nextDouble() * math.pi * 2;
      final pOffset = up.rotateAxis(dir, phi);
      final fallPos = pos
          + pOffset * lp(2.0, 8.0, rng.nextDouble())
          + V3(0, -lp(0.5, 5.0, rng.nextDouble()), 0);
      final pDir = (pOffset + const V3(0, 0.12, 0)).normalized;
      final pw = pDir.anyPerp;
      const psz = 3.0;
      // alpha 0xCC = 80% 불투명 — 반투명 꽃잎
      scene.add(QuadPrim([
        fallPos,
        fallPos + pDir * (psz * 0.5) + pw * (psz * 0.26),
        fallPos + pDir * psz,
        fallPos + pDir * (psz * 0.5) - pw * (psz * 0.26),
      ], pDir, const Color(0xCCFFB7C5)));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 열매 시스템
  // ══════════════════════════════════════════════════════════════════════════

  void _fruitCluster(V3 pos, V3 dir, double frAmt) {
    // frAmt: 0.06=유과, 0.35=소과, 0.68=성숙, 1.0=완숙
    // 생물학적 자연낙과 반영: 유과 단계엔 여러 개, 이후 1~2개
    final cnt = frAmt < 0.35 ? (1 + rng.nextInt(3)) : (1 + rng.nextInt(2));
    final up = dir.anyPerp;

    for (int fi = 0; fi < cnt; fi++) {
      final phi = fi * 2.094 + rng.nextDouble() * 0.5;
      final offsetDir = up.rotateAxis(dir, phi);
      // 중력으로 아래 방향 처짐
      final hangDir = (offsetDir * 0.58 + V3(0, -0.82, 0)).normalized;
      // 잎 클러스터 바깥에 열매 배치
      final clusterBase = pos + dir * lp(8.0, 14.0, frAmt);
      final stemLen = lp(3.5, 9.0, frAmt);
      final applePos = clusterBase + hangDir * stemLen;
      final radius = lp(4.0, 14.0, frAmt);   // 최소 4 유닛으로 확실히 보이게

      // 과경 (줄기)
      if (frAmt > 0.06) {
        scene.add(BranchPrim(
          clusterBase,
          applePos + V3(0, radius * 0.75, 0),
          lp(0.4, 1.4, frAmt),
          lp(0.3, 1.0, frAmt),
          const Color(0xFF4E342E),
        ));
      }

      // 사과 본체
      scene.add(SpherePrim(applePos, radius, _appleColor(frAmt)));

      // 꽃받침 흔적 (calyx) — 중간 크기 이상에서 표시
      if (frAmt > 0.28) {
        _appleCalyx(applePos + V3(0, -(radius * 0.84), 0), radius * 0.28);
      }

      // 볼 홍조(blush) — 익을수록 붉은 광택
      if (frAmt > 0.70) {
        final blushT = (frAmt - 0.70) / 0.30;
        final blushCol = Color.lerp(
            const Color(0xFFFF7043), const Color(0xFF9B1B1B), blushT)!;
        scene.add(SpherePrim(
            applePos + offsetDir * (radius * 0.35) + V3(0, radius * 0.22, 0),
            radius * 0.60,
            blushCol));
      }
    }
  }

  // 유과(연두) → 소과(녹색) → 성숙(황록) → 착색(주홍) → 완숙(진홍)
  Color _appleColor(double frAmt) {
    if (frAmt < 0.12) return const Color(0xFFDCEDC8); // 유과: 연두
    if (frAmt < 0.34) return const Color(0xFF81C784); // 소과: 녹색
    if (frAmt < 0.58) return const Color(0xFF43A047); // 성장: 진녹
    if (frAmt < 0.72) {
      return Color.lerp(const Color(0xFF43A047), const Color(0xFFCDDC39),
          (frAmt - 0.58) / 0.14)!;  // 녹→황록
    }
    if (frAmt < 0.86) {
      return Color.lerp(const Color(0xFFCDDC39), const Color(0xFFFF5722),
          (frAmt - 0.72) / 0.14)!;  // 황록→주홍
    }
    return Color.lerp(const Color(0xFFFF5722), const Color(0xFFC62828),
        (frAmt - 0.86) / 0.14)!;    // 주홍→진홍
  }

  // 사과 하단 꽃받침 흔적 (갈색 5갈래)
  void _appleCalyx(V3 base, double sz) {
    const calyxColor = Color(0xFF4E342E);
    final u = const V3(1, 0, 0);
    for (int i = 0; i < 5; i++) {
      final ang = i * 2 * math.pi / 5;
      final d = (u * math.cos(ang) + const V3(0, 0, 1) * math.sin(ang)).normalized;
      final tip = base + d * sz;
      final w = d.cross(const V3(0, -1, 0)).normalized;
      scene.add(QuadPrim([
        base,
        base + d * (sz * 0.5) + w * (sz * 0.20),
        tip,
        base + d * (sz * 0.5) - w * (sz * 0.20),
      ], const V3(0, -1, 0), calyxColor));
    }
  }
}
