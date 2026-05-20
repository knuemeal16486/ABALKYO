import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 해바라기 · 다육식물 · 고사리 — 3D 생성기 (연속 성장 + 시드 개체 변이)
// ═══════════════════════════════════════════════════════════════════════════

void _leafQuad(Scene scene, V3 base, V3 dir, double len, double width,
    Color color, {Color? tip, double tipFrac = 0.0}) {
  if (len < 1) return;
  final w = dir.anyPerp;
  final normal = dir.cross(w).normalized;
  final tipPt = base + dir * len;
  scene.add(QuadPrim([
    base,
    base + dir * (len * 0.42) + w * (width * 0.5),
    tipPt,
    base + dir * (len * 0.42) - w * (width * 0.5),
  ], normal, color, veinColor: const Color(0x55143A1E)));
  if (tip != null && tipFrac > 0.02) {
    scene.add(QuadPrim([
      base + dir * (len * 0.72),
      base + dir * (len * 0.86) + w * (width * 0.22),
      tipPt,
      base + dir * (len * 0.86) - w * (width * 0.22),
    ], normal, tip.withValues(alpha: tipFrac.clamp(0.0, 1.0))));
  }
}

// ── 해바라기 ─────────────────────────────────────────────────────────────────
void buildSunflower(Scene scene, double g, int seed) {
  final rng = math.Random(seed);
  final grow = sstep(0.0, 0.85, g);
  final stalkH = lp(22, 250, grow);
  const segs = 4;
  final segLen = stalkH / segs;
  final bend = (rng.nextDouble() - 0.5) * 0.14;
  final azBend = rng.nextDouble() * math.pi * 2;
  final bendAxis = V3(math.cos(azBend), 0, math.sin(azBend));

  V3 pos = const V3(0, 2, 0);
  V3 dir = const V3(0, 1, 0);
  final nodes = <V3>[pos];
  final dirs = <V3>[dir];
  for (int i = 0; i < segs; i++) {
    dir = dir.rotateAxis(bendAxis, bend).normalized;
    final end = pos + dir * segLen;
    scene.add(BranchPrim(pos, end, lp(2.2, 9, grow) * (1 - i / segs * 0.35),
        lp(2.0, 8, grow) * (1 - (i + 1) / segs * 0.35), const Color(0xFF558B2F)));
    pos = end;
    nodes.add(pos);
    dirs.add(dir);
  }

  // 잎 (번갈아 + 잎차례)
  if (grow > 0.2) {
    for (int i = 1; i < segs; i++) {
      final phi = i * 2.39996;
      final h = V3(math.cos(phi), 0, math.sin(phi));
      final outDir = (h + const V3(0, 0.35, 0)).normalized;
      final lg = sstep(0.18 + i * 0.05, 0.5 + i * 0.05, g);
      _leafQuad(scene, nodes[i], outDir, lp(20, 60, lg) * (1 - i * 0.12),
          lp(14, 40, lg) * (1 - i * 0.12), const Color(0xFF43A047));
    }
  }

  // 머리 (봉오리 → 만개)
  final headDir = (dir + const V3(0, 0.2, 0.7)).normalized;
  _sunflowerHead(scene, pos, headDir, g, grow);
}

void _sunflowerHead(Scene scene, V3 center, V3 normal, double g, double grow) {
  final bloom = sstep(0.6, 0.9, g);
  if (bloom < 0.05) {
    scene.add(SpherePrim(center, lp(4, 12, grow), const Color(0xFF66BB6A),
        glossy: false));
    return;
  }
  final diskR = lp(8, 24, bloom);
  final petalLen = lp(12, 32, bloom);
  final u = normal.anyPerp;
  final v = normal.cross(u).normalized;
  final seeding = sstep(0.92, 1.0, g);

  // 꽃잎
  for (int i = 0; i < 22; i++) {
    final ang = i * 2 * math.pi / 22;
    final d = (u * math.cos(ang) + v * math.sin(ang)).normalized;
    final t = (u * -math.sin(ang) + v * math.cos(ang)).normalized;
    final baseP = center + d * (diskR * 0.9);
    final tipP = center + d * (diskR + petalLen * (1 - seeding * 0.2));
    scene.add(QuadPrim([
      baseP + t * (petalLen * 0.16),
      tipP,
      baseP - t * (petalLen * 0.16),
    ], normal, const Color(0xFFF9A825)));
  }
  // 씨앗 원반
  const seg = 18;
  final diskColor =
      Color.lerp(const Color(0xFF6D4C41), const Color(0xFF3E2723), seeding)!;
  for (int i = 0; i < seg; i++) {
    final a0 = i / seg * 2 * math.pi;
    final a1 = (i + 1) / seg * 2 * math.pi;
    final p0 = center + (u * math.cos(a0) + v * math.sin(a0)) * diskR;
    final p1 = center + (u * math.cos(a1) + v * math.sin(a1)) * diskR;
    scene.add(QuadPrim([center, p0, p1], normal, diskColor));
  }
  scene.add(SpherePrim(center + normal * 0.5, diskR * 0.45,
      const Color(0xFF4E342E), glossy: false));
}

