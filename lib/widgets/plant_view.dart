import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import 'plant3d/engine.dart';
import 'plant3d/plant_builder.dart';

/// 식물을 실제 3D로 렌더링. 가로 드래그로 360° 회전(yaw), 두 번 탭하면 정면 복귀.
/// 3D 씬(가지·잎 모델 좌표)은 성장도/시드/종류가 바뀔 때만 재생성하고,
/// 매 프레임에는 카메라 회전·바람·투영만 적용해 최적화한다.
class PlantView extends StatefulWidget {
  final PlantType type;
  final int growthLevel; // 0~100
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
    return GestureDetector(
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
    );
  }
}

class _ScenePainter extends CustomPainter {
  final Scene scene;
  final double yaw;
  final double windPhase; // 0~1
  _ScenePainter(this.scene, this.yaw, this.windPhase);

  @override
  void paint(Canvas canvas, Size size) {
    // 식물 영역 높이에 맞춰 균일 스케일 (작은 영역에서도 잘리지 않게)
    final fit = (size.height / 580).clamp(0.45, 2.0);
    final cam = Cam(
      yaw: yaw,
      pitch: 0.42,
      focal: 720 * fit,
      camDist: 900,
      cx: size.width / 2,
      cy: size.height * 0.80,
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
