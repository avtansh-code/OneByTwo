// DeepLinkHandler tests (FR-AC-03 + FR-AC-05).
//
// Verifies that the DeepLinkHandler dispatches each NotificationType to
// the correct DeepLinkTarget via the shared `notification_deep_links.dart`
// resolver. The actual platform navigation is covered by the resolver
// helper's pure-function tests; this suite focuses on the dispatch
// table (type → target) and the telemetry emission.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/routing/notification_deep_links.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/notifications/application/deep_link_handler.dart';
import 'package:onebytwo/features/notifications/domain/notification_payload.dart';
import 'package:onebytwo/features/shell/application/shell_navigation_controller.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class RecordingAnalyticsService implements AnalyticsService {
  final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    calls.add({'name': name, 'parameters': parameters});
  }
}

NotificationPayload _payload({
  NotificationType type = NotificationType.expenseAdded,
  String contextType = 'friendship',
  String contextId = 'uid-me_uid-other',
  String? itemId = 'expense-1',
  int? amountPaise = 60000,
}) {
  return NotificationPayload(
    type: type,
    contextType: contextType,
    contextId: contextId,
    itemId: itemId,
    title: 't',
    body: 'b',
    senderName: 'n',
    amountPaise: amountPaise,
    createdAt: DateTime.utc(2026, 6, 8),
  );
}

