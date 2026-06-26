@Tags(['golden'])
library;

// DC-03 — golden scaffolds for the eleven new Haldi shared components.
//
// Each component's four states (populated, empty, loading = shimmer, error)
// plus the new states the rebuilds introduce (segmented "adds up" green /
// over-under red, the settle-up success moment and the inert UPI slot) are
// queued here in light + dark (04-qa-test-strategy.md sections A.5 / A.6).
//
// The pixel comparison is intentionally SKIPPED, consistent with DC-01 /
// DC-02: golden bytes are byte-sensitive across macOS/Linux, so baselines
// must be authored on ubuntu-latest by the DC-13 `golden-a11y-checks` job
// (04-qa-test-strategy.md sections A.2.2 and E). DC-13 un-skips this group,
// bundles the fonts in `loadHaldiFonts`, and runs `--update-goldens` on the
// canonical host. Animated surfaces (shimmer, sync spin, segment selection)
// are captured at a pinned, reduced-motion frame (section A.2.5 / C.3).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/branding/obt_brand.dart';
import 'package:onebytwo/core/widgets/charts/obt_spending_donut.dart';
import 'package:onebytwo/core/widgets/feedback/obt_empty_state.dart';
import 'package:onebytwo/core/widgets/feedback/obt_offline_banner.dart';
import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';
import 'package:onebytwo/core/widgets/indicators/obt_balance_pill.dart';
import 'package:onebytwo/core/widgets/inputs/obt_category_chip.dart';
import 'package:onebytwo/core/widgets/inputs/obt_otp_input.dart';
import 'package:onebytwo/core/widgets/inputs/obt_segmented_split_control.dart';
import 'package:onebytwo/core/widgets/sheets/obt_settle_up_sheet.dart';
import 'package:onebytwo/core/widgets/sheets/obt_stepper_sheet.dart';
import 'package:onebytwo/features/expenses/domain/split_method.dart';

import 'golden_harness.dart';

/// Freezes animations so shimmer/spin/segment goldens capture a pinned,
/// deterministic frame (section A.2.5 / C.3).
Widget _frozen(Widget child) {
  return Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child,
    ),
  );
}

const _slices = <OBTCategorySlice>[
  OBTCategorySlice(category: OBTCategory.food, totalPaise: 60000),
  OBTCategorySlice(category: OBTCategory.transport, totalPaise: 30000),
  OBTCategorySlice(category: OBTCategory.shopping, totalPaise: 10000),
];

