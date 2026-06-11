import 'package:flutter/material.dart';

import 'package:onebytwo/features/shell/application/shell_telemetry.dart';

/// Design-system primitive for the One By Two five-tab bottom navigation
/// bar. See `docs/design/02-design-system/components.md §2 OBTBottomNav`.
///
/// **Tabs (fixed):**
///
/// | Index | Label | Outlined / Filled icon |
/// |---|---|---|
/// | 0 | Home | [Icons.home_outlined] / [Icons.home] |
/// | 1 | Friends | [Icons.people_outline] / [Icons.people] |
/// | 2 | Groups | [Icons.groups_outlined] / [Icons.groups] |
/// | 3 | Activity | [Icons.notifications_outlined] / [Icons.notifications] |
/// | 4 | Profile | [Icons.person_outline] / [Icons.person] |
///
/// The active tab uses [ColorScheme.primary] for the label colour and
/// renders the filled icon variant; inactive tabs use
/// [ColorScheme.onSurfaceVariant] and the outlined variant. Minimum
/// tap target per tab is 48x48 dp (Material's default).
///
/// `BottomNavigationBar.type` is pinned to [BottomNavigationBarType.fixed]
/// per the spec ("five-tab bottom navigation bar" — fixed, not shifting).
///
/// **Note on the indicator pill.** `components.md §2` ratifies an
/// "indicator pill behind icon" for the active tab. Flutter's
/// [BottomNavigationBar] does not render this pill (it is a Material 3
/// [NavigationBar] feature). Per architect §2.10 reconciliation 4 the
/// pill is omitted for v1.0; the icon-fill-on-select + colour-tint-on-
/// select pattern is the canonical Material 2/3 affordance.
class OBTBottomNav extends StatelessWidget {
  /// Creates the bottom navigation bar.
  const OBTBottomNav({
    required this.currentIndex,
    required this.onTabSelected,
    super.key,
  });

  /// Index of the active tab (0..4).
  final int currentIndex;

  /// Callback invoked when the user taps a tab. Fires for every tap,
  /// including taps on the already-active tab (Material's default).
  final ValueChanged<int> onTabSelected;

  /// The canonical tab definitions — single source of truth for labels,
  /// icons, and telemetry tokens. Consumed by the authenticated shell
  /// when firing the `bottom_nav_tab_selected` telemetry event.
  static const List<OBTBottomNavTab> tabs = <OBTBottomNavTab>[
    OBTBottomNavTab(
      label: 'Home',
      telemetryLabel: tabLabelHome,
      outlinedIcon: Icons.home_outlined,
      filledIcon: Icons.home,
    ),
    OBTBottomNavTab(
      label: 'Friends',
      telemetryLabel: tabLabelFriends,
      outlinedIcon: Icons.people_outline,
      filledIcon: Icons.people,
    ),
    OBTBottomNavTab(
      label: 'Groups',
      telemetryLabel: tabLabelGroups,
      outlinedIcon: Icons.groups_outlined,
      filledIcon: Icons.groups,
    ),
    OBTBottomNavTab(
      label: 'Activity',
      telemetryLabel: tabLabelActivity,
      outlinedIcon: Icons.notifications_outlined,
      filledIcon: Icons.notifications,
    ),
    OBTBottomNavTab(
      label: 'Profile',
      telemetryLabel: tabLabelProfile,
      outlinedIcon: Icons.person_outline,
      filledIcon: Icons.person,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTabSelected,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: theme.colorScheme.primary,
      unselectedItemColor: theme.colorScheme.onSurfaceVariant,
      items: <BottomNavigationBarItem>[
        for (final tab in tabs)
          BottomNavigationBarItem(
            icon: Icon(tab.outlinedIcon),
            activeIcon: Icon(tab.filledIcon),
            label: tab.label,
            tooltip: tab.label,
          ),
      ],
    );
  }
}

/// Static definition of a single tab in [OBTBottomNav]. Carries the
/// visible label, the lowercase telemetry token, and the outlined /
/// filled icon pair.
@immutable
class OBTBottomNavTab {
  /// Creates a tab definition.
  const OBTBottomNavTab({
    required this.label,
    required this.telemetryLabel,
    required this.outlinedIcon,
    required this.filledIcon,
  });

  /// Visible label shown beneath the icon. Title-cased per the design
  /// spec (e.g. `Home`).
  final String label;

  /// Lowercase token emitted as the `tab_label` parameter on the
  /// `bottom_nav_tab_selected` telemetry event.
  final String telemetryLabel;

  /// Icon shown when the tab is inactive.
  final IconData outlinedIcon;

  /// Icon shown when the tab is active.
  final IconData filledIcon;
}
