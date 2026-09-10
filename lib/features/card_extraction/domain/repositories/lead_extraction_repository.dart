import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';

/// Result of a successful POST /api/leads/ call. Field names confirmed via
/// a live test call against the real dev backend on 2026-09-01 (response:
/// id, card_image, agency_name, contact_first_name, contact_last_name,
/// email, phone, secondary_phone, address, country, status, agency_id,
/// tc_username, api_error, submitted_at, created_at, updated_at, duplicate).
/// Confirmed again live on 2026-09-02 after the backend added two-sided
/// scanning: the same `card_image` multipart key now accepts 1 or 2 files
/// (front, optionally back — no new endpoint/field name), and the response
/// gained `card_image_back` (null when no back image was sent) and a
/// free-text `additional_phones` field. Per the backend team's 2026-09-04
/// update, the fixed phone/secondary_phone/additional_phones fields were
/// replaced with dynamic, type-specific keys — mobile_phone, mobile_phone_2
/// (only present if a second mobile number was found), landline_phone,
/// landline_phone_2, and fax_phone — each present only when that number
/// exists on the card. `status`/`agency_id`/`tc_username`/`api_error`/
/// `submitted_at` describe the backend's own Lead lifecycle (a different
/// concept from this app's local review-workflow `LeadStatus`) and aren't
/// consumed yet — only the fields the review screen needs are surfaced
/// here. Per the backend team's 2026-09-09 update, the response also
/// carries an OCR-scanned `agency_website` field, stored with the lead.
class LeadExtractionResult {
  const LeadExtractionResult({
    required this.backendLeadId,
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
    required this.isDuplicate,
    this.backImageUrl,
  });

  final String backendLeadId;
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
  // Set when a back-of-card image was sent along with this extraction.
  final String? backImageUrl;
  // The backend's own duplicate-card detection — not yet surfaced in the
  // UI; carried through so a future pass can warn the reviewer.
  final bool isDuplicate;
}

/// Domain-facing contract for turning a captured card image into a backend
/// Lead via OCR. Implemented against the real API (see
/// [lib/features/card_extraction/data]) — no mock implementation exists,
/// this always makes a real network call.
abstract class LeadExtractionRepository {
  Future<Either<Failure, LeadExtractionResult>> extractCard({
    required String imagePath,
    String? backImagePath,
  });
}
