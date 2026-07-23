import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../dino_game.dart';
import 'ground.dart';

/// One planted sprite. [band] decides everything about how it reads: how far up
/// the ground plane it stands, how big it is, how hazy its tint is and how fast
/// it slides past the camera.
class FoliagePlant {
  int spriteIndex;
  final int band;
  double x;
  final double baseY;
  double height;
  bool flip;
  final double swayPhase;
  final double swaySpeed;

  FoliagePlant({
    required this.spriteIndex,
    required this.band,
    required this.x,
    required this.baseY,
    required this.height,
    required this.flip,
    required this.swayPhase,
    required this.swaySpeed,
  });
}

/// Vegetation scattered over the ground plane under the mountains. Drawn from
/// the Kenney "Foliage Sprites" set (CC0) as white silhouettes, tinted through
/// the theme so the plants crossfade with the rest of the world.
///
/// Lives as a child of [Ground] so it always paints on top of the terrain plane
/// and underneath the runner and the obstacles.
class Foliage extends PositionComponent with HasGameReference<DinoGame> {
  /// Sprite files, in `assets/images/foliage/`.
  static const List<String> assetNames = [
    'grass_wide',
    'grass_full',
    'grass_curved',
    'grass_thin',
    'grass_tuft',
    'grass_dense',
    'reeds',
    'flowers',
    'bush',
    'fern',
  ];

  /// Which sprites suit each depth band. Wispy shapes disappear at distance, so
  /// the far bands stick to the solid clumps and the fine ones stay up close.
  /// Band 0 is the thin fringe right on the horizon line, only a few pixels tall.
  static const List<List<int>> _bandSprites = [
    [0, 1, 4, 5],
    [0, 1, 5, 8, 9],
    [0, 1, 2, 4, 5, 6, 8, 9],
    [0, 1, 2, 3, 4, 5, 6, 7],
  ];

  /// Fraction of the world scroll each band travels at — the parallax that sells
  /// the depth.
  static const List<double> _bandScroll = [0.12, 0.22, 0.5, 0.9];

  static const List<double> _bandSway = [0.006, 0.012, 0.025, 0.04];

  /// The silhouettes that resolved from assets, indexed by [assetNames].
  final List<Sprite> sprites = [];

  /// The scatter, far band first — which is also the order it is rendered in.
  final List<FoliagePlant> plants = [];
  final List<Paint> _bandPaints =
      List<Paint>.generate(_bandSprites.length, (_) => Paint(), growable: false);

  final Random _random = Random();
  double _swayTime = 0.0;

  /// Last grass colour the band tints were mixed for, so the paints are only
  /// rebuilt while the day/night crossfade is actually moving.
  Color? _tintedFor;

