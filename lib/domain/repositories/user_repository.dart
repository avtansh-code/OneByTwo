import '../../core/error/result.dart';
import '../entities/user_entity.dart';

/// Repository interface for user profile operations
/// 
/// This interface defines all user profile-related operations.
/// Implementation is in the data layer using Firestore and local sqflite.
abstract class UserRepository {
  /// Create user profile
  /// 
  /// Creates profile in both Firestore and local DB.
  /// Uses Firebase Auth currentUser for uid and phone.
  /// 
  /// Returns [Result] with created [UserEntity] on success
  Future<Result<UserEntity>> createProfile({
    required String name,
    required String email,
    String? avatarUrl,
  });

  /// Update user profile
  /// 
  /// Updates profile in both Firestore and local DB.
  /// All parameters are optional - only provided fields will be updated.
  /// 
  /// Returns [Result] with updated [UserEntity] on success
  Future<Result<UserEntity>> updateProfile({
    String? name,
    String? email,
    String? avatarUrl,
  });

  /// Get user profile by ID
  /// 
  /// Fetches from local DB first, falls back to Firestore if not found.
  /// 
  /// Returns [Result] with [UserEntity] if found, null if not found
  Future<Result<UserEntity?>> getUserProfile(String uid);

  /// Get current authenticated user's profile
  /// 
  /// Returns [Result] with [UserEntity] if found, null if not authenticated
  Future<Result<UserEntity?>> getCurrentUserProfile();

  /// Stream of current user's profile changes
  /// 
  /// Watches local DB for changes (which are updated by Firestore listeners)
  Stream<UserEntity?> watchCurrentUserProfile();
}
