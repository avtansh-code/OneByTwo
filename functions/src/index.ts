/**
 * OneByTwo Cloud Functions
 *
 * All functions deployed to asia-south1 (Mumbai).
 *
 * Trigger functions:
 *   - onExpenseCreated/Updated/Deleted       (group expenses)
 *   - onSettlementCreated                    (group settlements)
 *   - onMemberJoined/Left                    (group membership changes)
 *   - onUserCreated                          (new user setup)
 *   - onFriendExpenseCreated/Updated/Deleted (1:1 friend expenses)
 *   - onFriendSettlementCreated              (1:1 friend settlements)
 *
 * Callable functions:
 *   - simplifyDebts          — minimize transactions in a group
 *   - generateInviteLink     — create group invite code with expiry
 *   - joinGroupViaInvite     — join group via invite code
 *   - addFriend              — create 1:1 friend relationship
 *   - nudgeFriend            — send payment reminder to a friend
 *   - settleFriend           — record settlement between friends
 *   - settleAll              — record settlements for all group balances
 *   - nudgeUser              — send payment reminder in a group
 *   - deleteAccount          — GDPR-compliant full account deletion
 *   - exportData             — export all user data as JSON
 *
 * Scheduled functions:
 *   - cleanupExpiredInvites  — daily: expire old invite codes
 *   - cleanupSoftDeletes     — daily: hard-delete old soft-deleted docs
 *   - sendSettlementReminders — weekly: nudge users with outstanding balances
 */

import { initializeApp } from "firebase-admin/app";

// Initialize Firebase Admin SDK (must be called before any other admin calls)
initializeApp();

// ── Triggers ────────────────────────────────────────────────────────────────
// Uncomment as each trigger is implemented:
// export { onExpenseCreated, onExpenseUpdated, onExpenseDeleted } from "./triggers/onExpenseWrite";
// export { onSettlementCreated } from "./triggers/onSettlementWrite";
// export { onMemberJoined, onMemberLeft } from "./triggers/onMemberChange";
export { onUserCreated } from "./triggers/onUserCreated";
// export { onFriendExpenseCreated, onFriendExpenseUpdated, onFriendExpenseDeleted } from "./triggers/onFriendExpenseWrite";
// export { onFriendSettlementCreated } from "./triggers/onFriendSettlementWrite";

// ── Callable Functions ──────────────────────────────────────────────────────
// Uncomment as each callable is implemented:
// export { simplifyDebts } from "./callable/simplifyDebts";
// export { generateInviteLink } from "./callable/generateInviteLink";
// export { joinGroupViaInvite } from "./callable/joinGroupViaInvite";
// export { addFriend } from "./callable/addFriend";
// export { nudgeFriend } from "./callable/nudgeFriend";
// export { settleFriend } from "./callable/settleFriend";
// export { settleAll } from "./callable/settleAll";
// export { nudgeUser } from "./callable/nudgeUser";
// export { deleteAccount } from "./callable/deleteAccount";
// export { exportData } from "./callable/exportData";

// ── Scheduled Functions ─────────────────────────────────────────────────────
// Uncomment as each scheduled function is implemented:
// export { cleanupExpiredInvites } from "./scheduled/cleanupInvites";
// export { cleanupSoftDeletes } from "./scheduled/cleanupSoftDeletes";
// export { sendSettlementReminders } from "./scheduled/weeklyDigest";
