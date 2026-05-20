import 'dart:math' as math;
import 'package:flutter/material.dart';

class SkyParticles extends StatefulWidget {
  final Color color;
  const SkyParticles({super.key, required this.color});
  @override State<SkyParticles> createState() => _SkyParticlesState();
}

class _SkyParticlesState extends State<SkyParticles> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rng = math.Random();
  late List<_Pt> _pts;

  @override void initState() {
    super.initState();
    _pts = List.generate(28, (_) => _Pt(_rng));
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, child) => CustomPaint(painter: _SkyPainter(_pts, _ctrl.value, widget.color), size: Size.infinite),
  );
}

class _Pt {
  double x, y, r, spd, ph;
  _Pt(math.Random g) : x=g.nextDouble(), y=g.nextDouble(), r=1.5+g.nextDouble()*3, spd=0.003+g.nextDouble()*0.006, ph=g.nextDouble()*math.pi*2;
}

class _SkyPainter extends CustomPainter {
  final List<_Pt> pts;
  final double t;
  final Color c;
  _SkyPainter(this.pts, this.t, this.c);

  @override void paint(Canvas cv, Size sz) {
    for (final p in pts) {
      final a = 0.3 + 0.5 * math.sin(t * math.pi * 2 + p.ph);
      final dy = (p.y + t * p.spd) % 1.0;
      cv.drawCircle(Offset(p.x * sz.width, dy * sz.height), p.r,
        Paint()..color = c.withValues(alpha: a)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }

  @override bool shouldRepaint(_SkyPainter o) => true;
}
