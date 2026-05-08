// Match-and-invite controller unit tests.
//
// Tests the MatchAndInviteController which manages the post-contact-
// selection flow: phone lookup, match confirmation, friendship
// creation, and invite sharing.
//
// These tests are written BEFORE the implementation exists (test-first).
// They will fail to compile until the production code is created.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/match_and_invite_controller.dart';
import 'package:onebytwo/features/friends/data/friendship_repository.dart';
import 'package:onebytwo/features/friends/data/matching_repository.dart';
import 'package:onebytwo/features/friends/domain/selected_contact.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Fake [MatchingRepository] with configurable lookup results.
class FakeMatchingRepository {
  /// The result to return from [lookupUser].
  MatchResult? lookupResult;

  /// The phone number passed to [lookupUser].
  String? capturedPhoneNumber;

  /// Whether [lookupUser] was called.
  bool wasCalled = false;

  /// Simulates [MatchingRepository.lookupUser].
  Future<MatchResult> lookupUser(String phoneNumber) async {
    wasCalled = true;
    capturedPhoneNumber = phoneNumber;
    return lookupResult!;
  }
}

/// Fake [FriendshipRepository] with configurable results.
class FakeFriendshipRepository {
  /// Whether [friendshipExists] returns true.
  bool friendshipExistsResult = false;

  /// The friendship ID returned by [createFriendship].
  String? createdFriendshipId;

  /// Captured arguments from [createFriendship].
  ({String currentUserId, String otherUserId})? createArgs;

  /// Whether [createFriendship] was called.
  bool createFriendshipCalled = false;

  /// Whether [createFriendship] should throw.
  bool createThrows = false;

  /// Simulates [FriendshipRepository.createFriendship].
  Future<String> createFriendship(
    String currentUserId,
    String otherUserId,
  ) async {
    createFriendshipCalled = true;
    createArgs = (currentUserId: currentUserId, otherUserId: otherUserId);
    if (createThrows) throw Exception('Create failed');
    final sorted = [currentUserId, otherUserId]..sort();
    createdFriendshipId = '${sorted[0]}_${sorted[1]}';
    return createdFriendshipId!;
  }

  /// Simulates [FriendshipRepository.friendshipExists].
  Future<bool> friendshipExists(String userId1, String userId2) async {
    return friendshipExistsResult;
  }
}

/// Fake user info provider returning a configurable current user phone.
class FakeCurrentUserPhone {
  /// The current user's phone number in E.164 format.
  String phoneNumber = '+919999999999';

  /// The current user's UID.
  String uid = 'current-uid';
}

/// Fake [AnalyticsService] that records all events with parameters.
class FakeAnalyticsService implements AnalyticsService {
  /// All logged events.
  final List<({String name, Map<String, Object>? parameters})> loggedEvents =
      [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add((name: name, parameters: parameters));
  }

  /// Returns true if any event name or parameter value contains [pii].
  bool containsPii(String pii) {
    for (final event in loggedEvents) {
      if (event.name.contains(pii)) return true;
      if (event.parameters != null) {
        for (final value in event.parameters!.values) {
          if (value.toString().contains(pii)) return true;
        }
      }
    }
    return false;
  }
}

/// Fake share service that records whether share was called.
class FakeShareService {
  /// Whether [share] was called.
  bool shareCalled = false;

  /// The text passed to [share].
  String? sharedText;

