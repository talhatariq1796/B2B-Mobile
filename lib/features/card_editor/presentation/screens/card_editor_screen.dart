import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/card_image_view.dart';
import '../../../../core/widgets/image_preview_viewer.dart';
import '../../../../core/widgets/info_banner.dart';
import '../../../../core/widgets/review_field.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/sticky_action_bar.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../leads/domain/entities/lead.dart';
import '../../../leads/presentation/cubit/lead_store_cubit.dart';

/// A verification workflow, not a generic form: the card image stays
/// visible while reviewing, fields are grouped so the eye can scan by
/// category, anything flagged is called out up front, and the primary
/// action stays pinned rather than scrolling out of reach. Makes the
/// "OCR did the work → you verify/correct → you submit" sequence visible
/// rather than implicit.
///
/// "Create agency" saves corrections (PATCH) then submits (POST .../submit/)
/// — both real backend calls, see LeadStoreCubit.
class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({required this.leadId, super.key});

  final String leadId;

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
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

  bool _extracting = false;
  bool _submitting = false;
  bool _emailFlagged = false;
  bool _needsLogin = false;
  String? _extractionError;

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
    _emailFlagged = lead.emailLowConfidence;

    if (lead.status == LeadStatus.pending) {
      // Extraction hits the real backend (creates a Lead server-side) —
      // guests never make backend calls, per the capture screen's promise
      // that "nothing is submitted until you log in." Without this check,
      // extraction would silently succeed if a stale token happened to
      // still be in secure storage, then fail confusingly later at
      // save/submit once that token expired.
      if (context.read<AuthCubit>().state) {
        _runExtraction();
      } else {
        _needsLogin = true;
      }
    }
  }

  Future<void> _goToLogin() async {
    await context.push('/login');
    if (!mounted) return;
    if (context.read<AuthCubit>().state) {
      setState(() => _needsLogin = false);
      _runExtraction();
    }
  }

  void _runExtraction() {
    setState(() {
      _extracting = true;
      _extractionError = null;
    });
    context.read<LeadStoreCubit>().extract(widget.leadId).then((extracted) {
      if (!mounted) return;
      // Still `pending` means extract() failed and reverted the status —
      // see LeadStoreCubit.extract().
      if (extracted.status == LeadStatus.pending) {
        setState(() {
          _extracting = false;
          _extractionError = extracted.lastExtractionError ?? 'Something went wrong.';
        });
        return;
      }
      setState(() {
        _extracting = false;
        _agency.text = extracted.agencyName;
        _country.text = extracted.country;
        _firstName.text = extracted.firstName;
        _lastName.text = extracted.lastName;
        _email.text = extracted.email;
        _mobilePhone.text = extracted.mobilePhone;
        _mobilePhone2.text = extracted.mobilePhone2;
        _landlinePhone.text = extracted.landlinePhone;
        _landlinePhone2.text = extracted.landlinePhone2;
        _faxPhone.text = extracted.faxPhone;
        _agencyWebsite.text = extracted.agencyWebsite;
        _address.text = extracted.address;
        _emailFlagged = extracted.emailLowConfidence;
      });
    });
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

  Future<void> _createAgency() async {
    setState(() => _submitting = true);
    final store = context.read<LeadStoreCubit>();
    final saveError = await store.updateFields(
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
    if (saveError != null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Couldn't save your changes: $saveError")));
      return;
    }
    await store.createAgency(widget.leadId);
    if (!mounted) return;
    context.pushReplacement('/leads/${widget.leadId}/outcome');
  }

  @override
  Widget build(BuildContext context) {
    final flaggedCount = _emailFlagged ? 1 : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Review & correct')),
      body: _needsLogin
          ? _SignInRequiredView(onLogIn: _goToLogin)
          : _extracting
          ? const _ExtractingView()
          : _extractionError != null
          ? _ExtractionErrorView(message: _extractionError!, onRetry: _runExtraction)
          : Column(
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
                        _Thumbnail(
                          onRetake: () => context.pop(),
                          imagePath: _lead.imagePath,
                          remoteUrl: _lead.remoteImageUrl,
                        ),
                        if (_lead.backImagePath != null || _lead.remoteBackImageUrl != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          _Thumbnail(
                            onRetake: () => context.pop(),
                            imagePath: _lead.backImagePath,
                            remoteUrl: _lead.remoteBackImageUrl,
                            label: 'Back of card',
                          ),
                        ],
                        if (flaggedCount > 0) ...[
                          const SizedBox(height: AppSpacing.lg),
                          InfoBanner(
                            icon: Icons.error_outline_rounded,
                            tone: BannerTone.warning,
                            message:
                                '$flaggedCount field${flaggedCount == 1 ? '' : 's'} need${flaggedCount == 1 ? 's' : ''} your review before submitting.',
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
                          flagNote: _emailFlagged
                              ? 'Low confidence — double check this address'
                              : null,
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
                      label: 'Later',
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    AppButton.primary(
                      label: 'Create agency',
                      icon: _submitting ? null : Icons.arrow_forward_rounded,
                      loading: _submitting,
                      onPressed: _submitting ? null : _createAgency,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _ExtractingView extends StatelessWidget {
  const _ExtractingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.primary,
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primaryDim,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Extracting card details…', style: AppTextStyles.titleSm()),
          const SizedBox(height: 4),
          Text(
            'This usually takes a few seconds',
            style: AppTextStyles.bodySm(),
          ),
        ],
      ),
    );
  }
}

class _ExtractionErrorView extends StatelessWidget {
  const _ExtractionErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.dangerBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 24,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text("Couldn't extract this card", style: AppTextStyles.titleSm()),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm(),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton.primary(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInRequiredView extends StatelessWidget {
  const _SignInRequiredView({required this.onLogIn});

  final VoidCallback onLogIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.primaryDim,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 24,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Sign in to extract this card', style: AppTextStyles.titleSm()),
            const SizedBox(height: 6),
            Text(
              "Your photo is saved safely on this device. Sign in and we'll "
              "pick up the extraction from there.",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm(),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton.primary(
              label: 'Log in',
              icon: Icons.arrow_forward_rounded,
              onPressed: onLogIn,
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.onRetake,
    this.imagePath,
    this.remoteUrl,
    this.label = 'AI extracted',
  });

  final VoidCallback onRetake;
  final String? imagePath;
  final String? remoteUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: (imagePath == null && remoteUrl == null)
                ? null
                : () => openImagePreview(context, localPath: imagePath, remoteUrl: remoteUrl),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primaryDim,
                borderRadius: AppRadius.lgRadius,
                boxShadow: AppShadows.card,
              ),
              clipBehavior: Clip.antiAlias,
              child: CardImageView(
                localPath: imagePath,
                remoteUrl: remoteUrl,
                fit: BoxFit.contain,
                placeholder: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.badge_outlined, size: 26, color: AppColors.primary),
                    SizedBox(height: 6),
                    Text(
                      'Captured card',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.sm + 2,
            top: AppSpacing.sm + 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .55),
                borderRadius: AppRadius.pillRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 11,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: AppTextStyles.caption(
                      color: Colors.white,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: AppSpacing.sm + 2,
            top: AppSpacing.sm + 2,
            child: Material(
              color: Colors.black.withValues(alpha: .55),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onRetake,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
