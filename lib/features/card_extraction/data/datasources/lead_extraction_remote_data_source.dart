import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/lead_extraction_repository.dart';

/// Calls the app's own backend (POST /api/leads/) via the shared
/// [ApiClient], so the Bearer-token interceptor applies automatically.
/// Request field name `card_image` and the response body shape are both
/// confirmed — see [LeadExtractionResult]. Confirmed live on 2026-09-02:
/// the same `card_image` key now accepts 1 or 2 files (front, optionally
/// back) — no new field/endpoint — and the response echoes the back image
/// back as `card_image_back`. Per the backend team's 2026-09-04 update,
/// phone numbers now come back as dynamic per-type keys rather than a
/// fixed phone/secondary_phone/additional_phones set — see
/// [LeadExtractionResult]'s doc comment.
class LeadExtractionRemoteDataSource {
  LeadExtractionRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<LeadExtractionResult> extractCard({
    required String imagePath,
    String? backImagePath,
  }) async {
    try {
      final files = [await MultipartFile.fromFile(imagePath)];
      if (backImagePath != null) {
        files.add(await MultipartFile.fromFile(backImagePath));
      }
      final formData = FormData.fromMap({'card_image': files});
      final response = await _apiClient.dio.post<dynamic>(
        ApiConstants.leads,
        data: formData,
        options: Options(receiveTimeout: ApiConstants.extractionReceiveTimeout),
      );
      final body = response.data;
      final map = body is Map<String, dynamic> ? body : <String, dynamic>{};
      final id = map['id']?.toString();
      if (id == null) {
        throw const ServerException('Card was sent, but the server response was unexpected.');
      }
      return LeadExtractionResult(
        backendLeadId: id,
        agencyName: map['agency_name']?.toString() ?? '',
        firstName: map['contact_first_name']?.toString() ?? '',
        lastName: map['contact_last_name']?.toString() ?? '',
        email: map['email']?.toString() ?? '',
        mobilePhone: map['mobile_phone']?.toString() ?? '',
        mobilePhone2: map['mobile_phone_2']?.toString() ?? '',
        landlinePhone: map['landline_phone']?.toString() ?? '',
        landlinePhone2: map['landline_phone_2']?.toString() ?? '',
        faxPhone: map['fax_phone']?.toString() ?? '',
        agencyWebsite: map['agency_website']?.toString() ?? '',
        address: map['address']?.toString() ?? '',
        country: map['country']?.toString() ?? '',
        backImageUrl: map['card_image_back']?.toString(),
        isDuplicate: map['duplicate'] == true,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Exception _mapDioException(DioException e) {
    final status = e.response?.statusCode;

    // A response came back — the server confirmed what happened (success or
    // rejection), even if it's an error status.
    if (e.response != null) {
      if (status == 401 || status == 403) {
        return const UnauthorizedException();
      }
      return ServerException(
        'The server rejected this card (${status ?? 'unknown error'}).',
        statusCode: status,
      );
    }

    // Failed before the request left the device — nothing was sent.
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NetworkException("Couldn't reach the server — check your connection.");
    }

    // Timed out mid-flight (sending the image or awaiting a response) —
    // the server may have received and even processed it; we can't tell.
    if (e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const AmbiguousOutcomeException();
    }

    return ServerException('Could not extract this card right now.', statusCode: status);
  }
}
