import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/widgets/feedback/obt_empty_state.dart';
import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/presentation/friend_detail_screen.dart';
import 'package:onebytwo/features/home/application/home_balances_providers.dart';
import 'package:onebytwo/features/home/application/home_telemetry.dart';
import 'package:onebytwo/features/home/presentation/widgets/net_balance_header_card.dart';
import 'package:onebytwo/features/home/presentation/widgets/spending_breakdown_card.dart';
import 'package:onebytwo/features/home/presentation/widgets/top_balance_tile.dart';
import 'package:onebytwo/features/profile/application/contact_support_controller.dart';
import 'package:onebytwo/features/profile/presentation/contact_support_fallback_dialog.dart';
import 'package:onebytwo/features/settlements/application/settle_up_telemetry.dart';
import 'package:onebytwo/features/settlements/presentation/settle_up_bottom_sheet.dart';
import 'package:onebytwo/features/shell/presentation/add_expense_context_picker_sheet.dart';

/// Home dashboard (SCR-06 / FR-HD-01 + FR-HD-02), tab 0 of the
/// authenticated shell. Replaces the temporary `HomeDashboardPlaceholder`.
///
/// Renders the four SCR-06 states by composing the friendship balance
/// axis (no new data layer):
///
/// - **Loading**: skeleton placeholders while the first Firestore
///   snapshot resolves.
/// - **Empty**: new user with no non-zero balances — the empty-state
///   illustration and an "Add Expense" CTA.
/// - **Populated**: the FR-HD-01 net-balance header card, the FR-HD-02
///   "Top Balances" list (each row with a "Settle Up" action and
///   tile-tap navigation to Friend Detail), and the FR-HD-03 "This
///   Month" spend-breakdown card.
/// - **Error** (`HD-FIRESTORE-READ`): a retry affordance plus a Contact
///   Support link reusing the FR-PR-05 flow.
///
/// The state machine is driven by [topBalancesProvider]'s async
/// lifecycle (which mirrors the upstream `friendsListProvider`); the
/// header reads [overallNetBalanceProvider]. Empty vs populated is
/// discriminated by whether any non-zero balance exists — so a user who
/// is settled up overall but has offsetting individual balances still
/// sees the populated state with a settled-up header (SCR-06 Edge
/// Case 1).
///
/// Invariant compliance:
/// - **Invariant 1 (paise)**: balances flow as `int`; every rupee string
///   is produced by `formatInrFromPaise()` inside the child widgets.
/// - **Invariant 2 (`simplifiedBalances` read-only)**: the dashboard only
///   reads the field through the friends-list stream; it never writes.
/// - **Invariant 3 (system share sheet)**: the error-state Contact
///   Support link uses the FR-PR-05 `mailto:` flow, not the share sheet.
class HomeDashboardScreen extends ConsumerStatefulWidget {
  /// Creates a [HomeDashboardScreen].
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  bool _loggedView = false;
  int _retryAttempts = 0;

