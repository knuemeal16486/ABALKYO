import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 해바라기 · 다육식물 · 고사리 — 3D 생성기 (굵은 줄기 + 연속 성장)
// ═══════════════════════════════════════════════════════════════════════════

void _leafQuad(Scene scene, V3 base, V3 dir, double len, double width,
    Color color,
    {Color? tip, double tipFrac = 0.0, Color? veinColor}) {
  if (len < 1) return;
  final w = dir.anyPerp;
  final normal = dir.cross(w).normalized;
  final tipPt = base + dir * len;
  final vc = veinColor ?? const Color(0x55143A1E);
  scene.add(QuadPrim([
    base,
    base + dir * (len * 0.44) + w * (width * 0.5),
    tipPt,
    base + dir * (len * 0.44) - w * (width * 0.5),
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

// ── 해바라기 ─────────────────────────────────────────────────────────────────
void buildSunflower(Scene scene, double g, int seed) {
  final rng = math.Random(seed);
  final grow = sstep(0.0, 0.82, g);
  final stalkH = lp(28, 260, grow);
  const segs = 5;
  final segLen = stalkH / segs;
  final bend = (rng.nextDouble() - 0.5) * 0.12;
  final azBend = rng.nextDouble() * math.pi * 2;
  final bendAxis = V3(math.cos(azBend), 0, math.sin(azBend));

  V3 pos = const V3(0, 2, 0);
  V3 dir = const V3(0, 1, 0);
  final nodes = <V3>[pos];
  final dirs = <V3>[dir];

  for (int i = 0; i < segs; i++) {
    dir = dir.rotateAxis(bendAxis, bend).normalized;
    final end = pos + dir * segLen;
    // 눈에 띄게 굵은 줄기 — 줄기 색 싱그러운 초록
    final r0 = lp(3.2, 14, grow) * (1 - i / segs * 0.36);
    final r1 = lp(3.0, 13, grow) * (1 - (i + 1) / segs * 0.36);
    scene.add(BranchPrim(pos, end, r0, r1, const Color(0xFF4A8E3A)));
    pos = end;
    nodes.add(pos);
    dirs.add(dir);
  }

  // 잎 — 줄기 따라 황금각 배치
  if (grow > 0.18) {
    for (int i = 1; i < segs; i++) {
      final phi = i * 2.39996;
      final h = V3(math.cos(phi), 0, math.sin(phi));
      final outDir = (h + const V3(0, 0.32, 0)).normalized;
      final lg = sstep(0.15 + i * 0.045, 0.45 + i * 0.045, g);
      final ll = lp(22, 70, lg) * (1 - i * 0.11);
      _leafQuad(scene, nodes[i], outDir, ll, ll * 0.60,
          const Color(0xFF42A85A),
          veinColor: const Color(0xFF1A5E28));
    }
  }

  // 꽃머리
  final headDir =
      (dir + const V3(0.0, 0.18, 0.65)).normalized;
  _sunflowerHead(scene, pos, headDir, g, grow, rng);
}

void _sunflowerHead(
    Scene scene, V3 center, V3 normal, double g, double grow, math.Random rng) {
  final bloom = sstep(0.58, 0.88, g);

  final budAlpha = (1.0 - bloom / 0.12).clamp(0.0, 1.0);
  if (budAlpha > 0.02) {
    scene.add(SpherePrim(
        center,
        lp(5, 16, grow),
        const Color(0xFF4CB87E).withValues(alpha: budAlpha),
        glossy: true));
  }
  if (bloom < 0.04) return;

  final petalAlpha = ((bloom - 0.04) / 0.12).clamp(0.0, 1.0);
  final diskR = lp(9, 28, bloom);
  final petalLen = lp(14, 38, bloom);
  final u = normal.anyPerp;
  final v = normal.cross(u).normalized;
  final seeding = sstep(0.90, 1.0, g);
  final petalCount = 22;

  for (int i = 0; i < petalCount; i++) {
    final ang = i * 2 * math.pi / petalCount +
        rng.nextDouble() * 0.08;
    final d = (u * math.cos(ang) + v * math.sin(ang)).normalized;
    final t = (u * -math.sin(ang) + v * math.cos(ang)).normalized;
    final baseP = center + d * (diskR * 0.88);
    final tipP = center + d * (diskR + petalLen * (1 - seeding * 0.18));
    final petalColor = Color.lerp(
        const Color(0xFFFF9800), const Color(0xFFFFF176), i / petalCount.toDouble())!;
    scene.add(QuadPrim([
      baseP + t * (petalLen * 0.17),
      tipP,
      baseP - t * (petalLen * 0.17),
    ], normal, petalColor.withValues(alpha: petalAlpha)));
  }

  const diskSeg = 20;
  final diskColor =
      Color.lerp(const Color(0xFF6D4C41), const Color(0xFF3E2723), seeding)!;
  for (int i = 0; i < diskSeg; i++) {
    final a0 = i / diskSeg * 2 * math.pi;
    final a1 = (i + 1) / diskSeg * 2 * math.pi;
    final p0 = center + (u * math.cos(a0) + v * math.sin(a0)) * diskR;
    final p1 = center + (u * math.cos(a1) + v * math.sin(a1)) * diskR;
    scene.add(QuadPrim([center, p0, p1], normal,
        diskColor.withValues(alpha: petalAlpha)));
  }
  scene.add(SpherePrim(
      center + normal * 0.5, diskR * 0.48,
      const Color(0xFF4E342E).withValues(alpha: petalAlpha),
      glossy: false));
}

// ── 다육식물 (로제트) ────────────────────────────────────────────────────────
void buildSucculent(Scene scene, double g, int seed) {
  final rng = math.Random(seed);
  final maxLeaves = lp(6, 48, sstep(0.0, 0.83, g)).round();
  final blush = sstep(0.88, 1.0, g); // 끝물 붉은 단풍
  final phi0 = rng.nextDouble() * math.pi * 2;
  const baseY = 7.0;
  final center = const V3(0, baseY, 0);

  for (int i = 0; i < maxLeaves; i++) {
    final t = i / 48.0;
    final tBirth = t * 0.80;
    final lg = sstep(tBirth, tBirth + 0.18, g);
    if (lg < 0.03) continue;
    final phi = phi0 + i * 2.39996;
    final elev = lp(0.16, 1.35, t);
    final h = V3(math.cos(phi), 0, math.sin(phi));
    final dir =
        (h * math.cos(elev) + const V3(0, 1, 0) * math.sin(elev)).normalized;
    final len = lp(50, 16, t) * lg;
    final width = len * 0.52;
    // 청록빛 세이지 다육 잎 — 끝은 산호/핑크
    _leafQuad(
      scene,
      center + dir * (len * 0.08),
      dir,
      len,
      width,
      Color.lerp(
          const Color(0xFF6EC8A8), const Color(0xFF3E9E78), t)!,
      tip: const Color(0xFFE8627A),
      tipFrac: blush,
    );
  }
  scene.add(SpherePrim(
      center,
      lp(3.5, 8, sstep(0, 0.5, g)),
      Color.lerp(const Color(0xFF4DB886), const Color(0xFFE8627A), blush)!,
      glossy: true));

  // 희귀 꽃대
  if (g >= 0.96) {
    final stalkTop = center + const V3(9, 45, 5);
    scene.add(BranchPrim(center, stalkTop, 2.0, 1.2, const Color(0xFFFFABCC)));
    scene.add(SpherePrim(stalkTop, 6.5, const Color(0xFFFF6090)));
  }
}

// ── 고사리 ───────────────────────────────────────────────────────────────────
void buildFern(Scene scene, double g, int seed) {
  final rng = math.Random(seed);
  final grow = sstep(0.16, 1.0, g);
  if (grow < 0.02) {
    scene.add(SpherePrim(
        const V3(0, 7, 0),
        lp(2.5, 6, sstep(0, 0.18, g)),
        const Color(0xFF7CB342),
        glossy: false));
    return;
  }
  final open = sstep(0.32, 0.80, g);
  final frondLen = lp(55, 245, grow);
  final count = lp(2, 7, grow).round().clamp(2, 7);

  for (int f = 0; f < count; f++) {
    final az = f / count * 2 * math.pi + rng.nextDouble() * 0.38;
    final right = V3(math.cos(az), 0, math.sin(az));
    final planeN = right.cross(const V3(0, 1, 0)).normalized;
    final lenJ = frondLen * (0.82 + rng.nextDouble() * 0.36);
    _frond(scene, right, planeN, lenJ, open, g, rng);
  }
}

void _frond(Scene scene, V3 right, V3 planeN, double len, double open,
    double g, math.Random rng) {
  const steps = 15;
  final stepLen = len / steps;
  double ang = 0.20;
  V3 p = const V3(0, 5, 0);
  V3 prev = p;
  final openSteps = (open * steps).floor();

  for (int i = 0; i < steps; i++) {
    final u = i / steps;
    double turn = 0.055;
    double sl = stepLen;
    if (u > open) {
      final cu = (u - open) / (1 - open + 1e-6);
      turn += 0.85 * cu;
      sl *= (1 - 0.52 * cu);
    }
    ang += turn;
    final dirPlane =
        (right * math.sin(ang) + const V3(0, 1, 0) * math.cos(ang)).normalized;
    p = p + dirPlane * sl;

    // 굵고 싱싱한 고사리 줄기 — 에메랄드 초록
    scene.add(BranchPrim(
        prev, p,
        lp(3.5, 1.4, u),
        lp(3.2, 1.1, u),
        const Color(0xFF2D7A42)));
    prev = p;

    // 우편(잎조각): 양쪽 부채
    if (i >= 1 && i <= openSteps) {
      final pinLen =
          lp(6, 20, u / (open + 1e-6)) * (1 - u * 0.48) * 1.35;
      if (pinLen > 2.5) {
        for (final side in const [-1.0, 1.0]) {
          final pdir =
              (planeN * side * 0.88 + dirPlane * 0.44).normalized;
          _leafQuad(
              scene, p, pdir, pinLen, pinLen * 0.44,
              i.isEven
                  ? const Color(0xFF4AB866)
                  : const Color(0xFF36944E));
        }
      }
    }
  }
  // 피들헤드(코일 끝): open 0.80~0.95에서 서서히 사라짐
  final fiddleAlpha = (1.0 - sstep(0.78, 0.95, open)).clamp(0.0, 1.0);
  if (fiddleAlpha > 0.02) {
    scene.add(SpherePrim(
        p,
        lp(4, 1.2, open),
        const Color(0xFF8FDB68).withValues(alpha: fiddleAlpha),
        glossy: true));
  }
}
