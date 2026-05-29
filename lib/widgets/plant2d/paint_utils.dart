import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── 보간 헬퍼 ────────────────────────────────────────────────────────────────
double lp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

double sstep(double a, double b, double t) {
  final x = ((t - a) / (b - a)).clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

// ── 레거시 폴리곤 드로잉 (기존 호환) ──────────────────────────────────────────

void tri(Canvas c, Offset a, Offset b, Offset pt, Color col) {
  c.drawPath(
    Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(pt.dx, pt.dy)
      ..close(),
    Paint()..color = col,
  );
}

void poly(Canvas c, List<Offset> pts, Color col) {
  if (pts.length < 3) return;
  final p = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (int i = 1; i < pts.length; i++) { p.lineTo(pts[i].dx, pts[i].dy); }
  p.close();
  c.drawPath(p, Paint()..color = col);
}

void ngon(Canvas c, Offset center, double r, int n, Color col,
    {double startAngle = 0}) {
  final pts = List.generate(
    n,
    (i) => Offset(
      center.dx + r * math.cos(startAngle + 2 * math.pi * i / n),
      center.dy + r * math.sin(startAngle + 2 * math.pi * i / n),
    ),
  );
  poly(c, pts, col);
}

void quad(Canvas c, Offset tl, Offset tr, Offset br, Offset bl, Color col) {
  poly(c, [tl, tr, br, bl], col);
}

// ── 사실적 드로잉 유틸리티 ────────────────────────────────────────────────────

/// 베지어 곡선 잎 — 부드러운 타원형 윤곽 + LinearGradient + 잎맥
void botanicalLeaf(
  Canvas c,
  Offset base,
  Offset tip,
  double maxWidth,
  Color lightColor,
  Color darkColor, {
  bool vein = true,
  Color? veinColor,
}) {
  final dx = tip.dx - base.dx;
  final dy = tip.dy - base.dy;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 1) return;

  // 잎 폭 방향 수직 벡터
  final px = -dy / len;
  final py = dx / len;

  // 최대 폭 위치: 기저에서 40%
  final wX = base.dx + dx * 0.4;
  final wY = base.dy + dy * 0.4;

  final leftCtrl = Offset(wX + px * maxWidth * 1.1, wY + py * maxWidth * 1.1);
  final rightCtrl = Offset(wX - px * maxWidth * 1.1, wY - py * maxWidth * 1.1);

  final path = Path()..moveTo(base.dx, base.dy);
  path.quadraticBezierTo(leftCtrl.dx, leftCtrl.dy, tip.dx, tip.dy);
  path.quadraticBezierTo(rightCtrl.dx, rightCtrl.dy, base.dx, base.dy);
  path.close();

  final rect = Rect.fromPoints(
    Offset(base.dx - maxWidth, base.dy - maxWidth),
    Offset(tip.dx + maxWidth, tip.dy + maxWidth),
  );

  c.drawPath(
    path,
    Paint()
      ..shader = LinearGradient(
        colors: [lightColor, darkColor],
        begin: Alignment(-px.abs(), -py.abs()),
        end: Alignment(px.abs(), py.abs()),
      ).createShader(rect),
  );

  if (vein) {
    final vc = veinColor ?? darkColor.withValues(alpha: 0.45);
    c.drawLine(base, tip,
        Paint()
          ..color = vc
          ..strokeWidth = (maxWidth * 0.12).clamp(0.6, 1.4)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    // 측맥 2쌍
    for (final t in [0.35, 0.6]) {
      final mp = Offset(base.dx + dx * t, base.dy + dy * t);
      for (final side in [-1.0, 1.0]) {
        final tipVein = Offset(
          mp.dx + px * maxWidth * 0.55 * side + dx * 0.15,
          mp.dy + py * maxWidth * 0.55 * side + dy * 0.15,
        );
        c.drawLine(mp, tipVein,
            Paint()
              ..color = vc
              ..strokeWidth = 0.55
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round);
      }
    }
  }
}

/// 광택 열매 — RadialGradient + 스페큘러 하이라이트
void glossyFruit(
  Canvas c,
  Offset center,
  double r,
  Color baseColor,
  Color shadowColor,
  Color hiColor,
) {
  final rect = Rect.fromCircle(center: center, radius: r);
  c.drawCircle(
    center,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        radius: 0.9,
        colors: [hiColor.withValues(alpha: 0.55), baseColor, shadowColor],
        stops: const [0.0, 0.42, 1.0],
      ).createShader(rect),
  );
  // 스페큘러 하이라이트
  c.drawCircle(
    Offset(center.dx - r * 0.27, center.dy - r * 0.27),
    r * 0.19,
    Paint()..color = Colors.white.withValues(alpha: 0.52),
  );
}

