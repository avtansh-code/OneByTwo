import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onebytwo/core/validators.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/presentation/widgets/india_phone_input_formatter.dart';
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
    this.currentUserPhone,
    super.key,
  });

  /// Called when a valid phone number is submitted as a
  /// [SelectedContact] in E.164 format.
  final void Function(SelectedContact contact) onSubmit;

  /// Analytics service for telemetry events.
  final AnalyticsService analyticsService;

  /// The current user's phone number, used for self-add detection.
  final String? currentUserPhone;

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
        parameters: {'error_code': 'invalid_number'},
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Locked +91 prefix container.
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  border: Border.all(color: colorScheme.outline),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+91',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),

              // Phone number text field.
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      IndianPhoneInputFormatter(),
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Enter mobile number',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
            ],
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
              color: colorScheme.onSurface.withValues(alpha: 0.6),
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
