import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/validators.dart';
import 'package:onebytwo/core/widgets/inputs/obt_locked_phone_field.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/domain/selected_contact.dart';

/// Manual phone number entry tab for the add-friend flow (Path B).
///
/// Renders a locked +91 prefix, a phone number text field, and an
/// "Add Friend" button. Validates input with [validateIndianMobile]
/// and fires telemetry events on submission attempts. The visual
/// pattern mirrors the auth `PhoneEntryScreen` layout.
class ManualPhoneEntryTab extends StatefulWidget {
  /// Creates a [ManualPhoneEntryTab].
  const ManualPhoneEntryTab({
    required this.onSubmit,
    required this.analyticsService,
    super.key,
  });

  /// Called when a valid phone number is submitted as a
  /// [SelectedContact] in E.164 format.
  final void Function(SelectedContact contact) onSubmit;

  /// Analytics service for telemetry events.
  final AnalyticsService analyticsService;

  @override
  State<ManualPhoneEntryTab> createState() => _ManualPhoneEntryTabState();
}

class _ManualPhoneEntryTabState extends State<ManualPhoneEntryTab> {
  final _controller = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final digits = _controller.text.trim();
    final error = validateIndianMobile(digits);

    if (error != null) {
      setState(() {
        _validationError = error;
      });
      widget.analyticsService.logEvent(
        name: 'friend_manual_entry_validation_failed',
        parameters: {'error_code': _classifyError(digits)},
      );
      return;
    }

    setState(() {
      _validationError = null;
    });

    widget.analyticsService.logEvent(name: 'friend_manual_entry_submitted');

    final e164 = '+91$digits';
    widget.onSubmit(SelectedContact(displayName: e164, phoneNumbers: [e164]));
  }

  /// Classifies an invalid phone input into a stable analytics
  /// error code (no PII — never includes the digits themselves).
  ///
  /// Codes:
  /// - `empty`             — no characters entered
  /// - `non_numeric`       — contains non-digit characters
  /// - `too_short`         — fewer than 10 digits
  /// - `too_long`          — more than 10 digits (defence-in-depth; the
  ///   input formatter normally caps at 10)
  /// - `invalid_start_digit` — exactly 10 digits but does not start with 6-9
  /// - `invalid_number`    — fallback for any other validator rejection
  String _classifyError(String digits) {
    if (digits.isEmpty) return 'empty';
    if (!RegExp(r'^\d+$').hasMatch(digits)) return 'non_numeric';
    if (digits.length < 10) return 'too_short';
    if (digits.length > 10) return 'too_long';
    if (!RegExp('^[6-9]').hasMatch(digits)) return 'invalid_start_digit';
    return 'invalid_number';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasExactlyTenDigits = _controller.text.length == 10;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Phone input row: locked +91 prefix + text field.
          OBTLockedPhoneField(
            controller: _controller,
            hasError: _validationError != null,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),

          // Validation error text.
          if (_validationError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _validationError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Helper text.
          Text(
            'Enter a 10-digit Indian mobile number.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: OBTColors.metaText(theme),
            ),
          ),

          const SizedBox(height: 24),

          // Add Friend button — full width.
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: hasExactlyTenDigits ? _onSubmit : null,
              child: const Text('Add Friend'),
            ),
          ),
        ],
      ),
    );
  }
}
