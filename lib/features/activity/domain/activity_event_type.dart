/// Discriminator enum for an activity-feed item type, in camelCase
/// per the SCR-25 contract.
///
/// The Firestore schema stores the discriminator in snake_case
/// (`'expense_added'`, `'expense_edited'`, `'expense_deleted'`,
/// `'settlement'`, `'group_change'`) per
/// `docs/design/07-technical/firestore-schema.md` line 202. The
/// client converts on read via [ActivityEventTypeX.parseSnakeCase].
///
/// PR #52 only renders the four expense + settlement variants —
/// `groupCreated`, `groupMemberAdded`, `groupMemberRemoved`, and
/// `friendAdded` are declared in the SCR-25 Event Type Mapping
/// (lines 305-312) but have no producer in v1.0. They are NOT in
/// this enum until Sprint 3 ships the group-trigger activity
/// emission.
enum ActivityEventType {
  /// An expense was created (Firestore: `'expense_added'`).
  expenseAdded,

  /// An expense was edited (Firestore: `'expense_edited'`).
  expenseEdited,

  /// An expense was soft-deleted (Firestore: `'expense_deleted'`).
  expenseDeleted,

  /// A settlement was recorded (Firestore: `'settlement'`).
  settlementRecorded,
}

/// Extension methods on [ActivityEventType] for snake_case parsing.
///
/// Use [parseSnakeCase] when reading the Firestore document's `type`
/// field; the SCR-25 spec uses camelCase, the schema doc uses
/// snake_case. This is the single point of conversion.
extension ActivityEventTypeX on ActivityEventType {
  /// Parses the Firestore snake_case `type` value into an
  /// [ActivityEventType], or returns `null` for unknown discriminators.
  ///
  /// Unknown values (e.g. `'group_change'` from a future Sprint 3
  /// group-trigger emission) return `null` so the calling
  /// `fromFirestore` factory can drop the document silently. Forward-
  /// compatible by design.
  static ActivityEventType? parseSnakeCase(String snakeCase) {
    switch (snakeCase) {
      case 'expense_added':
        return ActivityEventType.expenseAdded;
      case 'expense_edited':
        return ActivityEventType.expenseEdited;
      case 'expense_deleted':
        return ActivityEventType.expenseDeleted;
      case 'settlement':
        return ActivityEventType.settlementRecorded;
      default:
        return null;
    }
  }

  /// Returns the canonical camelCase wire-name used by telemetry events
  /// (per SCR-25 lines 350-354). Matches the enum value's literal name.
  String get wireName {
    switch (this) {
      case ActivityEventType.expenseAdded:
        return 'expenseAdded';
      case ActivityEventType.expenseEdited:
        return 'expenseEdited';
      case ActivityEventType.expenseDeleted:
        return 'expenseDeleted';
      case ActivityEventType.settlementRecorded:
        return 'settlementRecorded';
    }
  }
}
