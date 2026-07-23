import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/game_characters.dart';
import '../constants/game_constants.dart';
import '../constants/game_theme.dart';
import 'components/coin.dart';
import 'components/dino.dart';
import 'components/elevated_platform.dart';
import 'components/ground.dart';
import 'components/obstacle.dart';
import 'components/parallax_background.dart';
import 'world_layout.dart';

enum GameState { intro, playing, gameOver }

class DinoGame extends FlameGame
    with HasCollisionDetection, TapCallbacks, KeyboardEvents {
  DinoGame({Random? random}) : _random = random ?? Random();

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
  final List<WorldEntitySpec> _layout = [];
  final List<ElevatedPlatformSpec> _platformLayout = [];
  double _frontierRight = 0.0;
  double _frontierLeft = 0.0;

  List<WorldEntitySpec> get worldLayout => List.unmodifiable(_layout);
  List<ElevatedPlatformSpec> get platformLayout =>
      List.unmodifiable(_platformLayout);

  /// Camera position along the world in px. Screen X = worldX - worldOffset.
  double worldOffset = 0.0;
  double _maxDistance = 0.0;
  int currentScore = 0;
  int highScore = 0;
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  int _currentCoins = 0;
  int get currentCoins => _currentCoins;
  final ValueNotifier<int> coinNotifier = ValueNotifier<int>(0);

  /// Derived movement state for the HUD: -1 reverse, 0 idle, +1 forward.
  final ValueNotifier<int> directionNotifier = ValueNotifier<int>(0);

  /// The palette every component draws with. Swapped as the day/night cycle
  /// advances, and published so the HUD and the touch pads follow along.
  final ValueNotifier<GameTheme> themeNotifier = ValueNotifier<GameTheme>(
    GameTheme.night,
  );
  GameTheme get theme => themeNotifier.value;

  /// 0 = night, 1 = day. Held at either end for [GameConstants.themeCycleSeconds]
  /// and then walked across over [GameConstants.themeTransitionSeconds].
  double _themeBlend = 0.0;
  double _themeHold = 0.0;
  int _themeDirection = 1;
  bool _themeSwitching = false;
  double _lastAppliedBlend = -1.0;

  /// The runner picked in the settings screen, restored from disk on launch.
  final ValueNotifier<GameCharacter> characterNotifier =
      ValueNotifier<GameCharacter>(GameCharacter.fallback);
  GameCharacter get selectedCharacter => characterNotifier.value;

  final Random _random;
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
    // Read persistence first: the Dino picks its sprite folder from the stored
    // character the moment it loads, so the choice must already be settled.
    try {
      _prefs = await SharedPreferences.getInstance();
      highScore = _prefs?.getInt(GameConstants.highScoreKey) ?? 0;
      characterNotifier.value = GameCharacter.fromId(
        _prefs?.getString(GameConstants.characterKey),
      );
    } catch (_) {
      // SharedPreferences might fail on unsupported web/desktop platforms,
      // fall back to a clean slate on the default character
      highScore = 0;
      characterNotifier.value = GameCharacter.fallback;
    }

    // Add components in proper Z-order
    background = ParallaxBackground();
    add(background);

    ground = Ground();
    add(ground);

    dino = Dino();
    add(dino);

    // Set Dino initial position
    dino.reset();
  }

  void startGame() {
    _clearWorld();

    // Reset game physics & parameters
    _state = GameState.playing;
    inputDirection = 0;
    worldSpeed = 0.0;
    scrollAccumulator = 0.0;
    worldOffset = 0.0;
    _maxDistance = 0.0;

    // Rebuild the world from scratch, leaving the first screen clear to start on
    _frontierRight = size.x;
    _frontierLeft = 0.0;
    currentScore = 0;
    scoreNotifier.value = 0;
    _resetCoinCount();
    directionNotifier.value = 0;

    // Every run opens at night and cycles from there
    _resetTheme();

    dino.reset();

    // Hide UI overlays, show the touch control pad
    overlays.remove('MainMenu');
    overlays.remove('Settings');
    overlays.remove('GameOver');
    // overlays.add('Controls');

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
      _shakeIntensity =
          _maxShakeIntensity * (_shakeTimer / _shakeDuration).clamp(0.0, 1.0);
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
      final double step =
          (rampingUp
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
      final newScore = (_maxDistance / GameConstants.scoreDistanceDivisor)
          .toInt();
      if (newScore != currentScore) {
        currentScore = newScore;
        scoreNotifier.value = currentScore;
      }

      // Lay out fresh terrain ahead of whichever way the player is facing, then
      // build and tear down components as their world slot enters and leaves view
      _ensureLayout();
      _streamWorld();
      _streamPlatforms();
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
      _themeBlend =
          (_themeBlend +
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

  /// Swaps the runner and remembers the choice, so the settings screen is only
  /// ever visited by players who want to change it.
  Future<void> selectCharacter(GameCharacter character) async {
    characterNotifier.value = character;
    await _prefs?.setString(GameConstants.characterKey, character.id);
    await dino.applyCharacter(character);
  }

  /// Settings live in front of the main menu — the character is locked in before
  /// the run starts, never mid-run.
  void openSettings() {
    if (!isIntro) return;
    overlays.remove('MainMenu');
    overlays.add('Settings');
  }

  void closeSettings() {
    overlays.remove('Settings');
    overlays.add('MainMenu');
    onRequestFocus?.call();
  }

  /// Back out of a finished run, so the character can be changed before the next
  /// one without restarting the app.
  void returnToMenu() {
    _state = GameState.intro;
    inputDirection = 0;
    worldSpeed = 0.0;
    directionNotifier.value = 0;

    _clearWorld();
    worldOffset = 0.0;
    _maxDistance = 0.0;
    currentScore = 0;
    scoreNotifier.value = 0;
    _resetCoinCount();
    _resetTheme();
    dino.reset();

    overlays.remove('GameOver');
    overlays.remove('Controls');
    overlays.add('MainMenu');
  }

  void _clearWorld() {
    for (final slot in _layout) {
      slot.live = null;
    }
    for (final platform in _platformLayout) {
      platform.live?.removeFromParent();
      platform.live = null;
    }
    final liveWorldComponents = children
        .where((child) => child is Obstacle || child is Coin)
        .toList();
    for (final component in liveWorldComponents) {
      component.removeFromParent();
    }
    _layout.clear();
    _platformLayout.clear();
  }

  bool collectCoin(WorldEntitySpec spec) {
    if (spec.kind != WorldEntityKind.coin || spec.collected) return false;
    spec.collected = true;
    spec.live = null;
    _currentCoins++;
    coinNotifier.value = _currentCoins;
    return true;
  }

  void _resetCoinCount() {
    _currentCoins = 0;
    coinNotifier.value = 0;
  }

  @visibleForTesting
  void addWorldSpecForTest(WorldEntitySpec spec) => _layout.add(spec);

  @visibleForTesting
  void addPlatformSpecForTest(ElevatedPlatformSpec spec) =>
      _platformLayout.add(spec);

  @visibleForTesting
  void streamWorldForTest() {
    _streamWorld();
    _streamPlatforms();
  }

  double? landingSurfaceY({
    required double worldLeft,
    required double worldRight,
    required double previousFeetY,
    required double currentFeetY,
  }) {
    double? highestSurface;
    for (final platform in _platformLayout) {
      if (!platform.available) continue;
      final surfaceY =
          size.y - GameConstants.dinoGroundYOffset - platform.elevation;
      if (platform.containsWorldX(worldLeft, worldRight) &&
          previousFeetY <= surfaceY &&
          currentFeetY >= surfaceY &&
          (highestSurface == null || surfaceY < highestSurface)) {
        highestSurface = surfaceY;
      }
    }
    return highestSurface;
  }

  bool hasPlatformSupport({
    required double worldLeft,
    required double worldRight,
    required double feetY,
  }) {
    const supportTolerance = 0.01;
    return _platformLayout.any((platform) {
      if (!platform.available) return false;
      final surfaceY =
          size.y - GameConstants.dinoGroundYOffset - platform.elevation;
      return platform.containsWorldX(worldLeft, worldRight) &&
          (feetY - surfaceY).abs() <= supportTolerance;
    });
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
    final double rightEdge =
        worldOffset + size.x + GameConstants.worldStreamMargin;
    while (_frontierRight < rightEdge) {
      _frontierRight += _gapAt(_frontierRight);
      _buildWorldAt(_frontierRight);
    }

    final double leftEdge = worldOffset - GameConstants.worldStreamMargin;
    while (_frontierLeft > leftEdge) {
      _frontierLeft -= _gapAt(_frontierLeft);
      _buildWorldAt(_frontierLeft);
    }
  }

  /// Instantiates and disposes world components as their slot enters or leaves
  /// the streaming window. Specs outlive their components, while collected coin
  /// specs remain permanently empty for the rest of the run.
  void _streamWorld() {
    final double from = worldOffset - GameConstants.worldStreamMargin;
    final double to = worldOffset + size.x + GameConstants.worldStreamMargin;

    for (final spec in _layout) {
      if (spec.collected || !spec.available) {
        spec.live?.removeFromParent();
        spec.live = null;
        continue;
      }

      final bool inWindow = spec.worldX >= from && spec.worldX <= to;

      if (inWindow && spec.live == null) {
        final component = spec.kind == WorldEntityKind.coin
            ? Coin(spec: spec, screenHeight: size.y)
            : _obstacleFor(spec);
        if (component != null) {
          spec.live = component;
          add(component);
        }
      } else if (!inWindow && spec.live != null) {
        spec.live!.removeFromParent();
        spec.live = null;
      }
    }
  }

  void _streamPlatforms() {
    final double from = worldOffset - GameConstants.worldStreamMargin;
    final double to = worldOffset + size.x + GameConstants.worldStreamMargin;

    for (final spec in _platformLayout) {
      if (!spec.available) {
        spec.live?.removeFromParent();
        spec.live = null;
        continue;
      }
      final inWindow = spec.worldX + spec.width >= from && spec.worldX <= to;
      if (inWindow && spec.live == null) {
        final component = ElevatedPlatform(spec: spec);
        spec.live = component;
        add(component);
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
    final progress = (_difficultyAt(worldX) / GameConstants.spawnRampScore)
        .clamp(0.0, 1.0);
    final baseLimit = lerpDouble(
      GameConstants.initialSpawnDistance,
      GameConstants.minSpawnDistance,
      progress,
    );
    return baseLimit + _random.nextDouble() * GameConstants.spawnDistanceJitter;
  }

  void _buildWorldAt(double worldX) {
    final difficulty = _difficultyAt(worldX);
    final roll = _random.nextDouble();

    if (roll < 0.16) {
      final platform = ElevatedPlatformSpec(
        worldX: worldX,
        width: _random.nextBool() ? 260 : 340,
      );
      final containsHazard = _layout.any(
        (slot) =>
            slot.kind != WorldEntityKind.coin &&
            slot.worldX >= platform.worldX &&
            slot.worldX <= platform.worldX + platform.width,
      );
      final overlapsPlatform = _platformLayout.any(
        (existing) => existing.containsWorldX(
          platform.worldX,
          platform.worldX + platform.width,
        ),
      );
      if (containsHazard || overlapsPlatform) return;

      _platformLayout.add(platform);
      final count = 2 + _random.nextInt(4);
      for (var index = 0; index < count; index++) {
        _layout.add(
          WorldEntitySpec(
            worldX:
                platform.worldX + (index + 1) * platform.width / (count + 1),
            kind: WorldEntityKind.coin,
            elevation: platform.elevation + 36,
          ),
        );
      }
      return;
    }

    if (roll < 0.32) {
      final count = 1 + _random.nextInt(3);
      for (var index = 0; index < count; index++) {
        _layout.add(
          WorldEntitySpec(
            worldX: worldX + index * 42,
            kind: WorldEntityKind.coin,
          ),
        );
      }
      return;
    }

    final kind = switch (roll) {
      < 0.68 => WorldEntityKind.cactus,
      < 0.86 => WorldEntityKind.springMan,
      _ when difficulty > 150 => WorldEntityKind.wingMan,
      _ => WorldEntityKind.cactus,
    };

    if (_platformLayout.any(
      (platform) =>
          worldX >= platform.worldX &&
          worldX <= platform.worldX + platform.width,
    )) {
      return;
    }

    _layout.add(
      WorldEntitySpec(
        worldX: worldX,
        kind: kind,
        wingHeight: _random.nextBool() ? WingHeight.low : WingHeight.high,
        cactusVariant: _cactusVariantAt(difficulty),
      ),
    );
  }

  CactusVariant _cactusVariantAt(double difficulty) {
    final typeChoice = _random.nextDouble();

    if (difficulty > 300) {
      if (typeChoice < 0.25) {
        return CactusVariant.largeTriple;
      }
      if (typeChoice < 0.5) {
        return CactusVariant.largeSingle;
      }
      if (typeChoice < 0.75) {
        return CactusVariant.smallDouble;
      }
      return CactusVariant.smallSingle;
    }

    if (difficulty > 100) {
      if (typeChoice < 0.4) {
        return CactusVariant.smallDouble;
      }
      if (typeChoice < 0.7) {
        return CactusVariant.smallSingle;
      }
      return CactusVariant.largeSingle;
    }

    return typeChoice < 0.7
        ? CactusVariant.smallSingle
        : CactusVariant.smallDouble;
  }

  Obstacle? _obstacleFor(WorldEntitySpec spec) {
    return switch (spec.kind) {
      WorldEntityKind.cactus => Cactus(
        variant: spec.cactusVariant,
        screenHeight: size.y,
        worldX: spec.worldX,
      ),
      WorldEntityKind.spikeMan => SpikeManEnemy(
        screenHeight: size.y,
        worldX: spec.worldX,
      ),
      WorldEntityKind.springMan => SpringManEnemy(
        screenHeight: size.y,
        worldX: spec.worldX,
      ),
      WorldEntityKind.wingMan => WingMan(
        heightLevel: spec.wingHeight,
        screenHeight: size.y,
        worldX: spec.worldX,
      ),
      WorldEntityKind.coin => null,
    };
  }

  @override
  void onRemove() {
    coinNotifier.dispose();
    super.onRemove();
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (isPlaying) {
      dino.jump();
      inputDirection = 1; // Start auto-running
    }
  }

  static final Set<LogicalKeyboardKey> _jumpKeys = {
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.keyW,
  };

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (!isPlaying) return KeyEventResult.ignored;

    if (_jumpKeys.contains(event.logicalKey)) {
      // Only the initial press jumps — OS auto-repeat must not machine-gun it
      if (event is KeyDownEvent) {
        dino.jump();
        inputDirection = 1; // Start auto-running
      }
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
