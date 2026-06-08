/**
 * Unit tests for the per-type FCM payload renderer (FR-AC-03).
 *
 * Asserts the rendered title + body strings for each of the six
 * notification types listed in `docs/design/07-technical/notifications.md`
 * §2.2, and verifies the full FCM data envelope shape per §2.1
 * (all values stringified; ISO 8601 `createdAt`).
 *
 * All amounts are formatted through `formatInrFromPaise()` — the test
 * file itself contains ZERO inline `/100` arithmetic.
 *
 * @module test/notifications/payload-renderer.test.ts
 */

import {renderPayload} from "../../src/notifications/payload-renderer";

const ISO_8601_PATTERN =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/;

describe("renderPayload — FR-AC-03 / notifications.md §2.2", () => {
  describe("expense_added", () => {
    it("renders title and body for the canonical (Rahul, Dinner, ₹1,200) input", () => {
      const payload = renderPayload("expense_added", {
        senderName: "Rahul",
        description: "Dinner",
        amountPaise: 120000,
        contextType: "friendship",
        contextId: "uid-rahul_uid-priya",
        itemId: "expense-123",
        createdAt: new Date("2026-06-08T10:00:00Z"),
      });

      expect(payload.title).toBe("Rahul added an expense");
      expect(payload.body).toBe("Dinner -- ₹1,200.");
    });

    it("envelope includes type/contextType/contextId/itemId/senderName/amountPaise/createdAt", () => {
      const payload = renderPayload("expense_added", {
        senderName: "Rahul",
        description: "Dinner",
        amountPaise: 120000,
        contextType: "friendship",
        contextId: "uid-rahul_uid-priya",
        itemId: "expense-123",
        createdAt: new Date("2026-06-08T10:00:00Z"),
      });

      expect(payload.type).toBe("expense_added");
      expect(payload.contextType).toBe("friendship");
      expect(payload.contextId).toBe("uid-rahul_uid-priya");
      expect(payload.itemId).toBe("expense-123");
      expect(payload.senderName).toBe("Rahul");
      // amountPaise is STRINGIFIED per §2.1 (FCM data payload constraint).
      expect(payload.amountPaise).toBe("120000");
      // createdAt is ISO 8601.
      expect(payload.createdAt).toMatch(ISO_8601_PATTERN);
    });
  });

  describe("expense_edited", () => {
    it("renders the edit-flavour title and body", () => {
      const payload = renderPayload("expense_edited", {
        senderName: "Rahul",
        description: "Dinner",
        amountPaise: 150000,
        contextType: "friendship",
        contextId: "uid-rahul_uid-priya",
        itemId: "expense-123",
        createdAt: new Date("2026-06-08T10:00:00Z"),
      });

      expect(payload.title).toBe("Rahul edited an expense");
      expect(payload.body).toBe("Dinner was updated to ₹1,500.");
      expect(payload.type).toBe("expense_edited");
    });
  });

  describe("expense_deleted", () => {
    it("renders the delete-flavour title and body (no itemId required)", () => {
      const payload = renderPayload("expense_deleted", {
        senderName: "Rahul",
        description: "Dinner",
        amountPaise: 120000,
        contextType: "friendship",
        contextId: "uid-rahul_uid-priya",
        createdAt: new Date("2026-06-08T10:00:00Z"),
      });

      expect(payload.title).toBe("Rahul deleted an expense");
      expect(payload.body).toBe("Dinner (₹1,200) was removed.");
      expect(payload.type).toBe("expense_deleted");
      // itemId is OPTIONAL per §2.2 — the expense has been soft-deleted.
      expect(payload.itemId).toBeUndefined();
    });
  });

  describe("settlement_received", () => {
    it("renders the (Priya, ₹350) canonical input", () => {
      const payload = renderPayload("settlement_received", {
        senderName: "Priya",
        amountPaise: 35000,
        contextType: "friendship",
        contextId: "uid-rahul_uid-priya",
        itemId: "settlement-456",
        createdAt: new Date("2026-06-08T10:00:00Z"),
      });

      expect(payload.title).toBe("Priya settled up");
      expect(payload.body).toBe("You received ₹350.");
      expect(payload.type).toBe("settlement_received");
      expect(payload.amountPaise).toBe("35000");
      expect(payload.itemId).toBe("settlement-456");
    });
  });

  describe("reminder", () => {
    it("renders the reminder title and body for a friendship reminder", () => {
      const payload = renderPayload("reminder", {
        senderName: "Priya",
        amountPaise: 50000,
        contextType: "friendship",
        contextId: "uid-rahul_uid-priya",
        createdAt: new Date("2026-06-08T10:00:00Z"),
      });

      expect(payload.title).toBe("Reminder from Priya");
      expect(payload.body).toBe("Priya is nudging you about ₹500.");
      expect(payload.type).toBe("reminder");
    });
  });

  describe("group_invite", () => {
    it("renders the group invite title and body (forward-compat — no producer in FR-AC-03)", () => {
      const payload = renderPayload("group_invite", {
        senderName: "Priya",
        contextType: "group",
        contextId: "group-789",
        groupName: "Goa Trip",
        inviteToken: "invite-token-abc",
        createdAt: new Date("2026-06-08T10:00:00Z"),
      });

      expect(payload.title).toBe("Priya invited you to a group");
      expect(payload.body).toBe('Join "Goa Trip" to start splitting.');
      expect(payload.type).toBe("group_invite");
      expect(payload.inviteToken).toBe("invite-token-abc");
      // amountPaise is undefined for group_invite (no monetary value).
      expect(payload.amountPaise).toBeUndefined();
    });
  });

  describe("envelope invariants", () => {
    it("renders amountPaise as a string, not a number", () => {
      const payload = renderPayload("expense_added", {
        senderName: "Rahul",
        description: "Dinner",
        amountPaise: 120000,
        contextType: "friendship",
        contextId: "uid-rahul_uid-priya",
        itemId: "expense-123",
        createdAt: new Date("2026-06-08T10:00:00Z"),
      });

      // FCM data payload constraint: all values must be strings.
      expect(typeof payload.amountPaise).toBe("string");
    });

    it("renders createdAt as an ISO 8601 string regardless of source Date", () => {
      const payload = renderPayload("expense_added", {
        senderName: "Rahul",
        description: "Dinner",
        amountPaise: 120000,
        contextType: "friendship",
        contextId: "uid-rahul_uid-priya",
        itemId: "expense-123",
        createdAt: new Date("2026-01-01T00:00:00Z"),
      });

      expect(payload.createdAt).toBe("2026-01-01T00:00:00.000Z");
    });

    it("uses the Indian-numbering formatter (₹1,00,000 for 1 crore paise)", () => {
      const payload = renderPayload("expense_added", {
        senderName: "Anil",
        description: "Hotel",
        amountPaise: 10000000,
        contextType: "friendship",
        contextId: "uid-anil_uid-meena",
        itemId: "expense-456",
        createdAt: new Date("2026-06-08T10:00:00Z"),
      });

      expect(payload.body).toContain("₹1,00,000");
    });
  });
});
