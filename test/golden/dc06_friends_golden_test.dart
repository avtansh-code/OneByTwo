@Tags(['golden'])
library;

// DC-06 — golden scaffolds for the converted Friends flow (Haldi 9, 11, 12).
//
// Queues the four states (loading-skeleton, empty illustration, populated,
// error) in light + dark for the three Friends heroes — the Friends list
// (9), the Friend detail (11) and the net-new Friend history (12) — each a
// hero with money on screen, so every state needs both brightnesses
// (04-qa-test-strategy.md sections A.5 / A.6).
//
// The pixel comparison is intentionally SKIPPED, consistent with
// DC-01..DC-05: golden bytes are byte-sensitive across macOS/Linux, so the
// baselines must be authored on ubuntu-latest by the DC-13
// `golden-a11y-checks` job. The load-bearing proof until then is the
// per-screen widget tests (friends_haldi_reskin_test.dart,
// friends_list_screen_widget_test.dart, friend_detail_screen_widget_test.dart,
// friend_history_screen_test.dart), which run for real.

import 'dart:async';

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/expenses/domain/expense_category.dart';
import 'package:onebytwo/features/expenses/domain/expense_doc.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';
import 'package:onebytwo/features/friends/application/friend_detail_provider.dart';
import 'package:onebytwo/features/friends/application/friend_history_provider.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/presentation/friend_history_screen.dart';
import 'package:onebytwo/features/friends/presentation/friends_list_screen.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_detail_header.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_detail_states.dart';
import 'package:onebytwo/features/friends/presentation/widgets/friend_detail_timeline.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';

import 'golden_harness.dart';

class _FakeAnalytics implements AnalyticsService {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {}
}

FriendListItem _item(int net, String name, String fid, String oid) {
  return FriendListItem(
    friendshipId: fid,
    otherUserId: oid,
    displayName: name,
    photoUrl: null,
    netBalancePaise: net,
  );
}

FriendDetailHeader _header(int net, BalanceState state) => FriendDetailHeader(
  displayName: 'Rahul Sharma',
  photoUrl: null,
  netBalancePaise: net,
  balanceState: state,
);

ExpenseDoc _expense() => ExpenseDoc(
  amountPaise: 320000,
  description: 'Dinner at Bombay Canteen',
  category: ExpenseCategory.food,
  date: DateTime(2026, 6, 22),
  payerId: 'uid-me',
  splits: const [
    Split(userId: 'uid-me', sharePaise: 160000),
    Split(userId: 'uid-friend', sharePaise: 160000),
  ],
  splitMethod: SplitMethod.equal,
  createdBy: 'uid-me',
);

SettlementDoc _settlement() => SettlementDoc(
  settlementId: 'sid-1',
  fromUserId: 'uid-friend',
  toUserId: 'uid-me',
  amountPaise: 50000,
  contextType: 'friendship',
  contextId: 'uid-friend_uid-me',
  date: DateTime(2026, 6, 12),
  note: null,
  method: 'manual',
  verificationStatus: 'unverified',
  currency: 'INR',
  createdAt: DateTime(2026, 6, 12),
  deleted: false,
);

Widget _friendsList(Stream<List<FriendListItem>> friends) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(_FakeAnalytics()),
      currentUserIdProvider.overrideWithValue('uid-me'),
      friendsListProvider.overrideWith((ref) => friends),
    ],
    child: const FriendsListScreen(),
  );
}

Widget _friendHistory(Stream<List<FriendDetailTimelineEvent>> events) {
  return ProviderScope(
    overrides: [friendHistoryProvider.overrideWith((ref, args) => events)],
    child: const FriendHistoryScreen(
      friendshipId: 'uid-friend_uid-me',
      currentUserUid: 'uid-me',
      otherUserUid: 'uid-friend',
      friendDisplayName: 'Rahul Sharma',
    ),
  );
}

