import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 선형 보간 (t는 0~1로 클램프)
double lp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

/// v를 [lo, hi] 구간에서 0~1로 정규화
double mr(double v, double lo, double hi) =>
    ((v - lo) / (hi - lo)).clamp(0.0, 1.0);

/// 모든 식물이 공유하는 토분. 캔버스 원점이 (중앙, 지면)에 있다고 가정한다.
/// 식물 줄기는 호출 후 translate(0, -PlantPot.height) 위치에서 시작한다.
class PlantPot {
  static const double height = 66;

  static void draw(Canvas c) {
    // 그림자
    c.drawOval(
      Rect.fromCenter(center: const Offset(0, 6), width: 140, height: 20),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // 토분 본체 (사다리꼴)
    c.drawPath(
      Path()
        ..moveTo(-54, 0)
        ..lineTo(54, 0)
        ..lineTo(70, -66)
        ..lineTo(-70, -66)
        ..close(),
      Paint()..color = const Color(0xFF8D6E63),
    );
    // 그림자 면
    c.drawPath(
      Path()
        ..moveTo(10, 0)
        ..lineTo(54, 0)
        ..lineTo(70, -66)
        ..lineTo(10, -66)
        ..close(),
      Paint()..color = const Color(0xFF6D4C41),
    );

    // 장식 띠
    c.drawLine(const Offset(-64, -24), const Offset(64, -24),
        Paint()..color = const Color(0xFF795548)..strokeWidth = 3);

    // 토분 림
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, -70), width: 152, height: 18),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF795548),
    );

    // 흙
    c.drawOval(
      Rect.fromCenter(center: const Offset(0, -70), width: 132, height: 11),
      Paint()..color = const Color(0xFF3E2723),
    );
    final rng = math.Random(99);
    for (int i = 0; i < 6; i++) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset((rng.nextDouble() * 2 - 1) * 50,
              -70.0 + (rng.nextDouble() * 2 - 1) * 3),
          width: 3 + rng.nextDouble() * 4,
          height: 2,
        ),
        Paint()..color = const Color(0xFF5D4037).withValues(alpha: 0.3),
      );
    }
  }
}
