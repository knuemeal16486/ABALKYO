import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 해바라기 · 다육식물 · 고사리 — 3D 생성기 (곡선 줄기 및 실제 생장 모델 적용)
// ═══════════════════════════════════════════════════════════════════════════

void _leafQuad(Scene scene, V3 base, V3 dir, double len, double width,
    Color color, {Color? tip, double tipFrac = 0.0, double shininess = 8.0, double specIntensity = 0.15}) {
  if (len < 1) return;
  final w = dir.anyPerp;
  final normal = dir.cross(w).normalized;
  final tipPt = base + dir * len;
  final cTip = tip != null && tipFrac > 0.02 ? Color.lerp(color, tip, tipFrac) : null;
  scene.add(LeafPrim(base, tipPt, normal, width, color, tipColor: cTip, veinColor: const Color(0x55143A1E), shininess: shininess, specIntensity: specIntensity));
}

// ── 해바라기 ─────────────────────────────────────────────────────────────────
void buildSunflower(Scene scene, double g, int seed) {
  final rng = math.Random(seed);
  final grow = sstep(0.0, 0.85, g);
  final stalkH = lp(22, 280, grow);
  
  // 1. 단일 곡선 줄기 (CurveStemPrim)
  final bend = (rng.nextDouble() - 0.5) * 0.2;
  final azBend = rng.nextDouble() * math.pi * 2;
  final bendAxis = V3(math.cos(azBend), 0, math.sin(azBend));
  
  final int ptsCount = 20;
  final List<V3> pts = [];
  final List<double> radii = [];
  
  V3 pos = const V3(0, 2, 0);
  V3 dir = const V3(0, 1, 0);
  final double stepLen = stalkH / ptsCount;
  
  for (int i = 0; i <= ptsCount; i++) {
    pts.add(pos);
    radii.add(lp(6.0, 2.0, i / ptsCount) * sstep(0, 0.5, grow));
    dir = dir.rotateAxis(bendAxis, bend / ptsCount).normalized;
    pos = pos + dir * stepLen;
  }
  
  if (pts.length > 1 && stalkH > 5) {
    scene.add(CurveStemPrim(pts, radii, const Color(0xFF558B2F)));
  }

  // 2. 잎차례 (Phyllotaxis) - 황금각에 따라 나선형 배치
  if (grow > 0.15) {
    final int numLeaves = (12 * grow).floor();
    final double goldenAngle = math.pi * (3 - math.sqrt(5));
    for (int i = 1; i <= numLeaves; i++) {
      // 줄기를 따라 잎이 돋아날 위치 인덱스
      final ptIdx = (i / (numLeaves + 1) * ptsCount).floor();
      final nodePos = pts[ptIdx];
      
      final phi = i * goldenAngle;
      final h = V3(math.cos(phi), 0, math.sin(phi));
      final outDir = (h + const V3(0, 0.4, 0)).normalized;
      
      final lg = sstep(0.1 + i * 0.05, 0.4 + i * 0.05, g);
      if (lg > 0) {
        _leafQuad(scene, nodePos, outDir, lp(15, 65, lg) * (1 - ptIdx / ptsCount * 0.4),
            lp(10, 45, lg) * (1 - ptIdx / ptsCount * 0.4), const Color(0xFF43A047), shininess: 10.0, specIntensity: 0.2);
      }
    }
  }

  // 3. 머리 (봉오리 → 만개)
  final headDir = (dir + const V3(0, 0.2, 0.5)).normalized;
  _sunflowerHead(scene, pts.last, headDir, g, grow);
}

