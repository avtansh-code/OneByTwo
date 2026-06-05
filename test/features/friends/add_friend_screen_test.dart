// Widget tests for AddFriendScreen.
//
// Exercises the segmented control that toggles between "From Contacts"
// and "Enter Number" tabs. The screen under test is expected to live at:
//   lib/features/friends/presentation/add_friend_screen.dart
//
// These tests are written BEFORE the implementation exists (test-first).
// They will fail to compile until the production code is created.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/data/contact_service.dart';
import 'package:onebytwo/features/friends/domain/contact_permission_state.dart';
import 'package:onebytwo/features/friends/presentation/add_friend_screen.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Fake [AnalyticsService] that records logged events for verification.
class FakeAnalyticsService implements AnalyticsService {
  /// Events logged during the test.
  final List<String> loggedEvents = [];

  /// Parameters logged alongside each event.
  final List<Map<String, Object>?> loggedParams = [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add(name);
    loggedParams.add(parameters);
  }
}

/// Fake [ContactService] with configurable behaviour for testing.
class FakeContactService implements ContactService {
  /// The permission state returned by [checkPermission].
  ContactPermissionState checkPermissionResult = ContactPermissionState.granted;

  /// The permission state returned by [requestPermission].
  ContactPermissionState requestPermissionResult =
      ContactPermissionState.granted;

  /// Contacts returned by [getContacts].
  List<DeviceContact> contactsResult = [];

  /// Whether [openSettings] was called.
  bool openSettingsCalled = false;

  @override
  Future<ContactPermissionState> checkPermission() async =>
      checkPermissionResult;

  @override
  Future<ContactPermissionState> requestPermission() async =>
      requestPermissionResult;

  @override
  Future<List<DeviceContact>> getContacts() async => contactsResult;

  @override
  Future<void> openSettings() async {
    openSettingsCalled = true;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds the [AddFriendScreen] wrapped in the minimal widget tree
/// required for testing.
Widget _buildSubject({
  required FakeAnalyticsService fakeAnalytics,
  required FakeContactService fakeContactService,
}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(fakeAnalytics),
      contactServiceProvider.overrideWithValue(fakeContactService),
    ],
    child: const MaterialApp(home: AddFriendScreen()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeAnalyticsService fakeAnalytics;
  late FakeContactService fakeContactService;

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
    fakeContactService = FakeContactService();
    fakeContactService.checkPermissionResult = ContactPermissionState.granted;
    fakeContactService.contactsResult = [
      const DeviceContact(
        displayName: 'Amit Kumar',
        phoneNumbers: ['9876543210'],
      ),
    ];
  });

  group('AddFriendScreen', () {
    testWidgets(
      'renders segmented control with From Contacts and Enter Number',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            fakeAnalytics: fakeAnalytics,
            fakeContactService: fakeContactService,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('From Contacts'), findsOneWidget);
        expect(find.text('Enter Number'), findsOneWidget);
      },
    );

