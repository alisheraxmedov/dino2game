import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dino2game/game/components/coin.dart';
import 'package:dino2game/game/components/obstacle.dart';
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
  game.onGameResize(Vector2(800.0, 400.0));
  await game.onLoad();
  await game.ready();
  return game;
}

void _tick(DinoGame game, double seconds) {
  const step = 1 / 60;
  for (double t = 0; t < seconds; t += step) {
    game.update(step);
  }
}

class _FailingObstacle extends Obstacle {
  _FailingObstacle({required double screenHeight, required super.worldX})
    : super(
        size: Vector2.all(20),
        groundY: screenHeight - 20,
        groundRelativeY: 0,
      );

  @override
  Future<List<Sprite>> loadSprites() =>
      Future.error(StateError('deliberate sprite-load failure'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('world slots explicitly identify every supported entity kind', () {
    expect(WorldEntityKind.values.toSet(), {
      WorldEntityKind.cactus,
      WorldEntityKind.spikeMan,
      WorldEntityKind.springMan,
      WorldEntityKind.wingMan,
      WorldEntityKind.coin,
    });
  });

  test('a seeded long world contains hazards, coins, and platforms', () async {
    final game = await _bootGame(random: Random(7));
    game.startGame();
    game.setInputDirection(1);
    _tick(game, 35);

    final kinds = game.worldLayout.map((slot) => slot.kind).toSet();
    expect(kinds, containsAll(WorldEntityKind.values));
    expect(game.platformLayout, isNotEmpty);
  });

  test('platform footprints contain no hazard slots', () async {
    for (final testCase in [
      (direction: -1, seconds: 60.0),
      (direction: 1, seconds: 35.0),
    ]) {
      final game = await _bootGame(random: Random(7));
      game.startGame();
      game.setInputDirection(testCase.direction);
      _tick(game, testCase.seconds);

      expect(game.platformLayout, isNotEmpty);
      for (final platform in game.platformLayout) {
        final hazards = game.worldLayout.where(
          (slot) =>
              slot.kind != WorldEntityKind.coin &&
              slot.worldX >= platform.worldX &&
              slot.worldX <= platform.worldX + platform.width,
        );
        expect(
          hazards,
          isEmpty,
          reason:
              'direction ${testCase.direction} placed a hazard on a platform',
        );
      }
    }
  });

  test('platform footprints never overlap in either direction', () async {
    final cases = [
      (direction: -1, seconds: 60.0, seed: 70),
      (direction: 1, seconds: 35.0, seed: 111),
    ];

    for (final testCase in cases) {
      final game = await _bootGame(random: Random(testCase.seed));
      game.startGame();
      game.setInputDirection(testCase.direction);
      _tick(game, testCase.seconds);

      for (
        var firstIndex = 0;
        firstIndex < game.platformLayout.length;
        firstIndex++
      ) {
        final first = game.platformLayout[firstIndex];
        for (
          var secondIndex = firstIndex + 1;
          secondIndex < game.platformLayout.length;
          secondIndex++
        ) {
          final second = game.platformLayout[secondIndex];
          expect(
            first.containsWorldX(second.worldX, second.worldX + second.width),
            isFalse,
            reason:
                'platforms overlap for seed ${testCase.seed} while generating '
                'direction ${testCase.direction}: '
                '${first.worldX}..${first.worldX + first.width} and '
                '${second.worldX}..${second.worldX + second.width}',
          );
        }
      }
    }
  });

  test('restart and menu cleanup clear specs and live components', () async {
    final game = await _bootGame(random: Random(7));
    game.startGame();
    game.setInputDirection(1);
    _tick(game, 35);

    final oldLiveSlots = game.worldLayout
        .where((slot) => slot.live != null)
        .toList();
    expect(oldLiveSlots, isNotEmpty);
    expect(game.platformLayout, isNotEmpty);

    game.startGame();

    expect(game.worldLayout, isEmpty);
    expect(game.platformLayout, isEmpty);
    expect(oldLiveSlots.every((slot) => slot.live == null), isTrue);
    _tick(game, 1 / 60);
    expect(game.children.whereType<Obstacle>(), isEmpty);

    game.setInputDirection(1);
    _tick(game, 35);
    final menuLiveSlots = game.worldLayout
        .where((slot) => slot.live != null)
        .toList();
    expect(menuLiveSlots, isNotEmpty);
    expect(game.platformLayout, isNotEmpty);

    game.returnToMenu();

    expect(game.worldLayout, isEmpty);
    expect(game.platformLayout, isEmpty);
    expect(menuLiveSlots.every((slot) => slot.live == null), isTrue);
    _tick(game, 1 / 60);
    expect(game.children.whereType<Obstacle>(), isEmpty);
  });

  test(
    'layout getters are read-only and keep streamed specifications',
    () async {
      final game = await _bootGame(random: Random(7));
      game.startGame();
      game.setInputDirection(1);
      _tick(game, 35);

      final originalWorld = game.worldLayout.toList();
      final originalPlatforms = game.platformLayout.toList();
      final liveSlots = originalWorld
          .where((slot) => slot.live != null)
          .toList();
      expect(originalWorld, isNotEmpty);
      expect(originalPlatforms, isNotEmpty);
      expect(liveSlots, isNotEmpty);

      expect(
        () => game.worldLayout.add(
          WorldEntitySpec(worldX: 0, kind: WorldEntityKind.coin),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => game.platformLayout.add(ElevatedPlatformSpec(worldX: 0)),
        throwsUnsupportedError,
      );

      final originalOffset = game.worldOffset;
      game.setInputDirection(0);
      game.worldSpeed = 0;
      game.worldOffset = originalOffset + 10000;
      _tick(game, 2 / 60);
      expect(liveSlots.every((slot) => slot.live == null), isTrue);

      game.worldOffset = originalOffset;
      _tick(game, 2 / 60);

      expect(
        originalWorld.every(
          (expected) =>
              game.worldLayout.any((actual) => identical(actual, expected)),
        ),
        isTrue,
      );
      expect(
        originalPlatforms.every(
          (expected) =>
              game.platformLayout.any((actual) => identical(actual, expected)),
        ),
        isTrue,
      );
      expect(liveSlots.any((slot) => slot.live != null), isTrue);
    },
  );

  test('layout generation preserves the clear opening runway', () async {
    final game = await _bootGame(random: Random(7));
    game.startGame();
    _tick(game, 1 / 60);

    expect(game.worldLayout, isNotEmpty);
    expect(
      game.worldLayout.where(
        (slot) => slot.worldX >= 0 && slot.worldX <= game.size.x,
      ),
      isEmpty,
    );
    expect(
      game.platformLayout.where(
        (platform) => platform.containsWorldX(0, game.size.x),
      ),
      isEmpty,
    );
    expect(game.children.whereType<Obstacle>(), isEmpty);
  });

  test('collecting the same coin increments the counter only once', () async {
    final game = await _bootGame();
    game.startGame();
    final spec = WorldEntitySpec(
      worldX: game.worldOffset + game.dino.position.x,
      kind: WorldEntityKind.coin,
    );
    final coin = Coin(spec: spec, screenHeight: game.size.y);
    game.add(coin);
    await game.ready();

    coin.collect();
    coin.collect();

    expect(game.currentCoins, 1);
    expect(game.coinNotifier.value, 1);
    expect(spec.collected, isTrue);
  });

  test('colliding with a coin does not end the active run', () async {
    final game = await _bootGame();
    game.startGame();
    final spec = WorldEntitySpec(
      worldX: game.worldOffset + game.dino.position.x,
      kind: WorldEntityKind.coin,
    );
    final coin = Coin(spec: spec, screenHeight: game.size.y);
    game.add(coin);
    await game.ready();

    game.dino.onCollisionStart(<Vector2>{}, coin);

    expect(game.isPlaying, isTrue);
    expect(game.currentCoins, 1);
    expect(spec.collected, isTrue);
  });

  test('a collected streamed coin never respawns', () async {
    final game = await _bootGame();
    game.startGame();
    final spec = WorldEntitySpec(worldX: 900, kind: WorldEntityKind.coin);
    game.addWorldSpecForTest(spec);
    game.streamWorldForTest();
    final coin = spec.live! as Coin;
    coin.collect();

    game.worldOffset = 2000;
    game.streamWorldForTest();
    game.worldOffset = 500;
    game.streamWorldForTest();

    expect(spec.collected, isTrue);
    expect(spec.live, isNull);
  });

  test('a new run and menu return reset the coin count', () async {
    final game = await _bootGame();
    game.startGame();
    final first = WorldEntitySpec(worldX: 200, kind: WorldEntityKind.coin);
    expect(game.collectCoin(first), isTrue);
    expect(game.currentCoins, 1);

    game.startGame();
    expect(game.currentCoins, 0);
    expect(game.coinNotifier.value, 0);

    final second = WorldEntitySpec(worldX: 300, kind: WorldEntityKind.coin);
    expect(game.collectCoin(second), isTrue);
    game.returnToMenu();

    expect(game.currentCoins, 0);
    expect(game.coinNotifier.value, 0);
  });

  test('streaming renders hazards and coins but not platforms', () async {
    final game = await _bootGame(random: Random(7));
    game.startGame();
    game.setInputDirection(1);
    _tick(game, 35);

    final liveHazards = game.worldLayout.where(
      (slot) => slot.kind != WorldEntityKind.coin && slot.live != null,
    );
    expect(liveHazards, isNotEmpty);
    final liveCoins = game.worldLayout.where(
      (slot) => slot.kind == WorldEntityKind.coin && slot.live is Coin,
    );
    expect(liveCoins, isNotEmpty);
    expect(
      game.platformLayout.every((platform) => platform.live == null),
      isTrue,
    );
  });

  test('every hazard loads its Kenney sprite set', () async {
    final game = await _bootGame();
    final hazards = <Obstacle>[
      Cactus(
        variant: CactusVariant.smallSingle,
        screenHeight: game.size.y,
        worldX: 200,
      ),
      SpikeManEnemy(screenHeight: game.size.y, worldX: 300),
      SpringManEnemy(screenHeight: game.size.y, worldX: 400),
      WingMan(
        heightLevel: WingHeight.low,
        screenHeight: game.size.y,
        worldX: 500,
      ),
    ];

    for (final hazard in hazards) {
      game.add(hazard);
    }
    await game.ready();

    expect(hazards.every((hazard) => hazard.spritesLoaded), isTrue);
  });

  test('WingMan advances through the five supplied frames', () async {
    final game = await _bootGame();
    game.startGame();
    final wingMan = WingMan(
      heightLevel: WingHeight.low,
      screenHeight: game.size.y,
      worldX: 200,
    );
    game.add(wingMan);
    await game.ready();

    final start = wingMan.frameIndex;
    _tick(game, 0.25);

    expect(wingMan.frameIndex, isNot(start));
    expect(wingMan.frameCount, 5);
  });

  test(
    'streaming maps typed hazard specs to their sprite components',
    () async {
      final game = await _bootGame(random: Random(7));
      game.startGame();
      game.dino.position.x = -1000;
      game.setInputDirection(1);
      _tick(game, 35);

      const expectedTypes = {
        WorldEntityKind.cactus: Cactus,
        WorldEntityKind.spikeMan: SpikeManEnemy,
        WorldEntityKind.springMan: SpringManEnemy,
        WorldEntityKind.wingMan: WingMan,
      };

      for (final entry in expectedTypes.entries) {
        final spec = game.worldLayout.firstWhere(
          (candidate) => candidate.kind == entry.key,
        );
        game.setInputDirection(0);
        game.worldSpeed = 0;
        game.worldOffset = spec.worldX - game.size.x / 2;
        _tick(game, 1 / 60);
        await game.ready();

        expect(spec.live.runtimeType, entry.value, reason: entry.key.name);
      }
    },
  );

  test('sprite hazards retain fixed world anchors', () async {
    final game = await _bootGame();
    game.startGame();
    final hazards = <Obstacle>[
      Cactus(
        variant: CactusVariant.largeTriple,
        screenHeight: game.size.y,
        worldX: 300,
      ),
      SpikeManEnemy(screenHeight: game.size.y, worldX: 400),
      SpringManEnemy(screenHeight: game.size.y, worldX: 500),
      WingMan(
        heightLevel: WingHeight.high,
        screenHeight: game.size.y,
        worldX: 600,
      ),
    ];
    final originalY = {for (final hazard in hazards) hazard: hazard.position.y};
    for (final hazard in hazards) {
      game.add(hazard);
    }
    await game.ready();

    game.worldOffset = 125;
    _tick(game, 0.5);

    for (final hazard in hazards) {
      expect(hazard.position.x, hazard.worldX - game.worldOffset);
      expect(hazard.position.y, originalY[hazard]);
    }
  });

  test('a failed sprite set removes a harmless invisible hazard', () async {
    final game = await _bootGame();
    final hazard = _FailingObstacle(screenHeight: game.size.y, worldX: 200);

    game.add(hazard);
    await game.ready();
    _tick(game, 1 / 60);

    expect(hazard.spritesLoaded, isFalse);
    expect(hazard.children, isEmpty);
    expect(game.children.contains(hazard), isFalse);
  });
}
