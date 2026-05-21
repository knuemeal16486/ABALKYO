import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import 'creature_overlay.dart';
import 'plant3d/engine.dart';
import 'plant3d/plant_builder.dart';

/// 식물 3D 뷰어 — 성장 레벨이 바뀌면 1.8초에 걸쳐 부드럽게 자라나는 애니메이션
/// · ClipRect으로 다른 UI 침범 방지
/// · 바닥 환경광/그림자 오버레이
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
  // 바람 애니메이션 (16s 반복)
  late final AnimationController _windCtrl;
  // 성장 전환 애니메이션 (일기 제출 시 구 레벨 → 신 레벨)
  late final AnimationController _growCtrl;

  double _yaw = 0;

  /// 애니메이션 시작 g값 (0.0~1.0)
  double _fromG = 0;
  /// 애니메이션 목표 g값
  double _toG = 0;

  // 씬 캐시
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
    // 초기엔 이미 완성된 상태 (애니메이션 없음)
    _growCtrl.value = 1.0;
  }

  @override
  void didUpdateWidget(PlantView old) {
    super.didUpdateWidget(old);

    // 식물 종류 또는 시드 변경 (수확 후 새 씨앗) → 즉시 전환, 애니메이션 없음
    if (old.type != widget.type || old.seed != widget.seed) {
      _fromG = _toG = widget.growthLevel / 100.0;
      _growCtrl.stop();
      _growCtrl.value = 1.0;
      return;
    }

    // 성장 레벨 변경 → 부드럽게 자라나기
    if (old.growthLevel != widget.growthLevel) {
      _fromG = _currentG; // 현재 표시 중인 g값부터 시작
      _toG = widget.growthLevel / 100.0;
      _growCtrl.forward(from: 0.0);
    }
  }

  /// 현재 표시할 g값 (easeInOutCubic 곡선으로 보간)
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
    // 1% 단위로만 씬 재생성 (애니메이션 중 최대 100회 → 실제론 5~15회 수준)
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
          // 3D 식물 + 제스처
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) =>
                setState(() => _yaw += d.delta.dx * 0.012),
            onDoubleTap: () => setState(() => _yaw = 0),
            child: AnimatedBuilder(
              animation: _windCtrl,
              builder: (_, _) {
                final g = _currentG;
                final scene = _ensureScene(g);
                return CustomPaint(
                  painter: _ScenePainter(scene, _yaw, _windCtrl.value),
                  size: Size.infinite,
                );
              },
            ),
          ),
          // 생물 오버레이 (터치 무시)
          IgnorePointer(
            child: CreatureOverlay(growthLevel: widget.growthLevel),
          ),
        ],
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
    final groundY = size.height - 88 * fit;

    // ── 배경 방사 환경광 (My Oasis 스타일) ──────────────────────────────────
    canvas.drawCircle(
      Offset(cx, groundY - 60 * fit),
      160 * fit,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, groundY - 60 * fit),
          160 * fit,
          [const Color(0x18FFFFFF), const Color(0x00FFFFFF)],
        ),
    );

    // ── 바닥 그림자 타원 ──────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY + 22 * fit),
        width: 200 * fit,
        height: 28 * fit,
      ),
      Paint()
        ..color = const Color(0x28000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 * fit),
    );
    // 반사광 하이라이트
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY + 16 * fit),
        width: 150 * fit,
        height: 14 * fit,
      ),
      Paint()
        ..color = const Color(0x14FFFFFF)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * fit),
    );

    // ── 3D 식물 씬 렌더링 ────────────────────────────────────────────────────
    final cam = Cam(
      yaw: yaw,
      pitch: -0.14,
      focal: 900 * fit,
      camDist: 900,
      cx: cx,
      cy: groundY,
      windT: windPhase * math.pi * 2,
      windAmp: 4.5,
      refH: 230,
    );
    scene.render(canvas, cam);
  }

  @override
  bool shouldRepaint(_ScenePainter o) =>
      o.scene != scene || o.yaw != yaw || o.windPhase != windPhase;
}
