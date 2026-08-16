import 'package:flutter/material.dart';

/// Centralized semantic color constants for MerkadoGo.
/// NO gradients — every value here is a flat solid color.
class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────
  static const Color primary      = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFFE8F5E9);

  // ── Backgrounds ────────────────────────────────────────
  static const Color canvas       = Color(0xFFF7F7F5);
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color surfaceDim   = Color(0xFFF1F8E9);

  // ── Text ───────────────────────────────────────────────
  static const Color ink          = Color(0xFF1A241A);
  static const Color inkMuted     = Color(0xFF667066);
  static const Color inkSubtle    = Color(0xFF9E9E9E);

  // ── Borders ────────────────────────────────────────────
  static const Color border       = Color(0xFFE2E8E2);
  static const Color borderLight  = Color(0xFFF0F0F0);

  // ── Semantic ───────────────────────────────────────────
  static const Color error        = Color(0xFFE53935);
  static const Color errorLight   = Color(0xFFFFEBEE);
  static const Color errorBorder  = Color(0xFFFFCDD2);
  static const Color warning      = Color(0xFFF57F17);
  static const Color warningLight = Color(0xFFFFFDE7);
  static const Color warningBorder = Color(0xFFFFE082);

  // ── Navigation ─────────────────────────────────────────
  static const Color navSurface   = Color(0xFF1A241A);
  static const Color navActive    = Color(0xFF4CAF50);

  // ── Chat ───────────────────────────────────────────────
  static const Color chatBubbleBot  = Color(0xFFF5F5F5);
  static const Color chatBackground = Color(0xFFFAFAFA);
}
