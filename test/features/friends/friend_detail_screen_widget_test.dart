// Friend Detail screen widget tests (FR-FR-04 / SCR-11).
//
// Verifies the SCR-11 six-state rendering (loading / populated /
// settled / no expenses / error / real-time update), the friend_detail_viewed
// single-fire discipline, and the FAB → AddExpenseBottomSheet wiring
// preserved from PR #38.
//
// Replaces the existing placeholder tests (none currently — the
// placeholder was widget-covered only via friends_list_screen_widget_test).
//
// These tests are written BEFORE the implementation exists (test-first).
// They will fail to compile until the production code is created.

// ignore_for_file: cascade_invocations

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/services/image_picker_service.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/data/receipt_storage_service.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/expenses/presentation/add_expense_bottom_sheet.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/friends/presentation/friend_detail_screen.dart';
import 'package:onebytwo/features/friends/presentation/widgets/obt_settle_up_card.dart';
import 'package:onebytwo/features/reminders/data/reminder_repository.dart';
import 'package:onebytwo/features/reminders/domain/reminder_send_error.dart';
import 'package:onebytwo/features/reminders/domain/reminder_send_success.dart';
import 'package:onebytwo/features/settlements/application/settle_up_telemetry.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';
import 'package:onebytwo/features/settlements/presentation/settle_up_bottom_sheet.dart';

import '../expenses/helpers/fake_services.dart';

class FakeAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object>? parameters})> loggedEvents =
      [];

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add((name: name, parameters: parameters));
  }

  int countOf(String name) => loggedEvents.where((e) => e.name == name).length;

  Map<String, Object>? lastParamsFor(String name) =>
      loggedEvents.lastWhere((e) => e.name == name).parameters;
}

const _args = FriendDetailArgs(
  friendshipId: 'uid-friend_uid-me',
  currentUserUid: 'uid-me',
  otherUserUid: 'uid-friend',
);

FriendDetailHeader _header({
  String displayName = 'Bina',
  String? photoUrl,
  int netBalancePaise = 0,
  BalanceState balanceState = BalanceState.settled,
}) {
  return FriendDetailHeader(
    displayName: displayName,
    photoUrl: photoUrl,
    netBalancePaise: netBalancePaise,
    balanceState: balanceState,
  );
}

ExpenseDoc _expense({
  required String description,
  required DateTime date,
  int amountPaise = 1000,
  String payerId = 'uid-me',
  List<Split>? splits,
}) {
  return ExpenseDoc(
    amountPaise: amountPaise,
    description: description,
    category: ExpenseCategory.food,
    date: date,
    payerId: payerId,
    splits:
        splits ??
        const [
          Split(userId: 'uid-me', sharePaise: 500),
          Split(userId: 'uid-friend', sharePaise: 500),
        ],
    splitMethod: SplitMethod.equal,
    createdBy: payerId,
  );
}

SettlementDoc _settlement({
  required String id,
  required DateTime date,
  int amountPaise = 5000,
  String fromUserId = 'uid-me',
  String toUserId = 'uid-friend',
}) {
  return SettlementDoc(
    settlementId: id,
    fromUserId: fromUserId,
    toUserId: toUserId,
    amountPaise: amountPaise,
    contextType: 'friendship',
    contextId: 'uid-friend_uid-me',
    date: date,
    note: null,
    method: 'manual',
    verificationStatus: 'unverified',
    currency: 'INR',
    createdAt: date,
    deleted: false,
  );
}

class FakeExpenseRepository implements ExpenseRepository {
  ExpenseCreateError? throwError;
  String returnId = 'eid-test';
  bool createCalled = false;
  String? lastWatchedFriendshipId;

  @override
  Future<String> createExpense({
    required String friendshipId,
    required ExpenseDoc doc,
  }) async {
    createCalled = true;
    if (throwError != null) {
      throw throwError!;
    }
    return returnId;
  }

  @override
  Future<void> updateExpense({
    required String friendshipId,
    required String expenseId,
    required Map<String, dynamic> updates,
  }) async {
    // FR-EX-06 surface — friend_detail_screen tests don't exercise
    // the edit flow directly; the dedicated expense_detail_screen
    // tests own that.
  }

  @override
  Future<void> softDeleteExpense({
    required String friendshipId,
    required String expenseId,
  }) async {
    // Same as above.
  }

  @override
  Stream<List<ExpenseDoc>> watchExpensesByFriendship({
    required String friendshipId,
    int limit = 5,
  }) {
    lastWatchedFriendshipId = friendshipId;
    return const Stream<List<ExpenseDoc>>.empty();
  }

