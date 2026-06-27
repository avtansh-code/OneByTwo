@Tags(['golden'])
library;

// DC-08 — golden scaffolds for the converted Settlements flow (Haldi 23, 24).
//
// Queues the states in light + dark for the two money/marigold heroes — the
// settle-up sheet (23: populated incl. the inert "Pay via UPI", the
// success-moment, the settled guard, loading, and the inline amount error)
// and the settlement history (24: loading-skeleton, empty, populated, error)
// — so every state has both brightnesses (04-qa-test-strategy.md §A.5 / §A.6).
//
// The settle-up states are captured via the shared OBTSettleUpSheet with
// explicit props: that is exactly the surface the SettleUpBottomSheet host
// renders (the host adds only the controller -> prop mapping + a scroll
// wrapper, no visual difference), and explicit props keep each state
// deterministic.
//
// This group is ENABLED, consistent with DC-01..DC-07: the pixel
// comparison runs and is no longer skipped. Determinism comes from the
// bundled OFL fonts (Bricolage Grotesque + Hanken Grotesk), loaded once
// via `loadHaldiFonts` in `golden_harness.dart` and served to google_fonts
// through its test http seam, so the real Haldi type ramp rasterises
// identically offline. Baselines are authored on ubuntu-latest via the
// manual `golden-refresh` workflow and committed under `goldens/`; the
// `golden-a11y-checks` CI job (pinned Flutter version) compares against
// them on every PR and fails on any unintended pixel diff
// (04-qa-test-strategy.md sections A.2.2 and E). The load-bearing
// per-screen widget tests (settle_up_bottom_sheet_widget_test.dart,
// settlement_history_screen_test.dart, settlements_haldi_reskin_test.dart)
// also run for real.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/widgets/sheets/obt_settle_up_sheet.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/settlements/data/settlement_repository.dart';
import 'package:onebytwo/features/settlements/domain/settlement_doc.dart';
import 'package:onebytwo/features/settlements/presentation/settlement_history_screen.dart';

import '../features/settlements/helpers/fake_services.dart';
import 'golden_harness.dart';

const _friendshipId = 'uid-me_uid-friend';
const _currentUid = 'uid-me';
const _friendUid = 'uid-friend';
const _friendName = 'Bina';

Widget _settleUp({
  int suggestedAmountPaise = 50000,
  bool isLoading = false,
  bool isSuccess = false,
  String? amountErrorText,
}) {
  return Scaffold(
    body: OBTSettleUpSheet(
      payerDisplayName: 'You',
      payeeDisplayName: _friendName,
      suggestedAmountPaise: suggestedAmountPaise,
      onAmountChanged: (_) {},
      onRecord: () {},
      isLoading: isLoading,
      isSuccess: isSuccess,
      amountErrorText: amountErrorText,
    ),
  );
}

Widget _history(FakeSettlementRepository repo) {
  return ProviderScope(
    overrides: <Override>[
      settlementRepositoryProvider.overrideWithValue(repo),
      analyticsServiceProvider.overrideWithValue(RecordingAnalytics()),
    ],
    child: const SettlementHistoryScreen(
      contextType: 'friendship',
      contextId: _friendshipId,
      currentUserUid: _currentUid,
      otherUserUid: _friendUid,
      otherDisplayName: _friendName,
    ),
  );
}

List<SettlementDoc> _historyItems() => <SettlementDoc>[
  fakeSettlement(id: 'out', date: DateTime(2026, 6, 24), note: 'UPI transfer'),
  fakeSettlement(
    id: 'in',
    date: DateTime(2026, 6, 18),
    amountPaise: 30000,
    fromUserId: _friendUid,
    toUserId: _currentUid,
  ),
];

void main() {
  group('DC-08 Settlements goldens', () {
    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.light ? 'light' : 'dark';

      // ---- Settle up 23 ----
      final settleUpStates = <String, Widget>{
        'populated': _settleUp(),
        'settled': _settleUp(suggestedAmountPaise: 0),
        'success': _settleUp(isSuccess: true),
        'loading': _settleUp(isLoading: true),
        'error': _settleUp(amountErrorText: 'Enter an amount above zero'),
      };
      for (final entry in settleUpStates.entries) {
        testWidgets('settle_up ${entry.key} ($mode)', (tester) async {
          await loadHaldiFonts();
          await pumpForGolden(tester, entry.value, brightness: brightness);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/dc08/settle_up_${entry.key}_$mode.png'),
          );
        });
      }

      // ---- Settlement history 24 ----
      final historyStates = <String, FakeSettlementRepository>{
        'loading': FakeSettlementRepository(keepLoading: true),
        'empty': FakeSettlementRepository(),
        'populated': FakeSettlementRepository(history: _historyItems()),
        'error': FakeSettlementRepository()..streamError = Exception('READ'),
      };
      for (final entry in historyStates.entries) {
        testWidgets('history ${entry.key} ($mode)', (tester) async {
          await loadHaldiFonts();
          await pumpForGolden(
            tester,
            _history(entry.value),
            brightness: brightness,
          );
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/dc08/history_${entry.key}_$mode.png'),
          );
        });
      }
    }
  });
}
