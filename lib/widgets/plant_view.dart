import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import 'creature_overlay.dart';
import 'plant3d/engine.dart';
import 'plant3d/plant_builder.dart';

/// 식물 3D 뷰어
///  · 핀치 줌 (0.5× ~ 3.0×) — 두 손가락 벌리기/오므리기
///  · 한 손가락 드래그 → yaw 회전
///  · 더블탭 → 초기화 (yaw=0, zoom=1.0)
///  · ClipRect으로 다른 UI 침범 방지
class PlantView extends StatefulWidget {
  final PlantType type;
  final int growthLevel;
  final int seed;
  const PlantView({
    super.key,
    required this.type,
    required this.growthLevel,
    required this.seed,
  });

  @override
  State<PlantView> createState() => _PlantViewState();
}

class _PlantViewState extends State<PlantView> with TickerProviderStateMixin {
  late final AnimationController _windCtrl;
  late final AnimationController _growCtrl;

  double _yaw = 0;
  double _zoom = 1.0;
  double _zoomBase = 1.0;

  double _fromG = 0;
  double _toG = 0;

  Scene? _scene;
  double? _builtG;
  int? _cseed;
  PlantType? _ctype;
  int? _cmonth;

  @override
  void initState() {
    super.initState();
    _fromG = _toG = widget.growthLevel / 100.0;

    _windCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 16))
          ..repeat();

    _growCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _growCtrl.value = 1.0;
  }

  @override
  void didUpdateWidget(PlantView old) {
    super.didUpdateWidget(old);
    if (old.type != widget.type || old.seed != widget.seed) {
      _fromG = _toG = widget.growthLevel / 100.0;
      _growCtrl.stop();
      _growCtrl.value = 1.0;
      return;
    }
    if (old.growthLevel != widget.growthLevel) {
      _fromG = _currentG;
      _toG = widget.growthLevel / 100.0;
      _growCtrl.forward(from: 0.0);
    }
  }

  double get _currentG {
    if (_growCtrl.value >= 1.0) return _toG;
    final t = Curves.easeInOutCubic.transform(_growCtrl.value);
    return _fromG + (_toG - _fromG) * t;
  }

  @override
  void dispose() {
    _windCtrl.dispose();
    _growCtrl.dispose();
    super.dispose();
  }

  Scene _ensureScene(double g) {
    final month = DateTime.now().month;
    final gStep = (g * 100).floor();
    final builtStep = _builtG == null ? -1 : (_builtG! * 100).floor();
    if (_scene == null ||
        gStep != builtStep ||
        _cseed != widget.seed ||
        _ctype != widget.type ||
        _cmonth != month) {
      _scene = buildPlantScene(widget.type, g, widget.seed, month);
      _builtG = g;
      _cseed = widget.seed;
      _ctype = widget.type;
      _cmonth = month;
    }
    return _scene!;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => _zoomBase = _zoom,
            onScaleUpdate: (d) => setState(() {
              if (d.pointerCount >= 2) {
                _zoom = (_zoomBase * d.scale).clamp(0.50, 3.2);
              } else {
                _yaw += d.focalPointDelta.dx * 0.010;
              }
            }),
            onDoubleTap: () => setState(() {
              _yaw = 0;
              _zoom = 1.0;
            }),
            child: AnimatedBuilder(
              animation: _windCtrl,
              builder: (_, _) {
                final g = _currentG;
                final scene = _ensureScene(g);
                return Transform.scale(
                  scale: _zoom,
                  alignment: const Alignment(0, 0.45),
                  child: CustomPaint(
                    painter: _ScenePainter(scene, _yaw, _windCtrl.value),
                    size: Size.infinite,
                  ),
                );
              },
            ),
          ),
          // 생물 오버레이
          IgnorePointer(
            child: CreatureOverlay(growthLevel: widget.growthLevel),
          ),
          // 줌 레벨 표시 (기본값 벗어났을 때만)
          if (_zoom < 0.98 || _zoom > 1.02)
            Positioned(
              top: 8,
              right: 10,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(_zoom * 100).round()}%',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          // 힌트 (첫 로드 후 잠깐)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: _ZoomHint(zoom: _zoom),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 줌이 기본값(1.0)일 때만 힌트 표시
class _ZoomHint extends StatelessWidget {
  final double zoom;
  const _ZoomHint({required this.zoom});

  @override
  Widget build(BuildContext context) {
    if (zoom < 0.98 || zoom > 1.02) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: 0.55,
      duration: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '핀치로 확대 · 드래그로 회전 · 더블탭 초기화',
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  final Scene scene;
  final double yaw;
  final double windPhase;
  _ScenePainter(this.scene, this.yaw, this.windPhase);

  @override
  void paint(Canvas canvas, Size size) {
    final fit = (size.height / 580).clamp(0.45, 2.0);
    final cx = size.width / 2;
    // 더 많은 공간 — 식물이 화면에 꽉 참
    final groundY = size.height - 65 * fit;

    // ── 배경 방사 환경광 ─────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx, groundY - 80 * fit),
      190 * fit,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, groundY - 80 * fit),
          190 * fit,
          [const Color(0x20FFFFFF), const Color(0x00FFFFFF)],
        ),
    );

    // ── 바닥 그림자 타원 ─────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY + 24 * fit),
        width: 220 * fit,
        height: 30 * fit,
      ),
      Paint()
        ..color = const Color(0x32000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * fit),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY + 17 * fit),
        width: 160 * fit,
        height: 15 * fit,
      ),
      Paint()
        ..color = const Color(0x10FFFFFF)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * fit),
    );

    // ── 3D 식물 씬 렌더링 ─────────────────────────────────────────────────
    final cam = Cam(
      yaw: yaw,
      pitch: -0.22,         // 조금 더 내려다보는 시점 (was -0.14)
      focal: 1050 * fit,    // 더 크게 (was 900 * fit)
      camDist: 820,         // (was 900)
      cx: cx,
      cy: groundY,
      windT: windPhase * math.pi * 2,
      windAmp: 4.0,
      refH: 240,
    );
    scene.render(canvas, cam);
  }

  @override
  bool shouldRepaint(_ScenePainter o) =>
      o.scene != scene || o.yaw != yaw || o.windPhase != windPhase;
}
