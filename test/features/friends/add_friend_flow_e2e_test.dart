// End-to-end widget test for the add-friend journey (audit S6 / PY3).
//
// This is the regression test whose absence let S6 ship. Previously the
// AddFriendScreen popped a `SelectedContact` that every caller silently
// discarded with `push<void>`, so `MatchAndInviteScreen` was never
// navigated to and NO reachable path created a friendship.
//
// Unlike the isolated screen/controller tests, this exercises the FULL
// wired journey through the real `openAddFriendFlow` seam:
//
//   FriendsListScreen "Add friend" -> AddFriendScreen -> select/enter a
//   contact -> screen pops the SelectedContact -> MatchAndInviteScreen
//   lookup -> match found -> "Add as friend" ->
//   FriendshipRepository.createFriendship.
//
// Everything is faked via `ProviderScope.overrides` — no emulator, no
// Firebase. The friendship write is proved through a recording
// `FriendshipStore` behind the REAL `FriendshipRepository`, so the
// deterministic-ID write contract is exercised end to end.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/data/contact_service.dart';
import 'package:onebytwo/features/friends/data/friendship_repository.dart';
import 'package:onebytwo/features/friends/data/matching_repository.dart';
import 'package:onebytwo/features/friends/data/share_service.dart';
import 'package:onebytwo/features/friends/domain/contact_permission_state.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/domain/friendship_doc.dart';
import 'package:onebytwo/features/friends/presentation/add_friend_screen.dart';
import 'package:onebytwo/features/friends/presentation/friends_list_screen.dart';
import 'package:onebytwo/features/friends/presentation/match_and_invite_screen.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Records every analytics event so the test can assert the PII-free
/// `friend_added{method}` payload (T4).
class FakeAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object>? parameters})> events =
      <({String name, Map<String, Object>? parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  /// Parameters of the most recent event named [name].
  Map<String, Object>? paramsFor(String name) =>
      events.lastWhere((e) => e.name == name).parameters;
}

/// In-memory [FriendshipStore] that records writes instead of hitting
/// Firestore. `exists` returns false so the duplicate-friendship guard
/// always proceeds to `createFriendship`.
class RecordingFriendshipStore implements FriendshipStore {
  /// Documents written, keyed by deterministic friendship ID.
  final Map<String, Map<String, dynamic>> documents =
      <String, Map<String, dynamic>>{};

  @override
  Future<void> set(String path, Map<String, dynamic> data) async {
    documents[path] = data;
  }

  @override
  Future<bool> exists(String path) async => false;

  @override
  Future<Map<String, dynamic>?> get(String path) async => documents[path];

  @override
  Stream<List<FriendshipDoc>> watchByMember(String userId) =>
      const Stream<List<FriendshipDoc>>.empty();

  @override
  Stream<FriendshipDoc?> watchById(String friendshipId) =>
      const Stream<FriendshipDoc?>.empty();
}

/// Contact service that reports permission as granted and returns a
/// fixed contact list, avoiding the `flutter_contacts` platform plugin.
class FakeContactService implements ContactService {
  FakeContactService(this.contacts);

  final List<DeviceContact> contacts;

  @override
  Future<ContactPermissionState> checkPermission() async =>
      ContactPermissionState.granted;

  @override
  Future<ContactPermissionState> requestPermission() async =>
      ContactPermissionState.granted;

  @override
  Future<List<DeviceContact>> getContacts() async => contacts;

  @override
  Future<void> openSettings() async {}
}

/// Share service that records invite text instead of opening the system
/// share sheet (invariant 3 — never imports a messaging-app SDK).
class FakeShareService implements ShareServiceBase {
  final List<String> shared = <String>[];

  @override
  Future<void> share(String text) async => shared.add(text);
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Builds [FriendsListScreen] — the real entry point to the add-friend
/// journey — with every collaborator faked. `currentUserPhone` differs
/// from the looked-up contact so the self-add guard never trips.
Widget _buildSubject({
  required FakeAnalyticsService analytics,
  required FakeContactService contacts,
  required FriendshipRepository friendshipRepository,
  required MatchingRepository matchingRepository,
  required FakeShareService share,
}) {
  return ProviderScope(
    overrides: <Override>[
      analyticsServiceProvider.overrideWithValue(analytics),
      currentUserIdProvider.overrideWithValue('uid-me'),
      currentUserPhoneProvider.overrideWithValue('+919999999999'),
      friendsListProvider.overrideWith(
        (ref) => Stream<List<FriendListItem>>.value(const <FriendListItem>[]),
      ),
      contactServiceProvider.overrideWithValue(contacts),
      matchingRepositoryProvider.overrideWithValue(matchingRepository),
      friendshipRepositoryProvider.overrideWithValue(friendshipRepository),
      shareServiceProvider.overrideWithValue(share),
    ],
    child: const MaterialApp(home: FriendsListScreen()),
  );
}

/// A [MatchingRepository] whose Cloud Function callable always reports a
/// registered match for `uid-amit`.
MatchingRepository _matchedRepository() {
  return MatchingRepository(
    lookupCallable: (data) async => <String, dynamic>{
      'matched': true,
      'displayName': 'Amit Kumar',
      'photoUrl': null,
      'otherUserId': 'uid-amit',
    },
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Add-friend journey (S6 wiring / PY3 regression)', () {
    testWidgets('contacts path: select a contact -> match -> add creates the '
        'friendship and tags friend_added{method: contacts}', (tester) async {
      final analytics = FakeAnalyticsService();
      final store = RecordingFriendshipStore();
      final friendshipRepository = FriendshipRepository(store: store);
      final share = FakeShareService();
      final contacts = FakeContactService(const <DeviceContact>[
        DeviceContact(
          displayName: 'Amit Kumar',
          phoneNumbers: <String>['9876543210'],
        ),
      ]);

      await tester.pumpWidget(
        _buildSubject(
          analytics: analytics,
          contacts: contacts,
          friendshipRepository: friendshipRepository,
          matchingRepository: _matchedRepository(),
          share: share,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open the add-friend flow from the friends list app bar.
      await tester.tap(find.byTooltip('Add friend'));
      await tester.pumpAndSettle();
      expect(find.byType(AddFriendScreen), findsOneWidget);

      // 2. Tap the device contact. This pops the SelectedContact —
      //    the hand-off every caller used to discard (S6).
      await tester.tap(find.text('Amit Kumar'));
      await tester.pumpAndSettle();

      // 3. The match-and-invite screen is now reachable and resolved a
      //    match for the looked-up number.
      expect(find.byType(MatchAndInviteScreen), findsOneWidget);
      expect(find.text('Add as friend'), findsOneWidget);

      // 4. Confirm the add — the friendship is actually written.
      await tester.tap(find.text('Add as friend'));
      await tester.pumpAndSettle();

      // createFriendship invoked: deterministic sorted-UID document ID,
      // no client-written simplifiedBalances (invariant 2).
      expect(store.documents.keys, contains('uid-amit_uid-me'));
      final created = store.documents['uid-amit_uid-me']!;
      expect(created['memberIds'], <String>['uid-amit', 'uid-me']);
      expect(created['createdBy'], 'uid-me');
      expect(created.containsKey('simplifiedBalances'), isFalse);

      // friend_added carries the PII-free entry method (T4).
      expect(analytics.paramsFor('friend_added'), {'method': 'contacts'});
    });

    testWidgets('manual path: type a number -> match -> add creates the '
        'friendship and tags friend_added{method: manual}', (tester) async {
      final analytics = FakeAnalyticsService();
      final store = RecordingFriendshipStore();
      final friendshipRepository = FriendshipRepository(store: store);
      final share = FakeShareService();
      final contacts = FakeContactService(const <DeviceContact>[]);

      await tester.pumpWidget(
        _buildSubject(
          analytics: analytics,
          contacts: contacts,
          friendshipRepository: friendshipRepository,
          matchingRepository: _matchedRepository(),
          share: share,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add friend'));
      await tester.pumpAndSettle();

      // Switch to the manual-entry tab and submit a valid number.
      await tester.tap(find.text('Enter Number'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add Friend'));
      await tester.pumpAndSettle();

      expect(find.byType(MatchAndInviteScreen), findsOneWidget);
      await tester.tap(find.text('Add as friend'));
      await tester.pumpAndSettle();

      expect(store.documents.keys, contains('uid-amit_uid-me'));
      // The manual entry path is segmented distinctly in the funnel.
      expect(analytics.paramsFor('friend_added'), {'method': 'manual'});
    });
  });
}
