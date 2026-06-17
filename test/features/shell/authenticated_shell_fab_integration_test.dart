// AuthenticatedShell — FAB integration tests.
//
// Covers the end-to-end wiring of:
//   - persistent FAB → `fab_tapped` telemetry with source_tab
//   - persistent FAB → opens AddExpenseContextPickerSheet
//   - picker → tap a friend → AddExpenseBottomSheet mounts
//
// AC coverage: AC-4 (FAB tap on Home fires source_tab=home) +
// AC-5 (parameterised across friends/groups/activity/profile) + the
// full FAB→picker→AddExpenseBottomSheet flow.
//
// PII guard: every `fab_tapped` payload MUST carry only `source_tab`
// per `docs/design/07-technical/telemetry-plan.md` §1.3 line 88.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/services/image_picker_service.dart';
import 'package:onebytwo/core/widgets/nav/obt_bottom_nav.dart';
import 'package:onebytwo/core/widgets/nav/obt_floating_action_button.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/data/receipt_storage_service.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/presentation/add_expense_bottom_sheet.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/shell/application/shell_telemetry.dart';
import 'package:onebytwo/features/shell/presentation/add_expense_context_picker_sheet.dart';
import 'package:onebytwo/features/shell/presentation/authenticated_shell.dart';

import '../expenses/helpers/fake_services.dart';

// ---------------------------------------------------------------------------
// Fakes + helpers
// ---------------------------------------------------------------------------

class _FakeAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object>? parameters})> events =
      <({String name, Map<String, Object>? parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }
}

/// Minimal `ExpenseRepository` fake — see picker test for rationale.
class _FakeExpenseRepository implements ExpenseRepository {
  @override
  Future<String> createExpense({
    required String friendshipId,
    required ExpenseDoc doc,
  }) async => 'fake-expense-id';

  @override
  String newExpenseId({required String friendshipId}) => 'fake-expense-id';

  @override
  Future<void> createExpenseAtId({
    required String friendshipId,
    required String expenseId,
    required ExpenseDoc doc,
  }) async {}

  @override
  Future<void> updateExpense({
    required String friendshipId,
    required String expenseId,
    required Map<String, dynamic> updates,
  }) async {}

  @override
  Future<void> softDeleteExpense({
    required String friendshipId,
    required String expenseId,
  }) async {}

  @override
  Stream<List<ExpenseDoc>> watchExpensesByFriendship({
    required String friendshipId,
    int limit = 5,
  }) => const Stream<List<ExpenseDoc>>.empty();

  @override
  Future<List<ExpenseDoc>> fetchExpensesInMonth({
    required String friendshipId,
    required DateTime monthStartUtc,
  }) async => const [];
}

class _TabStub extends StatelessWidget {
  const _TabStub({required this.label, super.key});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tab: $label')),
      body: Center(child: Text('content of $label')),
    );
  }
}

List<Widget> _stubTabs() {
  return const <Widget>[
    _TabStub(key: ValueKey('tab-0'), label: 'home'),
    _TabStub(key: ValueKey('tab-1'), label: 'friends'),
    _TabStub(key: ValueKey('tab-2'), label: 'groups'),
    _TabStub(key: ValueKey('tab-3'), label: 'activity'),
    _TabStub(key: ValueKey('tab-4'), label: 'profile'),
  ];
}

FriendListItem _friend({
  required String friendshipId,
  required String otherUserId,
  required String displayName,
}) {
  return FriendListItem(
    friendshipId: friendshipId,
    otherUserId: otherUserId,
    displayName: displayName,
    photoUrl: null,
    netBalancePaise: 0,
  );
}