  @override
  String newExpenseId({required String friendshipId}) => returnId;

  @override
  Future<void> createExpenseAtId({
    required String friendshipId,
    required String expenseId,
    required ExpenseDoc doc,
  }) async {
    // Not exercised by the Friend Detail widget tests.
  }
}

class FakeSettlementRepository implements SettlementRepository {
  bool createCalled = false;
  String returnSettlementId = 'sid-test';

  @override
  Future<String> createSettlement({required SettlementDoc doc}) async {
    createCalled = true;
    return returnSettlementId;
  }

  @override
  Stream<List<SettlementDoc>> watchByContext({
    required String contextType,
    required String contextId,
  }) => const Stream<List<SettlementDoc>>.empty();
}

Widget _buildSubject({
  required AsyncValue<FriendDetailState> initialValue,
  required FakeAnalyticsService analytics,
  FakeExpenseRepository? expenseRepository,
  FakeSettlementRepository? settlementRepository,
  ReminderRepository? reminderRepository,
}) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      receiptStorageServiceProvider.overrideWithValue(
        FakeReceiptStorageService(),
      ),
      imagePickerServiceProvider.overrideWithValue(FakeImagePickerService()),
      if (expenseRepository != null)
        expenseRepositoryProvider.overrideWithValue(expenseRepository),
      if (settlementRepository != null)
        settlementRepositoryProvider.overrideWithValue(settlementRepository),
      if (reminderRepository != null)
        reminderRepositoryProvider.overrideWithValue(reminderRepository),
      friendDetailProvider(_args).overrideWith((ref) {
        switch (initialValue) {
          case AsyncData(:final value):
            return Stream.value(value);
          case AsyncError(:final error, :final stackTrace):
            return Stream<FriendDetailState>.error(error, stackTrace);
          default:
            // Loading: never-completing stream.
            return const Stream<FriendDetailState>.empty();
        }
      }),
    ],
    child: const MaterialApp(
      home: FriendDetailScreen(
        friendshipId: 'uid-friend_uid-me',
        currentUserUid: 'uid-me',
        otherUserUid: 'uid-friend',
      ),
    ),
  );
}

