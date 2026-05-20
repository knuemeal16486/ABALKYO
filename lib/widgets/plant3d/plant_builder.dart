import '../../models/app_models.dart';
import 'apple_tree.dart';
import 'engine.dart';
import 'other_plants.dart';
import 'pot.dart';

/// 식물 종류 + 성장도(g 0~1) + 개체 시드로 3D 씬을 만든다.
/// 씬은 정적 모델 좌표만 담고, 회전/바람/투영은 렌더 시 카메라가 적용한다.
Scene buildPlantScene(PlantType type, double g, int seed, int month) {
  final scene = Scene();
  addPot(scene);
  switch (type) {
    case PlantType.appleTree:
      buildAppleTree(scene, g, seed, month);
    case PlantType.sunflower:
      buildSunflower(scene, g, seed);
    case PlantType.succulent:
      buildSucculent(scene, g, seed);
    case PlantType.fern:
      buildFern(scene, g, seed);
  }
  return scene;
}
