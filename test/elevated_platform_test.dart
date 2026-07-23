import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart' show Sprite;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dino2game/constants/game_constants.dart';
import 'package:dino2game/game/components/elevated_platform.dart';
import 'package:dino2game/game/dino_game.dart';
import 'package:dino2game/game/world_layout.dart';

Map<String, OverlayWidgetBuilder<DinoGame>> _stubOverlays() => {
  for (final name in ['MainMenu', 'Settings', 'GameOver', 'HUD', 'Controls'])
    name: (context, game) => const SizedBox.shrink(),
};

Future<DinoGame> _bootGame({Random? random}) async {
  final game = DinoGame(random: random);
  _stubOverlays().forEach(
    (name, builder) =>
        game.overlays.addEntry(name, (context, _) => builder(context, game)),
  );
  game.onGameResize(Vector2(800, 400));
  await game.onLoad();
  await game.ready();
  return game;
}

void _tick(DinoGame game, double seconds) {
  const step = 1 / 60;
  for (double elapsed = 0; elapsed < seconds; elapsed += step) {
    game.update(step);
  }
}

double _platformTop(DinoGame game, ElevatedPlatformSpec spec) =>
    game.size.y - GameConstants.dinoGroundYOffset - spec.elevation;

Future<ElevatedPlatformSpec> _landOnPlatform(DinoGame game) async {
  final spec = ElevatedPlatformSpec(worldX: 40, width: 240, elevation: 90);
  game.addPlatformSpecForTest(spec);
  game.requestJump();

  for (var frame = 0; frame < 180; frame++) {
    game.update(1 / 60);
    if (game.dino.isOnElevatedPlatform) return spec;
  }
  fail('runner never landed on the elevated platform');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('runner passes upward through a one-way platform', () async {
    final game = await _bootGame();
    game.startGame();
    final spec = ElevatedPlatformSpec(worldX: 40, width: 240, elevation: 90);
    game.addPlatformSpecForTest(spec);

    game.requestJump();
    var feetPassedAboveTop = false;
    while (game.dino.verticalVelocity < 0) {
      game.update(1 / 60);
      final feetY = game.dino.position.y + game.dino.size.y;
      if (feetY < _platformTop(game, spec)) {
        feetPassedAboveTop = true;
      }
      expect(game.dino.isOnElevatedPlatform, isFalse);
    }

    expect(feetPassedAboveTop, isTrue);
  });

  test('runner lands on the platform only while descending', () async {
    final game = await _bootGame();
    game.startGame();
    final spec = await _landOnPlatform(game);

    expect(game.dino.verticalVelocity, 0);
    expect(game.dino.isOnElevatedPlatform, isTrue);
    expect(
      game.dino.position.y + game.dino.size.y,
      closeTo(_platformTop(game, spec), 0.01),
    );
  });

  test('runner remains supported while standing on the footprint', () async {
    final game = await _bootGame();
    game.startGame();
    final spec = await _landOnPlatform(game);
    final standingY = game.dino.position.y;

    _tick(game, 1);

    expect(game.dino.isOnElevatedPlatform, isTrue);
    expect(game.dino.position.y, closeTo(standingY, 0.01));
    expect(
      game.hasPlatformSupport(
        worldLeft: game.worldOffset + game.dino.position.x,
        worldRight: game.worldOffset + game.dino.position.x + game.dino.size.x,
        feetY: _platformTop(game, spec),
      ),
      isTrue,
    );
  });

  test('runner falls after the platform footprint scrolls away', () async {
    final game = await _bootGame();
    game.startGame();
    await _landOnPlatform(game);

    game.worldOffset = 400;
    game.update(1 / 60);
    expect(game.dino.isOnElevatedPlatform, isFalse);
    expect(game.dino.verticalVelocity, greaterThan(0));

    _tick(game, 1);
    expect(
      game.dino.position.y,
      closeTo(
        game.size.y -
            GameConstants.dinoGroundYOffset -
            GameConstants.dinoHeight,
        0.01,
      ),
    );
  });

  test('runner can jump from an elevated platform', () async {
    final game = await _bootGame();
    game.startGame();
    final spec = await _landOnPlatform(game);
    final platformY = game.dino.position.y;

    game.requestJump();
    game.update(1 / 60);

    expect(game.dino.isOnElevatedPlatform, isFalse);
    expect(game.dino.verticalVelocity, lessThan(0));
    expect(game.dino.position.y, lessThan(platformY));
    expect(
      game.dino.position.y + game.dino.size.y,
      lessThan(_platformTop(game, spec)),
    );
  });

  test(
    'support queries use specs even when no platform view is mounted',
    () async {
      final game = await _bootGame();
      game.startGame();
      final spec = ElevatedPlatformSpec(worldX: 60, width: 240, elevation: 90);
      game.addPlatformSpecForTest(spec);

      final top = _platformTop(game, spec);
      expect(spec.live, isNull);
      expect(
        game.landingSurfaceY(
          worldLeft: 80,
          worldRight: 120,
          previousFeetY: top - 1,
          currentFeetY: top + 1,
        ),
        top,
      );
      expect(
        game.landingSurfaceY(
          worldLeft: 80,
          worldRight: 120,
          previousFeetY: top + 1,
          currentFeetY: top - 1,
        ),
        isNull,
        reason: 'upward crossings must pass through',
      );
    },
  );

  test('removing a platform while sprites load clears it safely', () async {
    final game = await _bootGame();
    game.startGame();
    final spec = ElevatedPlatformSpec(worldX: 200, width: 240, elevation: 90);
    final loadedSprites = await Future.wait([
      Sprite.load(ElevatedPlatform.assetName(isDay: false)),
      Sprite.load(ElevatedPlatform.assetName(isDay: true)),
    ]);
    final spriteLoad = Completer<List<Sprite>>();
    final platform = ElevatedPlatform(
      spec: spec,
      spriteLoader: () => spriteLoad.future,
    );
    spec.live = platform;

    game.add(platform);
    game.update(0);
    platform.removeFromParent();
    spec.live = null;
    game.update(0);

    expect(
      platform.findGame(),
      same(game),
      reason: 'async loading must retain its owning game after detachment',
    );
    spriteLoad.complete(loadedSprites);
    await game.ready();
    expect(spec.live, isNull);
    expect(game.children, isNot(contains(platform)));
  });

  test('platforms stream out, return, and clear safely across runs', () async {
    final game = await _bootGame();
    game.startGame();
    final spec = ElevatedPlatformSpec(
      worldX: game.worldOffset + 200,
      width: 240,
      elevation: 90,
    );
    game.addPlatformSpecForTest(spec);

    game.streamWorldForTest();
    await game.ready();
    final firstView = spec.live;
    expect(firstView, isA<ElevatedPlatform>());
    expect(game.children.whereType<ElevatedPlatform>(), contains(firstView));

    game.worldOffset = 2000;
    game.streamWorldForTest();
    game.update(0);
    expect(spec.live, isNull);
    expect(game.children, isNot(contains(firstView)));

    game.worldOffset = 0;
    game.streamWorldForTest();
    await game.ready();
    expect(spec.live, isA<ElevatedPlatform>());
    expect(identical(spec.live, firstView), isFalse);
    final secondView = spec.live;

    game.startGame();
    expect(spec.live, isNull);
    expect(game.platformLayout, isEmpty);
    game.update(0);
    expect(game.children, isNot(contains(secondView)));
  });
}
