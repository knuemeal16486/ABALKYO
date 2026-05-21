import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import 'plant3d/engine.dart';
import 'plant3d/plant_builder.dart';

/// 식물 3D 뷰어 — My Oasis 스타일 힐링 분위기
/// · 가로 드래그 360° 회전, 두 번 탭으로 정면 복귀
/// · ClipRect으로 다른 UI 침범 방지
/// · 하단 아이소메트릭 그라운드 글로우 + 배경 방사광
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

class _PlantViewState extends State<PlantView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _yaw = 0;

  Scene? _scene;
  int? _cgrowth;
  int? _cseed;
  PlantType? _ctype;
  int? _cmonth;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 16))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Scene _ensureScene() {
    final month = DateTime.now().month;
    if (_scene == null ||
        _cgrowth != widget.growthLevel ||
        _cseed != widget.seed ||
        _ctype != widget.type ||
        _cmonth != month) {
      _scene = buildPlantScene(
          widget.type, widget.growthLevel / 100.0, widget.seed, month);
      _cgrowth = widget.growthLevel;
      _cseed = widget.seed;
      _ctype = widget.type;
      _cmonth = month;
    }
    return _scene!;
  }

  @override
  Widget build(BuildContext context) {
    final scene = _ensureScene();
    // ClipRect: 식물이 다른 UI 영역을 절대 침범하지 않음
    return ClipRect(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) =>
            setState(() => _yaw += d.delta.dx * 0.012),
        onDoubleTap: () => setState(() => _yaw = 0),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) => CustomPaint(
            painter: _ScenePainter(scene, _yaw, _ctrl.value),
            size: Size.infinite,
          ),
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
    // 화분 접지점 Y — 아래에 충분한 여백 확보
    final groundY = size.height - 88 * fit;

    // ── 1. 배경 방사 환경광 (My Oasis 스타일 소프트 백라이트) ──────────────
    canvas.drawCircle(
      Offset(cx, groundY - 60 * fit),
      160 * fit,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, groundY - 60 * fit),
          160 * fit,
          [
            const Color(0x18FFFFFF),
            const Color(0x00FFFFFF),
          ],
        ),
    );

    // ── 2. 바닥 그림자/글로우 타원 (My Oasis 아일랜드 그림자) ───────────────
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

    // 아일랜드 하이라이트 (바닥 반사광)
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

    // ── 3. 3D 식물 씬 렌더링 ────────────────────────────────────────────────
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
