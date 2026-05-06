// PII leak tests for the match-and-invite flow.
//
// Verifies that no personally identifiable information (PII) leaks
// into analytics events, crashlytics breadcrumbs, or log output
// during the matching and invite flow.
//
// Extends the pattern established in pii_leak_test.dart for the
// contact picker. The only legitimate place a phone number crosses
// a boundary is the matching repository lookup call.
//
// These tests are written BEFORE the implementation exists (test-first).
// They will fail to compile until the production code is created.

// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/match_and_invite_controller.dart';
import 'package:onebytwo/features/friends/data/matching_repository.dart';
import 'package:onebytwo/features/friends/domain/selected_contact.dart';

/// PII strings that must never appear in telemetry or logs.
const _piiStrings = ['Priya', 'Sharma', '9876543210', '+919876543210'];

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Fake [AnalyticsService] that records all events with parameters.
class FakeAnalyticsService implements AnalyticsService {
  /// All logged events as `(name, parameters)` tuples.
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
        for (final key in event.parameters!.keys) {
          if (key.contains(pii)) return true;
        }
      }
    }
    return false;
  }
}

/// Fake crashlytics service that records breadcrumbs.
class FakeCrashlyticsService {
  /// All recorded breadcrumb messages.
  final List<String> breadcrumbs = [];

  /// Records a breadcrumb.
  void log(String message) {
    breadcrumbs.add(message);
  }

  /// Returns true if any breadcrumb contains [pii].
  bool containsPii(String pii) {
    return breadcrumbs.any((b) => b.contains(pii));
  }
}

/// Fake logger that captures all log output.
class FakeLogger {
  /// All logged messages.
  final List<String> messages = [];

  /// Logs a message.
  void log(String message) {
    messages.add(message);
  }

  /// Returns true if any log message contains [pii].
  bool containsPii(String pii) {
    return messages.any((m) => m.contains(pii));
  }
}

/// Fake matching repository that tracks where the phone number goes.
class FakeMatchingRepository {
  /// The result to return from [lookupUser].
  MatchResult lookupResult = const Matched(
    displayName: 'Priya Sharma',
    photoUrl: null,
    otherUserId: 'uid-xyz',
  );

  /// The phone number passed to [lookupUser].
  String? capturedPhoneNumber;

  /// Simulates [MatchingRepository.lookupUser].
  Future<MatchResult> lookupUser(String phoneNumber) async {
    capturedPhoneNumber = phoneNumber;
    return lookupResult;
  }
}

/// Fake friendship repository.
class FakeFriendshipRepository {
  /// Whether friendship exists.
  bool friendshipExistsResult = false;

  /// Simulates friendshipExists.
  Future<bool> friendshipExists(String userId1, String userId2) async {
    return friendshipExistsResult;
  }

  /// Simulates createFriendship.
  Future<String> createFriendship(
    String currentUserId,
    String otherUserId,
  ) async {
    final sorted = [currentUserId, otherUserId]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}

/// Fake share service.
class FakeShareService {
  /// Text passed to share.
  String? sharedText;

  /// Simulates share.
  Future<void> share(String text) async {
    sharedText = text;
  }
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

/// Contact with PII that should not leak into telemetry.
const _testContact = SelectedContact(
  displayName: 'Priya Sharma',
  phoneNumbers: ['+919876543210'],
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeAnalyticsService fakeAnalytics;
  late FakeCrashlyticsService fakeCrashlytics;
  late FakeLogger fakeLogger;
  late FakeMatchingRepository fakeMatchingRepo;
  late FakeFriendshipRepository fakeFriendshipRepo;
  late FakeShareService fakeShareService;
  late MatchAndInviteController controller;

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
    fakeCrashlytics = FakeCrashlyticsService();
    fakeLogger = FakeLogger();
    fakeMatchingRepo = FakeMatchingRepository();
    fakeFriendshipRepo = FakeFriendshipRepository();
    fakeShareService = FakeShareService();

    controller = MatchAndInviteController(
      matchingRepository: fakeMatchingRepo,
      friendshipRepository: fakeFriendshipRepo,
      currentUserPhone: '+919999999999',
      currentUserId: 'current-uid',
      analyticsService: fakeAnalytics,
      shareService: fakeShareService,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  group('PII leak prevention in match-and-invite flow', () {
    test('no PII in analytics events after performing lookup', () async {
      await controller.performLookup(_testContact);

      for (final pii in _piiStrings) {
        expect(
          fakeAnalytics.containsPii(pii),
          isFalse,
          reason: 'Analytics should not contain PII: $pii',
        );
      }
    });

    test('no PII in analytics events after adding friend', () async {
      await controller.performLookup(_testContact);
      await controller.addFriend();

      for (final pii in _piiStrings) {
        expect(
          fakeAnalytics.containsPii(pii),
          isFalse,
          reason: 'Analytics should not contain PII after '
              'addFriend: $pii',
        );
      }
    });

    test('no PII in crashlytics breadcrumbs after full flow', () async {
      await controller.performLookup(_testContact);
      await controller.addFriend();

      for (final pii in _piiStrings) {
        expect(
          fakeCrashlytics.containsPii(pii),
          isFalse,
          reason: 'Crashlytics should not contain PII: $pii',
        );
      }
    });

    test('no PII in log output after full flow', () async {
      await controller.performLookup(_testContact);
      await controller.addFriend();

      for (final pii in _piiStrings) {
        expect(
          fakeLogger.containsPii(pii),
          isFalse,
          reason: 'Logs should not contain PII: $pii',
        );
      }
    });

    test('phone number goes ONLY to the matching repository', () async {
      await controller.performLookup(_testContact);

      // The matching repository is the ONE legitimate boundary
      // where a phone number crosses.
      expect(
        fakeMatchingRepo.capturedPhoneNumber,
        '+919876543210',
        reason: 'Phone number should be passed to matching repo',
      );

      // Verify it did NOT leak into analytics.
      for (final pii in _piiStrings) {
        expect(
          fakeAnalytics.containsPii(pii),
          isFalse,
          reason: 'PII should not leak beyond the matching repo '
              'boundary: $pii',
        );
      }
    });

    test('no PII in analytics event names', () async {
      await controller.performLookup(_testContact);
      await controller.addFriend();

      for (final event in fakeAnalytics.loggedEvents) {
        for (final pii in _piiStrings) {
          expect(
            event.name.contains(pii),
            isFalse,
            reason: 'Event name "${event.name}" should not '
                'contain PII: $pii',
          );
        }
      }
    });

    test('no PII in analytics event parameter keys', () async {
      await controller.performLookup(_testContact);
      await controller.addFriend();

      for (final event in fakeAnalytics.loggedEvents) {
        if (event.parameters == null) continue;
        for (final key in event.parameters!.keys) {
          for (final pii in _piiStrings) {
            expect(
              key.contains(pii),
              isFalse,
              reason: 'Event parameter key "$key" should not '
                  'contain PII: $pii',
            );
          }
        }
      }
    });

    test('no PII in invite share text', () async {
      fakeMatchingRepo.lookupResult = const Unmatched();

      await controller.performLookup(_testContact);
      await controller.openInviteShareSheet();

      if (fakeShareService.sharedText != null) {
        for (final pii in _piiStrings) {
          expect(
            fakeShareService.sharedText!.contains(pii),
            isFalse,
            reason: 'Share text should not contain PII: $pii',
          );
        }
      }
    });
  });
}
