import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/result.dart';
import '../../../providers/auth_providers.dart';

/// OTP verification screen
/// 
/// Allows users to enter the 6-digit OTP sent to their phone.
/// Includes resend functionality with a 30-second countdown timer.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    required this.verificationId,
    required this.phoneNumber,
    super.key,
  });

  final String verificationId;
  final String phoneNumber;

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  
  bool _isLoading = false;
  bool _canResend = false;
  int _resendTimer = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendTimer = 30;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  String get _otp => _otpControllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    final otp = _otp;
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter complete OTP'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ref.read(verifyOtpProvider.notifier).verify(
      verificationId: widget.verificationId,
      otp: otp,
    );

    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);

    switch (result) {
      case Success():
        // Navigate to splash — router redirect will evaluate
        // auth + profile state and send to correct destination
        context.go('/splash');
      case Failure(:final exception):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(exception.message),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) {
      return;
    }

    for (final controller in _otpControllers) {
      controller.clear();
    }
    _otpFocusNodes[0].requestFocus();

    final result = await ref.read(sendOtpProvider.notifier).send(widget.phoneNumber);

    if (!mounted) {
      return;
    }

    switch (result) {
      case Success():
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case Failure(:final exception):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(exception.message),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Verify Phone',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Subtitle with phone number
              Text(
                'Code sent to ${widget.phoneNumber}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // OTP Input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    height: 56,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      enabled: !_isLoading,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          // Move to next field
                          _otpFocusNodes[index + 1].requestFocus();
                        }
                        
                        // Auto-submit when all 6 digits are entered
                        if (index == 5 && value.isNotEmpty) {
                          _verifyOtp();
                        }
                      },
                      onTap: () {
                        // Clear the field when tapped
                        _otpControllers[index].clear();
                      },
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 32),
              
              // Resend OTP
              Center(
                child: TextButton(
                  onPressed: _canResend ? _resendOtp : null,
                  child: Text(
                    _canResend
                        ? 'Resend OTP'
                        : 'Resend OTP in $_resendTimer seconds',
                    style: TextStyle(
                      color: _canResend
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Verify button
              FilledButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : const Text(
                        'Verify',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
