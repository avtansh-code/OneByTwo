import 'package:one_by_two/core/errors/failure.dart';

/// Abstract interface for authentication operations.
///
/// Implementations of this repository handle Firebase Auth interactions
/// including phone-based OTP authentication, sign-out, and account deletion.
///
/// All methods that can fail return [Result<T>] rather than throwing
/// exceptions, enabling type-safe error handling at the call site.
abstract class AuthRepository {
  /// Stream of auth state changes.
  ///
  /// Emits the user's UID ([String]) when signed in, or `null` when
  /// signed out. The stream fires immediately with the current auth state
  /// upon subscription and then on every subsequent change.
  Stream<String?> authStateChanges();

  /// Returns the currently signed-in user's UID, or `null` if no user
  /// is authenticated.
  String? get currentUserId;

  /// Sends an OTP to the given [phoneNumber].
  ///
  /// [phoneNumber] must be in E.164 format (e.g., `+91XXXXXXXXXX`).
  ///
  /// Returns a [Result] containing:
  /// - [Success<String>] with the verification ID on success.
  /// - [Failure] with an [AuthException] or [NetworkException] on failure.
  Future<Result<String>> sendOtp(String phoneNumber);

  /// Verifies the [otp] against the given [verificationId].
  ///
  /// [verificationId] is the ID returned by [sendOtp].
  /// [otp] must be exactly 6 digits.
  ///
  /// Returns a [Result] containing:
  /// - [Success<String>] with the authenticated user's UID on success.
  /// - [Failure] with an [AuthException] if the OTP is invalid or expired.
  Future<Result<String>> verifyOtp({
    required String verificationId,
    required String otp,
  });

  /// Signs out the currently authenticated user.
  ///
  /// Returns a [Result] containing:
  /// - [Success<void>] on success.
  /// - [Failure] with an [AuthException] if sign-out fails.
  Future<Result<void>> signOut();

  /// Permanently deletes the current user's Firebase Auth account.
  ///
  /// This is an irreversible operation. The user's Firestore data should
  /// be soft-deleted separately before calling this method.
  ///
  /// Returns a [Result] containing:
  /// - [Success<void>] on success.
  /// - [Failure] with an [AuthException] if deletion fails (e.g.,
  ///   re-authentication required).
  Future<Result<void>> deleteAccount();
}
