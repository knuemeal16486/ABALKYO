import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';

// 모든 식물이 공유하는 3D 화분 — 따뜻한 테라코타 세라믹
const double kPotHeight = 68;

void addPot(Scene scene) {
  const topR = 62.0;
  const botR = 44.0;
  const rimR = 70.0;
  const rimInner = 56.0;
  const seg = 36; // 더 많은 세그먼트 → 더 부드러운 곡면

  // 따뜻한 테라코타 세라믹 팔레트
  const body   = Color(0xFFCD8C65); // 테라코타 주황
  const belly  = Color(0xFFB87048); // 배부분 약간 어두운
  const rimCol = Color(0xFFE8B08A); // 밝은 테라코타 테두리
  const soilCol = Color(0xFF4A2E1A); // 진한 초콜릿 흙
  const soilLight = Color(0xFF6B4226); // 흙 하이라이트

  V3 ring(double r, double ang, double y) =>
      V3(math.cos(ang) * r, y, math.sin(ang) * r);

  // 높이에 따른 반지름 — 약간 배가 나온 항아리형
  double rAt(double y) {
    final t = (-y / kPotHeight).clamp(0.0, 1.0);
    // quadratic bulge: 중간(0.4)에서 약간 볼록
    final bulge = 1.0 + 0.06 * (1 - (t - 0.38) * (t - 0.38) / 0.16).clamp(0, 1);
    return (topR + (botR - topR) * t) * bulge;
  }

  // 세로 줄무늬 높이
  const stripeTop = -kPotHeight * 0.26;
  const stripeBot = -kPotHeight * 0.52;

  for (int i = 0; i < seg; i++) {
    final a0 = i / seg * 2 * math.pi;
    final a1 = (i + 1) / seg * 2 * math.pi;
    final mid = (a0 + a1) / 2;
    final outN = V3(math.cos(mid), 0.12, math.sin(mid)).normalized;

    // 상단 몸통
    scene.add(QuadPrim(
      [ring(topR, a0, 0), ring(topR, a1, 0),
       ring(rAt(stripeTop), a1, stripeTop), ring(rAt(stripeTop), a0, stripeTop)],
      outN, body,
    ));
    // 중간 장식 밴드 (약간 더 어두운)
    scene.add(QuadPrim(
      [ring(rAt(stripeTop), a0, stripeTop), ring(rAt(stripeTop), a1, stripeTop),
       ring(rAt(stripeBot), a1, stripeBot), ring(rAt(stripeBot), a0, stripeBot)],
      outN, belly,
    ));
    // 하단 몸통
    scene.add(QuadPrim(
      [ring(rAt(stripeBot), a0, stripeBot), ring(rAt(stripeBot), a1, stripeBot),
       ring(botR, a1, -kPotHeight), ring(botR, a0, -kPotHeight)],
      outN, body,
    ));

    // 림(위쪽 입술) — 안쪽 경사
    scene.add(QuadPrim(
      [ring(rimR, a0, 10), ring(rimR, a1, 10),
       ring(topR, a1, -4), ring(topR, a0, -4)],
      V3(math.cos(mid), 0.72, math.sin(mid)).normalized,
      rimCol,
    ));
    // 림 윗면 (평평한 테두리)
    scene.add(QuadPrim(
      [ring(rimInner, a0, 11), ring(rimR, a0, 10),
       ring(rimR, a1, 10), ring(rimInner, a1, 11)],
      const V3(0, 1, 0),
      rimCol,
    ));
    // 림 내측
    scene.add(QuadPrim(
      [ring(rimInner, a0, 11), ring(rimInner, a1, 11),
       ring(topR - 8, a1, 2), ring(topR - 8, a0, 2)],
      V3(-math.cos(mid), 0.18, -math.sin(mid)).normalized,
      belly,
    ));

    // 흙 표면 — 두 레이어 (진한 흙 + 밝은 중심)
    scene.add(QuadPrim(
      [const V3(0, 5, 0), ring(topR - 14, a0, 5), ring(topR - 14, a1, 5)],
      const V3(0, 1, 0),
      soilCol,
    ));
    // 흙 바깥 고리 (더 마른 흙 색)
    scene.add(QuadPrim(
      [ring(topR - 14, a0, 4), ring(topR, a0, 2),
       ring(topR, a1, 2), ring(topR - 14, a1, 4)],
      const V3(0, 1, 0),
      soilLight,
    ));
  }
}