// ── 다육식물 (로제트) ────────────────────────────────────────────────────────
void buildSucculent(Scene scene, double g, int seed) {
  final rng = math.Random(seed);
  final maxLeaves = lp(6, 42, sstep(0.0, 0.85, g)).round();
  final color = sstep(0.9, 1.0, g); // 끝물 단풍
  final phi0 = rng.nextDouble() * math.pi * 2;
  const baseY = 6.0;
  final center = const V3(0, baseY, 0);

  for (int i = 0; i < maxLeaves; i++) {
    final t = i / 42.0; // 0=바깥(먼저 남), 1=안쪽
    final tBirth = t * 0.82;
    final lg = sstep(tBirth, tBirth + 0.16, g);
    if (lg < 0.03) continue;
    final phi = phi0 + i * 2.39996;
    final elev = lp(0.18, 1.30, t); // 바깥은 눕고 안쪽은 곧추섬
    final h = V3(math.cos(phi), 0, math.sin(phi));
    final dir = (h * math.cos(elev) + const V3(0, 1, 0) * math.sin(elev))
        .normalized;
    final len = lp(46, 14, t) * lg;
    final width = len * 0.5;
    _leafQuad(scene, center + dir * (len * 0.08), dir, len, width,
        Color.lerp(const Color(0xFF66BB6A), const Color(0xFF43A047), t)!,
        tip: const Color(0xFFE57373), tipFrac: color);
  }
  scene.add(SpherePrim(center, lp(3, 7, sstep(0, 0.5, g)),
      Color.lerp(const Color(0xFF43A047), const Color(0xFFE57373), color)!,
      glossy: false));

  // 희귀한 개화
  if (g >= 0.97) {
    final stalkTop = center + const V3(8, 40, 4);
    scene.add(BranchPrim(center, stalkTop, 1.6, 1.0, const Color(0xFFEF9A9A)));
    scene.add(SpherePrim(stalkTop, 4, const Color(0xFFF48FB1)));
  }
}

// ── 고사리 ───────────────────────────────────────────────────────────────────
void buildFern(Scene scene, double g, int seed) {
  final rng = math.Random(seed);
  final grow = sstep(0.18, 1.0, g);
  if (grow < 0.02) {
    scene.add(SpherePrim(const V3(0, 6, 0), lp(2, 5, sstep(0, 0.2, g)),
        const Color(0xFF7CB342), glossy: false));
    return;
  }
  final open = sstep(0.35, 0.82, g);
  final frondLen = lp(50, 230, grow);
  final count = lp(2, 6, grow).round().clamp(2, 6);

  for (int f = 0; f < count; f++) {
    final az = f / count * 2 * math.pi + rng.nextDouble() * 0.4;
    final right = V3(math.cos(az), 0, math.sin(az));
    final planeN = right.cross(const V3(0, 1, 0)).normalized;
    final lenJ = frondLen * (0.85 + rng.nextDouble() * 0.3);
    _frond(scene, right, planeN, lenJ, open, g, rng);
  }
}

void _frond(Scene scene, V3 right, V3 planeN, double len, double open,
    double g, math.Random rng) {
  const steps = 13;
  final stepLen = len / steps;
  double ang = 0.22; // 처음 바깥으로 기운 각
  V3 p = const V3(0, 4, 0);
  V3 prev = p;
  final openSteps = (open * steps).floor();

  for (int i = 0; i < steps; i++) {
    final u = i / steps;
    double turn = 0.06;
    double sl = stepLen;
    if (u > open) {
      final cu = (u - open) / (1 - open + 1e-6);
      turn += 0.82 * cu;
      sl *= (1 - 0.5 * cu);
    }
    ang += turn;
    final dirPlane =
        (right * math.sin(ang) + const V3(0, 1, 0) * math.cos(ang)).normalized;
    p = p + dirPlane * sl;
    scene.add(BranchPrim(prev, p, lp(2.4, 1.0, u), lp(2.2, 0.8, u),
        const Color(0xFF33691E)));
    prev = p;

    // 우편(잎조각): 평면 밖으로 양쪽 부채
    if (i >= 1 && i <= openSteps) {
      final pinLen = lp(5, 16, u / (open + 1e-6)) * (1 - u * 0.5) * 1.3;
      if (pinLen > 2) {
        for (final side in const [-1.0, 1.0]) {
          final pdir =
              (planeN * side * 0.85 + dirPlane * 0.45).normalized;
          _leafQuad(scene, p, pdir, pinLen, pinLen * 0.42,
              i.isEven ? const Color(0xFF4CAF50) : const Color(0xFF388E3C));
        }
      }
    }
  }
  // 피들헤드(코일 끝)
  if (open < 0.97) {
    scene.add(SpherePrim(p, lp(3.5, 1.0, open), const Color(0xFF7CB342),
        glossy: false));
  }
}
