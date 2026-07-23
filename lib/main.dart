import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants/game_constants.dart';
import 'game/dino_game.dart';
import 'widgets/controls_overlay.dart';
import 'widgets/game_over_overlay.dart';
import 'widgets/hud_overlay.dart';
import 'widgets/main_menu_overlay.dart';
import 'widgets/settings_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon T-Rex Runner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: GameConstants.bgDark,
        fontFamily: 'monospace',
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final DinoGame _game;

  /// Owned here rather than left to GameWidget's internal node, so focus can be
  /// handed back to the canvas after an overlay button takes it.
  final FocusNode _gameFocusNode = FocusNode(debugLabel: 'dino-game-canvas');

  /// Tapping START or REPLAY focuses that button, which silently cuts the canvas
  /// off from the keyboard. Reclaim focus once the tap's frame has settled.
  void _restoreGameFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _gameFocusNode.requestFocus();
    });
  }

  @override
  void initState() {
    super.initState();
    // 1. Force landscape mode for standard running gameplay layout
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 2. Hide system status bar & navigation bar to make the canvas full-screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // 3. Instantiate the game engine exactly ONCE in state initialization
    _game = DinoGame()..onRequestFocus = _restoreGameFocus;
  }

  @override
  void dispose() {
    // 4. Reset orientation and system UI to avoid leaking settings to other system screens
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _gameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        // Safety net: key events bubble up from whichever descendant holds focus,
        // so even if an overlay button ends up owning it the arrow keys still
        // reach the game. GameWidget handles them first when it has focus, and a
        // handled event never propagates here, so no key is processed twice.
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (node, event) => _game.onKeyEvent(
            event,
            HardwareKeyboard.instance.logicalKeysPressed,
          ),
          child: GameWidget<DinoGame>(
            game: _game,
            focusNode: _gameFocusNode,
            autofocus: true,
            overlayBuilderMap: {
              'MainMenu': (context, game) => MainMenuOverlay(game: game),
              // Opened from the menu, before any run starts
              'Settings': (context, game) => SettingsOverlay(game: game),
              'GameOver': (context, game) => GameOverOverlay(game: game),
              'HUD': (context, game) => HudOverlay(game: game),
              // Added by DinoGame.startGame(), so it never covers the menus
              'Controls': (context, game) => ControlsOverlay(game: game),
            },
            initialActiveOverlays: const ['MainMenu', 'HUD'],
          ),
        ),
      ),
    );
  }
}
