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
/// parameter contract). Reuse it for any future telemetry event that
/// needs to carry an opaque identifier.
String hashFriendshipId(String friendshipId) {
  final bytes = utf8.encode(friendshipId);
  final digest = sha256.convert(bytes);
  return digest.toString().substring(0, 16);
}
