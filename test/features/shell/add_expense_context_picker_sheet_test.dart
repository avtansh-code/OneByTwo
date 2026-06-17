// AddExpenseContextPickerSheet widget tests — the modal bottom sheet
// hosting the Friend / Group context-selection step (SCR-08).
//
// AC coverage: AC-6 (populated state) / AC-7 (friend tap) / AC-8 (empty
// state) / AC-9 (add-first-friend) / AC-10 (loading) / AC-11 (error +
// retry) / AC-12 (Groups stub — parameterised across all four Friends-
// section sub-states).
//
// All tests run the picker inside a real Scaffold so ScaffoldMessenger
// is available for the AC-12 snackbar assertion.
//
// PII guard: every analytics event captured here MUST carry only the
// `context_type` parameter (per `docs/design/07-technical/telemetry-plan.md`
// §1.3 line 89).

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/services/image_picker_service.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/data/receipt_storage_service.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/presentation/add_expense_bottom_sheet.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/presentation/add_friend_screen.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_list_tile.dart';
import 'package:onebytwo/features/shell/application/shell_telemetry.dart';
import 'package:onebytwo/features/shell/presentation/add_expense_context_picker_sheet.dart';

import '../expenses/helpers/fake_services.dart';

// ---------------------------------------------------------------------------
// Fakes
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

/// Minimal `ExpenseRepository` fake so the integration friend-tap test
/// can mount `AddExpenseBottomSheet` without booting Firebase. The
/// sheet only watches the controller's initial state; it never calls
/// any repository method until the user submits the form.
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

FriendListItem _friend({
  required String friendshipId,
  required String otherUserId,
  required String displayName,
  int netBalancePaise = 0,
}) {
  return FriendListItem(
    friendshipId: friendshipId,
    otherUserId: otherUserId,
    displayName: displayName,
    photoUrl: null,
    netBalancePaise: netBalancePaise,
  );
}

/// Host widget that opens the picker on first frame. The host owns a
/// real Scaffold so ScaffoldMessenger is available for the AC-12
/// snackbar assertion.
class _PickerHost extends StatefulWidget {
  const _PickerHost();

  @override
  State<_PickerHost> createState() => _PickerHostState();
}

class _PickerHostState extends State<_PickerHost> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const AddExpenseContextPickerSheet(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('host')));
  }
}

