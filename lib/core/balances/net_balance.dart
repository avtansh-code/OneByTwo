/// Pure function that computes the signed net balance in paise between
/// the current user and another user, given the server-maintained
/// `simplifiedBalances` nested map from a `friendships/{friendshipId}`
/// document.
///
/// The map shape is
/// `{ [debtorUserId]: { [creditorUserId]: amountPaise } }`. From the
/// current user's perspective the net is
///
///   (amount the other user owes me) − (amount I owe the other user)
///
/// Positive ⇒ the other user owes me (display: "owes you").
/// Negative ⇒ I owe the other user (display: "you owe").
/// Zero    ⇒ no debts either way (display: "settled up").
///
/// **Invariant 1 (integer paise).** The function reads `int` values from
/// the nested map and performs integer subtraction. It never produces a
/// `double`. Callers must keep the value as `int` end-to-end and pass it
/// to `formatInrFromPaise()` for display.
///
/// **Invariant 2 (`simplifiedBalances` is server-maintained).** This
/// function is READ-ONLY. It does not mutate the input map and it is
/// never called by code that writes the field.
///
/// **Defensive defaults.**
/// - `null` or missing map  ⇒ `0`.
/// - The (current, other) pair is absent ⇒ `0` for that direction.
/// - A malformed nested value (string where an `int` is expected, or a
///   non-`Map` outer value) silently contributes `0` for that pair. The
///   `FriendshipDoc.fromFirestore` parsing layer is responsible for
///   logging the parse failure when malformed data is observed; this
///   function never throws, so the rest of the list keeps rendering.
int netBalancePaise({
  required Map<String, dynamic>? simplifiedBalances,
  required String currentUserId,
  required String otherUserId,
}) {
  if (simplifiedBalances == null) return 0;

  final theyOweMe = _readPaise(
    simplifiedBalances,
    debtor: otherUserId,
    creditor: currentUserId,
  );
  final iOweThem = _readPaise(
    simplifiedBalances,
    debtor: currentUserId,
    creditor: otherUserId,
  );

  return theyOweMe - iOweThem;
}

int _readPaise(
  Map<String, dynamic> simplifiedBalances, {
  required String debtor,
  required String creditor,
}) {
  final outer = simplifiedBalances[debtor];
  if (outer is! Map) return 0;
  final value = outer[creditor];
  if (value is int) return value;
  return 0;
}
