import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type scale for the app. Fraunces is reserved for hero/display moments
/// (brand, screen-level titles, outcome headlines) — Inter for everything
/// functional (body, labels, table content). Mixing them everywhere would
/// look busy; the rule is: Fraunces when the text IS the content, Inter
/// when the text is UI chrome around the content.
class AppTextStyles {
  const AppTextStyles._();

  // Display — Fraunces, hero moments only (brand mark, outcome headline).
  static TextStyle displayLg({Color color = AppColors.ink}) =>
      GoogleFonts.fraunces(
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle displayMd({Color color = AppColors.ink}) =>
      GoogleFonts.fraunces(
        fontSize: 23,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle brand({double size = 18, Color color = AppColors.primary}) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // Titles — Inter semibold, section/card/screen headers.
  static TextStyle titleLg({Color color = AppColors.ink}) => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: color,
    letterSpacing: -.2,
  );

  static TextStyle titleMd({Color color = AppColors.ink}) => GoogleFonts.inter(
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    color: color,
    letterSpacing: -.1,
  );

  static TextStyle titleSm({Color color = AppColors.ink}) => GoogleFonts.inter(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    color: color,
  );

  // Body — Inter regular.
  static TextStyle body({Color color = AppColors.ink}) =>
      GoogleFonts.inter(fontSize: 14, height: 1.45, color: color);

  static TextStyle bodySm({Color color = AppColors.inkSoft}) =>
      GoogleFonts.inter(fontSize: 12.5, height: 1.45, color: color);

  // Numeric emphasis (stat values).
  static TextStyle statValue({Color color = AppColors.ink}) =>
      GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -.4,
      );

  static TextStyle eyebrow = GoogleFonts.inter(
    fontSize: 11.5,
    letterSpacing: 1.0,
    fontWeight: FontWeight.w600,
    color: AppColors.inkSoft,
  );

  static TextStyle label({Color color = AppColors.inkSoft}) =>
      GoogleFonts.inter(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: .4,
      );

  static TextStyle caption({Color color = AppColors.ink3}) => GoogleFonts.inter(
    fontSize: 11,
    color: color,
    fontWeight: FontWeight.w500,
  );
}
