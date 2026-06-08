import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onebytwo/features/activity/data/activity_feed_repository.dart';
import 'package:onebytwo/features/activity/domain/activity_feed_item.dart';
import 'package:onebytwo/features/friends/application/friends_list_provider.dart';

/// Real-time projection of the current user's activity items into a
/// `List<ActivityFeedItem>` for the SCR-25 Activity Feed screen
/// (FR-AC-01).
///
/// Pipeline:
/// 1. Read the current user's UID from [currentUserIdProvider].
/// 2. Subscribe to
///    `activityFeedRepositoryProvider.watchItems(uid)` — a Firestore
///    snapshot stream filtered to the user's own subcollection,
///    ordered by `createdAt` descending (server-side via the
///    single-field index — auto-created per
///    `docs/design/07-technical/firestore-schema.md` line 266).
/// 3. The repository drops malformed items silently via
///    `logActivityParseFailure` (mirrors FriendshipDoc.fromFirestore).
/// 4. The list is unmodifiable — the screen cannot mutate it.
///
/// **Failure handling.**
/// - A snapshot-listener error (e.g. `permission-denied` if the rules
///   block is somehow violated — defence-in-depth) propagates as an
///   `AsyncError` and is consumed by the screen's Error state.
/// - A per-item parse failure (unknown `type`, malformed `payload`) is
///   silently dropped from the projected list and reported via
///   `logActivityParseFailure`. The remaining items render normally.
///
/// **Invariant compliance.**
/// - Invariant 2 (`simplifiedBalances` server-only): this provider
///   reads `activity/{uid}/items`, NOT `simplifiedBalances`. No writes.
/// - Invariant 1 (paise integers): all monetary fields inside the
///   payload remain `int` per the strict-parsing contract enforced by
///   the FR-EX-07 trigger and the boundary-contract grep at
///   `test/features/activity/activity_boundary_contract_test.dart`.
final activityFeedProvider = StreamProvider<List<ActivityFeedItem>>((ref) {
  final currentUserId = ref.watch(currentUserIdProvider);
  final repository = ref.watch(activityFeedRepositoryProvider);
  return repository.watchItems(currentUserId);
});
