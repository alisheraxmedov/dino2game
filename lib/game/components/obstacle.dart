import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../constants/game_constants.dart';
import '../dino_game.dart';
import '../world_layout.dart';
import 'sprite_layout.dart';

abstract class Obstacle extends PositionComponent
    with CollisionCallbacks, HasGameReference<DinoGame> {
  static final cactusSmallSize = Vector2(36, 50);
  static final cactusLargeSize = Vector2(44, 60);
  static final spikeManSize = Vector2(44, 58);
  static final springManSize = Vector2(42, 54);
  static final wingManSize = Vector2(64, 40);
  static const enemyFrameTime = 0.14;
  static const wingManFrameTime = 0.09;

  final double groundRelativeY;

  /// Anchored position in world space. Screen X is derived from it every frame,
  /// so a hazard never drifts and remains where it was when the player returns.
  final double worldX;
  final double frameTime;

  List<Sprite> _frames = const [];
  double _frameElapsed = 0;
  int _frameIndex = 0;

  bool get spritesLoaded => _frames.isNotEmpty;
  int get frameIndex => _frameIndex;
  int get frameCount => _frames.length;
  Sprite get currentFrame => _frames[_frameIndex];

  Obstacle({
    required Vector2 size,
    required double groundY,
    required this.groundRelativeY,
    required this.worldX,
    this.frameTime = double.infinity,
  }) : super(size: size, position: Vector2(worldX, groundY), priority: 2);

  Future<List<Sprite>> loadSprites();

  @override
  Future<void> onLoad() async {
    position.x = worldX - game.worldOffset;

    try {
      final loaded = await loadSprites();
      if (loaded.isEmpty) {
        throw StateError('A hazard must load at least one sprite');
      }
      _frames = loaded;
      add(
        RectangleHitbox(
          position: Vector2(4, 4),
          size: Vector2(size.x - 8, size.y - 8),
        ),
      );
    } catch (_) {
      // Never leave an invisible lethal component in the world. Since the
      // hitbox is attached only after every frame loads, a failed hazard is
      // harmless even before Flame processes its removal.
      _frames = const [];
      removeFromParent();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // The camera moves, the world does not: forward pushes hazards left,
    // reversing brings them back in from the left edge.
    position.x = worldX - game.worldOffset;

    if (!spritesLoaded || frameCount == 1 || game.isGameOver || game.isIntro) {
      return;
    }

    _frameElapsed += dt;
    while (_frameElapsed >= frameTime) {
      _frameElapsed -= frameTime;
      _frameIndex = (_frameIndex + 1) % frameCount;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!spritesLoaded) return;
    renderLoadedSprite(canvas);
  }

  void renderLoadedSprite(Canvas canvas) {
    currentFrame.renderRect(
      canvas,
      containedSpriteRect(
        sourceSize: currentFrame.srcSize,
        boundsSize: size,
        alignmentY: 1,
      ),
    );
  }
}

class Cactus extends Obstacle {
  final CactusVariant variant;
  final int _count;
  final Vector2 _singleSize;

  Cactus({
    required this.variant,
    required double screenHeight,
    required super.worldX,
  }) : _count = switch (variant) {
         CactusVariant.smallSingle || CactusVariant.largeSingle => 1,
         CactusVariant.smallDouble => 2,
         CactusVariant.largeTriple => 3,
       },
       _singleSize =
           variant == CactusVariant.smallSingle ||
               variant == CactusVariant.smallDouble
           ? Obstacle.cactusSmallSize.clone()
           : Obstacle.cactusLargeSize.clone(),
       super(
         size: Vector2(
           (variant == CactusVariant.smallSingle ||
                       variant == CactusVariant.smallDouble
                   ? Obstacle.cactusSmallSize.x
                   : Obstacle.cactusLargeSize.x) *
               switch (variant) {
                 CactusVariant.smallSingle || CactusVariant.largeSingle => 1,
                 CactusVariant.smallDouble => 2,
                 CactusVariant.largeTriple => 3,
               },
           variant == CactusVariant.smallSingle ||
                   variant == CactusVariant.smallDouble
               ? Obstacle.cactusSmallSize.y
               : Obstacle.cactusLargeSize.y,
         ),
         groundY:
             screenHeight -
             GameConstants.dinoGroundYOffset -
             (variant == CactusVariant.smallSingle ||
                     variant == CactusVariant.smallDouble
                 ? Obstacle.cactusSmallSize.y
                 : Obstacle.cactusLargeSize.y),
         groundRelativeY: 0,
       );

  @override
  Future<List<Sprite>> loadSprites() async => [
    await Sprite.load('environment/cactus.png'),
  ];

  @override
  void renderLoadedSprite(Canvas canvas) {
    for (var index = 0; index < _count; index++) {
      currentFrame.renderRect(
        canvas,
        containedSpriteRect(
          sourceSize: currentFrame.srcSize,
          boundsSize: _singleSize,
          origin: Offset(index * _singleSize.x, 0),
          alignmentY: 1,
        ),
      );
    }
  }
}

class SpikeManEnemy extends Obstacle {
  SpikeManEnemy({required double screenHeight, required super.worldX})
    : super(
        size: Obstacle.spikeManSize.clone(),
        groundY:
            screenHeight -
            GameConstants.dinoGroundYOffset -
            Obstacle.spikeManSize.y,
        groundRelativeY: 0,
        frameTime: Obstacle.enemyFrameTime,
      );

  @override
  Future<List<Sprite>> loadSprites() => Future.wait([
    Sprite.load('enemies/spikeMan_walk1.png'),
    Sprite.load('enemies/spikeMan_walk2.png'),
  ]);
}

class SpringManEnemy extends Obstacle {
  double _visualTime = 0;

  SpringManEnemy({required double screenHeight, required super.worldX})
    : super(
        size: Obstacle.springManSize.clone(),
        groundY:
            screenHeight -
            GameConstants.dinoGroundYOffset -
            Obstacle.springManSize.y,
        groundRelativeY: 0,
      );

  @override
  Future<List<Sprite>> loadSprites() async => [
    await Sprite.load('enemies/springMan_stand.png'),
  ];

  @override
  void update(double dt) {
    super.update(dt);
    if (!game.isGameOver && !game.isIntro) {
      _visualTime += dt;
    }
  }

  @override
  void renderLoadedSprite(Canvas canvas) {
    canvas.save();
    canvas.translate(0, sin(_visualTime * 7) * 3);
    super.renderLoadedSprite(canvas);
    canvas.restore();
  }
}

class WingMan extends Obstacle {
  final WingHeight heightLevel;

  WingMan({
    required this.heightLevel,
    required double screenHeight,
    required super.worldX,
  }) : super(
         size: Obstacle.wingManSize.clone(),
         groundY:
             screenHeight -
             GameConstants.dinoGroundYOffset -
             (heightLevel == WingHeight.low ? 55 : 100),
         groundRelativeY: heightLevel == WingHeight.low ? 55 : 100,
         frameTime: Obstacle.wingManFrameTime,
       );

  @override
  Future<List<Sprite>> loadSprites() => Future.wait([
    Sprite.load('enemies/wingMan1.png'),
    Sprite.load('enemies/wingMan2.png'),
    Sprite.load('enemies/wingMan3.png'),
    Sprite.load('enemies/wingMan4.png'),
    Sprite.load('enemies/wingMan5.png'),
  ]);
}
