import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Returns a stable, opaque correlation ID for telemetry events that
/// would otherwise carry a raw `friendshipId`.
///
/// A `friendshipId` is the deterministic concatenation of two sorted
/// user UIDs (`uid-a_uid-b`). Emitting the raw value to analytics or
/// crash reports would leak a PII-adjacent identifier that links two
/// real users. This helper applies SHA-256 to the raw ID and truncates
/// the hex digest to the first 16 characters — long enough to be
/// collision-resistant for correlation purposes, short enough that the
/// value is obviously not a reversible UID concatenation.
///
/// The function is referenced from the architect notes on
/// `docs/sprint-zero/stories/FR-FR-03-friends-list.md` and from
/// `docs/design/07-technical/telemetry-plan.md` (`friend_row_tapped`
/// parameter contract). For any other PII-adjacent identifier (e.g.
/// `expenseId`), use [hashId] which applies the same algorithm.
String hashFriendshipId(String friendshipId) => hashId(friendshipId);

/// Returns a stable, opaque correlation hash for any PII-adjacent
/// identifier (e.g. `expenseId`, `groupId`, `settlementId`). Applies
/// the same SHA-256-truncated-to-16-hex contract as [hashFriendshipId]
/// so the two functions are interchangeable on identical input
/// (verified by the PII-leak tests).
///
/// Use this helper whenever you need to emit a telemetry event with
/// an identifier parameter. The parameter name convention (per
/// ADR-0013) is to append `_hash` to indicate that the value is
/// hashed rather than the raw identifier — e.g. `expense_id_hash`,
/// `friendship_id_hash`.
String hashId(String id) {
  final bytes = utf8.encode(id);
  final digest = sha256.convert(bytes);
  return digest.toString().substring(0, 16);
}
