/// Split methods supported by the expense schema.
///
/// PR #38 ships `equal` and `exact` as enabled, working chips on
/// SCR-20; the other three values are present in the enum to preserve
/// schema compatibility with the security rules' allow-list at
/// `firestore.rules` line 204 and with the future PRs that will enable
/// them as UI choices. The Add Expense controller treats their
/// selection as a no-op (silent disable, no telemetry).
enum SplitMethod {
  /// 50/50 split between two friendship members; the splitter places
  /// any odd-paise remainder on the first share (current-user-first).
  equal,

  /// Per-member share values supplied by the user; the controller
  /// gates Save on `sum(shares) == amountPaise` (FR-EX-04).
  exact,

  /// Reserved — disabled chip with a "Coming soon" tooltip in PR #38.
  unequal,

  /// Reserved — disabled chip with a "Coming soon" tooltip in PR #38.
  percentage,

  /// Reserved — disabled chip with a "Coming soon" tooltip in PR #38.
  shares,
}

/// Returns true when [method] has a working implementation in PR #38.
/// The disabled chips on SCR-20 use this gate to render the "Coming
/// soon" affordance without firing any event when tapped.
bool isSplitMethodEnabled(SplitMethod method) {
  return method == SplitMethod.equal || method == SplitMethod.exact;
}
