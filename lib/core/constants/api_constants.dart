/// Backend endpoint config. Values are overridden per-flavor once
/// dev/staging/prod entrypoints are introduced.
class ApiConstants {
  const ApiConstants._();

  /// Live backend. Overridable at build time: `--dart-define=API_BASE_URL=...`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://3.67.44.35',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  // OCR extraction legitimately takes longer than a typical API call —
  // give it its own, longer receive timeout per-request rather than
  // raising the default for every call.
  static const Duration extractionReceiveTimeout = Duration(seconds: 60);

  static const String leads = '/api/leads/';
  static const String leadsStats = '/api/leads/stats/';
  static const String leadsExport = '/api/leads/export/';
  // Bulk "Submit to booking engine" for every eligible lead at once, per
  // the backend team's 2026-09-10 addition — same auth, empty body, no
  // per-lead id in the URL (unlike [leadSubmit]).
  static const String leadsSubmitAll = '/api/leads/submit-all/';
  static String lead(String id) => '/api/leads/$id/';
  static String leadSubmit(String id) => '/api/leads/$id/submit/';

  /// Login now lives on the app's own backend (per the BE team's
  /// 2026-09-08 change), not the earlier direct call to
  /// online.travelcompositor.com/resources/authentication/authenticate.
  /// Body is just `{username, password}` — no `micrositeId`; confirmed live
  /// against the real backend that the response shape is unchanged
  /// (`{token, expirationInSeconds}`), so [AuthRemoteDataSource]'s parsing
  /// didn't need to change, only the endpoint/host and request body.
  static const String authLogin = '/api/auth/login/';
}
