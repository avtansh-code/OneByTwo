import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onebytwo/core/balances/net_balance.dart';
import 'package:onebytwo/features/auth/domain/user_model.dart';
import 'package:onebytwo/features/friends/application/user_profile_provider.dart';
import 'package:onebytwo/features/friends/data/friendship_repository.dart';
import 'package:onebytwo/features/friends/domain/friend_list_item.dart';
import 'package:onebytwo/features/friends/domain/friendship_doc.dart';

/// Provides the current authenticated user's UID for the friends-list
/// pipeline. **Override in the widget tree** at the same point the
/// authenticated session is established (typically the authenticated
/// shell that hosts `FriendsListScreen`). Tests override it directly.
final currentUserIdProvider = Provider<String>((ref) {
  throw UnimplementedError(
    'currentUserIdProvider must be overridden with the signed-in '
    "user's UID before the friends list is rendered.",
  );
});

/// Real-time projection of the current user's friendships into a
/// `List<FriendListItem>` for the friends-list screen (FR-FR-03).
///
/// Pipeline:
/// 1. Subscribe to `friendshipRepositoryProvider.watchFriendships(uid)`
///    — a Firestore snapshot stream filtered and ordered by the
///    composite index `memberIds (array-contains) + lastActivityAt (desc)`.
/// 2. For each `FriendshipDoc`, resolve the OTHER user's display name
///    and photo URL via `userProfileProvider.family(otherUid)`. Each
///    family lookup is cached for the container lifetime.
/// 3. Compute the signed integer paise via `netBalancePaise()`.
/// 4. Yield a list of `FriendListItem` whose ordering matches the
///    Firestore snapshot (no client-side sort).
///
/// **Failure handling.**
/// - A per-profile failure (deleted user doc, permission glitch) does
///   **not** fail the whole list — the row falls back to
///   `displayName: "Unknown"` with a `null` photo.
/// - A friendship doc whose `memberIds` does not contain a distinct
///   other user (defensive: corrupt or self-only doc that the security
///   rules normally forbid) is **dropped** from the projected list and
///   surfaced via `developer.log` under the
///   `friendship_parse_failure` event name. No "self row" is ever
///   rendered.
/// - A failure in the underlying Firestore snapshot stream propagates
///   as an `AsyncError` (consumed by the screen's error state).
final friendsListProvider = StreamProvider<List<FriendListItem>>((ref) {
  final currentUserId = ref.watch(currentUserIdProvider);
  final repository = ref.watch(friendshipRepositoryProvider);

  return repository.watchFriendships(currentUserId).asyncMap((docs) async {
    final maybeItems = await Future.wait(
      docs.map((doc) => _projectItem(ref, doc, currentUserId)),
    );
    final items = maybeItems.whereType<FriendListItem>().toList(
      growable: false,
    );
    return List<FriendListItem>.unmodifiable(items);
  });
});

Future<FriendListItem?> _projectItem(
  Ref ref,
  FriendshipDoc doc,
  String currentUserId,
) async {
  String? otherUserId;
  for (final uid in doc.memberIds) {
    if (uid != currentUserId) {
      otherUserId = uid;
      break;
    }
  }
  if (otherUserId == null) {
    // Defensive: a well-formed friendship has exactly two members and
    // includes the current user as one of them (verified by Firestore
    // Security Rules per `firestore.rules` and
    // `functions/test/firestore-rules/friendships.test.ts`). A doc
    // that fails this contract — empty memberIds, a single-member
    // doc, or a doc whose only member is the current user — is
    // dropped from the projected list rather than rendered as a
    // misleading "self row" with the current user's own profile.
    developer.log(
      'friendship ${doc.friendshipId}: no distinct other user in '
      'memberIds (got ${doc.memberIds}); dropped from friends list',
      name: 'friendship_parse_failure',
      level: 900,
    );
    return null;
  }

  UserModel? profile;
  try {
    profile = await ref.read(userProfileProvider(otherUserId).future);
  } on Object {
    profile = null;
  }

  final netPaise = netBalancePaise(
    simplifiedBalances: doc.simplifiedBalances,
    currentUserId: currentUserId,
    otherUserId: otherUserId,
  );

  return FriendListItem(
    friendshipId: doc.friendshipId,
    otherUserId: otherUserId,
    displayName: profile?.displayName ?? 'Unknown',
    photoUrl: profile?.photoUrl,
    netBalancePaise: netPaise,
  );
}
