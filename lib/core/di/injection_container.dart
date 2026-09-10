import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/card_editor/data/datasources/lead_edit_remote_data_source.dart';
import '../../features/card_editor/data/repositories/lead_edit_repository_impl.dart';
import '../../features/card_editor/domain/repositories/lead_edit_repository.dart';
import '../../features/card_extraction/data/datasources/lead_extraction_remote_data_source.dart';
import '../../features/card_extraction/data/repositories/lead_extraction_repository_impl.dart';
import '../../features/card_extraction/domain/repositories/lead_extraction_repository.dart';
import '../../features/card_submission/data/datasources/lead_submit_remote_data_source.dart';
import '../../features/card_submission/data/repositories/lead_submit_repository_impl.dart';
import '../../features/card_submission/domain/repositories/lead_submit_repository.dart';
import '../../features/leads/data/datasources/lead_list_remote_data_source.dart';
import '../../features/leads/data/repositories/lead_list_repository_impl.dart';
import '../../features/leads/domain/repositories/lead_list_repository.dart';
import '../network/api_client.dart';
import '../storage/secure_storage_service.dart';

final GetIt sl = GetIt.instance;

/// Registers core singletons. Each feature adds its own `injection_container.dart`
/// (e.g. `features/card_capture/di/card_capture_injection.dart`) and calls its
/// own `initCardCaptureDependencies()` from here once that feature is built.
Future<void> initDependencies() async {
  // Core
  // Fetched once up front (not lazily) so it's available synchronously
  // wherever it's read — e.g. the Settings screen's app-version row.
  final packageInfo = await PackageInfo.fromPlatform();
  sl.registerLazySingleton<PackageInfo>(() => packageInfo);
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  sl.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(sl()),
  );
  sl.registerLazySingleton<ApiClient>(() => ApiClient(sl()));

  // Auth
  sl.registerLazySingleton<AuthRemoteDataSource>(() => AuthRemoteDataSource());
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl(), sl()),
  );

  // Card extraction (POST /api/leads/).
  sl.registerLazySingleton<LeadExtractionRemoteDataSource>(
    () => LeadExtractionRemoteDataSource(sl()),
  );
  sl.registerLazySingleton<LeadExtractionRepository>(
    () => LeadExtractionRepositoryImpl(sl()),
  );

  // Lead editing (PATCH /api/leads/{id}/, "Save corrections").
  sl.registerLazySingleton<LeadEditRemoteDataSource>(
    () => LeadEditRemoteDataSource(sl()),
  );
  sl.registerLazySingleton<LeadEditRepository>(
    () => LeadEditRepositoryImpl(sl()),
  );

  // Lead submission (POST /api/leads/{id}/submit/, "Submit to booking
  // engine" — creates the agency + user via Travel Compositor).
  sl.registerLazySingleton<LeadSubmitRemoteDataSource>(
    () => LeadSubmitRemoteDataSource(sl()),
  );
  sl.registerLazySingleton<LeadSubmitRepository>(
    () => LeadSubmitRepositoryImpl(sl()),
  );

  // Leads list (GET /api/leads/).
  sl.registerLazySingleton<LeadListRemoteDataSource>(
    () => LeadListRemoteDataSource(sl()),
  );
  sl.registerLazySingleton<LeadListRepository>(
    () => LeadListRepositoryImpl(sl()),
  );

  // Features are wired in as they're built, e.g.:
  // initCardCaptureDependencies();
  // initCardHistoryDependencies();
}
