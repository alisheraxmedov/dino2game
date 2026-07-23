import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/game_constants.dart';
import '../constants/game_theme.dart';
import 'components/dino.dart';
import 'components/ground.dart';
import 'components/obstacle.dart';
import 'components/parallax_background.dart';

enum GameState { intro, playing, gameOver }

/// One slot in the persistent world layout. The spec is generated once and kept
/// forever; [live] is only the component currently instantiated for it, which is
/// created and thrown away as the player streams past.
class ObstacleSpec {
  final double worldX;
  final bool isBird;
  final BirdHeight birdHeight;
  final CactusType cactusType;
  Obstacle? live;

  ObstacleSpec({
    required this.worldX,
    required this.isBird,
    required this.birdHeight,
    required this.cactusType,
  });
}

class DinoGame extends FlameGame with HasCollisionDetection, TapCallbacks, KeyboardEvents {
  late Dino dino;
  late Ground ground;
  late ParallaxBackground background;
  
  GameState _state = GameState.intro;

  /// Held control: -1 backward, 0 idle, +1 forward.
  int inputDirection = 0;

  /// Signed world scroll speed in px/s. Positive = world scrolls left = dino advances.
  double worldSpeed = 0.0;

  /// Magnitude of the world scroll, kept for effects that only care about "how fast".
  double get currentSpeed => worldSpeed.abs();

  double scrollAccumulator = 0.0;

  double _shakeIntensity = 0.0;
  double _shakeTimer = 0.0;
  static const double _shakeDuration = 0.5;
  static const double _maxShakeIntensity = 8.0;

  /// Persistent world layout. Every obstacle owns a fixed world coordinate, so
  /// the stretch behind the player is still there when they turn around.
  final List<ObstacleSpec> _layout = [];
  double _frontierRight = 0.0;
  double _frontierLeft = 0.0;

