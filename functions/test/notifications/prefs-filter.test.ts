/**
 * Unit tests for the notification-preferences short-circuit
 * (FR-AC-03 / FR-AC-04 server-side enforcement).
 *
 * Asserts the per-flag gating defined in
 * `docs/design/07-technical/notifications.md` §2.3, plus the
 * forward-compatibility carve-out for `group_invite` (FR-AC-03 AC-19 —
 * group invites are not user-suppressible because they grant access).
 *
 * @module test/notifications/prefs-filter.test.ts
 */

import {isNotificationAllowed} from "../../src/notifications/prefs-filter";

describe("isNotificationAllowed — FR-AC-03 / notifications.md §2.3", () => {
  // -------------------------------------------------------------------------
  // newExpense flag gates the three expense types
  // -------------------------------------------------------------------------
  describe("newExpense flag (gates expense_added / expense_edited / expense_deleted)", () => {
    it("allows expense_added when newExpense=true", () => {
      expect(
        isNotificationAllowed("expense_added", {
          newExpense: true,
          settlement: true,
          reminder: true,
        }),
      ).toBe(true);
    });

    it("blocks expense_added when newExpense=false", () => {
      expect(
        isNotificationAllowed("expense_added", {
          newExpense: false,
          settlement: true,
          reminder: true,
        }),
      ).toBe(false);
    });

    it("blocks expense_edited when newExpense=false", () => {
      expect(
        isNotificationAllowed("expense_edited", {
          newExpense: false,
          settlement: true,
          reminder: true,
        }),
      ).toBe(false);
    });

    it("blocks expense_deleted when newExpense=false", () => {
      expect(
        isNotificationAllowed("expense_deleted", {
          newExpense: false,
          settlement: true,
          reminder: true,
        }),
      ).toBe(false);
    });
  });

  // -------------------------------------------------------------------------
  // settlement flag gates settlement_received
  // -------------------------------------------------------------------------
  describe("settlement flag (gates settlement_received)", () => {
    it("allows settlement_received when settlement=true", () => {
      expect(
        isNotificationAllowed("settlement_received", {
          newExpense: true,
          settlement: true,
          reminder: true,
        }),
      ).toBe(true);
    });

    it("blocks settlement_received when settlement=false", () => {
      expect(
        isNotificationAllowed("settlement_received", {
          newExpense: true,
          settlement: false,
          reminder: true,
        }),
      ).toBe(false);
    });

    it("ignores newExpense=false when type is settlement_received", () => {
      // Per-category isolation: a user who disabled expense notifications
      // still receives settlement notifications (and vice versa).
      expect(
        isNotificationAllowed("settlement_received", {
          newExpense: false,
          settlement: true,
          reminder: true,
        }),
      ).toBe(true);
    });
  });

  // -------------------------------------------------------------------------
  // reminder flag gates reminder
  // -------------------------------------------------------------------------
  describe("reminder flag (gates reminder)", () => {
    it("allows reminder when reminder=true", () => {
      expect(
        isNotificationAllowed("reminder", {
          newExpense: true,
          settlement: true,
          reminder: true,
        }),
      ).toBe(true);
    });

    it("blocks reminder when reminder=false", () => {
      expect(
        isNotificationAllowed("reminder", {
          newExpense: true,
          settlement: true,
          reminder: false,
        }),
      ).toBe(false);
    });
  });

  // -------------------------------------------------------------------------
  // group_invite bypass (FR-AC-03 AC-19, forward-compat)
  // -------------------------------------------------------------------------
  describe("group_invite bypass (FR-AC-03 AC-19)", () => {
    it("always allows group_invite regardless of preferences", () => {
      expect(
        isNotificationAllowed("group_invite", {
          newExpense: false,
          settlement: false,
          reminder: false,
        }),
      ).toBe(true);
    });

    it("allows group_invite even with prefs undefined", () => {
      expect(isNotificationAllowed("group_invite", undefined)).toBe(true);
    });
  });

  // -------------------------------------------------------------------------
  // Defaults: missing prefs map / partial map defaults to true (matches the
  // FR-AU-06 schema default).
  // -------------------------------------------------------------------------
  describe("defaults (missing prefs map → true for all flags)", () => {
    it("defaults to true when prefs is undefined", () => {
      expect(isNotificationAllowed("expense_added", undefined)).toBe(true);
      expect(isNotificationAllowed("settlement_received", undefined)).toBe(true);
      expect(isNotificationAllowed("reminder", undefined)).toBe(true);
    });

    it("defaults to true when prefs is an empty object (no flags set)", () => {
      expect(isNotificationAllowed("expense_added", {})).toBe(true);
      expect(isNotificationAllowed("settlement_received", {})).toBe(true);
      expect(isNotificationAllowed("reminder", {})).toBe(true);
    });

    it("defaults to true when only some flags are set (partial map)", () => {
      // Only the gated flag is explicit; unrelated flags are absent.
      expect(
        isNotificationAllowed("expense_added", {newExpense: true}),
      ).toBe(true);
      // The gated flag being explicitly false still blocks.
      expect(
        isNotificationAllowed("expense_added", {newExpense: false}),
      ).toBe(false);
    });
  });
});
