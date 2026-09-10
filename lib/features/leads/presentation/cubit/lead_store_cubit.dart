import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../card_editor/domain/repositories/lead_edit_repository.dart';
import '../../../card_extraction/domain/repositories/lead_extraction_repository.dart';
import '../../../card_submission/domain/repositories/lead_submit_repository.dart';
import '../../domain/entities/lead.dart';
import '../../domain/repositories/lead_list_repository.dart';

/// Single in-memory source of truth for every Leads screen. State is a mix
/// of two kinds of [Lead]: locally-captured cards not yet extracted
/// (`backendLeadId == null` — nothing on the server for them yet), and
/// leads that exist on the backend, either extracted this session or
/// fetched via [refreshFromBackend] (GET /api/leads/, e.g. captured on
/// another device/session). Every method that touches the backend
/// ([extract], [updateFields], [createAgency], [retryUserCreation],
/// [refreshFromBackend]) calls the real API — nothing here is mocked.
class LeadStoreCubit extends Cubit<List<Lead>> {
  LeadStoreCubit(
    this._extractionRepository,
    this._editRepository,
    this._submitRepository,
    this._listRepository,
  ) : super(const []);

  final LeadExtractionRepository _extractionRepository;
  final LeadEditRepository _editRepository;
  final LeadSubmitRepository _submitRepository;
  final LeadListRepository _listRepository;

  Lead byId(String id) => state.firstWhere((l) => l.id == id);

  void _replace(Lead updated) {
    emit([
      for (final l in state)
        if (l.id == updated.id) updated else l,
    ]);
  }

  /// Real call: GET /api/leads/. Local-only leads (captured but not yet
  /// extracted, so nothing on the backend to fetch) are preserved across
  /// the refresh — everything else is replaced with the fetched list.
  /// Returns an error message on failure, or null on success.
  Future<String?> refreshFromBackend() async {
    final result = await _listRepository.getLeads();
    return result.fold((failure) => failure.message, (fetched) {
      final localOnly = state.where((l) => l.backendLeadId == null).toList();
      emit([...localOnly, ...fetched]);
      return null;
    });
  }

  /// Real call: GET /api/leads/export/. Doesn't touch cubit state (an
  /// export doesn't change any Lead), so it's a plain pass-through rather
  /// than something that needs [_replace]/[emit] — the screen is
  /// responsible for writing the returned bytes to a file and sharing it.
  Future<({LeadExportFile? file, String? error})> exportToExcel() async {
    final result = await _listRepository.exportToExcel();
    return result.fold(
      (failure) => (file: null, error: failure.message),
      (file) => (file: file, error: null),
    );
  }

  /// Capture/import -> local-only Lead, status = pending, until [extract]
  /// is called. [imagePath] is the real file from the device camera or
  /// gallery (see CardCaptureScreen).
  Lead addCaptured({String? imagePath, String? backImagePath}) {
    final lead = Lead(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      agencyName: '',
      country: '',
      firstName: '',
      lastName: '',
      email: '',
      address: '',
      status: LeadStatus.pending,
      capturedAt: DateTime.now(),
      imagePath: imagePath,
      backImagePath: backImagePath,
    );
    emit([lead, ...state]);
    return lead;
  }

  /// Attaches a locally-captured back-of-card photo to an already-captured
  /// lead. Front-end only for now — there's no backend field to send this
  /// image to yet, so it's just kept for local review/display until the
  /// backend adds support (see [Lead.backImagePath]).
  void setBackImage(String id, {required String backImagePath}) {
    final lead = byId(id);
    final updated = Lead(
      id: lead.id,
      agencyName: lead.agencyName,
      country: lead.country,
      firstName: lead.firstName,
      lastName: lead.lastName,
      email: lead.email,
      mobilePhone: lead.mobilePhone,
      mobilePhone2: lead.mobilePhone2,
      landlinePhone: lead.landlinePhone,
      landlinePhone2: lead.landlinePhone2,
      faxPhone: lead.faxPhone,
      agencyWebsite: lead.agencyWebsite,
      address: lead.address,
      status: lead.status,
      capturedAt: lead.capturedAt,
      emailLowConfidence: lead.emailLowConfidence,
      agencyId: lead.agencyId,
      failureReason: lead.failureReason,
      imagePath: lead.imagePath,
      remoteImageUrl: lead.remoteImageUrl,
      backImagePath: backImagePath,
      remoteBackImageUrl: lead.remoteBackImageUrl,
      backendLeadId: lead.backendLeadId,
      lastExtractionError: lead.lastExtractionError,
      siblingLeadIds: lead.siblingLeadIds,
    );
    _replace(updated);
  }

  /// Real call: POST /api/leads/ (OCR + Lead creation in one call), via
  /// [LeadExtractionRepository]. On success, the extracted fields + backend
  /// id are filled in and status advances to `needsReview`. On failure,
  /// status reverts to `pending` and [Lead.lastExtractionError] carries a
  /// message for the UI to show.
  Future<Lead> extract(String id) async {
    final lead = byId(id);
    lead.lastExtractionError = null;
    if (lead.imagePath == null) {
      lead.lastExtractionError = 'No image was captured for this card.';
      _replace(lead);
      return lead;
    }

    final result = await _extractionRepository.extractCard(
      imagePath: lead.imagePath!,
      backImagePath: lead.backImagePath,
    );
    return result.fold(
      (failure) {
        lead.lastExtractionError = failure.message;
        _replace(lead);
        return lead;
      },
      (extraction) {
        lead.status = LeadStatus.needsReview;
        lead.backendLeadId = extraction.backendLeadId;
        lead.agencyName = extraction.agencyName;
        lead.firstName = extraction.firstName;
        lead.lastName = extraction.lastName;
        lead.email = extraction.email;
        lead.mobilePhone = extraction.mobilePhone;
        lead.mobilePhone2 = extraction.mobilePhone2;
        lead.landlinePhone = extraction.landlinePhone;
        lead.landlinePhone2 = extraction.landlinePhone2;
        lead.faxPhone = extraction.faxPhone;
        lead.agencyWebsite = extraction.agencyWebsite;
        lead.address = extraction.address;
        lead.country = extraction.country;
        lead.remoteBackImageUrl = extraction.backImageUrl;
        _replace(lead);
        return lead;
      },
    );
  }

