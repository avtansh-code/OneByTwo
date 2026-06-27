@Tags(['golden'])
library;

// DC-07 — golden scaffolds for the converted Expenses flow (Haldi 21, 22)
// and the shell add-expense context picker (Haldi 8).
//
// Queues the states in light + dark for the money/marigold heroes — the
// Add-expense 3-step sheet (21, including the step-2 "adds up" green and the
// over-under red states), the Expense detail (22), and the context picker (8)
// — so every state has both brightnesses (04-qa-test-strategy.md §A.5 / §A.6).
//
// This group is ENABLED, consistent with DC-01..DC-06: the pixel
// comparison runs and is no longer skipped. Determinism comes from the
// bundled OFL fonts (Bricolage Grotesque + Hanken Grotesk), loaded once
// via `loadHaldiFonts` in `golden_harness.dart` and served to google_fonts
// through its test http seam, so the real Haldi type ramp rasterises
// identically offline. Baselines are authored on ubuntu-latest via the
// manual `golden-refresh` workflow and committed under `goldens/`; the
// `golden-a11y-checks` CI job (pinned Flutter version) compares against
// them on every PR and fails on any unintended pixel diff
// (04-qa-test-strategy.md sections A.2.2 and E). The load-bearing
// per-screen widget tests (expenses_haldi_reskin_test.dart,
// add_expense_bottom_sheet_widget_test.dart, the detail widget test, and
// add_expense_context_picker_sheet_test.dart) also run for real.

import 'dart:async';

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/services/image_picker_service.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/expenses/application/expense_detail_provider.dart';
import 'package:onebytwo/features/expenses/data/expense_repository.dart';
import 'package:onebytwo/features/expenses/data/receipt_storage_service.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/expenses/presentation/add_expense_bottom_sheet.dart';
import 'package:onebytwo/features/expenses/presentation/expense_detail_screen.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/application/user_profile_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/shell/presentation/add_expense_context_picker_sheet.dart';

import '../features/expenses/helpers/fake_services.dart';
import 'golden_harness.dart';

const _friendshipId = 'uid-me_uid-friend';
const _currentUid = 'uid-me';
const _friendUid = 'uid-friend';

ExpenseDoc _expense() => ExpenseDoc(
  id: 'eid',
  amountPaise: 50000,
  description: 'Group dinner',
  category: ExpenseCategory.food,
  date: DateTime.utc(2026, 6, 24),
  payerId: _currentUid,
  splits: const [
    Split(userId: _currentUid, sharePaise: 25000),
    Split(userId: _friendUid, sharePaise: 25000),
  ],
  splitMethod: SplitMethod.equal,
  createdBy: _currentUid,
);

FriendListItem _item(int net, String name, String oid) => FriendListItem(
  friendshipId: 'uid-me_$oid',
  otherUserId: oid,
  displayName: name,
  photoUrl: null,
  netBalancePaise: net,
);

List<Override> _serviceOverrides() => <Override>[
  analyticsServiceProvider.overrideWithValue(NoopAnalytics()),
  expenseRepositoryProvider.overrideWithValue(NoopExpenseRepository()),
  receiptStorageServiceProvider.overrideWithValue(FakeReceiptStorageService()),
  imagePickerServiceProvider.overrideWithValue(FakeImagePickerService()),
];

Widget _addExpenseHost() => ProviderScope(
  overrides: _serviceOverrides(),
  child: const Scaffold(
    body: AddExpenseBottomSheet(
      friendshipId: _friendshipId,
      currentUserUid: _currentUid,
      otherUserUid: _friendUid,
    ),
  ),
);

