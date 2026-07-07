import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/game_constants.dart';
import 'components/dino.dart';
import 'components/ground.dart';
import 'components/obstacle.dart';
import 'components/parallax_background.dart';

enum GameState { intro, playing, gameOver }

class DinoGame extends FlameGame with HasCollisionDetection, TapCallbacks, KeyboardEvents {
  late Dino dino;
  late Ground ground;
  late ParallaxBackground background;
  
  GameState _state = GameState.intro;
  double currentSpeed = GameConstants.initialSpeed;
  double scrollAccumulator = 0.0;
  
  double _shakeIntensity = 0.0;
  double _shakeTimer = 0.0;
  static const double _shakeDuration = 0.5;
  static const double _maxShakeIntensity = 8.0;
  
  double _obstacleSpawnTimer = 0.0;
  double _obstacleSpawnLimit = GameConstants.initialSpawnTimerLimit;
  
  double _rawScore = 0.0;
  int currentScore = 0;
  int highScore = 0;
  final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
  
  final Random _random = Random();
  SharedPreferences? _prefs;

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
      highScore = _prefs?.getInt('high_score') ?? 0;
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
    currentSpeed = GameConstants.initialSpeed;
    scrollAccumulator = 0.0;
    _obstacleSpawnTimer = 0.0;
    _obstacleSpawnLimit = GameConstants.initialSpawnTimerLimit;
    _rawScore = 0.0;
    currentScore = 0;
    scoreNotifier.value = 0;

    dino.reset();

    // Hide UI overlays
    overlays.remove('MainMenu');
    overlays.remove('GameOver');
  }

  void triggerGameOver() {
    _state = GameState.gameOver;
    _shakeTimer = _shakeDuration;
    _shakeIntensity = _maxShakeIntensity;
    
    if (currentScore > highScore) {
      highScore = currentScore;
      _prefs?.setInt('high_score', highScore);
    }

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
      // Calculate score based on running time
      _rawScore += dt * 10;
      final newScore = _rawScore.toInt();
      if (newScore != currentScore) {
        currentScore = newScore;
        scoreNotifier.value = currentScore;
      }

      // Slowly accelerate speed over time
      if (currentSpeed < GameConstants.maxSpeed) {
        currentSpeed += GameConstants.speedIncreaseRate * dt;
      }

      // Track distance scrolled (for matching grid background scrolling rate)
      scrollAccumulator += currentSpeed * dt;

      // Check obstacle spawning
      _obstacleSpawnTimer += dt;
      if (_obstacleSpawnTimer >= _obstacleSpawnLimit) {
        _spawnObstacle();
        _obstacleSpawnTimer = 0.0;
        
        // Dynamically reduce spawn intervals as game speeds up, adding random jitter
        final speedRatio = (currentSpeed - GameConstants.initialSpeed) / 
                           (GameConstants.maxSpeed - GameConstants.initialSpeed);
        final baseLimit = lerpDouble(
          GameConstants.initialSpawnTimerLimit, 
          GameConstants.minSpawnTimerLimit, 
          speedRatio.clamp(0.0, 1.0)
        );
        _obstacleSpawnLimit = baseLimit + _random.nextDouble() * 0.5;
      }
    }
  }

  void _spawnObstacle() {
    // Only spawn birds after scoring 150+ to ease users into the game
    final canSpawnBird = currentScore > 150;
    final spawnBirdChance = _random.nextDouble() < GameConstants.obstacleSpawnChanceBird;

    if (canSpawnBird && spawnBirdChance) {
      // Spawn a Flying Bird
      final heightLevel = _random.nextBool() ? BirdHeight.low : BirdHeight.high;
      add(Bird(heightLevel: heightLevel, screenHeight: size.y));
    } else {
      // Spawn a Ground Cactus
      final typeChoice = _random.nextDouble();
      CactusType cactusType;
      
      if (currentScore > 300) {
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
      } else if (currentScore > 100) {
        // Can spawn double obstacles
        if (typeChoice < 0.4) {
          cactusType = CactusType.smallDouble;
        } else if (typeChoice < 0.7) {
          cactusType = CactusType.smallSingle;
        } else {
          cactusType = CactusType.largeSingle;
        }
      } else {
        // Spawn small single/double cactus at starting phase
        cactusType = typeChoice < 0.7 ? CactusType.smallSingle : CactusType.smallDouble;
      }

      add(Cactus(type: cactusType, screenHeight: size.y));
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (isPlaying) {
      dino.jump();
    }
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (isPlaying) {
      if (keysPressed.contains(LogicalKeyboardKey.space) || 
          keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
        dino.jump();
        return KeyEventResult.handled;
      }
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
