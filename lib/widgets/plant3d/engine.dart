import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 경량 3D 엔진 — CustomPainter 위에서 동작
//   · V3 벡터 + Rodrigues 회전
//   · 원근 투영 카메라(yaw 드래그 회전 + 고정 pitch)
//   · 깊이 정렬(painter's algorithm)
//   · 람베르트 조명(뷰 공간 고정 광원) + 가지 원통 음영
//   · 바람 흔들림(높이 비례)
// ═══════════════════════════════════════════════════════════════════════════

// ── 공통 헬퍼 ────────────────────────────────────────────────────────────────
double lp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

/// 부드러운 계단(연속 성장용): [a,b] 구간을 0→1로 매끄럽게
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

  /// 이 방향에 수직인 단위벡터 하나
  V3 get anyPerp {
    final up = y.abs() > 0.9 ? const V3(1, 0, 0) : const V3(0, 1, 0);
    return cross(up).normalized;
  }

  /// 임의 축(k, 단위벡터) 둘레로 angle 만큼 회전 (Rodrigues)
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

/// 한 점의 투영 결과
class PV {
  final Offset s; // 화면 좌표
  final double z; // 뷰 공간 깊이(클수록 카메라에 가까움)
  final double scale; // 원근 배율
  const PV(this.s, this.z, this.scale);
}

/// 카메라 + 광원 + 바람. 매 프레임 새로 만든다.
class Cam {
  final double yaw, pitch, focal, cx, cy, camDist;
  final double windT, windAmp, refH;
  final V3 light;

  Cam({
    required this.yaw,
    required this.pitch,
    required this.cx,
    required this.cy,
    this.focal = 900,
    this.camDist = 900,
    this.windT = 0,
    this.windAmp = 0,
    this.refH = 300,
    V3? light,
  }) : light = light ?? const V3(-0.45, 0.78, 0.45).normalized;

  PV project(V3 p) {
    // 바람: 높이에 비례해 윗부분이 더 흔들림
    final hy = (p.y / refH).clamp(0.0, 1.6);
    final wx = math.sin(windT * 1.1 + p.y * 0.012) * windAmp * hy;
    final wz = math.cos(windT * 0.9 + p.y * 0.016) * windAmp * 0.6 * hy;
    var v = V3(p.x + wx, p.y, p.z + wz);
    v = v.rotateY(yaw).rotateX(pitch);
    final zc = v.z + camDist;
    final s = focal / (zc < 1 ? 1 : zc);
    return PV(Offset(cx + v.x * s, cy - v.y * s), v.z, s);
  }

  /// 법선을 뷰 공간으로 (이동/바람 무시, 회전만)
  V3 rotN(V3 n) => n.rotateY(yaw).rotateX(pitch);

  Color shade(Color base, V3 modelNormal, {double ambient = 0.45, double shininess = 0, double specIntensity = 0}) {
    final n = rotN(modelNormal);
    final d = n.dot(light).abs();
    final l = (ambient + (1 - ambient) * d).clamp(0.0, 1.0);
    
    int r = (base.r * 255 * l).round().clamp(0, 255);
    int g = (base.g * 255 * l).round().clamp(0, 255);
    int b = (base.b * 255 * l).round().clamp(0, 255);
    
    if (shininess > 0 && specIntensity > 0) {
      final h = (light + const V3(0, 0, 1)).normalized;
      final ndoth = n.dot(h).abs();
      final spec = math.pow(ndoth, shininess) * specIntensity;
      r = (r + 255 * spec).round().clamp(0, 255);
      g = (g + 255 * spec).round().clamp(0, 255);
      b = (b + 255 * spec).round().clamp(0, 255);
    }
    
    return Color.fromARGB((base.a * 255).round(), r, g, b);
  }
}

// ── 프리미티브 ───────────────────────────────────────────────────────────────
abstract class Prim {
  double depth = 0; // 정렬용 (뷰 공간 z 평균)
  void project(Cam cam);
  void draw(Canvas c);
}

Color _shade(Color base, double l) => Color.fromARGB(
      (base.a * 255).round(),
      (base.r * 255 * l).round().clamp(0, 255),
      (base.g * 255 * l).round().clamp(0, 255),
      (base.b * 255 * l).round().clamp(0, 255),
    );

/// 가지: 끝이 가늘어지는 리본 + 원통형(좌→우 명암) 음영
class BranchPrim extends Prim {
  final V3 a, b;
  final double ra, rb;
  final Color color;
  BranchPrim(this.a, this.b, this.ra, this.rb, this.color);

