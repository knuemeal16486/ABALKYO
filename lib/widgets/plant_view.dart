import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import 'creature_overlay.dart';
import 'plant2d/apple_tree_painter.dart';
import 'plant2d/tomato_painter.dart';
import 'plant2d/grapevine_painter.dart';
import 'plant2d/cherry_blossom_painter.dart';
import 'plant2d/lavender_painter.dart';
import 'plant_background.dart';

/// 식물 2D 로우폴리 뷰어
///  · 핀치 줌 (0.5× ~ 3.0×)
///  · 성장에 따른 자동 줌 아웃 (g=0 → 1.0×, g=1 → 0.52×)
///  · 더블탭 → 수동 줌 초기화
class PlantView extends StatefulWidget {
  final PlantType type;
  final int growthLevel;
  final int seed;
  final double wiltFactor;
  final double windAmp;
  const PlantView({
    super.key,
    required this.type,
    required this.growthLevel,
    required this.seed,
    this.wiltFactor = 0.0,
    this.windAmp = 4.0,
  });

  @override
  State<PlantView> createState() => _PlantViewState();
}

class _PlantViewState extends State<PlantView> with TickerProviderStateMixin {
  late final AnimationController _windCtrl;
  late final AnimationController _growCtrl;

  double _manualZoom = 1.0;
  double _zoomBase = 1.0;

  double _fromG = 0;
  double _toG = 0;

  @override
  void initState() {
    super.initState();
    _fromG = _toG = widget.growthLevel / 100.0;
    _windCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();
    _growCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
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

  // 자동 줌 아웃: g=0 → 1.0, g=1 → 0.52 (sqrt 커브)
  double _autoZoom(double g) {
    final t = math.sqrt(g.clamp(0.0, 1.0));
    return 1.0 - 0.48 * t;
  }

  @override
  void dispose() {
    _windCtrl.dispose();
    _growCtrl.dispose();
    super.dispose();
  }

  CustomPainter _buildPainter(double g, double windPhase) {
    final month = DateTime.now().month;
    switch (widget.type) {
      case PlantType.appleTree:
        return AppleTreePainter(
          g: g, windPhase: windPhase, windAmp: widget.windAmp,
          wiltFactor: widget.wiltFactor, seed: widget.seed, month: month,
        );
      case PlantType.tomato:
        return TomatoPainter(
          g: g, windPhase: windPhase, windAmp: widget.windAmp,
          wiltFactor: widget.wiltFactor, seed: widget.seed,
        );
      case PlantType.grapevine:
        return GrapevinePainter(
          g: g, windPhase: windPhase, windAmp: widget.windAmp,
          wiltFactor: widget.wiltFactor, seed: widget.seed,
        );
      case PlantType.cherryBlossom:
        return CherryBlossomPainter(
          g: g, windPhase: windPhase, windAmp: widget.windAmp,
          wiltFactor: widget.wiltFactor, seed: widget.seed, month: month,
        );
      case PlantType.lavender:
        return LavenderPainter(
          g: g, windPhase: windPhase, windAmp: widget.windAmp,
          wiltFactor: widget.wiltFactor, seed: widget.seed,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 고정 야외 배경
          AnimatedBuilder(
            animation: _windCtrl,
            builder: (_, _) => PlantBackground(
              growthLevel: widget.growthLevel,
              windPhase: _windCtrl.value,
            ),
          ),
          // 식물 페인터 (핀치 줌 + 자동 줌 아웃)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => _zoomBase = _manualZoom,
            onScaleUpdate: (d) => setState(() {
              if (d.pointerCount >= 2) {
                _manualZoom = (_zoomBase * d.scale).clamp(0.50, 3.2);
              }
            }),
            onDoubleTap: () => setState(() => _manualZoom = 1.0),
            child: AnimatedBuilder(
              animation: Listenable.merge([_windCtrl, _growCtrl]),
              builder: (_, _) {
                final g = _currentG;
                final zoom = _manualZoom * _autoZoom(g);
                return Transform.scale(
                  scale: zoom,
                  alignment: const Alignment(0, 0.45),
                  child: CustomPaint(
                    painter: _buildPainter(g, _windCtrl.value),
                    size: Size.infinite,
                  ),
                );
              },
            ),
          ),
          // 생물 오버레이
          IgnorePointer(child: CreatureOverlay(growthLevel: widget.growthLevel)),
          // 시들기 경고
          if (widget.wiltFactor > 0.3)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: AnimatedOpacity(
                    opacity: widget.wiltFactor.clamp(0.0, 1.0),
                    duration: const Duration(milliseconds: 600),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB8860B).withValues(alpha: 0.80),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '💧 일기를 써서 물을 줘요!',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // 수동 줌 표시 (기본값 벗어났을 때만)
          if (_manualZoom < 0.98 || _manualZoom > 1.02)
            Positioned(
              top: 8,
              right: 10,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${(_manualZoom * 100).round()}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          // 힌트
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(child: _ZoomHint(zoom: _manualZoom)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomHint extends StatelessWidget {
  final double zoom;
  const _ZoomHint({required this.zoom});

  @override
  Widget build(BuildContext context) {
    if (zoom < 0.98 || zoom > 1.02) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: 0.50,
      duration: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '핀치로 확대 · 더블탭 초기화',
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ),
    );
  }
}
