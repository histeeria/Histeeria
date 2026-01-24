import 'package:flutter/material.dart';
import 'app_colors.dart';

/// YouTube Music inspired text styles
class AppTextStyles {
  // Display styles (large, bold, for headlines)
  static TextStyle displayLarge({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontSize: 32,
      fontWeight: weight ?? FontWeight.bold,
      color: color ?? AppColors.textPrimary,
      letterSpacing: -0.5,
      height: 1.2,
    );
  }

  static TextStyle displayMedium({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontSize: 28,
      fontWeight: weight ?? FontWeight.bold,
      color: color ?? AppColors.textPrimary,
      letterSpacing: -0.5,
      height: 1.2,
    );
  }

  static TextStyle displaySmall({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontSize: 24,
      fontWeight: weight ?? FontWeight.w600,
      color: color ?? AppColors.textPrimary,
      letterSpacing: -0.3,
      height: 1.3,
    );
  }

  // Headline styles
  static TextStyle headlineLarge({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontSize: 22,
      fontWeight: weight ?? FontWeight.w600,
      color: color ?? AppColors.textPrimary,
      letterSpacing: 0,
      height: 1.3,
    );
  }

  static TextStyle headlineMedium({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontSize: 20,
      fontWeight: weight ?? FontWeight.w600,
      color: color ?? AppColors.textPrimary,
      letterSpacing: 0,
      height: 1.4,
    );
  }

  static TextStyle headlineSmall({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontSize: 18,
      fontWeight: weight ?? FontWeight.w500,
      color: color ?? AppColors.textPrimary,
      letterSpacing: 0,
      height: 1.4,
    );
  }

  // Body styles
  static TextStyle bodyLarge({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontSize: 16,
      fontWeight: weight ?? FontWeight.normal,
      color: color ?? AppColors.textPrimary,
      letterSpacing: 0.15,
      height: 1.5,
    );
  }

  static TextStyle bodyMedium({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontSize: 14,
      fontWeight: weight ?? FontWeight.normal,
      color: color ?? AppColors.textSecondary,
      letterSpacing: 0.25,
      height: 1.5,
    );
  }

  static TextStyle bodySmall({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontSize: 12,
      fontWeight: weight ?? FontWeight.normal,
      color: color ?? AppColors.textTertiary,
      letterSpacing: 0.4,
      height: 1.5,
    );
  }

  // Label styles (for buttons, labels)
  static TextStyle labelLarge({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontSize: 14,
      fontWeight: weight ?? FontWeight.w600,
      color: color ?? AppColors.textPrimary,
      letterSpacing: 0.1,
      height: 1.4,
    );
  }

  static TextStyle labelMedium({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontSize: 12,
      fontWeight: weight ?? FontWeight.w500,
      color: color ?? AppColors.textSecondary,
      letterSpacing: 0.5,
      height: 1.4,
    );
  }

  static TextStyle labelSmall({
    Color? color,
    FontWeight? weight,
  }) {
    return TextStyle(
      fontSize: 11,
      fontWeight: weight ?? FontWeight.w500,
      color: color ?? AppColors.textTertiary,
      letterSpacing: 0.5,
      height: 1.4,
    );
  }
}
