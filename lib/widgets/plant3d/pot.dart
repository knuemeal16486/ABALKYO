import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';

// 모든 식물이 공유하는 3D 토분(절두원뿔). 줄기는 y=0(흙 표면)에서 위로 자란다.
const double kPotHeight = 66;

void addPot(Scene scene) {
  const topR = 60.0;
  const botR = 46.0;
  const rimR = 65.0;
  const seg = 24;
  const body = Color(0xFFA1674A);
  const rim = Color(0xFF8D5A40);
  const soil = Color(0xFF3E2723);

  V3 ring(double r, double ang, double y) =>
      V3(math.cos(ang) * r, y, math.sin(ang) * r);

  for (int i = 0; i < seg; i++) {
    final a0 = i / seg * 2 * math.pi;
    final a1 = (i + 1) / seg * 2 * math.pi;
    final mid = (a0 + a1) / 2;
    final normal = V3(math.cos(mid), 0.18, math.sin(mid)).normalized;

    // 토분 몸통
    scene.add(QuadPrim(
      [ring(topR, a0, 0), ring(topR, a1, 0), ring(botR, a1, -kPotHeight),
        ring(botR, a0, -kPotHeight)],
      normal,
      body,
    ));
    // 윗 테두리(립)
    scene.add(QuadPrim(
      [ring(rimR, a0, 6), ring(rimR, a1, 6), ring(topR, a1, -4),
        ring(topR, a0, -4)],
      V3(math.cos(mid), 0.5, math.sin(mid)).normalized,
      rim,
    ));
    // 흙(윗면 부채꼴)
    scene.add(QuadPrim(
      [const V3(0, 4, 0), ring(topR - 8, a0, 4), ring(topR - 8, a1, 4)],
      const V3(0, 1, 0),
      soil,
    ));
  }
}