void _sunflowerHead(Scene scene, V3 center, V3 normal, double g, double grow) {
  final bloom = sstep(0.6, 0.9, g);
  if (bloom < 0.05) {
    scene.add(SpherePrim(center, lp(4, 15, grow), const Color(0xFF66BB6A), glossy: false));
    return;
  }
  final diskR = lp(8, 26, bloom);
  final petalLen = lp(12, 38, bloom);
  final u = normal.anyPerp;
  final v = normal.cross(u).normalized;
  final seeding = sstep(0.92, 1.0, g);

  // 겹꽃잎 (매끄러운 LeafPrim 적용)
  for (int i = 0; i < 42; i++) {
    final ang = i * 2 * math.pi / 42;
    final d = (u * math.cos(ang) + v * math.sin(ang)).normalized;
    final petalNormal = (normal + d * 0.12).normalized;
    final baseP = center + d * (diskR * 0.85);
    final tipP = center + d * (diskR + petalLen * (1 - seeding * 0.2));
    scene.add(LeafPrim(baseP, tipP, petalNormal, petalLen * 0.35, const Color(0xFFFFB300), tipColor: const Color(0xFFFFE082), shininess: 4.0, specIntensity: 0.1));
  }
  
  // 피보나치 나선 씨앗 원반
  final diskColor = Color.lerp(const Color(0xFF6D4C41), const Color(0xFF3E2723), seeding)!;
  final seedCount = (250 * bloom).round();
  final goldenAngle = math.pi * (3 - math.sqrt(5));
  for (int i = 0; i < seedCount; i++) {
    final r = diskR * math.sqrt(i / seedCount) * 0.96;
    final theta = i * goldenAngle;
    final seedP = center + (u * math.cos(theta) + v * math.sin(theta)) * r;
    scene.add(SpherePrim(seedP, diskR * 0.04 + 0.5, diskColor, glossy: false));
  }
}

// ── 다육식물 (로제트 구조 완벽 재현) ────────────────────────────────────────────────
void buildSucculent(Scene scene, double g, int seed) {
  final rng = math.Random(seed);
  // 줄기 없이 중심 코어에서 끊임없이 밀려나오는 잎 구조
  final double totalGrowth = sstep(0.0, 1.0, g);
  final int maxLeaves = lp(6, 60, totalGrowth).round();
  final color = sstep(0.85, 1.0, g); // 끝물 단풍
  
  const baseY = 4.0;
  final center = const V3(0, baseY, 0);
  final goldenAngle = math.pi * (3 - math.sqrt(5));
  final phi0 = rng.nextDouble() * math.pi * 2;

  // 피보나치 나선 배열 적용
  for (int i = 0; i < maxLeaves; i++) {
    final age = i / 60.0; // 0 = 가장 오래된(바깥) 잎, 1 = 방금 난 안쪽 잎
    final tBirth = age * 0.8;
    final lg = sstep(tBirth, tBirth + 0.15, g);
    if (lg < 0.05) continue;
    
    // 잎이 안에서 밖으로 밀려나며 눕는 각도 계산
    // 중심(새로운 잎)은 위를 향하고, 바깥(오래된 잎)은 눕는다
    final elev = lp(0.1, 1.4, age); 
    
    final phi = phi0 + i * goldenAngle;
    final h = V3(math.cos(phi), 0, math.sin(phi));
    final dir = (h * math.cos(elev) + const V3(0, 1, 0) * math.sin(elev)).normalized;
    
    // 바깥 잎일수록 크다
    final len = lp(55, 10, age) * lg;
    final width = len * 0.65; // 다육이 특유의 아주 통통한 형태
    
    final leafBase = center + h * (len * 0.1); // 중심에서 살짝 밖에서 시작
    
    _leafQuad(scene, leafBase, dir, len, width,
        Color.lerp(const Color(0xFF66BB6A), const Color(0xFF43A047), age)!,
        tip: const Color(0xFFE57373), tipFrac: color, shininess: 48.0, specIntensity: 0.6); // 매우 높은 광택
  }
  
  // 중심 코어 디테일
  if (totalGrowth > 0.1) {
    scene.add(SpherePrim(center + const V3(0, 2, 0), 4 * totalGrowth, Color.lerp(const Color(0xFF43A047), const Color(0xFFE57373), color)!, glossy: true));
  }
}

