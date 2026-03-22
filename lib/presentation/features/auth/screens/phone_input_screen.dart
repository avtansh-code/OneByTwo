import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/validators.dart';
import '../../../providers/auth_providers.dart';

/// Screen that collects the user's Indian phone number and initiates OTP
/// delivery via Firebase Phone Auth.
///
/// This is step 1 of the authentication flow:
///   1. **Phone input** (this screen)
///   2. OTP verification
///   3. Profile setup (for new users)
///
/// The screen displays a non-editable `+91` country code prefix alongside a
/// [TextFormField] that accepts a 10-digit Indian mobile number. The "Send OTP"
/// button is disabled until the number passes [Validators.phone] validation.
///
/// On successful OTP dispatch the screen navigates to
/// [RouteNames.otpVerification], passing the `verificationId` and full E.164
/// phone number via [GoRouterState.extra].
class PhoneInputScreen extends ConsumerStatefulWidget {
  /// Creates a [PhoneInputScreen].
  const PhoneInputScreen({super.key});

  @override
  ConsumerState<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends ConsumerState<PhoneInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  /// Whether the current phone input passes validation.
  bool _isPhoneValid = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController
      ..removeListener(_onPhoneChanged)
      ..dispose();
    super.dispose();
  }

  /// Re-evaluates phone validity on every keystroke.
  void _onPhoneChanged() {
    final isValid = Validators.phone(_phoneController.text) == null;
    if (isValid != _isPhoneValid) {
      setState(() {
        _isPhoneValid = isValid;
      });
    }
  }

  /// Triggers OTP delivery for the entered phone number.
  Future<void> _onSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final phoneDigits = _phoneController.text.trim();
    final fullPhone = '${AppConstants.defaultCountryCode}$phoneDigits';

    await ref.read(sendOtpNotifierProvider.notifier).sendOtp(fullPhone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sendOtpState = ref.watch(sendOtpNotifierProvider);
    final isLoading = sendOtpState.isLoading;

    // Listen for state changes to handle navigation and errors.
    ref.listen<AsyncValue<String?>>(sendOtpNotifierProvider, (previous, next) {
      next.whenOrNull(
        data: (verificationId) {
          if (verificationId == null) return;

          final phoneDigits = _phoneController.text.trim();
          context.goNamed(
            RouteNames.otpVerification,
            extra: {
              'verificationId': verificationId,
              'phone': '${AppConstants.defaultCountryCode}$phoneDigits',
            },
          );
        },
        error: (error, _) {
          final message = _mapErrorToMessage(error, l10n);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(message),
                behavior: SnackBarBehavior.floating,
              ),
            );
        },
      );
    });

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // ── Title ─────────────────────────────────────────────
                Text(
                  l10n.phoneInputTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Subtitle ──────────────────────────────────────────
                Text(
                  l10n.phoneInputSubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Phone input row ───────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Country code prefix (non-editable)
                    _CountryCodeBadge(theme: theme, l10n: l10n),
                    const SizedBox(width: 12),

                    // Phone number field
                    Expanded(
                      child: Semantics(
                        label: l10n.phoneInputHint,
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          autofocus: true,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            hintText: l10n.phoneInputHint,
                            counterText: '',
                          ),
                          validator: (value) => Validators.phone(value),
                          onFieldSubmitted: (_) {
                            if (_isPhoneValid && !isLoading) _onSendOtp();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // ── Send OTP button ───────────────────────────────────
                Semantics(
                  button: true,
                  label: l10n.sendOtp,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isPhoneValid && !isLoading
                          ? _onSendOtp
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : Text(l10n.sendOtp),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Non-editable country code badge displayed inline with the phone input.
///
/// Shows the default Indian country code (`+91`) in a styled container that
/// visually matches the adjacent [TextFormField].
class _CountryCodeBadge extends StatelessWidget {
  const _CountryCodeBadge({required this.theme, required this.l10n});

  /// The current [ThemeData] for styling.
  final ThemeData theme;

  /// The current [AppLocalizations] for the country code string.
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(77),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Text(
        l10n.countryCode,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Maps an error from the send-OTP flow to a localized user-facing message.
///
/// Switches on [AppException.code] for typed errors, falling back to
/// [AppLocalizations.genericError] for unrecognised exceptions.
String _mapErrorToMessage(Object error, AppLocalizations l10n) {
  if (error is AppException) {
    return switch (error.code) {
      'too-many-requests' => l10n.rateLimitExceeded,
      'invalid-phone-number' => l10n.invalidPhone,
      'network-request-failed' => l10n.networkError,
      _ => l10n.authFailed,
    };
  }
  return l10n.genericError;
}
