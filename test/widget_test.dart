// Gameplay tests for the hold-to-move control scheme: the world only scrolls
// while a control is held, and the score tracks forward progress only.

import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dino2game/constants/game_characters.dart';
import 'package:dino2game/constants/game_constants.dart';
import 'package:dino2game/constants/game_theme.dart';
import 'package:dino2game/game/components/obstacle.dart';
import 'package:dino2game/game/dino_game.dart';
import 'package:dino2game/game/world_layout.dart';
import 'package:dino2game/widgets/controls_overlay.dart';
import 'package:dino2game/widgets/hud_overlay.dart';
import 'package:dino2game/widgets/settings_overlay.dart';

/// Stub overlay builders — the real widgets are exercised by the widget test.
Map<String, OverlayWidgetBuilder<DinoGame>> _stubOverlays() => {
  for (final name in ['MainMenu', 'Settings', 'GameOver', 'HUD', 'Controls'])
    name: (context, game) => const SizedBox.shrink(),
};

/// Boots a headless game instance and runs it until its components are mounted.
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

/// Advances the simulation for [seconds] at a fixed 60 Hz step.
void _tick(DinoGame game, double seconds) {
  const step = 1 / 60;
  for (double t = 0; t < seconds; t += step) {
    game.update(step);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('world stays frozen while no control is held', () async {
    final game = await _bootGame();
    game.startGame();

    _tick(game, 1.0);

    expect(game.worldSpeed, 0.0);
    expect(game.currentScore, 0);
    expect(game.directionNotifier.value, 0);
  });

  test('holding forward ramps the world up to max run speed', () async {
    final game = await _bootGame();
    game.startGame();
    game.setInputDirection(1);

    _tick(game, 1.0);

    expect(game.worldSpeed, closeTo(GameConstants.maxRunSpeed, 0.001));
    expect(game.directionNotifier.value, 1);
    expect(game.currentScore, greaterThan(0));
  });

  test('releasing the control brings the world back to a standstill', () async {
    final game = await _bootGame();
    game.startGame();
    game.setInputDirection(1);
    _tick(game, 1.0);

    game.setInputDirection(0);
    _tick(game, 1.0);

    expect(game.worldSpeed, 0.0);
    expect(game.directionNotifier.value, 0);
  });

  test('backing up is slower and never changes the score', () async {
    final game = await _bootGame();
    game.startGame();
    game.setInputDirection(1);
    _tick(game, 1.0);
    expect(game.currentScore, greaterThan(0));

    game.setInputDirection(-1);
    _tick(game, 1.0);

    expect(GameConstants.maxBackSpeed, lessThan(GameConstants.maxRunSpeed));
    expect(game.worldSpeed, closeTo(-GameConstants.maxBackSpeed, 0.001));
    expect(game.directionNotifier.value, -1);

    // The score peaked the instant the dino stopped advancing — retreating
    // further can never roll it back
    final peakScore = game.currentScore;
    _tick(game, 0.5);
    expect(game.currentScore, peakScore);

    // ...and re-walking that same ground earns nothing extra
    game.setInputDirection(1);
    _tick(game, 0.25);
    expect(game.currentScore, peakScore);
  });

  test('reversing finds obstacles behind the starting line', () async {
    final game = await _bootGame(random: Random(7));
    game.startGame();

    // Nothing is instantiated on the opening screen — that stretch is the runway
    expect(game.children.whereType<Obstacle>(), isEmpty);

    game.setInputDirection(-1);
    _tick(game, 3.0);

    final behind = game.worldLayout.where((slot) => slot.worldX < 0).toList();
    expect(
      behind,
      isNotEmpty,
      reason: 'backing up must generate persistent world slots',
    );
    expect(behind.every((slot) => slot.worldX < 0), isTrue);
  });

  test('ground already walked keeps the same obstacles', () async {
    final game = await _bootGame(random: Random(7));
    game.startGame();

    game.setInputDirection(1);
    _tick(game, 4.0);
    final aheadX = game.worldLayout
        .where((slot) => slot.kind != WorldEntityKind.coin && slot.live != null)
        .map((slot) => slot.worldX)
        .toSet();
    expect(aheadX, isNotEmpty);

    // Walk back over that same ground and out the other side
    game.setInputDirection(-1);
    _tick(game, 8.0);
    expect(game.worldOffset, lessThan(0.0));

    // ...then return: the obstacles are still standing where they were left
    game.setInputDirection(1);
    _tick(game, 6.0);
    final returnedX = game.worldLayout
        .where((slot) => slot.kind != WorldEntityKind.coin && slot.live != null)
        .map((slot) => slot.worldX)
        .toSet();
    expect(returnedX.intersection(aheadX), isNotEmpty);
  });

  test('game over freezes the world regardless of held input', () async {
    final game = await _bootGame();
    game.startGame();
    game.setInputDirection(1);
    _tick(game, 1.0);

    game.triggerGameOver();
    _tick(game, 0.5);

    expect(game.worldSpeed, 0.0);
    expect(game.inputDirection, 0);
    expect(game.overlays.isActive('Controls'), isFalse);
  });

  test('the sky holds through the night, then crossfades into day', () async {
    final game = await _bootGame();
    game.startGame();
    expect(game.theme.isDay, isFalse);

    _tick(game, GameConstants.themeCycleSeconds - 1.0);
    expect(
      game.theme.isDay,
      isFalse,
      reason: 'the night has to hold for a full cycle before it turns',
    );

    _tick(game, GameConstants.themeTransitionSeconds + 1.5);
    expect(game.theme.isDay, isTrue);
    // ...and the crossfade lands fully on the day palette, not halfway
    expect(game.theme.sky0, GameTheme.day.sky0);
    expect(game.theme.starOpacity, GameTheme.day.starOpacity);
  });

  test('the cycle turns back around, and a new run reopens at night', () async {
    final game = await _bootGame();
    game.startGame();

    // Night hold + crossfade + day hold + crossfade back
    _tick(
      game,
      (GameConstants.themeCycleSeconds + GameConstants.themeTransitionSeconds) *
              2 +
          1.0,
    );
    expect(
      game.theme.isDay,
      isFalse,
      reason: 'day has to give way to night again',
    );

    _tick(
      game,
      GameConstants.themeCycleSeconds +
          GameConstants.themeTransitionSeconds +
          1.0,
    );
    expect(game.theme.isDay, isTrue);

    game.startGame();
    expect(game.theme.isDay, isFalse, reason: 'every run opens at night');
  });

  test('the sky stands still on the menu', () async {
    final game = await _bootGame();

    _tick(
      game,
      GameConstants.themeCycleSeconds +
          GameConstants.themeTransitionSeconds +
          1.0,
    );

    expect(game.isIntro, isTrue);
    expect(game.theme.isDay, isFalse);
  });

  test('a fresh install runs as the player', () async {
    SharedPreferences.setMockInitialValues({});
    final game = await _bootGame();

    expect(game.selectedCharacter.id, GameCharacter.player.id);
  });

  test('a saved runner is restored on launch, never asked for again', () async {
    SharedPreferences.setMockInitialValues({
      GameConstants.characterKey: 'zombie',
    });
    final game = await _bootGame();

    expect(game.selectedCharacter.id, GameCharacter.zombie.id);
  });

  test('an unknown stored id falls back to the player', () async {
    SharedPreferences.setMockInitialValues({
      GameConstants.characterKey: 'triceratops',
    });
    final game = await _bootGame();

    expect(game.selectedCharacter.id, GameCharacter.player.id);
  });

  test('picking a runner writes it straight to storage', () async {
    SharedPreferences.setMockInitialValues({});
    final game = await _bootGame();

    await game.selectCharacter(GameCharacter.soldier);

    expect(game.selectedCharacter.id, GameCharacter.soldier.id);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(GameConstants.characterKey),
      GameCharacter.soldier.id,
    );
    // The pick is worthless if that sprite folder does not resolve
    expect(game.dino.loadedCharacter?.id, GameCharacter.soldier.id);
  });

  test('every runner in the picker has a sprite set that loads', () async {
    SharedPreferences.setMockInitialValues({});
    final game = await _bootGame();

    for (final character in GameCharacter.all) {
      await game.dino.applyCharacter(character);
      expect(
        game.dino.loadedCharacter?.id,
        character.id,
        reason: 'the ${character.id} poses have to load from assets',
      );
    }
  });

  testWidgets('the settings screen offers every runner and saves the pick', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final game = DinoGame();
    await tester.pumpWidget(
      MaterialApp(
        // Scaffold stands in for the app shell: the overlay uses InkWell, which
        // needs a Material ancestor exactly as it has in main.dart
        home: Scaffold(
          body: GameWidget<DinoGame>(
            game: game,
            overlayBuilderMap: {
              ..._stubOverlays(),
              'Settings': (context, game) => SettingsOverlay(game: game),
            },
            initialActiveOverlays: const ['MainMenu'],
          ),
        ),
      ),
    );
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Settings sit in front of the menu, before any run has started
    game.openSettings();
    await tester.pump(const Duration(milliseconds: 16));

    for (final character in GameCharacter.all) {
      expect(find.text(character.label), findsOneWidget);
    }

    await tester.tap(find.text(GameCharacter.zombie.label));
    await tester.pump(const Duration(milliseconds: 16));

    expect(game.selectedCharacter.id, GameCharacter.zombie.id);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(GameConstants.characterKey),
      GameCharacter.zombie.id,
    );
  });

  testWidgets('the HUD renders the collected coin count', (
    WidgetTester tester,
  ) async {
    final game = DinoGame();
    game.coinNotifier.value = 3;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(children: [HudOverlay(game: game)]),
        ),
      ),
    );

    expect(find.byIcon(Icons.monetization_on_rounded), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('arrow keys reach the game even when the canvas has lost focus', (
    WidgetTester tester,
  ) async {
    // Clicking START or REPLAY hands keyboard focus to that button, which used
    // to cut the canvas off from the keyboard for the rest of the run: taps kept
    // jumping, the arrow keys did nothing. A key handler above the GameWidget
    // catches whatever the focused descendant leaves unhandled.
    SharedPreferences.setMockInitialValues({});

    final gameFocus = FocusNode(debugLabel: 'canvas');
    final thiefFocus = FocusNode(debugLabel: 'overlay-button');
    addTearDown(gameFocus.dispose);
    addTearDown(thiefFocus.dispose);

    final game = DinoGame();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (node, event) => game.onKeyEvent(
              event,
              HardwareKeyboard.instance.logicalKeysPressed,
            ),
            child: Stack(
              children: [
                GameWidget<DinoGame>(
                  game: game,
                  focusNode: gameFocus,
                  autofocus: true,
                  overlayBuilderMap: _stubOverlays(),
                ),
                // Stands in for the START button that steals the focus
                Focus(
                  focusNode: thiefFocus,
                  child: const SizedBox(width: 10, height: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    game.startGame();
    thiefFocus.requestFocus();
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      gameFocus.hasFocus,
      isFalse,
      reason: 'the canvas must have lost focus',
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.inputDirection, 1);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.inputDirection, 0);
  });

  testWidgets('touch pad holds a direction until the finger lifts', (
    WidgetTester tester,
  ) async {
    // The pad only builds on touch platforms
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // Without this the high-score channel never answers under fake async and
    // the game stays stuck in onLoad
    SharedPreferences.setMockInitialValues({});

    try {
      final game = DinoGame();
      await tester.pumpWidget(
        MaterialApp(
          home: GameWidget<DinoGame>(
            game: game,
            overlayBuilderMap: {
              ..._stubOverlays(),
              'Controls': (context, game) => ControlsOverlay(game: game),
            },
          ),
        ),
      );
      // Let onLoad resolve and the first frames run
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      game.startGame();
      await tester.pump(const Duration(milliseconds: 16));

      final forward = find.byIcon(Icons.chevron_right_rounded);
      expect(forward, findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(forward));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.inputDirection, 1);

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.inputDirection, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