void main() {
  late FakeAnalyticsService analytics;

  setUp(() {
    analytics = FakeAnalyticsService();
  });

  group('Loading state', () {
    testWidgets('shows skeleton placeholders before first emission', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: const AsyncLoading<FriendDetailState>(),
          analytics: analytics,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('friend_detail_skeleton')), findsOneWidget);
    });

    testWidgets('does NOT fire friend_detail_viewed while loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: const AsyncLoading<FriendDetailState>(),
          analytics: analytics,
        ),
      );
      await tester.pump();

      expect(analytics.countOf('friend_detail_viewed'), 0);
    });
  });

  group('Populated state (non-zero balance — owed)', () {
    final state = FriendDetailStatePopulated(
      header: _header(netBalancePaise: 12345, balanceState: BalanceState.owed),
      timeline: [
        TimelineExpense(
          doc: _expense(description: 'Coffee', date: DateTime(2026, 6, 5)),
        ),
        TimelineSettlement(
          doc: _settlement(id: 'sid-1', date: DateTime(2026, 6, 3)),
        ),
      ],
    );

    testWidgets('renders the friend display name in the header', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(initialValue: AsyncData(state), analytics: analytics),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bina'), findsWidgets);
    });

    testWidgets('renders the owed balance pill copy and INR amount', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(initialValue: AsyncData(state), analytics: analytics),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('You are owed ${formatInrFromPaise(12345)}'),
        findsOneWidget,
      );
    });

    testWidgets('renders the intermixed timeline rows in order', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(initialValue: AsyncData(state), analytics: analytics),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coffee'), findsOneWidget);
      // Settlement row is labelled by review §R3 with the payer
      // context. The seeded settlement uses the default fromUserId =
      // 'uid-me', so the label reads "You paid Bina ₹X.XX".
      expect(
        find.text('You paid Bina ${formatInrFromPaise(5000)}'),
        findsOneWidget,
      );
    });

    testWidgets('friend_detail_viewed fires once with owed balance_state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(initialValue: AsyncData(state), analytics: analytics),
      );
      await tester.pumpAndSettle();

      expect(analytics.countOf('friend_detail_viewed'), 1);
      final params = analytics.lastParamsFor('friend_detail_viewed');
      expect(params, isNotNull);
      expect(params!['balance_state'], 'owed');
      expect(
        params['friendship_id_hash'],
        equals(hashFriendshipId('uid-friend_uid-me')),
      );
    });
  });

  group('Populated state (non-zero balance — owes)', () {
    final state = FriendDetailStatePopulated(
      header: _header(netBalancePaise: -5000, balanceState: BalanceState.owes),
      timeline: [
        TimelineExpense(
          doc: _expense(
            description: 'Dinner',
            date: DateTime(2026, 6, 5),
            amountPaise: 10000,
            payerId: 'uid-friend',
            splits: const [
              Split(userId: 'uid-me', sharePaise: 5000),
              Split(userId: 'uid-friend', sharePaise: 5000),
            ],
          ),
        ),
      ],
    );

    testWidgets('renders the owes balance pill copy', (tester) async {
      await tester.pumpWidget(
        _buildSubject(initialValue: AsyncData(state), analytics: analytics),
      );
      await tester.pumpAndSettle();

      expect(find.text('You owe ${formatInrFromPaise(-5000)}'), findsOneWidget);
    });

    testWidgets('friend_detail_viewed fires with owes balance_state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(initialValue: AsyncData(state), analytics: analytics),
      );
      await tester.pumpAndSettle();

      expect(
        analytics.lastParamsFor('friend_detail_viewed')?['balance_state'],
        'owes',
      );
    });
  });

  group('Populated state (settled up)', () {
    final state = FriendDetailStatePopulated(
      header: _header(),
      timeline: [
        TimelineExpense(
          doc: _expense(
            description: 'Old expense',
            date: DateTime(2026, 5, 30),
          ),
        ),
      ],
    );

    testWidgets('renders the settled-up pill copy', (tester) async {
      await tester.pumpWidget(
        _buildSubject(initialValue: AsyncData(state), analytics: analytics),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settled up'), findsOneWidget);
    });

    testWidgets('friend_detail_viewed fires with settled balance_state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(initialValue: AsyncData(state), analytics: analytics),
      );
      await tester.pumpAndSettle();

      expect(
        analytics.lastParamsFor('friend_detail_viewed')?['balance_state'],
        'settled',
      );
    });
  });

  group('Empty state', () {
    final state = FriendDetailStateEmpty(header: _header());

    testWidgets('renders the no-expenses placeholder', (tester) async {
      await tester.pumpWidget(
        _buildSubject(initialValue: AsyncData(state), analytics: analytics),
      );
      await tester.pumpAndSettle();

      expect(find.text('No expenses yet'), findsOneWidget);
      expect(
        find.text('Add an expense with Bina to start tracking.'),
        findsOneWidget,
      );
    });

    testWidgets('FAB remains visible and opens AddExpenseBottomSheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncData(state),
          analytics: analytics,
          expenseRepository: FakeExpenseRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Add expense'), findsOneWidget);

      await tester.tap(find.byTooltip('Add expense'));
      await tester.pumpAndSettle();

      expect(find.byType(AddExpenseBottomSheet), findsOneWidget);
    });

    testWidgets('friend_detail_viewed fires once on the empty state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(initialValue: AsyncData(state), analytics: analytics),
      );
      await tester.pumpAndSettle();

      expect(analytics.countOf('friend_detail_viewed'), 1);
    });
  });

  group('Error state', () {
    testWidgets('renders the error placeholder with Retry', (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncError<FriendDetailState>(
            Exception('Firestore down'),
            StackTrace.empty,
          ),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text("We couldn't load this friend's details. Please try again."),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('does NOT fire friend_detail_viewed in error state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncError<FriendDetailState>(
            Exception('boom'),
            StackTrace.empty,
          ),
          analytics: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(analytics.countOf('friend_detail_viewed'), 0);
    });
  });

  group('Telemetry single-fire discipline', () {
    testWidgets('does NOT re-fire on subsequent state emissions', (
      tester,
    ) async {
      // Provider override that emits two states in sequence.
      final first = FriendDetailStateEmpty(header: _header());
      final second = FriendDetailStatePopulated(
        header: _header(netBalancePaise: 1000, balanceState: BalanceState.owed),
        timeline: [
          TimelineExpense(
            doc: _expense(description: 'Tea', date: DateTime(2026, 6)),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            analyticsServiceProvider.overrideWithValue(analytics),
            friendDetailProvider(_args).overrideWith(
              (ref) => Stream<FriendDetailState>.fromIterable([first, second]),
            ),
          ],
          child: const MaterialApp(
            home: FriendDetailScreen(
              friendshipId: 'uid-friend_uid-me',
              currentUserUid: 'uid-me',
              otherUserUid: 'uid-friend',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(analytics.countOf('friend_detail_viewed'), 1);
    });
  });

  group('Accessibility', () {
    testWidgets('every interactive widget has a semantics label', (
      tester,
    ) async {
      final state = FriendDetailStatePopulated(
        header: _header(
          netBalancePaise: 12345,
          balanceState: BalanceState.owed,
        ),
        timeline: [
          TimelineExpense(
            doc: _expense(description: 'Coffee', date: DateTime(2026, 6, 5)),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildSubject(initialValue: AsyncData(state), analytics: analytics),
      );
      await tester.pumpAndSettle();

      // The FAB exposes a tooltip / semantic label.
      expect(find.byTooltip('Add expense'), findsOneWidget);
    });
  });

  // ===================================================================
  // FR-SE-05 / FR-SE-07 / Architect Notes §2.5 — OBTSettleUpCard
  // ===================================================================

  group('OBTSettleUpCard rendering (FR-SE-07)', () {
    testWidgets('renders the OBTSettleUpCard in the owes direction', (
      tester,
    ) async {
      final state = FriendDetailStatePopulated(
        header: _header(
          netBalancePaise: -5000,
          balanceState: BalanceState.owes,
        ),
        timeline: [
          TimelineExpense(
            doc: _expense(
              description: 'Dinner',
              date: DateTime(2026, 6, 5),
              amountPaise: 10000,
              payerId: 'uid-friend',
              splits: const [
                Split(userId: 'uid-me', sharePaise: 5000),
                Split(userId: 'uid-friend', sharePaise: 5000),
              ],
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncData(state),
          analytics: analytics,
          settlementRepository: FakeSettlementRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OBTSettleUpCard), findsOneWidget);
      expect(find.text('Settle Up'), findsOneWidget);
      expect(find.text(formatInrFromPaise(5000)), findsWidgets);
    });

    testWidgets(
      'renders the receiving-direction OBTSettleUpCard in the owed direction '
      '(FR-SE-09 supersedes the PR #43 §2.5 omit)',
      (tester) async {
        final state = FriendDetailStatePopulated(
          header: _header(
            netBalancePaise: 5000,
            balanceState: BalanceState.owed,
          ),
          timeline: [
            TimelineExpense(
              doc: _expense(description: 'Tea', date: DateTime(2026, 6)),
            ),
          ],
        );

        await tester.pumpWidget(
          _buildSubject(
            initialValue: AsyncData(state),
            analytics: analytics,
            settlementRepository: FakeSettlementRepository(),
            reminderRepository: _StaticReminderRepository(
              () => ReminderSendSuccess(
                nextAllowedAt: DateTime.now().add(const Duration(hours: 24)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OBTSettleUpCard), findsOneWidget);
        expect(find.text('Send Reminder'), findsOneWidget);
        expect(find.text('Settle Up'), findsNothing);
      },
    );

    testWidgets('does NOT render the OBTSettleUpCard when settled (AC-2)', (
      tester,
    ) async {
      final state = FriendDetailStatePopulated(
        header: _header(),
        timeline: [
          TimelineExpense(
            doc: _expense(description: 'Old', date: DateTime(2026, 5, 30)),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildSubject(
          initialValue: AsyncData(state),
          analytics: analytics,
          settlementRepository: FakeSettlementRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OBTSettleUpCard), findsNothing);
    });

    testWidgets(
      'tapping the card opens SettleUpBottomSheet + fires settle_up_tapped',
      (tester) async {
        final state = FriendDetailStatePopulated(
          header: _header(
            netBalancePaise: -5000,
            balanceState: BalanceState.owes,
          ),
          timeline: const [],
        );

        await tester.pumpWidget(
          _buildSubject(
            initialValue: AsyncData(state),
            analytics: analytics,
            settlementRepository: FakeSettlementRepository(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Settle Up'));
        await tester.pumpAndSettle();

        expect(find.byType(SettleUpBottomSheet), findsOneWidget);
        expect(analytics.countOf(SettleUpTelemetry.settleUpTapped), 1);
        final params = analytics.lastParamsFor(
          SettleUpTelemetry.settleUpTapped,
        );
        expect(params?[SettleUpTelemetry.paramSource], 'friend_detail');
        expect(
          params?[SettleUpTelemetry.paramFriendshipIdHash],
          equals(hashFriendshipId('uid-friend_uid-me')),
        );
      },
    );
  });

  // ===================================================================
  // Review §R3 — _SettlementRow payer-context labels (AC-9)
  // ===================================================================

  group('Settlement row payer context (review §R3)', () {
    testWidgets('fromUserId == currentUid → "You paid Bina ₹X.XX"', (
      tester,
    ) async {
      final state = FriendDetailStatePopulated(
        header: _header(
          netBalancePaise: -5000,
          balanceState: BalanceState.owes,
        ),
        timeline: [
          TimelineSettlement(
            doc: _settlement(id: 'sid-me-paid', date: DateTime(2026, 6, 5)),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildSubject(initialValue: AsyncData(state), analytics: analytics),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('You paid Bina ${formatInrFromPaise(5000)}'),
        findsOneWidget,
      );
    });

    testWidgets('fromUserId == otherUid → "Bina paid you ₹X.XX"', (
      tester,
    ) async {
      final state = FriendDetailStatePopulated(
        header: _header(netBalancePaise: 5000, balanceState: BalanceState.owed),
        timeline: [
          TimelineSettlement(
            doc: _settlement(
              id: 'sid-friend-paid',
              date: DateTime(2026, 6, 5),
              fromUserId: 'uid-friend',
              toUserId: 'uid-me',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        _buildSubject(initialValue: AsyncData(state), analytics: analytics),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Bina paid you ${formatInrFromPaise(5000)}'),
        findsOneWidget,
      );
    });
  });

  // ===================================================================
  // FR-SE-09 — Send Reminder receiving-direction wiring
  // ===================================================================

  group('Send Reminder wiring (FR-SE-09)', () {
    testWidgets(
      'tapping Send Reminder fires the controller and updates cooldown',
      (tester) async {
        final repo = _StaticReminderRepository(() => ReminderSendSuccess(
              nextAllowedAt: DateTime.now().add(const Duration(hours: 24)),
            ));
        final state = FriendDetailStatePopulated(
          header: _header(
            netBalancePaise: 5000,
            balanceState: BalanceState.owed,
            displayName: 'Bina',
          ),
          timeline: [
            TimelineExpense(
              doc: _expense(description: 'Tea', date: DateTime(2026, 6)),
            ),
          ],
        );

        await tester.pumpWidget(
          _buildSubject(
            initialValue: AsyncData(state),
            analytics: analytics,
            settlementRepository: FakeSettlementRepository(),
            reminderRepository: repo,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Send Reminder'));
        await tester.pumpAndSettle();

        expect(repo.callCount, 1);
        expect(repo.lastToUserId, 'uid-friend');
        expect(repo.lastContextId, 'uid-friend_uid-me');
        expect(repo.lastContextType, 'friendship');
      },
    );

    testWidgets(
      'RATE_LIMITED surfaces snackbar with countdown',
      (tester) async {
        final nextAt = DateTime.now().add(
          const Duration(hours: 5, minutes: 32),
        );
        final repo = _StaticReminderRepository(
          () => ReminderSendRateLimited(nextAllowedAt: nextAt),
        );
        final state = FriendDetailStatePopulated(
          header: _header(
            netBalancePaise: 5000,
            balanceState: BalanceState.owed,
            displayName: 'Bina',
          ),
          timeline: const [],
        );

        await tester.pumpWidget(
          _buildSubject(
            initialValue: AsyncData(state),
            analytics: analytics,
            settlementRepository: FakeSettlementRepository(),
            reminderRepository: repo,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Send Reminder'));
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('Bina'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'RECIPIENT_PREFS_DISABLED surfaces a prefs-off snackbar',
      (tester) async {
        final repo = _StaticReminderRepository(
          () => const ReminderSendRecipientPrefsDisabled(),
        );
        final state = FriendDetailStatePopulated(
          header: _header(
            netBalancePaise: 5000,
            balanceState: BalanceState.owed,
            displayName: 'Bina',
          ),
          timeline: const [],
        );

        await tester.pumpWidget(
          _buildSubject(
            initialValue: AsyncData(state),
            analytics: analytics,
            settlementRepository: FakeSettlementRepository(),
            reminderRepository: repo,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Send Reminder'));
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.textContaining('notifications turned off'),
          findsOneWidget,
        );
      },
    );
  });
}

/// Static reminder repository for widget-test wiring.
class _StaticReminderRepository implements ReminderRepository {
  _StaticReminderRepository(this._produce);

  final ReminderSendResult Function() _produce;
  int callCount = 0;
  String? lastToUserId;
  String? lastContextType;
  String? lastContextId;

  @override
  Future<ReminderSendResult> sendReminder({
    required String toUserId,
    required String contextType,
    required String contextId,
    String? message,
  }) async {
    callCount += 1;
    lastToUserId = toUserId;
    lastContextType = contextType;
    lastContextId = contextId;
    return _produce();
  }
}
