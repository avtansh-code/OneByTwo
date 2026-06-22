import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/providers/phone_auth_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/notifications/data/fcm_token_service.dart';

/// FR-AC-03 AC-3: unregisters the device's FCM token from
/// `users/{uid}.fcmTokens` BEFORE `FirebaseAuth.signOut()` so the
/// server stops sending notifications to this device immediately.
///
/// The cleanup MUST NOT block sign-out (architect §2.7 contract).
/// If the FCM unregister fails (network error, missing token,
/// provider construction failure in a test environment), the failure
/// is swallowed and sign-out proceeds — a stale token will be pruned
/// server-side on the next FCM send via the 410 cleanup path
/// (functions/src/notifications/fcm-send.ts).
///
/// Throws whatever the underlying `signOut()` throws (callers wrap
/// in their own try/catch to surface a user-facing error snackbar).
Future<void> signOutWithFcmCleanup(WidgetRef ref) async {
  try {
    final authState = ref.read(authStateProvider).valueOrNull;
    if (authState is AuthenticatedWithProfile) {
      final tokenService = ref.read(fcmTokenServiceProvider);
      final currentToken = tokenService.currentToken;
      if (currentToken != null) {
        await tokenService.unregisterToken(authState.uid, currentToken);
      }
      await tokenService.stopTokenRefreshListener();
    }
  } catch (e, st) {
    debugPrint(
      '[signOutWithFcmCleanup] FCM cleanup skipped — '
      'token will be pruned server-side on next 410: $e\n$st',
    );
  }
  await ref.read(phoneAuthRepositoryProvider).signOut();
}
