import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 양치식물 (고사리)
//   포자 → 전엽체 → 크로지어(피들헤드) → 펼쳐짐 → 성숙 → 포자낭군
//   터틀 그래픽으로 그린 잎자루: 아랫부분은 펼쳐진 호, 끝은 도르르 말린 코일
// ═══════════════════════════════════════════════════════════════════════════
class FernPainter extends CustomPainter {
  final double g, wt;
  FernPainter(this.g, this.wt);

  @override
  void paint(Canvas c, Size s) {
    c.translate(s.width / 2, s.height - 22);
    PlantPot.draw(c);
    if (g < 0.02) return;

    c.save();
    c.translate(0, -PlantPot.height);

    if (g < 0.15) {
      _spores(c, mr(g, 0.02, 0.15));
      c.restore();
      return;
    }
    if (g < 0.35) {
      _prothallus(c, mr(g, 0.15, 0.35));
      c.restore();
      return;
    }

    final grow = mr(g, 0.35, 1.0);
    final open = mr(g, 0.35, 0.80); // 0=완전히 말림, 1=완전히 펼침
    final sori = mr(g, 0.85, 1.0);
    final frondLen = lp(70, 230, grow);
    final frondCount = lp(2, 6, grow).round().clamp(2, 6);

    // 가운데가 가장 곧고 바깥쪽으로 펼쳐짐
    for (int f = 0; f < frondCount; f++) {
      final spread = frondCount == 1 ? 0.0 : (f / (frondCount - 1) - 0.5) * 2;
      final baseAngle = spread * 0.85; // -0.85..0.85 rad
      final dir = spread >= 0 ? 1.0 : -1.0;
      final lenJit = 0.8 + (f * 0.13 % 0.4);
      final wind = math.sin(wt * 0.8 + f * 1.3) * 0.05;
      c.save();
      c.rotate(wind * 0.4);
      _frond(c, frondLen * lenJit, baseAngle, dir, open, sori, f);
      c.restore();
    }

    c.restore();
  }

  void _spores(Canvas c, double p) {
    final rng = math.Random(3);
    final n = (4 + p * 8).round();
    for (int i = 0; i < n; i++) {
      c.drawCircle(
        Offset((rng.nextDouble() * 2 - 1) * 46, -(rng.nextDouble() * 5)),
        0.8 + rng.nextDouble() * 1.2,
        Paint()
          ..color = Color.lerp(const Color(0xFF4E342E),
              const Color(0xFF558B2F), p)!.withValues(alpha: 0.7),
      );
    }
  }

  void _prothallus(Canvas c, double p) {
    // 작은 하트형 전엽체
    final sz = lp(8, 18, p);
    final heart = Path()
      ..moveTo(0, -sz * 0.2)
      ..cubicTo(-sz * 0.9, -sz * 1.1, -sz * 1.1, sz * 0.5, 0, sz * 0.55)
      ..cubicTo(sz * 1.1, sz * 0.5, sz * 0.9, -sz * 1.1, 0, -sz * 0.2)
      ..close();
    c.save();
    c.translate(0, -sz * 0.4);
    c.scale(1, 0.85);
    c.drawPath(heart, Paint()..color = const Color(0xFF7CB342).withValues(alpha: 0.92));
    c.drawPath(
        heart,
        Paint()
          ..color = const Color(0xFF558B2F)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke);
    c.restore();
    // 첫 크로지어 살짝
    if (p > 0.55) {
      c.save();
      c.translate(0, -sz * 0.5);
      _frond(c, lp(0, 40, (p - 0.55) / 0.45), 0, 1, 0.0, 0, 0);
      c.restore();
    }
  }

  // 잎자루 하나: 터틀 그래픽
  void _frond(Canvas c, double len, double baseAngle, double dir, double open,
      double sori, int seed) {
    if (len < 2) return;
    const steps = 26;
    final stepLen = len / steps;
    final rachis = <Offset>[];
    final headings = <double>[];

    double angle = baseAngle;
    Offset pos = Offset.zero;
    rachis.add(pos);
    headings.add(angle);

    for (int i = 0; i < steps; i++) {
      final u = i / steps;
      double turn = 0.05 * dir; // 완만한 호
      double sl = stepLen;
      if (u > open) {
        // 코일 영역: 점점 조이며 보폭 축소
        final cu = (u - open) / (1 - open + 1e-6);
        turn += 0.82 * cu * dir;
        sl *= (1 - 0.55 * cu);
      }
      angle += turn;
      pos += Offset(math.sin(angle) * sl, -math.cos(angle) * sl);
      rachis.add(pos);
      headings.add(angle);
    }

    // 잎자루 선
    final path = Path()..moveTo(rachis.first.dx, rachis.first.dy);
    for (final pt in rachis.skip(1)) {
      path.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF33691E)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // 우편(잎조각) — 펼쳐진 구간에만
    final openSteps = (open * steps).floor();
    final pinColor = const Color(0xFF4CAF50);
    final pinColorDark = const Color(0xFF2E7D32);
    for (int i = 1; i < openSteps; i++) {
      final u = i / steps;
      final base = rachis[i];
      final heading = headings[i];
      // 가운데가 가장 길고 양 끝은 짧게
      final pinLen = lp(4, 16, mr(u / (open + 1e-6), 0.0, 1.0)) *
          (1 - u * 0.5) *
          1.4;
      if (pinLen < 2) continue;
      for (final side in const [-1.0, 1.0]) {
        final a = heading + side * 1.15; // 잎자루에 거의 수직
        c.save();
        c.translate(base.dx, base.dy);
        c.rotate(a);
        _pinna(c, pinLen,
            ((i + (side > 0 ? 1 : 0)) % 2 == 0) ? pinColor : pinColorDark);
        // 포자낭군
        if (sori > 0.05 && i % 2 == 0) {
          c.drawCircle(Offset(0, -pinLen * 0.5), 0.9,
              Paint()..color = const Color(0xFF6D4C41).withValues(alpha: sori * 0.8));
        }
        c.restore();
      }
    }

    // 코일 끝(피들헤드) 강조
    if (open < 0.98) {
      final tip = rachis.last;
      c.drawCircle(tip, lp(3.5, 1.2, open),
          Paint()..color = const Color(0xFF7CB342));
      c.drawCircle(tip, lp(1.6, 0.4, open),
          Paint()..color = const Color(0xFFC5E1A5));
    }
  }

  // -y 방향의 좁은 잎조각
  void _pinna(Canvas c, double len, Color col) {
    final w = len * 0.34;
    c.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(-w, -len * 0.5, 0, -len)
        ..quadraticBezierTo(w, -len * 0.5, 0, 0)
        ..close(),
      Paint()..color = col,
    );
  }

  @override
  bool shouldRepaint(FernPainter o) => o.g != g || o.wt != wt;
}
