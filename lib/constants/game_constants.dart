import 'package:flutter/material.dart';

class GameConstants {
  // Game Physics & Speeds
  static const double gravity = 1500.0;
  static const double jumpForce = 620.0;

  // Player-driven Movement (the world scrolls only while a control is held)
  static const double maxRunSpeed = 420.0;
  static const double maxBackSpeed = 260.0;
  static const double moveAcceleration = 2200.0;
  static const double moveDeceleration = 2800.0;
  static const double movingThreshold = 20.0;

  // Runner Dimensions. The Kenney sprite sheet is 80x110, so the height is kept
  // close to the old hand-drawn dino to preserve every obstacle clearance.
  static const double dinoWidth = 52.0;
  static const double dinoHeight = 72.0;
  static const double dinoGroundYOffset = 30.0;

  // Runner sprite frames. The folder comes from the selected GameCharacter.
  static const double runnerWalkFrameTime = 0.13;

  // Day/night cycle: each sky holds for this long while the player is running,
  // then crossfades into the other one.
  static const double themeCycleSeconds = 30.0;
  static const double themeTransitionSeconds = 2.5;

  // shared_preferences keys
  static const String highScoreKey = 'high_score';
  static const String characterKey = 'character_id';

  // Spawning (measured in pixels of world laid out, not seconds elapsed)
  static const double initialSpawnDistance = 560.0;
  static const double minSpawnDistance = 300.0;
  static const double spawnDistanceJitter = 180.0;
  static const double spawnRampScore = 400.0;
  static const double obstacleSpawnChanceBird = 0.3;

  // How far past each screen edge the world stays generated and instantiated
  static const double worldStreamMargin = 400.0;

  // Scoring (forward pixels per point)
  static const double scoreDistanceDivisor = 35.0;

  // Premium Color Palette
  static const Color bgDark = Color(0xFF050B18);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonPink = Color(0xFFFF2D7C);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonYellow = Color(0xFFFFE500);
  static const Color neonOrange = Color(0xFFFF6B00);
  static const Color neonPurple = Color(0xFFBF40FF);
  static const Color groundColor = Color(0xFF1A1A3E);
  static const Color gridColor = Color(0xFF0D1B3E);
  static const Color horizonGlow = Color(0xFF1B0533);
}
