import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paint_utils.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 사과나무(Malus domestica) — 폴리곤 스타일 · 성능 최적화
// ─────────────────────────────────────────────────────────────────────────────
// 최적화 전략:
//   재귀 깊이 6→4, 분기 3→2, 잎 14→2 draws, 꽃 62→7 draws
//   프레임당 ~1,500 draw calls (기존 ~500,000 대비 99.7% 감소)
//
// 유지 사항:
//   L-system 분기 + 다빈치 법칙, 한국 기후 계절 시스템,
//   씨앗→발아→묘목→성목→개화→결실 연속 성장, 겨울 휴면아
// ═══════════════════════════════════════════════════════════════════════════════

// ── 계절 (한국 서울 기후) ───────────────────────────────────────────────────
class _Season {
  final double ld, bs, fs; // 잎 밀도, 개화 강도, 결실 강도
  final Color lc;           // 잎 색상
  const _Season(this.ld, this.bs, this.fs, this.lc);

  static _Season of(int m) => switch (m) {
    1 || 2 || 12 => const _Season(0.0,  0.0,  0.0,  Color(0xFF8D6E63)),
    3            => const _Season(0.25, 0.0,  0.0,  Color(0xFF81C784)),
    4            => const _Season(0.7,  1.0,  0.0,  Color(0xFF66BB6A)),
    5            => const _Season(0.9,  0.35, 0.12, Color(0xFF43A047)),
    6            => const _Season(1.0,  0.0,  0.35, Color(0xFF388E3C)),
    7 || 8       => const _Season(1.0,  0.0,  0.65, Color(0xFF2E7D32)),
    9            => const _Season(0.85, 0.0,  0.90, Color(0xFF558B2F)),
    10           => const _Season(0.5,  0.0,  1.0,  Color(0xFFE65100)),
    11           => const _Season(0.15, 0.0,  0.25, Color(0xFFBF360C)),
    _            => const _Season(0.6,  0.0,  0.0,  Color(0xFF43A047)),
  };
}

// ── 메인 페인터 ─────────────────────────────────────────────────────────────
class AppleTreePainter extends CustomPainter {
  final double g, wt;
  final int month;
  late final _Season _sn;

  // 프레임별 공유값 (재귀 파라미터 전달 최소화)
  double _la = 0, _fa = 0, _ra = 0;
  Color _rc = Colors.green;

  AppleTreePainter(this.g, this.wt, this.month) { _sn = _Season.of(month); }

  static double _l(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);
  static double _m(double v, double lo, double hi) => ((v - lo) / (hi - lo)).clamp(0.0, 1.0);

  @override
  void paint(Canvas c, Size s) {
    c.translate(s.width / 2, s.height - 22);
    _pot(c);
    if (g < 0.02) return;

    c.save();
    c.translate(0, -66);
    if (g < 0.08) { _seed(c, _m(g, 0.02, 0.08)); }
    else if (g < 0.15) { _sprout(c, _m(g, 0.08, 0.15)); }
    else { _tree(c); }
    c.restore();
  }

  // ── 씨앗 & 발아 ───────────────────────────────────────────────────────────
  void _seed(Canvas c, double p) {
    c.drawOval(Rect.fromCenter(center: const Offset(0, -2), width: 8, height: 5.5),
      Paint()..color = const Color(0xFF6D4C41));
    if (p > 0.25) {
      c.drawLine(Offset(0, -3), Offset(0, -3 - p * 5),
        Paint()..color = const Color(0xFF33691E)..strokeWidth = 0.8
          ..style = PaintingStyle.stroke);
    }
    if (p > 0.45) {
      final rp = Paint()..color = const Color(0xFFBCAAA4)..strokeWidth = 0.7
        ..style = PaintingStyle.stroke;
      c.drawLine(const Offset(0, 1), Offset(-2, 1 + (p - 0.45) * 18), rp);
      c.drawLine(const Offset(0, 1), Offset(1.5, 1 + (p - 0.45) * 14), rp);
    }
    if (p > 0.7) {
      c.drawLine(const Offset(0, -4), Offset(0, -4 - (p - 0.7) / 0.3 * 14),
        Paint()..color = const Color(0xFF8BC34A)..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round);
    }
  }

