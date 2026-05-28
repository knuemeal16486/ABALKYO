import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── 보간 헬퍼 ────────────────────────────────────────────────────────────────
double lp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

double sstep(double a, double b, double t) {
  final x = ((t - a) / (b - a)).clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

// ── 폴리곤 드로잉 ─────────────────────────────────────────────────────────────

/// 삼각형 1개
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

/// 볼록 다각형
void poly(Canvas c, List<Offset> pts, Color col) {
  if (pts.length < 3) return;
  final p = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (int i = 1; i < pts.length; i++) p.lineTo(pts[i].dx, pts[i].dy);
  p.close();
  c.drawPath(p, Paint()..color = col);
}

/// n각형 (정다각형 근사)
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

/// 4각형 (사다리꼴 / 직사각형)
void quad(Canvas c, Offset tl, Offset tr, Offset br, Offset bl, Color col) {
  poly(c, [tl, tr, br, bl], col);
}

// ── 식물 공통 요소 ────────────────────────────────────────────────────────────

/// 테라코타 화분 (사다리꼴 폴리곤)
void drawPot(Canvas c, Offset ground, double fit) {
  final cx = ground.dx;
  final gy = ground.dy;

  const rimH  = 9.0;
  const bodyH = 52.0;
  const rimW  = 62.0;
  const bodyBotW = 42.0;

  // 화분 몸통 (어두운 면, 밝은 면, 전면)
  final bL = Offset(cx - rimW * fit, gy);
  final bR = Offset(cx + rimW * fit, gy);
  final bBL = Offset(cx - bodyBotW * fit, gy + bodyH * fit);
  final bBR = Offset(cx + bodyBotW * fit, gy + bodyH * fit);

  // 몸통 왼쪽 면 (그림자)
  tri(c, bL, bBL, Offset(cx, gy + bodyH * fit), const Color(0xFF8B4513));
  // 몸통 오른쪽 면 (하이라이트)
  tri(c, bR, bBR, Offset(cx, gy + bodyH * fit), const Color(0xFFE8956D));
  // 몸통 전면
  quad(c, bL, bR, bBR, bBL, const Color(0xFFCD8055));

  // 화분 테두리 (림)
  final rL = Offset(cx - (rimW + 6) * fit, gy - rimH * fit);
  final rR = Offset(cx + (rimW + 6) * fit, gy - rimH * fit);
  quad(c, rL, rR, bR, bL, const Color(0xFFE8B080));

  // 흙
  c.drawOval(
    Rect.fromCenter(
        center: Offset(cx, gy - rimH * fit + 2 * fit),
        width: rimW * 1.9 * fit,
        height: rimH * 1.1 * fit),
    Paint()..color = const Color(0xFF3D2010),
  );
}

/// 잎 하나 — 삼각형 2–3개 조합 (low-poly 스타일)
/// [base]: 잎자루 끝 (줄기 붙는 지점)
/// [tipX/tipY]: 잎 끝 위치
/// [width]: 최대 폭 (leaf 중간 너비)
void leafPoly(Canvas c, Offset base, Offset tip, double width,
    {Color front = const Color(0xFF66BB6A),
    Color mid = const Color(0xFF43A047),
    Color back = const Color(0xFF2E7D32)}) {
  final dx = tip.dx - base.dx;
  final dy = tip.dy - base.dy;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 1) return;

  // 수직 방향
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

  // 뒤쪽 삼각형 (어두운)
  tri(c, base, rightPt, tip, back);
  // 앞쪽 삼각형 (밝은)
  tri(c, base, leftPt, tip, front);
  // 중간 하이라이트
  tri(c, leftPt, midPt, tip, mid);
}

// ── 바람 흔들림 ───────────────────────────────────────────────────────────────

/// 높이 비율(0–1)과 windPhase(0–1)로 흔들림 각도(라디안) 반환
double windSway(double windPhase, double heightFrac, double amp) {
  return math.sin(windPhase * math.pi * 2) * amp * 0.012 * heightFrac;
}

// ── 시들기 오버레이 ───────────────────────────────────────────────────────────

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

// ── 씨앗 공통 ─────────────────────────────────────────────────────────────────

void drawSeed(Canvas c, Offset ground, double fit, double alpha) {
  if (alpha <= 0) return;
  final cx = ground.dx;
  final gy = ground.dy;
  // 작은 씨앗: 타원 3개
  final p = Paint()..color = const Color(0xFF8D6E63).withValues(alpha: alpha);
  c.drawOval(Rect.fromCenter(center: Offset(cx, gy - 6 * fit), width: 10 * fit, height: 7 * fit), p);
  c.drawOval(Rect.fromCenter(center: Offset(cx - 5 * fit, gy - 3 * fit), width: 6 * fit, height: 4 * fit), p..color = const Color(0xFF6D4C41).withValues(alpha: alpha));
  c.drawOval(Rect.fromCenter(center: Offset(cx + 5 * fit, gy - 3 * fit), width: 6 * fit, height: 4 * fit), p);
}

// ── 줄기 세그먼트 (사다리꼴 3면) ──────────────────────────────────────────────

/// 줄기 세그먼트 하나 그리기
/// [bot]: 아랫면 중심, [top]: 윗면 중심
/// [wBot]/[wTop]: 아래/위 반폭
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

  // 왼쪽 면 (하이라이트)
  tri(c, bL, tL, bot, const Color(0xFF9A6035));
  // 오른쪽 면 (그림자)
  tri(c, bR, tR, bot, const Color(0xFF4A2810));
  // 전면
  quad(c, bL, tL, tR, bR, const Color(0xFF6B4226));
}