Widget _detail(Future<ExpenseDoc?> Function(Ref, ExpenseDetailArgs) value) {
  return ProviderScope(
    overrides: <Override>[
      ..._serviceOverrides(),
      expenseDetailProvider.overrideWith(value),
      userProfileProvider(_friendUid).overrideWith(
        (ref) async => UserModel(
          phoneNumber: '+919988776655',
          displayName: 'Rahul',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ),
    ],
    child: const ExpenseDetailScreen(
      friendshipId: _friendshipId,
      expenseId: 'eid',
      currentUserUid: _currentUid,
      otherUserUid: _friendUid,
    ),
  );
}

Widget _contextPicker(AsyncValue<List<FriendListItem>> state) {
  return ProviderScope(
    overrides: <Override>[
      analyticsServiceProvider.overrideWithValue(NoopAnalytics()),
      currentUserIdProvider.overrideWithValue(_currentUid),
      friendsListProvider.overrideWith((ref) async* {
        if (state is AsyncData<List<FriendListItem>>) {
          yield state.value;
        } else if (state is AsyncError<List<FriendListItem>>) {
          throw Exception('FR-FIRESTORE-READ');
        }
        // AsyncLoading: never emit.
        await Completer<void>().future;
      }),
    ],
    child: const Scaffold(body: AddExpenseContextPickerSheet()),
  );
}

Future<void> _driveToStep2(
  WidgetTester tester, {
  bool exactUnbalanced = false,
}) async {
  await tester.enterText(find.byKey(const Key('expense_amount_input')), '100');
  await tester.enterText(
    find.byKey(const Key('expense_description_input')),
    'Dinner',
  );
  await tester.tap(find.text('Food'));
  await tester.pumpAndSettle();
  final next = find.widgetWithText(FilledButton, 'Next').last;
  await tester.ensureVisible(next);
  await tester.pumpAndSettle();
  await tester.tap(next);
  await tester.pumpAndSettle();
  if (exactUnbalanced) {
    await tester.tap(find.text('Exact'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '60');
    await tester.enterText(fields.at(1), '30');
    await tester.pumpAndSettle();
  }
}

void main() {
  group('DC-07 Expenses goldens', () {
    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.light ? 'light' : 'dark';

      // ---- Add-expense 21: step 1 ----
      testWidgets('add_expense step1 ($mode)', (tester) async {
        await loadHaldiFonts();
        await pumpForGolden(tester, _addExpenseHost(), brightness: brightness);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/dc07/add_expense_step1_$mode.png'),
        );
      });

      // ---- Add-expense 21: step 2 balanced ("adds up" green) ----
      testWidgets('add_expense step2_balanced ($mode)', (tester) async {
        await loadHaldiFonts();
        await pumpForGolden(tester, _addExpenseHost(), brightness: brightness);
        await _driveToStep2(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/dc07/add_expense_step2_balanced_$mode.png',
          ),
        );
      });

      // ---- Add-expense 21: step 2 over-under (red) ----
      testWidgets('add_expense step2_overunder ($mode)', (tester) async {
        await loadHaldiFonts();
        await pumpForGolden(tester, _addExpenseHost(), brightness: brightness);
        await _driveToStep2(tester, exactUnbalanced: true);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/dc07/add_expense_step2_overunder_$mode.png',
          ),
        );
      });

      // ---- Expense detail 22 ----
      final detailStates = <String, Widget>{
        'loading': _detail((ref, args) => Completer<ExpenseDoc?>().future),
        'populated': _detail((ref, args) async => _expense()),
        'error': _detail((ref, args) async => throw Exception('READ')),
      };
      for (final entry in detailStates.entries) {
        testWidgets('expense_detail ${entry.key} ($mode)', (tester) async {
          await loadHaldiFonts();
          await pumpForGolden(tester, entry.value, brightness: brightness);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/dc07/detail_${entry.key}_$mode.png'),
          );
        });
      }

      // ---- Context picker 8 ----
      final pickerStates = <String, AsyncValue<List<FriendListItem>>>{
        'populated': AsyncData<List<FriendListItem>>(<FriendListItem>[
          _item(425000, 'Rahul Sharma', 'uid-r'),
          _item(-210000, 'Bina Kapoor', 'uid-b'),
        ]),
        'empty': const AsyncData<List<FriendListItem>>(<FriendListItem>[]),
        'loading': const AsyncLoading<List<FriendListItem>>(),
      };
      for (final entry in pickerStates.entries) {
        testWidgets('context_picker ${entry.key} ($mode)', (tester) async {
          await loadHaldiFonts();
          await pumpForGolden(
            tester,
            _contextPicker(entry.value),
            brightness: brightness,
          );
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/dc07/picker_${entry.key}_$mode.png'),
          );
        });
      }
    }
  });
}