/// 꽃잎 하나 — cubicTo 베지어 타원형, 각도는 라디안
void petal(
  Canvas c,
  Offset attach,
  double len,
  double width,
  double angle,
  Color lightColor,
  Color darkColor,
) {
  c.save();
  c.translate(attach.dx, attach.dy);
  c.rotate(angle);

  final path = Path()..moveTo(0, 0);
  path.cubicTo(-width * 0.55, -len * 0.28, -width * 0.38, -len * 0.82, 0, -len);
  path.cubicTo(width * 0.38, -len * 0.82, width * 0.55, -len * 0.28, 0, 0);
  path.close();

  c.drawPath(
    path,
    Paint()
      ..shader = LinearGradient(
        colors: [lightColor, darkColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(-width, -len, width * 2, len)),
  );
  c.restore();
}

/// 수채화풍 잎 무더기 (수관용) — 여러 원을 투명하게 겹쳐 깊이감
void foliageBlob(
  Canvas c,
  Offset center,
  double r,
  List<Color> shades,
  math.Random rng,
  double windLean,
) {
  // 메인 원
  c.drawCircle(
    Offset(center.dx + windLean * r * 0.08, center.dy),
    r,
    Paint()..color = shades[0 % shades.length].withValues(alpha: 0.88),
  );
  // 작은 보조 원 3–4개
  final count = 3 + rng.nextInt(2);
  for (int i = 0; i < count; i++) {
    final angle = rng.nextDouble() * math.pi * 2;
    final dist = r * (0.35 + rng.nextDouble() * 0.35);
    final sr = r * (0.45 + rng.nextDouble() * 0.3);
    final sc = Offset(
      center.dx + math.cos(angle) * dist + windLean * r * 0.06,
      center.dy + math.sin(angle) * dist,
    );
    c.drawCircle(
      sc,
      sr,
      Paint()
        ..color = shades[i % shades.length].withValues(alpha: 0.78),
    );
  }
}

/// 나무껍질 가지/줄기 — 굵은 선 + 측면 음영 + 선택적 껍질 줄무늬
void barkBranch(
  Canvas c,
  Offset from,
  Offset to,
  double thick,
  Color bark,
  Color barkDark, {
  bool lenticels = false,
  math.Random? rng,
}) {
  final dx = to.dx - from.dx;
  final dy = to.dy - from.dy;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 0.5) return;
  final px = -dy / len;
  final py = dx / len;

  // 기본 줄기
  final fromL = Offset(from.dx + px * thick, from.dy + py * thick);
  final fromR = Offset(from.dx - px * thick, from.dy - py * thick);
  final toL = Offset(to.dx + px * thick * 0.7, to.dy + py * thick * 0.7);
  final toR = Offset(to.dx - px * thick * 0.7, to.dy - py * thick * 0.7);

  final path = Path()
    ..moveTo(fromL.dx, fromL.dy)
    ..lineTo(toL.dx, toL.dy)
    ..lineTo(toR.dx, toR.dy)
    ..lineTo(fromR.dx, fromR.dy)
    ..close();

  final rect = Rect.fromPoints(from - Offset(thick, thick), to + Offset(thick, thick));
  c.drawPath(
    path,
    Paint()
      ..shader = LinearGradient(
        colors: [barkDark.withValues(alpha: 0.5), bark, barkDark.withValues(alpha: 0.7)],
        stops: const [0.0, 0.45, 1.0],
        begin: Alignment(-px, -py),
        end: Alignment(px, py),
      ).createShader(rect),
  );

  // 피목 (가로 선) — 벚꽃 나무껍질 등에 사용
  if (lenticels && rng != null && thick > 3) {
    final lenticelPaint = Paint()
      ..color = barkDark.withValues(alpha: 0.45)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    final count = (len / (thick * 3)).floor().clamp(1, 6);
    for (int i = 1; i <= count; i++) {
      final t = i / (count + 1);
      final mx = from.dx + dx * t;
      final my = from.dy + dy * t;
      final hw = thick * (0.8 + rng.nextDouble() * 0.4);
      c.drawLine(
        Offset(mx + px * hw, my + py * hw),
        Offset(mx - px * hw, my - py * hw),
        lenticelPaint,
      );
    }
  }
}

