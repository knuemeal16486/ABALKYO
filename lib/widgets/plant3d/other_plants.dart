import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 해바라기 · 다육식물 · 고사리 — 자연스러운 굴곡 + 불규칙 잎
// ═══════════════════════════════════════════════════════════════════════════

void _leafQuad(
  Scene scene, V3 base, V3 dir, double len, double width, Color color,
  {Color? tip, double tipFrac = 0.0, Color? veinColor,
   double asymm = 0.0, double droop = 0.0}) {
  if (len < 1) return;
  final w    = dir.anyPerp;
  final vc   = veinColor ?? const Color(0x55143A1E);
  // 중력 처짐 반영
  final tipPt = base + dir * len + V3(0, -droop * len, 0);
  final normal = dir.cross(w).normalized;
  // 비대칭 처리
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

// ── 해바라기 ─────────────────────────────────────────────────────────────────
void buildSunflower(Scene scene, double g, int seed) {
  final rng   = math.Random(seed);
  final grow  = sstep(0.0, 0.82, g);
  final stalkH = lp(28, 265, grow);
  const segs  = 5;
  final segLen = stalkH / segs;

  // 전체 기울기 방향 (개체 변이)
  final bend    = (rng.nextDouble() - 0.5) * 0.12;
  final azBend  = rng.nextDouble() * math.pi * 2;
  final bendAxis = V3(math.cos(azBend), 0, math.sin(azBend));

  V3 pos = const V3(0, 2, 0);
  V3 dir = const V3(0, 1, 0);
  final nodes = <V3>[pos];
  final dirs  = <V3>[dir];

  for (int i = 0; i < segs; i++) {
    // 주 기울기 + 세그먼트별 자연스러운 흔들림
    dir = dir.rotateAxis(bendAxis, bend).normalized;
    final sideAxis = dir.anyPerp;
    final wobble = (rng.nextDouble() - 0.5) * 0.09;
    dir = (dir + sideAxis * wobble).normalized;

    final end = pos + dir * segLen;
    final r0 = lp(3.2, 14, grow) * (1 - i / segs * 0.36);
    final r1 = lp(3.0, 13, grow) * (1 - (i + 1) / segs * 0.36);
    scene.add(BranchPrim(pos, end, r0, r1, const Color(0xFF3D7E2D)));
    pos = end;
    nodes.add(pos);
    dirs.add(dir);
  }

  // 잎 — 황금각 배치 + 비대칭 + 약간 처짐
  if (grow > 0.18) {
    for (int i = 1; i < segs; i++) {
      final phi   = i * 2.39996;
      final h     = V3(math.cos(phi), 0, math.sin(phi));
      final outDir = (h + const V3(0, 0.30, 0)).normalized;
      final lg    = sstep(0.14 + i * 0.045, 0.44 + i * 0.045, g);
      final ll    = lp(22, 72, lg) * (1 - i * 0.11);
      final asymm = (rng.nextDouble() - 0.5) * 0.20;
      _leafQuad(
        scene, nodes[i], outDir, ll, ll * 0.58,
        const Color(0xFF3E9635),
        veinColor: const Color(0xFF1E5C14),
        asymm: asymm,
        droop: rng.nextDouble() * 0.08,
      );
    }
  }

  final headDir = (dir + const V3(0.0, 0.18, 0.65)).normalized;
  _sunflowerHead(scene, pos, headDir, g, grow, rng);
}

void _sunflowerHead(
    Scene scene, V3 center, V3 normal, double g, double grow, math.Random rng) {
  final bloom = sstep(0.58, 0.88, g);

  final budAlpha = (1.0 - bloom / 0.12).clamp(0.0, 1.0);
  if (budAlpha > 0.02) {
    scene.add(SpherePrim(
        center, lp(5, 16, grow),
        const Color(0xFF4CB87E).withValues(alpha: budAlpha),
        glossy: true));
  }
  if (bloom < 0.04) return;

  final petalAlpha = ((bloom - 0.04) / 0.12).clamp(0.0, 1.0);
  final diskR     = lp(9, 28, bloom);
  final petalLen  = lp(14, 40, bloom);
  final u = normal.anyPerp;
  final v = normal.cross(u).normalized;
  final seeding = sstep(0.90, 1.0, g);

  for (int i = 0; i < 22; i++) {
    final ang   = i * 2 * math.pi / 22 + rng.nextDouble() * 0.06;
    final d     = (u * math.cos(ang) + v * math.sin(ang)).normalized;
    final t     = (u * -math.sin(ang) + v * math.cos(ang)).normalized;
    final baseP = center + d * (diskR * 0.87);
    // 꽃잎 길이/넓이 약간씩 다르게 (불규칙)
    final pLen  = petalLen * (0.85 + rng.nextDouble() * 0.30);
    final pWid  = pLen * (0.14 + rng.nextDouble() * 0.06);
    final tipP  = center + d * (diskR + pLen * (1 - seeding * 0.18));
    final petalColor = Color.lerp(
        const Color(0xFFFF9800), const Color(0xFFFFF176),
        i / 22.0)!;
    scene.add(QuadPrim([
      baseP + t * pWid,
      tipP,
      baseP - t * pWid,
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
  final rng   = math.Random(seed);
  final maxLv = lp(6, 50, sstep(0.0, 0.83, g)).round();
  final blush = sstep(0.88, 1.0, g);
  final phi0  = rng.nextDouble() * math.pi * 2;
  const baseY = 7.0;
  final center = const V3(0, baseY, 0);

  for (int i = 0; i < maxLv; i++) {
    final t      = i / 50.0;
    final tBirth = t * 0.80;
    final lg     = sstep(tBirth, tBirth + 0.18, g);
    if (lg < 0.03) continue;
    final phi  = phi0 + i * 2.39996;
    final elev = lp(0.16, 1.35, t);
    final h    = V3(math.cos(phi), 0, math.sin(phi));
    final dir  = (h * math.cos(elev) + const V3(0, 1, 0) * math.sin(elev))
        .normalized;
    final len   = lp(50, 16, t) * lg;
    final width = len * (0.50 + rng.nextDouble() * 0.08);
    final asymm = (rng.nextDouble() - 0.5) * 0.25;
    // 바깥 잎은 중력으로 처짐
    final droop = (1 - t) * 0.06 * rng.nextDouble();
    _leafQuad(
      scene,
      center + dir * (len * 0.08),
      dir, len, width,
      Color.lerp(const Color(0xFF6EC8A8), const Color(0xFF3E9E78), t)!,
      tip: const Color(0xFFE8627A),
      tipFrac: blush,
      asymm: asymm,
      droop: droop,
    );
  }
  scene.add(SpherePrim(
      center,
      lp(3.5, 8, sstep(0, 0.5, g)),
      Color.lerp(const Color(0xFF4DB886), const Color(0xFFE8627A), blush)!,
      glossy: true));

  if (g >= 0.96) {
    // 꽃대는 자연스러운 굴곡
    final mid = center + const V3(4, 22, 2);
    final top = center + const V3(9, 45, 5);
    scene.add(BranchPrim(center, mid, 2.2, 1.6, const Color(0xFFD4A0B0)));
    scene.add(BranchPrim(mid, top, 1.6, 1.0, const Color(0xFFFFABCC)));
    scene.add(SpherePrim(top, 6.5, const Color(0xFFFF6090)));
  }
}

// ── 고사리 ───────────────────────────────────────────────────────────────────
void buildFern(Scene scene, double g, int seed) {
  final rng  = math.Random(seed);
  final grow = sstep(0.16, 1.0, g);
  if (grow < 0.02) {
    scene.add(SpherePrim(
        const V3(0, 7, 0),
        lp(2.5, 6, sstep(0, 0.18, g)),
        const Color(0xFF7CB342),
        glossy: false));
    return;
  }
  final open     = sstep(0.32, 0.80, g);
  final frondLen = lp(55, 250, grow);
  final count    = lp(2, 7, grow).round().clamp(2, 7);

  for (int f = 0; f < count; f++) {
    final az    = f / count * 2 * math.pi + rng.nextDouble() * 0.38;
    final right = V3(math.cos(az), 0, math.sin(az));
    final planeN = right.cross(const V3(0, 1, 0)).normalized;
    final lenJ  = frondLen * (0.80 + rng.nextDouble() * 0.40);
    _frond(scene, right, planeN, lenJ, open, g, rng);
  }
}

void _frond(Scene scene, V3 right, V3 planeN, double len, double open,
    double g, math.Random rng) {
  const steps = 15;
  final stepLen = len / steps;
  double ang = 0.20;
  V3 p    = const V3(0, 5, 0);
  V3 prev = p;
  final openSteps = (open * steps).floor();

  for (int i = 0; i < steps; i++) {
    final u = i / steps;
    double turn = 0.055;
    double sl   = stepLen;
    if (u > open) {
      final cu = (u - open) / (1 - open + 1e-6);
      turn += 0.85 * cu;
      sl   *= (1 - 0.52 * cu);
    }
    // 세그먼트마다 미세한 불규칙 굴곡
    turn += (rng.nextDouble() - 0.5) * 0.025;
    ang  += turn;

    final dirPlane =
        (right * math.sin(ang) + const V3(0, 1, 0) * math.cos(ang)).normalized;
    p = p + dirPlane * sl;

    final r0 = lp(3.5, 1.4, u);
    final r1 = lp(3.2, 1.1, u);
    scene.add(BranchPrim(prev, p, r0, r1, const Color(0xFF2A6E38)));
    prev = p;

    if (i >= 1 && i <= openSteps) {
      final pinLen = lp(6, 21, u / (open + 1e-6)) * (1 - u * 0.46) * 1.35;
      if (pinLen > 2.5) {
        for (final side in const [-1.0, 1.0]) {
          final pdir = (planeN * side * 0.88 + dirPlane * 0.44).normalized;
          final asymm = (rng.nextDouble() - 0.5) * 0.18;
          final droop = rng.nextDouble() * 0.06;
          _leafQuad(
            scene, p, pdir, pinLen, pinLen * 0.44,
            i.isEven
                ? const Color(0xFF42A85A)
                : const Color(0xFF348A48),
            asymm: asymm,
            droop: droop,
          );
        }
      }
    }
  }

  final fiddleAlpha = (1.0 - sstep(0.78, 0.95, open)).clamp(0.0, 1.0);
  if (fiddleAlpha > 0.02) {
    scene.add(SpherePrim(
        p,
        lp(4, 1.2, open),
        const Color(0xFF8FDB68).withValues(alpha: fiddleAlpha),
        glossy: true));
  }
}
