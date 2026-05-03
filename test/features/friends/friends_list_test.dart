// Friends list tests.
//
// These tests verify the "Add friend" button presence, navigation
// behaviour, and telemetry on the friends list screen.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/data/contact_service.dart';
import 'package:onebytwo/features/friends/domain/contact_permission_state.dart';
import 'package:onebytwo/features/friends/presentation/contact_picker_screen.dart';
import 'package:onebytwo/features/friends/presentation/friends_list_screen.dart';

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

/// Fake [ContactService] for widget tests.
class FakeContactService implements ContactService {
  @override
  Future<ContactPermissionState> checkPermission() async =>
      ContactPermissionState.notDetermined;

  @override
  Future<ContactPermissionState> requestPermission() async =>
      ContactPermissionState.notDetermined;

  @override
  Future<List<DeviceContact>> getContacts() async => [];

  @override
  Future<void> openSettings() async {}
}

/// Mock [NavigatorObserver] for verifying navigation events.
class MockNavigatorObserver extends NavigatorObserver {
  /// All push events recorded.
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }
}

void main() {
  late FakeAnalyticsService fakeAnalytics;
  late FakeContactService fakeContactService;

  setUp(() {
    fakeAnalytics = FakeAnalyticsService();
    fakeContactService = FakeContactService();
  });

  Widget buildSubject({NavigatorObserver? observer}) {
    return ProviderScope(
      overrides: [
        analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        contactServiceProvider.overrideWithValue(fakeContactService),
      ],
      child: MaterialApp(
        navigatorObservers: [if (observer != null) observer],
        home: const FriendsListScreen(),
      ),
    );
  }

  group('FriendsListScreen', () {
    testWidgets('Add friend button is present', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byTooltip('Add friend'), findsOneWidget);
    });

    testWidgets('empty state text is displayed', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('No friends yet'), findsOneWidget);
      expect(
        find.text('Add a friend and start sharing expenses.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping Add friend triggers navigation', (tester) async {
      final observer = MockNavigatorObserver();

      await tester.pumpWidget(buildSubject(observer: observer));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Verify that the ContactPickerScreen is now displayed.
      expect(find.byType(ContactPickerScreen), findsOneWidget);
    });

    testWidgets('telemetry friend_add_button_tapped fires on tap', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(
        fakeAnalytics.loggedEvents,
        contains('friend_add_button_tapped'),
      );
    });
  });
}
