import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import 'apple_tree_painter.dart';
import 'sunflower_painter.dart';
import 'succulent_painter.dart';
import 'fern_painter.dart';

/// 식물 종류에 맞는 페인터를 골라 그리는 뷰. 단일 애니메이션 컨트롤러를 공유한다.
class PlantView extends StatefulWidget {
  final PlantType type;
  final int growthLevel; // 0~100
  const PlantView({super.key, required this.type, required this.growthLevel});

  @override
  State<PlantView> createState() => _PlantViewState();
}

class _PlantViewState extends State<PlantView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _rotationY = 0; // 가로 드래그로 식물을 좌우로 돌려본다 (360°)

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 14))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDrag(DragUpdateDetails d) =>
      setState(() => _rotationY += d.delta.dx * 0.012);

  void _resetRotation() => setState(() => _rotationY = 0);

  CustomPainter _painterFor(double g, double wt) {
    switch (widget.type) {
      case PlantType.appleTree:
        return AppleTreePainter(g, wt, DateTime.now().month);
      case PlantType.sunflower:
        return SunflowerPainter(g, wt);
      case PlantType.succulent:
        return SucculentPainter(g, wt);
      case PlantType.fern:
        return FernPainter(g, wt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.growthLevel / 100.0;
    return GestureDetector(
      onHorizontalDragUpdate: _onDrag,
      onDoubleTap: _resetRotation, // 두 번 탭하면 정면으로 복귀
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015) // 원근감
            ..rotateY(_rotationY),
          child: CustomPaint(
            painter: _painterFor(g, _ctrl.value * math.pi * 2),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}
