import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/application/phone_entry_controller.dart';
import 'package:onebytwo/features/auth/presentation/widgets/india_phone_input_formatter.dart';

/// Phone number entry screen for FR-AU-01.
///
/// Collects a 10-digit Indian mobile number. The +91 country code is
/// displayed as a non-editable prefix widget. Validation occurs on
/// Continue tap; the button is passively disabled until 10 digits are
/// entered.
class PhoneEntryScreen extends ConsumerWidget {
  /// Creates the phone entry screen.
  const PhoneEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(phoneEntryControllerProvider);
    final controller = ref.read(phoneEntryControllerProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasExactlyTenDigits = state.phoneNumber.length == 10;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // Heading.
              Text(
                'Enter your mobile number',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle.
              Text(
                "We'll send you a 6-digit code to verify.",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),

              // Phone input row.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Locked +91 prefix.
                  Semantics(
                    label: 'Country code, India, plus 91',
                    excludeSemantics: true,
                    child: Container(
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
                  ),

                  // Phone number text field.
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: TextField(
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
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          IndianPhoneInputFormatter(),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: controller.updatePhoneNumber,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                ],
              ),

              // Error text.
              if (state.validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    state.validationError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),

              const Spacer(),

              // Continue button.
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: hasExactlyTenDigits ? controller.submit : null,
                  child: const Text('Continue'),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