  late Offset _sa, _sb, _perp;
  late double _ras, _rbs;
  late Color _light, _dark;

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
    // 깊이로 약간의 명암 변화 + 원통 음영
    final dl = (0.5 + depth / 600).clamp(0.35, 1.0);
    _light = _shade(color, (dl + 0.25).clamp(0.0, 1.0));
    _dark = _shade(color, (dl - 0.28).clamp(0.0, 1.0));
  }

  @override
  void draw(Canvas c) {
    final lp = _sa + _perp * _ras;
    final lp2 = _sb + _perp * _rbs;
    final rp = _sb - _perp * _rbs;
    final rp2 = _sa - _perp * _ras;
    final path = Path()
      ..moveTo(lp.dx, lp.dy)
      ..lineTo(lp2.dx, lp2.dy)
      ..lineTo(rp.dx, rp.dy)
      ..lineTo(rp2.dx, rp2.dy)
      ..close();
    final mid = (_sa + _sb) * 0.5;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        mid + _perp * (math.max(_ras, _rbs)),
        mid - _perp * (math.max(_ras, _rbs)),
        [_light, _dark],
      );
    c.drawPath(path, paint);
  }
}

/// 곡선 줄기: 여러 점을 이어 하나의 부드러운 패스(관)로 렌더링하여 이음새를 없앱니다.
class CurveStemPrim extends Prim {
  final List<V3> pts;
  final List<double> radii;
  final Color color;
  CurveStemPrim(this.pts, this.radii, this.color);

  late List<Offset> _sPts;
  late List<double> _sRadii;
  late Color _light, _dark;

  @override
  void project(Cam cam) {
    _sPts = [];
    _sRadii = [];
    double zSum = 0;
    for (int i = 0; i < pts.length; i++) {
      final p = cam.project(pts[i]);
      _sPts.add(p.s);
      _sRadii.add(radii[i] * p.scale);
      zSum += p.z;
    }
    depth = zSum / pts.length;
    
    // 깊이 기반 약간의 명암 변화
    final dl = (0.5 + depth / 600).clamp(0.35, 1.0);
    _light = _shade(color, (dl + 0.25).clamp(0.0, 1.0));
    _dark = _shade(color, (dl - 0.28).clamp(0.0, 1.0));
  }

  @override
  void draw(Canvas c) {
    if (_sPts.length < 2) return;
    
    final path = Path();
    // 왼쪽 윤곽선
    for (int i = 0; i < _sPts.length; i++) {
      Offset dir;
      if (i == 0) dir = _sPts[1] - _sPts[0];
      else if (i == _sPts.length - 1) dir = _sPts[i] - _sPts[i - 1];
      else dir = _sPts[i + 1] - _sPts[i - 1];
      final len = dir.distance;
      dir = len < 1e-3 ? const Offset(0, -1) : dir / len;
      final perp = Offset(-dir.dy, dir.dx);
      
      final pt = _sPts[i] + perp * _sRadii[i];
      if (i == 0) path.moveTo(pt.dx, pt.dy);
      else path.lineTo(pt.dx, pt.dy);
    }
    // 오른쪽 윤곽선 (역순)
    for (int i = _sPts.length - 1; i >= 0; i--) {
      Offset dir;
      if (i == 0) dir = _sPts[1] - _sPts[0];
      else if (i == _sPts.length - 1) dir = _sPts[i] - _sPts[i - 1];
      else dir = _sPts[i + 1] - _sPts[i - 1];
      final len = dir.distance;
      dir = len < 1e-3 ? const Offset(0, -1) : dir / len;
      final perp = Offset(-dir.dy, dir.dx);
      
      final pt = _sPts[i] - perp * _sRadii[i];
      path.lineTo(pt.dx, pt.dy);
    }
    path.close();

    final midBase = _sPts.first;
    final midTop = _sPts.last;
    final overallDir = midTop - midBase;
    final dist = overallDir.distance;
    final overallPerp = dist < 1e-3 ? const Offset(1, 0) : Offset(-overallDir.dy, overallDir.dx) / dist;
    final maxR = _sRadii.reduce(math.max);

    final mid = (midBase + midTop) * 0.5;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        mid + overallPerp * maxR,
        mid - overallPerp * maxR,
        [_light, _dark],
      );
    c.drawPath(path, paint);
  }
}

/// 평면 폴리곤(잎·꽃잎·화분면). 법선으로 람베르트 음영, 양면.
class QuadPrim extends Prim {
  final List<V3> v; // 3~4점
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
    _c = cam.shade(color, normal);
    if (veinColor != null && v.length >= 3) {
      _veinA = _s[0];
      _veinB = _s[(v.length / 2).floor()];
    }
  }

  @override
  void draw(Canvas c) {
    final path = Path()..moveTo(_s[0].dx, _s[0].dy);
    for (int i = 1; i < _s.length; i++) {
      path.lineTo(_s[i].dx, _s[i].dy);
    }
    path.close();
    c.drawPath(path, Paint()..color = _c);
    if (_veinA != null) {
      c.drawLine(
          _veinA!,
          _veinB!,
          Paint()
            ..color = veinColor!.withValues(alpha: 0.5)
            ..strokeWidth = 0.8);
    }
  }
}

