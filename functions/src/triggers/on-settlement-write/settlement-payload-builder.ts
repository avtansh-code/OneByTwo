/**
 * Activity Payload Builder for the settlement trigger (FR-AC-01).
 *
 * Pure function that maps the settlement-trigger
 * `(changeType, before, after)` tuple to a typed `BuiltActivityPayload`
 * for embedding inside an `activity/{userId}/items/{auto-id}` document.
 * Mirrors the FR-EX-07 payload-builder convention; the sibling
 * placement (under `on-settlement-write/`) keeps the trigger-specific
 * mapping co-located with its consumer.
 *
 * Architect ratification: FR-AC-01 architect notes §2.2 (soft-delete
 * emits NO activity item) and §2.4 (settlement payload schema).
 *
 * @module triggers/on-settlement-write/settlement-payload-builder
 */

import type {
  ActivityItemType,
  ActivityPayload,
  SettlementPayload,
} from "../on-expense-write/payload-builder";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Trigger change discriminator (mirrors `function.ts` `ChangeType`). */
export type ChangeType = "create" | "update" | "delete";

/**
 * Shape of the source settlement document (subset relevant to the
 * activity payload). Mirrors the fields read by the trigger handler's
 * `extractContextDiscriminator` plus the additional fields needed by
 * the activity payload (`fromUserId`, `toUserId`, `amountPaise`,
 * `note`).
 */
export interface SettlementDocData {
  fromUserId: string;
  toUserId: string;
  amountPaise: number;
  contextType: "friendship" | "group";
  contextId: string;
  note?: string | null;
  deleted?: boolean;
}

/** Result tuple of `buildSettlementActivityPayload`. */
export interface BuiltActivityPayload {
  eventType: ActivityItemType;
  payload: ActivityPayload;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Maps a settlement-trigger event to the activity-payload pair
 * `{ eventType, payload }` for emission into
 * `activity/{userId}/items/{auto-id}` documents.
 *
 * V1.0 emission policy (architect §2.2):
 *
 *   - `'create'`: emit `{eventType: 'settlement', payload: {...}}`.
 *   - `'update'`: NO emission (settlements only update on soft-delete
 *     per the rules at firestore.rules:461-469; the SCR-25 Event Type
 *     Mapping has no `settlementDeleted` row; v1.0 contract is
 *     "no activity item on settlement soft-delete").
 *   - `'delete'`: NO emission (hard-delete is admin-only; no SCR-25
 *     row type).
 *
 * The `null` return signals "no activity emission for this branch"
 * — the caller MUST short-circuit before invoking the activity-writer
 * when this function returns null.
 *
 * @param changeType - The trigger's change discriminator.
 * @param request - The settlement document ID + before/after snapshots.
 *   `after` is required for `'create'`; `before` is required for
 *   `'delete'`; both are required for `'update'`.
 * @returns The typed `{eventType, payload}` tuple for create events;
 *   `null` for update/delete events (no activity emission).
 *
 * @throws Error if the `(changeType, before, after)` combination is
 *   inconsistent (e.g. `'create'` with no `after`).
 */
export function buildSettlementActivityPayload(
  changeType: ChangeType,
  request: {
    settlementId: string;
    before?: SettlementDocData;
    after?: SettlementDocData;
  },
): BuiltActivityPayload | null {
  const {settlementId, after} = request;

  if (changeType === "create") {
    if (!after) {
      throw new Error(
        "buildSettlementActivityPayload: 'create' requires 'after' snapshot.",
      );
    }
    return {
      eventType: "settlement",
      payload: buildSettlementPayload(settlementId, after),
    };
  }

  // Both 'update' (soft-delete) and 'delete' (hard-delete) emit NO
  // activity item per architect §2.2. Documented in code so the caller
  // can short-circuit cleanly.
  return null;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/**
 * Builds the `settlement` payload from the source settlement document.
 * The `note` field is omitted when the source value is null or
 * undefined; included when present and non-empty.
 */
function buildSettlementPayload(
  settlementId: string,
  data: SettlementDocData,
): SettlementPayload {
  const payload: SettlementPayload = {
    settlementId,
    fromUserId: data.fromUserId,
    toUserId: data.toUserId,
    amountPaise: data.amountPaise,
    contextType: data.contextType,
    contextId: data.contextId,
    authorUid: data.fromUserId,
  };

  if (typeof data.note === "string" && data.note.length > 0) {
    payload.note = data.note;
  }

  return payload;
}
