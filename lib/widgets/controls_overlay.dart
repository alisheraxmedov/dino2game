import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/game_theme.dart';
import '../game/dino_game.dart';

/// Hold-to-move touch pad. Only rendered on phones and tablets — desktop and
/// web players drive the dino with the arrow keys instead.
class ControlsOverlay extends StatefulWidget {
  final DinoGame game;

  const ControlsOverlay({super.key, required this.game});

  @override
  State<ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<ControlsOverlay> {
  // Which direction pad is currently under a finger, so lifting one button
  // never cancels a hold that belongs to the other one.
  int _heldDirection = 0;
  // bool _jumpHeld = false;

  static const double _buttonSize = 68.0;

  void _pressDirection(int dir) {
    if (!mounted) return;
    setState(() => _heldDirection = dir);
    widget.game.setInputDirection(dir);
  }

  void _releaseDirection(int dir) {
    if (_heldDirection != dir) return;
    if (!mounted) return;
    setState(() => _heldDirection = 0);
    widget.game.setInputDirection(0);
  }

  /*
  void _pressJump() {
    if (!mounted) return;
    setState(() => _jumpHeld = true);
    widget.game.requestJump();
  }

  void _releaseJump() {
    if (!_jumpHeld) return;
    if (!mounted) return;
    setState(() => _jumpHeld = false);
  }
  */

  @override
  Widget build(BuildContext context) {
    // Keyboard is the input scheme everywhere except touch, so stay out of the way
    final bool isTouchPlatform = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!isTouchPlatform) return const SizedBox.shrink();

    final padding = MediaQuery.paddingOf(context);

    // The pads sit on top of the canvas, so they follow the day/night crossfade
    return ValueListenableBuilder<GameTheme>(
      valueListenable: widget.game.themeNotifier,
      builder: (context, theme, child) {
        return Positioned.fill(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 16.0 + padding.right),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildButton(
                        theme: theme,
                        icon: Icons.chevron_left_rounded,
                        color: theme.accent,
                        pressed: _heldDirection == -1,
                        onDown: () => _pressDirection(-1),
                        onUp: () => _releaseDirection(-1),
                      ),
                      const SizedBox(width: 14.0),
                      _buildButton(
                        theme: theme,
                        icon: Icons.chevron_right_rounded,
                        color: theme.accent,
                        pressed: _heldDirection == 1,
                        onDown: () => _pressDirection(1),
                        onUp: () => _releaseDirection(1),
                      ),
                    ],
                  ),
                ),
              ),
              /*
              Positioned(
                right: 16.0 + padding.right,
                bottom: 16.0 + padding.bottom,
                child: _buildButton(
                  theme: theme,
                  label: 'JUMP',
                  color: theme.obstacle,
                  pressed: _jumpHeld,
                  onDown: _pressJump,
                  onUp: _releaseJump,
                ),
              ),
              */
            ],
          ),
        );
      },
    );
  }

  /// A single translucent neon pad. [Listener] rather than a tap callback, so a
  /// held finger keeps the dino walking until it lifts.
  Widget _buildButton({
    required GameTheme theme,
    IconData? icon,
    String? label,
    required Color color,
    required bool pressed,
    required VoidCallback onDown,
    required VoidCallback onUp,
  }) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
          child: Container(
            width: _buttonSize,
            height: _buttonSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.panel.withAlpha(pressed ? 190 : 130),
                  theme.panel.withAlpha(pressed ? 150 : 90),
                ],
              ),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: color.withAlpha(pressed ? 200 : 70),
                width: pressed ? 2.0 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(pressed ? 90 : 30),
                  blurRadius: pressed ? 18.0 : 10.0,
                  spreadRadius: pressed ? 2.0 : 0.0,
                ),
              ],
            ),
            child: Center(
              child: icon != null
                  ? Icon(
                      icon,
                      size: 38.0,
                      color: color.withAlpha(pressed ? 255 : 190),
                    )
                  : Text(
                      label ?? '',
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w900,
                        color: color.withAlpha(pressed ? 255 : 190),
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
