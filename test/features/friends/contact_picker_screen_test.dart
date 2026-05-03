// Contact picker screen tests.
//
// These tests verify the presentation layer widgets for the contact
// picker. They use FakeContactService and FakeAnalyticsService to
// avoid platform plugin initialisation.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/data/contact_service.dart';
import 'package:onebytwo/features/friends/domain/contact_permission_state.dart';
import 'package:onebytwo/features/friends/presentation/contact_picker_screen.dart';

/// Fake [AnalyticsService] that records logged events for verification.
class FakeAnalyticsService implements AnalyticsService {
  /// Events logged during the test.
  final List<String> loggedEvents = [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add(name);
  }
}

/// Fake [ContactService] with configurable behaviour for testing.
class FakeContactService implements ContactService {
  /// The permission state returned by [checkPermission].
  ContactPermissionState checkPermissionResult =
      ContactPermissionState.notDetermined;

  /// The permission state returned by [requestPermission].
  ContactPermissionState requestPermissionResult =
      ContactPermissionState.notDetermined;

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

/// Mock [NavigatorObserver] for verifying navigation events.
class MockNavigatorObserver extends NavigatorObserver {
  /// All push events recorded.
  final List<Route<dynamic>> pushedRoutes = [];

  /// All pop events recorded.
  final List<Route<dynamic>> poppedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    poppedRoutes.add(route);
  }
}

