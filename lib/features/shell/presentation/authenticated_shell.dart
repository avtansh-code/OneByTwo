import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/core/widgets/nav/obt_bottom_nav.dart';
import 'package:onebytwo/features/activity/presentation/activity_feed_screen.dart';
import 'package:onebytwo/features/auth/application/analytics_provider.dart';
import 'package:onebytwo/features/friends/presentation/friends_list_screen.dart';
import 'package:onebytwo/features/profile/presentation/profile_screen.dart';
import 'package:onebytwo/features/shell/application/shell_telemetry.dart';
import 'package:onebytwo/features/shell/presentation/groups_list_placeholder.dart';
import 'package:onebytwo/features/shell/presentation/home_dashboard_placeholder.dart';

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
/// - §2.2: in-shell `setState` — no Riverpod `Notifier<int>` until a
///   second consumer (e.g. FCM cold-start deep-link expansion) needs
///   programmatic tab switching.
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
  /// widgets (Home placeholder, [FriendsListScreen],
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
  int _currentIndex = 0;

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
      HomeDashboardPlaceholder(),
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
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() => _currentIndex = 0);
      },
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _tabContent),
        bottomNavigationBar: OBTBottomNav(
          currentIndex: _currentIndex,
          onTabSelected: _onTabSelected,
        ),
      ),
    );
  }
}