Map<String, Widget Function()> _cases() => <String, Widget Function()>{
  // #1 skeleton-loader set (loading silhouettes).
  'skeleton_list': () =>
      _frozen(const Scaffold(body: OBTSkeletonList(itemCount: 4))),
  'skeleton_card': () => _frozen(
    const Scaffold(
      body: Padding(padding: EdgeInsets.all(16), child: OBTSkeletonCard()),
    ),
  ),
  // #2 balance pill — the three branches.
  'balance_pill_positive': () => const Scaffold(
    body: Center(child: OBTBalancePill(netBalancePaise: 50000)),
  ),
  'balance_pill_negative': () => const Scaffold(
    body: Center(child: OBTBalancePill(netBalancePaise: -50000)),
  ),
  'balance_pill_zero': () =>
      const Scaffold(body: Center(child: OBTBalancePill(netBalancePaise: 0))),
  // #3 category chip — selection matrix.
  'category_chip_unselected': () => Scaffold(
    body: Center(
      child: OBTCategoryChip(
        category: OBTCategory.food,
        icon: Icons.restaurant,
        label: 'Food',
        selected: false,
        onSelected: (_) {},
      ),
    ),
  ),
  'category_chip_selected': () => Scaffold(
    body: Center(
      child: OBTCategoryChip(
        category: OBTCategory.food,
        icon: Icons.restaurant,
        label: 'Food',
        selected: true,
        onSelected: (_) {},
      ),
    ),
  ),
  // #4 stepper sheet shell.
  'stepper_sheet_step2': () => const OBTStepperSheet(
    currentStep: 2,
    totalSteps: 3,
    title: 'Add expense',
    stepBodies: <Widget>[
      SizedBox(height: 120),
      Center(child: Text('Step 2 — split and payer')),
      SizedBox(height: 120),
    ],
  ),
  // #5 segmented split control — neutral / adds-up / over / under.
  'segmented_addsup': () => _frozen(
    Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _split(totalPaise: 100000, allocatedPaise: 100000),
      ),
    ),
  ),
  'segmented_over': () => _frozen(
    Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _split(totalPaise: 100000, allocatedPaise: 120000),
      ),
    ),
  ),
  'segmented_under': () => _frozen(
    Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _split(totalPaise: 100000, allocatedPaise: 75000),
      ),
    ),
  ),
  // #6 settle-up sheet — editing / success / settled / error.
  'settleup_editing': _settleUp,
  'settleup_success': () => _settleUp(isSuccess: true),
  'settleup_settled': () => _settleUp(suggestedAmountPaise: 0),
  'settleup_error': () => _settleUp(amountErrorText: 'Enter an amount'),
  // #7 empty-state scaffold.
  'empty_with_cta': () => Scaffold(
    body: OBTEmptyState(
      illustration: const Icon(Icons.group_outlined, size: 64),
      headline: 'No friends yet',
      supportingText: 'Add a friend to start splitting.',
      ctaLabel: 'Add a friend',
      onCta: () {},
    ),
  ),
  // #8 offline / pending-sync banner.
  'offline_offline': () => _frozen(
    const Scaffold(body: OBTOfflineBanner(status: OBTSyncStatus.offline)),
  ),
  'offline_pending': () => _frozen(
    const Scaffold(
      body: OBTOfflineBanner(
        status: OBTSyncStatus.pendingSync,
        pendingCount: 3,
      ),
    ),
  ),
  // #9 donut + legend.
  'donut_populated': () => _frozen(
    const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            OBTSpendingDonut(slices: _slices, monthTotalPaise: 100000),
            SizedBox(height: 16),
            OBTCategoryLegend(slices: _slices, monthTotalPaise: 100000),
          ],
        ),
      ),
    ),
  ),
  // #11 OTP input — empty / error.
  'otp_empty': () => Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: OBTOtpInput(
        onDigitEntered: (_, _) {},
        onCompleted: (_) {},
        onBackspace: (_) {},
      ),
    ),
  ),
  'otp_error': () => Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: OBTOtpInput(
        onDigitEntered: (_, _) {},
        onCompleted: (_) {},
        onBackspace: (_) {},
        errorText: 'Incorrect code',
      ),
    ),
  ),
  // #13 brand kit.
  'brand_lockup': () => const Scaffold(body: Center(child: OBTBrandLockup())),
  'brand_splash': () => const OBTSplashGradient(child: OBTBrandLockup()),
};

Widget _split({required int totalPaise, required int allocatedPaise}) {
  return OBTSegmentedSplitControl(
    selected: SplitMethod.equal,
    enabledMethods: const <SplitMethod>{SplitMethod.equal, SplitMethod.exact},
    onMethodSelected: (_) {},
    totalPaise: totalPaise,
    allocatedPaise: allocatedPaise,
    onNext: () {},
  );
}

Widget _settleUp({
  int suggestedAmountPaise = 50000,
  bool isSuccess = false,
  String? amountErrorText,
}) {
  return _frozen(
    OBTSettleUpSheet(
      payerDisplayName: 'You',
      payeeDisplayName: 'Priya',
      suggestedAmountPaise: suggestedAmountPaise,
      onAmountChanged: (_) {},
      onRecord: () {},
      isSuccess: isSuccess,
      amountErrorText: amountErrorText,
    ),
  );
}

void main() {
  group(
    'Haldi shared components (DC-03)',
    () {
      setUp(loadHaldiFonts);

      _cases().forEach((name, build) {
        for (final brightness in Brightness.values) {
          final theme = brightness.name;
          testWidgets('$name ($theme)', (tester) async {
            await pumpForGolden(tester, build(), brightness: brightness);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/haldi_${name}__$theme.png'),
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