/// 사실적 화분 — 원통형 3D 느낌의 테라코타 화분
void realisticPot(Canvas c, Offset ground, double fit) {
  final cx = ground.dx;
  final gy = ground.dy;

  const rimW = 60.0;
  const botW = 42.0;
  const bodyH = 52.0;
  const rimH = 10.0;

  final rect = Rect.fromLTRB(
    cx - rimW * fit, gy - rimH * fit,
    cx + rimW * fit, gy + bodyH * fit,
  );

  // 몸통 — LinearGradient로 원통 입체감
  final bodyPath = Path()
    ..moveTo(cx - rimW * fit, gy)
    ..lineTo(cx + rimW * fit, gy)
    ..lineTo(cx + botW * fit, gy + bodyH * fit)
    ..lineTo(cx - botW * fit, gy + bodyH * fit)
    ..close();

  c.drawPath(
    bodyPath,
    Paint()
      ..shader = LinearGradient(
        colors: const [
          Color(0xFF9E5020),
          Color(0xFFCD8055),
          Color(0xFFE8956D),
          Color(0xFFB05C30),
        ],
        stops: const [0.0, 0.25, 0.65, 1.0],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(rect),
  );

  // 화분 테두리 (림)
  final rimPath = Path()
    ..moveTo(cx - (rimW + 7) * fit, gy - rimH * fit)
    ..lineTo(cx + (rimW + 7) * fit, gy - rimH * fit)
    ..lineTo(cx + rimW * fit, gy)
    ..lineTo(cx - rimW * fit, gy)
    ..close();

  c.drawPath(
    rimPath,
    Paint()
      ..shader = LinearGradient(
        colors: const [Color(0xFF8B4513), Color(0xFFE8B080), Color(0xFFCD7040)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTRB(
        cx - (rimW + 7) * fit, gy - rimH * fit,
        cx + (rimW + 7) * fit, gy,
      )),
  );

  // 화분 밑 마감선
  c.drawLine(
    Offset(cx - botW * fit, gy + bodyH * fit),
    Offset(cx + botW * fit, gy + bodyH * fit),
    Paint()
      ..color = const Color(0xFF6B3010)
      ..strokeWidth = 2 * fit,
  );

  // 흙 (타원)
  c.drawOval(
    Rect.fromCenter(
      center: Offset(cx, gy - rimH * fit + 3 * fit),
      width: rimW * 1.85 * fit,
      height: rimH * 1.2 * fit,
    ),
    Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFF5D3A1A), Color(0xFF3D2010)],
        center: Alignment(-0.2, -0.3),
        radius: 0.8,
      ).createShader(Rect.fromCenter(
        center: Offset(cx, gy - rimH * fit + 3 * fit),
        width: rimW * 1.85 * fit,
        height: rimH * 1.2 * fit,
      )),
  );
}

// ── 공통 식물 요소 (기존 유지) ─────────────────────────────────────────────────

void leafPoly(Canvas c, Offset base, Offset tip, double width,
    {Color front = const Color(0xFF66BB6A),
    Color mid = const Color(0xFF43A047),
    Color back = const Color(0xFF2E7D32)}) {
  final dx = tip.dx - base.dx;
  final dy = tip.dy - base.dy;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 1) return;

  final px = -dy / len * width;
  final py = dx / len * width;

  final midPt = Offset(
    (base.dx + tip.dx) / 2 + px * 0.15,
    (base.dy + tip.dy) / 2 + py * 0.15,
  );
  final leftPt = Offset(
    base.dx + dx * 0.42 + px,
    base.dy + dy * 0.42 + py,
  );
  final rightPt = Offset(
    base.dx + dx * 0.42 - px,
    base.dy + dy * 0.42 - py,
  );

  tri(c, base, rightPt, tip, back);
  tri(c, base, leftPt, tip, front);
  tri(c, leftPt, midPt, tip, mid);
}

double windSway(double windPhase, double heightFrac, double amp) {
  return math.sin(windPhase * math.pi * 2) * amp * 0.012 * heightFrac;
}

void drawWiltOverlay(Canvas c, Size size, double wiltFactor) {
  if (wiltFactor <= 0.01) return;
  c.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()
      ..color = const Color(0xFFB8860B)
          .withValues(alpha: (wiltFactor * 0.48).clamp(0, 0.48))
      ..blendMode = BlendMode.srcATop,
  );
}

void drawSeed(Canvas c, Offset ground, double fit, double alpha) {
  if (alpha <= 0) return;
  final cx = ground.dx;
  final gy = ground.dy;
  c.drawOval(
    Rect.fromCenter(center: Offset(cx, gy - 6 * fit), width: 10 * fit, height: 7 * fit),
    Paint()..color = const Color(0xFF8D6E63).withValues(alpha: alpha),
  );
  c.drawOval(
    Rect.fromCenter(center: Offset(cx - 5 * fit, gy - 3 * fit), width: 6 * fit, height: 4 * fit),
    Paint()..color = const Color(0xFF6D4C41).withValues(alpha: alpha),
  );
  c.drawOval(
    Rect.fromCenter(center: Offset(cx + 5 * fit, gy - 3 * fit), width: 6 * fit, height: 4 * fit),
    Paint()..color = const Color(0xFF6D4C41).withValues(alpha: alpha),
  );
}

void trunkSegment(Canvas c, Offset bot, Offset top, double wBot, double wTop) {
  final dx = top.dx - bot.dx;
  final dy = top.dy - bot.dy;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 0.1) return;
  final px = -dy / len;
  final py = dx / len;

  final bL = Offset(bot.dx + px * wBot, bot.dy + py * wBot);
  final bR = Offset(bot.dx - px * wBot, bot.dy - py * wBot);
  final tL = Offset(top.dx + px * wTop, top.dy + py * wTop);
  final tR = Offset(top.dx - px * wTop, top.dy - py * wTop);

  tri(c, bL, tL, bot, const Color(0xFF9A6035));
  tri(c, bR, tR, bot, const Color(0xFF4A2810));
  quad(c, bL, tL, tR, bR, const Color(0xFF6B4226));
}
