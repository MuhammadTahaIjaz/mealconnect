import 'package:flutter/material.dart';

class AppColors {
  // Primary gradient
  static const Color primaryPink = Color(0xFFFF4B7B);
  static const Color primaryOrange = Color(0xFFFF8C00);

  // Accent
  static const Color accent = Color(0xFFF5A623);

  // Backgrounds
  static const Color background = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF9B9B9B);

  // Utility
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);
  static const Color divider = Color(0xFFEEEEEE);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPink, primaryOrange],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
