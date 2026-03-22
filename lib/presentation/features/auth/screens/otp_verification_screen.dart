import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/router/route_paths.dart';
import '../../../providers/auth_providers.dart';

/// Screen for OTP verification (auth step 2).
///
/// Receives `verificationId` and `phone` via [GoRouterState.extra].
/// The user enters the 6-digit OTP code, which is verified against Firebase
/// Auth. On success, the screen checks whether a user profile already exists
/// in Firestore and navigates accordingly:
/// - Profile exists → Home screen.
/// - Profile missing → Profile Setup screen.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  /// Creates an [OtpVerificationScreen].
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  /// Controller for the OTP pin input field.
  final _pinController = TextEditingController();

  /// Focus node for the OTP pin input field.
  final _pinFocusNode = FocusNode();

  /// Remaining seconds before the resend button becomes active.
  int _resendSeconds = AppConstants.otpResendDelaySeconds;

  /// Periodic timer that drives the resend countdown display.
  Timer? _resendTimer;

  /// Whether the OTP has reached 6 digits and is ready to verify.
  bool _isOtpComplete = false;

  /// The current verification ID used for OTP verification.
  ///
  /// Initialized from route params on first build, then updated on
  /// successful OTP resend so that verification always uses the latest ID.
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _pinController.addListener(_onPinChanged);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _pinController
      ..removeListener(_onPinChanged)
      ..dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  /// Starts (or restarts) the countdown timer for the resend button.
  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendSeconds = AppConstants.otpResendDelaySeconds;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _resendSeconds = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _resendSeconds--;
          });
        }
      }
    });
  }

  /// Listener for pin input changes – updates the [_isOtpComplete] flag.
  void _onPinChanged() {
    final complete = _pinController.text.length == AppConstants.otpLength;
    if (complete != _isOtpComplete) {
      setState(() {
        _isOtpComplete = complete;
      });
    }
  }

  /// Masks the phone number so that the middle digits are hidden.
  ///
  /// Example: "+919876543210" → "+91 •••••• 3210".
  String _maskPhone(String phone) {
    if (phone.length < 4) return phone;
    final last4 = phone.substring(phone.length - 4);
    final prefix = phone.length >= 7
        ? phone.substring(0, phone.length - 10)
        : '';
    return '$prefix •••••• $last4';
  }

  /// Extracts route parameters from [GoRouterState.extra].
  ({String verificationId, String phone}) _extractParams() {
    final extra = GoRouterState.of(context).extra as Map<String, String>? ?? {};
    return (
      verificationId: extra['verificationId'] ?? '',
      phone: extra['phone'] ?? '',
    );
  }

  /// Submits the OTP for verification.
  Future<void> _verifyOtp(String verificationId) async {
    final otp = _pinController.text;
    if (otp.length != AppConstants.otpLength) return;

    await ref
        .read(verifyOtpNotifierProvider.notifier)
        .verifyOtp(verificationId: verificationId, otp: otp);
  }

  /// Resends the OTP by re-triggering the send OTP flow with the same phone.
  Future<void> _resendOtp(String phone) async {
    _startResendTimer();
    await ref.read(sendOtpNotifierProvider.notifier).sendOtp(phone);
  }

  /// Handles a successful OTP verification by checking user existence
  /// and navigating to the appropriate screen.
  Future<void> _onVerificationSuccess(String uid, String phone) async {
    if (!mounted) return;

    final exists = await ref.read(userExistsProvider(uid).future);
    if (!mounted) return;

    if (exists) {
      context.go(RoutePaths.home);
    } else {
      context.goNamed(
        RouteNames.profileSetup,
        extra: {'uid': uid, 'phone': phone},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final params = _extractParams();
    // Fix: Initialize verificationId from route params on first build.
    // After OTP resend, _verificationId is updated by the
    // sendOtpNotifierProvider listener below, so we always verify
    // against the latest (valid) verificationId from Firebase.
    _verificationId ??= params.verificationId;
    final maskedPhone = _maskPhone(params.phone);

    // Listen for verification state changes.
    ref.listen<AsyncValue<String?>>(verifyOtpNotifierProvider, (
      previous,
      next,
    ) {
      next.whenOrNull(
        data: (uid) {
          if (uid != null) {
            _onVerificationSuccess(uid, params.phone);
          }
        },
        error: (error, _) {
          // Clear input so the user can retry.
          _pinController.clear();
          _pinFocusNode.requestFocus();

          final message = switch (error) {
            final Exception e when e.toString().contains('invalid') =>
              l10n.invalidOtp,
            final Exception e when e.toString().contains('expired') =>
              l10n.otpExpired,
            _ => l10n.genericError,
          };

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

    // Listen for resend OTP state changes (update verificationId via
    // sendOtpNotifierProvider if resend succeeds).
    ref.listen<AsyncValue<String?>>(sendOtpNotifierProvider, (previous, next) {
      next.whenOrNull(
        data: (newVerificationId) {
          // Fix: Capture the new verificationId so subsequent verification
          // attempts use the fresh ID instead of the stale one from route
          // params. Also restart the resend timer from the moment the new
          // OTP was actually sent.
          if (newVerificationId != null) {
            setState(() => _verificationId = newVerificationId);
            _startResendTimer();
          }
        },
        error: (error, _) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(l10n.genericError),
                behavior: SnackBarBehavior.floating,
              ),
            );
        },
      );
    });

    final verifyState = ref.watch(verifyOtpNotifierProvider);
    final isLoading = verifyState is AsyncLoading;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // ── Title ────────────────────────────────────────────
              Text(
                l10n.otpVerificationTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // ── Subtitle with masked phone ───────────────────────
              Text(
                l10n.otpVerificationSubtitle(maskedPhone),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // ── OTP Input ────────────────────────────────────────
              Semantics(
                label: l10n.otpVerificationTitle,
                child: _buildPinInput(theme, isLoading, _verificationId!),
              ),
              const SizedBox(height: 32),

              // ── Verify Button ────────────────────────────────────
              Semantics(
                button: true,
                label: l10n.verifyOtp,
                child: FilledButton(
                  onPressed: _isOtpComplete && !isLoading
                      ? () => _verifyOtp(_verificationId!)
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
                        : Text(l10n.verifyOtp),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Resend Timer / Button ────────────────────────────
              Center(
                child: _resendSeconds > 0
                    ? Text(
                        l10n.resendCodeIn(_resendSeconds),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Semantics(
                        button: true,
                        label: l10n.resendCode,
                        child: TextButton(
                          onPressed: () => _resendOtp(params.phone),
                          child: Text(l10n.resendCode),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the 6-digit [Pinput] widget styled to match the app theme.
  Widget _buildPinInput(
    ThemeData theme,
    bool isLoading,
    String verificationId,
  ) {
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        border: Border.all(color: theme.colorScheme.primary, width: 2),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        border: Border.all(color: theme.colorScheme.primary),
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        border: Border.all(color: theme.colorScheme.error),
      ),
    );

    return Pinput(
      length: AppConstants.otpLength,
      controller: _pinController,
      focusNode: _pinFocusNode,
      autofocus: true,
      enabled: !isLoading,
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: focusedPinTheme,
      submittedPinTheme: submittedPinTheme,
      errorPinTheme: errorPinTheme,
      keyboardType: TextInputType.number,
      onCompleted: (_) => _verifyOtp(verificationId),
      pinAnimationType: PinAnimationType.fade,
      animationDuration: const Duration(milliseconds: 200),
    );
  }
}
