/// Telemetry event-name, parameter-key, and tab-label-token constants
/// for the [AuthenticatedShell] bottom-nav.
///
/// One event ships with this surface: `bottom_nav_tab_selected`. It
/// fires on every user-initiated tab tap (NOT on programmatic switches
/// such as the PopScope back-button snap-to-zero — see architect §2.6).
///
/// PII guard per ADR-0013: the payload carries only `tab_index` (int,
/// 0..4) and `tab_label` (lowercase string from the canonical set
/// `home` / `friends` / `groups` / `activity` / `profile`). No
/// UID-derived parameters. The defence-in-depth grep in
/// `test/features/shell/shell_boundary_contract_test.dart` enforces.
///
/// Reference: `docs/design/07-technical/telemetry-plan.md` §1.8
/// Cross-Cutting Events (the event is appended in this PR).
library;

// ---------------------------------------------------------------------------
// Event name.
// ---------------------------------------------------------------------------

/// User tapped a tab in [OBTBottomNav]. Single client event for the
/// shell surface.
const String bottomNavTabSelectedEvent = 'bottom_nav_tab_selected';

// ---------------------------------------------------------------------------
// Parameter keys.
// ---------------------------------------------------------------------------

/// The zero-based tab index (0..4).
const String tabIndexParam = 'tab_index';

/// The canonical lowercase tab token. One of the `tabLabel*` constants
/// below.
const String tabLabelParam = 'tab_label';

// ---------------------------------------------------------------------------
// Tab label tokens — match the canonical lowercase strings used by the
// design spec at `docs/design/02-design-system/components.md §2`. Kept
// as top-level constants so the shell, the bottom-nav primitive, and
// the telemetry test all reference the same source of truth.
// ---------------------------------------------------------------------------

/// Tab 0 — Home dashboard.
const String tabLabelHome = 'home';

/// Tab 1 — Friends list.
const String tabLabelFriends = 'friends';

/// Tab 2 — Groups list.
const String tabLabelGroups = 'groups';

/// Tab 3 — Activity feed.
const String tabLabelActivity = 'activity';

/// Tab 4 — Profile and settings.
const String tabLabelProfile = 'profile';
