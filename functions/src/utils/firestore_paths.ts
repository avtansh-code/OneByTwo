/**
 * Firestore collection and document path helpers.
 *
 * Mirrors the Dart-side path helpers to keep paths consistent
 * between client and server. Always use these helpers instead of
 * inline string concatenation to avoid path typos.
 *
 * Collection hierarchy:
 *
 *   users/{userId}
 *     └─ notifications/{notificationId}
 *     └─ drafts/{draftId}
 *
 *   groups/{groupId}
 *     ├─ members/{userId}
 *     ├─ expenses/{expenseId}
 *     │   ├─ splits/{splitId}
 *     │   ├─ payers/{payerId}
 *     │   ├─ items/{itemId}
 *     │   └─ attachments/{attachmentId}
 *     ├─ settlements/{settlementId}
 *     ├─ balances/{balancePairId}
 *     └─ activity/{activityId}
 *
 *   friends/{friendPairId}
 *     ├─ expenses/{expenseId}
 *     │   ├─ splits/{splitId}
 *     │   ├─ payers/{payerId}
 *     │   └─ items/{itemId}
 *     ├─ settlements/{settlementId}
 *     ├─ balance/{balanceDocId}
 *     └─ activity/{activityId}
 *
 *   invites/{inviteCode}
 *   userGroups/{userId}/groups/{groupId}
 *   userFriends/{userId}/friends/{friendUserId}
 *   rateLimits/{docId}
 */

// ── Users ─────────────────────────────────────────────────────────────────

export const usersCol = () => "users";
export const userDoc = (userId: string) => `users/${userId}`;

export const userNotificationsCol = (userId: string) =>
  `users/${userId}/notifications`;
export const userNotificationDoc = (userId: string, notificationId: string) =>
  `users/${userId}/notifications/${notificationId}`;

export const userDraftsCol = (userId: string) => `users/${userId}/drafts`;
export const userDraftDoc = (userId: string, draftId: string) =>
  `users/${userId}/drafts/${draftId}`;

// ── Groups ────────────────────────────────────────────────────────────────

export const groupsCol = () => "groups";
export const groupDoc = (groupId: string) => `groups/${groupId}`;

// Members
export const groupMembersCol = (groupId: string) =>
  `groups/${groupId}/members`;
export const groupMemberDoc = (groupId: string, userId: string) =>
  `groups/${groupId}/members/${userId}`;

// Expenses
export const groupExpensesCol = (groupId: string) =>
  `groups/${groupId}/expenses`;
export const groupExpenseDoc = (groupId: string, expenseId: string) =>
  `groups/${groupId}/expenses/${expenseId}`;

// Expense subcollections
export const expenseSplitsCol = (groupId: string, expenseId: string) =>
  `groups/${groupId}/expenses/${expenseId}/splits`;
export const expenseSplitDoc = (
  groupId: string,
  expenseId: string,
  splitId: string
) => `groups/${groupId}/expenses/${expenseId}/splits/${splitId}`;

export const expensePayersCol = (groupId: string, expenseId: string) =>
  `groups/${groupId}/expenses/${expenseId}/payers`;
export const expensePayerDoc = (
  groupId: string,
  expenseId: string,
  payerId: string
) => `groups/${groupId}/expenses/${expenseId}/payers/${payerId}`;

export const expenseItemsCol = (groupId: string, expenseId: string) =>
  `groups/${groupId}/expenses/${expenseId}/items`;
export const expenseItemDoc = (
  groupId: string,
  expenseId: string,
  itemId: string
) => `groups/${groupId}/expenses/${expenseId}/items/${itemId}`;

export const expenseAttachmentsCol = (groupId: string, expenseId: string) =>
  `groups/${groupId}/expenses/${expenseId}/attachments`;
export const expenseAttachmentDoc = (
  groupId: string,
  expenseId: string,
  attachmentId: string
) => `groups/${groupId}/expenses/${expenseId}/attachments/${attachmentId}`;

// Settlements
export const groupSettlementsCol = (groupId: string) =>
  `groups/${groupId}/settlements`;
export const groupSettlementDoc = (
  groupId: string,
  settlementId: string
) => `groups/${groupId}/settlements/${settlementId}`;

