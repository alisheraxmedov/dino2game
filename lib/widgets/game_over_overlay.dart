import 'dart:ui';
import 'package:flutter/material.dart';
import '../game/dino_game.dart';
import '../constants/game_constants.dart';

class GameOverOverlay extends StatelessWidget {
  final DinoGame game;

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final isNewHighScore = game.currentScore >= game.highScore && game.currentScore > 0;

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
          child: Container(
            width: 340,
            padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 28.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  GameConstants.bgDark.withAlpha(230),
                  const Color(0xFF150520).withAlpha(230),
                ],
              ),
              borderRadius: BorderRadius.circular(28.0),
              border: Border.all(
                color: GameConstants.neonPink.withAlpha(60),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: GameConstants.neonPink.withAlpha(30),
                  blurRadius: 30.0,
                  spreadRadius: 4.0,
                ),
                BoxShadow(
                  color: GameConstants.neonOrange.withAlpha(15),
                  blurRadius: 50.0,
                  spreadRadius: 8.0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      GameConstants.neonPink,
                      GameConstants.neonOrange,
                      Colors.redAccent,
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'GAME OVER',
                    style: TextStyle(
                      fontSize: 38.0,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 3.0,
                    ),
                  ),
                ),
                const SizedBox(height: 28.0),

                // Score display with gradient background
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withAlpha(12),
                        Colors.white.withAlpha(5),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(color: Colors.white.withAlpha(15)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'SCORE: ${game.currentScore}',
                        style: const TextStyle(
                          fontSize: 24.0,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (!isNewHighScore) ...[
                        const SizedBox(height: 4.0),
                        Text(
                          'HIGH SCORE: ${game.highScore}',
                          style: TextStyle(
                            fontSize: 13.0,
                            color: Colors.white.withAlpha(150),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12.0),

                if (isNewHighScore) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 14.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          GameConstants.neonGreen.withAlpha(25),
                          GameConstants.neonYellow.withAlpha(15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(
                        color: GameConstants.neonGreen.withAlpha(100),
                        width: 1.0,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events_rounded,
                            color: GameConstants.neonYellow, size: 20),
                        SizedBox(width: 8.0),
                        Text(
                          '🎉  NEW HIGH SCORE!',
                          style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: GameConstants.neonGreen,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28.0),

                InkWell(
                  onTap: game.startGame,
                  borderRadius: BorderRadius.circular(18.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          GameConstants.neonPink,
                          GameConstants.neonOrange,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18.0),
                      boxShadow: [
                        BoxShadow(
                          color: GameConstants.neonPink.withAlpha(80),
                          blurRadius: 16.0,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.replay_rounded, color: GameConstants.bgDark, size: 22),
                          SizedBox(width: 8.0),
                          Text(
                            'REPLAY',
                            style: TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w900,
                              color: GameConstants.bgDark,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
