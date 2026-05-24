import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';

// 공유 상수: 화분 높이 (식물 줄기의 y=0이 흙 표면)
const double kPotHeight = 60.0;

void addPot(Scene scene) {
  const topR = 56.0;    // 화분 몸통 상단(입구) 반지름
  const botR = 41.0;    // 화분 바닥 반지름
  const rimR = 63.0;    // 림(테두리) 외곽 반지름
  const rimTopY = 8.0;  // 림 상면 높이 (y=0 위로 돌출)
  const seg = 28;

  // 테라코타 계열 색상
  const bodyColor  = Color(0xFF9C6749);
  const rimSideCol = Color(0xFF8A5A3E);
  const rimTopCol  = Color(0xFFBB7F5E); // 위를 향해 밝음
  const innerCol   = Color(0xFF3A1E10); // 내벽 — 어두운 그림자
  const soilColor  = Color(0xFF3C2112);
  const botColor   = Color(0xFF7A4E38); // 바닥면

  V3 ring(double r, double ang, double y) =>
      V3(math.cos(ang) * r, y, math.sin(ang) * r);

  for (int i = 0; i < seg; i++) {
    final a0 = i / seg * 2 * math.pi;
    final a1 = (i + 1) / seg * 2 * math.pi;
    final mid = (a0 + a1) / 2;

    // ── 1. 몸통 외벽 (y=0 → y=-kPotHeight, 절두원뿔) ──────────────────────
    final bodyN = V3(math.cos(mid), 0.22, math.sin(mid)).normalized;
    scene.add(QuadPrim(
      [
        ring(topR, a0, 0), ring(topR, a1, 0),
        ring(botR, a1, -kPotHeight), ring(botR, a0, -kPotHeight),
      ],
      bodyN,
      bodyColor,
    ));

    // ── 2. 림 수직 측면 (r=rimR, y=0 → y=rimTopY) ─────────────────────────
    final rimSideN = V3(math.cos(mid), 0.0, math.sin(mid));
    scene.add(QuadPrim(
      [
        ring(rimR, a0, 0),      ring(rimR, a1, 0),
        ring(rimR, a1, rimTopY), ring(rimR, a0, rimTopY),
      ],
      rimSideN,
      rimSideCol,
    ));

    // ── 3. 림 상면 — 수평 링 (y=rimTopY, r=topR→rimR) ────────────────────
    // 위에서 내려다볼 때 가장 잘 보이는 면 — 밝고 선명하게
    scene.add(QuadPrim(
      [
        ring(topR, a0, rimTopY), ring(topR, a1, rimTopY),
        ring(rimR, a1, rimTopY), ring(rimR, a0, rimTopY),
      ],
      const V3(0, 1, 0),
      rimTopCol,
    ));

    // ── 4. 림 내벽 (r=topR, y=0 → y=rimTopY) — 위에서 보이는 어두운 안쪽 면
    scene.add(QuadPrim(
      [
        ring(topR, a0, rimTopY), ring(topR, a1, rimTopY),
        ring(topR, a1, 0),       ring(topR, a0, 0),
      ],
      V3(-math.cos(mid), 0.0, -math.sin(mid)),
      innerCol,
    ));

    // ── 5. 흙 표면 (y=0 디스크) ───────────────────────────────────────────
    scene.add(QuadPrim(
      [
        const V3(0, 0, 0),
        ring(topR - 3, a0, 0),
        ring(topR - 3, a1, 0),
      ],
      const V3(0, 1, 0),
      soilColor,
    ));

    // ── 6. 바닥 원판 (y=-kPotHeight) ─────────────────────────────────────
    scene.add(QuadPrim(
      [
        const V3(0, -kPotHeight, 0),
        ring(botR - 2, a0, -kPotHeight),
        ring(botR - 2, a1, -kPotHeight),
      ],
      const V3(0, -1, 0),
      botColor,
    ));
  }
}
