import '../../../../core/widgets/status_pill.dart';

/// A captured business card and its review/submission progress. Deliberately
/// a plain mutable data class rather than a strict immutable domain entity —
/// this is shared, easy-to-change shape used directly by the UI layer; see
/// ARCHITECTURE.md's "Held discrepancies" note for the fuller local Card vs.
/// backend Lead model this is a pragmatic stand-in for.
enum LeadStatus { pending, needsReview, created, partial, failed }

class Lead {
  Lead({
    required this.id,
    required this.agencyName,
    required this.country,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.address,
    required this.status,
    required this.capturedAt,
    this.mobilePhone = '',
    this.mobilePhone2 = '',
    this.landlinePhone = '',
    this.landlinePhone2 = '',
    this.faxPhone = '',
    this.agencyWebsite = '',
    this.emailLowConfidence = false,
    this.agencyId,
    this.failureReason,
    this.imagePath,
    this.remoteImageUrl,
    this.backImagePath,
    this.remoteBackImageUrl,
    this.backendLeadId,
    this.lastExtractionError,
    this.siblingLeadIds = const [],
  });

  final String id;
  final String? imagePath; // local file path from camera/gallery, if any
  // Card image URL from the backend — set on leads fetched via GET
  // /api/leads/ (e.g. captured on another device/session) that have no
  // local file on this device. [imagePath] takes priority when both are
  // set — see CardImageView.
  final String? remoteImageUrl;
  // Local file path for a captured back-of-card photo, if the user scanned
  // one — sent to the backend under the same `card_image` field as the
  // front photo (the API accepts 1 or 2 files under that key).
  final String? backImagePath;
  // Backend's `card_image_back` URL — either set at construction (leads
  // fetched via GET) or filled in by [LeadStoreCubit.extract] once
  // extraction has run. [backImagePath] takes priority when both are set.
  String? remoteBackImageUrl;
  String agencyName;
  String country;
  String firstName;
  String lastName;
  String email;
  // Dynamic phone fields — the backend only includes a given key when the
  // card actually has that number (e.g. `mobile_phone_2` is absent unless
  // a second mobile number was found), so all of these default to ''.
  String mobilePhone;
  String mobilePhone2;
  String landlinePhone;
  String landlinePhone2;
  String faxPhone;
  // Backend's `agency_website` field — added 2026-09-09, OCR-scanned from
  // the card alongside the other agency fields.
  String agencyWebsite;
  String address;
  bool emailLowConfidence;
  LeadStatus status;
  String? agencyId;
  String? failureReason;
  // The Lead record id returned by the real POST /api/leads/ call — distinct
  // from [agencyId], which is set later by the agency-creation/submit step.
  String? backendLeadId;
  // Set when a real extractCard() call fails; cleared on the next attempt.
  String? lastExtractionError;
  final DateTime capturedAt;
  // Per the backend's 2026-09-10 change, GET /api/leads/ now groups
  // contacts by agency (e.g. two people scanned from the same company
  // become two contacts under one agency object) instead of returning one
  // flat row per contact. Rather than reshaping this app's whole Lead
  // model around that, [LeadListRemoteDataSource] flattens each group back
  // into one [Lead] per contact (unchanged everywhere else — extraction,
  // edit, submit are all still per-contact) and records the OTHER
  // contacts' ids here, so the Leads list can show "+N more contacts at
  // this agency" and let the user jump to them — each sibling id is just
  // another real entry already in [LeadStoreCubit]'s state. Empty for
  // locally-captured leads and for any agency with only one contact.
  final List<String> siblingLeadIds;

  String get contactName => '$firstName $lastName';

  Lead copyWith({
    String? agencyName,
    String? country,
    String? firstName,
    String? lastName,
    String? email,
    String? mobilePhone,
    String? mobilePhone2,
    String? landlinePhone,
    String? landlinePhone2,
    String? faxPhone,
    String? agencyWebsite,
    String? address,
    bool? emailLowConfidence,
    LeadStatus? status,
    String? agencyId,
    String? failureReason,
  }) {
    return Lead(
      id: id,
      agencyName: agencyName ?? this.agencyName,
      country: country ?? this.country,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      mobilePhone: mobilePhone ?? this.mobilePhone,
      mobilePhone2: mobilePhone2 ?? this.mobilePhone2,
      landlinePhone: landlinePhone ?? this.landlinePhone,
      landlinePhone2: landlinePhone2 ?? this.landlinePhone2,
      faxPhone: faxPhone ?? this.faxPhone,
      agencyWebsite: agencyWebsite ?? this.agencyWebsite,
      address: address ?? this.address,
      emailLowConfidence: emailLowConfidence ?? this.emailLowConfidence,
      status: status ?? this.status,
      agencyId: agencyId ?? this.agencyId,
      failureReason: failureReason ?? this.failureReason,
      capturedAt: capturedAt,
      imagePath: imagePath,
      remoteImageUrl: remoteImageUrl,
      backImagePath: backImagePath,
      remoteBackImageUrl: remoteBackImageUrl,
      backendLeadId: backendLeadId,
      lastExtractionError: lastExtractionError,
      siblingLeadIds: siblingLeadIds,
    );
  }
}

extension LeadStatusDisplay on LeadStatus {
  String get label => switch (this) {
    LeadStatus.pending => 'Pending',
    LeadStatus.needsReview => 'Needs Review',
    LeadStatus.created => 'Created',
    LeadStatus.partial => 'Partial',
    LeadStatus.failed => 'Failed',
  };

  PillTone get tone => switch (this) {
    LeadStatus.pending => PillTone.neutral,
    LeadStatus.needsReview => PillTone.neutral,
    LeadStatus.created => PillTone.ok,
    LeadStatus.partial => PillTone.warn,
    LeadStatus.failed => PillTone.err,
  };
}
