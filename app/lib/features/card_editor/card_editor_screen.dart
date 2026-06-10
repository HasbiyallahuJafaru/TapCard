/// Card editor screen — the form where the user creates or edits their contact card.
/// Shows six fields (name, phone, email, company, job title, note) and a live
/// URL-length progress bar. Saves to Hive via CardRepository on submit.
/// Visual spec: UI_DIRECTION.md §Card Editor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colours.dart';
import '../../core/constants.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../core/url_codec.dart';
import '../../core/vcard_builder.dart';
import '../../core/widgets/pressable_widget.dart';
import '../../core/providers/card_repository_provider.dart';
import '../../data/models/contact_card.dart';

/// Card editor screen.
///
/// Pre-fills fields from the existing saved card when one is present.
/// The URL length indicator shows live character count vs the 1200-char limit,
/// computed from the current field values using [VCardBuilder] + [UrlCodec].
class CardEditorScreen extends ConsumerStatefulWidget {
  const CardEditorScreen({super.key});

  @override
  ConsumerState<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends ConsumerState<CardEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers — one per field, in field order.
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;

  int _encodedLength = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(contactCardProvider);
    _nameCtrl    = TextEditingController(text: existing?.fullName ?? '');
    _phoneCtrl   = TextEditingController(text: existing?.cellPhone ?? '');
    _emailCtrl   = TextEditingController(text: existing?.email ?? '');
    _companyCtrl = TextEditingController(text: existing?.company ?? '');
    _titleCtrl   = TextEditingController(text: existing?.jobTitle ?? '');
    _noteCtrl    = TextEditingController(text: existing?.note ?? '');

    // Start listening for live URL length updates.
    for (final c in [_nameCtrl, _phoneCtrl, _emailCtrl, _companyCtrl, _titleCtrl, _noteCtrl]) {
      c.addListener(_updateLength);
    }
    _updateLength();
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _emailCtrl, _companyCtrl, _titleCtrl, _noteCtrl]) {
      c.removeListener(_updateLength);
      c.dispose();
    }
    super.dispose();
  }

  // Recomputes the encoded URL length whenever any field changes.
  void _updateLength() {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() => _encodedLength = 0);
      return;
    }
    final card = _buildCard();
    try {
      final vCard = VCardBuilder.build(card);
      setState(() => _encodedLength = UrlCodec.computeUrlLength(vCard));
    } catch (_) {
      setState(() => _encodedLength = 0);
    }
  }

  ContactCard _buildCard() {
    return ContactCard(
      fullName:  _nameCtrl.text.trim(),
      cellPhone: _phoneCtrl.text.trim(),
      email:     _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      company:   _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
      jobTitle:  _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
      note:      _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(cardRepositoryProvider).save(_buildCard());
      // Invalidate the contactCardProvider so the share screen reads fresh data.
      ref.invalidate(contactCardProvider);
      if (mounted) context.go(AppConstants.routeShare);
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool overLimit = _encodedLength > AppConstants.maxUrlLength;
    final double progress = _encodedLength == 0
        ? 0
        : (_encodedLength / AppConstants.maxUrlLength).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColours.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTokens.lg, AppTokens.lg, AppTokens.lg, 0),
              child: Row(
                children: [
                  Text('Your Card', style: AppTypography.title(size: 24))
                      .animate()
                      .fadeIn(duration: AppTokens.entrance, curve: AppTokens.entrance_),
                ],
              ),
            ),

            const SizedBox(height: AppTokens.md),

            // ── Scrollable fields ─────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _Field(
                        controller: _nameCtrl,
                        label: 'Full Name',
                        required: true,
                        textInputAction: TextInputAction.next,
                        delay: 0,
                      ),
                      _Field(
                        controller: _phoneCtrl,
                        label: 'Phone',
                        required: true,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        delay: 40,
                      ),
                      _Field(
                        controller: _emailCtrl,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        delay: 80,
                      ),
                      _Field(
                        controller: _companyCtrl,
                        label: 'Company',
                        textInputAction: TextInputAction.next,
                        delay: 120,
                      ),
                      _Field(
                        controller: _titleCtrl,
                        label: 'Job Title',
                        textInputAction: TextInputAction.next,
                        delay: 160,
                      ),
                      _Field(
                        controller: _noteCtrl,
                        label: 'Note',
                        textInputAction: TextInputAction.done,
                        maxLines: 3,
                        delay: 200,
                      ),
                      const SizedBox(height: AppTokens.xl),
                    ],
                  ),
                ),
              ),
            ),

            // ── URL length indicator ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColours.bgTertiary,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        overLimit ? AppColours.error : AppColours.success,
                      ),
                      minHeight: 3,
                    ),
                  ),
                  const SizedBox(height: AppTokens.xs),
                  Text(
                    '$_encodedLength / ${AppConstants.maxUrlLength}',
                    style: AppTypography.mono(size: 11)
                        .copyWith(color: overLimit ? AppColours.error : AppColours.textTertiary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTokens.md),

            // ── Save button ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppTokens.lg, 0, AppTokens.lg, AppTokens.xxl),
              child: PressableWidget(
                onTap: _saving ? () {} : _save,
                enabled: !_saving && !overLimit,
                child: Container(
                  width: double.infinity,
                  height: AppTokens.minTouchTarget + 4,
                  decoration: BoxDecoration(
                    color: AppColours.bgTertiary,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  alignment: Alignment.center,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColours.textTertiary,
                          ),
                        )
                      : Text('Save Card', style: AppTypography.bodyMedium(size: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Field — styled TextFormField with floating label
// ---------------------------------------------------------------------------

/// A single form field matching the CardEditor visual spec.
///
/// [bgTertiary] fill, no border in idle state, 1dp accent underline on focus.
/// Required fields show a small dot indicator.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.required = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    required this.delay,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.md),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLines: maxLines,
        style: AppTypography.bodyMedium(size: 15),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
        decoration: InputDecoration(
          labelText: required ? '$label ·' : label,
          labelStyle: AppTypography.label(size: 11, uppercase: false)
              .copyWith(color: AppColours.textTertiary),
          floatingLabelStyle: AppTypography.label(size: 11, uppercase: false)
              .copyWith(color: AppColours.textSecondary),
          filled: true,
          fillColor: AppColours.bgTertiary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            borderSide: const BorderSide(color: AppColours.accent, width: 1),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            borderSide: const BorderSide(color: AppColours.error, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            borderSide: const BorderSide(color: AppColours.error, width: 1),
          ),
          errorStyle: AppTypography.label(size: 10, uppercase: false)
              .copyWith(color: AppColours.error),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTokens.md, vertical: AppTokens.md),
        ),
      )
          .animate(delay: Duration(milliseconds: delay))
          .fadeIn(duration: AppTokens.entrance, curve: AppTokens.entrance_)
          .slideY(begin: 12 / 15, end: 0, duration: AppTokens.entrance, curve: AppTokens.entrance_),
    );
  }
}
