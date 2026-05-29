import 'package:flutter/material.dart';
import 'widgets/plant2d/apple_tree_painter.dart';
import 'widgets/plant2d/tomato_painter.dart';
import 'widgets/plant2d/grapevine_painter.dart';
import 'widgets/plant2d/cherry_blossom_painter.dart';
import 'widgets/plant2d/lavender_painter.dart';

void main() {
  runApp(const ShowcaseApp());
}

class ShowcaseApp extends StatelessWidget {
  const ShowcaseApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Plant Showcase',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: const ShowcasePage(),
      );
}

class ShowcasePage extends StatefulWidget {
  const ShowcasePage({super.key});
  @override
  State<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<ShowcasePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _wind;
  int _idx = 0;

  static const _plants = [
    'appleTree',
    'tomato',
    'grapevine',
    'cherryBlossom',
    'lavender',
  ];

  static const _labels = [
    '🍎 사과나무',
    '🍅 토마토',
    '🍇 포도나무',
    '🌸 벚꽃나무',
    '💜 라벤더',
  ];

  @override
  void initState() {
    super.initState();
    _wind = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
  }

  @override
  void dispose() {
    _wind.dispose();
    super.dispose();
  }

  CustomPainter _painter(double windPhase) {
    const g = 1.0;
    const amp = 0.6;
    const wilt = 0.0;
    const seed = 42;
    final month = DateTime.now().month;
    switch (_plants[_idx]) {
      case 'appleTree':
        return AppleTreePainter(
            g: g, windPhase: windPhase, windAmp: amp,
            wiltFactor: wilt, seed: seed, month: month);
      case 'tomato':
        return TomatoPainter(
            g: g, windPhase: windPhase, windAmp: amp,
            wiltFactor: wilt, seed: seed);
      case 'grapevine':
        return GrapevinePainter(
            g: g, windPhase: windPhase, windAmp: amp,
            wiltFactor: wilt, seed: seed);
      case 'cherryBlossom':
        return CherryBlossomPainter(
            g: g, windPhase: windPhase, windAmp: amp,
            wiltFactor: wilt, seed: seed, month: month);
      case 'lavender':
        return LavenderPainter(
            g: g, windPhase: windPhase, windAmp: amp,
            wiltFactor: wilt, seed: seed);
      default:
        return AppleTreePainter(
            g: g, windPhase: windPhase, windAmp: amp,
            wiltFactor: wilt, seed: seed, month: month);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF87CEEB),
        appBar: AppBar(
          title: Text(_labels[_idx]),
          backgroundColor: const Color(0xFF6DB8D4),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(
                  () => _idx = (_idx - 1 + _plants.length) % _plants.length),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () =>
                  setState(() => _idx = (_idx + 1) % _plants.length),
            ),
          ],
        ),
        body: AnimatedBuilder(
          animation: _wind,
          builder: (_, __) => CustomPaint(
            painter: _painter(_wind.value),
            child: Container(),
          ),
        ),
      );
}
