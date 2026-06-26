@Tags(['golden'])
library;

// DC-02 — golden scaffolds for the six reskinned OBT* shared widgets.
//
// Re-baselines the SAME widget tree to the Haldi skin (04-qa-test-strategy.md
// section A.5: the diff must be purely chromatic/typographic; the unchanged
// structural widget tests prove no structure moved). Light + dark per widget.
//
// The pixel comparison is intentionally SKIPPED, consistent with DC-01's
// foundation_showcase_golden_test.dart: golden bytes are byte-sensitive across
// macOS/Linux, so baselines must be authored on ubuntu-latest by the DC-13
// `golden-a11y-checks` job (04-qa-test-strategy.md sections A.2.2 and E). DC-13
// un-skips this group, bundles the fonts in `loadHaldiFonts`, and runs
// `--update-goldens` on the canonical host.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/widgets/dialogs/obt_confirmation_dialog.dart';
import 'package:onebytwo/core/widgets/inputs/obt_amount_input.dart';
import 'package:onebytwo/core/widgets/lists/obt_activity_row.dart';
import 'package:onebytwo/core/widgets/nav/obt_bottom_nav.dart';
import 'package:onebytwo/core/widgets/nav/obt_floating_action_button.dart';
import 'package:onebytwo/features/activity/domain/activity_event_type.dart';
import 'package:onebytwo/features/activity/domain/activity_feed_item.dart';
import 'package:onebytwo/features/friends/presentation/widgets/obt_settle_up_card.dart';

import 'golden_harness.dart';

ActivityFeedItem _activityItem() => ActivityFeedItem(
  id: '1',
  type: ActivityEventType.expenseAdded,
  payload: const <String, dynamic>{
    'description': 'Dinner',
    'amountPaise': 123450,
    'authorUid': 'uidB',
  },
  createdAt: DateTime.utc(2026, 6, 8, 12),
);

/// One representative tree per reskinned widget. The tree is the SAME as the
/// pre-Haldi structure; only the tokens/type differ (section A.5 reskin scope).
Map<String, Widget Function()> _cases() => <String, Widget Function()>{
  'fab': () =>
      Scaffold(floatingActionButton: OBTFloatingActionButton(onPressed: () {})),
  'bottom_nav': () => Scaffold(
    bottomNavigationBar: OBTBottomNav(currentIndex: 0, onTabSelected: (_) {}),
  ),
  'amount_input': () => Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: OBTAmountInput(
        onChanged: (_) {},
        autoFocus: false,
        initialAmountPaise: 150050,
      ),
    ),
  ),
  'activity_row': () => Scaffold(
    body: OBTActivityRow(
      item: _activityItem(),
      currentUserUid: 'uidA',
      otherPartyDisplayName: 'Priya',
      secondaryText: '2 hours ago',
      onTap: () {},
    ),
  ),
  'confirmation_dialog': () => Scaffold(
    body: Center(
      child: OBTConfirmationDialog(
        title: 'Delete expense?',
        body: 'This cannot be undone.',
        confirmLabel: 'Delete',
        isDestructive: true,
        onCancel: () {},
        onConfirm: () {},
      ),
    ),
  ),
  'settle_up_card': () => Scaffold(
    body: OBTSettleUpCard(
      payerDisplayName: 'You',
      payerPhotoUrl: null,
      payeeDisplayName: 'Priya',
      payeePhotoUrl: null,
      suggestedAmountPaise: 50000,
      onSettleUp: () {},
    ),
  ),
};

void main() {
  group(
    'OBT* reskinned widgets (DC-02)',
    () {
      setUp(loadHaldiFonts);

      _cases().forEach((name, build) {
        for (final brightness in Brightness.values) {
          final theme = brightness.name;
          testWidgets('$name ($theme)', (tester) async {
            await pumpForGolden(tester, build(), brightness: brightness);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/obt_${name}__$theme.png'),
            );
          });
        }
      });
    },
    skip:
        'Baselines authored on ubuntu-latest by DC-13 '
        '(04-qa-test-strategy.md sections A.2.2 and E).',
  );
}
