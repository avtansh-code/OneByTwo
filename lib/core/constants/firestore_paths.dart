/// Centralized Firestore collection and document path definitions.
///
/// All Firestore path strings used by data sources should be referenced from
/// this class to avoid typos and ensure consistency. This class cannot be
/// instantiated or extended.
///
/// The Firestore hierarchy is:
/// ```text
/// users/{userId}
///   ├── notifications/{notificationId}
///   └── drafts/{draftId}
/// groups/{groupId}
///   ├── members/{userId}
///   ├── expenses/{expenseId}
///   ├── settlements/{settlementId}
///   ├── balances/{balancePairId}
///   └── activity/{activityId}
/// friends/{friendPairId}
///   ├── expenses/{expenseId}
///   ├── settlements/{settlementId}
///   ├── balance (single doc)
///   └── activity/{activityId}
/// invites/{inviteCode}
/// userGroups/{userId}
/// userFriends/{userId}
/// ```
abstract final class FirestorePaths {
  // ── Top-level collections ────────────────────────────────────────────

  /// Collection of user profile documents.
  static const String users = 'users';

  /// Collection of group documents.
  static const String groups = 'groups';

  /// Collection of friend-pair documents.
  static const String friends = 'friends';

  /// Collection of group invite link documents.
  static const String invites = 'invites';

  /// Collection of per-user group membership lookups.
  static const String userGroups = 'userGroups';

  /// Collection of per-user friend list lookups.
  static const String userFriends = 'userFriends';

  // ── Subcollection names ──────────────────────────────────────────────

  /// Subcollection of group members.
  static const String members = 'members';

  /// Subcollection of expenses (under groups or friends).
  static const String expenses = 'expenses';

  /// Subcollection of settlement records (under groups or friends).
  static const String settlements = 'settlements';

  /// Subcollection of pairwise balance documents (under groups or friends).
  static const String balances = 'balances';

  /// Subcollection of activity feed entries (under groups or friends).
  static const String activity = 'activity';

  /// Subcollection of user notifications.
  static const String notifications = 'notifications';

  /// Subcollection of draft expenses saved locally by the user.
  static const String drafts = 'drafts';

  /// Subcollection of expense splits.
  static const String splits = 'splits';

  /// Subcollection of expense payers.
  static const String payers = 'payers';

  /// Subcollection of itemized expense items.
  static const String items = 'items';

  /// Subcollection of expense attachments (receipts, photos).
  static const String attachments = 'attachments';

  // ── User paths ───────────────────────────────────────────────────────

  /// Returns the document path for a user: `users/{userId}`.
  static String userDoc(String userId) => '$users/$userId';

  /// Returns the notifications subcollection path for a user.
  static String userNotifications(String userId) =>
      '$users/$userId/$notifications';

  /// Returns the drafts subcollection path for a user.
  static String userDrafts(String userId) => '$users/$userId/$drafts';

  // ── Group paths ──────────────────────────────────────────────────────

  /// Returns the document path for a group: `groups/{groupId}`.
  static String groupDoc(String groupId) => '$groups/$groupId';

  /// Returns the members subcollection path for a group.
  static String groupMembers(String groupId) => '$groups/$groupId/$members';

  /// Returns the expenses subcollection path for a group.
  static String groupExpenses(String groupId) => '$groups/$groupId/$expenses';

  /// Returns the settlements subcollection path for a group.
  static String groupSettlements(String groupId) =>
      '$groups/$groupId/$settlements';

  /// Returns the balances subcollection path for a group.
  static String groupBalances(String groupId) => '$groups/$groupId/$balances';

  /// Returns the activity subcollection path for a group.
  static String groupActivity(String groupId) => '$groups/$groupId/$activity';

  // ── Friend paths ─────────────────────────────────────────────────────

  /// Returns the document path for a friend pair: `friends/{friendPairId}`.
  static String friendDoc(String friendPairId) => '$friends/$friendPairId';

  /// Returns the expenses subcollection path for a friend pair.
  static String friendExpenses(String friendPairId) =>
      '$friends/$friendPairId/$expenses';

  /// Returns the settlements subcollection path for a friend pair.
  static String friendSettlements(String friendPairId) =>
      '$friends/$friendPairId/$settlements';

  /// Returns the balance subcollection path for a friend pair:
  /// `friends/{friendPairId}/balance`.
  static String friendBalance(String friendPairId) =>
      '$friends/$friendPairId/balance';

  /// Returns the net balance document path for a friend pair:
  /// `friends/{friendPairId}/balance/net`.
  ///
  /// This is the full document path used by Cloud Functions to store
  /// the computed net balance between two friends.
  static String friendBalanceDoc(String friendPairId) =>
      '$friends/$friendPairId/balance/net';

  /// Returns the activity subcollection path for a friend pair.
  static String friendActivity(String friendPairId) =>
      '$friends/$friendPairId/$activity';

  // ── Utilities ────────────────────────────────────────────────────────

  /// Generates a canonical friend pair ID from two user IDs.
  ///
  /// The pair ID is deterministic: `min(userA, userB)_max(userA, userB)`.
  /// This ensures the same pair always maps to the same document regardless
  /// of argument order.
  ///
  /// Example:
  /// ```dart
  /// FirestorePaths.friendPairId('bob', 'alice'); // → 'alice_bob'
  /// FirestorePaths.friendPairId('alice', 'bob'); // → 'alice_bob'
  /// ```
  static String friendPairId(String userA, String userB) {
    final sorted = [userA, userB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}
