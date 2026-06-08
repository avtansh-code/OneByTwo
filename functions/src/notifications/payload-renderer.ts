/**
 * Per-type FCM payload renderer (FR-AC-03 / notifications.md §2.2).
 *
 * Maps each `NotificationType` to its corresponding title + body
 * template using a single dispatching function. All money values are
 * formatted through `formatInrFromPaise()` (FR-AC-03 / Invariant 1 —
 * no inline `/100` arithmetic).
 *
 * The renderer is a PURE function — no I/O, no globals, no clocks
 * other than the explicit `createdAt` input. This makes it trivially
 * unit-testable and side-effect-free for trigger-side composition.
 *
 * @module notifications/payload-renderer
 */

import {formatInrFromPaise} from "../utils/format-inr";
import type {NotificationPayload, NotificationType} from "./types";

/**
 * Input shape for the expense-flavour templates (`expense_added`,
 * `expense_edited`, `expense_deleted`).
 */
export interface ExpensePayloadInput {
  senderName: string;
  description: string;
  amountPaise: number;
  contextType: "friendship" | "group";
  contextId: string;
  itemId?: string;
  createdAt: Date;
}

/**
 * Input shape for the `settlement_received` template.
 */
export interface SettlementPayloadInput {
  senderName: string;
  amountPaise: number;
  contextType: "friendship" | "group";
  contextId: string;
  itemId?: string;
  createdAt: Date;
}

/**
 * Input shape for the `reminder` template (FR-AC-04 — producer ships
 * later; the renderer is forward-compat per AC-19).
 */
export interface ReminderPayloadInput {
  senderName: string;
  amountPaise: number;
  contextType: "friendship" | "group";
  contextId: string;
  itemId?: string;
  createdAt: Date;
}

/**
 * Input shape for the `group_invite` template (FR-GR-* — producer
 * ships when group invites land; renderer is forward-compat).
 */
export interface GroupInvitePayloadInput {
  senderName: string;
  contextType: "friendship" | "group";
  contextId: string;
  itemId?: string;
  groupName: string;
  inviteToken: string;
  createdAt: Date;
}

/**
 * Discriminated union of all renderer inputs. The `type` parameter on
 * `renderPayload` selects which branch is active.
 */
export type RenderInput =
  | ExpensePayloadInput
  | SettlementPayloadInput
  | ReminderPayloadInput
  | GroupInvitePayloadInput;

/**
 * Renders a `NotificationPayload` for the given notification type and
 * input. Each template is a faithful implementation of the strings
 * specified in `docs/design/07-technical/notifications.md` §2.2.
 *
 * @param type - The notification type discriminator. Selects the
 *   template and validates that the input has the right shape.
 * @param input - The template inputs. The discriminated union is
 *   loosely typed at the public surface (TypeScript can't fully
 *   statically validate the cross-product of type × input), but the
 *   per-branch reads are type-narrowed inside.
 */
export function renderPayload(
  type: "expense_added" | "expense_edited" | "expense_deleted",
  input: ExpensePayloadInput,
): NotificationPayload;
export function renderPayload(
  type: "settlement_received",
  input: SettlementPayloadInput,
): NotificationPayload;
export function renderPayload(
  type: "reminder",
  input: ReminderPayloadInput,
): NotificationPayload;
export function renderPayload(
  type: "group_invite",
  input: GroupInvitePayloadInput,
): NotificationPayload;
export function renderPayload(
  type: NotificationType,
  input: RenderInput,
): NotificationPayload {
  const createdAtIso = input.createdAt.toISOString();

  switch (type) {
  case "expense_added": {
    const i = input as ExpensePayloadInput;
    return {
      type,
      contextType: i.contextType,
      contextId: i.contextId,
      itemId: i.itemId,
      title: `${i.senderName} added an expense`,
      body: `${i.description} -- ${formatInrFromPaise(i.amountPaise)}.`,
      senderName: i.senderName,
      amountPaise: i.amountPaise.toString(),
      createdAt: createdAtIso,
    };
  }

  case "expense_edited": {
    const i = input as ExpensePayloadInput;
    return {
      type,
      contextType: i.contextType,
      contextId: i.contextId,
      itemId: i.itemId,
      title: `${i.senderName} edited an expense`,
      body:
        `${i.description} was updated to ${formatInrFromPaise(i.amountPaise)}.`,
      senderName: i.senderName,
      amountPaise: i.amountPaise.toString(),
      createdAt: createdAtIso,
    };
  }

  case "expense_deleted": {
    const i = input as ExpensePayloadInput;
    return {
      type,
      contextType: i.contextType,
      contextId: i.contextId,
      // itemId is OPTIONAL for delete (expense has been soft-deleted).
      itemId: i.itemId,
      title: `${i.senderName} deleted an expense`,
      body:
        `${i.description} (${formatInrFromPaise(i.amountPaise)}) was removed.`,
      senderName: i.senderName,
      amountPaise: i.amountPaise.toString(),
      createdAt: createdAtIso,
    };
  }

  case "settlement_received": {
    const i = input as SettlementPayloadInput;
    return {
      type,
      contextType: i.contextType,
      contextId: i.contextId,
      itemId: i.itemId,
      title: `${i.senderName} settled up`,
      body: `You received ${formatInrFromPaise(i.amountPaise)}.`,
      senderName: i.senderName,
      amountPaise: i.amountPaise.toString(),
      createdAt: createdAtIso,
    };
  }

  case "reminder": {
    const i = input as ReminderPayloadInput;
    return {
      type,
      contextType: i.contextType,
      contextId: i.contextId,
      itemId: i.itemId,
      title: `Reminder from ${i.senderName}`,
      body:
        `${i.senderName} is nudging you about ${formatInrFromPaise(i.amountPaise)}.`,
      senderName: i.senderName,
      amountPaise: i.amountPaise.toString(),
      createdAt: createdAtIso,
    };
  }

  case "group_invite": {
    const i = input as GroupInvitePayloadInput;
    return {
      type,
      contextType: i.contextType,
      contextId: i.contextId,
      itemId: i.itemId,
      title: `${i.senderName} invited you to a group`,
      body: `Join "${i.groupName}" to start splitting.`,
      senderName: i.senderName,
      // amountPaise is intentionally OMITTED for group_invite — the
      // template has no monetary value (FR-AC-03 / notifications.md
      // §2.2 group_invite template).
      createdAt: createdAtIso,
      inviteToken: i.inviteToken,
    };
  }

  default: {
    // Exhaustiveness check — TypeScript will fail to compile if a
    // new NotificationType is added to the union without a matching
    // branch here.
    const _exhaustive: never = type;
    throw new Error(
      `renderPayload: unsupported notification type '${_exhaustive as string}'.`,
    );
  }
  }
}
