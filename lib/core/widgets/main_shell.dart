import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_shadows.dart';
import '../../features/card_capture/capture_flow.dart';

/// Bottom-nav scaffold shared by the main tabs. Order is Leads, Capture,
/// Settings — Capture sits in the center as a raised, larger circular
/// button (the core workflow deserves the most prominent affordance),
/// while Leads and Settings are plain icon+label tabs either side of it.
/// Wired up via go_router's StatefulShellRoute so each tab keeps its own
/// navigation stack and state when switching tabs.
///
/// The Capture button is a real Scaffold [floatingActionButton] (via
/// [_RaisedCenterFabLocation]) rather than being stacked inside
/// [bottomNavigationBar]. It used to be the latter, with the whole raised
/// area — button included — wrapped in one `SizedBox` passed as
/// `bottomNavigationBar`; Scaffold insets the body by that widget's full
/// height, so scrollable content on every tab was cut off `_raise` pixels
/// above the visible bar, right at the top of the button, instead of
/// reaching down to the bar itself. Since the FAB slot isn't counted in
/// that inset, `bottomNavigationBar` below is now just the real bar.
///
/// [resizeToAvoidBottomInset] is deliberately left at its Scaffold default
/// (true), and [_RaisedCenterFabLocation] deliberately positions the
/// button from [ScaffoldPrelayoutGeometry.scaffoldSize] rather than
/// [ScaffoldPrelayoutGeometry.contentBottom] — setting it false here was
/// tried (to stop the button drifting up with the keyboard on the Leads
/// search field) and made things worse: this Scaffold's `body` wraps each
/// tab's own screen, which has its *own* nested Scaffold that already
/// resizes itself around the keyboard correctly. With this one also set to
/// false, its `body` stops consuming the keyboard inset for its
/// descendants (see Scaffold's `removeBottomInset` docs), so the nested
/// screen received the *un-consumed* full keyboard height on top of a body
/// box that was already `_barHeight` shorter than the real screen — double
/// counting it, over-shrinking the nested screen's content by that much,
/// and leaving a `_barHeight`-tall gap of this shell's own background
/// showing above the keyboard where the search results should have been.
/// `scaffoldSize` is documented as never reflecting keyboard/resize
/// changes, so computing the raise from it keeps the button fixed without
/// touching `resizeToAvoidBottomInset` at all.
class MainShell extends StatelessWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _barHeight = 62.0;
  static const _raise = 26.0;

  @override
  Widget build(BuildContext context) {
    // Computed explicitly rather than via SafeArea: SafeArea would shrink
    // the fixed-height bar's content area to fit the home-indicator inset
    // instead of growing the bar, which is what caused the tab labels to
    // overflow. The inset is added as extra bar height instead.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final navBarHeight = _barHeight + bottomInset;

    return Scaffold(
      body: navigationShell,
      floatingActionButtonLocation: _RaisedCenterFabLocation(
        raise: _raise,
        navBarHeight: navBarHeight,
      ),
      floatingActionButton: _CaptureTab(
        selected: navigationShell.currentIndex == 1,
        onTap: () => _openCapture(context),
      ),
      bottomNavigationBar: Container(
        height: navBarHeight,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Row(
            children: [
              Expanded(
                child: _SideTab(
                  icon: Icons.list_alt_outlined,
                  selectedIcon: Icons.list_alt_rounded,
                  label: 'Leads',
                  selected: navigationShell.currentIndex == 0,
                  onTap: () => _goBranch(0),
                ),
              ),
              const SizedBox(
                width: 76,
              ), // clearance for the raised center button
              Expanded(
                child: _SideTab(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings_rounded,
                  label: 'Settings',
                  selected: navigationShell.currentIndex == 2,
                  onTap: () => _goBranch(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goBranch(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  /// Tapping the center tab both switches to the Capture screen (so the
  /// card-placement guide is what's behind it) and immediately opens the
  /// camera/gallery picker — one tap instead of "switch tab, then tap the
  /// shutter." The IndexedStack behind the shell keeps CardCaptureScreen
  /// alive across tab switches, so this can't rely on the screen's own
  /// initState firing again; the picker is launched from here instead.
  void _openCapture(BuildContext context) {
    _goBranch(1);
    unawaited(launchCardCapture(context));
  }
}

/// Centers the FAB horizontally and sits its top edge [raise] pixels above
/// the top of [Scaffold.bottomNavigationBar] — the same raised-above-the-bar
/// look the old Stack-based layout had. Deliberately computed from
/// [ScaffoldPrelayoutGeometry.scaffoldSize] (documented as constant,
/// regardless of the keyboard or `resizeToAvoidBottomInset`) and the bar's
/// own known-fixed [navBarHeight], rather than from `contentBottom` — see
/// [MainShell]'s doc comment for why: `contentBottom` moves with the
/// keyboard, which is exactly what made this button drift upward when a
/// text field on any tab (e.g. the Leads search field) got focus.
class _RaisedCenterFabLocation extends FloatingActionButtonLocation {
  const _RaisedCenterFabLocation({required this.raise, required this.navBarHeight});

  final double raise;
  final double navBarHeight;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final fabX =
        (scaffoldGeometry.scaffoldSize.width -
            scaffoldGeometry.floatingActionButtonSize.width) /
        2;
    final fabY = scaffoldGeometry.scaffoldSize.height - navBarHeight - raise;
    return Offset(fabX, fabY);
  }
}

class _SideTab extends StatelessWidget {
  const _SideTab({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.inkSoft;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? selectedIcon : icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// The raised, larger center tab — no backing fill behind it (transparent),
/// so it reads as a button floating freely above the bar rather than a
/// colored disc that looks like the screen is cut off before the bar.
class _CaptureTab extends StatelessWidget {
  const _CaptureTab({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.accent,
          shape: BoxShape.circle,
          boxShadow: AppShadows.floating,
        ),
        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}
