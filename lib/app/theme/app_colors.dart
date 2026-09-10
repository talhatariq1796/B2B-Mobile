import 'package:flutter/material.dart';

/// Palette lifted directly from the client-approved mockup's CSS variables.
class AppColors {
  const AppColors._();

  static const bg = Color(0xFFEEF2F0);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF152225);
  static const inkSoft = Color(0xFF5B6B6C);

  static const primary = Color(0xFF0F3D3E);
  static const primaryDim = Color(0xFFDCEAE9);
  static const accent = Color(0xFFC68A34);

  static const success = Color(0xFF2F7A5A);
  static const successBg = Color(0xFFE4F1EA);

  static const warning = Color(0xFFB9812F);
  static const warningBg = Color(0xFFFBF0DD);

  static const danger = Color(0xFFC1483A);
  static const dangerBg = Color(0xFFFBE7E3);

  static const border = Color(0xFFDFE5E2);
  static const borderStrong = Color(0xFFC7D1CD);
  static const surfaceMuted = Color(0xFFF6F8F7);
  static const ink3 = Color(
    0xFF8A9695,
  ); // faint tertiary text (timestamps, hints)
  static const overlay = Color(0x66152225); // scrims behind sheets/modals
  static const accentDim = Color(0xFFF3E6D0);
}
