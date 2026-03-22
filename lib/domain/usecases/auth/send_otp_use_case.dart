import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/core/errors/failure.dart';

import '../../repositories/auth_repository.dart';

/// Use case for sending an OTP to a phone number.
///
/// Validates the phone number format before delegating to the
/// [AuthRepository]. Returns a verification ID on success.
///
/// ## Validation
/// The phone number must be in E.164 format for Indian numbers:
/// `+91` followed by exactly 10 digits starting with 6–9.
///
/// ## Example
/// ```dart
/// final result = await sendOtpUseCase('+919876543210');
/// result.when(
///   success: (verificationId) => navigateToOtpScreen(verificationId),
///   failure: (exception) => showError(exception.message),
/// );
/// ```
class SendOtpUseCase {
  /// Creates a [SendOtpUseCase] with the given [_authRepository].
  const SendOtpUseCase(this._authRepository);

  final AuthRepository _authRepository;

  /// Indian E.164 phone number pattern: +91 followed by 10 digits
  /// starting with 6, 7, 8, or 9.
  static final _indianPhoneRegex = RegExp(r'^\+91[6-9]\d{9}$');

  /// Sends an OTP to [phoneNumber] after validating its format.
  ///
  /// [phoneNumber] must be in E.164 format (e.g., `+919876543210`).
  ///
  /// Returns:
  /// - [Success<String>] with the verification ID from Firebase Auth.
  /// - [Failure] with a [ValidationException] if the phone number is invalid.
  /// - [Failure] with an [AuthException] or [NetworkException] if sending fails.
  Future<Result<String>> call(String phoneNumber) async {
    if (!_indianPhoneRegex.hasMatch(phoneNumber)) {
      return Result.failure(
        const ValidationException(
          'Invalid phone number. Expected format: +91XXXXXXXXXX',
          code: 'invalid-phone-number',
        ),
      );
    }

    return _authRepository.sendOtp(phoneNumber);
  }
}