  @override
  Future<void> onLoad() async {
    try {
      final loaded = await Future.wait(
        assetNames.map((name) => Sprite.load('foliage/$name.png')),
      );
      sprites.addAll(loaded);
    } catch (_) {
      // Missing artwork must not take the run down — the ground simply stays
      // bare, exactly as it looked before the plants were added.
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = Vector2(size.x, Ground.bandHeight);

    // The scatter is generated once: replanting on every resize would make the
    // whole field jump around whenever the window changes shape.
    if (plants.isEmpty) _plant(size.x);
  }

  void _plant(double width) {
    // Density follows the width so a wide desktop window is not left half empty.
    // The horizon fringe is the thickest: it stands in for the hand-drawn blades
    // that used to line the skyline, so it has to read as continuous cover.
    final counts = [
      (width / 22).round().clamp(20, 70),
      (width / 55).round().clamp(8, 30),
      (width / 90).round().clamp(6, 20),
      (width / 150).round().clamp(4, 12),
    ];

    // Bands are planted far to near, and rendered in the same order, so a near
    // clump always overlaps the hazy ones standing behind it.
    for (int band = 0; band < counts.length; band++) {
      for (int i = 0; i < counts[band]; i++) {
        plants.add(FoliagePlant(
          spriteIndex: _pickSprite(band),
          band: band,
          x: _random.nextDouble() * width,
          baseY: _baseYFor(band),
          height: _heightFor(band),
          flip: _random.nextBool(),
          swayPhase: _random.nextDouble() * pi * 2,
          swaySpeed: 0.6 + _random.nextDouble() * 1.1,
        ));
      }
    }
  }

  int _pickSprite(int band) {
    final options = _bandSprites[band];
    return options[_random.nextInt(options.length)];
  }

  /// Where the plant meets the ground, measured down from the horizon line. The
  /// fringe sits on the line itself at the foot of the mountains, the near band
  /// down by the front edge of the plane where the runner is.
  double _baseYFor(int band) {
    switch (band) {
      case 0:
        return 2.0 + _random.nextDouble() * 5.0;
      case 1:
        return 10.0 + _random.nextDouble() * 10.0;
      case 2:
        return 30.0 + _random.nextDouble() * 16.0;
      default:
        return 62.0 + _random.nextDouble() * 30.0;
    }
  }

  double _heightFor(int band) {
    switch (band) {
      case 0:
        return 5.0 + _random.nextDouble() * 4.0;
      case 1:
        return 9.0 + _random.nextDouble() * 6.0;
      case 2:
        return 17.0 + _random.nextDouble() * 10.0;
      default:
        return 30.0 + _random.nextDouble() * 16.0;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isIntro) return;

    _swayTime += dt;

    final double speed = game.worldSpeed;
    final double width = game.size.x;
    const double margin = 120.0;

    for (int i = 0; i < plants.length; i++) {
      final plant = plants[i];
      plant.x -= speed * dt * _bandScroll[plant.band];
      // A plant that leaves the screen comes back as a different one, so a short
      // stretch of ground never looks like the same five clumps on a loop
      if (plant.x < -margin) {
        plant.x = width + _random.nextDouble() * 60.0;
        _reroll(plant);
      } else if (plant.x > width + margin) {
        plant.x = -_random.nextDouble() * 60.0;
        _reroll(plant);
      }
    }
  }

  void _reroll(FoliagePlant plant) {
    plant.spriteIndex = _pickSprite(plant.band);
    plant.height = _heightFor(plant.band);
    plant.flip = _random.nextBool();
  }

  /// Mixes the three band tints out of the current palette. Distance washes the
  /// plants toward the mountains they stand in front of.
  void _syncTints() {
    final theme = game.theme;
    if (_tintedFor == theme.grass) return;
    _tintedFor = theme.grass;

    final hazes = [0.72, 0.62, 0.3, 0.0];
    final alphas = [130, 150, 200, 240];
    for (int band = 0; band < _bandPaints.length; band++) {
      final Color tint =
          Color.lerp(theme.grass, theme.nearMountainTop, hazes[band])!
              .withAlpha(alphas[band]);
      // Modulate rather than replace: the sprites carry their own top-to-bottom
      // shading, and multiplying keeps it instead of flattening the clump out
      _bandPaints[band].colorFilter =
          ColorFilter.mode(tint, BlendMode.modulate);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (sprites.isEmpty) return;

    _syncTints();

    for (int i = 0; i < plants.length; i++) {
      final plant = plants[i];
      final sprite = sprites[plant.spriteIndex];
      final double aspect = sprite.srcSize.x / sprite.srcSize.y;
      final double h = plant.height;
      final double w = h * aspect;

      // Wind: the clump pivots on its own root instead of sliding sideways
      final double lean = sin(_swayTime * plant.swaySpeed + plant.swayPhase) *
          _bandSway[plant.band];

      canvas.save();
      canvas.translate(plant.x, plant.baseY);
      canvas.rotate(lean);
      if (plant.flip) canvas.scale(-1, 1);
      sprite.render(
        canvas,
        position: Vector2(-w / 2, -h),
        size: Vector2(w, h),
        overridePaint: _bandPaints[plant.band],
      );
      canvas.restore();
    }
  }
}