    testWidgets('From Contacts is selected by default', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          fakeAnalytics: fakeAnalytics,
          fakeContactService: fakeContactService,
        ),
      );
      await tester.pumpAndSettle();

      // The contacts tab content should be visible — e.g. the contact
      // list or the search field.
      expect(find.text('Amit Kumar'), findsOneWidget);
    });

    testWidgets('tapping Enter Number switches to manual entry tab', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          fakeAnalytics: fakeAnalytics,
          fakeContactService: fakeContactService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enter Number'));
      await tester.pumpAndSettle();

      // The manual entry tab should now be visible.
      expect(
        find.text('Enter a 10-digit Indian mobile number.'),
        findsOneWidget,
      );
      // The contacts list should be hidden.
      expect(find.text('Amit Kumar'), findsNothing);
    });

    testWidgets('tapping From Contacts switches back to contact picker', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          fakeAnalytics: fakeAnalytics,
          fakeContactService: fakeContactService,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to manual entry.
      await tester.tap(find.text('Enter Number'));
      await tester.pumpAndSettle();
      expect(find.text('Amit Kumar'), findsNothing);

      // Switch back to contacts.
      await tester.tap(find.text('From Contacts'));
      await tester.pumpAndSettle();
      expect(find.text('Amit Kumar'), findsOneWidget);
    });

    testWidgets(
      'fires add_friend_screen_viewed with entry_path contacts on load',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            fakeAnalytics: fakeAnalytics,
            fakeContactService: fakeContactService,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          fakeAnalytics.loggedEvents,
          contains('add_friend_screen_viewed'),
        );

        // Verify the entry_path parameter is 'contacts'.
        final eventIndex = fakeAnalytics.loggedEvents.indexOf(
          'add_friend_screen_viewed',
        );
        expect(eventIndex, isNot(-1));
        final params = fakeAnalytics.loggedParams[eventIndex];
        expect(params, isNotNull);
        expect(params, containsPair('entry_path', 'contacts'));
      },
    );

    testWidgets('fires add_friend_tab_switched with tab manual when '
        'Enter Number tapped', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          fakeAnalytics: fakeAnalytics,
          fakeContactService: fakeContactService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enter Number'));
      await tester.pumpAndSettle();

      expect(fakeAnalytics.loggedEvents, contains('add_friend_tab_switched'));

      final eventIndex = fakeAnalytics.loggedEvents.indexOf(
        'add_friend_tab_switched',
      );
      expect(eventIndex, isNot(-1));
      final params = fakeAnalytics.loggedParams[eventIndex];
      expect(params, isNotNull);
      expect(params, containsPair('tab', 'manual'));
    });

    // ─── AC-6: Permission-denied fallback ────────────────────────────────

    group('permission-denied fallback (AC-6)', () {
      setUp(() {
        // Force the denied permission state for this group.
        fakeContactService.checkPermissionResult =
            ContactPermissionState.denied;
      });

      testWidgets('PermissionDeniedView is rendered with the '
          'Type-a-number-instead link wired', (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            fakeAnalytics: fakeAnalytics,
            fakeContactService: fakeContactService,
          ),
        );
        await tester.pumpAndSettle();

        // The contacts tab is still selected by default; its body
        // renders the permission-denied view with the fallback link.
        expect(find.text('Grant Permission'), findsOneWidget);
        expect(find.text('Type a number instead'), findsOneWidget);
        // The manual-entry helper text must NOT be visible yet (still
        // on the contacts tab body, just in the denied state).
        expect(
          find.text('Enter a 10-digit Indian mobile number.'),
          findsNothing,
        );
      });

      testWidgets('tapping Type a number instead switches the segmented '
          'control to the manual tab and shows the manual-entry UI', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildSubject(
            fakeAnalytics: fakeAnalytics,
            fakeContactService: fakeContactService,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Type a number instead'));
        await tester.pumpAndSettle();

        // Manual-entry tab body is now visible.
        expect(
          find.text('Enter a 10-digit Indian mobile number.'),
          findsOneWidget,
        );
        // The fallback link is gone because the contacts tab is no
        // longer being rendered.
        expect(find.text('Type a number instead'), findsNothing);
      });

      testWidgets('tapping Type a number instead fires add_friend_tab_switched '
          'with tab=manual and source=permission_denied', (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            fakeAnalytics: fakeAnalytics,
            fakeContactService: fakeContactService,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Type a number instead'));
        await tester.pumpAndSettle();

        expect(fakeAnalytics.loggedEvents, contains('add_friend_tab_switched'));

        // Find the LAST tab-switched event (there may be earlier ones
        // from initialisation paths) and assert its parameters.
        final indices = <int>[];
        for (var i = 0; i < fakeAnalytics.loggedEvents.length; i++) {
          if (fakeAnalytics.loggedEvents[i] == 'add_friend_tab_switched') {
            indices.add(i);
          }
        }
        expect(indices, isNotEmpty);
        final params = fakeAnalytics.loggedParams[indices.last];
        expect(params, isNotNull);
        expect(params, containsPair('tab', 'manual'));
        expect(
          params,
          containsPair('source', 'permission_denied'),
          reason:
              'The fallback path from the denied view must mark the '
              'source so funnel analytics can distinguish user-initiated '
              'tab taps from permission-denied recoveries.',
        );
      });

      testWidgets(
        'tapping Type a number instead fires friend_manual_entry_opened',
        (tester) async {
          await tester.pumpWidget(
            _buildSubject(
              fakeAnalytics: fakeAnalytics,
              fakeContactService: fakeContactService,
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Type a number instead'));
          await tester.pumpAndSettle();

          expect(
            fakeAnalytics.loggedEvents,
            contains('friend_manual_entry_opened'),
            reason:
                'The opened event must fire when the manual tab becomes '
                'active, regardless of whether the user reached it via '
                'the segmented control or the permission-denied fallback.',
          );
        },
      );

      testWidgets('permanently-denied state also exposes the fallback link', (
        tester,
      ) async {
        fakeContactService.checkPermissionResult =
            ContactPermissionState.deniedPermanently;

        await tester.pumpWidget(
          _buildSubject(
            fakeAnalytics: fakeAnalytics,
            fakeContactService: fakeContactService,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Open Settings'), findsOneWidget);
        expect(find.text('Type a number instead'), findsOneWidget);
      });
    });
  });
}
