import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../constants/game_constants.dart';
import '../dino_game.dart';

class StarData {
  final double x;
  final double y;
  final double radius;
  double alpha;
  final double pulseSpeed;
  double time;
  final Color color;

  StarData({
    required this.x,
    required this.y,
    required this.radius,
    required this.alpha,
    required this.pulseSpeed,
    required this.color,
  }) : time = Random().nextDouble() * 10;
}

class ShootingStar {
  double x;
  double y;
  double vx;
  double vy;
  double alpha;
  double life;

  ShootingStar({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  })  : alpha = 1.0,
        life = 1.0;
}

class ParallaxBackground extends PositionComponent with HasGameReference<DinoGame> {
  final List<StarData> _stars = [];
  final List<ShootingStar> _shootingStars = [];
  final Random _random = Random();

  late final Paint _starPaint;
  late final Paint _moonPaint;
  late final Paint _moonCraterPaint;

  final Path _farMountainPath = Path();
  final Path _nearMountainPath = Path();

  double _farMountainScroll = 0.0;
  double _nearMountainScroll = 0.0;
  double _auroraPhase = 0.0;
  double _shootingStarTimer = 0.0;

  ParallaxBackground() : super(priority: 0);

  @override
  Future<void> onLoad() async {
    _starPaint = Paint()..style = PaintingStyle.fill;

    _moonPaint = Paint()
      ..color = const Color(0xFFE8E0D0)
      ..style = PaintingStyle.fill;

    _moonCraterPaint = Paint()
      ..color = const Color(0xFFCDC0AA)
      ..style = PaintingStyle.fill;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;

    if (_stars.isEmpty) {
      final starColors = [
        Colors.white,
        const Color(0xFFAADDFF),
        const Color(0xFFFFDDAA),
        GameConstants.neonCyan,
      ];
      for (int i = 0; i < 60; i++) {
        _stars.add(StarData(
          x: _random.nextDouble() * size.x,
          y: _random.nextDouble() * (size.y * 0.55),
          radius: _random.nextDouble() * 1.8 + 0.4,
          alpha: _random.nextDouble() * 0.7 + 0.3,
          pulseSpeed: _random.nextDouble() * 2.5 + 0.8,
          color: starColors[_random.nextInt(starColors.length)],
        ));
      }
    }
    _buildMountainPaths();
  }

  void _buildMountainPaths() {
    final w = size.x;
    final groundY = size.y - GameConstants.dinoGroundYOffset - 90;

    _farMountainPath.reset();
    _farMountainPath.moveTo(0, groundY);
    for (double x = 0; x <= w; x += w / 8) {
      final peakH = 70 + _random.nextDouble() * 80;
      _farMountainPath.lineTo(x, groundY - peakH);
      _farMountainPath.lineTo(x + w / 16, groundY - peakH * 0.4);
    }
    _farMountainPath.lineTo(w, groundY);
    _farMountainPath.close();

    _nearMountainPath.reset();
    _nearMountainPath.moveTo(0, groundY);
    for (double x = 0; x <= w; x += w / 6) {
      final peakH = 40 + _random.nextDouble() * 55;
      _nearMountainPath.lineTo(x, groundY - peakH);
      _nearMountainPath.lineTo(x + w / 12, groundY - peakH * 0.3);
    }
    _nearMountainPath.lineTo(w, groundY);
    _nearMountainPath.close();
  }

