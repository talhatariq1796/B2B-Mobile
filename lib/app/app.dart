import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/injection_container.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/card_editor/domain/repositories/lead_edit_repository.dart';
import '../features/card_extraction/domain/repositories/lead_extraction_repository.dart';
import '../features/card_submission/domain/repositories/lead_submit_repository.dart';
import '../features/leads/domain/repositories/lead_list_repository.dart';
import '../features/leads/presentation/cubit/lead_store_cubit.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class App extends StatefulWidget {
  const App({required this.restoredSession, this.restoredUsername, super.key});

  // Whether a still-valid session was found in secure storage at startup —
  // see main.dart. Seeds both the initial auth state and the router's
  // starting location.
  final bool restoredSession;

  // The username saved at that session's login, if any — see AuthCubit's
  // doc comment for why it isn't part of the login response itself.
  final String? restoredUsername;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  // Built once, not per-build — go_router's own state (current location,
  // nested-navigator stacks) would otherwise be discarded on any rebuild.
  late final GoRouter _router = buildAppRouter(
    initialLocation: widget.restoredSession ? AppRoutes.capture : AppRoutes.login,
  );

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      // Auth, card extraction, editing, submission, and the leads list are
      // all real (see features/) — no mock data left.
      providers: [
        BlocProvider(
          create: (_) => LeadStoreCubit(
            sl<LeadExtractionRepository>(),
            sl<LeadEditRepository>(),
            sl<LeadSubmitRepository>(),
            sl<LeadListRepository>(),
          ),
        ),
        BlocProvider(
          create: (_) => AuthCubit(
            sl<AuthRepository>(),
            restoredSession: widget.restoredSession,
            restoredUsername: widget.restoredUsername,
          ),
        ),
      ],
      child: MaterialApp.router(
        title: 'B2B OCR Tool',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light, // client mockup is light-only for now
        routerConfig: _router,
      ),
    );
  }
}