Future<void> _pumpHostAndDispatch({
  required WidgetTester tester,
  required ProviderContainer container,
  required DeepLinkHandler handler,
  required NotificationPayload payload,
  required String currentUid,
  required DeepLinkSource source,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => handler.handleDeepLink(
                  payload: payload,
                  context: context,
                  currentUid: currentUid,
                  source: source,
                ),
                child: const Text('go'),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
}

/// Advances past the SnackBar auto-hide so no `Timer` is pending at teardown.
/// The `DeepLinkUnavailable` / `DeepLinkGroupsComingSoon` paths show a snackbar
/// via `NotificationDeepLinks.navigate`.
Future<void> _drainSnackbar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late RecordingAnalyticsService analytics;
  late ProviderContainer container;
  late DeepLinkHandler handler;

  setUp(() {
    analytics = RecordingAnalyticsService();
    container = ProviderContainer(
      overrides: [analyticsServiceProvider.overrideWithValue(analytics)],
    );
    handler = DeepLinkHandler(container);
  });

  tearDown(() => container.dispose());

  group('DeepLinkHandler.resolveTarget — type → DeepLinkTarget', () {
    test('expense_added → expense detail target', () {
      final target = handler.resolveTarget(_payload(), currentUid: 'uid-me');
      expect(target, isA<DeepLinkExpenseDetail>());
      final t = target as DeepLinkExpenseDetail;
      expect(t.friendshipId, 'uid-me_uid-other');
      expect(t.expenseId, 'expense-1');
      expect(t.currentUid, 'uid-me');
      expect(t.otherUid, 'uid-other');
    });

    test('expense_edited → expense detail target', () {
      final target = handler.resolveTarget(
        _payload(type: NotificationType.expenseEdited),
        currentUid: 'uid-me',
      );
      expect(target, isA<DeepLinkExpenseDetail>());
    });

    test('expense_deleted → unavailable snackbar target', () {
      final target = handler.resolveTarget(
        _payload(type: NotificationType.expenseDeleted, itemId: null),
        currentUid: 'uid-me',
      );
      expect(target, isA<DeepLinkUnavailable>());
    });

    test('settlement_received → friend detail target', () {
      final target = handler.resolveTarget(
        _payload(type: NotificationType.settlementReceived),
        currentUid: 'uid-me',
      );
      expect(target, isA<DeepLinkFriendDetail>());
      final t = target as DeepLinkFriendDetail;
      expect(t.friendshipId, 'uid-me_uid-other');
      expect(t.currentUid, 'uid-me');
      expect(t.otherUid, 'uid-other');
    });

    test('reminder → friend detail target', () {
      final target = handler.resolveTarget(
        _payload(type: NotificationType.reminder, itemId: null),
        currentUid: 'uid-me',
      );
      expect(target, isA<DeepLinkFriendDetail>());
    });

    test('group_invite → "groups coming soon" target (forward-compat)', () {
      final target = handler.resolveTarget(
        _payload(
          type: NotificationType.groupInvite,
          contextType: 'group',
          contextId: 'group-7',
          itemId: null,
          amountPaise: null,
        ),
        currentUid: 'uid-me',
      );
      expect(target, isA<DeepLinkGroupsComingSoon>());
    });

    test('missing other-UID (malformed composite) → unavailable target', () {
      // contextId doesn't follow {uidA}_{uidB} pattern.
      final target = handler.resolveTarget(
        _payload(
          type: NotificationType.settlementReceived,
          contextId: 'not-a-valid-composite',
        ),
        currentUid: 'uid-me',
      );
      expect(target, isA<DeepLinkUnavailable>());
    });

    test('expense_added with missing itemId → unavailable target', () {
      final target = handler.resolveTarget(
        _payload(itemId: null),
        currentUid: 'uid-me',
      );
      expect(target, isA<DeepLinkUnavailable>());
    });
  });

  group('DeepLinkTarget.homeTabIndex — target → primary tab (FR-AC-05)', () {
    test('expense detail target → Friends tab (index 1)', () {
      final target = handler.resolveTarget(_payload(), currentUid: 'uid-me');
      expect(target.homeTabIndex, 1);
    });

    test('friend detail target → Friends tab (index 1)', () {
      final target = handler.resolveTarget(
        _payload(type: NotificationType.settlementReceived),
        currentUid: 'uid-me',
      );
      expect(target.homeTabIndex, 1);
    });

    test('unavailable target → Activity tab (index 3)', () {
      final target = handler.resolveTarget(
        _payload(type: NotificationType.expenseDeleted, itemId: null),
        currentUid: 'uid-me',
      );
      expect(target, isA<DeepLinkUnavailable>());
      expect(target.homeTabIndex, 3);
    });

    test('groups-coming-soon target → no tab switch (null)', () {
      final target = handler.resolveTarget(
        _payload(
          type: NotificationType.groupInvite,
          contextType: 'group',
          contextId: 'group-7',
          itemId: null,
          amountPaise: null,
        ),
        currentUid: 'uid-me',
      );
      expect(target, isA<DeepLinkGroupsComingSoon>());
      expect(target.homeTabIndex, isNull);
    });
  });

  group('DeepLinkHandler.handleDeepLink — tab selection (FR-AC-05)', () {
    // A keep-alive subscription so the autoDispose shell controller is not
    // disposed between the dispatch and the assertion.
    ProviderSubscription<int> keepAlive() {
      final sub = container.listen<int>(
        shellNavigationControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      return sub;
    }

    testWidgets('expense_added (background) selects the Friends tab (1)', (
      tester,
    ) async {
      keepAlive();
      await _pumpHostAndDispatch(
        tester: tester,
        container: container,
        handler: handler,
        payload: _payload(),
        currentUid: 'uid-me',
        source: DeepLinkSource.background,
      );
      expect(container.read(shellNavigationControllerProvider), 1);
    });

    testWidgets(
      'expense_added (foreground banner) selects the Friends tab (1) — AC-7',
      (tester) async {
        keepAlive();
        await _pumpHostAndDispatch(
          tester: tester,
          container: container,
          handler: handler,
          payload: _payload(),
          currentUid: 'uid-me',
          source: DeepLinkSource.foreground,
        );
        // The foreground in-app-banner tap switches tabs for consistency
        // with the background / cold-start paths (AC-7): the tab logic is
        // source-independent.
        expect(container.read(shellNavigationControllerProvider), 1);
      },
    );

    testWidgets(
      'settlement_received (cold start) selects the Friends tab (1)',
      (tester) async {
        keepAlive();
        await _pumpHostAndDispatch(
          tester: tester,
          container: container,
          handler: handler,
          payload: _payload(type: NotificationType.settlementReceived),
          currentUid: 'uid-me',
          source: DeepLinkSource.coldStart,
        );
        // Tab selected before the (root-navigator) push — FR-AC-05 ordering.
        expect(container.read(shellNavigationControllerProvider), 1);
      },
    );

    testWidgets('expense_deleted (unavailable) selects the Activity tab (3)', (
      tester,
    ) async {
      keepAlive();
      await _pumpHostAndDispatch(
        tester: tester,
        container: container,
        handler: handler,
        payload: _payload(type: NotificationType.expenseDeleted, itemId: null),
        currentUid: 'uid-me',
        source: DeepLinkSource.background,
      );
      await _drainSnackbar(tester);
      expect(container.read(shellNavigationControllerProvider), 3);
    });

    testWidgets('group_invite leaves the active tab unchanged (no switch)', (
      tester,
    ) async {
      keepAlive();
      // Seed the active tab at Profile (4) to prove no switch occurs.
      container.read(shellNavigationControllerProvider.notifier).selectTab(4);
      await _pumpHostAndDispatch(
        tester: tester,
        container: container,
        handler: handler,
        payload: _payload(
          type: NotificationType.groupInvite,
          contextType: 'group',
          contextId: 'group-7',
          itemId: null,
          amountPaise: null,
        ),
        currentUid: 'uid-me',
        source: DeepLinkSource.background,
      );
      await _drainSnackbar(tester);
      expect(container.read(shellNavigationControllerProvider), 4);
    });
  });

  group('DeepLinkHandler.handleDeepLink — telemetry', () {
    testWidgets('emits fcm_notification_tapped with notification_type + '
        'source on foreground dispatch', (tester) async {
      await _pumpHostAndDispatch(
        tester: tester,
        container: container,
        handler: handler,
        payload: _payload(),
        currentUid: 'uid-me',
        source: DeepLinkSource.foreground,
      );

      // The dispatch may push a route; for the telemetry assertion we
      // only care that the event was logged.
      expect(analytics.calls, isNotEmpty);
      final call = analytics.calls.first;
      expect(call['name'], 'fcm_notification_tapped');
      final params = call['parameters'] as Map<String, Object>?;
      expect(params, isNotNull);
      expect(params!['notification_type'], 'expense_added');
      expect(params['source'], 'foreground');
    });

    testWidgets('source label is `background` for backgrounded-app tap', (
      tester,
    ) async {
      await _pumpHostAndDispatch(
        tester: tester,
        container: container,
        handler: handler,
        payload: _payload(type: NotificationType.reminder, itemId: null),
        currentUid: 'uid-me',
        source: DeepLinkSource.background,
      );

      final params =
          analytics.calls.first['parameters'] as Map<String, Object>?;
      expect(params!['source'], 'background');
      expect(params['notification_type'], 'reminder');
    });

    testWidgets('source label is `cold_start` for cold-start dispatch', (
      tester,
    ) async {
      await _pumpHostAndDispatch(
        tester: tester,
        container: container,
        handler: handler,
        payload: _payload(type: NotificationType.settlementReceived),
        currentUid: 'uid-me',
        source: DeepLinkSource.coldStart,
      );

      final params =
          analytics.calls.first['parameters'] as Map<String, Object>?;
      expect(params!['source'], 'cold_start');
      expect(params['notification_type'], 'settlement_received');
    });

    testWidgets('includes target_tab=friends for an expense detail dispatch', (
      tester,
    ) async {
      await _pumpHostAndDispatch(
        tester: tester,
        container: container,
        handler: handler,
        payload: _payload(),
        currentUid: 'uid-me',
        source: DeepLinkSource.background,
      );
      final params =
          analytics.calls.first['parameters'] as Map<String, Object>?;
      expect(params!['target_tab'], 'friends');
    });

    testWidgets('target_tab=activity for an unavailable (expense_deleted) '
        'dispatch', (tester) async {
      await _pumpHostAndDispatch(
        tester: tester,
        container: container,
        handler: handler,
        payload: _payload(type: NotificationType.expenseDeleted, itemId: null),
        currentUid: 'uid-me',
        source: DeepLinkSource.background,
      );
      await _drainSnackbar(tester);
      final params =
          analytics.calls.first['parameters'] as Map<String, Object>?;
      expect(params!['target_tab'], 'activity');
    });

    testWidgets('target_tab=none for a group_invite dispatch', (tester) async {
      await _pumpHostAndDispatch(
        tester: tester,
        container: container,
        handler: handler,
        payload: _payload(
          type: NotificationType.groupInvite,
          contextType: 'group',
          contextId: 'group-7',
          itemId: null,
          amountPaise: null,
        ),
        currentUid: 'uid-me',
        source: DeepLinkSource.background,
      );
      await _drainSnackbar(tester);
      final params =
          analytics.calls.first['parameters'] as Map<String, Object>?;
      expect(params!['target_tab'], 'none');
    });

    testWidgets('fcm_notification_tapped carries no uid / friendship composite '
        '(PII guard, ADR-0013)', (tester) async {
      await _pumpHostAndDispatch(
        tester: tester,
        container: container,
        handler: handler,
        payload: _payload(),
        currentUid: 'uid-me',
        source: DeepLinkSource.background,
      );
      final params =
          analytics.calls.first['parameters'] as Map<String, Object>?;
      expect(params, isNotNull);
      expect(params!.keys, isNot(contains('uid')));
      expect(params.keys, isNot(contains('friendship_id')));
      for (final value in params.values) {
        final s = value.toString();
        expect(s, isNot(contains('uid-me')));
        expect(s, isNot(contains('uid-other')));
      }
    });
  });
}
