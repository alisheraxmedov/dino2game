// Proves the day/night cycle actually reaches the canvas. The game is pumped
// inside a real widget so its components get mounted and sized, then the same
// scene is rasterised at both ends of the crossfade and compared pixel by pixel.

import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dino2game/constants/game_constants.dart';
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

/// Rasterises the painted canvas and reads one pixel back as RGBA.
Future<int> _pixelAt(WidgetTester tester, GlobalKey key, int x, int y) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late int value;
  // toImage needs the real event loop, which a widget test's fake async lacks
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    value = data!.getUint32((y * image.width + x) * 4);
  });
  return value;
}

void main() {
  testWidgets('the canvas repaints when the sky turns to day',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = Size(_width.toDouble(), _height.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    final game = DinoGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: GameWidget<DinoGame>(
              game: game,
              overlayBuilderMap: _stubOverlays(),
            ),
          ),
        ),
      ),
    );
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    game.startGame();
    await tester.pump(const Duration(milliseconds: 16));

    // Sky near the top, and ground well below the horizon
    final int nightSky = await _pixelAt(tester, key, 40, 30);
    final int nightGround = await _pixelAt(tester, key, 40, _height - 20);

    _tick(
      game,
      GameConstants.themeCycleSeconds + GameConstants.themeTransitionSeconds + 1.0,
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.theme.isDay, isTrue);

    final int daySky = await _pixelAt(tester, key, 40, 30);
    final int dayGround = await _pixelAt(tester, key, 40, _height - 20);

    expect(nightSky, isNot(0), reason: 'the night frame has to have been painted');
    expect(daySky, isNot(nightSky), reason: 'the sky has to be repainted');
    expect(dayGround, isNot(nightGround), reason: 'the ground has to be repainted');
  });
}
