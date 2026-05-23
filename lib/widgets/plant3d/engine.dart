import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 경량 3D 엔진
//   · 가지: 베지어 곡선 + 원통형 그라데이션 + 수피 질감(거친 가장자리 + 균열선)
//   · 잎: 이차 베지어 타원 + 비대칭 + 베이스→팁 그라데이션
//   · 풍향 애니메이션, 깊이 정렬(painter's algorithm)
// ═══════════════════════════════════════════════════════════════════════════

// ── 공통 헬퍼 ────────────────────────────────────────────────────────────────
double lp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

double sstep(double a, double b, double t) {
  final x = ((t - a) / (b - a)).clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

class V3 {
  final double x, y, z;
  const V3(this.x, this.y, this.z);

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);

  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) =>
      V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(x * x + y * y + z * z);
  V3 get normalized {
    final l = length;
    return l < 1e-9 ? const V3(0, 1, 0) : V3(x / l, y / l, z / l);
  }

  V3 rotateY(double a) {
    final c = math.cos(a), s = math.sin(a);
    return V3(c * x + s * z, y, -s * x + c * z);
  }

  V3 rotateX(double a) {
    final c = math.cos(a), s = math.sin(a);
    return V3(x, c * y - s * z, s * y + c * z);
  }

  V3 get anyPerp {
    final up = y.abs() > 0.9 ? const V3(1, 0, 0) : const V3(0, 1, 0);
    return cross(up).normalized;
  }

  V3 rotateAxis(V3 k, double angle) {
    final c = math.cos(angle), s = math.sin(angle);
    final kv = k.cross(this);
    final kd = k.dot(this);
    return V3(
      x * c + kv.x * s + k.x * kd * (1 - c),
      y * c + kv.y * s + k.y * kd * (1 - c),
      z * c + kv.z * s + k.z * kd * (1 - c),
    );
  }
}

class PV {
  final Offset s;
  final double z;
  final double scale;
  const PV(this.s, this.z, this.scale);
}

class Cam {
  final double yaw, pitch, focal, cx, cy, camDist;
  final double windT, windAmp, refH;
  final V3 light;

  Cam({
    required this.yaw,
    required this.pitch,
    required this.cx,
    required this.cy,
    this.focal = 1000,
    this.camDist = 800,
    this.windT = 0,
    this.windAmp = 0,
    this.refH = 300,
    V3? light,
  }) : light = light ?? const V3(-0.45, 0.78, 0.45).normalized;

  PV project(V3 p) {
    final hy = (p.y / refH).clamp(0.0, 1.6);
    final wx = math.sin(windT * 1.1 + p.y * 0.012) * windAmp * hy;
    final wz = math.cos(windT * 0.9 + p.y * 0.016) * windAmp * 0.6 * hy;
    var v = V3(p.x + wx, p.y, p.z + wz);
    v = v.rotateY(yaw).rotateX(pitch);
    final zc = v.z + camDist;
    final s = focal / (zc < 1 ? 1 : zc);
    return PV(Offset(cx + v.x * s, cy - v.y * s), v.z, s);
  }

  V3 rotN(V3 n) => n.rotateY(yaw).rotateX(pitch);

  double lambert(V3 modelNormal, {double ambient = 0.60}) {
    final n = rotN(modelNormal);
    final d = n.dot(light).abs();
    return (ambient + (1 - ambient) * d).clamp(0.0, 1.0);
  }
}

// ── 프리미티브 ───────────────────────────────────────────────────────────────
abstract class Prim {
  double depth = 0;
  void project(Cam cam);
  void draw(Canvas c);
}

