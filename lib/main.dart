import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/remote_config/remote_config_service.dart';
import 'package:onebytwo/core/services/key_value_store.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/presentation/phone_entry_screen.dart';
import 'package:onebytwo/features/auth/presentation/profile_setup_screen.dart';
import 'package:onebytwo/features/auth/presentation/splash_screen.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/data/matching_callable_adapter.dart';
import 'package:onebytwo/features/friends/data/matching_repository.dart';
import 'package:onebytwo/features/notifications/data/notification_handler.dart';
import 'package:onebytwo/features/notifications/presentation/notifications_lifecycle_host.dart';
import 'package:onebytwo/features/profile/data/delete_account_callable_adapter.dart';
import 'package:onebytwo/features/profile/data/delete_account_repository.dart';
import 'package:onebytwo/features/reminders/data/reminder_callable_adapter.dart';
import 'package:onebytwo/features/reminders/data/reminder_repository.dart';
import 'package:onebytwo/features/shell/presentation/authenticated_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether to use the Firebase Auth Emulator.
///
/// Pass `--dart-define=USE_EMULATOR=true` to `flutter run` to enable:
///   flutter run --dart-define=USE_EMULATOR=true
const _useEmulator = bool.fromEnvironment('USE_EMULATOR');

/// Cloud Functions region — pinned to Mumbai per SRS section 7.1 and
/// matches `functions/src/index.ts:16` (`REGION = "asia-south1"`).
const _functionsRegion = 'asia-south1';

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
    debugPrint('[OneByTwo] Connecting to Firestore emulator $host:8181...');
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8181);
    debugPrint('[OneByTwo] Firestore emulator connected.');
    debugPrint('[OneByTwo] Connecting to Storage emulator $host:9199...');
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    debugPrint('[OneByTwo] Storage emulator connected.');
    debugPrint('[OneByTwo] Connecting to Functions emulator $host:5001...');
    FirebaseFunctions.instanceFor(
      region: _functionsRegion,
    ).useFunctionsEmulator(host, 5001);
    debugPrint('[OneByTwo] Functions emulator connected.');
    // FCM emulator is NOT part of the Firebase Emulator Suite
    // (architect §2.5) — manual smoke uses real FCM tokens on a debug
    // build; tests mock at the SDK boundary via Riverpod overrides.
  }

  // Production wiring (FR-AC-04 architect §2.7): the repositories
  // hide `cloud_functions` behind the `ReminderCallable` /
  // `LookupCallable` typedefs. main.dart is the ONLY place that
  // constructs the adapters and injects them via ProviderScope
  // overrides — tests inject their own fake callables and never load
  // `cloud_functions` Firebase.
  final functions = FirebaseFunctions.instanceFor(region: _functionsRegion);
  final reminderAdapter = ReminderCallableAdapter(
    functions.httpsCallable('sendReminderNotification'),
  );
  final matchingAdapter = MatchingCallableAdapter(
    functions.httpsCallable('lookupUserByPhoneNumber'),
  );
  final deleteAccountAdapter = DeleteAccountCallableAdapter(
    functions.httpsCallable('deleteUserAccount'),
  );

  // FR-PR-05: initialise Firebase Remote Config (the app's first
  // consumer, ADR-0006). `initialise()` awaits the fast local
  // `setDefaults`; the network fetch is fire-and-forget so the first
  // frame is never gated on it. The Contact Support address resolves to
  // the compiled-in default until the background fetch activates.
  final remoteConfig = FirebaseRemoteConfigService(
    FirebaseRemoteConfig.instance,
  );
  await remoteConfig.initialise();

  // First on-device key-value persistence (cross-launch state). Load the
  // SharedPreferences instance ONCE here — after the existing awaits,
  // before runApp — and inject it behind the KeyValueStore seam via a
  // ProviderScope override. Loading it eagerly keeps reads synchronous so
  // the sync NotificationPermissionController.build() can hydrate without
  // an async/sync mismatch, and guarantees the store is ready before any
  // provider reads it.
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(
          SharedPreferencesKeyValueStore(sharedPreferences),
        ),
        reminderRepositoryProvider.overrideWithValue(
          ReminderRepository(callable: reminderAdapter.asCallable),
        ),
        matchingRepositoryProvider.overrideWithValue(
          MatchingRepository(lookupCallable: matchingAdapter.asCallable),
        ),
        deleteAccountRepositoryProvider.overrideWithValue(
          DeleteAccountRepository(callable: deleteAccountAdapter.asCallable),
        ),
        remoteConfigServiceProvider.overrideWithValue(remoteConfig),
      ],
      child: const OneBytwoApp(),
    ),
  );
}

/// Root widget for the One By Two application.
///
/// Watches the [authStateProvider] and rebuilds the
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
    final authState = ref.watch(authStateProvider);

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
        // The per-arm currentUserId / currentUserPhone overrides are applied
        // in MaterialApp.builder (ABOVE the root Navigator), not here, so that
        // root-Navigator modals (e.g. the add-expense context picker) inherit
        // the scope (D8 / FR-HD-04). See `scopeOverrides` below.
        AuthenticatedWithProfile() => const AuthenticatedShell(),
      },
      loading: () => const SplashScreen(),
      error: (_, __) => const SplashScreen(),
    );

    // D8 / FR-HD-04: bind `currentUserIdProvider` and `currentUserPhoneProvider`
    // for the authenticated session ABOVE the root Navigator (applied in the
    // builder below), so root-Navigator modals — notably the add-expense
    // context picker — inherit the scope rather than reading the unscoped
    // providers (which throw). The overrides are dropped automatically on
    // sign-out when the auth state leaves `AuthenticatedWithProfile`.
    final scopeOverrides = authState.maybeWhen<List<Override>>(
      data: (state) => state is AuthenticatedWithProfile
          ? [
              currentUserIdProvider.overrideWithValue(state.uid),
              currentUserPhoneProvider.overrideWithValue(
                state.user.phoneNumber,
              ),
            ]
          : const [],
      orElse: () => const [],
    );

    return MaterialApp(
      key: ValueKey('app-$stateCategory'),
      title: 'OneByTwo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: home,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        final scoped = scopeOverrides.isEmpty
            ? content
            : ProviderScope(overrides: scopeOverrides, child: content);
        return NotificationsLifecycleHost(child: scoped);
      },
    );
  }
}