Widget _buildShell({
  required _FakeAnalyticsService analytics,
  required AsyncValue<List<FriendListItem>> friendsState,
  String currentUid = 'test-uid',
}) {
  return ProviderScope(
    overrides: <Override>[
      analyticsServiceProvider.overrideWithValue(analytics),
      currentUserIdProvider.overrideWithValue(currentUid),
      // Same rationale as the picker test — fake the Firebase-backed
      // providers so AddExpenseBottomSheet can mount on the
      // post-friend-tap leg without initialising Firebase.
      expenseRepositoryProvider.overrideWithValue(_FakeExpenseRepository()),
      receiptStorageServiceProvider.overrideWithValue(
        FakeReceiptStorageService(),
      ),
      imagePickerServiceProvider.overrideWithValue(FakeImagePickerService()),
      friendsListProvider.overrideWith((ref) {
        switch (friendsState) {
          case AsyncData(:final value):
            return Stream<List<FriendListItem>>.value(value);
          case AsyncError(:final error, :final stackTrace):
            return Stream<List<FriendListItem>>.error(error, stackTrace);
          default:
            return const Stream<List<FriendListItem>>.empty();
        }
      }),
    ],
    child: MaterialApp(
      home: AuthenticatedShell(tabContentOverride: _stubTabs()),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeAnalyticsService analytics;

  setUp(() {
    analytics = _FakeAnalyticsService();
  });

  group('AuthenticatedShell — FAB tap fab_tapped telemetry (AC-4, AC-5)', () {
    final tabExpectations = <(int, String)>[
      (0, tabLabelHome),
      (1, tabLabelFriends),
      (2, tabLabelGroups),
      (3, tabLabelActivity),
      (4, tabLabelProfile),
    ];

    for (final pair in tabExpectations) {
      final tabIndex = pair.$1;
      final expectedLabel = pair.$2;
      testWidgets('tap FAB on tab $tabIndex fires fab_tapped with source_tab '
          '"$expectedLabel"', (tester) async {
        await tester.pumpWidget(
          _buildShell(
            analytics: analytics,
            friendsState: const AsyncData<List<FriendListItem>>(
              <FriendListItem>[],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to the target tab (the bottom-nav tap fires its own
        // `bottom_nav_tab_selected` event; we count that out below).
        if (tabIndex != 0) {
          await tester.tap(find.text(OBTBottomNav.tabs[tabIndex].label));
          await tester.pumpAndSettle();
        }

        // Capture event count BEFORE the FAB tap so we can isolate
        // the fab_tapped event we just triggered.
        final beforeCount = analytics.events.length;

        // Tap the FAB.
        await tester.tap(find.byType(OBTFloatingActionButton));
        await tester.pumpAndSettle();

        // EXACTLY one new event fired and it is `fab_tapped` with the
        // expected source_tab.
        expect(
          analytics.events.length - beforeCount,
          1,
          reason: 'expected exactly one new analytics event for the FAB tap',
        );
        final fabEvent = analytics.events.last;
        expect(fabEvent.name, fabTappedEvent);
        expect(fabEvent.parameters, isNotNull);
        expect(fabEvent.parameters![sourceTabParam], expectedLabel);
        expect(
          fabEvent.parameters!.keys.toSet(),
          <String>{sourceTabParam},
          reason: 'PII guard: fab_tapped payload must contain only source_tab',
        );
      });
    }
  });

  group('AuthenticatedShell — FAB opens AddExpenseContextPickerSheet', () {
    testWidgets('tap FAB on Home opens the picker as a modal bottom sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildShell(
          analytics: analytics,
          friendsState: const AsyncData<List<FriendListItem>>(
            <FriendListItem>[],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No picker yet.
      expect(find.byType(AddExpenseContextPickerSheet), findsNothing);

      // Tap the FAB.
      await tester.tap(find.byType(OBTFloatingActionButton));
      await tester.pumpAndSettle();

      // The picker is now mounted.
      expect(find.byType(AddExpenseContextPickerSheet), findsOneWidget);
    });
  });

  group(
    'AuthenticatedShell — full FAB → picker → AddExpenseBottomSheet flow',
    () {
      testWidgets(
        'tap FAB → tap friend in picker → AddExpenseBottomSheet mounts with '
        'correct args',
        (tester) async {
          final friends = <FriendListItem>[
            _friend(
              friendshipId: 'uid-a_uid-me',
              otherUserId: 'uid-a',
              displayName: 'Alice',
            ),
          ];

          await tester.pumpWidget(
            _buildShell(
              analytics: analytics,
              friendsState: AsyncData<List<FriendListItem>>(friends),
            ),
          );
          await tester.pumpAndSettle();

          // Tap the FAB on Home.
          await tester.tap(find.byType(OBTFloatingActionButton));
          await tester.pumpAndSettle();

          // Picker is up.
          expect(find.byType(AddExpenseContextPickerSheet), findsOneWidget);

          // Tap Alice's row.
          await tester.tap(find.text('Alice'));
          await tester.pumpAndSettle();

          // Picker dismissed; AddExpenseBottomSheet mounted with Alice's args.
          expect(find.byType(AddExpenseContextPickerSheet), findsNothing);
          expect(find.byType(AddExpenseBottomSheet), findsOneWidget);
          final sheet = tester.widget<AddExpenseBottomSheet>(
            find.byType(AddExpenseBottomSheet),
          );
          expect(sheet.friendshipId, 'uid-a_uid-me');
          expect(sheet.currentUserUid, 'test-uid');
          expect(sheet.otherUserUid, 'uid-a');

          // Telemetry trail: fab_tapped, then expense_context_selected.
          final fabEvents = analytics.events
              .where((e) => e.name == fabTappedEvent)
              .toList();
          final ctxEvents = analytics.events
              .where((e) => e.name == expenseContextSelectedEvent)
              .toList();
          expect(fabEvents, hasLength(1));
          expect(ctxEvents, hasLength(1));
          expect(
            ctxEvents.single.parameters![contextTypeParam],
            contextTypeFriend,
          );
        },
      );
    },
  );
}