  // ── 새싹 ──────────────────────────────────────────────────────────────────
  void _sprout(Canvas c, double p) {
    final h = _l(12, 60, p), w = _l(1.8, 3.0, p);
    c.rotate(math.sin(wt * 1.2) * 0.02 * p);

    final col = Color.lerp(const Color(0xFF8BC34A), const Color(0xFF8D6E63), p * 0.3)!;
    c.drawLine(Offset.zero, Offset(0, -h),
      Paint()..color = col..strokeWidth = w..strokeCap = StrokeCap.round);

    if (p < 0.35) {
      final sz = _l(4, 10, p / 0.35);
      for (final s in [-1.0, 1.0]) {
        c.save(); c.translate(0, -h * 0.8); c.rotate(s * 0.7);
        c.drawOval(Rect.fromCenter(center: Offset(s * sz * 0.5, 0),
          width: sz, height: sz * 0.6),
          Paint()..color = const Color(0xFF9CCC65));
        c.restore();
      }
    } else {
      final n = (p * 5).ceil().clamp(1, 5);
      final ls = _l(6, 14, _m(p, 0.35, 1.0));
      for (int i = 0; i < n; i++) {
        c.save();
        c.translate(0, -h * (0.5 + i * 0.09));
        c.rotate((i.isEven ? -1.0 : 1.0) * _l(0.4, 0.8, i / 5)
               + math.sin(wt * 2 + i) * 0.03);
        _leaf(c, ls * (1 - i * 0.06), 1.0, _sn.lc, true);
        c.restore();
      }
    }
  }

  // ── 나무 전체 ─────────────────────────────────────────────────────────────
  void _tree(Canvas c) {
    final tp = _m(g, 0.15, 0.70);
    final th = _l(60, 220, tp), tw = _l(3, 30, tp);
    final sway = math.sin(wt * 0.6) * 0.018 * _l(0.5, 1.0, tp);
    c.rotate(sway);

    _trunk(c, th, tw);
    c.translate(math.sin(sway) * th * 0.04, -th);

    final bm = _m(g, 0.20, 0.75);
    // ▼ 최적화: 최대 깊이 4, 항상 2분기
    final md = bm < 0.1 ? 0 : bm < 0.3 ? 1 : bm < 0.55 ? 2 : bm < 0.8 ? 3 : 4;
    final bl = _l(18, 100, bm);

    _la = _m(g, 0.12, 0.40) * _sn.ld;
    _fa = g >= 0.70 ? _m(g, 0.70, 0.82) * _sn.bs : 0;
    _ra = g >= 0.82 ? _m(g, 0.82, 0.95) * _sn.fs : 0;

    final ripe = _m(g, 0.88, 1.0) * _m(_sn.fs, 0.3, 1.0);
    _rc = Color.lerp(
      Color.lerp(const Color(0xFF7CB342), const Color(0xFFFDD835), ripe * 0.5)!,
      const Color(0xFFC62828), (ripe * 2 - 1).clamp(0.0, 1.0))!;

    // ▼ 최적화: 최대 5개 주지
    if (md > 0) {
      final sc = _l(2, 5, bm).round().clamp(2, 5);
      final rng = math.Random(42);
      for (int i = 0; i < sc; i++) {
        final hr = (i + 1) / (sc + 1);
        final ba = (i.isEven ? -1.0 : 1.0) * _l(0.75, 0.35, hr);
        c.save();
        c.translate(0, th * hr * 0.12);
        c.rotate(ba + math.sin(wt * (0.7 + i * 0.13) + i * 1.7) * 0.02
                    + (rng.nextDouble() - 0.5) * 0.08);
        _branch(c, md, bl * _l(1.0, 0.45, hr), tw * _l(0.55, 0.25, hr), i * 7 + 3);
        c.restore();
      }
      if (bm > 0.3) {
        c.save();
        c.rotate(math.sin(wt * 0.5) * 0.012);
        _branch(c, (md - 1).clamp(0, 4), bl * 0.35, tw * 0.2, 99);
        c.restore();
      }
    }

    if (bm < 0.3 && _la > 0) { _termLeaves(c, _la * (1 - bm / 0.3), 0); }
    if (_fa > 0.2 && _sn.bs > 0.2) { _petals(c, th); }
  }