  /// Camera position along the world in px. Screen X = worldX - worldOffset.
  double worldOffset = 0.0;
  double _maxDistance = 0.0;
  int currentScore = 0;
  int highScore = 0;
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);

  /// Derived movement state for the HUD: -1 reverse, 0 idle, +1 forward.
  final ValueNotifier<int> directionNotifier = ValueNotifier<int>(0);

  /// The palette every component draws with. Swapped as the day/night cycle
  /// advances, and published so the HUD and the touch pads follow along.
  final ValueNotifier<GameTheme> themeNotifier =
      ValueNotifier<GameTheme>(GameTheme.night);
  GameTheme get theme => themeNotifier.value;

  /// 0 = night, 1 = day. Held at either end for [GameConstants.themeCycleSeconds]
  /// and then walked across over [GameConstants.themeTransitionSeconds].
  double _themeBlend = 0.0;
  double _themeHold = 0.0;
  int _themeDirection = 1;
  bool _themeSwitching = false;
  double _lastAppliedBlend = -1.0;

  final Random _random = Random();
  SharedPreferences? _prefs;

  /// Hook the host widget sets so the canvas can take keyboard focus back after
  /// an overlay button has stolen it. Without this the arrow keys go nowhere
  /// once the player has clicked START.
  VoidCallback? onRequestFocus;

  bool get isIntro => _state == GameState.intro;
  bool get isPlaying => _state == GameState.playing;
  bool get isGameOver => _state == GameState.gameOver;

  @override
  Future<void> onLoad() async {
    // Add components in proper Z-order
    background = ParallaxBackground();
    add(background);

    ground = Ground();
    add(ground);

    dino = Dino();
    add(dino);

    // Load high score from local persistence
    try {
      _prefs = await SharedPreferences.getInstance();
      highScore = _prefs?.getInt(GameConstants.highScoreKey) ?? 0;
    } catch (_) {
      // SharedPreferences might fail on unsupported web/desktop platforms, fallback to 0
      highScore = 0;
    }

    // Set Dino initial position
    dino.reset();
  }

  void startGame() {
    // Clear any active obstacles on restart
    children.whereType<Obstacle>().forEach((obstacle) => obstacle.removeFromParent());

    // Reset game physics & parameters
    _state = GameState.playing;
    inputDirection = 0;
    worldSpeed = 0.0;
    scrollAccumulator = 0.0;
    worldOffset = 0.0;
    _maxDistance = 0.0;

    // Rebuild the world from scratch, leaving the first screen clear to start on
    _layout.clear();
    _frontierRight = size.x;
    _frontierLeft = 0.0;
    currentScore = 0;
    scoreNotifier.value = 0;
    directionNotifier.value = 0;

    // Every run opens at night and cycles from there
    _resetTheme();

    dino.reset();

    // Hide UI overlays, show the touch control pad
    overlays.remove('MainMenu');
    overlays.remove('GameOver');
    overlays.add('Controls');

    // START/REPLAY was just clicked, so the button owns the focus — take it back
    onRequestFocus?.call();
  }

  void triggerGameOver() {
    _state = GameState.gameOver;
    _shakeTimer = _shakeDuration;
    _shakeIntensity = _maxShakeIntensity;

    // Freeze the world immediately, whatever the player was holding
    inputDirection = 0;
    worldSpeed = 0.0;
    directionNotifier.value = 0;

    if (currentScore > highScore) {
      highScore = currentScore;
      _prefs?.setInt(GameConstants.highScoreKey, highScore);
    }

    overlays.remove('Controls');
    overlays.add('GameOver');
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_shakeTimer > 0) {
      _shakeTimer -= dt;
      _shakeIntensity = _maxShakeIntensity * (_shakeTimer / _shakeDuration).clamp(0.0, 1.0);
      if (_shakeTimer <= 0) _shakeIntensity = 0.0;
    }

    if (isPlaying) {
      // The sky turns on its own clock, so it keeps cycling even if the player
      // stops to stand still for a while
      _advanceTheme(dt);

      // Ease the world speed toward whatever the held control asks for
      final double target = inputDirection > 0
          ? GameConstants.maxRunSpeed
          : inputDirection < 0
              ? -GameConstants.maxBackSpeed
              : 0.0;

      // Accelerate when pushing harder or turning around, decelerate when letting go
      final bool rampingUp =
          target.abs() > worldSpeed.abs() || target * worldSpeed < 0;
      final double step = (rampingUp
              ? GameConstants.moveAcceleration
              : GameConstants.moveDeceleration) *
          dt;

      if (worldSpeed < target) {
        worldSpeed = min(worldSpeed + step, target);
      } else if (worldSpeed > target) {
        worldSpeed = max(worldSpeed - step, target);
      }

      // Track distance scrolled (for matching grid background scrolling rate)
      scrollAccumulator += worldSpeed * dt;

      // Score is the furthest point ever reached: backing up never costs points,
      // and re-walking old ground never earns them twice
      worldOffset += worldSpeed * dt;
      if (worldOffset > _maxDistance) _maxDistance = worldOffset;
      final newScore = (_maxDistance / GameConstants.scoreDistanceDivisor).toInt();
      if (newScore != currentScore) {
        currentScore = newScore;
        scoreNotifier.value = currentScore;
      }

      // Lay out fresh terrain ahead of whichever way the player is facing, then
      // build and tear down components as their world slot enters and leaves view
      _ensureLayout();
      _streamObstacles();
    } else {
      // Menus and game over freeze the world outright
      worldSpeed = 0.0;
      inputDirection = 0;
    }

    // Publish the coarse movement state to the HUD, only when it actually flips
    final int movementState = worldSpeed > GameConstants.movingThreshold
        ? 1
        : worldSpeed < -GameConstants.movingThreshold
            ? -1
            : 0;
    if (movementState != directionNotifier.value) {
      directionNotifier.value = movementState;
    }
  }

  /// Walks the day/night cycle forward: hold at one end, cross to the other,
  /// then turn around and do it again.
  void _advanceTheme(double dt) {
    if (_themeSwitching) {
      _themeBlend = (_themeBlend +
              _themeDirection * dt / GameConstants.themeTransitionSeconds)
          .clamp(0.0, 1.0);
      if (_themeBlend <= 0.0 || _themeBlend >= 1.0) {
        _themeSwitching = false;
        _themeHold = 0.0;
        _themeDirection = -_themeDirection;
      }
    } else {
      _themeHold += dt;
      if (_themeHold >= GameConstants.themeCycleSeconds) _themeSwitching = true;
    }
    _applyThemeBlend();
  }

  /// Rebuilds the palette only when the blend actually moved, so the HUD is not
  /// told to repaint on every frame of a 30 second hold.
  void _applyThemeBlend() {
    if ((_themeBlend - _lastAppliedBlend).abs() < 0.0001) return;
    _lastAppliedBlend = _themeBlend;
    // Smoothstep: the sky eases out of one palette and into the other instead
    // of sliding across at a constant rate
    final double t = _themeBlend * _themeBlend * (3.0 - 2.0 * _themeBlend);
    themeNotifier.value = GameTheme.lerp(GameTheme.night, GameTheme.day, t);
  }

  void _resetTheme() {
    _themeBlend = 0.0;
    _themeHold = 0.0;
    _themeDirection = 1;
    _themeSwitching = false;
    _lastAppliedBlend = -1.0;
    _applyThemeBlend();
  }

  /// Called by the on-screen touch pad. -1 backward, 0 idle, +1 forward.
  void setInputDirection(int dir) {
    if (!isPlaying) return;
    inputDirection = dir.clamp(-1, 1);
  }

  /// Called by the on-screen JUMP button.
  void requestJump() {
    if (!isPlaying) return;
    dino.jump();
  }

  /// Extends the layout in whichever direction the player is heading, so terrain
  /// always exists beyond both screen edges — including the ground behind the
  /// starting line, which reversing eventually reaches.
  void _ensureLayout() {
    final double rightEdge = worldOffset + size.x + GameConstants.worldStreamMargin;
    while (_frontierRight < rightEdge) {
      _frontierRight += _gapAt(_frontierRight);
      _layout.add(_buildSpec(_frontierRight));
    }

    final double leftEdge = worldOffset - GameConstants.worldStreamMargin;
    while (_frontierLeft > leftEdge) {
      _frontierLeft -= _gapAt(_frontierLeft);
      _layout.add(_buildSpec(_frontierLeft));
    }
  }

  /// Instantiates and disposes obstacle components as their world slot enters or
  /// leaves the streaming window. Specs outlive their components, so an obstacle
  /// removed off-screen comes back identical when the player returns to it.
  void _streamObstacles() {
    final double from = worldOffset - GameConstants.worldStreamMargin;
    final double to = worldOffset + size.x + GameConstants.worldStreamMargin;

    for (final spec in _layout) {
      final bool inWindow = spec.worldX >= from && spec.worldX <= to;

      if (inWindow && spec.live == null) {
        final obstacle = spec.isBird
            ? Bird(
                heightLevel: spec.birdHeight,
                screenHeight: size.y,
                worldX: spec.worldX,
              )
            : Cactus(
                type: spec.cactusType,
                screenHeight: size.y,
                worldX: spec.worldX,
              );
        spec.live = obstacle;
        add(obstacle);
      } else if (!inWindow && spec.live != null) {
        spec.live!.removeFromParent();
        spec.live = null;
      }
    }
  }

  /// Difficulty is measured by distance from the origin, so the world gets just
  /// as hostile heading backward as it does heading forward.
  double _difficultyAt(double worldX) =>
      worldX.abs() / GameConstants.scoreDistanceDivisor;

  /// Distance to the next obstacle: gaps tighten the further out the layout goes,
  /// with the same random jitter the timed spawner used to apply.
  double _gapAt(double worldX) {
    final progress =
        (_difficultyAt(worldX) / GameConstants.spawnRampScore).clamp(0.0, 1.0);
    final baseLimit = lerpDouble(
      GameConstants.initialSpawnDistance,
      GameConstants.minSpawnDistance,
      progress,
    );
    return baseLimit + _random.nextDouble() * GameConstants.spawnDistanceJitter;
  }

  ObstacleSpec _buildSpec(double worldX) {
    final difficulty = _difficultyAt(worldX);

    // Only place birds past the 150 mark to ease users into the game
    final canSpawnBird = difficulty > 150;
    final spawnBirdChance = _random.nextDouble() < GameConstants.obstacleSpawnChanceBird;

    final typeChoice = _random.nextDouble();
    CactusType cactusType;

    if (difficulty > 300) {
      // Can spawn triple/large obstacles
      if (typeChoice < 0.25) {
        cactusType = CactusType.largeTriple;
      } else if (typeChoice < 0.5) {
        cactusType = CactusType.largeSingle;
      } else if (typeChoice < 0.75) {
        cactusType = CactusType.smallDouble;
      } else {
        cactusType = CactusType.smallSingle;
      }
    } else if (difficulty > 100) {
      // Can spawn double obstacles
      if (typeChoice < 0.4) {
        cactusType = CactusType.smallDouble;
      } else if (typeChoice < 0.7) {
        cactusType = CactusType.smallSingle;
      } else {
        cactusType = CactusType.largeSingle;
      }
    } else {
      // Small single/double cactus in the starting stretch
      cactusType = typeChoice < 0.7 ? CactusType.smallSingle : CactusType.smallDouble;
    }

    return ObstacleSpec(
      worldX: worldX,
      isBird: canSpawnBird && spawnBirdChance,
      birdHeight: _random.nextBool() ? BirdHeight.low : BirdHeight.high,
      cactusType: cactusType,
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (isPlaying) {
      dino.jump();
    }
  }

  // Not const: LogicalKeyboardKey overrides `==`, which const sets disallow
  static final Set<LogicalKeyboardKey> _backKeys = {
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.keyA,
  };
  static final Set<LogicalKeyboardKey> _forwardKeys = {
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyD,
  };
  static final Set<LogicalKeyboardKey> _jumpKeys = {
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.keyW,
  };

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (!isPlaying) return KeyEventResult.ignored;

    // Re-derive the direction from what is physically held right now, so key
    // repeats and simultaneous presses can never desync the state
    final bool back = keysPressed.any(_backKeys.contains);
    final bool forward = keysPressed.any(_forwardKeys.contains);
    inputDirection = (forward ? 1 : 0) + (back ? -1 : 0);

    if (_jumpKeys.contains(event.logicalKey)) {
      // Only the initial press jumps — OS auto-repeat must not machine-gun it
      if (event is KeyDownEvent) dino.jump();
      return KeyEventResult.handled;
    }

    if (_backKeys.contains(event.logicalKey) ||
        _forwardKeys.contains(event.logicalKey)) {
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void render(Canvas canvas) {
    if (_shakeIntensity > 0) {
      final dx = sin(_shakeTimer * 60) * _shakeIntensity;
      final dy = cos(_shakeTimer * 45) * _shakeIntensity * 0.6;
      canvas.save();
      canvas.translate(dx, dy);
      super.render(canvas);
      canvas.restore();
    } else {
      super.render(canvas);
    }
  }

  double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
