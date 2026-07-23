import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../constants/game_characters.dart';
import '../../constants/game_constants.dart';
import '../dino_game.dart';
import 'obstacle.dart';

class DinoParticle {
  Offset position;
  Offset velocity;
  double alpha = 1.0;

  DinoParticle({required this.position, required this.velocity});

  void reset(Offset pos, Offset vel) {
    position = pos;
    velocity = vel;
    alpha = 1.0;
  }
}

/// The player character. Drawn from the Kenney "Platformer Characters 1" sprite
/// set (CC0), wrapped in the game's neon treatment: a blurred cyan silhouette
/// behind the sprite plus the dust and shadow the hand-drawn dino used to have.
class Dino extends PositionComponent with CollisionCallbacks, HasGameReference<DinoGame> {
  double _yVelocity = 0.0;
  bool _isOnGround = false;
  bool _isRunning = false;
  bool _facingLeft = false;
  double _animationTime = 0.0;
  int _runStep = 0;

  final List<DinoParticle> _particles = [];
  final List<DinoParticle> _particlePool = [];
  final double _particleSpawnInterval = 0.04;
  double _particleTimer = 0.0;

  // Nullable and swappable: the settings screen can change character at any
  // point before a run, and a half-loaded set must never reach the canvas.
  Sprite? _idleSprite;
  Sprite? _walk1Sprite;
  Sprite? _walk2Sprite;
  Sprite? _jumpSprite;
  Sprite? _fallSprite;
  Sprite? _hurtSprite;

  late final Paint _glowPaint;
  late final Paint _particlePaint;
  late final Paint _shadowPaint;

  /// Last accent the glow filter was built for, so it is only rebuilt when the
  /// day/night crossfade actually moves the colour.
  Color? _glowColor;

  Dino() : super(
    size: Vector2(GameConstants.dinoWidth, GameConstants.dinoHeight),
    priority: 2,
  );

  @override
  Future<void> onLoad() async {
    // Tall and narrow: the sprite's wide frame is mostly swinging arms, so the
    // hitbox tracks the torso and legs instead of the full 80px width.
    add(RectangleHitbox(
      position: Vector2(12, 10),
      size: Vector2(size.x - 24, size.y - 12),
    ));

    // Recolours the sprite's silhouette to the theme accent and blurs it, so the
    // character reads as part of the same world as the glowing cacti.
    _glowPaint = Paint();
    _syncGlowColor();

    _particlePaint = Paint()..style = PaintingStyle.fill;

    _shadowPaint = Paint()..style = PaintingStyle.fill;

    await applyCharacter(game.selectedCharacter);
  }

  /// Whose poses are on screen right now. Stays on the previous character if a
  /// sprite set fails to load, and is null only before the first one arrives.
  GameCharacter? loadedCharacter;

  /// Loads the six poses belonging to [character]. Called once on load and again
  /// every time the settings screen picks a different runner.
  Future<void> applyCharacter(GameCharacter character) async {
    final String path = character.spritePath;
    final String id = character.id;
    try {
      final loaded = await Future.wait([
        Sprite.load('$path/${id}_idle.png'),
        Sprite.load('$path/${id}_walk1.png'),
        Sprite.load('$path/${id}_walk2.png'),
        Sprite.load('$path/${id}_jump.png'),
        Sprite.load('$path/${id}_fall.png'),
        Sprite.load('$path/${id}_hurt.png'),
      ]);
      _idleSprite = loaded[0];
      _walk1Sprite = loaded[1];
      _walk2Sprite = loaded[2];
      _jumpSprite = loaded[3];
      _fallSprite = loaded[4];
      _hurtSprite = loaded[5];
      loadedCharacter = character;
    } catch (_) {
      // A sprite set that will not load must not take the run down with it —
      // the runner keeps its shadow and dust until a working one is chosen.
    }
  }

  /// Rebuilds the glow filter when the day/night crossfade shifts the accent.
  void _syncGlowColor() {
    final Color accent = game.theme.accent;
    if (_glowColor == accent) return;
    _glowColor = accent;
    _glowPaint
      ..colorFilter = ColorFilter.mode(accent.withAlpha(190), BlendMode.srcATop)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
  }

  void _spawnParticle(Offset position, Offset velocity) {
    if (_particlePool.isNotEmpty) {
      final p = _particlePool.removeLast();
      p.reset(position, velocity);
      _particles.add(p);
    } else {
      _particles.add(DinoParticle(position: position, velocity: velocity));
    }
  }

