import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/core/errors/failure.dart';

import '../../repositories/auth_repository.dart';

/// Use case for verifying an OTP and completing phone authentication.
///
/// Validates that the OTP is exactly 6 digits before delegating to the
/// [AuthRepository]. Returns the authenticated user's UID on success.
///
/// ## Validation
/// The OTP must consist of exactly 6 numeric digits (0–9).
///
/// ## Example
/// ```dart
/// final result = await verifyOtpUseCase(
///   verificationId: verificationId,
///   otp: '123456',
/// );
/// result.when(
///   success: (uid) => navigateToHome(uid),
///   failure: (exception) => showError(exception.message),
/// );
/// ```
class VerifyOtpUseCase {
  /// Creates a [VerifyOtpUseCase] with the given [_authRepository].
  const VerifyOtpUseCase(this._authRepository);

  final AuthRepository _authRepository;

  /// Pattern matching exactly 6 digits.
  static final _otpRegex = RegExp(r'^\d{6}$');

  /// Verifies the [otp] against the given [verificationId].
  ///
  /// [verificationId] is the ID returned by [SendOtpUseCase].
  /// [otp] must be exactly 6 numeric digits.
  ///
  /// Returns:
  /// - [Success<String>] with the authenticated user's UID.
  /// - [Failure] with a [ValidationException] if the OTP format is invalid.
  /// - [Failure] with an [AuthException] if verification fails.
  Future<Result<String>> call({
    required String verificationId,
    required String otp,
  }) async {
    if (verificationId.isEmpty) {
      return Result.failure(
        const ValidationException(
          'Verification ID cannot be empty',
          code: 'empty-verification-id',
        ),
      );
    }

    if (!_otpRegex.hasMatch(otp)) {
      return Result.failure(
        const ValidationException(
          'OTP must be exactly 6 digits',
          code: 'invalid-otp',
        ),
      );
    }

    return _authRepository.verifyOtp(verificationId: verificationId, otp: otp);
  }
}
