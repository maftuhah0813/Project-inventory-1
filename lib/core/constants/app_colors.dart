import 'package:flutter/material.dart';

/// Palet warna standar untuk Maftuhah Mobile POS
/// Didesain dengan kontras tinggi untuk visibilitas optimal di lingkungan operasional kasir ritel.
class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF0F172A); // Deep Navy Slate
  static const Color primaryLight = Color(0xFF1E293B);
  static const Color primaryDark = Color(0xFF020617);

  // Accent & Action Colors
  static const Color accent = Color(0xFF10B981); // Emerald Green (Action/Pay)
  static const Color accentHover = Color(0xFF059669);
  static const Color secondary = Color(0xFF3B82F6); // Blue Accent

  // EWS (Early Warning System) & Alert Colors
  static const Color ewsCritical = Color(0xFFEF4444); // Merah Darurat (Stok <= 50% ROP)
  static const Color ewsWarning = Color(0xFFF59E0B); // Amber Waspada (Stok <= ROP)
  static const Color ewsSafe = Color(0xFF10B981); // Hijau Aman (Stok > ROP)

  // Surface & Neutral Colors
  static const Color background = Color(0xFFF8FAFC); // Clean Off-White
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Scanner UI Colors
  static const Color scannerOverlay = Color(0x99000000);
  static const Color scannerTarget = Color(0xFF10B981);
}