// Balances (Cloud Functions only — clients read-only)
export const groupBalancesCol = (groupId: string) =>
  `groups/${groupId}/balances`;
export const groupBalanceDoc = (groupId: string, balancePairId: string) =>
  `groups/${groupId}/balances/${balancePairId}`;

// Activity (Cloud Functions only — clients read-only)
export const groupActivityCol = (groupId: string) =>
  `groups/${groupId}/activity`;
export const groupActivityDoc = (groupId: string, activityId: string) =>
  `groups/${groupId}/activity/${activityId}`;

// ── Friends ───────────────────────────────────────────────────────────────

export const friendsCol = () => "friends";
export const friendDoc = (friendPairId: string) =>
  `friends/${friendPairId}`;

// Friend expenses
export const friendExpensesCol = (friendPairId: string) =>
  `friends/${friendPairId}/expenses`;
export const friendExpenseDoc = (friendPairId: string, expenseId: string) =>
  `friends/${friendPairId}/expenses/${expenseId}`;

// Friend expense subcollections
export const friendExpenseSplitsCol = (
  friendPairId: string,
  expenseId: string
) => `friends/${friendPairId}/expenses/${expenseId}/splits`;
export const friendExpenseSplitDoc = (
  friendPairId: string,
  expenseId: string,
  splitId: string
) => `friends/${friendPairId}/expenses/${expenseId}/splits/${splitId}`;

export const friendExpensePayersCol = (
  friendPairId: string,
  expenseId: string
) => `friends/${friendPairId}/expenses/${expenseId}/payers`;
export const friendExpensePayerDoc = (
  friendPairId: string,
  expenseId: string,
  payerId: string
) => `friends/${friendPairId}/expenses/${expenseId}/payers/${payerId}`;

export const friendExpenseItemsCol = (
  friendPairId: string,
  expenseId: string
) => `friends/${friendPairId}/expenses/${expenseId}/items`;
export const friendExpenseItemDoc = (
  friendPairId: string,
  expenseId: string,
  itemId: string
) => `friends/${friendPairId}/expenses/${expenseId}/items/${itemId}`;

// Friend settlements
export const friendSettlementsCol = (friendPairId: string) =>
  `friends/${friendPairId}/settlements`;
export const friendSettlementDoc = (
  friendPairId: string,
  settlementId: string
) => `friends/${friendPairId}/settlements/${settlementId}`;

// Friend balance (single doc — Cloud Functions only)
export const friendBalanceCol = (friendPairId: string) =>
  `friends/${friendPairId}/balance`;
export const friendBalanceDoc = (
  friendPairId: string,
  balanceDocId: string
) => `friends/${friendPairId}/balance/${balanceDocId}`;

/** Convenience: the single net balance doc for a friend pair. */
export const friendNetBalanceDoc = (friendPairId: string) =>
  `friends/${friendPairId}/balance/net`;

// Friend activity (Cloud Functions only)
export const friendActivityCol = (friendPairId: string) =>
  `friends/${friendPairId}/activity`;
export const friendActivityDoc = (
  friendPairId: string,
  activityId: string
) => `friends/${friendPairId}/activity/${activityId}`;

// ── Invites ───────────────────────────────────────────────────────────────

export const invitesCol = () => "invites";
export const inviteDoc = (inviteCode: string) => `invites/${inviteCode}`;

// ── User Groups (denormalized) ──────────────────────────────────────────

export const userGroupsCol = (userId: string) =>
  `userGroups/${userId}/groups`;
export const userGroupDoc = (userId: string, groupId: string) =>
  `userGroups/${userId}/groups/${groupId}`;

// ── User Friends (denormalized) ─────────────────────────────────────────

export const userFriendsCol = (userId: string) =>
  `userFriends/${userId}/friends`;
export const userFriendDoc = (userId: string, friendUserId: string) =>
  `userFriends/${userId}/friends/${friendUserId}`;

// ── Rate Limits (Cloud Functions only) ──────────────────────────────────

export const rateLimitsCol = () => "rateLimits";
export const rateLimitDoc = (docId: string) => `rateLimits/${docId}`;
