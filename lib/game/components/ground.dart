import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../constants/game_constants.dart';
import '../dino_game.dart';
import 'foliage.dart';

class GroundRock {
  double x;
  final double y;
  final double w;
  final double h;

  GroundRock({required this.x, required this.y, required this.w, required this.h});
}

class Ground extends PositionComponent with HasGameReference<DinoGame> {
  /// Height of the ground plane: local y 0 is the horizon line, y [bandHeight]
  /// is the front edge the runner stands on.
  static const double bandHeight = 100.0;

  late Paint _horizonPaint;
  late Paint _horizonGlowPaint;
  late Paint _gridPaint;
  late Paint _rockPaint;
  late Paint _fogPaint;

  double _scrollOffset = 0.0;

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

    _rockPaint = Paint()
      ..color = const Color(0xFF2A2A4A)
      ..style = PaintingStyle.fill;

    _fogPaint = Paint()..style = PaintingStyle.fill;

    // A child, not a sibling: children render after their parent, so the plants
    // are guaranteed to land on top of the terrain plane drawn below.
    add(Foliage());
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = Vector2(size.x, bandHeight);
    position = Vector2(0, size.y - GameConstants.dinoGroundYOffset - bandHeight);

    if (_rocks.isEmpty) {
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

    // Signed speed: the grid and scatter run either way the player walks
    final speed = game.worldSpeed;
    _scrollOffset = _positiveMod(_scrollOffset + speed * dt, 60.0);

    // Recycle margin sits outside every respawn position, so a rock that just
    // wrapped can never trip the opposite edge on the very next frame
    final screenWidth = game.size.x;
    const double margin = 100.0;
    for (int i = 0; i < _rocks.length; i++) {
      final rock = _rocks[i];
      rock.x -= speed * dt * 0.5;
      if (rock.x < -margin) {
        rock.x = screenWidth + _random.nextDouble() * 80;
      } else if (rock.x > screenWidth + margin) {
        rock.x = -_random.nextDouble() * 80;
      }
    }
  }

  /// Keeps a wrapped phase inside [0, range) whichever direction it drifts,
  /// so a negative scroll delta never flips the grid inside out.
  double _positiveMod(double value, double range) {
    final result = value % range;
    return result < 0 ? result + range : result;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Colours are pulled per frame rather than baked in onLoad: the day/night
    // crossfade moves them continuously while the player runs
    final theme = game.theme;
    _horizonPaint.color = theme.accent;
    _horizonGlowPaint.color = theme.accent.withAlpha(30);
    _rockPaint.color = theme.rock;

    // 1. Ground terrain gradient fill
    final terrainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          theme.groundTop,
          theme.groundMid,
          theme.groundBottom,
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
      _gridPaint.color = theme.accent.withAlpha(alpha);
      canvas.drawLine(Offset(centerX, 0), Offset(endX, gridHeight), _gridPaint);
    }

    const int horizontalLines = 6;
    final double scrollFraction = _scrollOffset / 60.0;
    for (int i = 0; i < horizontalLines; i++) {
      final double ratio = (i + scrollFraction) / horizontalLines;
      final double y = gridHeight * ratio * ratio;
      final double halfWidth = centerX * ratio;
      final alpha = (60 * ratio).clamp(8, 60).toInt();
      _gridPaint.color = theme.accent.withAlpha(alpha);
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

    // 5. Atmospheric fog near horizon
    _fogPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        theme.fog.withAlpha(20),
        Colors.transparent,
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.x, 20));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, 20), _fogPaint);
  }
}