  /// Real call: PATCH /api/leads/{id}/ ("Save corrections"), via
  /// [LeadEditRepository]. Returns an error message on failure (state is
  /// NOT updated locally, so the UI keeps showing the user's unsaved
  /// edits for retry) or null on success (state is updated to match).
  ///
  /// Trims every text field before sending: a stray leading/trailing space
  /// (easy to type by accident in e.g. Country or First name) has been
  /// observed to make the backend reject the request outright, or to save
  /// a trimmed value while echoing it back — which [LeadEditRemoteDataSource]
  /// then reads as "didn't actually save" and surfaces as an error, even
  /// though the save itself succeeded. Trimming here, once, covers both the
  /// PATCH body and the local state this replaces on success — so the
  /// later POST /submit/ body (built from that same state, see [_submit])
  /// is untrimmed-space-free too.
  Future<String?> updateFields(String id, Lead edited) async {
    final backendLeadId = edited.backendLeadId;
    if (backendLeadId == null) {
      return "This card hasn't been extracted yet — nothing to save.";
    }
    final trimmed = edited.copyWith(
      agencyName: edited.agencyName.trim(),
      country: edited.country.trim(),
      firstName: edited.firstName.trim(),
      lastName: edited.lastName.trim(),
      email: edited.email.trim(),
      mobilePhone: edited.mobilePhone.trim(),
      mobilePhone2: edited.mobilePhone2.trim(),
      landlinePhone: edited.landlinePhone.trim(),
      landlinePhone2: edited.landlinePhone2.trim(),
      faxPhone: edited.faxPhone.trim(),
      agencyWebsite: edited.agencyWebsite.trim(),
      address: edited.address.trim(),
    );
    final result = await _editRepository.updateLead(
      backendLeadId: backendLeadId,
      fields: LeadEditFields(
        agencyName: trimmed.agencyName,
        firstName: trimmed.firstName,
        lastName: trimmed.lastName,
        email: trimmed.email,
        mobilePhone: trimmed.mobilePhone,
        mobilePhone2: trimmed.mobilePhone2,
        landlinePhone: trimmed.landlinePhone,
        landlinePhone2: trimmed.landlinePhone2,
        faxPhone: trimmed.faxPhone,
        agencyWebsite: trimmed.agencyWebsite,
        address: trimmed.address,
        country: trimmed.country,
      ),
    );
    return result.fold((failure) => failure.message, (_) {
      _replace(trimmed);
      return null;
    });
  }

  /// Real call: POST /api/leads/{id}/submit/ ("Submit to booking engine").
  Future<Lead> createAgency(String id) => _submit(id);

  /// Partial-failure retry uses the same call — submit is expected to be
  /// safe to call again on an already-partially-submitted lead (retries
  /// only the failed half; see [LeadSubmitRepository]'s doc comment).
  Future<Lead> retryUserCreation(String id) => _submit(id);

  Future<Lead> _submit(String id) async {
    final lead = byId(id);
    final backendLeadId = lead.backendLeadId;
    if (backendLeadId == null) {
      lead.status = LeadStatus.failed;
      lead.failureReason = "This card hasn't been extracted yet.";
      _replace(lead);
      return lead;
    }

    final result = await _submitRepository.submit(
      backendLeadId: backendLeadId,
      fields: LeadSubmitFields(
        agencyName: lead.agencyName,
        firstName: lead.firstName,
        lastName: lead.lastName,
        email: lead.email,
        mobilePhone: lead.mobilePhone,
        mobilePhone2: lead.mobilePhone2,
        landlinePhone: lead.landlinePhone,
        landlinePhone2: lead.landlinePhone2,
        faxPhone: lead.faxPhone,
        agencyWebsite: lead.agencyWebsite,
        address: lead.address,
        country: lead.country,
      ),
    );
    return result.fold(
      (failure) {
        lead.status = LeadStatus.failed;
        lead.failureReason = failure.message;
        _replace(lead);
        return lead;
      },
      (submission) {
        switch (submission.outcome) {
          case LeadSubmitOutcome.created:
            lead.status = LeadStatus.created;
            lead.agencyId = submission.agencyId;
            lead.failureReason = null;
          case LeadSubmitOutcome.partial:
            lead.status = LeadStatus.partial;
            lead.agencyId = submission.agencyId;
            lead.failureReason = submission.failureReason;
          case LeadSubmitOutcome.failed:
            lead.status = LeadStatus.failed;
            lead.failureReason = submission.failureReason;
        }
        _replace(lead);
        return lead;
      },
    );
  }

  /// Real call: POST /api/leads/submit-all/ ("Submit all"). Bulk-submits
  /// every eligible lead server-side in one call — there's no per-lead
  /// result to apply locally (see [LeadSubmitRepository.submitAll]'s doc
  /// comment), so on success this just re-fetches the list via
  /// [refreshFromBackend] to pick up whatever actually changed. Returns an
  /// error message on failure, or null on success.
  Future<String?> submitAllPending() async {
    final result = await _submitRepository.submitAll();
    final error = result.fold((failure) => failure.message, (_) => null);
    if (error != null) return error;
    return refreshFromBackend();
  }
}
