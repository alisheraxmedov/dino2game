import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/game_theme.dart';
import '../game/dino_game.dart';

class HudOverlay extends StatelessWidget {
  final DinoGame game;

  const HudOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16.0,
      right: 16.0,
      left: 16.0,
      // The chrome follows the sky: dark glass at night, pale glass by day
      child: ValueListenableBuilder<GameTheme>(
        valueListenable: game.themeNotifier,
        builder: (context, theme, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPill(
                theme: theme,
                borderColor: theme.accent.withAlpha(40),
                // Driven by a notifier so the pill tracks movement without
                // rebuilding this whole overlay every frame
                child: ValueListenableBuilder<int>(
                  valueListenable: game.directionNotifier,
                  builder: (context, direction, child) {
                    final statusColor = direction > 0
                        ? theme.grass
                        : direction < 0
                            ? theme.thorn
                            : theme.accent.withAlpha(120);
                    final statusLabel = direction > 0
                        ? 'FORWARD'
                        : direction < 0
                            ? 'REVERSE'
                            : 'IDLE';

                    return Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withAlpha(120),
                                blurRadius: 4.0,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        Icon(
                          theme.isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                          color: theme.accent,
                          size: 14.0,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w800,
                            color: theme.accent,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              _buildPill(
                theme: theme,
                borderColor: theme.highlight.withAlpha(40),
                child: Row(
                  children: [
                    if (game.highScore > 0) ...[
                      Text(
                        'HI ${game.highScore.toString().padLeft(5, '0')}',
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w700,
                          color: theme.accent.withAlpha(150),
                          fontFamily: 'monospace',
                          letterSpacing: 1.0,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 16,
                        margin: const EdgeInsets.symmetric(horizontal: 10.0),
                        color: theme.accent.withAlpha(60),
                      ),
                    ],
                    ValueListenableBuilder<int>(
                      valueListenable: game.scoreNotifier,
                      builder: (context, score, child) {
                        return Text(
                          score.toString().padLeft(5, '0'),
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.w900,
                            color: theme.highlight,
                            fontFamily: 'monospace',
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                color: theme.highlight.withAlpha(160),
                                blurRadius: 6.0,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPill({
    required GameTheme theme,
    required Color borderColor,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.panel.withAlpha(170),
                theme.panel.withAlpha(110),
              ],
            ),
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: child,
        ),
      ),
    );
  }
}
