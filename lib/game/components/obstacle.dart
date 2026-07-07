import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../constants/game_constants.dart';
import '../dino_game.dart';

abstract class Obstacle extends PositionComponent with CollisionCallbacks, HasGameReference<DinoGame> {
  final double groundRelativeY;

  Obstacle({required Vector2 size, required double groundY, required this.groundRelativeY})
      : super(size: size, priority: 2) {
    position = Vector2(0, groundY);
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox(
      position: Vector2(4, 4),
      size: Vector2(size.x - 8, size.y - 8),
    ));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (position.x == 0) position.x = size.x + 50;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isIntro) return;
    position.x -= game.currentSpeed * dt;
    if (position.x + size.x < 0) removeFromParent();
  }
}

class CactusType {
  final int count;
  final double width;
  final double height;
  const CactusType({required this.count, required this.width, required this.height});

  static const smallSingle = CactusType(count: 1, width: 22, height: 40);
  static const smallDouble = CactusType(count: 2, width: 42, height: 40);
  static const largeSingle = CactusType(count: 1, width: 28, height: 52);
  static const largeTriple = CactusType(count: 3, width: 70, height: 52);
}

class Cactus extends Obstacle {
  final CactusType type;

  late final Paint _trunkFillPaint;
  late final Paint _trunkStrokePaint;
  late final Paint _trunkGlowPaint;
  late final Paint _thornPaint;
  late final Paint _shadowPaint;
  final Path _cactusPath = Path();

  Cactus({required this.type, required double screenHeight})
      : super(
          size: Vector2(type.width, type.height),
          groundY: screenHeight - GameConstants.dinoGroundYOffset - type.height,
          groundRelativeY: 0.0,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _trunkStrokePaint = Paint()
      ..color = GameConstants.neonPink
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _trunkGlowPaint = Paint()
      ..color = GameConstants.neonPink.withAlpha(40)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    _trunkFillPaint = Paint()..style = PaintingStyle.fill;

    _thornPaint = Paint()
      ..color = GameConstants.neonOrange
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    _shadowPaint = Paint()
      ..color = Colors.black.withAlpha(100)
      ..style = PaintingStyle.fill;
  }

  @override
  void render(Canvas canvas) {
    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 1),
        width: size.x * 1.2,
        height: 6.0,
      ),
      _shadowPaint,
    );
    super.render(canvas);

    _trunkFillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        GameConstants.neonPink.withAlpha(130),
        const Color(0xFF400020).withAlpha(110),
        const Color(0xFF200010).withAlpha(70),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));

    double xOffset = 0;
    for (int ci = 0; ci < type.count; ci++) {
      final double h = (ci == 1) ? size.y * 0.85 : size.y;
      final double yShift = size.y - h;
      canvas.save();
      canvas.translate(0, yShift);
      _drawCactus(canvas, xOffset, h);
      canvas.restore();
      xOffset += 22;
    }
  }

  void _drawCactus(Canvas canvas, double x, double h) {
    _cactusPath.reset();

    // Main trunk (rounded top)
    _cactusPath.moveTo(x + 8, h);
    _cactusPath.lineTo(x + 8, 10);
    _cactusPath.quadraticBezierTo(x + 8, 2, x + 12, 2);
    _cactusPath.quadraticBezierTo(x + 16, 2, x + 16, 10);
    _cactusPath.lineTo(x + 16, h);

    // Left branch (thick, organic curve)
    _cactusPath.moveTo(x + 8, h * 0.55);
    _cactusPath.quadraticBezierTo(x + 2, h * 0.55, x + 2, h * 0.38);
    _cactusPath.lineTo(x + 2, h * 0.22);
    _cactusPath.quadraticBezierTo(x + 2, h * 0.14, x + 5, h * 0.14);
    _cactusPath.quadraticBezierTo(x + 8, h * 0.14, x + 8, h * 0.22);

    // Right branch
    _cactusPath.moveTo(x + 16, h * 0.65);
    _cactusPath.quadraticBezierTo(x + 22, h * 0.65, x + 22, h * 0.48);
    _cactusPath.lineTo(x + 22, h * 0.32);
    _cactusPath.quadraticBezierTo(x + 22, h * 0.24, x + 19, h * 0.24);
    _cactusPath.quadraticBezierTo(x + 16, h * 0.24, x + 16, h * 0.32);

    canvas.drawPath(_cactusPath, _trunkFillPaint);
    canvas.drawPath(_cactusPath, _trunkGlowPaint);
    canvas.drawPath(_cactusPath, _trunkStrokePaint);

    // Vertical rib lines on trunk
    final ribPaint = Paint()
      ..color = GameConstants.neonPink.withAlpha(40)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(x + 12, 12), Offset(x + 12, h - 4), ribPaint);

    // Thorns
    final rng = Random(x.toInt() + h.toInt());
    for (int t = 0; t < 6; t++) {
      final ty = 15.0 + rng.nextDouble() * (h - 30);
      final side = rng.nextBool();
      if (side) {
        canvas.drawLine(Offset(x + 8, ty), Offset(x + 5, ty - 3), _thornPaint);
      } else {
        canvas.drawLine(Offset(x + 16, ty), Offset(x + 19, ty - 3), _thornPaint);
      }
    }
  }
}

