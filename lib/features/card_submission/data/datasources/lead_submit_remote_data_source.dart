import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/lead_submit_repository.dart';

/// Calls POST /api/leads/{id}/submit/ via the shared [ApiClient]. The body
/// was originally empty (confirmed from the Postman collection on
/// 2026-09-01) — the endpoint just used whatever the preceding PATCH
/// /api/leads/{id}/ call had already persisted. Per the 2026-09-06 decision
/// to have this call carry the reviewed page's data itself, the same
/// fields PATCH sends (see LeadEditRemoteDataSource) are now included here
/// too; unconfirmed whether the backend's submit serializer actually reads
/// them yet — if it turns out to ignore an unexpected body, this is a
/// no-op rather than a regression, since the PATCH call still runs first
/// and persists the same data.
///
/// Response body shape confirmed via a live test call on 2026-09-01: a
/// business-level rejection (Travel Compositor rejected the agency
/// payload) came back as HTTP 502, but the body was still the full updated
/// Lead JSON with a populated `api_error` — so the body is parsed the same
/// way regardless of status code, rather than treating every non-2xx as
/// opaque.
class LeadSubmitRemoteDataSource {
  LeadSubmitRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<LeadSubmitResult> submit({
    required String backendLeadId,
    required LeadSubmitFields fields,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        ApiConstants.leadSubmit(backendLeadId),
        data: {
          'agency_name': fields.agencyName,
          'contact_first_name': fields.firstName,
          'contact_last_name': fields.lastName,
          'email': fields.email,
          'mobile_phone': fields.mobilePhone,
          'mobile_phone_2': fields.mobilePhone2,
          'landline_phone': fields.landlinePhone,
          'landline_phone_2': fields.landlinePhone2,
          'fax_phone': fields.faxPhone,
          'agency_website': fields.agencyWebsite,
          'address': fields.address,
          'country': fields.country,
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      return _parseResult(response.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data.containsKey('agency_id')) {
        return _parseResult(data);
      }
      throw _mapDioException(e);
    }
  }

  /// Calls POST /api/leads/submit-all/ — per the backend team's 2026-09-10
  /// addition. No id, no body — just the auth header, same as every other
  /// call through [_apiClient]. Response shape isn't confirmed (no example
  /// given), so this only checks the status code succeeded; per-lead
  /// outcomes have to come from re-fetching GET /api/leads/ afterward.
  Future<void> submitAll() async {
    try {
      await _apiClient.dio.post<dynamic>(ApiConstants.leadsSubmitAll);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  LeadSubmitResult _parseResult(dynamic body) {
    final map = body is Map<String, dynamic> ? body : <String, dynamic>{};
    final agencyId = map['agency_id']?.toString();
    final apiError = map['api_error']?.toString();
    final hasAgency = agencyId != null && agencyId.isNotEmpty;
    final hasError = apiError != null && apiError.isNotEmpty;

    if (hasAgency && !hasError) {
      return LeadSubmitResult(outcome: LeadSubmitOutcome.created, agencyId: agencyId);
    }
    if (hasAgency && hasError) {
      return LeadSubmitResult(
        outcome: LeadSubmitOutcome.partial,
        agencyId: agencyId,
        failureReason: apiError,
      );
    }
    return LeadSubmitResult(
      outcome: LeadSubmitOutcome.failed,
      failureReason: hasError ? apiError : 'The booking engine rejected this submission.',
    );
  }

  Exception _mapDioException(DioException e) {
    final status = e.response?.statusCode;

    if (e.response != null) {
      if (status == 401 || status == 403) {
        return const UnauthorizedException();
      }
      return ServerException(
        'The server rejected this submission (${status ?? 'unknown error'}).',
        statusCode: status,
      );
    }

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NetworkException("Couldn't reach the server — check your connection.");
    }

    // Timed out mid-flight — the agency/user may already have been
    // created. Don't let a caller blindly auto-retry on this.
    if (e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const AmbiguousOutcomeException(
        "Couldn't confirm whether the agency was created — check the leads list before retrying.",
      );
    }

    return ServerException('Could not submit this lead right now.', statusCode: status);
  }
}