  void jump() {
    if (_isOnGround) {
      _yVelocity = -GameConstants.jumpForce;
      _isOnGround = false;
      for (int i = 0; i < 15; i++) {
        _spawnParticle(
          Offset(size.x * 0.4, size.y - 2),
          Offset(
            (i - 7) * 20.0 - 50.0,
            -40.0 - Random().nextDouble() * 60,
          ),
        );
      }
    }
  }

  void reset() {
    _yVelocity = 0.0;
    _isOnGround = true;
    _isRunning = false;
    _facingLeft = false;
    _animationTime = 0.0;
    _runStep = 0;
    _particlePool.addAll(_particles);
    _particles.clear();
    final gameHeight = game.size.y;
    position = Vector2(60.0, gameHeight - GameConstants.dinoGroundYOffset - size.y);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Obstacle) {
      game.triggerGameOver();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isIntro) return;

    if (!_isOnGround) {
      _yVelocity += GameConstants.gravity * dt;
      position.y += _yVelocity * dt;
      final groundY = game.size.y - GameConstants.dinoGroundYOffset - size.y;
      if (position.y >= groundY) {
        position.y = groundY;
        _yVelocity = 0.0;
        _isOnGround = true;
      }
    }

    if (game.isGameOver) return;

    // Only the world moving underfoot counts as running — the runner is pinned in X
    final double worldSpeed = game.worldSpeed;
    _isRunning = worldSpeed.abs() > GameConstants.movingThreshold;
    if (worldSpeed > GameConstants.movingThreshold) {
      _facingLeft = false;
    } else if (worldSpeed < -GameConstants.movingThreshold) {
      _facingLeft = true;
    }

    if (_isOnGround && _isRunning) {
      // Step cadence follows the actual pace, so backing up looks slower
      final double pace =
          (game.currentSpeed / GameConstants.maxRunSpeed).clamp(0.35, 1.0);
      _animationTime += dt * pace;
      if (_animationTime >= GameConstants.runnerWalkFrameTime) {
        _runStep = (_runStep + 1) % 2;
        _animationTime = 0.0;
      }
      _particleTimer += dt;
      if (_particleTimer >= _particleSpawnInterval) {
        _particleTimer = 0.0;
        // Dust kicks out behind the heel, whichever way the runner is headed
        final double dustDir = _facingLeft ? 1.0 : -1.0;
        _spawnParticle(
          Offset(size.x * (_facingLeft ? 0.7 : 0.3), size.y - 2),
          Offset(
            dustDir * (100.0 + game.currentSpeed * 0.2),
            -15.0 - Random().nextDouble() * 25,
          ),
        );
      }
    }

    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.position += p.velocity * dt;
      p.alpha -= dt * 3.0;
      if (p.alpha <= 0) {
        _particles.removeAt(i);
        _particlePool.add(p);
      }
    }
  }

  /// Picks the pose for the current physics and input state.
  Sprite? get _currentSprite {
    if (game.isGameOver) return _hurtSprite;
    if (!_isOnGround) return _yVelocity < 0 ? _jumpSprite : _fallSprite;
    if (!_isRunning) return _idleSprite;
    return _runStep == 0 ? _walk1Sprite : _walk2Sprite;
  }

  @override
  void render(Canvas canvas) {
    // Dynamic ground shadow
    final double groundY = game.size.y - GameConstants.dinoGroundYOffset - size.y;
    final double distToGround = groundY - position.y;
    final double shadowScale = (1.0 - (distToGround / 350.0)).clamp(0.15, 1.0);
    _shadowPaint.color = Colors.black.withAlpha((100 * shadowScale).toInt());
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x * 0.5, size.y + distToGround - 1),
        width: size.x * 0.9 * shadowScale,
        height: 8.0 * shadowScale,
      ),
      _shadowPaint,
    );

    super.render(canvas);

    _syncGlowColor();

    // Particles sit behind the character so the dust trails out from the heels
    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      _particlePaint.color = game.theme.accent
          .withAlpha((p.alpha.clamp(0.0, 1.0) * 180).toInt());
      canvas.drawCircle(p.position, 2.0 * p.alpha, _particlePaint);
    }

    final sprite = _currentSprite;
    if (sprite == null) return;

    canvas.save();
    // Mirror in place when heading back the other way
    if (_facingLeft) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }

    // Neon rim: the same pose, blown up slightly and blurred, drawn underneath
    const double glowSpread = 4.0;
    sprite.render(
      canvas,
      position: Vector2(-glowSpread / 2, -glowSpread / 2),
      size: Vector2(size.x + glowSpread, size.y + glowSpread),
      overridePaint: _glowPaint,
    );

    sprite.render(canvas, position: Vector2.zero(), size: size);

    canvas.restore();
  }
}
