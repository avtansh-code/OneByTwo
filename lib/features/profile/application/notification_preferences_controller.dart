import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/connectivity/connectivity_provider.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/profile/application/notification_preferences_telemetry.dart';

// ---------------------------------------------------------------------------
// State hierarchy (FR-PR-03 architect §2.3 — in-file sealed union).
// ---------------------------------------------------------------------------

/// State for the SCR-27 Notification Preferences screen.
///
/// Three concrete variants:
///   - [NotificationPreferencesLoading] — initial read in flight.
///   - [NotificationPreferencesError] — initial read failed.
///   - [NotificationPreferencesReady] — toggles can be flipped; the
///     `savingKeys` set indicates which categories have an in-flight
///     (or debouncing) write.
@immutable
sealed class NotificationPreferencesState {
  /// Creates a [NotificationPreferencesState].
  const NotificationPreferencesState();
}

/// The controller is reading `users/{uid}.notificationPrefs` from
/// Firestore.
final class NotificationPreferencesLoading
    extends NotificationPreferencesState {
  /// Creates a [NotificationPreferencesLoading].
  const NotificationPreferencesLoading();
}

/// The initial read failed (network, parse error, missing user doc).
/// The screen surfaces the AC-8 error copy + Retry button.
final class NotificationPreferencesError extends NotificationPreferencesState {
  /// Creates a [NotificationPreferencesError].
  const NotificationPreferencesError({required this.message});

  /// Human-readable error message (not localised in v1.0 per architect
  /// §2.3).
  final String message;
}

/// The toggles are populated and interactive. `prefs` is the
/// optimistic state (reflects in-flight flips). `savingKeys` is the
/// set of categories with a debounce timer pending or a write in
/// flight. `offlineWriteJustQueued` is a one-shot signal that
/// transitions `false → true` exactly once per controller session
/// (the first time a toggle is flipped while the device is offline);
/// the screen listens for the transition and surfaces the AC-10
/// snackbar.
final class NotificationPreferencesReady extends NotificationPreferencesState {
  /// Creates a [NotificationPreferencesReady].
  const NotificationPreferencesReady({
    required this.prefs,
    required this.savingKeys,
    this.offlineWriteJustQueued = false,
  });

  /// The current (optimistic) preferences. Keys are
  /// `newExpense` / `settlement` / `reminder`.
  final Map<String, bool> prefs;

  /// The categories with a pending debounce timer or an in-flight
  /// write. UI may render per-row activity indicators based on this.
  final Set<String> savingKeys;

  /// One-shot AC-10 signal — `true` exactly once per controller
  /// session the first time a flip is detected while offline. Stays
  /// `true` for the remainder of the controller's lifetime (so the
  /// screen-side false→true transition fires only once), then resets
  /// when the screen is popped and a fresh autoDispose controller is
  /// created.
  final bool offlineWriteJustQueued;

  /// Creates a copy with the given fields replaced. Preserves
  /// [offlineWriteJustQueued] by default so the one-shot signal
  /// stays latched.
  NotificationPreferencesReady copyWith({
    Map<String, bool>? prefs,
    Set<String>? savingKeys,
    bool? offlineWriteJustQueued,
  }) {
    return NotificationPreferencesReady(
      prefs: prefs ?? this.prefs,
      savingKeys: savingKeys ?? this.savingKeys,
      offlineWriteJustQueued:
          offlineWriteJustQueued ?? this.offlineWriteJustQueued,
    );
  }
}

// ---------------------------------------------------------------------------
// Controller — FR-PR-03 architect §2.3.
// ---------------------------------------------------------------------------

/// Debounce window for a single toggle flip (architect §2.3 — chosen
/// to absorb rapid taps without blocking the network on every frame).
const Duration kNotificationPrefsDebounce = Duration(milliseconds: 500);

