import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

import '../../models/user_model.dart';

/// Firestore data source for User operations
/// 
/// Handles reading and writing user profiles to/from Firestore `users/{uid}` collection.
class UserFirestoreSource {
  UserFirestoreSource({
    required FirebaseFirestore firestore,
    required Logger logger,
  })  : _firestore = firestore,
        _logger = logger;

  static const _tag = 'Firestore.User';

  final FirebaseFirestore _firestore;
  final Logger _logger;

  /// Collection reference for users
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Get user profile from Firestore
  /// 
  /// Returns null if user document doesn't exist
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      _logger.d('[$_tag] Getting user profile');
      
      final docSnapshot = await _usersCollection.doc(uid).get();
      
      if (!docSnapshot.exists) {
        _logger.d('[$_tag] User profile not found');
        return null;
      }
      
      final data = docSnapshot.data();
      if (data == null) {
        return null;
      }
      
      return UserModel.fromJson(data);
    } catch (e, stack) {
      _logger.e(
        '[$_tag] Error getting user profile',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Create user profile in Firestore
  /// 
  /// Throws if document already exists or on failure
  Future<void> createUserProfile(UserModel user) async {
    try {
      _logger.i('[$_tag] Creating user profile');
      
      await _usersCollection.doc(user.uid).set(user.toFirestore());
      
      _logger.i('[$_tag] User profile created successfully');
    } catch (e, stack) {
      _logger.e(
        '[$_tag] Error creating user profile',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Update user profile in Firestore
  /// 
  /// Uses merge to update only specified fields
  Future<void> updateUserProfile(UserModel user) async {
    try {
      _logger.i('[$_tag] Updating user profile');
      
      await _usersCollection.doc(user.uid).set(
        user.toFirestore(),
        SetOptions(merge: true),
      );
      
      _logger.i('[$_tag] User profile updated successfully');
    } catch (e, stack) {
      _logger.e(
        '[$_tag] Error updating user profile',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Stream user profile changes from Firestore
  /// 
  /// Emits null if user document doesn't exist
  Stream<UserModel?> watchUserProfile(String uid) {
    try {
      _logger.d('[$_tag] Watching user profile');
      
      return _usersCollection.doc(uid).snapshots().map((snapshot) {
        if (!snapshot.exists) {
          return null;
        }
        
        final data = snapshot.data();
        if (data == null) {
          return null;
        }
        
        return UserModel.fromJson(data);
      });
    } catch (e, stack) {
      _logger.e(
        '[$_tag] Error watching user profile',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Delete user profile from Firestore
  /// 
  /// This is a hard delete - use with caution
  Future<void> deleteUserProfile(String uid) async {
    try {
      _logger.w('[$_tag] Deleting user profile');
      
      await _usersCollection.doc(uid).delete();
      
      _logger.w('[$_tag] User profile deleted successfully');
    } catch (e, stack) {
      _logger.e(
        '[$_tag] Error deleting user profile',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }
}
