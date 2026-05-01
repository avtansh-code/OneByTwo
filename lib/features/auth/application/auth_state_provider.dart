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

/// Starts a Firestore snapshot listener on the user doc and adds
/// the derived [AuthState] to [controller].
void _listenToUserDoc({
  required FirebaseFirestore firestore,
  required User user,
  required StreamController<AuthState> controller,
  required void Function(
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>,
  )
  onSubscription,
}) {
  // ignore: cancel_subscriptions — tracked via onSubscription callback.
  final sub = firestore
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
          controller.add(
            AuthenticatedNoProfile(
              uid: user.uid,
              phoneNumber: user.phoneNumber,
            ),
          );
        },
      );
  onSubscription(sub);
}

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
/// On each auth emission, the cached token is validated via
/// [User.reload]. If the token is stale (e.g., iOS Keychain
/// persisting across app reinstall, or server-side account
/// deletion), the user is signed out to clear local state.
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

      // Validate the cached token is still valid by reloading
      // the user. This catches stale Keychain tokens on iOS
      // (which persist across app reinstalls) and server-side
      // account deletions. If reload fails, sign out to clear
      // the stale local state.
      user
          .reload()
          .then((_) {
            // Token is valid. Proceed to check user doc.
            _listenToUserDoc(
              firestore: firestore,
              user: user,
              controller: controller,
              onSubscription: (sub) => userDocSub = sub,
            );
          })
          .catchError((Object error) {
            debugPrint('[AuthState] Token reload failed: $error');
            // Stale token — sign out to clear local cache.
            auth.signOut();
          });
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