enum BirdHeight { low, high }

class Bird extends Obstacle {
  final BirdHeight heightLevel;
  double _wingTime = 0.0;
  double _wingAngle = 0.0;

  late final Paint _bodyFillPaint;
  late final Paint _bodyStrokePaint;
  late final Paint _bodyGlowPaint;
  late final Paint _eyePaint;
  late final Paint _shadowPaint;
  final Path _birdPath = Path();

  Bird({required this.heightLevel, required double screenHeight})
      : super(
          size: Vector2(44, 30),
          groundY: screenHeight -
              GameConstants.dinoGroundYOffset -
              (heightLevel == BirdHeight.low ? 55.0 : 100.0),
          groundRelativeY: heightLevel == BirdHeight.low ? 55.0 : 100.0,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _bodyStrokePaint = Paint()
      ..color = GameConstants.neonPink
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _bodyGlowPaint = Paint()
      ..color = GameConstants.neonPink.withAlpha(40)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    _bodyFillPaint = Paint()..style = PaintingStyle.fill;

    _eyePaint = Paint()
      ..color = GameConstants.neonYellow
      ..style = PaintingStyle.fill;

    _shadowPaint = Paint()..style = PaintingStyle.fill;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isIntro) return;
    _wingTime += dt;
    _wingAngle = sin(_wingTime * 12.0) * 0.8;
  }

  @override
  void render(Canvas canvas) {
    // Flight altitude ground shadow
    final double shadowScale = (1.0 - (groundRelativeY / 180.0)).clamp(0.15, 0.7);
    _shadowPaint.color = Colors.black.withAlpha((80 * shadowScale).toInt());
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y + groundRelativeY - 2),
        width: size.x * 0.8 * shadowScale,
        height: 4.0 * shadowScale,
      ),
      _shadowPaint,
    );

    super.render(canvas);

    _bodyFillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        GameConstants.neonPink.withAlpha(130),
        const Color(0xFF3D0020).withAlpha(100),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));

    _birdPath.reset();

    // Aerodynamic body
    _birdPath.moveTo(6, 15);
    _birdPath.quadraticBezierTo(18, 8, 34, 14);
    _birdPath.quadraticBezierTo(38, 16, 38, 18);
    _birdPath.quadraticBezierTo(24, 22, 6, 15);

    // Beak
    _birdPath.moveTo(34, 14);
    _birdPath.lineTo(42, 17);
    _birdPath.lineTo(34, 18);

    // Tail feathers (multiple)
    _birdPath.moveTo(6, 15);
    _birdPath.lineTo(0, 12);
    _birdPath.lineTo(2, 15);
    _birdPath.moveTo(6, 15);
    _birdPath.lineTo(1, 18);
    _birdPath.lineTo(4, 16);

    canvas.drawPath(_birdPath, _bodyFillPaint);
    canvas.drawPath(_birdPath, _bodyGlowPaint);
    canvas.drawPath(_birdPath, _bodyStrokePaint);

    // Animated wing
    canvas.save();
    canvas.translate(20, 14);
    canvas.rotate(_wingAngle);
    final wingPath = Path()
      ..moveTo(0, 0)
      ..lineTo(-8, _wingAngle > 0 ? -14 : 10)
      ..lineTo(-4, _wingAngle > 0 ? -10 : 7)
      ..lineTo(0, _wingAngle > 0 ? -12 : 8)
      ..lineTo(4, 0);

    final wingFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          GameConstants.neonPink.withAlpha(100),
          GameConstants.neonPink.withAlpha(30),
        ],
      ).createShader(const Rect.fromLTWH(-10, -16, 20, 30));
    canvas.drawPath(wingPath, wingFill);
    canvas.drawPath(wingPath, _bodyStrokePaint);
    canvas.restore();

    // Eye with glint
    canvas.drawCircle(const Offset(32, 13), 2.0, _eyePaint);
    canvas.drawCircle(const Offset(32.8, 12.4), 0.6,
      Paint()..color = Colors.white..style = PaintingStyle.fill);
  }
}