  @override
  void update(double dt) {
    super.update(dt);

    _auroraPhase += dt * 0.4;

    for (int i = 0; i < _stars.length; i++) {
      final star = _stars[i];
      star.time += dt * star.pulseSpeed;
      star.alpha = (sin(star.time) * 0.4 + 0.6).clamp(0.15, 1.0);
    }

    // Shooting stars
    _shootingStarTimer += dt;
    if (_shootingStarTimer > 3.0 + _random.nextDouble() * 5.0) {
      _shootingStarTimer = 0.0;
      _shootingStars.add(ShootingStar(
        x: _random.nextDouble() * size.x * 0.8,
        y: _random.nextDouble() * size.y * 0.3,
        vx: 400 + _random.nextDouble() * 300,
        vy: 150 + _random.nextDouble() * 100,
      ));
    }
    for (int i = _shootingStars.length - 1; i >= 0; i--) {
      final ss = _shootingStars[i];
      ss.x += ss.vx * dt;
      ss.y += ss.vy * dt;
      ss.life -= dt * 1.5;
      ss.alpha = ss.life.clamp(0.0, 1.0);
      if (ss.life <= 0) _shootingStars.removeAt(i);
    }

    if (game.isGameOver || game.isIntro) return;

    final speed = game.currentSpeed;
    _farMountainScroll -= speed * 0.012 * dt;
    _nearMountainScroll -= speed * 0.035 * dt;
    if (_farMountainScroll <= -size.x) _farMountainScroll += size.x;
    if (_nearMountainScroll <= -size.x) _nearMountainScroll += size.x;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1. Gradient sky
    final skyGradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF020810),
          const Color(0xFF0A0E2A),
          const Color(0xFF15083A),
          const Color(0xFF200840),
          GameConstants.horizonGlow,
        ],
        stops: const [0.0, 0.3, 0.55, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), skyGradient);

    // 2. Aurora borealis curtain
    final auroraPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 3; i++) {
      final path = Path();
      final yBase = size.y * (0.15 + i * 0.06);
      path.moveTo(0, yBase);
      for (double x = 0; x <= size.x; x += 20) {
        final wave = sin(_auroraPhase * (1.2 + i * 0.3) + x * 0.008 + i) * 25;
        path.lineTo(x, yBase + wave);
      }
      path.lineTo(size.x, yBase + 60);
      path.lineTo(0, yBase + 60);
      path.close();

      final auroraColor = i == 0
          ? GameConstants.neonGreen
          : i == 1
              ? GameConstants.neonCyan
              : GameConstants.neonPurple;
      auroraPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          auroraColor.withAlpha(35),
          auroraColor.withAlpha(8),
        ],
      ).createShader(Rect.fromLTWH(0, yBase - 30, size.x, 100));
      canvas.drawPath(path, auroraPaint);
    }

    // 3. Stars
    for (int i = 0; i < _stars.length; i++) {
      final star = _stars[i];
      _starPaint.color = star.color.withAlpha((star.alpha * 255).toInt());
      canvas.drawCircle(Offset(star.x, star.y), star.radius, _starPaint);
      // Cross glow for bright stars
      if (star.radius > 1.2) {
        final crossPaint = Paint()
          ..color = star.color.withAlpha((star.alpha * 60).toInt())
          ..strokeWidth = 0.8;
        canvas.drawLine(
          Offset(star.x - 4, star.y),
          Offset(star.x + 4, star.y),
          crossPaint,
        );
        canvas.drawLine(
          Offset(star.x, star.y - 4),
          Offset(star.x, star.y + 4),
          crossPaint,
        );
      }
    }

    // 4. Shooting stars
    for (int i = 0; i < _shootingStars.length; i++) {
      final ss = _shootingStars[i];
      final tailPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withAlpha((ss.alpha * 255).toInt()),
            Colors.white.withAlpha(0),
          ],
        ).createShader(Rect.fromLTWH(ss.x - 40, ss.y - 20, 50, 25));
      tailPaint.strokeWidth = 2.0;
      canvas.drawLine(
        Offset(ss.x, ss.y),
        Offset(ss.x - 35, ss.y - 15),
        tailPaint,
      );
      _starPaint.color = Colors.white.withAlpha((ss.alpha * 255).toInt());
      canvas.drawCircle(Offset(ss.x, ss.y), 2.0, _starPaint);
    }

    // 5. Detailed moon with craters
    final double moonX = size.x - 130;
    const double moonY = 65.0;
    const double moonR = 30.0;

    // Ambient glow layers
    for (int r = 5; r >= 1; r--) {
      final glowPaint = Paint()
        ..color = const Color(0xFFE8E0D0).withAlpha(8 * r)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(moonX, moonY), moonR + r * 10, glowPaint);
    }
    canvas.drawCircle(Offset(moonX, moonY), moonR, _moonPaint);

    // Moon craters
    canvas.drawCircle(Offset(moonX - 8, moonY - 5), 5.0, _moonCraterPaint);
    canvas.drawCircle(Offset(moonX + 10, moonY + 8), 3.5, _moonCraterPaint);
    canvas.drawCircle(Offset(moonX + 3, moonY - 12), 2.5, _moonCraterPaint);
    canvas.drawCircle(Offset(moonX - 12, moonY + 10), 2.0, _moonCraterPaint);

    // 6. Far mountain layer with gradient
    _renderMountainLayer(canvas, _farMountainPath, _farMountainScroll,
        const Color(0xFF0D0D28), const Color(0xFF141438), GameConstants.neonPurple.withAlpha(20));

    // 7. Near mountain layer
    _renderMountainLayer(canvas, _nearMountainPath, _nearMountainScroll,
        const Color(0xFF0A0A20), const Color(0xFF101030), GameConstants.neonPink.withAlpha(30));
  }

  void _renderMountainLayer(
    Canvas canvas,
    Path path,
    double scroll,
    Color topColor,
    Color bottomColor,
    Color edgeColor,
  ) {
    final groundY = size.y - GameConstants.dinoGroundYOffset - 90;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, bottomColor],
      ).createShader(Rect.fromLTWH(0, groundY - 160, size.x, 160));

    final edgePaint = Paint()
      ..color = edgeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int pass = 0; pass < 2; pass++) {
      canvas.save();
      canvas.translate(scroll + pass * size.x, 0);
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, edgePaint);
      canvas.restore();
    }
  }
}
