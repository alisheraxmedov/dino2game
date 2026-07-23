import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/game_characters.dart';
import '../constants/game_constants.dart';
import '../game/dino_game.dart';

/// Pre-run settings. The only choice here is the runner, and picking one writes
/// straight to shared_preferences — the game never asks again on later launches.
class SettingsOverlay extends StatelessWidget {
  final DinoGame game;

  const SettingsOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      // Landscape phones are short: the panel scrolls instead of overflowing
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height - 24.0,
        ),
        child: SingleChildScrollView(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 560.0),
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      GameConstants.bgDark.withAlpha(230),
                      const Color(0xFF0A0520).withAlpha(230),
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
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          GameConstants.neonCyan,
                          GameConstants.neonPurple,
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'SETTINGS',
                        style: TextStyle(
                          fontSize: 26.0,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 4.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'CHOOSE YOUR RUNNER',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withAlpha(140),
                        letterSpacing: 3.0,
                      ),
                    ),
                    const SizedBox(height: 18.0),

                    // Rebuilt on every pick so the selected card is always the
                    // one the game will actually spawn
                    ValueListenableBuilder<GameCharacter>(
                      valueListenable: game.characterNotifier,
                      builder: (context, selected, child) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final character in GameCharacter.all) ...[
                                _CharacterCard(
                                  character: character,
                                  selected: character.id == selected.id,
                                  onTap: () => game.selectCharacter(character),
                                ),
                                if (character != GameCharacter.all.last)
                                  const SizedBox(width: 10.0),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14.0),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_rounded,
                            size: 13.0, color: GameConstants.neonGreen.withAlpha(170)),
                        const SizedBox(width: 6.0),
                        Text(
                          'SAVED — ASKED ONLY ONCE',
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withAlpha(120),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18.0),

                    InkWell(
                      onTap: game.closeSettings,
                      // The canvas keeps keyboard focus, exactly like START does
                      canRequestFocus: false,
                      borderRadius: BorderRadius.circular(16.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13.0),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              GameConstants.neonCyan,
                              GameConstants.neonPurple,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              color: GameConstants.neonCyan.withAlpha(70),
                              blurRadius: 14.0,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '←  BACK TO MENU',
                            style: TextStyle(
                              fontSize: 14.0,
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
        ),
      ),
    );
  }
}

/// A single runner tile: idle pose, name, and a neon frame when it is the one
/// currently saved.
class _CharacterCard extends StatelessWidget {
  final GameCharacter character;
  final bool selected;
  final VoidCallback onTap;

  const _CharacterCard({
    required this.character,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent =
        selected ? GameConstants.neonCyan : Colors.white.withAlpha(50);

    return InkWell(
      onTap: onTap,
      canRequestFocus: false,
      borderRadius: BorderRadius.circular(16.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 92.0,
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 6.0),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(selected ? 18 : 8),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: accent, width: selected ? 2.0 : 1.0),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: GameConstants.neonCyan.withAlpha(60),
                    blurRadius: 16.0,
                    spreadRadius: 1.0,
                  ),
                ]
              : const [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              character.previewAsset,
              height: 62.0,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(height: 8.0),
            Text(
              character.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.w900,
                color: selected ? GameConstants.neonCyan : Colors.white.withAlpha(190),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 2.0),
            Text(
              character.blurb,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.0,
                height: 1.3,
                color: Colors.white.withAlpha(110),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
