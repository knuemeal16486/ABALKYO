import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'engine.dart';

// 모든 식물이 공유하는 3D 화분. My Oasis 스타일 - 부드러운 세라믹 도자기
const double kPotHeight = 66;

void addPot(Scene scene) {
  const topR = 60.0;
  const botR = 46.0;
  const rimR = 66.0;
  const seg = 32; // 더 많은 세그먼트 → 더 부드러운 곡선감

  // 파스텔 세이지 그린 세라믹 팔레트 (My Oasis 스타일)
  const body    = Color(0xFF8EC5B0); // 소프트 민트 세라믹
  const stripe  = Color(0xFFA9D9C8); // 밝은 민트 스트라이프
  const rimCol  = Color(0xFFC5E8DC); // 크림 민트 테두리
  const soilCol = Color(0xFF7A5440); // 풍부한 초콜릿 흙

  V3 ring(double r, double ang, double y) =>
      V3(math.cos(ang) * r, y, math.sin(ang) * r);

  // 팟 높이에 따른 반지름 보간
  double rAt(double y) => topR + (botR - topR) * (-y / kPotHeight);

  // 스트라이프 밴드 위치 (위에서 30~55%)
  const stripeTop = -kPotHeight * 0.28;
  const stripeBot = -kPotHeight * 0.54;

  for (int i = 0; i < seg; i++) {
    final a0 = i / seg * 2 * math.pi;
    final a1 = (i + 1) / seg * 2 * math.pi;
    final mid = (a0 + a1) / 2;
    final outN = V3(math.cos(mid), 0.15, math.sin(mid)).normalized;

    // 상단 몸통 (top → stripe top)
    scene.add(QuadPrim(
      [ring(topR, a0, 0), ring(topR, a1, 0),
       ring(rAt(stripeTop), a1, stripeTop), ring(rAt(stripeTop), a0, stripeTop)],
      outN, body,
    ));

    // 장식 스트라이프 밴드 (lighter mint)
    scene.add(QuadPrim(
      [ring(rAt(stripeTop), a0, stripeTop), ring(rAt(stripeTop), a1, stripeTop),
       ring(rAt(stripeBot), a1, stripeBot), ring(rAt(stripeBot), a0, stripeBot)],
      outN, stripe,
    ));

    // 하단 몸통 (stripe bot → bottom)
    scene.add(QuadPrim(
      [ring(rAt(stripeBot), a0, stripeBot), ring(rAt(stripeBot), a1, stripeBot),
       ring(botR, a1, -kPotHeight), ring(botR, a0, -kPotHeight)],
      outN, body,
    ));

    // 테두리(립) — 넓고 부드럽게
    scene.add(QuadPrim(
      [ring(rimR, a0, 8), ring(rimR, a1, 8),
       ring(topR, a1, -5), ring(topR, a0, -5)],
      V3(math.cos(mid), 0.65, math.sin(mid)).normalized,
      rimCol,
    ));

    // 흙(윗면)
    scene.add(QuadPrim(
      [const V3(0, 4, 0), ring(topR - 10, a0, 4), ring(topR - 10, a1, 4)],
      const V3(0, 1, 0),
      soilCol,
    ));
  }
}