  // ── 줄기 (간소화: 비늘·이끼 제거, 균열 축소) ─────────────────────────────
  void _trunk(Canvas c, double h, double w) {
    final baseCol = Color.lerp(
      const Color(0xFF7CB342), const Color(0xFF4E342E), _m(g, 0.15, 0.35))!;
    final lightCol = Color.lerp(
      const Color(0xFF9CCC65), const Color(0xFF6D4C41), _m(g, 0.15, 0.35))!;

    final Path tp = Path()
      ..moveTo(-w / 2, 6)
      ..cubicTo(-w * 0.55, -h * 0.25, -w * 0.48, -h * 0.6, -w * 0.22, -h)
      ..lineTo(w * 0.22, -h)
      ..cubicTo(w * 0.48, -h * 0.6, w * 0.55, -h * 0.25, w / 2, 6)
      ..close();
    c.drawPath(tp, Paint()..color = baseCol);

    // 밝은 면
    final Path lp = Path()
      ..moveTo(-w / 2, 6)
      ..cubicTo(-w * 0.55, -h * 0.25, -w * 0.48, -h * 0.6, -w * 0.22, -h)
      ..lineTo(-w * 0.05, -h)..lineTo(-w * 0.05, 6)..close();
    c.drawPath(lp, Paint()..color = lightCol);

    // ▼ 수피 균열 (최대 4개로 제한)
    if (w > 8) {
      final cp = Paint()..color = const Color(0xFF3E2723)..strokeWidth = 0.7
        ..style = PaintingStyle.stroke;
      final rng = math.Random(17);
      final n = (w / 5).floor().clamp(1, 4);
      for (int i = 0; i < n; i++) {
        final x = -w * 0.3 + i * w * 0.17;
        final Path cr = Path()..moveTo(x, rng.nextDouble() * 6);
        double cy = rng.nextDouble() * 6;
        for (int j = 0; j < 3 + rng.nextInt(2); j++) {
          cy -= h / 5 * (0.7 + rng.nextDouble() * 0.4);
          cr.lineTo(x + (rng.nextDouble() * 2 - 1) * 2.5, cy);
        }
        c.drawPath(cr, cp);
      }
    }

    // 하이라이트
    c.drawPath(
      Path()..moveTo(-w * 0.14, 4)
        ..quadraticBezierTo(-w * 0.1, -h * 0.4, -w * 0.07, -h * 0.85),
      Paint()..color = Colors.white.withValues(alpha: 0.07)
        ..strokeWidth = w * 0.14..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round);
  }

  // ── 가지: 2분기, 최대 깊이 4, 그림자 제거 ────────────────────────────────
  void _branch(Canvas c, int d, double len, double th, int seed) {
    if (d <= 0 || len < 4) {
      _termLeaves(c, _la, seed);
      final rng = math.Random(seed * 11 + 3);
      if (rng.nextDouble() < 0.5) {
        if (_fa > 0) { _corymb(c, _fa, seed); }
        if (_ra > 0) { _fruit(c, _ra, _rc, seed); }
      }
      return;
    }

    final rng = math.Random(seed);
    final wind = math.sin(wt * (0.65 + d * 0.12) + seed * 1.3) * 0.02;
    final tx = wind * len * 0.3 + (rng.nextDouble() - 0.5) * 2;

    // ▼ 2차 베지어로 간소화 (cubicTo → quadraticBezierTo)
    final Path bp = Path()..moveTo(0, 0)
      ..quadraticBezierTo(
        tx * 0.5 + (rng.nextDouble() - 0.5) * len * 0.15, -len * 0.5,
        tx, -len);

    final bCol = Color.lerp(
      const Color(0xFF3E2723), const Color(0xFF8D6E63), d / 5.0)!;
    // ▼ 가지 1 draw (그림자 제거)
    c.drawPath(bp, Paint()..color = bCol
      ..strokeWidth = th..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke);

    // ▼ 중간 잎: 긴 가지 1개만
    if (_la > 0 && len > 40 && d >= 3) {
      c.save();
      c.translate(tx * 0.4, -len * 0.4);
      c.rotate((rng.nextDouble() - 0.5) * 1.2 + math.sin(wt * 2 + seed) * 0.03);
      _leaf(c, _l(8, 14, _la), _la, _sn.lc, false);
      c.restore();
    }

    // ▼ 항상 2분기
    c.save();
    c.translate(tx, -len);
    for (int i = 0; i < 2; i++) {
      final cl = len * _l(0.58, 0.7, rng.nextDouble());
      final ct = th * 0.7 * _l(0.85, 1.05, rng.nextDouble());
      final a = (i == 0 ? -1.0 : 1.0) * _l(0.35, 0.6, rng.nextDouble());
      c.save();
      c.rotate(a + wind * 0.4);
      _branch(c, d - 1, cl, ct, seed * 3 + i + 1);
      c.restore();
    }
    c.restore();
  }

