import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/card_image_view.dart';
import '../../../../core/widgets/image_preview_viewer.dart';
import '../../../../core/widgets/review_field.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../../core/widgets/sticky_action_bar.dart';
import '../../../leads/domain/entities/lead.dart';
import '../../../leads/presentation/cubit/lead_store_cubit.dart';

/// The persistent record for a lead that already has a backend outcome
/// (created/partial/failed) — reachable from "View lead" on the Success
/// outcome, or by tapping a "Created" row in the Leads list. Unlike
/// CardEditorScreen (the fresh capture -> review -> Create agency flow),
/// this is a plain view/edit screen: every field the lead has is visible
/// and editable, with a "Save changes" action instead of "Create agency" —
/// no re-submission implied.
class LeadDetailScreen extends StatefulWidget {
  const LeadDetailScreen({required this.leadId, super.key});

  final String leadId;

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  late final TextEditingController _agency;
  late final TextEditingController _country;
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _mobilePhone;
  late final TextEditingController _mobilePhone2;
  late final TextEditingController _landlinePhone;
  late final TextEditingController _landlinePhone2;
  late final TextEditingController _faxPhone;
  late final TextEditingController _agencyWebsite;
  late final TextEditingController _address;

  bool _saving = false;

  Lead get _lead => context.read<LeadStoreCubit>().byId(widget.leadId);

  @override
  void initState() {
    super.initState();
    final lead = _lead;
    _agency = TextEditingController(text: lead.agencyName);
    _country = TextEditingController(text: lead.country);
    _firstName = TextEditingController(text: lead.firstName);
    _lastName = TextEditingController(text: lead.lastName);
    _email = TextEditingController(text: lead.email);
    _mobilePhone = TextEditingController(text: lead.mobilePhone);
    _mobilePhone2 = TextEditingController(text: lead.mobilePhone2);
    _landlinePhone = TextEditingController(text: lead.landlinePhone);
    _landlinePhone2 = TextEditingController(text: lead.landlinePhone2);
    _faxPhone = TextEditingController(text: lead.faxPhone);
    _agencyWebsite = TextEditingController(text: lead.agencyWebsite);
    _address = TextEditingController(text: lead.address);
  }

  @override
  void dispose() {
    _agency.dispose();
    _country.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _mobilePhone.dispose();
    _mobilePhone2.dispose();
    _landlinePhone.dispose();
    _landlinePhone2.dispose();
    _faxPhone.dispose();
    _agencyWebsite.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);
    final error = await context.read<LeadStoreCubit>().updateFields(
      widget.leadId,
      _lead.copyWith(
        agencyName: _agency.text,
        country: _country.text,
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        mobilePhone: _mobilePhone.text,
        mobilePhone2: _mobilePhone2.text,
        landlinePhone: _landlinePhone.text,
        landlinePhone2: _landlinePhone2.text,
        faxPhone: _faxPhone.text,
        agencyWebsite: _agencyWebsite.text,
        address: _address.text,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error != null ? "Couldn't save changes: $error" : 'Changes saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeadStoreCubit, List<Lead>>(
      builder: (context, leads) {
        final lead = leads.firstWhere((l) => l.id == widget.leadId);
        final time = TimeOfDay.fromDateTime(lead.capturedAt).format(context);

        return Scaffold(
          appBar: AppBar(
            title: Text(lead.agencyName.isEmpty ? 'Lead' : lead.agencyName),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _Avatar(imagePath: lead.imagePath, remoteUrl: lead.remoteImageUrl),
                          if (lead.backImagePath != null || lead.remoteBackImageUrl != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            _Avatar(
                              imagePath: lead.backImagePath,
                              remoteUrl: lead.remoteBackImageUrl,
                            ),
                          ],
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StatusPill(
                                  label: lead.status.label,
                                  tone: lead.status.tone,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Captured $time',
                                  style: AppTextStyles.bodySm(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (lead.agencyId != null) ...[
                        const SizedBox(height: AppSpacing.lg),
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
                              Text('Agency ID', style: AppTextStyles.label()),
                              const Spacer(),
                              Text(
                                lead.agencyId!,
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
                      const SizedBox(height: AppSpacing.xxl),
                      const SectionHeader(title: 'Contact'),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: ReviewField(
                              label: 'First name',
                              controller: _firstName,
                              icon: Icons.person_outline_rounded,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: ReviewField(
                              label: 'Last name',
                              controller: _lastName,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ReviewField(
                        label: 'Email',
                        controller: _email,
                        icon: Icons.mail_outline_rounded,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: ReviewField(
                              label: 'Mobile phone',
                              controller: _mobilePhone,
                              icon: Icons.call_outlined,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: ReviewField(
                              label: 'Mobile phone 2',
                              controller: _mobilePhone2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: ReviewField(
                              label: 'Landline',
                              controller: _landlinePhone,
                              icon: Icons.phone_outlined,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: ReviewField(
                              label: 'Landline 2',
                              controller: _landlinePhone2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ReviewField(
                        label: 'Fax',
                        controller: _faxPhone,
                        icon: Icons.print_outlined,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      const SectionHeader(title: 'Agency'),
                      const SizedBox(height: AppSpacing.md),
                      ReviewField(
                        label: 'Agency name',
                        controller: _agency,
                        icon: Icons.apartment_rounded,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ReviewField(
                        label: 'Country',
                        controller: _country,
                        icon: Icons.public_rounded,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ReviewField(
                        label: 'Website',
                        controller: _agencyWebsite,
                        icon: Icons.language_rounded,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      const SectionHeader(title: 'Address'),
                      const SizedBox(height: AppSpacing.md),
                      ReviewField(
                        label: 'Street address',
                        controller: _address,
                        icon: Icons.place_outlined,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              StickyActionBar(
                children: [
                  AppButton.ghost(
                    label: 'Close',
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: AppButton.primary(
                      label: 'Save changes',
                      loading: _saving,
                      expand: true,
                      onPressed: _saving ? null : _saveChanges,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.imagePath, this.remoteUrl});

  final String? imagePath;
  final String? remoteUrl;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (imagePath == null && remoteUrl == null)
          ? null
          : () => openImagePreview(context, localPath: imagePath, remoteUrl: remoteUrl),
      child: ClipRRect(
        borderRadius: AppRadius.mdRadius,
        child: Container(
          width: 56,
          height: 56,
          color: AppColors.primaryDim,
          child: CardImageView(
            localPath: imagePath,
            remoteUrl: remoteUrl,
            fit: BoxFit.cover,
            placeholder: const Icon(
              Icons.apartment_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
