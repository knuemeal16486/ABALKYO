import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 해바라기(Helianthus annuus)
//   씨앗 → 발아 → 떡잎 → 본잎 → 꽃봉오리 → 만개 → 결실
//   곧게 자라는 줄기 + 번갈아 나는 하트형 잎 + 노란 두상화
// ═══════════════════════════════════════════════════════════════════════════
class SunflowerPainter extends CustomPainter {
  final double g, wt;
  SunflowerPainter(this.g, this.wt);

  @override
  void paint(Canvas c, Size s) {
    c.translate(s.width / 2, s.height - 22);
    PlantPot.draw(c);
    if (g < 0.02) return;

    c.save();
    c.translate(0, -PlantPot.height);

    if (g < 0.10) {
      _seed(c, mr(g, 0.02, 0.10));
      c.restore();
      return;
    }

    final grow = mr(g, 0.10, 0.85);
    final stemH = lp(28, 300, grow);
    final stemW = lp(2.5, 10, grow);
    final sway = math.sin(wt * 0.7) * 0.05 * grow;
    final topX = math.sin(sway) * stemH * 0.18;

    // 줄기
    c.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(topX * 0.5, -stemH * 0.5, topX, -stemH),
      Paint()
        ..color = const Color(0xFF558B2F)
        ..strokeWidth = stemW
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // 잎 (번갈아)
    final leafCount = (grow * 6).round().clamp(0, 6);
    for (int i = 0; i < leafCount; i++) {
      final t = (i + 1) / 7.0;
      final ly = -stemH * t;
      final lx = topX * t;
      final side = i.isEven ? -1.0 : 1.0;
      final size = lp(40, 16, t) * lp(0.4, 1.0, grow);
      c.save();
      c.translate(lx, ly);
      if (side < 0) c.scale(-1, 1);
      c.rotate(-0.5 + math.sin(wt * 1.6 + i) * 0.05);
      _leaf(c, size);
      c.restore();
    }

    // 꽃 머리 / 봉오리
    c.save();
    c.translate(topX, -stemH);
    c.rotate(math.sin(wt * 0.5) * 0.04);
    if (g < 0.85) {
      _bud(c, mr(g, 0.65, 0.85));
    } else {
      _flower(c, mr(g, 0.85, 1.0));
    }
    c.restore();

    c.restore();
  }

  void _seed(Canvas c, double p) {
    c.drawOval(
        Rect.fromCenter(center: const Offset(0, -2), width: 7, height: 11),
        Paint()..color = const Color(0xFF4E342E));
    c.drawLine(
        const Offset(2, -3),
        const Offset(-2, 3),
        Paint()
          ..color = const Color(0xFFBCAAA4)
          ..strokeWidth = 1);
    if (p > 0.4) {
      c.drawLine(
          const Offset(0, -4),
          Offset(0, -4 - (p - 0.4) / 0.6 * 16),
          Paint()
            ..color = const Color(0xFF7CB342)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round);
    }
  }

  // +x 방향 아몬드형 잎
  void _leaf(Canvas c, double size) {
    if (size < 2) return;
    final leaf = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size * 0.45, -size * 0.5, size, 0)
      ..quadraticBezierTo(size * 0.45, size * 0.5, 0, 0)
      ..close();
    c.drawPath(leaf, Paint()..color = const Color(0xFF43A047));
    c.drawLine(
        Offset.zero,
        Offset(size * 0.92, 0),
        Paint()
          ..color = const Color(0xFF2E7D32)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke);
  }

  void _bud(Canvas c, double p) {
    final r = lp(5, 14, p);
    // 초록 꽃받침
    for (int i = 0; i < 8; i++) {
      c.save();
      c.rotate(i * math.pi / 4);
      c.drawPath(
        Path()
          ..moveTo(-r * 0.45, 0)
          ..lineTo(0, -r * 1.5)
          ..lineTo(r * 0.45, 0)
          ..close(),
        Paint()..color = const Color(0xFF66BB6A),
      );
      c.restore();
    }
    c.drawCircle(Offset.zero, r * 0.7, Paint()..color = const Color(0xFF388E3C));
    // 노란 기색
    if (p > 0.6) {
      c.drawCircle(Offset.zero, r * 0.5,
          Paint()..color = const Color(0xFFFDD835).withValues(alpha: (p - 0.6) / 0.4));
    }
  }

  void _flower(Canvas c, double p) {
    final petalLen = lp(26, 60, p);
    final petalW = petalLen * 0.34;
    final diskR = lp(12, 26, p);
    final seeding = mr(p, 0.85, 1.0); // 끝물에 고개 숙임/색 변화

    // 뒷 꽃받침 살짝
    c.drawCircle(Offset.zero, diskR + petalLen * 0.4,
        Paint()..color = const Color(0xFF66BB6A).withValues(alpha: 0.0));

    // 꽃잎 2겹
    void petalRing(int n, double offset, double lenScale, Color col) {
      for (int i = 0; i < n; i++) {
        c.save();
        c.rotate(i * 2 * math.pi / n + offset + math.sin(wt * 0.5 + i) * 0.01);
        final len = petalLen * lenScale * (1 - seeding * 0.15);
        c.drawPath(
          Path()
            ..moveTo(0, -diskR * 0.8)
            ..quadraticBezierTo(-petalW * 0.5, -diskR - len * 0.5,
                0, -diskR - len)
            ..quadraticBezierTo(
                petalW * 0.5, -diskR - len * 0.5, 0, -diskR * 0.8)
            ..close(),
          Paint()..color = col,
        );
        c.restore();
      }
    }

    petalRing(16, 0, 1.0, const Color(0xFFF9A825));
    petalRing(16, math.pi / 16, 0.86, const Color(0xFFFFD54F));

    // 씨앗 원반
    c.drawCircle(
        Offset.zero,
        diskR,
        Paint()
          ..color = Color.lerp(const Color(0xFF6D4C41),
              const Color(0xFF3E2723), seeding)!);
    c.drawCircle(Offset.zero, diskR * 0.72,
        Paint()..color = const Color(0xFF5D4037).withValues(alpha: 0.6));

    // 씨앗 점 (제한된 수)
    final rng = math.Random(7);
    final dots = (diskR * 1.2).round().clamp(8, 26);
    for (int i = 0; i < dots; i++) {
      final a = i * 2.399963; // 황금각 → 자연스러운 나선
      final rr = diskR * 0.85 * math.sqrt(i / dots);
      c.drawCircle(
        Offset(math.cos(a) * rr, math.sin(a) * rr),
        0.9 + rng.nextDouble() * 0.5,
        Paint()..color = const Color(0xFF3E2723).withValues(alpha: 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(SunflowerPainter o) => o.g != g || o.wt != wt;
}