/// 밝아질 때 흰색 쪽으로 lerp → 채도 유지
Color _shade(Color base, double l) {
  if (l >= 1.0) {
    final t = ((l - 1.0) * 0.55).clamp(0.0, 1.0);
    return Color.fromARGB(
      (base.a * 255).round(),
      ((base.r * 255 + (255 - base.r * 255) * t)).round().clamp(0, 255),
      ((base.g * 255 + (255 - base.g * 255) * t)).round().clamp(0, 255),
      ((base.b * 255 + (255 - base.b * 255) * t)).round().clamp(0, 255),
    );
  }
  return Color.fromARGB(
    (base.a * 255).round(),
    (base.r * 255 * l).round().clamp(0, 255),
    (base.g * 255 * l).round().clamp(0, 255),
    (base.b * 255 * l).round().clamp(0, 255),
  );
}

/// 가지: 베지어 윤곽 + 5-stop 원통형 그라데이션 + 수피 질감
class BranchPrim extends Prim {
  final V3 a, b;
  final double ra, rb;
  final Color color;
  BranchPrim(this.a, this.b, this.ra, this.rb, this.color);

  late Offset _sa, _sb, _perp;
  late double _ras, _rbs;
  late Color _col;
  late Offset _cp1s, _cp2s; // 화면공간 베지어 제어점 (재사용)

  // ── 결정론적 해시 노이즈 [0,1) — 3D 좌표 기반이라 회전해도 안정적 ──
  static double _n(double x, double y) {
    final h = (x * 127.1 + y * 311.7).abs();
    return (math.sin(h) * 43758.5453).abs() % 1.0;
  }

  // 3차 베지어 위의 점 계산
  static Offset _beval(
      Offset pa, Offset cp1, Offset cp2, Offset pb, double t) {
    final mt = 1 - t;
    return Offset(
      mt * mt * mt * pa.dx +
          3 * mt * mt * t * cp1.dx +
          3 * mt * t * t * cp2.dx +
          t * t * t * pb.dx,
      mt * mt * mt * pa.dy +
          3 * mt * mt * t * cp1.dy +
          3 * mt * t * t * cp2.dy +
          t * t * t * pb.dy,
    );
  }

  @override
  void project(Cam cam) {
    final pa = cam.project(a), pb = cam.project(b);
    _sa = pa.s;
    _sb = pb.s;
    depth = (pa.z + pb.z) * 0.5;
    _ras = ra * pa.scale;
    _rbs = rb * pb.scale;
    var dir = _sb - _sa;
    final len = dir.distance;
    dir = len < 1e-3 ? const Offset(0, -1) : dir / len;
    _perp = Offset(-dir.dy, dir.dx);
    // 베지어 제어점 캐싱 (draw/bark 에서 재사용)
    _cp1s = _sa + dir * (len * 0.33);
    _cp2s = _sa + dir * (len * 0.67);
    final dl = (0.50 + depth / 650).clamp(0.38, 1.0);
    _col = _shade(color, dl);
  }