  // ── 폴리곤 잎 (6각형, 1-2 draws) ─────────────────────────────────────────
  // 기존 14 draws → 1-2 draws (fill + 선택적 주맥)
  void _leaf(Canvas c, double sz, double a, Color bc, bool detail) {
    if (a < 0.01 || sz < 2) return;
    final Path lf = Path()
      ..moveTo(0, 0)
      ..lineTo(sz * 0.22, -sz * 0.22)
      ..lineTo(sz * 0.55, -sz * 0.26)
      ..lineTo(sz, 0)
      ..lineTo(sz * 0.55, sz * 0.20)
      ..lineTo(sz * 0.22, sz * 0.16)
      ..close();
    c.drawPath(lf, Paint()..color = bc.withValues(alpha: a));
    // 주맥만 (큰 잎 + detail 모드일 때)
    if (detail && sz > 8) {
      c.drawLine(Offset(sz * 0.08, 0), Offset(sz * 0.88, 0),
        Paint()..color = Color.lerp(bc, const Color(0xFF2E7D32), 0.4)!
          .withValues(alpha: a * 0.5)
        ..strokeWidth = 0.6..style = PaintingStyle.stroke);
    }
  }

  // ── 가지 끝 잎다발 / 휴면아 ──────────────────────────────────────────────
  void _termLeaves(Canvas c, double a, int seed) {
    if (a <= 0) {
      if (g > 0.30) { _dormBuds(c, seed); }
      return;
    }
    final rng = math.Random(seed * 11 + 5);
    // ▼ 3-4개 (기존 3-6개)
    final n = 3 + rng.nextInt(2);
    for (int i = 0; i < n; i++) {
      c.save();
      c.rotate((rng.nextDouble() * 2 - 1) * math.pi * 0.75
             + math.sin(wt * 2.1 + seed + i) * 0.04);
      // 미세 색상 변이 (draw call 추가 없이 시각적 풍성함)
      final tint = Color.lerp(_sn.lc, const Color(0xFF1B5E20), (seed + i) % 5 * 0.04)!;
      _leaf(c, _l(8, 16, a) * (0.75 + rng.nextDouble() * 0.5), a, tint, i == 0);
      c.restore();
    }
  }

  // ── 휴면아 (1 draw per bud) ───────────────────────────────────────────────
  void _dormBuds(Canvas c, int seed) {
    final rng = math.Random(seed * 11 + 5);
    for (int i = 0; i < 1 + rng.nextInt(2); i++) {
      c.save();
      c.rotate((rng.nextDouble() * 2 - 1) * 0.4);
      final bs = 2.5 + rng.nextDouble() * 1.5;
      c.drawOval(
        Rect.fromCenter(center: Offset(bs * 0.2, -bs * 0.3),
          width: bs, height: bs * 1.4),
        Paint()..color = const Color(0xFF8D6E63).withValues(alpha: 0.75));
      c.restore();
    }
  }

