import 'package:flutter/foundation.dart';

/// UI-facing projection of a friendship row in the friends list
/// (`FR-FR-03`). Combines the friendship doc with the resolved other
/// user's display profile and the signed integer net balance.
///
/// Per **invariant 1**, [netBalancePaise] is `int`; the widget layer
/// passes it to `formatInrFromPaise()` for display. No widget may
/// perform inline rupee arithmetic.
@immutable
class FriendListItem {
  /// Creates a [FriendListItem].
  const FriendListItem({
    required this.friendshipId,
    required this.otherUserId,
    required this.displayName,
    required this.photoUrl,
    required this.netBalancePaise,
  });

  /// Deterministic friendship document ID (sorted UIDs joined with
  /// `_`). Used for navigation targeting and (after hashing) for the
  /// `friend_row_tapped` telemetry parameter.
  final String friendshipId;

  /// The OTHER user's UID (i.e. not the current user's). Used for
  /// avatar resolution and downstream navigation.
  final String otherUserId;

  /// The other user's display name, or `"Unknown"` when the user-doc
  /// lookup fails (per architect note §4 fallback).
  final String displayName;

  /// The other user's avatar URL, or `null` when unset or the lookup
  /// failed.
  final String? photoUrl;

  /// Signed net balance in **paise** (invariant 1). Positive ⇒ the
  /// other user owes the current user; negative ⇒ the current user
  /// owes the other user; zero ⇒ settled up.
  final int netBalancePaise;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FriendListItem &&
        other.friendshipId == friendshipId &&
        other.otherUserId == otherUserId &&
        other.displayName == displayName &&
        other.photoUrl == photoUrl &&
        other.netBalancePaise == netBalancePaise;
  }

  @override
  int get hashCode => Object.hash(
    friendshipId,
    otherUserId,
    displayName,
    photoUrl,
    netBalancePaise,
  );
}
