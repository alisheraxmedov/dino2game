import 'dart:ui';

import 'package:flame/components.dart';

import '../../constants/game_constants.dart';
import '../dino_game.dart';
import '../world_layout.dart';

class ElevatedPlatform extends PositionComponent
    with HasGameReference<DinoGame> {
  static const double platformHeight = 64;

  final ElevatedPlatformSpec spec;

  Sprite? _nightSprite;
  Sprite? _daySprite;

  ElevatedPlatform({required this.spec})
    : super(
        position: Vector2(spec.worldX, 0),
        size: Vector2(spec.width, platformHeight),
        priority: 2,
      );

  static String assetName({required bool isDay}) => isDay
      ? 'environment/ground_wood_broken.png'
      : 'environment/ground_stone.png';

  String get activeAssetName => assetName(isDay: game.theme.isDay);

  @override
  Future<void> onLoad() async {
    final loaded = await Future.wait([
      Sprite.load(assetName(isDay: false)),
      Sprite.load(assetName(isDay: true)),
    ]);
    _nightSprite = loaded[0];
    _daySprite = loaded[1];
    _syncPosition();
  }

  void _syncPosition() {
    position
      ..x = spec.worldX - game.worldOffset
      ..y = game.size.y - GameConstants.dinoGroundYOffset - spec.elevation;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncPosition();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final sprite = game.theme.isDay ? _daySprite : _nightSprite;
    sprite?.render(canvas, position: Vector2.zero(), size: size);
  }

  @override
  void onRemove() {
    if (identical(spec.live, this)) {
      spec.live = null;
    }
    super.onRemove();
  }
}
