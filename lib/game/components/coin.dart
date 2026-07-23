import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../constants/game_constants.dart';
import '../dino_game.dart';
import '../world_layout.dart';

class Coin extends PositionComponent
    with CollisionCallbacks, HasGameReference<DinoGame> {
  static final coinSize = Vector2.all(32);
  static const double frameTime = 0.10;

  final WorldEntitySpec spec;

  List<Sprite> _frames = const [];
  double _frameElapsed = 0;
  int _frameIndex = 0;

  Coin({required this.spec, required double screenHeight})
    : super(
        position: Vector2(
          spec.worldX,
          screenHeight - GameConstants.dinoGroundYOffset - spec.elevation,
        ),
        size: coinSize.clone(),
        priority: 2,
      );

  @override
  Future<void> onLoad() async {
    _frames = await Future.wait([
      Sprite.load('items/gold_1.png'),
      Sprite.load('items/gold_2.png'),
      Sprite.load('items/gold_3.png'),
      Sprite.load('items/gold_4.png'),
    ]);
    add(RectangleHitbox(position: Vector2(4, 2), size: Vector2(24, 28)));
  }

  void collect() {
    if (game.collectCoin(spec)) {
      removeFromParent();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    position
      ..x = spec.worldX - game.worldOffset
      ..y = game.size.y - GameConstants.dinoGroundYOffset - spec.elevation;

    if (!game.isPlaying || _frames.isEmpty) return;

    _frameElapsed += dt;
    while (_frameElapsed >= frameTime) {
      _frameElapsed -= frameTime;
      _frameIndex = (_frameIndex + 1) % _frames.length;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_frames.isEmpty) return;
    _frames[_frameIndex].render(canvas, position: Vector2.zero(), size: size);
  }
}
