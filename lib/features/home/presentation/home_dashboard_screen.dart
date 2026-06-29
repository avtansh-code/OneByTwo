import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/app/theme.dart';
import 'package:onebytwo/core/formatters/inr_formatter.dart';
import 'package:onebytwo/core/telemetry/event_id_hash.dart';
import 'package:onebytwo/core/theme/obt_colors.dart';
import 'package:onebytwo/core/theme/obt_text.dart';
import 'package:onebytwo/core/widgets/branding/obt_gradient_avatar.dart';
import 'package:onebytwo/core/widgets/feedback/obt_skeleton.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/auth/application/auth_state_provider.dart';
import 'package:onebytwo/features/auth/domain/auth_state.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/presentation/add_friend_flow.dart';
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
import 'package:onebytwo/features/shell/application/shell_navigation_controller.dart';
import 'package:onebytwo/features/shell/presentation/add_expense_context_picker_sheet.dart';

/// Home dashboard (SCR-06 / FR-HD-01 + FR-HD-02), tab 0 of the
/// authenticated shell. Replaces the temporary `HomeDashboardPlaceholder`.
///
/// Renders the four SCR-06 states by composing the friendship balance
/// axis (no new data layer):
///
/// - **Loading**: skeleton placeholders while the first Firestore
///   snapshot resolves.
/// - **Empty**: new user with no non-zero balances — a settled-up ₹0.00
///   hero, a friendly receipt illustration, and the dual "Add an
///   expense" / "Invite a friend" CTAs.
/// - **Populated**: the FR-HD-01 net-balance header card, the FR-HD-02
///   "Top balances" list (each row with a "Settle Up" action and
///   tile-tap navigation to Friend Detail, plus a "See all" jump to the
///   Friends tab), and the FR-HD-03 "This Month" spend-breakdown card.
/// - **Error** (`HD-FIRESTORE-READ`): a retry affordance plus a Contact
///   Support link reusing the FR-PR-05 flow.
///
/// A greeting header (the user's first name + a search affordance + the
/// gradient profile avatar) replaces the AppBar and sits above every
/// state. The state machine is driven by [topBalancesProvider]'s async
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
///   Support link uses the FR-PR-05 `mailto:` flow; the empty-state
///   "Invite a friend" CTA hands off to the OS system share sheet via
///   the add-friend flow — never an app-specific target.
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The greeting header replaces the AppBar and sits above every
            // state (loading / empty / populated / error) for a consistent
            // top-of-screen identity.
            _GreetingHeader(
              onSearch: _onSearchTapped,
              onAvatar: _onAvatarTapped,
            ),
            Expanded(
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
                    return _EmptyState(
                      onAddExpense: _onEmptyAddExpenseTapped,
                      onInviteFriend: _onInviteFriendTapped,
                    );
                  }
                  final netPaise =
                      ref.watch(overallNetBalanceProvider).valueOrNull ?? 0;
                  final friendCount =
                      ref.watch(friendsListProvider).valueOrNull?.length ?? 0;
                  _logViewedOnce(HomeTelemetry.netBalanceStateFor(netPaise));
                  return _PopulatedState(
                    netBalancePaise: netPaise,
                    friendCount: friendCount,
                    topItems: topItems,
                    onTileTap: _onTileTapped,
                    onSettleUp: _onSettleUpTapped,
                    onSeeAllFriends: _onSeeAllFriendsTapped,
                  );
                },
              ),
            ),
          ],
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

  /// Empty-state secondary CTA — opens the add-friend flow, whose invite
  /// path hands off to the OS system share sheet (Invariant 3). The phone
  /// is read lazily here (not during build) so the screen renders even
  /// before [currentUserPhoneProvider] is in scope.
  void _onInviteFriendTapped() {
    unawaited(
      openAddFriendFlow(
        context: context,
        currentUserId: ref.read(currentUserIdProvider),
        currentUserPhone: ref.read(currentUserPhoneProvider),
      ),
    );
  }

  /// Header search affordance. Search (SCR-07) is not built yet, so this
  /// surfaces a "coming soon" SnackBar (mirroring the Groups slot in the
  /// add-expense picker) rather than navigating.
  void _onSearchTapped() {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('Search is coming soon.')));
  }

  /// Header avatar tap — jump to the Profile tab (index 4) of the shell.
  void _onAvatarTapped() {
    ref.read(shellNavigationControllerProvider.notifier).selectTab(4);
  }

  /// "See all" link in the Top balances header — jump to the Friends tab
  /// (index 1) of the shell.
  void _onSeeAllFriendsTapped() {
    ref.read(shellNavigationControllerProvider.notifier).selectTab(1);
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

/// The greeting header that replaces the AppBar (SCR-06). Left: a
/// "Namaste," label over the signed-in user's first name; right: a search
/// affordance and the gradient profile avatar. The user comes from
/// [authStateProvider]; if the profile is unavailable the name line is
/// omitted (just "Namaste,") — the header never crashes on a missing user.
class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader({required this.onSearch, required this.onAvatar});

  final VoidCallback onSearch;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;

    final authState = ref.watch(authStateProvider).valueOrNull;
    final user = switch (authState) {
      AuthenticatedWithProfile(:final user) => user,
      _ => null,
    };
    final displayName = user?.displayName.trim() ?? '';
    final firstName = displayName.isEmpty ? null : displayName.split(' ').first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Namaste,',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OBTColors.metaText(theme),
                  ),
                ),
                if (firstName != null)
                  Text(
                    firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          MergeSemantics(
            child: Semantics(
              button: true,
              label: 'Search',
              child: InkWell(
                onTap: onSearch,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: obtColors.rowShadow,
                  ),
                  child: Icon(Icons.search, size: 21, color: colors.onSurface),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          MergeSemantics(
            child: Semantics(
              button: true,
              label: 'Profile',
              child: InkWell(
                onTap: onAvatar,
                borderRadius: BorderRadius.circular(38 * 0.33),
                child: ExcludeSemantics(
                  child: OBTGradientAvatar(
                    size: 38,
                    displayName: firstName == null ? null : displayName,
                    photoUrl: user?.photoUrl,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddExpense, required this.onInviteFriend});

  final VoidCallback onAddExpense;
  final VoidCallback onInviteFriend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    final isDark = theme.brightness == Brightness.dark;
    final metaColor = OBTColors.metaText(theme);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Settled-up zero hero (₹0.00, "no balances yet").
        Container(
          margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF241D16) : const Color(0xFFEFE9DD),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: metaColor),
                  const SizedBox(width: 7),
                  Text(
                    "You're all settled up",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 13,
                      color: metaColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                formatInrFromPaise(0),
                style: OBTText.amountHero(
                  context,
                ).copyWith(fontSize: 42, color: obtColors.balanceZero),
              ),
              const SizedBox(height: 9),
              Text(
                'No balances yet — add your first expense.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12.5,
                  color: metaColor,
                ),
              ),
            ],
          ),
        ),
        // Illustration + copy + dual CTA.
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 40, 30, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.receipt_long,
                            size: 56,
                            color: colors.primary,
                          ),
                        ),
                        Positioned(
                          right: 14,
                          bottom: 14,
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: obtColors.balancePositive,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  "Let's split your first bill",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add an expense or invite a friend, and balances will show '
                'up right here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 14,
                  color: metaColor,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onAddExpense,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                  ),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add an expense'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onInviteFriend,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.onSurface,
                  minimumSize: const Size.fromHeight(50),
                  side: BorderSide(color: colors.outline, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusButton),
                  ),
                ),
                icon: const Icon(Icons.person_add, size: 20),
                label: const Text('Invite a friend'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PopulatedState extends StatelessWidget {
  const _PopulatedState({
    required this.netBalancePaise,
    required this.friendCount,
    required this.topItems,
    required this.onTileTap,
    required this.onSettleUp,
    required this.onSeeAllFriends,
  });

  final int netBalancePaise;
  final int friendCount;
  final List<FriendListItem> topItems;
  final void Function(FriendListItem item) onTileTap;
  final void Function(FriendListItem item) onSettleUp;
  final VoidCallback onSeeAllFriends;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final obtColors = theme.extension<OBTColors>() ?? OBTColors.light;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        NetBalanceHeaderCard(
          netBalancePaise: netBalancePaise,
          friendCount: friendCount,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Top balances',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'See all friends',
                child: InkWell(
                  onTap: onSeeAllFriends,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: ExcludeSemantics(
                      child: Text(
                        'See all',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: obtColors.link,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
