/**
 * Tests for Firestore path helpers.
 */

import {
  userDoc,
  userNotificationsCol,
  userNotificationDoc,
  groupDoc,
  groupMembersCol,
  groupMemberDoc,
  groupExpensesCol,
  groupExpenseDoc,
  expenseSplitsCol,
  groupSettlementsCol,
  groupBalancesCol,
  groupBalanceDoc,
  groupActivityCol,
  friendDoc,
  friendExpensesCol,
  friendExpenseDoc,
  friendSettlementsCol,
  friendNetBalanceDoc,
  friendActivityCol,
  inviteDoc,
  userGroupDoc,
  userFriendDoc,
  rateLimitDoc,
} from "../src/utils/firestore_paths";

describe("Firestore path helpers", () => {
  // ── Users ────────────────────────────────────────
  it("userDoc", () => {
    expect(userDoc("uid1")).toBe("users/uid1");
  });

  it("userNotificationsCol", () => {
    expect(userNotificationsCol("uid1")).toBe("users/uid1/notifications");
  });

  it("userNotificationDoc", () => {
    expect(userNotificationDoc("uid1", "n1")).toBe("users/uid1/notifications/n1");
  });

  // ── Groups ───────────────────────────────────────
  it("groupDoc", () => {
    expect(groupDoc("g1")).toBe("groups/g1");
  });

  it("groupMembersCol", () => {
    expect(groupMembersCol("g1")).toBe("groups/g1/members");
  });

  it("groupMemberDoc", () => {
    expect(groupMemberDoc("g1", "uid1")).toBe("groups/g1/members/uid1");
  });

  it("groupExpensesCol", () => {
    expect(groupExpensesCol("g1")).toBe("groups/g1/expenses");
  });

  it("groupExpenseDoc", () => {
    expect(groupExpenseDoc("g1", "e1")).toBe("groups/g1/expenses/e1");
  });

  it("expenseSplitsCol", () => {
    expect(expenseSplitsCol("g1", "e1")).toBe("groups/g1/expenses/e1/splits");
  });

  it("groupSettlementsCol", () => {
    expect(groupSettlementsCol("g1")).toBe("groups/g1/settlements");
  });

  it("groupBalancesCol", () => {
    expect(groupBalancesCol("g1")).toBe("groups/g1/balances");
  });

  it("groupBalanceDoc", () => {
    expect(groupBalanceDoc("g1", "a_b")).toBe("groups/g1/balances/a_b");
  });

  it("groupActivityCol", () => {
    expect(groupActivityCol("g1")).toBe("groups/g1/activity");
  });

  // ── Friends ──────────────────────────────────────
  it("friendDoc", () => {
    expect(friendDoc("alice_bob")).toBe("friends/alice_bob");
  });

  it("friendExpensesCol", () => {
    expect(friendExpensesCol("alice_bob")).toBe("friends/alice_bob/expenses");
  });

  it("friendExpenseDoc", () => {
    expect(friendExpenseDoc("alice_bob", "e1")).toBe("friends/alice_bob/expenses/e1");
  });

  it("friendSettlementsCol", () => {
    expect(friendSettlementsCol("alice_bob")).toBe("friends/alice_bob/settlements");
  });

  it("friendNetBalanceDoc", () => {
    expect(friendNetBalanceDoc("alice_bob")).toBe("friends/alice_bob/balance/net");
  });

  it("friendActivityCol", () => {
    expect(friendActivityCol("alice_bob")).toBe("friends/alice_bob/activity");
  });

  // ── Invites ──────────────────────────────────────
  it("inviteDoc", () => {
    expect(inviteDoc("ABCD1234")).toBe("invites/ABCD1234");
  });

  // ── User Groups / Friends (denormalized) ─────────
  it("userGroupDoc", () => {
    expect(userGroupDoc("uid1", "g1")).toBe("userGroups/uid1/groups/g1");
  });

  it("userFriendDoc", () => {
    expect(userFriendDoc("uid1", "uid2")).toBe("userFriends/uid1/friends/uid2");
  });

  // ── Rate Limits ──────────────────────────────────
  it("rateLimitDoc", () => {
    expect(rateLimitDoc("uid1_simplifyDebts")).toBe("rateLimits/uid1_simplifyDebts");
  });
});