  // ── 꽃 화서: 중심화 + 2개 측화 (기존 3-5개→2개) ──────────────────────────
  void _corymb(Canvas c, double a, int seed) {
    if (a < 0.01) return;
    final rng = math.Random(seed * 17 + 11);

    // 중심화 (king bloom)
    _blossom(c, a, _l(8, 15, a));

    // ▼ 측화 2개 (기존 3-5개)
    final sa = (a * 0.7).clamp(0.0, 1.0);
    for (int i = 0; i < 2; i++) {
      final ang = (i + 0.5) * math.pi + rng.nextDouble() * 0.5;
      final dist = _l(7, 15, a);
      c.save();
      c.translate(math.cos(ang) * dist, math.sin(ang) * dist);
      _blossom(c, sa, _l(5, 10, sa));
      c.restore();
    }
  }

  // ── 폴리곤 꽃 (5 마름모 꽃잎 + 중심 2원, 7 draws) ────────────────────────
  // 기존 62 draws → 7 draws
  void _blossom(Canvas c, double a, double sz) {
    if (a < 0.01) return;
    c.save();
    c.scale(sz / 12.0);

    // 꽃잎 5장 — 마름모(kite) 형태
    for (int i = 0; i < 5; i++) {
      c.save();
      c.rotate(i * 2 * math.pi / 5 + math.sin(wt * 0.4 + i) * 0.012);
      c.drawPath(
        Path()..moveTo(-4.5, 0)..lineTo(-1, -12)..lineTo(0, -20)
              ..lineTo(1, -12)..lineTo(4.5, 0)..close(),
        Paint()..color = const Color(0xFFFFF0F3).withValues(alpha: a * 0.88));
      c.restore();
    }

    // 수술 집합 (원 1개로 간소화, 기존 20개 개별 draw → 1)
    c.drawCircle(Offset.zero, 4, Paint()
      ..color = Color(0xFFFFD600).withValues(alpha: a * 0.7));
    // 암술 중앙
    c.drawCircle(Offset.zero, 1.8, Paint()
      ..color = Color(0xFFC0CA33).withValues(alpha: a));

    c.restore();
  }

  // ── 과실 (줄기 + 원 + 하이라이트, 3 draws) ───────────────────────────────
  // 기존 ~30 draws → 3 draws
  void _fruit(Canvas c, double a, Color col, int seed) {
    if (a < 0.01) return;
    if (math.Random(seed * 13 + 7).nextDouble() > 0.5) return;

    final r = _l(3, 14, a);

    // 과경
    c.drawLine(Offset(0, -r * 0.3), Offset(0.5, -(r + 4)),
      Paint()..color = Color(0xFF5D4037).withValues(alpha: a)..strokeWidth = 1.2
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    // 과실 본체
    c.drawCircle(Offset(0, r * 0.05), r,
      Paint()..color = col.withValues(alpha: a));
    // 하이라이트
    c.drawCircle(Offset(-r * 0.25, -r * 0.22), r * 0.28,
      Paint()..color = Colors.white.withValues(alpha: a * 0.35));
  }

  // ── 낙화 (5개, 기존 10개) ─────────────────────────────────────────────────
  void _petals(Canvas c, double th) {
    final rng = math.Random(77);
    for (int i = 0; i < 5; i++) {
      final ph = (wt * 0.25 + i * 1.26) % (2 * math.pi);
      final fall = ph / (2 * math.pi);
      final al = (1 - fall) * 0.5;
      if (al < 0.04) continue;

      c.save();
      c.translate(
        (rng.nextDouble() * 2 - 1) * 65 + math.sin(ph * 3 + i) * 16,
        -th * (1 - fall) + fall * 80);
      c.rotate(ph * 2.5 + i);
      // ▼ 마름모 꽃잎 (1 draw, 기존 2)
      c.drawPath(
        Path()..moveTo(0, 0)..lineTo(-3, -6)..lineTo(0, -12)
              ..lineTo(3, -6)..close(),
        Paint()..color = Color(0xFFFCE4EC).withValues(alpha: al));
      c.restore();
    }
  }

  // ── 화분 (공통 토분) ──────────────────────────────────────────────────────
  void _pot(Canvas c) => PlantPot.draw(c);

  @override
  bool shouldRepaint(AppleTreePainter o) =>
      o.g != g || o.wt != wt || o.month != month;
}
