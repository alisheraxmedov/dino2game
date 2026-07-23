import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('transitional streaming renders hazards but not coins', () async {
    final game = await _bootGame(random: Random(7));
    game.startGame();
    game.setInputDirection(1);
    _tick(game, 35);

    final liveHazards = game.worldLayout.where(
      (slot) => slot.kind != WorldEntityKind.coin && slot.live != null,
    );
    expect(liveHazards, isNotEmpty);
    expect(
      game.worldLayout
          .where((slot) => slot.kind == WorldEntityKind.coin)
          .every((slot) => slot.live == null),
      isTrue,
    );
    expect(
      game.platformLayout.every((platform) => platform.live == null),
      isTrue,
    );
  });
}
