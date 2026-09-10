import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';

enum LeadSubmitOutcome { created, partial, failed }

/// Result of POST /api/leads/{id}/submit/. Confirmed via a live test call
/// on 2026-09-01 (a rejected submission came back as HTTP 502 with the
/// full updated Lead body, `api_error` populated, `agency_id` empty).
/// [LeadSubmitOutcome] is derived from `agency_id`/`api_error`: non-empty
/// `agency_id` + empty `api_error` -> created; non-empty `agency_id` +
/// non-empty `api_error` -> partial (agency ok, user invite failed); empty
/// `agency_id` -> failed. The `created`/`partial` cases are still
/// inferred (only the `failed` shape has been observed live) — see
/// LeadSubmitRemoteDataSource for the mapping.
class LeadSubmitResult {
  const LeadSubmitResult({required this.outcome, this.agencyId, this.failureReason});

  final LeadSubmitOutcome outcome;
  final String? agencyId;
  final String? failureReason;
}

/// The same reviewable fields as [LeadEditFields] (card_editor), sent as
/// the submit body per the 2026-09-06 decision to have this call carry the
/// page's current data itself rather than relying solely on whatever the
/// preceding PATCH /api/leads/{id}/ already persisted.
class LeadSubmitFields {
  const LeadSubmitFields({
    required this.agencyName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.mobilePhone,
    required this.mobilePhone2,
    required this.landlinePhone,
    required this.landlinePhone2,
    required this.faxPhone,
    required this.agencyWebsite,
    required this.address,
    required this.country,
  });

  final String agencyName;
  final String firstName;
  final String lastName;
  final String email;
  final String mobilePhone;
  final String mobilePhone2;
  final String landlinePhone;
  final String landlinePhone2;
  final String faxPhone;
  final String agencyWebsite;
  final String address;
  final String country;
}

/// Domain-facing contract for POST /api/leads/{id}/submit/ ("Submit to
/// booking engine") — creates the agency + user via Travel Compositor.
/// Also used for the partial-failure "Retry invite" action: calling this
/// again on an already-partially-submitted lead is expected to be safe
/// (retries only the failed half, per the existing outcome-screen copy).
abstract class LeadSubmitRepository {
  Future<Either<Failure, LeadSubmitResult>> submit({
    required String backendLeadId,
    required LeadSubmitFields fields,
  });

  /// POST /api/leads/submit-all/ — per the backend team's 2026-09-10
  /// addition, bulk-submits every eligible lead server-side in one call
  /// (no id, no body). Unlike [submit], there's no per-lead result to
  /// surface here — success just means the call went through; the actual
  /// per-lead outcomes only show up once the caller re-fetches the list.
  Future<Either<Failure, Unit>> submitAll();
}