  @override
  Widget build(BuildContext context) {
    final topAsync = ref.watch(topBalancesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(header: true, child: const Text('Home')),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: topAsync.when(
          loading: () => const _LoadingState(),
          error: (error, stack) {
            _logViewedOnce(HomeTelemetry.netBalanceStateError);
            return _ErrorState(
              showSecondTryCopy: _retryAttempts >= 1,
              onRetry: _onRetry,
              onContactSupport: _onContactSupport,
            );
          },
          data: (topItems) {
            if (topItems.isEmpty) {
              _logViewedOnce(HomeTelemetry.netBalanceStateZero);
              return _EmptyState(onAddExpense: _onEmptyAddExpenseTapped);
            }
            final netPaise =
                ref.watch(overallNetBalanceProvider).valueOrNull ?? 0;
            _logViewedOnce(HomeTelemetry.netBalanceStateFor(netPaise));
            return _PopulatedState(
              netBalancePaise: netPaise,
              topItems: topItems,
              onTileTap: _onTileTapped,
              onSettleUp: _onSettleUpTapped,
            );
          },
        ),
      ),
    );
  }

  void _logViewedOnce(String netBalanceState) {
    if (_loggedView) return;
    _loggedView = true;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: HomeTelemetry.viewed,
            parameters: <String, Object>{
              HomeTelemetry.paramNetBalanceState: netBalanceState,
            },
          ),
    );
  }

  void _onRetry() {
    _retryAttempts += 1;
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: HomeTelemetry.errorRetryTapped,
            parameters: <String, Object>{
              HomeTelemetry.paramAttemptNumber: _retryAttempts,
            },
          ),
    );
    ref.invalidate(friendsListProvider);
  }

  Future<void> _onContactSupport() async {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: HomeTelemetry.errorSupportTapped,
            parameters: <String, Object>{
              HomeTelemetry.paramErrorCode:
                  HomeTelemetry.errorCodeFirestoreRead,
            },
          ),
    );
    final result = await ref
        .read(contactSupportControllerProvider)
        .contactSupport();
    if (!mounted) return;
    if (result is ContactSupportFallbackRequired) {
      await ContactSupportFallbackDialog.show(
        context,
        supportEmailAddress: result.supportEmailAddress,
      );
    }
  }

  void _onEmptyAddExpenseTapped() {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(name: HomeTelemetry.emptyCtaTapped),
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddExpenseContextPickerSheet(),
    );
  }

  void _onTileTapped(FriendListItem item) {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: HomeTelemetry.tileTapped,
            parameters: <String, Object>{
              HomeTelemetry.paramContextType: HomeTelemetry.contextTypeFriend,
              HomeTelemetry.paramContextIdHash: hashFriendshipId(
                item.friendshipId,
              ),
            },
          ),
    );
    final currentUid = ref.read(currentUserIdProvider);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FriendDetailScreen(
          friendshipId: item.friendshipId,
          currentUserUid: currentUid,
          otherUserUid: item.otherUserId,
        ),
      ),
    );
  }

  void _onSettleUpTapped(FriendListItem item) {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: HomeTelemetry.settleUpTapped,
            parameters: <String, Object>{
              HomeTelemetry.paramContextType: HomeTelemetry.contextTypeFriend,
              HomeTelemetry.paramContextIdHash: hashFriendshipId(
                item.friendshipId,
              ),
              HomeTelemetry.paramAmountRange: SettleUpTelemetry.amountRangeFor(
                item.netBalancePaise.abs(),
              ),
            },
          ),
    );
    final currentUid = ref.read(currentUserIdProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => SettleUpBottomSheet(
        friendshipId: item.friendshipId,
        currentUserUid: currentUid,
        otherUserUid: item.otherUserId,
        otherDisplayName: item.displayName,
        otherUserPhotoUrl: item.photoUrl,
        suggestedAmountPaise: item.netBalancePaise.abs(),
        source: 'home_dashboard',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading content',
      child: ListView(
        key: const Key('home_dashboard_skeleton'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: OBTSkeleton(
              height: 96,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            ),
          ),
          for (var i = 0; i < 5; i++) const OBTSkeletonRow(announce: false),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddExpense});

  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    return OBTEmptyState(
      illustration: const Icon(Icons.account_balance_wallet_outlined, size: 72),
      headline: 'No expenses yet',
      supportingText: 'Add your first expense and start splitting!',
      ctaLabel: 'Add Expense',
      onCta: onAddExpense,
    );
  }
}

class _PopulatedState extends StatelessWidget {
  const _PopulatedState({
    required this.netBalancePaise,
    required this.topItems,
    required this.onTileTap,
    required this.onSettleUp,
  });

  final int netBalancePaise;
  final List<FriendListItem> topItems;
  final void Function(FriendListItem item) onTileTap;
  final void Function(FriendListItem item) onSettleUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        NetBalanceHeaderCard(netBalancePaise: netBalancePaise),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Semantics(
            header: true,
            child: Text(
              'Top Balances',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        for (final item in topItems)
          TopBalanceTile(
            key: ValueKey('home_top_balance_${item.friendshipId}'),
            item: item,
            onTap: () => onTileTap(item),
            onSettleUp: () => onSettleUp(item),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Semantics(
            header: true,
            child: Text(
              'This Month',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SpendingBreakdownCard(),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.showSecondTryCopy,
    required this.onRetry,
    required this.onContactSupport,
  });

  final bool showSecondTryCopy;
  final VoidCallback onRetry;
  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                'Something went wrong',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              showSecondTryCopy
                  ? 'Still not working. Try again or contact support.'
                  : 'We could not load your balances. Please check your '
                        'connection and try again.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: OBTColors.metaText(theme),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onContactSupport,
              child: const Text('Contact Support'),
            ),
            const SizedBox(height: 8),
            Text(
              'Error code: ${HomeTelemetry.errorCodeFirestoreRead}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: OBTColors.metaText(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
