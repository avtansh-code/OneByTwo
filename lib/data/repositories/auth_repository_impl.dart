import 'package:one_by_two/core/errors/app_exception.dart';
import 'package:one_by_two/core/errors/failure.dart';
import 'package:one_by_two/data/remote/auth/firebase_auth_source.dart';
import 'package:one_by_two/domain/repositories/auth_repository.dart';

/// Concrete implementation of [AuthRepository] backed by [FirebaseAuthSource].
///
/// Every method wraps the corresponding [FirebaseAuthSource] call in a
/// try/catch block, converting exceptions into [Result.failure] values
/// so that the domain layer never sees raw exceptions.
class AuthRepositoryImpl implements AuthRepository {
  /// Creates an [AuthRepositoryImpl] with the given [FirebaseAuthSource].
  const AuthRepositoryImpl(this._authSource);

  final FirebaseAuthSource _authSource;

  @override
  Stream<String?> authStateChanges() => _authSource.authStateChanges();

  @override
  String? get currentUserId => _authSource.currentUserId;

  @override
  Future<Result<String>> sendOtp(String phoneNumber) async {
    try {
      final verificationId = await _authSource.sendOtp(phoneNumber);
      return Result.success(verificationId);
    } on AuthException catch (e) {
      return Result.failure(e);
    } catch (e, st) {
      return Result.failure(
        UnknownException(e.toString(), originalError: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<String>> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final uid = await _authSource.verifyOtp(
        verificationId: verificationId,
        otp: otp,
      );
      return Result.success(uid);
    } on AuthException catch (e) {
      return Result.failure(e);
    } catch (e, st) {
      return Result.failure(
        UnknownException(e.toString(), originalError: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _authSource.signOut();
      return Result.success(null);
    } on AuthException catch (e) {
      return Result.failure(e);
    } catch (e, st) {
      return Result.failure(
        UnknownException(e.toString(), originalError: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> deleteAccount() async {
    try {
      await _authSource.deleteAccount();
      return Result.success(null);
    } on AuthException catch (e) {
      return Result.failure(e);
    } catch (e, st) {
      return Result.failure(
        UnknownException(e.toString(), originalError: e, stackTrace: st),
      );
    }
  }
}
