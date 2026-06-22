import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-scoped dependency-injection providers for Firebase SDK singletons.
///
/// These live in `lib/core/providers/` (outside any feature tree) because
/// they are consumed across many features (auth, profile, friends, expenses,
/// settlements, notifications, activity). See
/// `docs/design/07-technical/state-management.md` section 4.

/// Provides a [FirebaseFirestore] instance for dependency injection.
///
/// Override in tests to inject a fake or mock instance.
final firebaseFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Provides a [FirebaseStorage] instance for dependency injection.
///
/// Override in tests to inject a fake or mock instance.
final firebaseStorageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);
