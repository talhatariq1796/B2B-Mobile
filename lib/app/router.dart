import 'package:go_router/go_router.dart';

import '../core/widgets/main_shell.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/card_capture/presentation/screens/capture_preview_screen.dart';
import '../features/card_capture/presentation/screens/card_capture_screen.dart';
import '../features/card_capture/presentation/screens/live_camera_screen.dart';
import '../features/card_editor/presentation/screens/card_editor_screen.dart';
import '../features/card_editor/presentation/screens/lead_detail_screen.dart';
import '../features/card_list/presentation/screens/card_list_screen.dart';
import '../features/card_submission/presentation/screens/outcome_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';

abstract class AppRoutes {
  const AppRoutes._();

  static const login = '/login';
  static const capture = '/capture';
  static const leads = '/leads';
  static const settings = '/settings';
}

/// Capture stays reachable without login (per ARCHITECTURE.md's
/// zero-backend-dependency capture requirement) and the guest banner
/// communicates the logged-out state — so there's no redirect guarding
/// routes here. [initialLocation] is decided once at startup in main.dart,
/// based on whether a still-valid session was restored from secure
/// storage, so an already-signed-in user doesn't see the login screen on
/// every app launch.
GoRouter buildAppRouter({required String initialLocation}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/capture/live',
      builder: (context, state) => LiveCameraScreen(
        attachToLeadId: state.uri.queryParameters['attachTo'],
      ),
    ),
    GoRoute(
      path: '/leads/:id/preview',
      builder: (context, state) =>
          CapturePreviewScreen(leadId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/leads/:id/review',
      builder: (context, state) =>
          CardEditorScreen(leadId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/leads/:id',
      builder: (context, state) =>
          LeadDetailScreen(leadId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/leads/:id/outcome',
      builder: (context, state) =>
          OutcomeScreen(leadId: state.pathParameters['id']!),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      // Order matches the bottom nav: Leads, Capture (center, raised), Settings.
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.leads,
              builder: (context, state) => const CardListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.capture,
              builder: (context, state) => const CardCaptureScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
