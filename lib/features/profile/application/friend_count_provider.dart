import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';

/// FR-PR-04 — the signed-in user's **friend count** for the Profile
/// Stats "My Friends" row. Pure read-side projection of
/// [friendsListProvider] into its cardinality (`items.length`).
///
/// Mirrors the upstream async lifecycle: AsyncLoading while the first
/// Firestore snapshot resolves, AsyncError if the stream fails (the row
/// renders an em dash, never a crash), otherwise AsyncData<int>.
///
/// Declares `dependencies: [friendsListProvider]` because
/// `friendsListProvider` is itself scoped on the per-arm
/// `currentUserIdProvider` override (lib/main.dart); a provider that
/// watches it must list it or Riverpod throws the "specified a
/// 'dependencies' list" assert at first read. (Same rule as
/// `overallNetBalanceProvider` in the home feature.)
///
/// READ-ONLY over `simplifiedBalances` (Invariant 2).
final friendCountProvider = Provider<AsyncValue<int>>((ref) {
  final friendsAsync = ref.watch(friendsListProvider);
  return friendsAsync.whenData((items) => items.length);
}, dependencies: [friendsListProvider]);
