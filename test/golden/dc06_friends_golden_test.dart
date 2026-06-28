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
// This group is ENABLED, consistent with DC-01..DC-05: the pixel
// comparison runs and is no longer skipped. Determinism comes from the
// bundled OFL fonts (Bricolage Grotesque + Hanken Grotesk), loaded once
// via `loadHaldiFonts` in `golden_harness.dart` and served to google_fonts
// through its test http seam, so the real Haldi type ramp rasterises
// identically offline. Baselines are authored on ubuntu-latest via the
// manual `golden-refresh` workflow and committed under `goldens/`; the
// `golden-a11y-checks` CI job (pinned Flutter version) compares against
// them on every PR and fails on any unintended pixel diff
// (04-qa-test-strategy.md sections A.2.2 and E). The load-bearing
// per-screen widget tests (friends_haldi_reskin_test.dart,
// friends_list_screen_widget_test.dart,
// friend_detail_screen_widget_test.dart, friend_history_screen_test.dart)
// also run for real.

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
  // List/history values are BUILDERS, not pre-built streams: each golden runs
  // once per brightness and a `Stream.value`/`Stream.error`/`StreamController`
  // stream is single-subscription, so a shared instance would be consumed by
  // the first brightness and throw on the second — silently rendering the
  // error state. (The detail states are plain widgets, safe to reuse.)
  // ---- Friends list 9 ----
  final listStates = <String, Stream<List<FriendListItem>> Function()>{
    'loading': () => StreamController<List<FriendListItem>>().stream,
    'empty': () => Stream.value(const <FriendListItem>[]),
    'populated': () => Stream.value(<FriendListItem>[
      _item(425000, 'Rahul Sharma', 'uid-r_uid-me', 'uid-r'),
      _item(-210000, 'Bina Kapoor', 'uid-b_uid-me', 'uid-b'),
      _item(0, 'Aditya Menon', 'uid-a_uid-me', 'uid-a'),
    ]),
    'error': () =>
        Stream<List<FriendListItem>>.error(Exception('FR-FIRESTORE-READ')),
  };

  // ---- Friend history 12 ----
  final historyStates =
      <String, Stream<List<FriendDetailTimelineEvent>> Function()>{
        'loading': () =>
            StreamController<List<FriendDetailTimelineEvent>>().stream,
        'empty': () => Stream.value(const <FriendDetailTimelineEvent>[]),
        'populated': () => Stream.value(<FriendDetailTimelineEvent>[
          TimelineExpense(doc: _expense()),
          TimelineSettlement(doc: _settlement()),
        ]),
        'error': () => Stream<List<FriendDetailTimelineEvent>>.error(
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

  group('DC-06 Friends goldens', () {
    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.light ? 'light' : 'dark';

      for (final entry in listStates.entries) {
        testWidgets('friends_list ${entry.key} ($mode)', (tester) async {
          await loadHaldiFonts();
          await pumpForGolden(
            tester,
            _friendsList(entry.value()),
            brightness: brightness,
          );
          _expectNotErrorUnless(entry.key);
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
            _friendHistory(entry.value()),
            brightness: brightness,
          );
          _expectNotErrorUnless(entry.key);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/dc06/history_${entry.key}_$mode.png'),
          );
        });
      }
    }
  });
}

/// Asserts the friends surface rendered the state named [key] rather than
/// silently falling through to the error screen: `'error'` must show it,
/// every other state must not. Guards against a fixture rendering the wrong
/// state (which the pixel comparator alone cannot detect).
void _expectNotErrorUnless(String key) {
  final errorFinder = find.text('Something went wrong');
  if (key == 'error') {
    expect(errorFinder, findsOneWidget, reason: 'error state must render');
  } else {
    expect(
      errorFinder,
      findsNothing,
      reason: '"$key" must not render the error screen',
    );
  }
}