// ── 고사리 (대수 나선 피들헤드 및 곡선 줄기) ──────────────────────────────────────
void buildFern(Scene scene, double g, int seed) {
  final rng = math.Random(seed);
  final grow = sstep(0.1, 1.0, g);
  if (grow < 0.02) {
    scene.add(SpherePrim(const V3(0, 4, 0), lp(2, 6, sstep(0, 0.15, g)), const Color(0xFF7CB342), glossy: false));
    return;
  }
  final open = sstep(0.3, 0.85, g); // 나선이 풀리는 정도
  final frondLen = lp(60, 260, grow);
  final count = lp(2, 7, grow).round().clamp(2, 7);

  for (int f = 0; f < count; f++) {
    final az = f / count * 2 * math.pi + rng.nextDouble() * 0.3;
    final right = V3(math.cos(az), 0, math.sin(az));
    final planeN = right.cross(const V3(0, 1, 0)).normalized;
    final lenJ = frondLen * (0.85 + rng.nextDouble() * 0.3);
    _fernFrond(scene, right, planeN, lenJ, open, grow, rng);
  }
}

void _fernFrond(Scene scene, V3 right, V3 planeN, double len, double open, double grow, math.Random rng) {
  const int steps = 40;
  final double stepLen = len / steps;
  
  final List<V3> pts = [];
  final List<double> radii = [];
  
  V3 p = const V3(0, 2, 0);
  pts.add(p);
  radii.add(lp(2.5, 0.5, 0));
  
  double currentAng = 0.3; // 처음 밖으로 기운 각도
  
  for (int i = 1; i <= steps; i++) {
    final double t = i / steps;
    
    // 대수 나선(Logarithmic Spiral) 시뮬레이션:
    // 열림 정도(open)에 따라 뒤쪽은 직선이 되고 앞쪽은 여전히 말려있게 됨
    double turn = 0.04;
    double sl = stepLen;
    
    // 풀리지 않은 부분은 강력하게 안으로 말린다
    if (t > open) {
      final cu = (t - open) / (1 - open + 1e-6);
      turn += 0.5 * cu; // 말리는 곡률 급격히 증가
      sl *= (1 - 0.6 * cu); // 말린 부분은 길이가 압축됨
    }
    
    currentAng += turn;
    final dirPlane = (right * math.sin(currentAng) + const V3(0, 1, 0) * math.cos(currentAng)).normalized;
    p = p + dirPlane * sl;
    
    pts.add(p);
    radii.add(lp(2.5, 0.5, t) * sstep(0, 0.4, grow));
  }
  
  // 1. 단일 곡선 줄기(Rachis) 렌더링
  if (pts.length > 2) {
    scene.add(CurveStemPrim(pts, radii, const Color(0xFF33691E)));
  }
  
  // 2. 우편(Pinnae - 잎조각) 고밀도 배치
  final int openSteps = (open * steps).floor();
  for (int i = 2; i < openSteps; i++) {
    final double t = i / steps;
    // 부채꼴로 양쪽으로 퍼지는 잎조각
    final pinLen = lp(6, 22, t / (open + 1e-6)) * (1 - t * 0.4) * 1.4;
    if (pinLen < 2) continue;
    
    final basePt = pts[i];
    final dirP = (pts[i] - pts[i-1]).normalized;
    
    for (final side in const [-1.0, 1.0]) {
      final pdir = (planeN * side * 0.9 + dirP * 0.3).normalized;
      _leafQuad(scene, basePt, pdir, pinLen, pinLen * 0.35,
          i.isEven ? const Color(0xFF4CAF50) : const Color(0xFF388E3C), shininess: 12.0, specIntensity: 0.1);
    }
  }
  
  // 끝부분 피들헤드 둥글게 마감
  if (open < 0.98) {
    scene.add(SpherePrim(pts.last, lp(4, 1.5, open), const Color(0xFF7CB342), glossy: false));
  }
}
