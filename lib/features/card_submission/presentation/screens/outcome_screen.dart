import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/sticky_action_bar.dart';
import '../../../leads/presentation/cubit/lead_store_cubit.dart';
import '../../../leads/domain/entities/lead.dart';

/// Reproduces the three distinct outcomes required by ARCHITECTURE.md's
/// SubmissionOutcome model — success, partial (agency created, user
/// creation failed -> "Retry"), and full failure (agency creation failed
/// -> "Edit and retry"). Each is deliberately unambiguous about what
/// happened and whether the data is safe — the user should never have to
/// guess. All actions here are mocked; nothing about the real Submit API
/// sequencing is decided.
class OutcomeScreen extends StatefulWidget {
  const OutcomeScreen({required this.leadId, super.key});

  final String leadId;

  @override
  State<OutcomeScreen> createState() => _OutcomeScreenState();
}

class _OutcomeScreenState extends State<OutcomeScreen> {
  bool _retrying = false;

  Future<void> _retryUserCreation() async {
    setState(() => _retrying = true);
    await context.read<LeadStoreCubit>().retryUserCreation(widget.leadId);
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeadStoreCubit, List<Lead>>(
      builder: (context, leads) {
        final lead = leads.firstWhere((l) => l.id == widget.leadId);
        return Scaffold(
          appBar: AppBar(
            title: Text(lead.agencyName.isEmpty ? 'Lead' : lead.agencyName),
          ),
          body: switch (lead.status) {
            LeadStatus.created => _SuccessPanel(lead: lead),
            LeadStatus.partial => _PartialPanel(
              lead: lead,
              retrying: _retrying,
              onRetry: _retryUserCreation,
            ),
            LeadStatus.failed => _FailedPanel(lead: lead),
            LeadStatus.pending ||
            LeadStatus.needsReview => const SizedBox.shrink(),
          },
        );
      },
    );
  }
}

class _OutcomeLayout extends StatelessWidget {
  const _OutcomeLayout({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.body,
    required this.primaryAction,
    this.secondaryAction,
    this.idLabel,
    this.idValue,
    this.reassurance,
    this.errorText,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String body;
  final Widget primaryAction;
  final Widget? secondaryAction;
  final String? idLabel;
  final String? idValue;
  final String? reassurance;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.xl,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: iconColor.withValues(alpha: .18),
                        width: 6,
                      ),
                    ),
                    child: Icon(icon, color: iconColor, size: 30),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  title,
                  style: AppTextStyles.displayMd(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  body,
                  style: AppTextStyles.body(color: AppColors.inkSoft),
                  textAlign: TextAlign.center,
                ),
                if (reassurance != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: AppRadius.mdRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          size: 15,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            reassurance!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (idValue != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.mdRadius,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Text(idLabel ?? 'ID', style: AppTextStyles.label()),
                        const Spacer(),
                        Text(
                          idValue!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (errorText != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: AppRadius.mdRadius,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 15,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorText!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              color: AppColors.danger,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        StickyActionBar(
          children: [
            if (secondaryAction != null) ...[
              secondaryAction!,
              const SizedBox(width: AppSpacing.sm + 2),
            ],
            Expanded(child: primaryAction),
          ],
        ),
      ],
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({required this.lead});

  final Lead lead;

  @override
  Widget build(BuildContext context) {
    return _OutcomeLayout(
      icon: Icons.check_rounded,
      iconColor: AppColors.success,
      iconBg: AppColors.successBg,
      title: 'Agency created',
      body:
          '${lead.agencyName} is set up and the welcome email is on its way to ${lead.firstName}.',
      idLabel: 'Agency ID',
      idValue: lead.agencyId,
      secondaryAction: AppButton.ghost(
        label: 'View lead',
        // `go`, not `push` — the capture/review flow got here via
        // pushReplacement at every step, so the stack underneath is stale
        // camera/preview screens, not the Leads tab. `go` resets onto the
        // shell's Leads branch cleanly, matching the "Later" buttons below.
        onPressed: () => context.go('/leads'),
      ),
      primaryAction: AppButton.primary(
        label: 'Scan next card',
        icon: Icons.camera_alt_rounded,
        expand: true,
        onPressed: () => context.go('/capture'),
      ),
    );
  }
}

class _PartialPanel extends StatelessWidget {
  const _PartialPanel({
    required this.lead,
    required this.retrying,
    required this.onRetry,
  });

  final Lead lead;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _OutcomeLayout(
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.warning,
      iconBg: AppColors.warningBg,
      title: 'User invite failed',
      body:
          '${lead.agencyName} was created successfully — only the invite to ${lead.firstName} failed to send.',
      reassurance:
          'Retrying only resends the invite — no duplicate agency will be created.',
      idLabel: 'Agency ID',
      idValue: lead.agencyId,
      errorText: lead.failureReason,
      secondaryAction: AppButton.ghost(
        label: 'Later',
        onPressed: () => context.go('/leads'),
      ),
      primaryAction: AppButton.primary(
        label: retrying ? 'Retrying…' : 'Retry invite',
        icon: retrying ? null : Icons.refresh_rounded,
        loading: retrying,
        expand: true,
        onPressed: retrying ? null : onRetry,
      ),
    );
  }
}

class _FailedPanel extends StatelessWidget {
  const _FailedPanel({required this.lead});

  final Lead lead;

  @override
  Widget build(BuildContext context) {
    return _OutcomeLayout(
      icon: Icons.report_gmailerrorred_rounded,
      iconColor: AppColors.danger,
      iconBg: AppColors.dangerBg,
      title: 'Agency creation failed',
      body: 'The booking engine rejected the request below.',
      reassurance: 'Your card details are safely saved — nothing is lost.',
      errorText: lead.failureReason,
      secondaryAction: AppButton.ghost(
        label: 'Later',
        onPressed: () => context.go('/leads'),
      ),
      primaryAction: AppButton.primary(
        label: 'Edit and retry',
        icon: Icons.edit_outlined,
        expand: true,
        onPressed: () => context.push('/leads/${lead.id}/review'),
      ),
    );
  }
}
