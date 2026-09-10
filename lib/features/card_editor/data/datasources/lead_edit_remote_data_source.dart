import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/lead_edit_repository.dart';

/// Calls PATCH /api/leads/{id}/ via the shared [ApiClient]. Field names
/// and response shape confirmed via a live test call against the real dev
/// backend on 2026-09-01: body accepts any subset of agency_name,
/// contact_first_name, contact_last_name, email, address, country plus the
/// phone fields; 200 response echoes back the full updated Lead (same shape
/// as POST /api/leads/). That echo is now checked against what was sent
/// (see [_verifyPersisted]) — a 200 here has been observed to NOT mean the
/// edit was actually saved (the server can accept the request but silently
/// keep the old field values), which previously showed the user a false
/// "Changes saved". Per the backend team's 2026-09-04 update, the phone
/// fields sent/echoed are the dynamic mobile_phone/mobile_phone_2/
/// landline_phone/landline_phone_2/fax_phone keys, not the old fixed
/// phone/secondary_phone/additional_phones set.
class LeadEditRemoteDataSource {
  LeadEditRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<void> updateLead({
    required String backendLeadId,
    required LeadEditFields fields,
  }) async {
    try {
      final body = {
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
      };
      final response = await _apiClient.dio.patch<dynamic>(
        ApiConstants.lead(backendLeadId),
        data: body,
        options: Options(contentType: Headers.jsonContentType),
      );
      _verifyPersisted(sent: body, echoed: response.data);
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// The backend echoes back the full Lead it now has on record. If any
  /// field we just sent doesn't match what comes back, the server accepted
  /// the request without actually persisting it — treat that as a failure
  /// rather than reporting success with stale data still in the database.
  void _verifyPersisted({
    required Map<String, dynamic> sent,
    required dynamic echoed,
  }) {
    if (echoed is! Map<String, dynamic>) return;
    final mismatched = <String>[];
    for (final entry in sent.entries) {
      if (!echoed.containsKey(entry.key)) continue;
      if (echoed[entry.key]?.toString() != entry.value?.toString()) {
        mismatched.add(entry.key);
      }
    }
    if (mismatched.isNotEmpty) {
      throw ServerException(
        "The server didn't save these changes: ${mismatched.join(', ')}. Please try again.",
      );
    }
  }

  Exception _mapDioException(DioException e) {
    final status = e.response?.statusCode;

    if (e.response != null) {
      if (status == 401 || status == 403) {
        return const UnauthorizedException();
      }
      if (status == 404) {
        return const ServerException('This card no longer exists on the server.', statusCode: 404);
      }
      return ServerException(
        'The server rejected these changes (${status ?? 'unknown error'}).',
        statusCode: status,
      );
    }

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NetworkException("Couldn't reach the server — check your connection.");
    }

    if (e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const AmbiguousOutcomeException();
    }

    return ServerException('Could not save these changes right now.', statusCode: status);
  }
}
