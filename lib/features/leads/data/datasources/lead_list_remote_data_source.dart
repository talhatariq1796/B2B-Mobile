import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/lead.dart';
import '../../domain/repositories/lead_list_repository.dart' show LeadExportFile;

/// Calls GET /api/leads/ via the shared [ApiClient]. Originally (confirmed
/// live 2026-09-01, re-confirmed 2026-09-02/04) a flat JSON array of the
/// same Lead shape seen from POST/PATCH/submit. Per the backend team's
/// 2026-09-10 change, confirmed live, the response is now:
///  - Paginated (standard DRF page-number pagination): `{count, next,
///    previous, results}`. `next`/`previous` are full absolute URLs (or
///    null) — passed straight back into `dio.get` as-is, which resolves an
///    absolute URL over `baseUrl` correctly, and still carries the auth
///    interceptor since it's the same [ApiClient] instance.
///  - Grouped by agency: each item in `results` is no longer one contact —
///    it's `{agency_name, agency_website, address, country, agency_id,
///    contacts: [...]}`, where `contacts` holds one entry per person
///    scanned for that agency (e.g. two people from the same company
///    scanned on different occasions land in the same agency's `contacts`
///    array rather than becoming two separate agencies). Each contact
///    carries `id, card_image, card_image_back, contact_first_name,
///    contact_last_name, email, status, tc_username, api_error,
///    submitted_at, created_at, updated_at` plus the dynamic phone keys
///    (mobile_phone, mobile_phone_2, landline_phone, landline_phone_2,
///    fax_phone — still only present when non-empty, same as before).
///
/// [_toLeadsFromGroup] flattens this back into one [Lead] per contact
/// (agency-level fields copied onto each) so the rest of the app — which
/// still extracts/edits/submits one contact at a time — doesn't need to
/// change; [Lead.siblingLeadIds] preserves which flattened Leads came from
/// the same agency group, for the Leads list to surface.
///
/// [getLeads] auto-follows `next` to fetch every page rather than exposing
/// pagination to callers: existing screens (stat cards, search, filters)
/// all assume they have the complete list in memory already, and
/// splitting that apart into real incremental loading is a separate,
/// larger UI change than just adapting to the new response shape.
class LeadListRemoteDataSource {
  LeadListRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Lead>> getLeads() async {
    try {
      final leads = <Lead>[];
      String? url = ApiConstants.leads;
      while (url != null) {
        final response = await _apiClient.dio.get<dynamic>(url);
        final page = response.data;
        final results = page is Map<String, dynamic> ? page['results'] : null;
        if (results is List) {
          for (final group in results.whereType<Map<String, dynamic>>()) {
            leads.addAll(_toLeadsFromGroup(group));
          }
        }
        url = page is Map<String, dynamic> ? page['next']?.toString() : null;
      }
      return leads;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Calls GET /api/leads/export/ — confirmed live on 2026-09-09:
  /// `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
  /// (a real .xlsx file) with `Content-Disposition: attachment;
  /// filename="leads.xlsx"`. No query params/filters — it's a full export
  /// of everything this workspace can see.
  Future<LeadExportFile> exportToExcel() async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        ApiConstants.leadsExport,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data ?? const []);
      final disposition = response.headers.value('content-disposition');
      final match = RegExp('filename="?([^";]+)"?').firstMatch(disposition ?? '');
      return LeadExportFile(bytes: bytes, filename: match?.group(1) ?? 'leads.xlsx');
    } on DioException catch (e) {
      throw _mapDioException(e, genericMessage: 'Could not export leads right now.');
    }
  }

  /// One agency group -> one [Lead] per entry in its `contacts` array.
  /// Agency-level fields (name/website/address/country/id) come from
  /// [group] and are copied onto every contact; everything else is
  /// per-contact. [Lead.siblingLeadIds] on each is every other contact's
  /// id in this same group, so a group of 1 always gets an empty list.
  Iterable<Lead> _toLeadsFromGroup(Map<String, dynamic> group) {
    final contactsRaw = group['contacts'];
    final contacts = contactsRaw is List
        ? contactsRaw.whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];
    final agencyId = group['agency_id']?.toString();
    final hasAgency = agencyId != null && agencyId.isNotEmpty;
    final agencyName = group['agency_name']?.toString() ?? '';
    final agencyWebsite = group['agency_website']?.toString() ?? '';
    final address = group['address']?.toString() ?? '';
    final country = group['country']?.toString() ?? '';
    final allIds = contacts.map((c) => c['id']?.toString() ?? '').toList();

    return contacts.map((contact) {
      final id = contact['id']?.toString() ?? '';
      final apiError = contact['api_error']?.toString();
      final hasError = apiError != null && apiError.isNotEmpty;
      final status = switch (contact['status']?.toString()) {
        'user_created' => LeadStatus.created,
        'failed' => LeadStatus.failed,
        'scanned' => LeadStatus.needsReview,
        _ => hasAgency
            ? (hasError ? LeadStatus.partial : LeadStatus.created)
            : LeadStatus.needsReview,
      };
      final createdAt =
          DateTime.tryParse(contact['created_at']?.toString() ?? '') ?? DateTime.now();

      return Lead(
        id: id,
        backendLeadId: id,
        agencyName: agencyName,
        agencyWebsite: agencyWebsite,
        firstName: contact['contact_first_name']?.toString() ?? '',
        lastName: contact['contact_last_name']?.toString() ?? '',
        email: contact['email']?.toString() ?? '',
        mobilePhone: contact['mobile_phone']?.toString() ?? '',
        mobilePhone2: contact['mobile_phone_2']?.toString() ?? '',
        landlinePhone: contact['landline_phone']?.toString() ?? '',
        landlinePhone2: contact['landline_phone_2']?.toString() ?? '',
        faxPhone: contact['fax_phone']?.toString() ?? '',
        address: address,
        country: country,
        status: status,
        agencyId: hasAgency ? agencyId : null,
        failureReason: hasError ? apiError : null,
        remoteImageUrl: contact['card_image']?.toString(),
        remoteBackImageUrl: contact['card_image_back']?.toString(),
        capturedAt: createdAt,
        siblingLeadIds: allIds.where((other) => other.isNotEmpty && other != id).toList(),
      );
    });
  }

  Exception _mapDioException(
    DioException e, {
    String genericMessage = 'Could not load leads right now.',
  }) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      return const UnauthorizedException();
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NetworkException("Couldn't reach the server — check your connection.");
    }
    return ServerException(genericMessage, statusCode: status);
  }
}
