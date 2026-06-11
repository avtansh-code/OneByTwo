/// Telemetry event-name, parameter-key, and tab-label-token constants
/// for the authenticated shell's bottom-nav AND the persistent
/// Add-Expense FAB + context picker (FR-HD-04).
///
/// Three events ship from this surface:
///   1. `bottom_nav_tab_selected` — fires on every user-initiated tab
///      tap (NOT on programmatic switches such as the PopScope
///      back-button snap-to-zero — see architect §2.6).
///   2. `fab_tapped` — fires on every Add-Expense FAB tap, with the
///      canonical lowercase `source_tab` token from
///      `tabLabel{Home,Friends,Groups,Activity,Profile}`. PRE-DECLARED
///      in `docs/design/07-technical/telemetry-plan.md` §1.3 line 88.
///   3. `expense_context_selected` — fires when the user picks a
///      friend (or taps the Groups stub row) inside the context
///      picker. Carries only `context_type` ∈ {`friend`, `group`}.
///      PRE-DECLARED in `telemetry-plan.md` §1.3 line 89.
///
/// PII guard per ADR-0013: NONE of the payloads carry UID-derived
/// parameters. `tab_index` (int 0..4), `tab_label`, `source_tab`, and
/// `context_type` are all safe non-identifying values. The defence-in-
/// depth grep in `test/features/shell/shell_boundary_contract_test.dart`
/// enforces.
///
/// Reference: `docs/design/07-technical/telemetry-plan.md` §1.3
/// (FR-HD-04 events) and §1.8 (Cross-Cutting Events for the bottom
/// nav).
library;

// ---------------------------------------------------------------------------
// Event names.
// ---------------------------------------------------------------------------

/// User tapped a tab in the bottom nav. Shell-emitted.
const String bottomNavTabSelectedEvent = 'bottom_nav_tab_selected';

/// User tapped the persistent Add-Expense FAB. Shell-emitted.
const String fabTappedEvent = 'fab_tapped';

/// User selected a context (friend / group) inside the Add-Expense
/// context picker. Picker-emitted.
const String expenseContextSelectedEvent = 'expense_context_selected';

// ---------------------------------------------------------------------------
// Parameter keys.
// ---------------------------------------------------------------------------

/// The zero-based tab index (0..4). Parameter on
/// [bottomNavTabSelectedEvent].
const String tabIndexParam = 'tab_index';

/// The canonical lowercase tab token. Parameter on
/// [bottomNavTabSelectedEvent].
const String tabLabelParam = 'tab_label';

/// The canonical lowercase tab token of the tab the user was on when
/// they tapped the FAB. Parameter on [fabTappedEvent].
const String sourceTabParam = 'source_tab';

/// The type of context the user picked (`friend` / `group`). Parameter
/// on [expenseContextSelectedEvent].
const String contextTypeParam = 'context_type';

// ---------------------------------------------------------------------------
// Tab label tokens — match the canonical lowercase strings used by the
// design spec at `docs/design/02-design-system/components.md §2`. Kept
// as top-level constants so the shell, the bottom-nav primitive, and
// the telemetry test all reference the same source of truth. The same
// five tokens are reused as `source_tab` parameter values on the
// `fab_tapped` event (FR-HD-04) — no duplicate token set.
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

// ---------------------------------------------------------------------------
// Context-type tokens — emitted as the `context_type` parameter on the
// `expense_context_selected` event. See `telemetry-plan.md §1.3` line
// 89 for the safe-enum contract.
// ---------------------------------------------------------------------------

/// User selected a friend in the context picker.
const String contextTypeFriend = 'friend';

/// User tapped the Groups stub row in the context picker (the real
/// Groups path ships in Sprint 3).
const String contextTypeGroup = 'group';
