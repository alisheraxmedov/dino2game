// Covers the plants scattered over the ground plane. The game is pumped inside
// a real widget because the plant layer is a child of the ground, and a
// headless game never mounts its component tree — nothing would be planted.

import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dino2game/constants/game_constants.dart';
import 'package:dino2game/game/components/foliage.dart';
import 'package:dino2game/game/components/ground.dart';
import 'package:dino2game/game/dino_game.dart';

const int _width = 800;
const int _height = 400;

Map<String, OverlayWidgetBuilder<DinoGame>> _stubOverlays() => {
      for (final name in ['MainMenu', 'Settings', 'GameOver', 'HUD', 'Controls'])
        name: (context, game) => const SizedBox.shrink(),
    };

void _tick(DinoGame game, double seconds) {
  const step = 1 / 60;
  for (double t = 0; t < seconds; t += step) {
    game.update(step);
  }
}

/// Pumps a mounted, sized game and hands back its plant layer.
Future<(DinoGame, Foliage)> _pumpGame(WidgetTester tester, GlobalKey key) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(_width.toDouble(), _height.toDouble());
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final game = DinoGame();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RepaintBoundary(
          key: key,
          child: GameWidget<DinoGame>(game: game, overlayBuilderMap: _stubOverlays()),
        ),
      ),
    ),
  );
  // Sprite loading needs the real event loop, so the component tree only
  // finishes mounting outside the fake async a widget test runs in
  await tester.runAsync(game.ready);
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }

  return (game, game.ground.children.whereType<Foliage>().first);
}

/// Rasterises the painted canvas and returns the rows covering the ground plane.
/// Only that strip is read back: the sky above it keeps twinkling on its own.
Future<List<int>> _groundStrip(WidgetTester tester, GlobalKey key) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late List<int> pixels;
  // toImage needs the real event loop, which a widget test's fake async lacks
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final int top =
        (_height - GameConstants.dinoGroundYOffset - Ground.bandHeight).round();
    final int bottom = (_height - GameConstants.dinoGroundYOffset).round();
    pixels = [
      for (int y = top; y < bottom; y++)
        for (int x = 0; x < image.width; x++)
          data!.getUint32((y * image.width + x) * 4),
    ];
  });
  return pixels;
}

void main() {
  testWidgets('the ground is planted, and every silhouette loads from assets',
      (WidgetTester tester) async {
    final key = GlobalKey();
    final (_, foliage) = await _pumpGame(tester, key);

    expect(foliage.sprites.length, Foliage.assetNames.length,
        reason: 'a missing file leaves the ground bare instead of throwing');
    expect(foliage.plants, isNotEmpty);
    // Every depth band is represented — the depth is the whole point
    expect(foliage.plants.map((p) => p.band).toSet(), {0, 1, 2, 3});
    for (final plant in foliage.plants) {
      expect(plant.baseY, inInclusiveRange(0.0, Ground.bandHeight),
          reason: 'a plant off the ground plane would float in the sky');
    }
  });

  testWidgets('the plants actually reach the canvas', (WidgetTester tester) async {
    final key = GlobalKey();
    final (_, foliage) = await _pumpGame(tester, key);

    final planted = await _groundStrip(tester, key);

    // Same frame, minus the plants: whatever changes is what they were painting
    foliage.plants.clear();
    await tester.pump(const Duration(milliseconds: 16));
    final bare = await _groundStrip(tester, key);

    expect(planted.length, bare.length);
    int changed = 0;
    for (int i = 0; i < planted.length; i++) {
      if (planted[i] != bare[i]) changed++;
    }
    expect(changed, greaterThan(500),
        reason: 'the plant layer has to leave a mark on the ground plane');
  });

  testWidgets('the near plants sweep past faster than the far ones',
      (WidgetTester tester) async {
    final key = GlobalKey();
    final (game, foliage) = await _pumpGame(tester, key);

    final far = foliage.plants.firstWhere((p) => p.band == 0);
    final near = foliage.plants.firstWhere((p) => p.band == 3);

    // Frozen on the menu, exactly like the rest of the ground scatter
    final parked = far.x;
    _tick(game, 0.5);
    expect(far.x, parked);

    game.startGame();
    game.setInputDirection(1);
    final startFar = far.x;
    final startNear = near.x;
    // Short enough that nothing reaches an edge and wraps
    _tick(game, 0.2);

    final farTravel = startFar - far.x;
    final nearTravel = startNear - near.x;
    expect(farTravel, greaterThan(0.0));
    expect(nearTravel, greaterThan(farTravel),
        reason: 'without parallax the field reads as a flat sticker');
  });
}
