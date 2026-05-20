import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 다육식물 (에케베리아풍 로제트)
//   잎꽂이 → 잔뿌리 → 자구 → 로제트 → 다육질화 → 단풍 → 희귀한 개화
//   위에서 비스듬히 본 로제트: 바깥(큰 잎) → 안쪽(작은 잎) 동심 배열
// ═══════════════════════════════════════════════════════════════════════════
class SucculentPainter extends CustomPainter {
  final double g, wt;
  SucculentPainter(this.g, this.wt);

  @override
  void paint(Canvas c, Size s) {
    c.translate(s.width / 2, s.height - 22);
    PlantPot.draw(c);
    if (g < 0.02) return;

    c.save();
    c.translate(0, -PlantPot.height);

    // 잎꽂이 단계: 누운 잎 하나 + 잔뿌리
    if (g < 0.30) {
      _cutting(c, mr(g, 0.02, 0.30));
      c.restore();
      return;
    }

    final size = lp(26, 78, mr(g, 0.30, 0.85));
    final color = mr(g, 0.90, 1.0); // 단풍(끝물 붉은 기운)
    final breathe = 1 + math.sin(wt * 0.8) * 0.012;

    c.save();
    c.translate(0, -size * 0.42);
    c.scale(breathe, breathe * 0.82); // 살짝 비스듬한 시점
    _rosette(c, size, color);
    c.restore();

    // 희귀한 개화: 가는 꽃대 + 분홍 별꽃
    if (g >= 0.97) {
      _bloomStalk(c, mr(g, 0.97, 1.0), size);
    }

    c.restore();
  }

  void _cutting(Canvas c, double p) {
    // 누운 통통한 잎
    c.save();
    c.translate(0, -6);
    c.rotate(-0.5);
    final len = lp(16, 30, p);
    _leaf(c, len, len * 0.5, const Color(0xFF81C784), const Color(0xFFA5D6A7), 0);
    c.restore();
    // 잔뿌리
    if (p > 0.45) {
      final rp = Paint()
        ..color = const Color(0xFFCFD8DC).withValues(alpha: 0.8)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      for (int i = -1; i <= 1; i++) {
        c.drawLine(const Offset(8, -2),
            Offset(8 + i * 4.0, -2 + (p - 0.45) / 0.55 * 12), rp);
      }
    }
    // 자구(아기 다육) 살짝
    if (p > 0.7) {
      c.save();
      c.translate(14, -4);
      c.scale(1, 0.85);
      _rosette(c, (p - 0.7) / 0.3 * 16, 0);
      c.restore();
    }
  }

  void _rosette(Canvas c, double size, double colorFactor) {
    if (size < 2) return;
    // (잎 수, 길이비율, 폭비율, 회전 오프셋)
    const rings = [
      [12, 1.0, 0.42],
      [9, 0.74, 0.40],
      [6, 0.50, 0.38],
    ];
    final base = const Color(0xFF66BB6A);
    final tip = Color.lerp(
        const Color(0xFF81C784), const Color(0xFFE57373), colorFactor)!;

    for (int r = 0; r < rings.length; r++) {
      final n = rings[r][0].toInt();
      final len = size * rings[r][1].toDouble();
      final w = len * rings[r][2].toDouble();
      final offset = r * 2.399963; // 황금각 → 자연 패킹
      // 안쪽 링일수록 약간 밝게
      final ringBase = Color.lerp(base, const Color(0xFF43A047), r * 0.2)!;
      for (int i = 0; i < n; i++) {
        c.save();
        c.rotate(i * 2 * math.pi / n + offset);
        // 안쪽 잎은 더 곧추섬 → 살짝 작게 위로
        c.translate(0, -len * 0.04 * r);
        _leaf(c, len, w, ringBase, tip, colorFactor);
        c.restore();
      }
    }
    // 중심
    c.drawCircle(Offset.zero, size * 0.10,
        Paint()..color = Color.lerp(const Color(0xFF43A047), tip, colorFactor)!);
  }

  // -y(위) 방향의 통통한 잎
  void _leaf(Canvas c, double len, double w, Color base, Color tip,
      double colorFactor) {
    if (len < 1) return;
    final leaf = Path()
      ..moveTo(0, 0)
      ..cubicTo(-w * 0.55, -len * 0.4, -w * 0.4, -len * 0.82, 0, -len)
      ..cubicTo(w * 0.4, -len * 0.82, w * 0.55, -len * 0.4, 0, 0)
      ..close();
    c.drawPath(leaf, Paint()..color = base);
    // 밝은 중앙 하이라이트
    c.drawPath(
      Path()
        ..moveTo(0, -len * 0.1)
        ..cubicTo(-w * 0.18, -len * 0.45, -w * 0.12, -len * 0.78, 0, -len * 0.9)
        ..cubicTo(w * 0.12, -len * 0.78, w * 0.18, -len * 0.45, 0, -len * 0.1)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );
    // 끝 단풍
    if (colorFactor > 0.02) {
      c.drawPath(
        Path()
          ..moveTo(0, -len * 0.7)
          ..lineTo(-w * 0.28, -len * 0.92)
          ..lineTo(0, -len)
          ..lineTo(w * 0.28, -len * 0.92)
          ..close(),
        Paint()..color = tip.withValues(alpha: colorFactor),
      );
    }
  }

  void _bloomStalk(Canvas c, double p, double size) {
    final h = lp(0, size * 1.4, p);
    final sway = math.sin(wt * 1.2) * 0.06;
    c.save();
    c.translate(size * 0.5, -size * 0.4);
    c.rotate(0.3 + sway);
    c.drawLine(
        Offset.zero,
        Offset(0, -h),
        Paint()
          ..color = const Color(0xFFEF9A9A)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);
    // 분홍 별꽃 2~3송이
    final flowers = (p * 3).ceil().clamp(1, 3);
    for (int f = 0; f < flowers; f++) {
      final fy = -h * (0.5 + f * 0.24);
      c.save();
      c.translate(0, fy);
      for (int i = 0; i < 5; i++) {
        c.save();
        c.rotate(i * 2 * math.pi / 5);
        c.drawOval(
            Rect.fromCenter(center: const Offset(0, -3), width: 3, height: 5),
            Paint()..color = const Color(0xFFF48FB1));
        c.restore();
      }
      c.drawCircle(Offset.zero, 1.6, Paint()..color = const Color(0xFFFFF59D));
      c.restore();
    }
    c.restore();
  }

  @override
  bool shouldRepaint(SucculentPainter o) => o.g != g || o.wt != wt;
}