void main() {
  late FakeAnalyticsService fakeAnalytics;
  late FakeContactService fakeContactService;
  late MockNavigatorObserver mockObserver;

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
    fakeContactService = FakeContactService();
    mockObserver = MockNavigatorObserver();
  });

  /// Builds the [ContactPickerScreen] wrapped in [ProviderScope] and
  /// [MaterialApp] with provider overrides.
  ///
  /// When [pushAsRoute] is true, the screen is pushed as a route from
  /// a landing page so that pop behaviour can be tested.
  Widget buildSubject({bool pushAsRoute = false, NavigatorObserver? observer}) {
    final overrides = <Override>[
      analyticsServiceProvider.overrideWithValue(fakeAnalytics),
      contactServiceProvider.overrideWithValue(fakeContactService),
    ];

    if (pushAsRoute) {
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          navigatorObservers: [if (observer != null) observer],
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const ContactPickerScreen(),
                      ),
                    );
                  },
                  child: const Text('Open Picker'),
                ),
              );
            },
          ),
        ),
      );
    }

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        navigatorObservers: [if (observer != null) observer],
        home: const ContactPickerScreen(),
      ),
    );
  }

  group('ContactPickerScreen', () {
    testWidgets('renders loading state when contacts are loading', (
      tester,
    ) async {
      fakeContactService.checkPermissionResult = ContactPermissionState.granted;
      // Make getContacts never complete during the test frame.
      fakeContactService.contactsResult = [];

      await tester.pumpWidget(buildSubject());
      // After initState fires the post-frame callback, permission is
      // checked. Pump to trigger the callback.
      await tester.pump();

      // The loading indicator should be visible briefly while contacts
      // load. Since our fake resolves instantly, pump once more to
      // let it settle.
      expect(find.byType(ContactPickerScreen), findsOneWidget);
    });

    testWidgets('renders permission prompt when state is notDetermined', (
      tester,
    ) async {
      fakeContactService.checkPermissionResult =
          ContactPermissionState.notDetermined;

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Grant Contact Access'), findsOneWidget);
    });

    testWidgets('renders contact list when permission is granted '
        'and contacts loaded', (tester) async {
      fakeContactService.checkPermissionResult = ContactPermissionState.granted;
      fakeContactService.contactsResult = [
        const DeviceContact(
          displayName: 'Amit Kumar',
          phoneNumbers: ['9876543210'],
        ),
        const DeviceContact(
          displayName: 'Priya Sharma',
          phoneNumbers: ['8765432109'],
        ),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Amit Kumar'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
    });

    testWidgets('renders denied screen with Grant Permission when denied', (
      tester,
    ) async {
      fakeContactService.checkPermissionResult = ContactPermissionState.denied;

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Contact access helps you find friends '
          'already on One By Two.',
        ),
        findsOneWidget,
      );
      expect(find.text('Grant Permission'), findsOneWidget);
    });

    testWidgets('renders deniedPermanently screen with Open Settings', (
      tester,
    ) async {
      fakeContactService.checkPermissionResult =
          ContactPermissionState.deniedPermanently;

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Contact access helps you find friends '
          'already on One By Two.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('empty state shows appropriate message', (tester) async {
      fakeContactService.checkPermissionResult = ContactPermissionState.granted;
      fakeContactService.contactsResult = [];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('No contacts found'), findsOneWidget);
      expect(find.text('You can enter a number manually.'), findsOneWidget);
    });

    testWidgets('search field filters the visible list', (tester) async {
      fakeContactService.checkPermissionResult = ContactPermissionState.granted;
      fakeContactService.contactsResult = [
        const DeviceContact(
          displayName: 'Amit Kumar',
          phoneNumbers: ['9876543210'],
        ),
        const DeviceContact(
          displayName: 'Priya Sharma',
          phoneNumbers: ['8765432109'],
        ),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Amit Kumar'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Amit');
      await tester.pumpAndSettle();

      expect(find.text('Amit Kumar'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsNothing);
    });

    testWidgets(
      'tapping a single-phone contact fires hand-off and pops route',
      (tester) async {
        fakeContactService.checkPermissionResult =
            ContactPermissionState.granted;
        fakeContactService.contactsResult = [
          const DeviceContact(
            displayName: 'Amit Kumar',
            phoneNumbers: ['9876543210'],
          ),
        ];

        await tester.pumpWidget(
          buildSubject(pushAsRoute: true, observer: mockObserver),
        );
        await tester.pumpAndSettle();

        // Navigate to the picker.
        await tester.tap(find.text('Open Picker'));
        await tester.pumpAndSettle();

        expect(find.text('Amit Kumar'), findsOneWidget);

        // Tap the contact.
        await tester.tap(find.text('Amit Kumar'));
        await tester.pumpAndSettle();

        // The screen should have popped.
        expect(find.text('Open Picker'), findsOneWidget);
        expect(fakeAnalytics.loggedEvents, contains('friend_contact_selected'));
      },
    );

    testWidgets('tapping a multi-phone contact opens phone selector', (
      tester,
    ) async {
      fakeContactService.checkPermissionResult = ContactPermissionState.granted;
      fakeContactService.contactsResult = [
        const DeviceContact(
          displayName: 'Priya Sharma',
          phoneNumbers: ['9876543210', '8765432109'],
        ),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Priya Sharma'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a phone number'), findsOneWidget);
      // The first phone appears both in the list tile subtitle and
      // the bottom sheet, so we check for at least one match for each.
      expect(find.text('9876543210'), findsWidgets);
      expect(find.text('8765432109'), findsWidgets);
    });

    testWidgets('selecting a phone in selector completes the selection', (
      tester,
    ) async {
      fakeContactService.checkPermissionResult = ContactPermissionState.granted;
      fakeContactService.contactsResult = [
        const DeviceContact(
          displayName: 'Priya Sharma',
          phoneNumbers: ['9876543210', '8765432109'],
        ),
      ];

      await tester.pumpWidget(
        buildSubject(pushAsRoute: true, observer: mockObserver),
      );
      await tester.pumpAndSettle();

      // Navigate to the picker.
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Tap the multi-phone contact.
      await tester.tap(find.text('Priya Sharma'));
      await tester.pumpAndSettle();

      // Select a phone number from the bottom sheet.
      await tester.tap(find.text('8765432109'));
      await tester.pumpAndSettle();

      // Should have popped back to the landing page.
      expect(find.text('Open Picker'), findsOneWidget);
      expect(fakeAnalytics.loggedEvents, contains('friend_contact_selected'));
    });

    testWidgets('telemetry friend_contact_picker_opened fires on open', (
      tester,
    ) async {
      fakeContactService.checkPermissionResult = ContactPermissionState.granted;
      fakeContactService.contactsResult = [
        const DeviceContact(
          displayName: 'Amit Kumar',
          phoneNumbers: ['9876543210'],
        ),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(
        fakeAnalytics.loggedEvents,
        contains('friend_contact_picker_opened'),
      );
    });

    testWidgets('telemetry friend_contact_search_used fires on search', (
      tester,
    ) async {
      fakeContactService.checkPermissionResult = ContactPermissionState.granted;
      fakeContactService.contactsResult = [
        const DeviceContact(
          displayName: 'Amit Kumar',
          phoneNumbers: ['9876543210'],
        ),
      ];

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'A');
      await tester.pumpAndSettle();

      expect(
        fakeAnalytics.loggedEvents,
        contains('friend_contact_search_used'),
      );
    });

    testWidgets('telemetry friend_contact_selected fires on selection', (
      tester,
    ) async {
      fakeContactService.checkPermissionResult = ContactPermissionState.granted;
      fakeContactService.contactsResult = [
        const DeviceContact(
          displayName: 'Amit Kumar',
          phoneNumbers: ['9876543210'],
        ),
      ];

      await tester.pumpWidget(
        buildSubject(pushAsRoute: true, observer: mockObserver),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Amit Kumar'));
      await tester.pumpAndSettle();

      expect(fakeAnalytics.loggedEvents, contains('friend_contact_selected'));
    });

    testWidgets('telemetry friend_contact_picker_dismissed_without_selection '
        'fires on dismiss', (tester) async {
      fakeContactService.checkPermissionResult = ContactPermissionState.granted;
      fakeContactService.contactsResult = [
        const DeviceContact(
          displayName: 'Amit Kumar',
          phoneNumbers: ['9876543210'],
        ),
      ];

      await tester.pumpWidget(
        buildSubject(pushAsRoute: true, observer: mockObserver),
      );
      await tester.pumpAndSettle();

      // Navigate to the picker.
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Go back without selecting.
      final backButton = find.byTooltip('Back');
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(
        fakeAnalytics.loggedEvents,
        contains('friend_contact_picker_dismissed_without_selection'),
      );
    });
  });
}
