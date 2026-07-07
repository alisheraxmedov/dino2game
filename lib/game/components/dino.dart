import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
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

class Dino extends PositionComponent with CollisionCallbacks, HasGameReference<DinoGame> {
  double _yVelocity = 0.0;
  bool _isOnGround = false;
  double _animationTime = 0.0;
  int _runStep = 0;
  double _breathPhase = 0.0;

  final List<DinoParticle> _particles = [];
  final List<DinoParticle> _particlePool = [];
  final double _particleSpawnInterval = 0.04;
  double _particleTimer = 0.0;

  late final Paint _bodyFillPaint;
  late final Paint _bodyStrokePaint;
  late final Paint _bodyGlowPaint;
  late final Paint _eyeWhitePaint;
  late final Paint _eyePupilPaint;
  late final Paint _teethPaint;
  late final Paint _spinesPaint;
  late final Paint _clawPaint;
  late final Paint _bellyPaint;
  late final Paint _particlePaint;
  late final Paint _shadowPaint;

  final Path _bodyPath = Path();
  final Path _leftLegPath = Path();
  final Path _rightLegPath = Path();

  Dino() : super(
    size: Vector2(GameConstants.dinoWidth, GameConstants.dinoHeight),
    priority: 2,
  );

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(
      position: Vector2(8, 8),
      size: Vector2(size.x - 16, size.y - 16),
    ));

    _bodyStrokePaint = Paint()
      ..color = GameConstants.neonCyan
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _bodyGlowPaint = Paint()
      ..color = GameConstants.neonCyan.withAlpha(50)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    _bodyFillPaint = Paint()..style = PaintingStyle.fill;

    _eyeWhitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    _eyePupilPaint = Paint()
      ..color = const Color(0xFFFF2020)
      ..style = PaintingStyle.fill;

    _teethPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    _spinesPaint = Paint()
      ..color = GameConstants.neonOrange
      ..style = PaintingStyle.fill;

    _clawPaint = Paint()
      ..color = GameConstants.neonCyan.withAlpha(200)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    _bellyPaint = Paint()..style = PaintingStyle.fill;

    _particlePaint = Paint()..style = PaintingStyle.fill;

    _shadowPaint = Paint()..style = PaintingStyle.fill;
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

    _breathPhase += dt * 3.0;

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

    if (_isOnGround) {
      _animationTime += dt;
      if (_animationTime >= 0.07) {
        _runStep = (_runStep + 1) % 2;
        _animationTime = 0.0;
      }
      _particleTimer += dt;
      if (_particleTimer >= _particleSpawnInterval) {
        _particleTimer = 0.0;
        _spawnParticle(
          Offset(size.x * 0.3, size.y - 2),
          Offset(-100.0 - (game.currentSpeed * 0.2), -15.0 - Random().nextDouble() * 25),
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

  @override
  void render(Canvas canvas) {
    // Dynamic ground shadow
    final double groundY = game.size.y - GameConstants.dinoGroundYOffset - size.y;
    final double distToGround = groundY - position.y;
    final double shadowScale = (1.0 - (distToGround / 350.0)).clamp(0.15, 1.0);
    _shadowPaint.color = Colors.black.withAlpha((100 * shadowScale).toInt());
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x * 0.45, size.y + distToGround - 1),
        width: size.x * 0.85 * shadowScale,
        height: 8.0 * shadowScale,
      ),
      _shadowPaint,
    );

    super.render(canvas);

    // Particles
    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      _particlePaint.color = GameConstants.neonCyan.withAlpha((p.alpha.clamp(0.0, 1.0) * 180).toInt());
      canvas.drawCircle(p.position, 2.0 * p.alpha, _particlePaint);
    }

    final double breathOffset = sin(_breathPhase) * 1.2;
    final double headBob = _isOnGround ? sin(_animationTime * (2 * pi / 0.07)) * 1.0 : 0.0;
    final double tailWag = _isOnGround ? cos(_animationTime * (2 * pi / 0.07)) * 2.5 : 0.0;

    // Body fill gradient
    _bodyFillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        GameConstants.neonCyan.withAlpha(100),
        const Color(0xFF003040).withAlpha(130),
        const Color(0xFF001520).withAlpha(80),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));

    // Belly lighter gradient
    _bellyPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        GameConstants.neonCyan.withAlpha(40),
        GameConstants.neonCyan.withAlpha(15),
      ],
    ).createShader(Rect.fromLTWH(10, 30, 30, 20));

    // Build body path
    _bodyPath.reset();
    // Tail
    _bodyPath.moveTo(4, 38 + tailWag);
    _bodyPath.quadraticBezierTo(-2, 30, 0, 42 + tailWag);
    _bodyPath.quadraticBezierTo(3, 46, 8, 44);
    _bodyPath.lineTo(14, 46 + breathOffset);
    // Belly
    _bodyPath.lineTo(14, 28);
    // Spine to neck
    _bodyPath.lineTo(30, 28);
    // Neck
    _bodyPath.lineTo(30, 12 + headBob);
    // Head top
    _bodyPath.quadraticBezierTo(32, 6 + headBob, 38, 6 + headBob);
    _bodyPath.lineTo(54, 6 + headBob);
    // Snout front
    _bodyPath.quadraticBezierTo(58, 8 + headBob, 58, 14 + headBob);
    // Jaw underside
    _bodyPath.lineTo(56, 20 + headBob);
    _bodyPath.lineTo(38, 22 + headBob);
    // Throat
    _bodyPath.lineTo(34, 28);
    // Chest connects to belly
    _bodyPath.lineTo(38, 36 + breathOffset);
    _bodyPath.lineTo(30, 48 + breathOffset);
    _bodyPath.lineTo(14, 48 + breathOffset);
    _bodyPath.close();

    canvas.drawPath(_bodyPath, _bodyFillPaint);

    // Belly patch
    final bellyPath = Path()
      ..moveTo(18, 36)
      ..quadraticBezierTo(24, 34, 30, 36 + breathOffset)
      ..lineTo(28, 46 + breathOffset)
      ..lineTo(16, 46 + breathOffset)
      ..close();
    canvas.drawPath(bellyPath, _bellyPaint);

    // Glow + outline stroke
    canvas.drawPath(_bodyPath, _bodyGlowPaint);
    canvas.drawPath(_bodyPath, _bodyStrokePaint);

    // Spines along back
    for (int i = 0; i < 5; i++) {
      final sx = 14.0 + i * 4.5;
      final path = Path()
        ..moveTo(sx, 28)
        ..lineTo(sx + 1.5, 22 - i * 0.5)
        ..lineTo(sx + 3, 28);
      canvas.drawPath(path, _spinesPaint);
    }

    // Eye with sclera and pupil
    canvas.drawOval(
      Rect.fromCenter(center: Offset(46, 11 + headBob), width: 7, height: 6),
      _eyeWhitePaint,
    );
    canvas.drawCircle(Offset(47.5, 11 + headBob), 2.2, _eyePupilPaint);
    // Eye glint
    canvas.drawCircle(Offset(48.5, 10 + headBob), 0.8,
      Paint()..color = Colors.white..style = PaintingStyle.fill);

    // Teeth along jaw
    for (int i = 0; i < 4; i++) {
      final tx = 42.0 + i * 3.5;
      final path = Path()
        ..moveTo(tx, 19 + headBob)
        ..lineTo(tx + 1, 22 + headBob)
        ..lineTo(tx + 2, 19 + headBob);
      canvas.drawPath(path, _teethPaint);
    }

    // Nostril
    canvas.drawCircle(Offset(55, 9 + headBob), 1.2,
      Paint()..color = GameConstants.neonCyan.withAlpha(100)..style = PaintingStyle.fill);

    // Small arm with claws
    canvas.drawLine(Offset(36, 30), Offset(40, 30), _clawPaint);
    canvas.drawLine(Offset(40, 30), Offset(42, 28), _clawPaint);
    canvas.drawLine(Offset(40, 30), Offset(42, 32), _clawPaint);

    // Legs
    _leftLegPath.reset();
    _rightLegPath.reset();

    if (!_isOnGround) {
      _leftLegPath.moveTo(18, 48);
      _leftLegPath.lineTo(15, 56);
      _leftLegPath.lineTo(20, 56);
      _leftLegPath.lineTo(22, 54);

      _rightLegPath.moveTo(28, 48);
      _rightLegPath.lineTo(25, 56);
      _rightLegPath.lineTo(30, 56);
      _rightLegPath.lineTo(32, 54);
    } else {
      if (_runStep == 0) {
        _leftLegPath.moveTo(18, 48);
        _leftLegPath.lineTo(16, 60);
        _leftLegPath.lineTo(12, 62);
        _leftLegPath.lineTo(20, 62);
        _leftLegPath.lineTo(22, 60);

        _rightLegPath.moveTo(28, 48);
        _rightLegPath.lineTo(25, 54);
        _rightLegPath.lineTo(28, 52);
        _rightLegPath.lineTo(30, 54);
      } else {
        _leftLegPath.moveTo(18, 48);
        _leftLegPath.lineTo(15, 54);
        _leftLegPath.lineTo(18, 52);
        _leftLegPath.lineTo(20, 54);

        _rightLegPath.moveTo(28, 48);
        _rightLegPath.lineTo(26, 60);
        _rightLegPath.lineTo(22, 62);
        _rightLegPath.lineTo(30, 62);
        _rightLegPath.lineTo(32, 60);
      }
    }

    canvas.drawPath(_leftLegPath, _bodyFillPaint);
    canvas.drawPath(_leftLegPath, _bodyGlowPaint);
    canvas.drawPath(_leftLegPath, _bodyStrokePaint);
    canvas.drawPath(_rightLegPath, _bodyFillPaint);
    canvas.drawPath(_rightLegPath, _bodyGlowPaint);
    canvas.drawPath(_rightLegPath, _bodyStrokePaint);

    // Toe claws on grounded legs
    if (_isOnGround) {
      if (_runStep == 0) {
        canvas.drawLine(Offset(13, 62), Offset(11, 64), _clawPaint);
        canvas.drawLine(Offset(17, 62), Offset(16, 64), _clawPaint);
      } else {
        canvas.drawLine(Offset(23, 62), Offset(21, 64), _clawPaint);
        canvas.drawLine(Offset(27, 62), Offset(26, 64), _clawPaint);
      }
    }
  }
}