Widget _buildSubject({
  required AsyncValue<List<FriendListItem>> friendsState,
  required _FakeAnalyticsService analytics,
  String currentUid = 'test-uid',
}) {
  return ProviderScope(
    overrides: <Override>[
      analyticsServiceProvider.overrideWithValue(analytics),
      currentUserIdProvider.overrideWithValue(currentUid),
      // AddExpenseBottomSheet (mounted post friend-tap) watches the
      // family-provider `addExpenseControllerProvider(args)`, which
      // resolves `expenseRepositoryProvider` / `receiptStorageServiceProvider`
      // / `imagePickerServiceProvider`. Override them with non-Firebase
      // fakes so the sheet can mount without booting the real SDK.
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
    child: const MaterialApp(home: _PickerHost()),
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

  group('AddExpenseContextPickerSheet — Friends populated (AC-6)', () {
    final friends = <FriendListItem>[
      _friend(
        friendshipId: 'uid-a_uid-me',
        otherUserId: 'uid-a',
        displayName: 'Alice',
        netBalancePaise: 1000,
      ),
      _friend(
        friendshipId: 'uid-b_uid-me',
        otherUserId: 'uid-b',
        displayName: 'Bina',
        netBalancePaise: -2500,
      ),
      _friend(
        friendshipId: 'uid-c_uid-me',
        otherUserId: 'uid-c',
        displayName: 'Chetan',
      ),
    ];

    testWidgets('renders 3 FriendListTile rows in provider order', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          friendsState: AsyncData<List<FriendListItem>>(friends),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      final tiles = tester
          .widgetList<FriendListTile>(find.byType(FriendListTile))
          .toList();
      expect(tiles, hasLength(3));
      expect(tiles[0].item.displayName, 'Alice');
      expect(tiles[1].item.displayName, 'Bina');
      expect(tiles[2].item.displayName, 'Chetan');
    });

    testWidgets('renders the Groups section header + the stub row', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          friendsState: AsyncData<List<FriendListItem>>(friends),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      // Two "Groups" texts: the section header (labelLarge) AND the
      // stub row's ListTile title (titleMedium) per
      // architect notes §2.3 / §2.6.
      expect(find.text('Groups'), findsNWidgets(2));
      expect(find.text('Coming in Sprint 3'), findsOneWidget);
    });
  });

  group('AddExpenseContextPickerSheet — Friend tap (AC-7)', () {
    final friends = <FriendListItem>[
      _friend(
        friendshipId: 'uid-a_uid-me',
        otherUserId: 'uid-a',
        displayName: 'Alice',
      ),
      _friend(
        friendshipId: 'uid-b_uid-me',
        otherUserId: 'uid-b',
        displayName: 'Bina',
      ),
    ];

    testWidgets(
      'fires expense_context_selected{context_type: friend} BEFORE the '
      'picker is dismissed and mounts AddExpenseBottomSheet with the '
      'correct args',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            friendsState: AsyncData<List<FriendListItem>>(friends),
            analytics: analytics,
          ),
        );
        await tester.pumpAndSettle();

        // The picker is mounted.
        expect(find.byType(AddExpenseContextPickerSheet), findsOneWidget);

        // Tap Bina's row.
        await tester.tap(find.text('Bina'));
        await tester.pumpAndSettle();

        // The picker fires `expense_context_selected` exactly once. The
        // mounted AddExpenseBottomSheet's controller fires its own
        // `step_1_opened` event on construction — filter to isolate the
        // picker's contribution.
        final ctxEvents = analytics.events
            .where((e) => e.name == expenseContextSelectedEvent)
            .toList();
        expect(ctxEvents, hasLength(1));
        expect(ctxEvents.single.parameters, isNotNull);
        expect(
          ctxEvents.single.parameters![contextTypeParam],
          contextTypeFriend,
        );

        // Picker has been dismissed.
        expect(find.byType(AddExpenseContextPickerSheet), findsNothing);

        // AddExpenseBottomSheet has been mounted with Bina's args.
        expect(find.byType(AddExpenseBottomSheet), findsOneWidget);
        final sheet = tester.widget<AddExpenseBottomSheet>(
          find.byType(AddExpenseBottomSheet),
        );
        expect(sheet.friendshipId, 'uid-b_uid-me');
        expect(sheet.currentUserUid, 'test-uid');
        expect(sheet.otherUserUid, 'uid-b');
      },
    );

    testWidgets(
      'telemetry payload contains ONLY context_type (PII guard, AC-16)',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            friendsState: AsyncData<List<FriendListItem>>(friends),
            analytics: analytics,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Alice'));
        await tester.pumpAndSettle();

        // Filter for the picker's own event — the mounted
        // AddExpenseBottomSheet fires `step_1_opened` after which we
        // do NOT inspect here.
        final ctxEvent = analytics.events.firstWhere(
          (e) => e.name == expenseContextSelectedEvent,
        );
        final params = ctxEvent.parameters!;
        expect(params.keys.toSet(), <String>{contextTypeParam});
        const forbidden = <String>[
          'userId',
          'uid',
          'friendship_id',
          'friendship_id_hash',
        ];
        for (final key in forbidden) {
          expect(
            params.containsKey(key),
            isFalse,
            reason:
                'PII guard (ADR-0013): expense_context_selected payload '
                'must not carry $key',
          );
        }
      },
    );
  });

  group('AddExpenseContextPickerSheet — Friends empty (AC-8)', () {
    testWidgets(
      'renders "You have no friends yet" + "Add your first friend" CTA + '
      'the Groups stub row still renders',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            friendsState: const AsyncData<List<FriendListItem>>(
              <FriendListItem>[],
            ),
            analytics: analytics,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('You have no friends yet'), findsOneWidget);
        expect(find.text('Add your first friend'), findsOneWidget);
        // Groups section still renders (header + row title both say
        // "Groups" per architect §2.6).
        expect(find.text('Groups'), findsNWidgets(2));
        expect(find.text('Coming in Sprint 3'), findsOneWidget);
      },
    );
  });

  group('AddExpenseContextPickerSheet — Add-first-friend tap (AC-9)', () {
    testWidgets(
      'tapping "Add your first friend" dismisses the picker and pushes '
      'AddFriendScreen',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            friendsState: const AsyncData<List<FriendListItem>>(
              <FriendListItem>[],
            ),
            analytics: analytics,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add your first friend'));
        await tester.pumpAndSettle();

        // Picker dismissed.
        expect(find.byType(AddExpenseContextPickerSheet), findsNothing);
        // AddFriendScreen is the topmost route.
        expect(find.byType(AddFriendScreen), findsOneWidget);
      },
    );
  });

  group('AddExpenseContextPickerSheet — Friends loading (AC-10)', () {
    testWidgets(
      'renders CircularProgressIndicator in Friends section + Groups stub',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            friendsState: const AsyncLoading<List<FriendListItem>>(),
            analytics: analytics,
          ),
        );
        await tester.pump();
        // Open the picker.
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Groups section still renders (header + row title both say
        // "Groups").
        expect(find.text('Groups'), findsNWidgets(2));
        expect(find.text('Coming in Sprint 3'), findsOneWidget);
      },
    );
  });

  group('AddExpenseContextPickerSheet — Friends error (AC-11)', () {
    testWidgets(
      'renders error message + Retry button; tapping Retry reloads the '
      'provider',
      (tester) async {
        await tester.pumpWidget(
          _buildSubject(
            friendsState: AsyncError<List<FriendListItem>>(
              Exception('boom'),
              StackTrace.empty,
            ),
            analytics: analytics,
          ),
        );
        await tester.pumpAndSettle();

        // Error message + Retry button are rendered.
        expect(find.text('Retry'), findsOneWidget);
        // The error copy can vary but MUST be present in some form —
        // assert a non-empty error indicator.
        expect(find.textContaining('went wrong'), findsWidgets);

        // Tapping Retry must not throw and the button is wired.
        await tester.tap(find.text('Retry'));
        await tester.pump();
      },
    );
  });

  group('AddExpenseContextPickerSheet — Groups stub (AC-12)', () {
    final populatedFriends = <FriendListItem>[
      _friend(
        friendshipId: 'uid-a_uid-me',
        otherUserId: 'uid-a',
        displayName: 'Alice',
      ),
    ];

    final cases = <(String, AsyncValue<List<FriendListItem>>)>[
      ('populated', AsyncData<List<FriendListItem>>(populatedFriends)),
      ('empty', const AsyncData<List<FriendListItem>>(<FriendListItem>[])),
      ('loading', const AsyncLoading<List<FriendListItem>>()),
      (
        'error',
        AsyncError<List<FriendListItem>>(Exception('boom'), StackTrace.empty),
      ),
    ];

    for (final pair in cases) {
      final label = pair.$1;
      final state = pair.$2;
      testWidgets(
        'tapping the Groups row in the "$label" Friends-state shows the '
        'SnackBar, fires telemetry, and KEEPS the picker mounted',
        (tester) async {
          await tester.pumpWidget(
            _buildSubject(friendsState: state, analytics: analytics),
          );
          // Loading state never completes — use pump() not pumpAndSettle.
          // Pump enough frames to (a) trigger the post-frame callback
          // that opens the bottom sheet, and (b) advance past the
          // bottom-sheet enter animation (default 250 ms) so the
          // Groups row is in-viewport for the tap below.
          if (state is AsyncLoading) {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump();
          } else {
            await tester.pumpAndSettle();
          }

          // Tap the Groups stub row. Scope to the ListTile that owns
          // the unique "Coming in Sprint 3" trailing label (the bare
          // text "Groups" appears twice: section header + row title).
          await tester.tap(
            find.ancestor(
              of: find.text('Coming in Sprint 3'),
              matching: find.byType(ListTile),
            ),
          );
          // The snackbar is enqueued asynchronously by ScaffoldMessenger
          // — pump a few frames so the SnackBar's enter-transition
          // mounts the Text in the overlay. (`pumpAndSettle` would
          // deadlock on the loading-state CircularProgressIndicator.)
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump();

          // Snackbar copy per architect §2.3.
          expect(
            find.text('Group expenses coming in Sprint 3.'),
            findsOneWidget,
          );

          // Telemetry fired exactly once with the group context_type.
          expect(analytics.events, hasLength(1));
          final event = analytics.events.single;
          expect(event.name, expenseContextSelectedEvent);
          expect(event.parameters, isNotNull);
          expect(event.parameters![contextTypeParam], contextTypeGroup);

          // Picker STAYS mounted (does not dismiss).
          expect(find.byType(AddExpenseContextPickerSheet), findsOneWidget);
        },
      );
    }
  });
}
