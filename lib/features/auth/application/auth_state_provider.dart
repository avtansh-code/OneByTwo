import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';

/// Provides a [FirebaseAuth] instance for dependency injection.
///
/// Override in tests to inject a fake or mock instance.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// Combines Firebase Auth state with Firestore user-doc presence
/// into a single [AuthState] stream.
///
/// This provider drives the auth gate (root navigation) and is
/// app-scoped (kept alive for the process lifetime).
///
/// The provider implements switchMap semantics: when the Firebase
/// Auth user changes, the previous Firestore doc listener is
/// cancelled and a new one is established for the new user.
///
/// See `docs/design/07-technical/state-management.md` section 2.1.
final authStateNotifierProvider = StreamProvider<AuthState>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);

  final controller = StreamController<AuthState>();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userDocSub;

  final authSub = auth.authStateChanges().listen(
    (user) {
      // Cancel previous user-doc listener (switchMap semantics).
      userDocSub?.cancel();
      userDocSub = null;

      if (user == null) {
        controller.add(const AuthUnauthenticated());
        return;
      }

      // Listen to user doc for real-time updates. When the profile
      // is created (FR-AU-06), this listener detects the new doc
      // and transitions to AuthenticatedWithProfile.
      userDocSub = firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(
        (doc) {
          if (doc.exists && doc.data() != null) {
            try {
              final userData = UserModel.fromFirestore(doc);
              if (userData.displayName.trim().isNotEmpty) {
                controller.add(
                  AuthenticatedWithProfile(uid: user.uid, user: userData),
                );
              } else {
                controller.add(
                  AuthenticatedNoProfile(
                    uid: user.uid,
                    phoneNumber: user.phoneNumber,
                  ),
                );
              }
            } catch (e) {
              debugPrint('[AuthState] Error parsing user doc: $e');
              controller.add(
                AuthenticatedNoProfile(
                  uid: user.uid,
                  phoneNumber: user.phoneNumber,
                ),
              );
            }
          } else {
            controller.add(
              AuthenticatedNoProfile(
                uid: user.uid,
                phoneNumber: user.phoneNumber,
              ),
            );
          }
        },
        onError: (Object error) {
          debugPrint('[AuthState] Firestore user doc error: $error');
          // On Firestore error, default to no-profile. The Firestore
          // security rules prevent accidental doc overwrites (ADR-0008:
          // creation is one-shot), so routing to profile-setup for a
          // returning user would show a save error, not data loss.
          controller.add(
            AuthenticatedNoProfile(
              uid: user.uid,
              phoneNumber: user.phoneNumber,
            ),
          );
        },
      );
    },
    onError: (Object error) {
      debugPrint('[AuthState] Auth stream error: $error');
      controller.addError(error);
    },
  );

  ref.onDispose(() {
    authSub.cancel();
    userDocSub?.cancel();
    controller.close();
  });

  return controller.stream;
});
