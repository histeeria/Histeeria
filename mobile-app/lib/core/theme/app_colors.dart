import 'package:flutter/material.dart';

/// YouTube Music inspired color palette
class AppColors {
  // Deep dark backgrounds (YouTube Music style)
  static const Color backgroundPrimary = Color(0xFF0A0A0A);
  static const Color backgroundSecondary = Color(0xFF121212);
  static const Color backgroundTertiary = Color(0xFF1A1A1A);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceElevated = Color(0xFF242424);

  // Upvista Digital brand colors
  static const Color accentPrimary = Color(0xFF9B59B6); // Purple
  static const Color accentSecondary = Color(0xFFE94560); // Pink
  static const Color accentTertiary = Color(0xFF4A90E2); // Blue
  static const Color accentQuaternary = Color(0xFFE74C3C); // Red

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF808080);

  // Gradient colors for backgrounds (Upvista brand)
  static const List<Color> gradientWarm = [
    Color(0xFF9B59B6), // Purple
    Color(0xFFE94560), // Pink
    Color(0xFF4A90E2), // Blue
  ];

  static const List<Color> gradientCool = [
    Color(0xFF4A90E2), // Blue
    Color(0xFF9B59B6), // Purple
    Color(0xFFE94560), // Pink
  ];

  static const List<Color> gradientPurple = [
    Color(0xFF8E44AD), // Deep purple
    Color(0xFF9B59B6), // Purple
    Color(0xFFE94560), // Pink
  ];

  // Glassmorphism colors
  static Color glassBackground = Colors.white.withOpacity(0.05);
  static Color glassBorder = Colors.white.withOpacity(0.1);
  static Color glassElevated = Colors.white.withOpacity(0.1);

  // Social login brand colors
  static const Color googleRed = Color(0xFFDB4437);
  static const Color linkedInBlue = Color(0xFF0077B5);
  static const Color githubGray = Color(0xFF24292E);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE94560);
  static const Color warning = Color(0xFFFFC107);
}

