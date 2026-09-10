# Architecture

B2B business-card collection app. Flutter, iOS-first (Android also scaffolded).

**Primary use case**: events/exhibitions where a user rapidly captures 20–50+
business cards. Capture must stay fast and never depend on a backend call.
OCR extraction, review/editing, and final submission are separate operations
the user can do later, on their own schedule.

**Revision note (this version)**: the backend team has now confirmed the
full API contract — three distinct endpoints (create+OCR, edit, submit),
each with its own semantics, and critically: **`POST /api/leads/` creates a
persistent backend record, not just an OCR result.** This changes the domain
model materially: the app now has two related-but-distinct entities (local
`Card`, backend `Lead`), a two-axis status model, and an explicit safety
story for network calls that create backend state. See **[Architecture
changes](#1-architecture-changes)** at the bottom for a direct diff from the
previous version.

**Corrections pass note**: a follow-up review against the confirmed backend
contract found three inconsistencies, now fixed throughout: (1) ambiguous
timeouts on `POST /api/leads/`/Submit were incorrectly being recorded as
confirmed failures (`extractionFailed`/`failed`) — they now revert the
relevant status to its pre-attempt value instead, since the outcome is
genuinely unknown; (2) the `submission_*` schema invariant was imprecise
about which fields are null for a `failed` outcome; (3) the single
`clientRequestId` idempotency seam is now split into
`clientCreateRequestId`/`clientSubmitRequestId`, since Create and Submit are
separate operations that may need independent idempotency keys. No
structural change — same Card/Lead separation, same two-axis status model,
same five presentation units.

**Status: architecture only.** No screens or business logic have been built
against this revision yet.

---

## Stack

| Concern              | Choice                          |
|-----------------------|----------------------------------|
| Framework              | Flutter (iOS-first, Android supported) |
| Architecture            | Clean Architecture, feature-first, with `Card` as the local aggregate root |
| State management        | `flutter_bloc` — five focused Cubits/Blocs, no monolith |
| Local database           | `drift` (SQLite) — reaffirmed, see review below |
| Dependency injection    | `get_it` |
| Networking              | `dio` |
| Routing                 | `go_router` |
| Secure storage           | `flutter_secure_storage` |
| Camera                  | `camera` package |
| Gallery import/save      | `image_picker` (pick) + `gal` (save to Photos) |
| Image preprocessing      | `image` package, run via `compute()`/isolate |
| Client-generated request IDs | `uuid` — one id per backend-mutating operation (`clientCreateRequestId`, `clientSubmitRequestId`), for the idempotency-key seam (see Retry & Safety) |
| Immutable models/state    | `freezed` + `json_serializable` |
| Functional error handling | `dartz` (`Either<Failure, T>`) |
| Testing                 | `flutter_test`, `bloc_test`, `mocktail` |

---

## Local Card vs. backend Lead

This is the central conceptual correction in this revision. They are two
different things, tracked separately, linked by an id:

```
Local Card                              Backend Lead
───────────                              ────────────
Created immediately on capture/import.    Does NOT exist yet.
Survives: app kill, navigation,           backendLeadId = null
offline, crashes. Zero backend
dependency.
        │
        │  user chooses "Extract"
        ▼
                                    POST /api/leads/  ──►  Lead created
                                                            server-side
        ◄────────────────────────────────────────────────
Local Card
  backendLeadId = "abc123"
  ocrResult = {...}
        │
        │  user edits, taps Save
        ▼
                                    Edit API  ──►  Lead updated
        ◄────────────────────────────────────────
        │
        │  user taps Submit
        ▼
                                    Submit API  ──►  Agency/User outcome
        ◄────────────────────────────────────────
Local Card
  submissionOutcome = {...}
```

**A Lead does not exist until `POST /api/leads/` succeeds.** Before that,
`Card.backendLeadId` is `null` and nothing about the card has any backend
representation. This is why local capture has zero backend dependency: it
never touches anything that could fail to exist yet.

At any point during an event, the app may hold e.g. 50 local Cards and only
10 backend Leads — that's the expected, normal state, not an edge case.

---

## Local database: Drift (reaffirmed)

Still the right choice; nothing about the confirmed backend contract changes
the reasoning from the previous revision (migration story and maintenance
risk mattered more than raw write speed at this data volume — see prior
version's comparison table). The schema below grows to represent the two
new axes (backend Lead linkage, sync status, submission outcome), which
Drift's relational model handles the same way it already handled OCR
results and custom fields — no new database concept is needed.

**Schema**:

```
cards
  id                      INTEGER PK AUTOINCREMENT   -- local id, source of truth
  client_create_request_id   TEXT                        -- stable UUID, generated at capture time.
                                                        -- Reserved as an idempotency key for
                                                        -- POST /api/leads/ once backend confirms support.
  client_submit_request_id    TEXT NULL                    -- stable UUID, generated lazily on the first
                                                        -- Submit attempt (not at capture time — most
                                                        -- captured cards never reach Submit). Reserved
                                                        -- as an idempotency key for the Submit API.
  local_image_path          TEXT                        -- app-sandbox copy, source of truth
  thumbnail_path             TEXT NULL
  gallery_asset_id            TEXT NULL
  source                    TEXT                        -- 'camera' | 'gallery'

  processing_status           TEXT                        -- captured | extracting | extracted | extractionFailed
  sync_status                TEXT                        -- notCreated | created | editPending | updated |
                                                        -- submitting | completed | partialFailure | failed
  backend_lead_id             TEXT NULL                    -- set once POST /api/leads/ succeeds; null until then

  ocr_result_json              TEXT NULL                    -- immutable raw OCR snapshot, as returned by /api/leads/
  edited_person_name           TEXT NULL                    -- user-edited draft/current data — searchable columns
  edited_company_name          TEXT NULL
  edited_designation           TEXT NULL
  edited_phone                 TEXT NULL
  edited_email                 TEXT NULL
  edited_website                TEXT NULL
  edited_address                TEXT NULL
  notes                      TEXT NOT NULL DEFAULT ''

  last_error_type               TEXT NULL                    -- e.g. 'network' | 'server' | 'timeout' |
                                                        -- 'ambiguousOutcome' | 'validation' | ...
  last_error_message             TEXT NULL

  submission_agency_id           TEXT NULL                    -- non-null iff sync_status ∈ {completed, partialFailure}
                                                        -- (agency creation succeeded in both); null for 'failed'
  submission_user_created         INTEGER NULL                  -- 1 for completed, 0 for partialFailure/failed,
                                                        -- NULL if no confirmed outcome yet
  submission_failure_reason        TEXT NULL                    -- non-null for partialFailure/failed only

  created_at                  DATETIME
  updated_at                  DATETIME

card_custom_fields             -- unchanged from previous revision
  id          INTEGER PK AUTOINCREMENT
  card_id      INTEGER FK -> cards.id ON DELETE CASCADE
  label       TEXT
  value       TEXT
  sort_order   INTEGER
```

Notes on choices:

- `ocr_result_json` stays a JSON blob (immutable snapshot, never queried
  directly) — unchanged reasoning from before.
- `edited_*` fields (renamed from the previous revision's `final_*`) are
  real columns because they're searched/filtered/sorted on the list screen.
- `submission_*` columns are a flat, denormalized representation of
  `SubmissionOutcome` rather than a separate table — there is at most one
  outcome per card and it's never queried independently of its card, so a
  child table would add a join for no benefit.
- **Invariant** (enforced by the repository, not the schema): a confirmed
  `submission_*` outcome exists — populated per-column as below — if and
  only if `sync_status ∈ {completed, partialFailure, failed}`. It is **not**
  a blanket "all columns non-null":
  - `completed`: `agency_id` set, `user_created = 1`, `failure_reason` null
  - `partialFailure`: `agency_id` set (agency succeeded), `user_created = 0`,
    `failure_reason` set (why user creation failed)
  - `failed`: `agency_id` **null** (agency creation itself failed, so no id
    was ever issued), `user_created = 0`, `failure_reason` set (why agency
    creation failed)
  An **ambiguous** Submit outcome populates none of the `submission_*`
  columns and does not set `sync_status` to any of the three values above —
  see [Retry & duplicate-Lead safety](#retry--duplicate-lead-safety). This
  is spelled out precisely because a nullable-column design can otherwise
  silently conflate "no outcome yet" with "an outcome exists but the agency
  id is genuinely absent."

---

## Folder structure

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/app_theme.dart
│
├── core/
│   ├── di/injection_container.dart
│   ├── network/api_client.dart
│   ├── error/{failures.dart,exceptions.dart}      # extended, see Error Handling
│   ├── storage/secure_storage_service.dart
│   ├── usecase/usecase.dart
│   ├── constants/api_constants.dart
│   ├── logging/app_logger.dart
│   ├── database/app_database.dart                 # Drift instance
│   └── widgets/main_shell.dart
│
└── features/
    ├── card/                       # local aggregate — UNCHANGED role from previous revision
    │   ├── domain/
    │   │   ├── entities/           # Card, CardData, CardImage, CustomField,
    │   │   │                       # CardProcessingStatus, BackendSyncStatus,
    │   │   │                       # SubmissionOutcome, CardSource
    │   │   ├── repositories/       # CardRepository (local persistence only)
    │   │   └── usecases/           # GetCard, WatchCards, UpdateCardLocal, DeleteCard
    │   └── data/
    │       ├── datasources/        # CardLocalDataSource (Drift)
    │       ├── models/
    │       └── repositories/       # CardRepositoryImpl
    │
    ├── lead/                       # NEW — everything that talks to the backend Lead API
    │   ├── domain/
    │   │   ├── repositories/       # LeadRepository (create / update / submit — ONE interface,
    │   │   │                       # not three; see reasoning below)
    │   │   └── entities/           # LeadExtractionResult (record type)
    │   └── data/
    │       ├── datasources/        # LeadRemoteDataSource — 3 Dio calls, and the
    │       │                       # confirmed/network/ambiguous failure classification
    │       ├── models/             # request/response DTOs per endpoint
    │       └── repositories/       # LeadRepositoryImpl
    │
    ├── card_capture/                # camera/gallery intake -> persisted Card. UNCHANGED.
    │   ├── domain/{repositories,usecases}/    # ImageRepository, CaptureCardFromCamera, ImportCardFromGallery
    │   ├── data/{datasources,repositories}/
    │   └── presentation/{cubit,screens,widgets}/    # CardCaptureCubit
    │
    ├── card_extraction/             # POST /api/leads/ — creates the Lead + returns OCR data
    │   ├── domain/usecases/         # ExtractCard
    │   └── presentation/
    │       ├── bloc/                # CardExtractionBloc
    │       └── widgets/             # extracting overlay, ambiguous-outcome warning
    │
    ├── card_editor/                 # review OCR result, edit, call Edit API
    │   ├── domain/usecases/         # UpdateLead
    │   └── presentation/
    │       ├── cubit/                # CardEditorCubit
    │       ├── screens/
    │       └── widgets/
    │
    ├── card_submission/             # NEW — Submit API, agency/user outcome
    │   ├── domain/usecases/          # SubmitLead, RetryUserCreation (provisional, see Open Questions)
    │   └── presentation/
    │       ├── cubit/                 # CardSubmissionCubit
    │       ├── screens/                # OutcomeScreen (success / partial / failure)
    │       └── widgets/
    │
    ├── card_list/                   # Pending / Needs Review / Ready to Submit / Submitted
    │   └── presentation/{cubit,screens,widgets}/    # CardListCubit
    │
    ├── auth/                        # unchanged
    └── settings/                     # unchanged
```

**Why one `lead` module instead of three repositories** (direct answer to
"does extraction/submission deserve separate features/repositories"):
`create`, `update`, and `submit` are three operations on the *same* backend
resource family (`/api/leads/...`), sharing the same Dio client and the same
failure-classification logic (confirmed/network/ambiguous — see below).
Splitting them into three repository interfaces would multiply
boilerplate without buying independent testability or independent
swappability — nothing would ever use `LeadRepository.update` without also
depending on `.create`. So: **one repository, three methods.** What *does*
stay separate are the three **use cases** (`ExtractCard`, `UpdateLead`,
`SubmitLead`) and three **presentation features**, because those really are
distinct business operations with distinct triggers, distinct screens, and
distinct failure/retry UX — collapsing those would be the over-engineering
in the other direction (one generic `SaveCard()` hiding three different
things from the user and from tests).

---

## Domain entities

```dart
typedef CardId = int; // local Drift id

enum CardSource { camera, gallery }

/// State of the remote POST /api/leads/ call — which performs OCR AND
/// creates the backend Lead in one request. Persisted locally so it
/// survives navigation/restart, but every transition past `captured` is
/// driven by that one network call, not by on-device processing. Does not
/// know about edit/submit — those live on BackendSyncStatus.
enum CardProcessingStatus {
  captured,          // image saved locally, extraction not attempted
  extracting,        // POST /api/leads/ in flight
  extracted,         // OCR + Lead creation succeeded; ocrResult + backendLeadId set
  extractionFailed,  // CONFIRMED failure or network failure only. An ambiguous
                     // outcome reverts this to `captured` instead — see
                     // Retry & duplicate-Lead safety.
}

/// Backend Lead lifecycle. Independent axis from CardProcessingStatus —
/// stays notCreated until extraction succeeds, then tracks edit/submit.
enum BackendSyncStatus {
  notCreated,      // no Lead yet
  created,         // Lead exists, not yet edited
  editPending,     // local edits made, not yet sent through Edit API
  updated,         // Edit API succeeded, Lead reflects the latest edited data
  submitting,      // Submit API in flight
  completed,       // agency + user both created
  partialFailure,  // agency created, user creation failed
  failed,          // agency creation CONFIRMED failed. An ambiguous Submit
                   // outcome reverts syncStatus to its pre-attempt value
                   // instead — see Retry & duplicate-Lead safety.
}

class CustomField {
  final String label;
  final String value;
}

/// Same shape for the raw OCR snapshot AND the user's edited data.
class CardData {
  final String? personName;
  final String? companyName;
  final String? designation;
  final String? phone;
  final String? email;
  final String? website;
  final String? address;
  final List<CustomField> customFields;
}

class CardImage {
  final String localPath;
  final String? thumbnailPath;
  final String? galleryAssetId;
}

class SubmissionOutcome {
  final String? agencyId;       // present once agency creation succeeds
  final bool userCreated;       // true only when the full flow completed
  final String? failureReason;  // present for partialFailure/failed
}

class Card {
  final CardId id;
  final String clientCreateRequestId;   // stable UUID, generated at capture — idempotency seam for
                                        // POST /api/leads/, see Retry & Safety
  final String? clientSubmitRequestId;  // stable UUID, generated lazily on first Submit attempt —
                                        // idempotency seam for the Submit API. Kept separate from
                                        // the create id: create and submit are independent
                                        // operations that may need independent idempotency keys.
  final CardImage image;
  final CardSource source;

  final CardProcessingStatus processingStatus;
  final BackendSyncStatus syncStatus;
  final String? backendLeadId;          // null until POST /api/leads/ succeeds

  final CardData? ocrResult;            // immutable once set
  final CardData? editedData;           // renamed from v2's `finalData` — mirrors "Edit Lead"
  final String notes;

  final Failure? lastError;             // last extraction OR submission error, if any (see note below)
  final SubmissionOutcome? submissionOutcome;

  final DateTime createdAt;
  final DateTime updatedAt;
}
```

Why `lastError` is a single field, not one per operation: `extractionFailed`
and a submission failure can never be "live" at the same time for the same
card — `syncStatus` cannot advance past `notCreated` until
`processingStatus` reaches `extracted`, so extraction and submission errors
are temporally exclusive for a given card. One field, always meaning "the
most recent thing that went wrong, if anything, and what to do about it," is
sufficient and avoids two fields that would almost always agree anyway.

---

## Card lifecycle — two independent axes

The previous revision's linear `captured → extracting → needsReview → saved`
model can't represent "extracted but not yet edited" vs. "edited but not yet
submitted" vs. "submitted with a partial failure" without either exploding
into 10+ flat statuses or falling back to boolean flags. Splitting into two
axes avoids both:

```
CardProcessingStatus (the local record of the remote create+OCR call):

  captured ──► extracting ──► extracted
                  │
                  └──► extractionFailed     (CONFIRMED failure only —
                                             an ambiguous outcome reverts
                                             to `captured` instead)


BackendSyncStatus (backend Lead lifecycle, independent axis):

  notCreated ──► created ──► editPending ──► updated ──► submitting ──┬──► completed
                     ▲              │                                │
                     └──────────────┘                                ├──► partialFailure
                     (re-edit after update)                          │
                                                                      └──► failed
```

`BackendSyncStatus` only starts moving once `CardProcessingStatus` reaches
`extracted` — that's the coupling point (a single API call,
`POST /api/leads/`, resolves both axes together on success). After that,
they're independent: editing only moves `syncStatus`, submission only moves
`syncStatus`. `processingStatus` never changes again after reaching
`extracted` — there's no "extraction happens twice" concept. `failed` in the
diagram above means a CONFIRMED Submit failure only — an ambiguous Submit
outcome reverts `syncStatus` to whichever of `created`/`updated` it held
immediately before Submit was attempted, not to `failed`.

**Deliberately dropped from the initial sketch**: a `submitPending` sync
status. It would need to exist between `created`/`updated` and `submitting`,
but nothing ever *causes* that transition — a Lead is submittable any time
`syncStatus ∈ {created, updated}`. Adding a status with no corresponding
event is exactly the "state with no transition" smell to avoid. "Ready to
submit" is a computed condition on the list/editor screens, not a persisted
status.

**Deliberately NOT added**: a separate `ambiguous` value on either enum.
Ambiguous outcomes are represented via the `Failure` type on `lastError`
(`AmbiguousOutcomeFailure`), not as a lifecycle status — "ambiguous" isn't a
resting state a card lives in, it's a property of the last attempt. The
concrete rule: **an ambiguous outcome never advances `processingStatus` or
`syncStatus` toward a failure/terminal value.** It reverts the axis in
question to whatever it held immediately before the attempt
(`extracting → captured`; `submitting → created`/`updated`, whichever it
was), and `lastError` carries the ambiguity. This is what keeps
`extractionFailed`/`failed` honest — they mean *confirmed* failure only,
never "confirmed, or maybe not, we're not sure." Gating retry on the
ambiguous case is a business rule enforced by the use case (see Retry &
duplicate-Lead safety), not something the status enum needs to model, and
it's still fully queryable/filterable via the persisted `last_error_type`
column.

**Card list buckets** (a UI-only computed value, not persisted — derived
from both axes):

| processingStatus | syncStatus | Bucket |
|---|---|---|
| `captured` | `notCreated` | Pending |
| `extracting` | `notCreated` | Extracting… (transient) |
| `extractionFailed` | `notCreated` | Needs attention |
| `extracted` | `created` / `editPending` | Needs Review |
| `extracted` | `updated` | Ready to Submit |
| `extracted` | `submitting` | Submitting… (transient) |
| `extracted` | `completed` | Submitted — Success |
| `extracted` | `partialFailure` | Submitted — Needs attention |
| `extracted` | `failed` | Submission Failed |

Every other combination is unreachable given the use cases are the only
writers of these fields — that's the "invalid states difficult to
represent" goal, achieved through controlled write paths rather than a
sealed type per combination (which would be the over-engineered version of
this).

---

## Retry & duplicate-Lead safety

`POST /api/leads/` creates the Lead. The Submit API triggers the downstream
agency-then-user creation flow. Both are mutating, non-idempotent-by-default
calls, so a timeout on either is fundamentally different from a timeout on
a read: **the client cannot assume the server didn't process the request.**

**Failure classification**, done once in `LeadRemoteDataSource` (shared by
the create and submit calls — Edit is a plain update and doesn't carry the
same duplicate-creation risk, so it doesn't need this classification):

| Dio outcome | Meaning | Failure type | Safe to retry? |
|---|---|---|---|
| Got an error response (4xx/5xx) | Server explicitly rejected/failed the request | `ServerFailure` / `ValidationFailure` | Yes — server confirmed nothing was created |
| `connectionError` / `connectionTimeout` (failed before any bytes sent) | Request never reached the server | `NetworkFailure` | Yes — nothing happened server-side |
| `sendTimeout`, `receiveTimeout`, or a connection drop mid-transfer | Request may have been fully processed; response just didn't arrive | **`AmbiguousOutcomeFailure`** | **No — not without confirmation** |

**An ambiguous outcome never sets `processingStatus = extractionFailed` or
`syncStatus = failed`** — those values mean *confirmed* failure only. On an
ambiguous outcome, the relevant axis reverts to its pre-attempt value
(`extracting → captured`; `submitting → created`/`updated`) and
`lastError = AmbiguousOutcomeFailure` is the only signal that something is
unresolved. This is what lets the UI safely offer a normal, un-gated retry
for `extractionFailed`/`failed` — conflating an ambiguous outcome into
`failed` would either make `failed` unsafe to retry without inspection, or
force every `failed` retry path to re-check `lastError` anyway, defeating
the point of having the status distinguish them.

**`AmbiguousOutcomeFailure` is never blindly retried.** `ExtractCard` and
`SubmitLead` refuse a plain retry when `card.lastError is
AmbiguousOutcomeFailure`; the UI must show an explicit warning ("we
couldn't confirm whether this was already sent — retrying may create a
duplicate") and require acknowledgement before calling the use case again.
This is enforced in the use case layer, not by a status enum value.

**The durable fix is a client-generated idempotency key**, not UI
friction — which is why `Card.clientCreateRequestId` (generated at capture
time) and `Card.clientSubmitRequestId` (generated lazily on the first
Submit attempt) already exist in the schema, unused until the backend
confirms support. They're deliberately two separate ids, not one reused
across both calls: create and submit are independent operations, likely
against different backend code paths, and there's no confirmed guarantee a
single idempotency mechanism covers both the same way — keeping them
separate costs nothing now and avoids assuming an unconfirmed shared
mechanism. The moment support is confirmed (per endpoint), `LeadRepository`
starts sending the relevant id as a header/param, and the "ambiguous → must
acknowledge" UX for that endpoint degrades gracefully into "ambiguous →
safe to auto-retry with the same key." This is flagged as the single most
important open backend question (see below) — everything else about the
retry story is a fallback for the case where the answer is "not supported."

**No automatic background retry loop.** Consistent with "don't
over-engineer": retry for both confirmed and ambiguous failures is
user-initiated from the card's detail/review screen. A background retry
queue is not needed for v1 and isn't precluded later (see Deferred).

---

## Use cases

```
features/card/domain/usecases/
  GetCard(CardId)                       -> Either<Failure, Card>
  WatchCards({filters})                  -> Stream<Either<Failure, List<Card>>>
  DeleteCard(CardId)                     -> Either<Failure, Unit>   // + local file cleanup

features/card_capture/domain/usecases/
  CaptureCardFromCamera()                -> Either<Failure, Card>
  ImportCardFromGallery()                -> Either<Failure, Card>
  // Acquire -> process -> local copy -> best-effort gallery save (camera only)
  // -> CardRepository.createCard(status: captured, syncStatus: notCreated).
  // Zero network calls. Zero dependency on auth state.

features/card_extraction/domain/usecases/
  ExtractCard(CardId, {bool acknowledgedAmbiguousRetry = false}) -> Either<Failure, Card>
  // Guards: no-ops if processingStatus is already `extracting` (prevents a
  // double-tap firing two concurrent POSTs). Refuses to run if lastError is
  // AmbiguousOutcomeFailure and acknowledgedAmbiguousRetry is false.
  //   1. processingStatus = extracting
  //   2. LeadRepository.createLead(image, clientCreateRequestId, cancelToken)
  //   3. success -> backendLeadId, ocrResult, processingStatus = extracted,
  //      syncStatus = created, lastError = null
  //   4. confirmed/network failure -> processingStatus = extractionFailed,
  //      lastError = ServerFailure/NetworkFailure
  //   5. ambiguous failure -> processingStatus REVERTS to captured (never
  //      extractionFailed — outcome unknown), lastError = AmbiguousOutcomeFailure

features/card_editor/domain/usecases/
  UpdateLead(CardId, CardData editedData, String notes) -> Either<Failure, Card>
  // Local-first: persists editedData + notes immediately, syncStatus =
  // editPending, BEFORE calling the network. Then:
  //   LeadRepository.updateLead(backendLeadId, editedData)
  //   success -> syncStatus = updated
  //   failure -> stays editPending; lastError set (never loses the edit)

features/card_submission/domain/usecases/
  SubmitLead(CardId, {bool acknowledgedAmbiguousRetry = false}) -> Either<Failure, Card>
  // Requires backendLeadId present (validation failure otherwise). Generates
  // clientSubmitRequestId on first attempt if not already set. Same
  // ambiguous-retry guard as ExtractCard.
  //   1. priorSyncStatus = current syncStatus (created or updated)
  //   2. syncStatus = submitting
  //   3. LeadRepository.submitLead(backendLeadId, clientSubmitRequestId, cancelToken)
  //   4. confirmed outcome -> submissionOutcome set, syncStatus ∈
  //      {completed, partialFailure, failed} per the response
  //   5. ambiguous outcome -> syncStatus REVERTS to priorSyncStatus (never
  //      failed — outcome unknown), lastError = AmbiguousOutcomeFailure,
  //      submissionOutcome stays null
  RetryUserCreation(CardId)              -> Either<Failure, Card>   // PROVISIONAL
  // Exact mechanics depend on how the backend supports retrying only the
  // user-creation half of a partialFailure without re-running agency
  // creation. Signature/behavior TBD — see Open Questions. The architecture
  // reserves this use case and the SubmissionOutcome.agencyId field so it
  // can be implemented once confirmed, without a schema change.
```

Field-level edits (typing, adding/removing a custom-field row) remain
in-memory `CardEditorCubit` draft mutations, not use cases — same reasoning
as the previous revision. `UpdateLead` is the persistence/sync boundary,
called once on "Save edits."

---

## Repository interfaces

```dart
// features/card/domain/repositories/card_repository.dart — LOCAL ONLY
abstract class CardRepository {
  Future<Either<Failure, Card>> createCard(CardImage image, CardSource source, String clientCreateRequestId);
  Future<Either<Failure, Card>> getCard(CardId id);
  Stream<Either<Failure, List<Card>>> watchCards({CardProcessingStatus? processing, BackendSyncStatus? sync});
  Future<Either<Failure, Card>> updateCard(Card card); // generic local field update
  Future<Either<Failure, Unit>> deleteCard(CardId id);
}

// features/lead/domain/repositories/lead_repository.dart — BACKEND ONLY
abstract class LeadRepository {
  Future<Either<Failure, LeadExtractionResult>> createLead(
    CardImage image, {
    required String clientCreateRequestId,
    CancelToken? cancelToken,
  });

  Future<Either<Failure, CardData>> updateLead(String leadId, CardData editedData);

  Future<Either<Failure, SubmissionOutcome>> submitLead(
    String leadId, {
    required String clientSubmitRequestId,
    CancelToken? cancelToken,
  });
}

typedef LeadExtractionResult = ({String backendLeadId, CardData ocrResult});

// features/card_capture/domain/repositories/image_repository.dart — unchanged
abstract class ImageRepository {
  Future<Either<Failure, CardImage>> captureFromCamera();
  Future<Either<Failure, CardImage>> importFromGallery();
}
```

`CardRepository` never imports Dio or anything network-related.
`LeadRepository` never imports Drift or anything local-storage-related. Use
cases are the only place that talks to both — which is exactly where that
coordination belongs.

---

## Data sources

```
card/data/datasources/
  CardLocalDataSource          # Drift CRUD + watch queries

lead/data/datasources/
  LeadRemoteDataSource          # 3 Dio calls (create/update/submit) against
                                # /api/leads/... + the confirmed/network/
                                # ambiguous failure classification (shared
                                # logic, used by the create and submit calls
                                # only — update doesn't carry the same
                                # duplicate-creation risk)

card_capture/data/datasources/
  CameraDataSource
  GalleryDataSource            # image_picker (pick) + gal (save)
  ImageProcessingDataSource     # image pkg, via compute()
  LocalFileStorageDataSource
```

---

## Bloc/Cubit responsibilities

Five focused units — one per workflow stage, matching the product's own
five stages (capture, extract, edit, submit, list). Still no monolith, still
no bloc-to-bloc coupling: navigation passes a `CardId`, the next
Bloc/Cubit re-fetches from `CardRepository`.

- **`CardCaptureCubit`** (Cubit) — unchanged. Camera/gallery, preview, zero
  backend dependency.
- **`CardExtractionBloc`** (Bloc — event-driven for cancellation). Calls
  `ExtractCard`. States: `ExtractionIdle`, `Extracting(Card)`,
  `ExtractionSuccess(Card)`, `ExtractionFailure(Card, Failure)`. The UI
  branches on `failure is AmbiguousOutcomeFailure` to show the
  acknowledge-before-retry warning — not a distinct Bloc state, to avoid
  state proliferation for what is fundamentally a Failure-type concern. Note
  that the `Card` attached to `ExtractionFailure` has
  `processingStatus = captured` when the failure is ambiguous (it reverted,
  per Retry & Safety), not `extractionFailed` — the UI keys its warning off
  `failure`'s type, not off `card.processingStatus`.
- **`CardEditorCubit`** (Cubit) — same shape as before, `save()` now calls
  `UpdateLead` instead of a purely local save. States: `EditorLoaded(draft,
  isDirty)`, `EditorSaving`, `EditorSaved(Card)`, `EditorError(Failure)`.
- **`CardSubmissionCubit`** (Cubit, **new**) — deliberately *not* a Bloc:
  unlike extraction (a slow OCR call over a large image upload, where
  cancel-and-retake is a real user need), submission is a small, fast
  payload with no meaningful mid-flight cancellation use case, and
  interrupting a multi-step backend operation (agency then user creation)
  mid-flight is worse than letting it finish. States are three distinct
  sealed variants — not one generic result with nullable fields — because
  the three outcomes are genuinely mutually exclusive and the UI must
  render them differently: `SubmissionIdle`, `Submitting(Card)`,
  `SubmissionSucceeded(Card, SubmissionOutcome)`,
  `SubmissionPartial(Card, SubmissionOutcome)`,
  `SubmissionFailed(Card, Failure)`. `SubmissionFailed` covers both
  confirmed (`syncStatus = failed`) and ambiguous (`syncStatus` reverted to
  its pre-Submit value) outcomes — same pattern as `CardExtractionBloc`, the
  UI branches on `failure is AmbiguousOutcomeFailure`, not on
  `card.syncStatus`, to decide whether to gate the retry.
- **`CardListCubit`** (Cubit, subscribes to `WatchCards`). Computes the
  bucket table above for filtering/display.

`auth` and `settings` are unchanged and out of scope here.

---

## Flow: Capture → Save for Later (unchanged, reaffirmed)

```
Camera/Gallery -> process image -> local copy (+ best-effort gallery save)
  -> CardRepository.createCard(status: captured, syncStatus: notCreated)
  -> CapturePreview(card)
  -> user taps "Save for Later" -> nothing further to persist -> back to camera
```

No backend call anywhere in this path. `CardCaptureCubit`, `ImageRepository`,
and `CardRepository` have **zero import-level dependency on `features/auth`**
— this is an explicit architectural constraint, not just an emergent
property, precisely so a guest user can capture cards identically to a
logged-in one (see Guest Flow below).

## Flow: Capture → Extract → Review/Edit → Submit → Outcome

```
Capture (as above, status = captured)
  │
  │ user taps "Extract" (either immediately, or later from Card List)
  ▼
CardExtractionBloc: ExtractionStarted(cardId)
  -> processingStatus = extracting
  -> LeadRepository.createLead(image, clientCreateRequestId)
  -> POST /api/leads/
  │
  ├─ success -> backendLeadId + ocrResult persisted,
  │             processingStatus = extracted, syncStatus = created
  │             -> navigate to CardEditorScreen
  │
  ├─ confirmed/network failure -> processingStatus = extractionFailed,
  │                              lastError set -> stays on Preview screen,
  │                              Retry available normally
  │
  └─ ambiguous failure -> processingStatus REVERTS to captured (not
                          extractionFailed), lastError = AmbiguousOutcomeFailure
                          -> stays on Preview screen; Retry requires explicit
                             acknowledgement per Retry & Safety

CardEditorCubit: loads card, seeds draft = copy of ocrResult
  (ocrResult itself is never mutated — stays available for comparison)
  -> user edits fields / custom fields / notes
  -> taps "Save"
  -> UpdateLead(cardId, draft, notes)
     -> persists editedData + notes locally FIRST, syncStatus = editPending
     -> Edit API call
     -> success: syncStatus = updated
     -> failure: stays editPending, lastError set — edit is NEVER lost
                 locally even if the Edit API call fails
  -> navigate to review-complete state, "Submit" now available

CardSubmissionCubit: user taps "Submit"
  -> priorSyncStatus = current syncStatus (created or updated)
  -> syncStatus = submitting
  -> SubmitLead(cardId)
  -> LeadRepository.submitLead(backendLeadId, clientSubmitRequestId)
  │
  ├─ completed         -> SubmissionOutcome(agencyId, userCreated: true),
  │                       syncStatus = completed
  ├─ partialFailure     -> SubmissionOutcome(agencyId, userCreated: false, reason),
  │                       syncStatus = partialFailure — Lead + agency remain
  │                       locally available, only user-creation is retryable
  ├─ failed (confirmed) -> Failure surfaced, syncStatus = failed, Lead remains
  │                       locally available, Retry available normally
  └─ ambiguous          -> Failure surfaced (AmbiguousOutcomeFailure),
                          syncStatus REVERTS to priorSyncStatus — never set
                          to failed, since agency/user creation may have
                          actually succeeded. Retry requires explicit
                          acknowledgement per Retry & Safety.

OutcomeScreen renders one of three distinct states — see Bloc section.
```

## Flow: later extraction, from the Card List

```
Card List (Pending bucket) -> open Card 1 -> same ExtractCard/UpdateLead/
SubmitLead flow as above, entered from a different screen. No separate
business logic — this is the exact same use-case chain as the
"extract immediately" path, just triggered later.
```

## Flow: Gallery import (unchanged, reaffirmed)

Still converges into the identical pipeline as camera capture — the branch
is isolated to `ImageRepositoryImpl` (skip gallery-save step; everything
else, including the entire extraction/edit/submit chain above, is identical
and unaware of `CardSource`).

---

## Image storage strategy — unchanged

No concrete issue was found that requires a change. Reaffirming the
previous revision's strategy as still correct for the 20–50+ card event
scenario:

- App-local sandbox copy = source of truth; gallery copy = best-effort,
  fire-and-forget, camera-only.
- Resize (~1600–2000px long edge) + JPEG compress (~85 quality) via
  `compute()`, off the UI thread.
- Thumbnails generated alongside the main image; list screens only ever
  decode thumbnails, never full images, keeping memory bounded regardless
  of how many cards have been captured.
- Deleting a Card deletes its local files, never the Photos library copy.

---

## Guest flow

Capture requires **no authentication**, unconditionally — this is enforced
architecturally by `card_capture` and `card`'s local persistence layer
having no dependency on `features/auth` or on `ApiClient`/`SecureStorageService`
at all. A guest can capture and locally save 20–50 cards with no account.

Extraction, edit, and submission go through `ApiClient`, whose existing auth
interceptor attaches a token *if one is present* in secure storage — for a
guest, none is, so whether those calls succeed for a guest depends entirely
on backend policy (see Open Questions). No special "migrate guest cards"
step is needed: once the user logs in, the same local Cards that were
sitting in the Pending/Needs Review buckets are simply now actionable,
because `ApiClient` now has a token to attach. This falls out of the
local/backend separation for free rather than requiring dedicated code.

---

## Error handling strategy

Extends the previous revision's `Failure` hierarchy. New addition:

```dart
class AmbiguousOutcomeFailure extends Failure {
  // A mutating request (create/submit) may have been processed by the
  // server despite no confirmed response reaching the client. Distinct
  // from NetworkFailure (request never sent) and TimeoutFailure (used
  // elsewhere in the app for calls where a timeout is always safe to
  // retry, e.g. plain reads). Never blindly retried — see Retry & Safety.
  // Use cases that catch this NEVER move processingStatus/syncStatus to a
  // failure value (extractionFailed/failed) — they revert to the
  // pre-attempt value instead, since the outcome is genuinely unknown.
  bool get isRetryable => false; // not automatically; requires explicit
                                  // user acknowledgement via the use case
}
```

Existing types (`ServerFailure`, `NetworkFailure`, `ValidationFailure`,
`UnauthorizedFailure`, `TimeoutFailure`, `ImageProcessingFailure`,
`LocalStorageFailure`, `ExtractionFailure`, `UnknownFailure`) are unchanged
and reused; `ExtractionFailure` now specifically covers the case where the
OCR call succeeds at the HTTP level but the backend signals it couldn't
read the card (a confirmed, safely-retryable failure — distinct from
`AmbiguousOutcomeFailure`).

Logging: unchanged — `AppLogger` never logs card PII or full
request/response bodies in release builds; only error type, HTTP status,
timing, and card id.

---

## Senior architecture review

Direct answers to the review questions raised:

- **Is Drift still appropriate?** Yes — see the dedicated section above. The
  schema grew (Lead linkage, sync status, submission outcome) but nothing
  about that growth needs a different kind of database; it's more columns
  on the same relational model.
- **Is the four-Cubit/Bloc structure still appropriate?** It's now five, and
  yes — each maps 1:1 to a real, distinct product stage
  (capture/extract/edit/submit/list). Adding `CardSubmissionCubit` reflects
  a genuinely new operation (Submit API + 3-outcome result), not scope
  creep.
- **Should `Card` remain the central local aggregate?** Yes, more clearly
  now than before — the confirmed backend contract makes explicit that many
  Cards will exist per few Leads, which only makes sense if Card is the
  primary local entity and Lead-related state is *attached to* it, not the
  other way around.
- **Does backend Lead sync deserve its own feature/repository?** Its own
  feature (`lead/`), yes. Its own *repository* — reconsidered down to one
  shared `LeadRepository` with three methods rather than three, for the
  reasons given in the Folder Structure section (same resource, same
  client, same failure-classification logic; splitting further wouldn't
  buy independent testability).
- **Should extraction and submission be separate features?** Yes — as
  presentation features and use cases, because they're genuinely distinct
  triggers/screens/failure semantics for the user. Not as repositories (see
  above).
- **Does the schema correctly represent local Card, Lead id, OCR result,
  edited result, sync state, submission outcome?** Yes — each is now an
  explicit column/field rather than folded into a single flat status, per
  the schema section above.
- **Does the architecture handle ambiguous network failures safely?** Yes,
  as far as is possible without a confirmed idempotency mechanism: ambiguous
  outcomes are classified distinctly, never auto-retried, and — critically —
  never recorded as a confirmed failure (`processingStatus`/`syncStatus`
  revert to their pre-attempt value rather than advancing to
  `extractionFailed`/`failed`), so the status model never asserts something
  it doesn't actually know. The schema already reserves
  `clientCreateRequestId`/`clientSubmitRequestId` for the moment the backend
  confirms idempotency-key support per endpoint, at which point this
  degrades from "must acknowledge" to "safe to retry automatically." This is
  the one place where the architecture is knowingly incomplete pending a
  backend answer — flagged explicitly rather than papered over.
- **Does it support rapid event capture?** Yes, unchanged from the previous
  revision — capture has zero network dependency and the local write path
  (compress + one DB insert) is the only thing between shutter taps.
- **Can it support batch extraction/submission later without a rewrite?**
  Yes — `ExtractCard(cardId)` and `SubmitLead(cardId)` are already
  single-card orchestrators; a future `ExtractSelectedCards(List<CardId>)`
  or `SubmitSelectedCards(List<CardId>)` composes them without touching
  existing use cases, Blocs, or the repository layer.
- **Is anything over-engineered?** Two things were deliberately pulled back
  during this revision, worth naming explicitly: (1) a `submitPending` sync
  status was dropped as a status with no corresponding event; (2) a
  separate `ambiguous` value on the status enums was rejected in favor of
  representing it via the `Failure` type on `lastError`, with the concrete
  rule that ambiguous outcomes revert the affected axis to its pre-attempt
  value rather than advancing it — keeping both status enums at 4 and 8
  values respectively instead of growing them further for a concern that's
  really about the *last attempt*, not the card's resting state.

---

## What should be implemented now vs. deferred

**Now (v1)** — everything from the previous revision's list, plus:

- `CardProcessingStatus` / `BackendSyncStatus` two-axis model, `SubmissionOutcome`
- `lead/` feature: `LeadRepository`, `LeadRemoteDataSource`, confirmed/network/ambiguous
  failure classification
- `ExtractCard`, `UpdateLead`, `SubmitLead` use cases (meaningfully distinct, not one
  generic save)
- `CardSubmissionCubit` + Outcome screen with 3 distinct rendered states
- `clientCreateRequestId` generation (`uuid`) at capture time, and
  `clientSubmitRequestId` generation lazily on first Submit attempt — both
  stored now, used as idempotency keys once confirmed per endpoint
- Card List bucket computation across both status axes

**Deliberately deferred**:

- **Idempotent auto-retry** for `createLead`/`submitLead` — blocked entirely
  on the backend confirming idempotency-key/request-ID support (see Open
  Questions). Until then, retry after an ambiguous outcome stays
  user-acknowledged, never automatic.
- **`RetryUserCreation`** — signature/behavior is provisional; needs the
  Submit API's retry contract confirmed (see Open Questions) before it can
  be implemented for real.
- **Background upload/sync engine** — still not required for v1; the
  repository split (`CardRepository` vs. `LeadRepository`) already supports
  adding one later without touching use cases or presentation.
- **Batch extraction/submission** — architecturally supported (see review
  above), not built now.
- **Backend Lead ↔ local edit conflict handling** (e.g. what if the same
  Lead is edited from two devices) — out of scope; this is a single-device,
  single-user local app.
- **Isar or other DB reconsideration** — not warranted by anything in this
  revision.

---

## 1. Architecture changes

What changed from the previous revision, directly:

1. **New concept: local `Card` vs. backend `Lead`, explicitly distinct.**
   The previous revision conflated "extraction" with a generic
   result-fetch; now `POST /api/leads/` is understood to create persistent
   backend state, and `Card.backendLeadId` is `null` until that succeeds.
2. **Card status model split into two independent axes**
   (`CardProcessingStatus`, `BackendSyncStatus`) replacing the single linear
   `captured → extracting → needsReview → saved` — the old model had no way
   to represent "extracted but not edited" vs. "edited but not submitted" vs.
   "submitted with a partial failure" without booleans or a much longer
   flat enum.
3. **New `lead/` feature module** — a single `LeadRepository` covering
   create/update/submit, shared by three presentation features. Didn't
   exist before; extraction previously had its own repository assumption
   with no concept of edit/submit.
4. **New `card_submission` feature** — didn't exist before at all. New
   `CardSubmissionCubit` with three mutually-exclusive outcome states.
5. **`card_editor`'s use case changed** from a purely local `SaveFinalCard`
   to `UpdateLead`, which calls the real Edit API and is local-first
   (persists the edit before attempting the network call, so an edit is
   never lost even if the Edit API fails).
6. **New `Failure` type**: `AmbiguousOutcomeFailure`, plus the
   confirmed/network/ambiguous classification logic in `LeadRemoteDataSource`
   — this entire safety concern didn't exist previously because the OCR
   call wasn't understood to create backend state.
7. **`Card.clientRequestId`** (UUID, generated at capture) added to the
   schema — a forward-looking field for the idempotency-key question, at
   effectively zero cost now.
8. **`CardData.editedData`** renamed from `finalData` to better match the
   now-confirmed "Edit Lead" API terminology; behavior unchanged (immutable
   `ocrResult` snapshot vs. editable draft).
9. **Explicit guest-flow constraint** — `card_capture` and `card`'s local
   layer must not depend on `features/auth` at all, stated as an
   architectural rule rather than left implicit.
10. **New dependency**: `uuid`. Everything else from the previous
    revision's stack is unchanged.

## 2. Confirmed backend contract

- Three separate endpoints: create+OCR (`POST /api/leads/`), Edit, Submit.
- `POST /api/leads/` is synchronous: uploads the image, runs OCR, extracts
  fields, **creates a persistent Lead**, and returns both the extracted
  fields and the Lead id in one response. No job id, polling, websocket, or
  webhook.
- Edit is a separate API call, made after the user reviews/corrects OCR
  output.
- Submit is a separate API call, made after edit, and triggers
  agency+user creation with three possible outcomes: full success, partial
  success (agency created, user creation failed), or failure (agency
  creation failed).
- Guests can skip login (per backend docs); exact scope of what guests can
  call is still open (see below).

## 3. Open backend questions

Only the ones that block or materially affect implementation:

1. **Idempotency / safe recovery for `POST /api/leads/` and Submit.** Does
   either API support a client-generated idempotency key or request ID —
   and if so, is it one mechanism shared by both endpoints, or does each
   need its own? (The architecture assumes the latter and reserves separate
   `clientCreateRequestId`/`clientSubmitRequestId` fields, but that's an
   assumption, not a confirmed contract.) This is the single
   highest-priority question — without it, every ambiguous timeout requires
   manual user acknowledgement before retry, and duplicate Leads/agencies
   remain a real risk in poor-connectivity event environments (the exact
   conditions this app is built for).
2. **Exact `POST /api/leads/` response shape** — field names for the Lead
   id and each extracted field, so `LeadExtractionResult`/`CardDataModel`
   mapping can be written precisely.
3. **Edit API request/response shape** — does it return the server's
   confirmed state of the Lead (recommended, so the local `editedData` can
   be reconciled against what the server actually stored), or just a
   success/failure signal?
4. **Submit API request/response shape** — specifically, the discriminator
   used to distinguish completed / partialFailure / failed, and the shape
   of `agencyId`/user info/error codes returned in each case.
5. **Partial-failure retry behavior**: if agency creation succeeded but
   user creation failed, does retrying Submit re-run agency creation (risk
   of duplicate agencies) or is there a way to retry only the user-creation
   step against the existing agency? This directly determines whether
   `RetryUserCreation` can be implemented as designed.
6. **Guest authentication requirements per endpoint.** Confirmed that
   capture needs no auth (enforced locally regardless). Does
   `POST /api/leads/`, Edit, or Submit require authentication even for
   guest-originated leads, or is there guest-mode support server-side too?
7. **Error codes/vocabulary** for agency/user creation failures, so
   `submission_failure_reason` can show something more useful than a raw
   message where possible.

## 4. Recommended implementation order

Sequenced so each step is independently useful and testable before the next
depends on it:

1. **Local persistence** — `AppDatabase` (Drift), `cards` +
   `card_custom_fields` tables, `Card`/`CardData`/status enums,
   `CardRepository` + `CardLocalDataSource`. Verifiable with unit tests
   alone, no UI needed yet.
2. **Capture & gallery import** — `ImageRepository` +
   `CardCaptureCubit`, camera + gallery pipeline, local-only. This is the
   highest-value, most time-sensitive path (event capture speed) and has
   zero backend dependency, so it can be built and validated in isolation.
3. **Preview / Save-for-Later screen** — proves the "capture N cards
   rapidly with zero waiting" requirement end-to-end before any network
   code exists.
4. **Card List** (Pending bucket only, to start) — needed to navigate back
   into previously captured cards; can be built with just
   `CardProcessingStatus.captured` filtering before the other buckets have
   any data to show.
5. **`lead/` feature + `ExtractCard`** — `LeadRepository`,
   `LeadRemoteDataSource` (including the confirmed/network/ambiguous
   classification), `CardExtractionBloc`. This is the first network-
   dependent piece; build once the create-Lead response shape is confirmed
   (Open Question 2).
6. **`CardEditorCubit` + `UpdateLead`** — review/edit screen, Edit API
   integration. Depends on Open Question 3.
7. **`CardSubmissionCubit` + `SubmitLead` + Outcome screen** — the three
   distinct outcome states. Depends on Open Questions 4–5.
8. **`RetryUserCreation`** and **idempotency-key wiring** — implemented
   once Open Questions 1 and 5 are answered; until then, the
   acknowledge-before-retry fallback (already part of step 5–7) is the
   production behavior.
9. **Remaining Card List buckets** (Needs Review / Ready to Submit /
   Submitted) — mechanical once steps 5–7 exist, since the bucket table is
   a pure function of state that already exists by this point.

Steps 1–4 have no backend dependency and can start immediately. Steps 5–8
should be sequenced against backend confirmation of the open questions
above, in roughly that order, so no step is built against a guessed
contract that then needs rework.