/// 곡선형 부드러운 잎사귀. 베지에 곡선 활용.
class LeafPrim extends Prim {
  final V3 base;
  final V3 tip;
  final V3 normal;
  final double width;
  final Color color;
  final Color? tipColor;
  final Color? veinColor;
  final double shininess;
  final double specIntensity;
  LeafPrim(this.base, this.tip, this.normal, this.width, this.color, {this.tipColor, this.veinColor, this.shininess = 0, this.specIntensity = 0});

  late Offset _sBase, _sTip, _sCp1, _sCp2;
  late Color _c, _cTip;

  @override
  void project(Cam cam) {
    final pBase = cam.project(base);
    final pTip = cam.project(tip);
    depth = (pBase.z + pTip.z) * 0.5;
    
    final dir = (tip - base).normalized;
    final wDir = dir.cross(normal).normalized;
    final len = (tip - base).length;
    final mid = base + dir * (len * 0.4);
    final cp1 = mid + wDir * (width * 0.5);
    final cp2 = mid - wDir * (width * 0.5);
    
    _sBase = pBase.s;
    _sTip = pTip.s;
    _sCp1 = cam.project(cp1).s;
    _sCp2 = cam.project(cp2).s;
    
    _c = cam.shade(color, normal, shininess: shininess, specIntensity: specIntensity);
    if (tipColor != null) {
      _cTip = cam.shade(tipColor!, normal, shininess: shininess, specIntensity: specIntensity);
    }
  }

  @override
  void draw(Canvas c) {
    final path = Path()
      ..moveTo(_sBase.dx, _sBase.dy)
      ..quadraticBezierTo(_sCp1.dx, _sCp1.dy, _sTip.dx, _sTip.dy)
      ..quadraticBezierTo(_sCp2.dx, _sCp2.dy, _sBase.dx, _sBase.dy)
      ..close();
    
    final paint = Paint();
    if (tipColor != null) {
      paint.shader = ui.Gradient.linear(_sBase, _sTip, [_c, _cTip]);
    } else {
      paint.color = _c;
    }
    c.drawPath(path, paint);
    
    if (veinColor != null) {
      final veinPath = Path()
        ..moveTo(_sBase.dx, _sBase.dy)
        ..quadraticBezierTo((_sBase.dx + _sTip.dx)/2 + (_sCp1.dx - _sCp2.dx)*0.1, (_sBase.dy + _sTip.dy)/2 + (_sCp1.dy - _sCp2.dy)*0.1, _sTip.dx, _sTip.dy);
      c.drawPath(veinPath, Paint()..color = veinColor!.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1.0);
    }
  }
}

/// 바닥에 생기는 부드러운 그림자
class DropShadowPrim extends Prim {
  final V3 center;
  final double radiusX, radiusZ;
  final double alpha;
  DropShadowPrim(this.center, this.radiusX, this.radiusZ, this.alpha) {
    depth = 99999; // 가장 먼저 그려지도록 아주 큰 값 (먼 것)
  }

  late Offset _c;
  late double _rx, _ry;

  @override
  void project(Cam cam) {
    final p = cam.project(center);
    _c = p.s;
    _rx = radiusX * p.scale;
    _ry = radiusZ * p.scale * math.sin(cam.pitch.abs() + 0.1).abs();
    depth = 99999; // 렌더링 시 Z 정렬에서 가장 멀리 배치
  }

  @override
  void draw(Canvas c) {
    if (_rx < 1 || _ry < 1) return;
    final rect = Rect.fromCenter(center: _c, width: _rx * 2, height: _ry * 2);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        _c,
        _rx,
        [Color.fromARGB((200 * alpha).round(), 0, 0, 0), const Color(0x00000000)],
        [0.0, 1.0],
      );
    c.drawOval(rect, paint);
  }
}

/// 구체 느낌의 빌보드(열매·꽃 중심). 위치는 3D, 크기는 원근 배율.
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
      final hl = _c + Offset(-_r * 0.3, -_r * 0.3);
      c.drawCircle(
        _c,
        _r,
        Paint()
          ..shader = ui.Gradient.radial(hl, _r * 1.4, [
            _shade(color, 1.2),
            color,
            _shade(color, 0.6),
          ], [
            0.0,
            0.5,
            1.0
          ]),
      );
    } else {
      c.drawCircle(_c, _r, Paint()..color = color);
    }
  }
}

// ── 씬 ───────────────────────────────────────────────────────────────────────
class Scene {
  final List<Prim> prims = [];
  void add(Prim p) => prims.add(p);

  void render(Canvas canvas, Cam cam) {
    for (final p in prims) {
      p.project(cam);
    }
    prims.sort((a, b) => a.depth.compareTo(b.depth)); // 먼 것(z 작은 것)부터 → painter's algorithm
    for (final p in prims) {
      p.draw(canvas);
    }
  }
}