  /// Simulates share.
  Future<void> share(String text) async {
    shareCalled = true;
    sharedText = text;
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Test contact representing a matched user.
const _testContact = SelectedContact(
  displayName: 'Priya Sharma',
  phoneNumbers: ['+919876543210'],
);

/// Test contact whose phone matches the current user.
const _selfContact = SelectedContact(
  displayName: 'Me',
  phoneNumbers: ['+919999999999'],
);

void main() {
  late FakeMatchingRepository fakeMatchingRepo;
  late FakeFriendshipRepository fakeFriendshipRepo;
  late FakeCurrentUserPhone fakeCurrentUser;
  late FakeAnalyticsService fakeAnalytics;
  late FakeShareService fakeShareService;
  late MatchAndInviteController controller;

  setUp(() {
    fakeMatchingRepo = FakeMatchingRepository();
    fakeFriendshipRepo = FakeFriendshipRepository();
    fakeCurrentUser = FakeCurrentUserPhone();
    fakeAnalytics = FakeAnalyticsService();
    fakeShareService = FakeShareService();

    controller = MatchAndInviteController(
      matchingRepository: fakeMatchingRepo,
      friendshipRepository: fakeFriendshipRepo,
      currentUserPhone: fakeCurrentUser.phoneNumber,
      currentUserId: fakeCurrentUser.uid,
      analyticsService: fakeAnalytics,
      shareService: fakeShareService,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  group('MatchAndInviteController initial state', () {
    test('starts in Initial state', () {
      expect(controller.state, isA<MatchAndInviteInitial>());
    });
  });

  group('MatchAndInviteController.performLookup', () {
    test('emits Loading then MatchFound on Matched result', () async {
      fakeMatchingRepo.lookupResult = const Matched(
        displayName: 'Priya Sharma',
        photoUrl: null,
        otherUserId: 'uid-xyz',
      );

      final states = <MatchAndInviteState>[];
      controller.addListener((state) => states.add(state));

      await controller.performLookup(_testContact);

      expect(states, contains(isA<MatchAndInviteLoading>()));
      expect(states.last, isA<MatchAndInviteMatchFound>());

      final matchFound = states.last as MatchAndInviteMatchFound;
      expect(matchFound.displayName, 'Priya Sharma');
      expect(matchFound.photoUrl, isNull);
      expect(matchFound.otherUserId, 'uid-xyz');
    });

    test('emits MatchFound with non-null photoUrl when present', () async {
      fakeMatchingRepo.lookupResult = const Matched(
        displayName: 'Priya Sharma',
        photoUrl: 'https://example.com/photo.jpg',
        otherUserId: 'uid-xyz',
      );

      await controller.performLookup(_testContact);

      expect(controller.state, isA<MatchAndInviteMatchFound>());
      final matchFound = controller.state as MatchAndInviteMatchFound;
      expect(matchFound.photoUrl, 'https://example.com/photo.jpg');
    });

    test('emits NoMatch on Unmatched result', () async {
      fakeMatchingRepo.lookupResult = const Unmatched();

      await controller.performLookup(_testContact);

      expect(controller.state, isA<MatchAndInviteNoMatch>());
      final noMatch = controller.state as MatchAndInviteNoMatch;
      expect(noMatch.contactDisplayName, 'Priya Sharma');
    });

    test('emits Error on Failed result', () async {
      fakeMatchingRepo.lookupResult = const Failed('INTERNAL');

      await controller.performLookup(_testContact);

      expect(controller.state, isA<MatchAndInviteError>());
    });

    test('emits RateLimited on RateLimited result', () async {
      fakeMatchingRepo.lookupResult = const RateLimited();

      await controller.performLookup(_testContact);

      expect(controller.state, isA<MatchAndInviteRateLimited>());
    });

    test('passes E.164 phone number to matching repository', () async {
      fakeMatchingRepo.lookupResult = const Unmatched();

      await controller.performLookup(_testContact);

      expect(fakeMatchingRepo.capturedPhoneNumber, '+919876543210');
    });
  });

  group('MatchAndInviteController self-add blocking', () {
    test(
      'emits SelfAddBlocked when contact phone matches current user',
      () async {
        await controller.performLookup(_selfContact);

        expect(controller.state, isA<MatchAndInviteSelfAddBlocked>());
      },
    );

    test(
      'does NOT call matching repository when self-add is detected',
      () async {
        await controller.performLookup(_selfContact);

        expect(fakeMatchingRepo.wasCalled, isFalse);
      },
    );
  });

  group('MatchAndInviteController duplicate friendship', () {
    test('emits DuplicateFriendship when friendship already exists', () async {
      fakeMatchingRepo.lookupResult = const Matched(
        displayName: 'Priya Sharma',
        photoUrl: null,
        otherUserId: 'uid-xyz',
      );
      fakeFriendshipRepo.friendshipExistsResult = true;

      await controller.performLookup(_testContact);

      expect(controller.state, isA<MatchAndInviteDuplicateFriendship>());
      final dup = controller.state as MatchAndInviteDuplicateFriendship;
      expect(dup.existingFriendshipId, isNotEmpty);
    });
  });

  group('MatchAndInviteController.addFriend', () {
    test(
      'calls createFriendship with current user and matched user IDs',
      () async {
        fakeMatchingRepo.lookupResult = const Matched(
          displayName: 'Priya Sharma',
          photoUrl: null,
          otherUserId: 'uid-xyz',
        );

        await controller.performLookup(_testContact);
        await controller.addFriend();

        expect(fakeFriendshipRepo.createFriendshipCalled, isTrue);
        expect(fakeFriendshipRepo.createArgs?.currentUserId, 'current-uid');
        expect(fakeFriendshipRepo.createArgs?.otherUserId, 'uid-xyz');
      },
    );

    test('logs analytics event on successful friendship creation', () async {
      fakeMatchingRepo.lookupResult = const Matched(
        displayName: 'Priya Sharma',
        photoUrl: null,
        otherUserId: 'uid-xyz',
      );

      await controller.performLookup(_testContact);
      await controller.addFriend();

      expect(
        fakeAnalytics.loggedEvents.any((e) => e.name == 'friend_added'),
        isTrue,
        reason: 'Expected a friend_added analytics event',
      );
    });

    test('emits Error when createFriendship throws', () async {
      fakeMatchingRepo.lookupResult = const Matched(
        displayName: 'Priya Sharma',
        photoUrl: null,
        otherUserId: 'uid-xyz',
      );
      fakeFriendshipRepo.createThrows = true;

      await controller.performLookup(_testContact);
      await controller.addFriend();

      expect(controller.state, isA<MatchAndInviteError>());
    });
  });

  group('MatchAndInviteController.openInviteShareSheet', () {
    test('calls share service when in NoMatch state', () async {
      fakeMatchingRepo.lookupResult = const Unmatched();

      await controller.performLookup(_testContact);
      await controller.openInviteShareSheet();

      expect(fakeShareService.shareCalled, isTrue);
    });

    test('share text is not empty', () async {
      fakeMatchingRepo.lookupResult = const Unmatched();

      await controller.performLookup(_testContact);
      await controller.openInviteShareSheet();

      expect(fakeShareService.sharedText, isNotNull);
      expect(fakeShareService.sharedText, isNotEmpty);
    });
  });
}
