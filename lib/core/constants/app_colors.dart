import 'package:flutter/material.dart';


/// App-wide color palette derived from the design mockups.
/// Calm, medical/health aesthetic — soft blues, greens, and neutral grays.
class AppColors {
  AppColors._();

  // Primary
  static const Color primary = Color(0xFF3B82F6); // Calm sky blue
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color accent = Color(0xFF26C6A0); // Teal green for "Taken"
  static const Color accentLight = Color(0xFFDDFBF4);

  // Backgrounds
  static const Color scaffoldBg = Color(0xFFF5F7FA);
  static const Color cardBg = Colors.white;
  static const Color headerBg = Color(0xFFE8F4FD);

  // Text
  static const Color textPrimary = Color(0xFF2D3748);
  static const Color textSecondary = Color(0xFF8E99A8);
  static const Color textHint = Color(0xFFB0BEC5);

  // Status
  static const Color taken = Color(0xFF26C6A0);
  static const Color skipped = Color(0xFFE0E5EC);
  static const Color skippedText = Color(0xFF6B7B8D);
  static const Color missed = Color(0xFFFF6B6B);
  static const Color warning = Color(0xFFE65100);

  // Misc
  static const Color divider = Color(0xFFEDF0F5);
  static const Color ringTrack = Color(0xFFE8ECF1);
  static const Color iconBg = Color(0xFFE3F2FD);
}
