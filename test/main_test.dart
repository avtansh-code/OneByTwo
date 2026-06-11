// OneBytwoApp `currentUserIdProvider` production-wiring regression tests.
//
// Closes the regression from PR #56 — `currentUserIdProvider` declared
// at `lib/features/friends/application/friends_list_provider.dart:15-21`
// throws `UnimplementedError` when no override is in place. Before
// FR-HD-04, the production `main.dart` did NOT wrap the
// `AuthenticatedWithProfile` arm in a `ProviderScope` override, so the
// Friends tab (1) and Activity tab (3) crashed on first tap.
//
// AC coverage:
//   - AC-13: with `AuthenticatedWithProfile(uid: 'uid-X')`, reading
//     `currentUserIdProvider` inside the per-arm scope returns 'uid-X'
//     (NOT throws).
//   - AC-14: with `AuthenticatedWithProfile(uid: 'uid-X')`, tapping
//     Friends tab (1) and Activity tab (3) does not throw
//     UnimplementedError.

// ignore_for_file: cascade_invocations

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/result.dart';
import 'package:onebytwo/features/activity/data/activity_feed_repository.dart';
import 'package:onebytwo/features/activity/domain/activity_feed_item.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/data/phone_auth_repository.dart';
import 'package:onebytwo/features/auth/data/user_repository.dart';
import 'package:onebytwo/features/auth/domain/auth_error.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/auth/domain/auth_user.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/auth/domain/verification_session.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/data/friendship_repository.dart';
import 'package:onebytwo/features/friends/domain/friendship_doc.dart';
import 'package:onebytwo/features/friends/presentation/friends_list_screen.dart';
import 'package:onebytwo/features/shell/presentation/authenticated_shell.dart';
import 'package:onebytwo/main.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeAnalyticsService implements AnalyticsService {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

class _FakePhoneAuthRepository implements PhoneAuthRepository {
  @override
  Future<void> requestOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthUser user) onAutoVerified,
    required void Function(AuthError error) onError,
    void Function()? onAutoRetrievalTimeout,
  }) async {}

  @override
  Future<Result<AuthUser, AuthError>> verifyOtp({
    required String verificationId,
    required String code,
  }) async => const Failure(AuthError.unknown);

  @override
  Future<void> resendOtp({
    required String phoneNumber,
    required void Function(VerificationSession session) onCodeSent,
    required void Function(AuthError error) onError,
    int? resendToken,
  }) async {}

  @override
  Future<void> signOut() async {}
}

class _FakeUserRepository implements UserRepository {
  @override
  Future<UserModel?> getUser(String uid) async => null;

  @override
  Future<void> createUser({
    required String uid,
    required String displayName,
    required String phoneNumber,
    String? photoUrl,
  }) async {}

  @override
  Future<String> uploadAvatar(String uid, String filePath) async =>
      'https://example.com/avatar.jpg';

  @override
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
    bool removePhoto = false,
  }) async {}

  @override
  Future<void> deleteAvatar(String uid) async {}

  @override
  Future<void> updateNotificationPrefs({
    required String uid,
    required Map<String, bool> prefs,
  }) async {}
}

/// In-memory friendship repository that emits an empty list. Keeps the
/// production `friendsListProvider` pipeline live (reading
/// `currentUserIdProvider`) without needing Firestore.
class _EmptyFriendshipRepository implements FriendshipRepository {
  @override
  Stream<List<FriendshipDoc>> watchFriendships(String currentUserId) {
    return Stream<List<FriendshipDoc>>.value(const <FriendshipDoc>[]);
  }

  @override
  Stream<FriendshipDoc?> watchFriendship(String friendshipId) {
    return Stream<FriendshipDoc?>.value(null);
  }

  @override
  Future<bool> friendshipExists(String userId1, String userId2) async {
    return false;
  }

  @override
  Future<String> createFriendship(
    String currentUserId,
    String otherUserId,
  ) async {
    throw UnimplementedError(
      'write path not exercised in this regression test',
    );
  }
}

/// In-memory activity-feed repository that emits an empty list. Same
/// rationale as `_EmptyFriendshipRepository` for the Activity tab.
class _EmptyActivityFeedRepository implements ActivityFeedRepository {
  @override
  Stream<List<ActivityFeedItem>> watchItems(String userId) {
    return Stream<List<ActivityFeedItem>>.value(const <ActivityFeedItem>[]);
  }
}

List<Override> _baseOverrides({required Stream<AuthState> authStream}) {
  return [
    analyticsServiceProvider.overrideWithValue(_FakeAnalyticsService()),
    phoneAuthRepositoryProvider.overrideWithValue(_FakePhoneAuthRepository()),
    userRepositoryProvider.overrideWithValue(_FakeUserRepository()),
    authStateNotifierProvider.overrideWith((ref) => authStream),
    // Keep the production friendsListProvider pipeline live (so it
    // reads the per-arm `currentUserIdProvider` override) but route
    // through an in-memory fake so no Firestore call is required.
    friendshipRepositoryProvider.overrideWithValue(
      _EmptyFriendshipRepository(),
    ),
    activityFeedRepositoryProvider.overrideWithValue(
      _EmptyActivityFeedRepository(),
    ),
  ];
}

UserModel _testUser() {
  return UserModel(
    phoneNumber: '+919876543210',
    displayName: 'Test User',
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('currentUserIdProvider production wiring (AC-13)', () {
    testWidgets(
      'returns the AuthenticatedWithProfile uid inside the per-arm scope',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: _baseOverrides(
              authStream: Stream.value(
                AuthenticatedWithProfile(uid: 'uid-X', user: _testUser()),
              ),
            ),
            child: const OneBytwoApp(),
          ),
        );
        await tester.pumpAndSettle();

        // The shell mounts — confirms the production arm rendered.
        expect(find.byType(AuthenticatedShell), findsOneWidget);

        // Read `currentUserIdProvider` from inside the per-arm scope
        // (the scope hosting the AuthenticatedShell element).
        final shellElement = tester.element(find.byType(AuthenticatedShell));
        final container = ProviderScope.containerOf(shellElement);
        expect(
          container.read(currentUserIdProvider),
          'uid-X',
          reason:
              'main.dart MUST wrap AuthenticatedWithProfile in a per-arm '
              'ProviderScope overriding currentUserIdProvider to the '
              'session uid. Without the override, the provider throws '
              'UnimplementedError and Friends/Activity tabs crash on '
              'first tap (PR #56 regression).',
        );
      },
    );
  });

  group('Friends + Activity tabs no longer crash on tap (AC-14)', () {
    testWidgets('tapping Friends tab and Activity tab does not throw', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _baseOverrides(
            authStream: Stream.value(
              AuthenticatedWithProfile(uid: 'uid-X', user: _testUser()),
            ),
          ),
          child: const OneBytwoApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AuthenticatedShell), findsOneWidget);

      // Tap Friends tab (index 1).
      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();
      // Friends list screen is mounted and rendered in its empty
      // state (the fake friendship repo emits an empty stream).
      expect(find.byType(FriendsListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap Activity tab (index 3).
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      // No exception from activity feed mount either.
      expect(tester.takeException(), isNull);
    });
  });
}
