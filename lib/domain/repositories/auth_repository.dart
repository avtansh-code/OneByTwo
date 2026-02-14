import '../../core/error/result.dart';
import '../entities/user_entity.dart';

/// Repository interface for authentication operations
/// 
/// This interface defines all authentication-related operations.
/// Implementation is in the data layer using Firebase Auth.
abstract class AuthRepository {
  /// Send OTP to phone number
  /// 
  /// [phoneNumber] should be in E.164 format (+91XXXXXXXXXX)
  /// Returns [Result] with verification ID on success
  Future<Result<String>> sendOtp(String phoneNumber);
  
  /// Verify OTP and sign in
  /// 
  /// [verificationId] is received from sendOtp
  /// [otp] is the 6-digit code sent to user's phone
  /// Returns [Result] with [UserEntity] on success, null if new user (needs profile setup)
  Future<Result<UserEntity?>> verifyOtp({
    required String verificationId,
    required String otp,
  });
  
  /// Get current authenticated user
  /// 
  /// Returns null if no user is signed in
  UserEntity? get currentUser;
  
  /// Stream of auth state changes
  /// 
  /// Emits [UserEntity] when user signs in, null when user signs out
  Stream<UserEntity?> get authStateChanges;
  
  /// Sign out current user
  Future<Result<void>> signOut();
  
  /// Delete user account and all associated data (GDPR)
  /// 
  /// This operation:
  /// - Calls Cloud Function to delete all user data from Firestore
  /// - Removes all local data from sqflite database
  /// - Signs out the user
  /// - Deletes Firebase Auth account
  /// 
  /// This is irreversible and complies with GDPR Article 17 (Right to Erasure)
  Future<Result<void>> deleteAccount();
  
  /// Check if user is signed in
  bool get isSignedIn;
}
