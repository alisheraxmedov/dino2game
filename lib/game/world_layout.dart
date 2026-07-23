import 'package:flame/components.dart';

enum WorldEntityKind { cactus, spikeMan, springMan, wingMan, coin }

enum CactusVariant { smallSingle, smallDouble, largeSingle, largeTriple }

enum WingHeight { low, high }

class WorldEntitySpec {
  final double worldX;
  final WorldEntityKind kind;
  final WingHeight wingHeight;
  final CactusVariant cactusVariant;
  final double elevation;
  bool collected;
  PositionComponent? live;

  WorldEntitySpec({
    required this.worldX,
    required this.kind,
    this.wingHeight = WingHeight.low,
    this.cactusVariant = CactusVariant.smallSingle,
    this.elevation = 36,
    this.collected = false,
  });
}

class ElevatedPlatformSpec {
  final double worldX;
  final double width;
  final double elevation;
  PositionComponent? live;

  ElevatedPlatformSpec({
    required this.worldX,
    this.width = 260,
    this.elevation = 90,
  });

  bool containsWorldX(double left, double right) =>
      right > worldX && left < worldX + width;
}