  @override
  void draw(Canvas c) {
    if (_ras < 0.22 && _rbs < 0.22) return;
    final len = (_sb - _sa).distance;
    if (len < 0.3) return;

    // ── 메인 가지 몸통 ──────────────────────────────────────────────
    final path = Path()
      ..moveTo(_sa.dx + _perp.dx * _ras, _sa.dy + _perp.dy * _ras)
      ..cubicTo(
        _cp1s.dx + _perp.dx * _ras, _cp1s.dy + _perp.dy * _ras,
        _cp2s.dx + _perp.dx * _rbs, _cp2s.dy + _perp.dy * _rbs,
        _sb.dx + _perp.dx * _rbs,   _sb.dy + _perp.dy * _rbs,
      )
      ..lineTo(_sb.dx - _perp.dx * _rbs, _sb.dy - _perp.dy * _rbs)
      ..cubicTo(
        _cp2s.dx - _perp.dx * _rbs, _cp2s.dy - _perp.dy * _rbs,
        _cp1s.dx - _perp.dx * _ras, _cp1s.dy - _perp.dy * _ras,
        _sa.dx - _perp.dx * _ras,   _sa.dy - _perp.dy * _ras,
      )
      ..close();

    final maxR = math.max(_ras, _rbs);
    final mid  = Offset((_sa.dx + _sb.dx) * 0.5, (_sa.dy + _sb.dy) * 0.5);
    final pLen = maxR * 1.18;

    c.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(mid.dx + _perp.dx * pLen, mid.dy + _perp.dy * pLen),
          Offset(mid.dx - _perp.dx * pLen, mid.dy - _perp.dy * pLen),
          [
            _shade(_col, 0.28), _shade(_col, 0.65),
            _shade(_col, 1.50), _shade(_col, 0.68), _shade(_col, 0.30),
          ],
          [0.0, 0.18, 0.40, 0.70, 1.0],
        ),
    );

    // ── 수피 질감 ────────────────────────────────────────────────────
    _drawBark(c, maxR);

    // ── 스페큘러 하이라이트 ──────────────────────────────────────────
    if (maxR > 1.6) {
      c.drawPath(
        Path()
          ..moveTo(
            _sa.dx + _perp.dx * _ras * 0.08,
            _sa.dy + _perp.dy * _ras * 0.08,
          )
          ..cubicTo(
            _cp1s.dx + _perp.dx * _ras * 0.10,
            _cp1s.dy + _perp.dy * _ras * 0.10,
            _cp2s.dx + _perp.dx * _rbs * 0.13,
            _cp2s.dy + _perp.dy * _rbs * 0.13,
            _sb.dx + _perp.dx * _rbs * 0.13,
            _sb.dy + _perp.dy * _rbs * 0.13,
          ),
        Paint()
          ..color = const Color(0x20FFFFFF)
          ..strokeWidth = maxR * 0.26
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// 수피 질감: 거친 가장자리 선 + 세로 균열
  void _drawBark(Canvas c, double maxR) {
    // 3D 좌표 기반 시드 — 카메라 회전해도 같은 패턴 유지
    final sx = a.x * 73.7 + a.z * 31.3;
    final sy = b.x * 17.9 + b.z * 41.1;

    // 1. 거친 실루엣 가장자리
    const edgeSteps = 10;
    final jitter = maxR * 0.12;
    for (final side in [1.0, -1.0]) {
      final ep = Path();
      for (int i = 0; i <= edgeSteps; i++) {
        final t = i / edgeSteps;
        final bp = _beval(_sa, _cp1s, _cp2s, _sb, t);
        final curR = lp(_ras, _rbs, t);
        final noise =
            (_n(sx + i * 7.3 + side * 99.1, sy + i * 11.7) - 0.5) * jitter;
        final px = bp.dx + _perp.dx * (curR * side + noise);
        final py = bp.dy + _perp.dy * (curR * side + noise);
        if (i == 0) ep.moveTo(px, py);
        else ep.lineTo(px, py);
      }
      c.drawPath(
        ep,
        Paint()
          ..color = _shade(_col, side > 0 ? 0.30 : 0.18)
              .withValues(alpha: 0.38)
          ..strokeWidth = maxR * 0.14
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // 2. 세로 수피 균열선 (굵은 가지에서만)
    if (maxR > 2.6) {
      final numCracks = (maxR / 5.5).floor().clamp(1, 4);
      for (int ci = 0; ci < numCracks; ci++) {
        final crackOff =
            (numCracks > 1 ? ci / (numCracks - 1.0) - 0.5 : 0.0) *
                maxR * 0.80;
        final cp = Path();
        for (int j = 0; j <= 8; j++) {
          final t = j / 8.0;
          final bp = _beval(_sa, _cp1s, _cp2s, _sb, t);
          final noise = (_n(sx + ci * 23.1 + j * 9.3,
                          sy + ci * 11.5 + j * 4.7) -
                      0.5) *
                  maxR *
                  0.13;
          final px = bp.dx + _perp.dx * (crackOff + noise);
          final py = bp.dy + _perp.dy * (crackOff + noise);
          if (j == 0) cp.moveTo(px, py);
          else cp.lineTo(px, py);
        }
        c.drawPath(
          cp,
          Paint()
            ..color = _shade(_col, 0.16).withValues(alpha: 0.34)
            ..strokeWidth = 0.60
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }
}

/// 잎·꽃잎·화분면 — 4점 베지어 타원형, 3점 직선
class QuadPrim extends Prim {
  final List<V3> v;
  final V3 normal;
  final Color color;
  final Color? veinColor;
  QuadPrim(this.v, this.normal, this.color, {this.veinColor});

  late List<Offset> _s;
  late Color _c;
  Offset? _veinA, _veinB;

  @override
  void project(Cam cam) {
    _s = List<Offset>.filled(v.length, Offset.zero);
    double zSum = 0;
    for (int i = 0; i < v.length; i++) {
      final pv = cam.project(v[i]);
      _s[i] = pv.s;
      zSum += pv.z;
    }
    depth = zSum / v.length;
    _c = _shade(color, cam.lambert(normal));
    if (veinColor != null && v.length >= 3) {
      _veinA = _s[0];
      _veinB = _s[(v.length / 2).floor()];
    }
  }

  @override
  void draw(Canvas c) {
    final path = _bezierPath();
    if (veinColor != null && _s.length >= 4) {
      final base = _s[0];
      final tip  = _s[2];
      c.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            base, tip,
            [_shade(_c, 0.72), _c, _shade(_c, 1.14)],
            [0.0, 0.45, 1.0],
          ),
      );
      if (_veinA != null) {
        c.drawLine(
          _veinA!, _veinB!,
          Paint()
            ..color = veinColor!.withValues(alpha: 0.50)
            ..strokeWidth = 0.90
            ..strokeCap = StrokeCap.round,
        );
      }
    } else {
      c.drawPath(path, Paint()..color = _c);
    }
  }

  Path _bezierPath() {
    if (_s.length != 4) {
      final path = Path()..moveTo(_s[0].dx, _s[0].dy);
      for (int i = 1; i < _s.length; i++) path.lineTo(_s[i].dx, _s[i].dy);
      return path..close();
    }
    final base = _s[0];
    final lft  = _s[1];
    final tip  = _s[2];
    final rgt  = _s[3];
    return Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(lft.dx, lft.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(rgt.dx, rgt.dy, base.dx, base.dy)
      ..close();
  }
}

/// 구체 빌보드 (열매·꽃 중심)
class SpherePrim extends Prim {
  final V3 center;
  final double radius;
  final Color color;
  final bool glossy;
  SpherePrim(this.center, this.radius, this.color, {this.glossy = true});

  late Offset _c;
  late double _r;

  @override
  void project(Cam cam) {
    final p = cam.project(center);
    _c = p.s;
    _r = radius * p.scale;
    depth = p.z;
  }

  @override
  void draw(Canvas c) {
    if (_r < 0.5) return;
    if (glossy) {
      c.drawCircle(
        _c, _r * 2.4,
        Paint()
          ..color = color.withValues(alpha: 0.16)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _r * 1.4),
      );
      final hl = _c + Offset(-_r * 0.30, -_r * 0.35);
      c.drawCircle(
        _c, _r,
        Paint()
          ..shader = ui.Gradient.radial(hl, _r * 1.4, [
            _shade(color, 1.55), color, _shade(color, 0.55),
          ], [0.0, 0.40, 1.0]),
      );
      c.drawCircle(
        _c + Offset(-_r * 0.26, -_r * 0.30), _r * 0.22,
        Paint()..color = const Color(0xAAFFFFFF),
      );
    } else {
      c.drawCircle(
        _c, _r * 1.7,
        Paint()
          ..color = color.withValues(alpha: 0.12)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _r * 0.9),
      );
      c.drawCircle(_c, _r, Paint()..color = color);
    }
  }
}

// ── 씬 ───────────────────────────────────────────────────────────────────────
class Scene {
  final List<Prim> prims = [];
  void add(Prim p) => prims.add(p);

  void render(Canvas canvas, Cam cam) {
    for (final p in prims) p.project(cam);
    prims.sort((a, b) => a.depth.compareTo(b.depth));
    for (final p in prims) p.draw(canvas);
  }
}
