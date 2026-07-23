import 'dart:ui';
import 'package:flutter/material.dart';
import '../game/dino_game.dart';
import '../constants/game_constants.dart';

class MainMenuOverlay extends StatelessWidget {
  final DinoGame game;

  const MainMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            width: 340,
            padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 28.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  GameConstants.bgDark.withAlpha(220),
                  const Color(0xFF0A0520).withAlpha(220),
                ],
              ),
              borderRadius: BorderRadius.circular(28.0),
              border: Border.all(
                color: GameConstants.neonCyan.withAlpha(60),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: GameConstants.neonCyan.withAlpha(30),
                  blurRadius: 30.0,
                  spreadRadius: 4.0,
                ),
                BoxShadow(
                  color: GameConstants.neonPurple.withAlpha(20),
                  blurRadius: 50.0,
                  spreadRadius: 8.0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      GameConstants.neonCyan,
                      GameConstants.neonPurple,
                      GameConstants.neonPink,
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'NEON T-REX',
                    style: TextStyle(
                      fontSize: 38.0,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 3.0,
                    ),
                  ),
                ),
                const SizedBox(height: 4.0),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      GameConstants.neonPink,
                      GameConstants.neonOrange,
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'CYBER RUNNER',
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 6.0,
                    ),
                  ),
                ),
                const SizedBox(height: 32.0),

                if (game.highScore > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          GameConstants.neonYellow.withAlpha(20),
                          GameConstants.neonOrange.withAlpha(10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(
                        color: GameConstants.neonYellow.withAlpha(60),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events_rounded,
                            color: GameConstants.neonYellow, size: 20.0),
                        const SizedBox(width: 8.0),
                        Text(
                          'HIGH SCORE: ${game.highScore}',
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: GameConstants.neonYellow,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),
                ],

                Container(
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(8),
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(color: Colors.white.withAlpha(10)),
                  ),
                  child: Column(
                    children: [
                      _buildInstructionRow(Icons.swap_horiz_rounded, '←  →  Hold to Move  •  Nothing Held = Stand Still'),
                      const SizedBox(height: 12.0),
                      _buildInstructionRow(Icons.touch_app_rounded, 'Space / Tap JUMP to Leap'),
                      const SizedBox(height: 12.0),
                      _buildInstructionRow(Icons.warning_amber_rounded, 'Avoid Neon Cacti & Pterodactyls'),
                    ],
                  ),
                ),
                const SizedBox(height: 32.0),

                InkWell(
                  onTap: game.startGame,
                  // Never take keyboard focus off the canvas — the arrow keys
                  // have to keep reaching the game after this is clicked
                  canRequestFocus: false,
                  borderRadius: BorderRadius.circular(18.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          GameConstants.neonCyan,
                          GameConstants.neonPurple,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18.0),
                      boxShadow: [
                        BoxShadow(
                          color: GameConstants.neonCyan.withAlpha(80),
                          blurRadius: 16.0,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '▶  START RUNNING',
                        style: TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w900,
                          color: GameConstants.bgDark,
                          letterSpacing: 2.0,
                        ),
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

  Widget _buildInstructionRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16.0, color: GameConstants.neonCyan.withAlpha(180)),
        const SizedBox(width: 10.0),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.0,
              color: Colors.white.withAlpha(180),
            ),
          ),
        ),
      ],
    );
  }
}
