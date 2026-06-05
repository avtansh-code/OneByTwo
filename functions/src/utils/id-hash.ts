/**
 * PII-safe ID hashing for structured logging.
 *
 * Firestore document IDs that derive from user UIDs (e.g. friendship IDs,
 * which use the pattern `{uidA}_{uidB}`) MUST NOT be logged verbatim —
 * they would leak user identifiers into Cloud Logging in violation of
 * SRS section 5.4 and ADR-0013. This module wraps SHA-256 with a fixed
 * truncation to produce a deterministic, non-reversible identifier
 * suitable for log correlation.
 *
 * Parallel client-side helper: `lib/core/telemetry/event_id_hash.dart`.
 *
 * @module utils/id-hash
 */

import {createHash} from "crypto";

/**
 * Returns a SHA-256-truncated hex hash (16 chars / 64 bits) of the
 * provided ID. Suitable for telemetry / structured-log correlation
 * where the raw value would otherwise leak PII.
 *
 * Examples:
 *   hashId('uid-alice_uid-bob') -> 'a1b2c3d4e5f60718' (16 hex chars)
 *
 * 64 bits of hash space is comfortable for correlation across
 * thousands of contexts without realistic collision risk.
 */
export function hashId(id: string): string {
  return createHash("sha256").update(id).digest("hex").slice(0, 16);
}
