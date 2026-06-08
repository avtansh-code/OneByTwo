import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the singleton [FirebaseMessaging] instance.
///
/// Override in tests with a fake to avoid platform-channel resolution.
/// Production wiring delegates to `FirebaseMessaging.instance` which is
/// safe to access after `Firebase.initializeApp()` has resolved in
/// `lib/main.dart`.
final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (ref) => FirebaseMessaging.instance,
);
