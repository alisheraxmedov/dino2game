import 'package:flutter/material.dart';

class GameConstants {
  // Game Physics & Speeds
  static const double gravity = 1500.0;
  static const double initialSpeed = 350.0;
  static const double maxSpeed = 700.0;
  static const double speedIncreaseRate = 10.0;
  static const double jumpForce = 620.0;

  // Dino Dimensions (larger for more detail)
  static const double dinoWidth = 64.0;
  static const double dinoHeight = 68.0;
  static const double dinoGroundYOffset = 10.0;

  // Spawning
  static const double initialSpawnTimerLimit = 1.6;
  static const double minSpawnTimerLimit = 0.8;
  static const double obstacleSpawnChanceBird = 0.3;

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
