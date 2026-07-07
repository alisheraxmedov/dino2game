import 'dart:ui';
import 'package:flutter/material.dart';
import '../game/dino_game.dart';
import '../constants/game_constants.dart';

class HudOverlay extends StatelessWidget {
  final DinoGame game;

  const HudOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16.0,
      right: 16.0,
      left: 16.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      GameConstants.bgDark.withAlpha(160),
                      GameConstants.bgDark.withAlpha(100),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(
                    color: GameConstants.neonCyan.withAlpha(40),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: GameConstants.neonGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: GameConstants.neonGreen.withAlpha(120),
                            blurRadius: 4.0,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    const Icon(
                      Icons.bolt,
                      color: GameConstants.neonCyan,
                      size: 14.0,
                    ),
                    const SizedBox(width: 4.0),
                    const Text(
                      'RUNNING',
                      style: TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w800,
                        color: GameConstants.neonCyan,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      GameConstants.bgDark.withAlpha(100),
                      GameConstants.bgDark.withAlpha(160),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(
                    color: GameConstants.neonYellow.withAlpha(30),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    if (game.highScore > 0) ...[
                      Text(
                        'HI ${game.highScore.toString().padLeft(5, '0')}',
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withAlpha(100),
                          fontFamily: 'monospace',
                          letterSpacing: 1.0,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 16,
                        margin: const EdgeInsets.symmetric(horizontal: 10.0),
                        color: Colors.white.withAlpha(30),
                      ),
                    ],
                    ValueListenableBuilder<int>(
                      valueListenable: game.scoreNotifier,
                      builder: (context, score, child) {
                        return Text(
                          score.toString().padLeft(5, '0'),
                          style: const TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.w900,
                            color: GameConstants.neonYellow,
                            fontFamily: 'monospace',
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                color: GameConstants.neonYellow,
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
            ),
          ),
        ],
      ),
    );
  }
}
