import 'package:flutter/material.dart';

/// Low-opacity, tight-radius shadows only — "subtle depth," never a heavy
/// drop shadow. Three levels: resting cards, floating controls (FAB, sticky
/// bars), and modals/sheets.
class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A0F1A1B), blurRadius: 1, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x080F1A1B), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x140F1A1B), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> modal = [
    BoxShadow(color: Color(0x1F0F1A1B), blurRadius: 32, offset: Offset(0, -4)),
  ];
}