Widget _friendDetail(Widget body) {
  return Scaffold(
    appBar: AppBar(title: const Text('Rahul Sharma')),
    body: body,
  );
}

void main() {
  // ---- Friends list 9 ----
  final listStates = <String, Stream<List<FriendListItem>>>{
    'loading': StreamController<List<FriendListItem>>().stream,
    'empty': Stream.value(const <FriendListItem>[]),
    'populated': Stream.value(<FriendListItem>[
      _item(425000, 'Rahul Sharma', 'uid-r_uid-me', 'uid-r'),
      _item(-210000, 'Bina Kapoor', 'uid-b_uid-me', 'uid-b'),
      _item(0, 'Aditya Menon', 'uid-a_uid-me', 'uid-a'),
    ]),
    'error': Stream<List<FriendListItem>>.error(Exception('FR-FIRESTORE-READ')),
  };

  // ---- Friend history 12 ----
  final historyStates = <String, Stream<List<FriendDetailTimelineEvent>>>{
    'loading': StreamController<List<FriendDetailTimelineEvent>>().stream,
    'empty': Stream.value(const <FriendDetailTimelineEvent>[]),
    'populated': Stream.value(<FriendDetailTimelineEvent>[
      TimelineExpense(doc: _expense()),
      TimelineSettlement(doc: _settlement()),
    ]),
    'error': Stream<List<FriendDetailTimelineEvent>>.error(
      Exception('FH-FIRESTORE-READ'),
    ),
  };

  // ---- Friend detail 11 ----
  final detailStates = <String, Widget>{
    'loading': _friendDetail(const FriendDetailLoadingState()),
    'empty': _friendDetail(
      Column(
        children: [
          FriendDetailHeaderWidget(header: _header(0, BalanceState.settled)),
          const Expanded(
            child: FriendDetailEmptyState(friendDisplayName: 'Rahul Sharma'),
          ),
        ],
      ),
    ),
    'populated': _friendDetail(
      SingleChildScrollView(
        child: Column(
          children: [
            FriendDetailHeaderWidget(
              header: _header(425000, BalanceState.owed),
            ),
            FriendDetailTimelineWidget(
              timeline: [
                TimelineExpense(doc: _expense()),
                TimelineSettlement(doc: _settlement()),
              ],
              friendshipId: 'uid-friend_uid-me',
              currentUserUid: 'uid-me',
              otherUserUid: 'uid-friend',
              friendDisplayName: 'Rahul Sharma',
            ),
          ],
        ),
      ),
    ),
    'error': _friendDetail(FriendDetailErrorState(onRetry: () {})),
  };

  group(
    'DC-06 Friends goldens',
    () {
      for (final brightness in Brightness.values) {
        final mode = brightness == Brightness.light ? 'light' : 'dark';

        for (final entry in listStates.entries) {
          testWidgets('friends_list ${entry.key} ($mode)', (tester) async {
            await loadHaldiFonts();
            await pumpForGolden(
              tester,
              _friendsList(entry.value),
              brightness: brightness,
            );
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/dc06/list_${entry.key}_$mode.png'),
            );
          });
        }

        for (final entry in detailStates.entries) {
          testWidgets('friend_detail ${entry.key} ($mode)', (tester) async {
            await loadHaldiFonts();
            await pumpForGolden(tester, entry.value, brightness: brightness);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/dc06/detail_${entry.key}_$mode.png'),
            );
          });
        }

        for (final entry in historyStates.entries) {
          testWidgets('friend_history ${entry.key} ($mode)', (tester) async {
            await loadHaldiFonts();
            await pumpForGolden(
              tester,
              _friendHistory(entry.value),
              brightness: brightness,
            );
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/dc06/history_${entry.key}_$mode.png'),
            );
          });
        }
      }
    },
    skip:
        'DC-13 (#125) authors and un-skips Friends goldens on ubuntu-latest; '
        'baselines are not committed from macOS.',
  );
}
