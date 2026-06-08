import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/presentation/home_placeholder_screen.dart';
import 'package:onebytwo/features/auth/presentation/phone_entry_screen.dart';
import 'package:onebytwo/features/auth/presentation/profile_setup_screen.dart';
import 'package:onebytwo/features/auth/presentation/splash_screen.dart';
import 'package:onebytwo/features/notifications/data/notification_handler.dart';
import 'package:onebytwo/features/notifications/presentation/notifications_lifecycle_host.dart';

/// Whether to use the Firebase Auth Emulator.
///
/// Pass `--dart-define=USE_EMULATOR=true` to `flutter run` to enable:
///   flutter run --dart-define=USE_EMULATOR=true
const _useEmulator = bool.fromEnvironment('USE_EMULATOR');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // FR-AC-03: register the top-level FCM background handler BEFORE
  // runApp per Flutter Firebase docs. The handler is annotated
  // @pragma('vm:entry-point') so the Dart tree-shaker keeps it alive
  // in release builds.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  if (_useEmulator) {
    const host = String.fromEnvironment(
      'EMULATOR_HOST',
      defaultValue: 'localhost',
    );
    debugPrint('[OneByTwo] Connecting to auth emulator $host:9099...');
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    debugPrint('[OneByTwo] Auth emulator connected.');
    debugPrint('[OneByTwo] Connecting to Firestore emulator $host:8080...');
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8181);
    debugPrint('[OneByTwo] Firestore emulator connected.');
    debugPrint('[OneByTwo] Connecting to Storage emulator $host:9199...');
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    debugPrint('[OneByTwo] Storage emulator connected.');
    // FCM emulator is NOT part of the Firebase Emulator Suite
    // (architect §2.5) — manual smoke uses real FCM tokens on a debug
    // build; tests mock at the SDK boundary via Riverpod overrides.
  }
  runApp(const ProviderScope(child: OneBytwoApp()));
}

/// Root widget for the One By Two application.
///
/// Watches the [authStateNotifierProvider] and rebuilds the
/// [MaterialApp] with the appropriate home screen based on
/// auth state. The [ValueKey] on [MaterialApp] ensures the
/// Navigator stack is fully cleared on auth state transitions
/// (no stale routes from previous states).
///
/// The home content is wrapped in a [NotificationsLifecycleHost] via
/// [MaterialApp.builder] so FCM streams, the pre-permission dialog,
/// and the in-app banner overlay are all hosted in a single place
/// (FR-AC-03, FR-AC-05).
class OneBytwoApp extends ConsumerWidget {
  /// Creates the root application widget.
  const OneBytwoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateNotifierProvider);

    final stateCategory = authState.when(
      data: (state) => switch (state) {
        AuthLoading() => 'loading',
        AuthUnauthenticated() => 'unauthenticated',
        AuthenticatedNoProfile() => 'no-profile',
        AuthenticatedWithProfile() => 'authenticated',
      },
      loading: () => 'loading',
      error: (_, __) => 'error',
    );

    final home = authState.when(
      data: (state) => switch (state) {
        AuthLoading() => const SplashScreen(),
        AuthUnauthenticated() => const PhoneEntryScreen(),
        AuthenticatedNoProfile(:final uid, :final phoneNumber) =>
          ProfileSetupScreen(uid: uid, phoneNumber: phoneNumber ?? ''),
        AuthenticatedWithProfile() => const HomePlaceholderScreen(),
      },
      loading: () => const SplashScreen(),
      error: (_, __) => const SplashScreen(),
    );

    return MaterialApp(
      key: ValueKey('app-$stateCategory'),
      title: 'OneByTwo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: home,
      builder: (context, child) {
        return NotificationsLifecycleHost(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