/// Controller for the SCR-27 Notification Preferences screen.
///
/// State machine: `Loading` → (`Ready` | `Error`).
///
/// On a toggle flip via [setNewExpense] / [setSettlement] /
/// [setReminder]:
///   1. Optimistically updates `prefs[key]` and adds `key` to
///      `savingKeys`.
///   2. Cancels any prior debounce timer for that key.
///   3. Starts a [kNotificationPrefsDebounce] timer. On fire, appends
///      the persist call to a per-controller serial write chain
///      (`_writeChain`) so concurrent flushes never race.
///   4. On persist success: updates the persisted snapshot, removes
///      the key from `savingKeys`, fires
///      [notificationPrefChangedEvent].
///   5. On persist failure: reverts `prefs[key]` to the last persisted
///      value, removes the key from `savingKeys`, fires
///      [notificationPrefErrorEvent] with a classified `error_code`.
class NotificationPreferencesController
    extends StateNotifier<NotificationPreferencesState> {
  /// Creates a [NotificationPreferencesController].
  ///
  /// Kicks off the initial Firestore read immediately. Callers should
  /// not need to invoke any "init" method — the state transitions
  /// from [NotificationPreferencesLoading] to [NotificationPreferencesReady]
  /// or [NotificationPreferencesError] as the read completes.
  NotificationPreferencesController({
    required UserRepository repository,
    required AnalyticsService analytics,
    required IsOnline isOnline,
    required String uid,
  }) : _repository = repository,
       _analytics = analytics,
       _isOnline = isOnline,
       _uid = uid,
       super(const NotificationPreferencesLoading()) {
    // Fire and forget — the future drives the state transitions.
    unawaited(_load());
  }

  final UserRepository _repository;
  final AnalyticsService _analytics;
  final IsOnline _isOnline;
  final String _uid;

  /// Per-toggle debounce timers (one per category key).
  final Map<String, Timer> _debounceTimers = <String, Timer>{};

  /// Serial queue: every persist call is chained onto the previous
  /// one. Guarantees AC-9 (in-flight write completes before the next
  /// debounce flush starts).
  Future<void> _writeChain = Future<void>.value();

  /// The last successfully persisted snapshot. Used to revert
  /// `prefs[key]` on persist failure.
  final Map<String, bool> _persistedPrefs = <String, bool>{};

  /// AC-10 single-fire-per-session latch — set the first time a flip
  /// is detected while offline. Prevents subsequent offline flips from
  /// re-showing the banner. Reset implicitly when the autoDispose
  /// controller is recreated on the next SCR-27 mount.
  bool _offlineBannerSignalled = false;

  /// Loads the initial preferences from `users/{_uid}`.
  Future<void> _load() async {
    try {
      final user = await _repository.getUser(_uid);
      if (!mounted) return;
      if (user == null) {
        state = const NotificationPreferencesError(
          message: 'Could not load your preferences.',
        );
        return;
      }
      final loaded = Map<String, bool>.from(user.notificationPrefs);
      _persistedPrefs
        ..clear()
        ..addAll(loaded);
      state = NotificationPreferencesReady(
        prefs: loaded,
        savingKeys: const <String>{},
      );
    } catch (e) {
      if (!mounted) return;
      state = const NotificationPreferencesError(
        message: 'Could not load your preferences.',
      );
    }
  }

  /// Re-attempts the initial Firestore read. Called by the Retry
  /// button on the error state.
  Future<void> reload() async {
    state = const NotificationPreferencesLoading();
    await _load();
  }

  /// Flip the `newExpense` category.
  // ignore: avoid_positional_boolean_parameters
  void setNewExpense(bool value) =>
      _setKey(notificationPrefCategoryNewExpense, value);

  /// Flip the `settlement` category.
  // ignore: avoid_positional_boolean_parameters
  void setSettlement(bool value) =>
      _setKey(notificationPrefCategorySettlement, value);

  /// Flip the `reminder` category.
  // ignore: avoid_positional_boolean_parameters
  void setReminder(bool value) =>
      _setKey(notificationPrefCategoryReminder, value);

  void _setKey(String key, bool value) {
    final current = state;
    if (current is! NotificationPreferencesReady) return;

    // (1) Optimistic update.
    final newPrefs = Map<String, bool>.from(current.prefs);
    newPrefs[key] = value;
    final newSaving = Set<String>.from(current.savingKeys)..add(key);
    state = current.copyWith(prefs: newPrefs, savingKeys: newSaving);

    // (2) Cancel prior debounce timer for this key.
    _debounceTimers[key]?.cancel();

    // (3) Start a fresh debounce timer. On fire, chain the persist
    //     onto _writeChain so concurrent flushes serialise.
    _debounceTimers[key] = Timer(kNotificationPrefsDebounce, () {
      _debounceTimers.remove(key);
      _writeChain = _writeChain.then((_) => _persist(key, value));
    });

    // (4) AC-10 — fire-and-forget connectivity probe. If we're
    //     offline AND haven't shown the banner this session yet,
    //     latch the one-shot signal on state so the screen can
    //     surface the AC-10 snackbar. Subsequent flips are silent.
    unawaited(_maybeSignalOffline());
  }

  Future<void> _maybeSignalOffline() async {
    if (_offlineBannerSignalled) return;
    final bool online;
    try {
      online = await _isOnline();
    } on Exception {
      // Connectivity check itself failed — assume online (don't show
      // a false-positive banner).
      return;
    }
    if (online) return;
    if (_offlineBannerSignalled) return;
    _offlineBannerSignalled = true;
    if (!mounted) return;
    final current = state;
    if (current is! NotificationPreferencesReady) return;
    state = current.copyWith(offlineWriteJustQueued: true);
  }

  Future<void> _persist(String key, bool value) async {
    try {
      await _repository.updateNotificationPrefs(
        uid: _uid,
        prefs: <String, bool>{key: value},
      );

      if (!mounted) return;
      _persistedPrefs[key] = value;

      await _analytics.logEvent(
        name: notificationPrefChangedEvent,
        parameters: <String, Object>{
          notificationPrefCategoryParam: key,
          notificationPrefEnabledParam: value,
        },
      );

      _removeFromSavingKeys(key);
    } catch (e) {
      if (!mounted) return;
      final errorCode = _classifyError(e);

      await _analytics.logEvent(
        name: notificationPrefErrorEvent,
        parameters: <String, Object>{
          notificationPrefCategoryParam: key,
          notificationPrefErrorCodeParam: errorCode,
        },
      );

      _revertKey(key);
    }
  }

  void _revertKey(String key) {
    final current = state;
    if (current is! NotificationPreferencesReady) return;
    final reverted = Map<String, bool>.from(current.prefs);
    // Fall back to true (the default in UserModel.toCreateMap) if no
    // persisted value exists yet for this key.
    reverted[key] = _persistedPrefs[key] ?? true;
    final newSaving = Set<String>.from(current.savingKeys)..remove(key);
    state = current.copyWith(prefs: reverted, savingKeys: newSaving);
  }

  void _removeFromSavingKeys(String key) {
    final current = state;
    if (current is! NotificationPreferencesReady) return;
    if (!current.savingKeys.contains(key)) return;
    final newSaving = Set<String>.from(current.savingKeys)..remove(key);
    state = current.copyWith(savingKeys: newSaving);
  }

  /// Classifies a persist failure into the
  /// [notificationPrefErrorCodeParam] taxonomy. Matches the
  /// `expense_telemetry.dart` precedent: `network` for the Firestore
  /// `unavailable` code, `firestore-error` for any other
  /// [FirebaseException], `unknown` for everything else.
  String _classifyError(Object e) {
    if (e is FirebaseException) {
      if (e.code == 'unavailable') return notificationPrefErrorCodeNetwork;
      return notificationPrefErrorCodeFirestore;
    }
    return notificationPrefErrorCodeUnknown;
  }

  @override
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    super.dispose();
  }
}

/// Riverpod provider for [NotificationPreferencesController].
///
/// Reads the current authenticated user's uid from
/// `authStateNotifierProvider`. If the state is not
/// [AuthenticatedWithProfile] (the only state from which SCR-27 is
/// reachable per the SCR-26 nav row), the controller is constructed
/// with an empty uid — the next Firestore read will surface an Error
/// state and the screen will render the AC-8 error message.
///
/// Auto-disposing so the controller (and its debounce timers) are
/// cleaned up when the screen is popped.
final notificationPreferencesControllerProvider =
    StateNotifierProvider.autoDispose<
      NotificationPreferencesController,
      NotificationPreferencesState
    >((ref) {
      final authState = ref.read(authStateNotifierProvider).valueOrNull;
      final uid = switch (authState) {
        AuthenticatedWithProfile(:final uid) => uid,
        _ => '',
      };

      return NotificationPreferencesController(
        repository: ref.watch(userRepositoryProvider),
        analytics: ref.watch(analyticsServiceProvider),
        isOnline: ref.watch(connectivityCheckProvider),
        uid: uid,
      );
    });
