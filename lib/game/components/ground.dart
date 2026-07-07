import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../constants/game_constants.dart';
import '../dino_game.dart';

class GrassBlade {
  double x;
  final double height;
  final double sway;

  GrassBlade({required this.x, required this.height, required this.sway});
}

class GroundRock {
  double x;
  final double y;
  final double w;
  final double h;

  GroundRock({required this.x, required this.y, required this.w, required this.h});
}

class Ground extends PositionComponent with HasGameReference<DinoGame> {
  late Paint _horizonPaint;
  late Paint _horizonGlowPaint;
  late Paint _gridPaint;
  late Paint _grassPaint;
  late Paint _rockPaint;
  late Paint _fogPaint;

  double _scrollOffset = 0.0;
  double _grassTime = 0.0;

  final List<GrassBlade> _grassBlades = [];
  final List<GroundRock> _rocks = [];
  final Random _random = Random();

  Ground() : super(priority: 1);

  @override
  Future<void> onLoad() async {
    _horizonPaint = Paint()
      ..color = GameConstants.neonCyan
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    _horizonGlowPaint = Paint()
      ..color = GameConstants.neonCyan.withAlpha(30)
      ..strokeWidth = 12.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

    _gridPaint = Paint()
      ..color = GameConstants.neonCyan.withAlpha(50)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    _grassPaint = Paint()
      ..color = GameConstants.neonGreen.withAlpha(120)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    _rockPaint = Paint()
      ..color = const Color(0xFF2A2A4A)
      ..style = PaintingStyle.fill;

    _fogPaint = Paint()..style = PaintingStyle.fill;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = Vector2(size.x, 100);
    position = Vector2(0, size.y - GameConstants.dinoGroundYOffset - 100);

    if (_grassBlades.isEmpty) {
      for (int i = 0; i < 40; i++) {
        _grassBlades.add(GrassBlade(
          x: _random.nextDouble() * size.x,
          height: _random.nextDouble() * 10 + 4,
          sway: _random.nextDouble() * 2.0 + 0.5,
        ));
      }
      for (int i = 0; i < 12; i++) {
        _rocks.add(GroundRock(
          x: _random.nextDouble() * size.x,
          y: _random.nextDouble() * 6 + 4,
          w: _random.nextDouble() * 6 + 3,
          h: _random.nextDouble() * 3 + 2,
        ));
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isIntro) return;

    final speed = game.currentSpeed;
    _scrollOffset = (_scrollOffset + speed * dt) % 60.0;
    _grassTime += dt;

    final screenWidth = game.size.x;
    for (int i = 0; i < _grassBlades.length; i++) {
      _grassBlades[i].x -= speed * dt * 0.7;
      if (_grassBlades[i].x < -10) {
        _grassBlades[i].x = screenWidth + _random.nextDouble() * 50;
      }
    }
    for (int i = 0; i < _rocks.length; i++) {
      _rocks[i].x -= speed * dt * 0.5;
      if (_rocks[i].x < -10) {
        _rocks[i].x = screenWidth + _random.nextDouble() * 80;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1. Ground terrain gradient fill
    final terrainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          GameConstants.groundColor,
          const Color(0xFF0A0A1E),
          const Color(0xFF050510),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), terrainPaint);

    // 2. Horizon glow line
    canvas.drawLine(const Offset(0, 0), Offset(size.x, 0), _horizonGlowPaint);
    canvas.drawLine(const Offset(0, 0), Offset(size.x, 0), _horizonPaint);

    // 3. Perspective grid
    final double centerX = size.x / 2;
    final double gridHeight = size.y;
    const int verticalLines = 16;
    for (int i = 0; i <= verticalLines; i++) {
      final double ratio = i / verticalLines;
      final double endX = ratio * size.x;
      final alpha = (50 * (1.0 - (ratio - 0.5).abs() * 1.8)).clamp(10, 50).toInt();
      _gridPaint.color = GameConstants.neonCyan.withAlpha(alpha);
      canvas.drawLine(Offset(centerX, 0), Offset(endX, gridHeight), _gridPaint);
    }

    const int horizontalLines = 6;
    final double scrollFraction = _scrollOffset / 60.0;
    for (int i = 0; i < horizontalLines; i++) {
      final double ratio = (i + scrollFraction) / horizontalLines;
      final double y = gridHeight * ratio * ratio;
      final double halfWidth = centerX * ratio;
      final alpha = (60 * ratio).clamp(8, 60).toInt();
      _gridPaint.color = GameConstants.neonCyan.withAlpha(alpha);
      canvas.drawLine(
        Offset(centerX - halfWidth, y),
        Offset(centerX + halfWidth, y),
        _gridPaint,
      );
    }

    // 4. Scattered rocks
    for (int i = 0; i < _rocks.length; i++) {
      final rock = _rocks[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rock.x, rock.y, rock.w, rock.h),
          const Radius.circular(1.5),
        ),
        _rockPaint,
      );
    }

    // 5. Swaying grass blades
    for (int i = 0; i < _grassBlades.length; i++) {
      final blade = _grassBlades[i];
      final swayOffset = sin(_grassTime * blade.sway + blade.x * 0.1) * 3.0;
      _grassPaint.color = GameConstants.neonGreen.withAlpha(
        (80 + 40 * sin(_grassTime * blade.sway)).toInt().clamp(40, 120),
      );
      canvas.drawLine(
        Offset(blade.x, 3),
        Offset(blade.x + swayOffset, 3 - blade.height),
        _grassPaint,
      );
    }

    // 6. Atmospheric fog near horizon
    _fogPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        GameConstants.neonPurple.withAlpha(20),
        Colors.transparent,
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.x, 20));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, 20), _fogPaint);
  }
}
