import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/widgets/nav/obt_bottom_nav.dart';
import 'package:onebytwo/core/widgets/nav/obt_floating_action_button.dart';
import 'package:onebytwo/features/activity/presentation/activity_feed_screen.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/presentation/friends_list_screen.dart';
import 'package:onebytwo/features/home/presentation/home_dashboard_screen.dart';
import 'package:onebytwo/features/profile/presentation/profile_screen.dart';
import 'package:onebytwo/features/shell/application/shell_navigation_controller.dart';
import 'package:onebytwo/features/shell/application/shell_telemetry.dart';
import 'package:onebytwo/features/shell/presentation/add_expense_context_picker_sheet.dart';
import 'package:onebytwo/features/shell/presentation/groups_list_placeholder.dart';

/// Authenticated-area shell that hosts the five primary tabs
/// (Home / Friends / Groups / Activity / Profile) via an
/// [IndexedStack] for tab-state preservation.
///
/// See `docs/design/01-information-architecture/navigation-flow.md §1`
/// (the `MainTabs` subgraph at lines 80-88 enumerates the five
/// primary destinations) and `docs/design/02-design-system/components.md §2`
/// for the bottom-nav contract.
///
/// **Architectural notes (chore story §Architect Notes).**
/// - §2.1: IndexedStack — chosen over `go_router ShellRoute` for v1.0;
///   the migration is a Sprint 3 standalone chore.
/// - §2.2: the active tab index is owned by
///   `shellNavigationControllerProvider` (a Riverpod `Notifier<int>`).
///   The PR #56 deferral ("no `Notifier<int>` until a second consumer
///   needs programmatic tab switching") is now IMPLEMENTED — FR-PR-04's
///   Profile "My Friends / My Groups" rows are that second consumer and
///   drive `selectTab(1)` / `selectTab(2)`.
/// - §2.6: [PopScope] snap-to-tab-0 on Android back when on a
///   non-zero tab. The back-driven switch does NOT fire telemetry —
///   the `bottom_nav_tab_selected` event is reserved for user-initiated
///   tab taps.
/// - §2.10 reconciliation 2: the shell does NOT inject an outer
///   [AppBar]; every tab content widget owns its own.
class AuthenticatedShell extends ConsumerStatefulWidget {
  /// Creates the authenticated shell.
  ///
  /// In production, the shell mounts the canonical tab content
  /// widgets ([HomeDashboardScreen], [FriendsListScreen],
  /// [GroupsListPlaceholder], [ActivityFeedScreen], [ProfileScreen]).
  /// Tests may override via [tabContentOverride] to isolate shell
  /// behaviour from per-feature provider graphs.
  const AuthenticatedShell({this.tabContentOverride, super.key});

  /// @nodoc — testing-only override of the production tab content list.
  /// MUST be exactly 5 widgets in tab order if provided.
  @visibleForTesting
  final List<Widget>? tabContentOverride;

  @override
  ConsumerState<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends ConsumerState<AuthenticatedShell> {
  late final List<Widget> _tabContent = _resolveTabContent();

  List<Widget> _resolveTabContent() {
    final override = widget.tabContentOverride;
    if (override != null) {
      assert(
        override.length == OBTBottomNav.tabs.length,
        'tabContentOverride must contain exactly '
        '${OBTBottomNav.tabs.length} widgets (got ${override.length})',
      );
      return override;
    }
    return const <Widget>[
      HomeDashboardScreen(),
      FriendsListScreen(),
      GroupsListPlaceholder(),
      ActivityFeedScreen(),
      ProfileScreen(),
    ];
  }

  void _onTabSelected(int index) {
    if (index < 0 || index >= OBTBottomNav.tabs.length) {
      return;
    }
    final tab = OBTBottomNav.tabs[index];
    ref
        .read(analyticsServiceProvider)
        .logEvent(
          name: bottomNavTabSelectedEvent,
          parameters: <String, Object>{
            tabIndexParam: index,
            tabLabelParam: tab.telemetryLabel,
          },
        );
    ref.read(shellNavigationControllerProvider.notifier).selectTab(index);
  }

  void _onFabTapped() {
    // FR-HD-04 — emit fab_tapped with the source_tab token of the
    // currently-active tab, then open the AddExpenseContextPickerSheet
    // as a modal bottom sheet. PII guard: payload carries ONLY the
    // canonical lowercase tab token (no UID-derived parameters).
    // See `docs/design/07-technical/telemetry-plan.md §1.3` line 88.
    //
    // Telemetry is deliberately fire-and-forget here (no `await` on
    // `logEvent`) so the modal sheet opens on the same frame as the
    // FAB tap — primary-action latency must never be coupled to the
    // analytics SDK. The picker's per-row handlers
    // (`_onFriendSelected`, `_onGroupsTapped` in
    // `add_expense_context_picker_sheet.dart`) DO `await` their
    // `logEvent` calls because they sequence with `Navigator.pop` /
    // `ScaffoldMessenger.showSnackBar` where ordering matters; the
    // FAB-tap path has no such sequencing requirement.
    final sourceTab = OBTBottomNav
        .tabs[ref.read(shellNavigationControllerProvider)]
        .telemetryLabel;
    ref
        .read(analyticsServiceProvider)
        .logEvent(
          name: fabTappedEvent,
          parameters: <String, Object>{sourceTabParam: sourceTab},
        );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddExpenseContextPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(shellNavigationControllerProvider);
    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Direct notifier call (NOT via `_onTabSelected`) so the
        // back-driven snap-to-tab-0 emits NO `bottom_nav_tab_selected`
        // telemetry — architect §2.6 / AC-7.
        ref.read(shellNavigationControllerProvider.notifier).selectTab(0);
      },
      child: Scaffold(
        body: IndexedStack(index: currentIndex, children: _tabContent),
        floatingActionButton: OBTFloatingActionButton(onPressed: _onFabTapped),
        bottomNavigationBar: OBTBottomNav(
          currentIndex: currentIndex,
          onTabSelected: _onTabSelected,
        ),
      ),
    );
  }
}
