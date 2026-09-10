import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/filter_chip_row.dart';
import '../../../../core/widgets/info_banner.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../leads/presentation/cubit/lead_store_cubit.dart';
import '../../../leads/domain/entities/lead.dart';
import '../../../leads/export_file_storage.dart';

enum _Filter { all, pending, needsReview, created, partial, failed }

/// The production-dashboard read: a branded header (not a generic AppBar),
/// meaningful stat cards, a status filter, and rows with real hierarchy —
/// answers "how many leads, what needs attention, where do I scan next"
/// at a glance, plus a floating scan CTA (from the original mockup, never
/// actually built until now).
class CardListScreen extends StatefulWidget {
  const CardListScreen({super.key});

  @override
  State<CardListScreen> createState() => _CardListScreenState();
}

class _CardListScreenState extends State<CardListScreen> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;
  bool _loadingInitial = true;
  bool _exporting = false;
  bool _submittingAll = false;

  @override
  void initState() {
    super.initState();
    _refresh(showErrorSnackBar: false);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool showErrorSnackBar = true}) async {
    final error = await context.read<LeadStoreCubit>().refreshFromBackend();
    if (!mounted) return;
    if (_loadingInitial) setState(() => _loadingInitial = false);
    if (error != null && showErrorSnackBar) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Couldn't refresh leads: $error")));
    }
  }

  /// GET /api/leads/export/ -> save to a temp file -> hand it to the OS
  /// share sheet, so the user picks where it ends up (Files, email,
  /// AirDrop, ...) rather than the app guessing a destination for them.
  Future<void> _export() async {
    setState(() => _exporting = true);
    final result = await context.read<LeadStoreCubit>().exportToExcel();
    if (!mounted) return;
    setState(() => _exporting = false);
    if (result.error != null || result.file == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Couldn't export leads: ${result.error}")));
      return;
    }
    final path = await saveExportFile(result.file!.bytes, result.file!.filename);
    if (!mounted) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
  }

  /// Bulk submit creates real agencies/users at Travel Compositor for
  /// every eligible lead at once — a confirmation dialog first, since
  /// there's no per-lead review step here the way there is for a single
  /// "Create agency" (see [LeadSubmitRepository.submitAll]'s doc comment).
  Future<void> _confirmSubmitAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit all leads?'),
        content: const Text(
          'This creates a real agency and user for every lead that\'s ready '
          'to submit. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submittingAll = true);
    final error = await context.read<LeadStoreCubit>().submitAllPending();
    if (!mounted) return;
    setState(() => _submittingAll = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error != null ? "Couldn't submit all leads: $error" : 'Leads submitted.'),
      ),
    );
  }

  void _open(Lead lead) {
    switch (lead.status) {
      case LeadStatus.pending:
      case LeadStatus.needsReview:
        context.push('/leads/${lead.id}/review');
      case LeadStatus.partial:
      case LeadStatus.failed:
        // Still actionable (Retry / Edit and retry) — the outcome screen is
        // the right place for that.
        context.push('/leads/${lead.id}/outcome');
      case LeadStatus.created:
        // Resolved — nothing left to retry, so this opens the persistent
        // record instead of re-showing the one-time success screen.
        context.push('/leads/${lead.id}');
    }
  }

  bool _matchesFilter(Lead lead) => switch (_filter) {
    _Filter.all => true,
    _Filter.pending => lead.status == LeadStatus.pending,
    _Filter.needsReview => lead.status == LeadStatus.needsReview,
    _Filter.created => lead.status == LeadStatus.created,
    _Filter.partial => lead.status == LeadStatus.partial,
    _Filter.failed => lead.status == LeadStatus.failed,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      // No scan CTA here — the bottom nav's raised center tab is the single
      // entry point for capture now, so this doesn't duplicate it.
      body: BlocBuilder<LeadStoreCubit, List<Lead>>(
        builder: (context, leads) {
          final total = leads.length;
          final created = leads
              .where((l) => l.status == LeadStatus.created)
              .length;
          final partial = leads
              .where((l) => l.status == LeadStatus.partial)
              .length;
          final failed = leads
              .where((l) => l.status == LeadStatus.failed)
              .length;
          final pending = leads
              .where((l) => l.status == LeadStatus.pending)
              .length;
          final needsReview = leads
              .where((l) => l.status == LeadStatus.needsReview)
              .length;

          final query = _search.text.trim().toLowerCase();
          final visible = leads.where((l) {
            if (!_matchesFilter(l)) return false;
            if (query.isEmpty) return true;
            return l.agencyName.toLowerCase().contains(query) ||
                l.contactName.toLowerCase().contains(query) ||
                l.email.toLowerCase().contains(query);
          }).toList();

          // One row per agency, not one per contact — two people scanned
          // for the same agency (see [Lead.siblingLeadIds]) used to show
          // as two separate cards, each opening straight to its own
          // contact, which read as duplicate agencies rather than one
          // agency with two people. Each row still resolves to a single
          // real [Lead] to open (or a choice between them, for a
          // multi-contact agency) — nothing about navigation/editing
          // changed, only how many cards represent one agency in this list.
          final rows = <({Lead primary, List<Lead> contacts})>[];
          final consumedIds = <String>{};
          for (final lead in visible) {
            if (consumedIds.contains(lead.id)) continue;
            final groupIds = {lead.id, ...lead.siblingLeadIds};
            final contacts = leads.where((l) => groupIds.contains(l.id)).toList();
            consumedIds.addAll(groupIds);
            rows.add((primary: lead, contacts: contacts));
          }

          return SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Leads', style: AppTextStyles.displayMd()),
                                const SizedBox(height: 2),
                                Text(
                                  pending + needsReview == 0
                                      ? 'All caught up'
                                      : '$pending pending · $needsReview need review',
                                  style: AppTextStyles.bodySm(),
                                ),
                              ],
                            ),
                          ),
                          _ExportButton(
                            loading: _exporting,
                            onTap: _exporting ? null : _export,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: AppSpacing.sm + 2,
                              mainAxisSpacing: AppSpacing.sm + 2,
                              mainAxisExtent: 124,
                            ),
                        children: [
                          StatCard(
                            label: 'Total leads',
                            value: '$total',
                            icon: Icons.badge_outlined,
                          ),
                          StatCard(
                            label: 'Created',
                            value: '$created',
                            icon: Icons.check_circle_outline_rounded,
                            tone: StatTone.success,
                          ),
                          StatCard(
                            label: 'Partial',
                            value: '$partial',
                            icon: Icons.error_outline_rounded,
                            tone: StatTone.warning,
                          ),
                          StatCard(
                            label: 'Failed',
                            value: '$failed',
                            icon: Icons.report_gmailerrorred_rounded,
                            tone: StatTone.danger,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (needsReview > 0)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.lg,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: InfoBanner(
                          icon: Icons.upload_rounded,
                          message:
                              '$needsReview lead${needsReview == 1 ? '' : 's'} ready to submit.',
                          actionLabel: _submittingAll ? 'Submitting…' : 'Submit all',
                          onAction: _submittingAll ? null : _confirmSubmitAll,
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            style: AppTextStyles.body(),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Search by name, email, agency',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 19,
                                color: AppColors.ink3,
                              ),
                              filled: true,
                              fillColor: AppColors.surface,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: AppRadius.mdRadius,
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: AppRadius.mdRadius,
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: FilterChipRow<_Filter>(
                                  selected: _filter,
                                  onChanged: (f) => setState(() => _filter = f),
                                  options: [
                                    FilterChipOption(
                                      value: _Filter.all,
                                      label: 'All',
                                      count: total,
                                    ),
                                    FilterChipOption(
                                      value: _Filter.pending,
                                      label: 'Pending',
                                      count: pending,
                                    ),
                                    FilterChipOption(
                                      value: _Filter.needsReview,
                                      label: 'Needs review',
                                      count: needsReview,
                                    ),
                                    FilterChipOption(
                                      value: _Filter.created,
                                      label: 'Created',
                                      count: created,
                                    ),
                                    FilterChipOption(
                                      value: _Filter.partial,
                                      label: 'Partial',
                                      count: partial,
                                    ),
                                    FilterChipOption(
                                      value: _Filter.failed,
                                      label: 'Failed',
                                      count: failed,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _FilterHelpButton(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_loadingInitial && leads.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (visible.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.inbox_outlined,
                        title: leads.isEmpty ? 'No leads yet' : 'No matches',
                        message: leads.isEmpty
                            ? 'Scan your first business card to get started.'
                            : 'Try a different search or filter.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      sliver: SliverList.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm + 2),
                        itemBuilder: (context, i) {
                          final row = rows[i];
                          return _LeadRow(
                            lead: row.primary,
                            contacts: row.contacts,
                            onOpen: _open,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryDim,
      borderRadius: AppRadius.mdRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdRadius,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(
                    Icons.ios_share_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
          ),
        ),
      ),
    );
  }
}

/// A single "what do these mean?" entry point for the status filters,
/// rather than a tooltip on each chip — long-press tooltips on a
/// touch-first screen aren't discoverable, so one tap here opens a sheet
/// explaining every status at once.
class _FilterHelpButton extends StatelessWidget {
  const _FilterHelpButton();

  static const _explanations = [
    (label: 'All', detail: 'Every card you\'ve scanned, in any status.'),
    (
      label: 'Pending',
      detail: 'Captured but not yet processed — open it to extract the details.',
    ),
    (
      label: 'Needs review',
      detail: 'Details extracted — review and correct them before creating the agency.',
    ),
    (label: 'Created', detail: 'Submitted successfully — the agency and user were created.'),
    (
      label: 'Partial',
      detail: 'The agency was created, but the user invite failed — retry it from here.',
    ),
    (label: 'Failed', detail: 'Submission was rejected — edit the card and try again.'),
  ];

  void _showExplanations(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      // Without this, the sheet is capped at ~half the screen height
      // regardless of content, so a Column taller than that (six statuses,
      // each with a title + description) overflows instead of scrolling.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter statuses', style: AppTextStyles.titleSm()),
                const SizedBox(height: AppSpacing.md),
                for (final e in _explanations) ...[
                  Text(
                    e.label,
                    style: AppTextStyles.body().copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(e.detail, style: AppTextStyles.bodySm()),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        onTap: () => _showExplanations(context),
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            Icons.info_outline_rounded,
            size: 17,
            color: AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _LeadRow extends StatelessWidget {
  const _LeadRow({required this.lead, required this.contacts, required this.onOpen});

  // The contact this row's name/status/time are drawn from — the one that
  // matched the current filter/search (see where [_LeadRow] is built).
  final Lead lead;
  // Every contact scanned under this same agency, [lead] included (see
  // [Lead.siblingLeadIds]) — length 1 for an agency with only one contact.
  // Tapping the row opens [lead] directly when this is the only one;
  // otherwise it asks which contact to open, rather than guessing.
  final List<Lead> contacts;
  final ValueChanged<Lead> onOpen;

  void _pickContact(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contacts at ${lead.agencyName.isEmpty ? 'this agency' : lead.agencyName}',
                  style: AppTextStyles.titleSm(),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final contact in contacts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      flat: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2,
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onOpen(contact);
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              contact.contactName.trim().isEmpty
                                  ? 'Not extracted yet'
                                  : contact.contactName,
                              style: AppTextStyles.body(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          StatusPill(label: contact.status.label, tone: contact.status.tone),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    if (contacts.length <= 1) {
      onOpen(lead);
    } else {
      _pickContact(context);
    }
  }

  String get _initials {
    final name = lead.agencyName.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    return parts.length == 1
        ? parts.first.substring(0, 1)
        : '${parts.first[0]}${parts[1][0]}';
  }

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(lead.capturedAt).format(context);
    return AppCard(
      flat: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      onTap: () => _handleTap(context),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primaryDim,
              shape: BoxShape.circle,
            ),
            child: Text(
              _initials.toUpperCase(),
              style: AppTextStyles.titleSm(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lead.agencyName.isEmpty ? 'Untitled card' : lead.agencyName,
                  style: AppTextStyles.titleSm(),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  lead.contactName.trim().isEmpty
                      ? 'Not extracted yet'
                      : lead.contactName,
                  style: AppTextStyles.bodySm(),
                  overflow: TextOverflow.ellipsis,
                ),
                if (contacts.length > 1) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDim,
                      borderRadius: AppRadius.pillRadius,
                    ),
                    child: Text(
                      '${contacts.length} contacts — tap to choose',
                      style: AppTextStyles.caption(
                        color: AppColors.primary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(label: lead.status.label, tone: lead.status.tone),
              const SizedBox(height: 6),
              Text(time, style: AppTextStyles.caption()),
            ],
          ),
          const SizedBox(width: 2),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.ink3,
          ),
        ],
      ),
    );
  }
}
