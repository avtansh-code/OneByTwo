import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/core/widgets/nav/obt_bottom_nav.dart';

/// Owns the authenticated shell's active primary-tab index (0..4),
/// replacing the former in-shell `setState(_currentIndex)`
/// (PR #56 shell story Architect Notes §2.2 — deferred "until a second
/// consumer needs it"; FR-PR-04's Profile "My Friends/Groups" rows are
/// that consumer).
///
/// Root-scoped (watches no scoped provider → no `dependencies` list).
/// `autoDispose`: the shell `ref.watch`es it, so it lives for the
/// shell's lifetime and auto-resets to 0 (Home) when the shell unmounts
/// on sign-out — reproducing the previous "fresh shell mounts on tab 0"
/// behaviour with no dispose-time `ref` access.
final shellNavigationControllerProvider =
    NotifierProvider.autoDispose<ShellNavigationController, int>(
      ShellNavigationController.new,
    );

/// Notifier backing [shellNavigationControllerProvider].
class ShellNavigationController extends AutoDisposeNotifier<int> {
  @override
  int build() => 0;

  /// Programmatically select a primary tab. Out-of-range indices are
  /// ignored. Emits NO telemetry — `bottom_nav_tab_selected` is emitted
  /// only by the shell's user-tap handler (`_onTabSelected`).
  void selectTab(int index) {
    if (index < 0 || index >= OBTBottomNav.tabs.length) return;
    state = index;
  }
}
