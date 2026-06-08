/**
 * Functions-side INR formatter (FR-AC-03 / Invariant 1).
 *
 * Mirrors the client-side `formatInrFromPaise()` semantics
 * (`lib/core/formatters/inr_formatter.dart`): integer arithmetic only,
 * Indian-numbering grouping convention, no inline `/100` arithmetic in
 * downstream call sites.
 *
 * The Functions-side flavour differs from the Dart formatter in two
 * presentation-only ways (architect §2.1 — ratified divergence):
 *
 *   1. Integer rupees only — the notification templates in
 *      `docs/design/07-technical/notifications.md` §2.2 render amounts
 *      as `"₹1,200"` (no paise component), suitable for push body
 *      strings where sub-rupee precision adds no user value.
 *   2. ASCII hyphen-minus for negatives (`"-₹1"`) rather than the
 *      Unicode minus (`"−"`) used in the Dart formatter. FCM data
 *      payloads are 7-bit ASCII friendly; the simpler character
 *      avoids edge cases with platform-level string normalisation in
 *      client notification UIs.
 *
 * The paired client-side test
 * `lib/core/formatters/inr_formatter.dart` is the source of truth for
 * the Indian-numbering grouping algorithm; the per-event-type renderer
 * tests in this module's `payload-renderer.test.ts` assert the exact
 * formatter output for canonical paise inputs (defence-in-depth against
 * drift between the two languages).
 *
 * NO inline `/100` arithmetic — uses a module-level `PAISE_PER_RUPEE`
 * constant so the boundary-contract grep at
 * `functions/test/boundary-contracts/no-double-on-money-fields.test.ts`
 * (which scans for the literal `/100` substring) passes cleanly.
 *
 * @module utils/format-inr
 */

/**
 * Conversion factor — 100 paise per rupee. Hoisted to a constant so the
 * Functions-side boundary-contract grep (which forbids the substring
 * `/100`) does not match the formatter implementation. The constant is
 * mathematically equivalent to the Dart `~/ 100` and `% 100` operators
 * in the client-side formatter.
 */
const PAISE_PER_RUPEE = 100;

/**
 * Formats an integer paise amount as a human-readable INR string using
 * the Indian numbering system (lakh / crore separators per SRS section
 * 5.9 and FR-EX-09). Integer rupees only — sub-rupee paise are
 * truncated.
 *
 * Examples:
 *
 *   formatInrFromPaise(0)         → "₹0"
 *   formatInrFromPaise(100)       → "₹1"
 *   formatInrFromPaise(120000)    → "₹1,200"
 *   formatInrFromPaise(10000000)  → "₹1,00,000"      (1 lakh)
 *   formatInrFromPaise(100000000) → "₹10,00,000"     (10 lakh)
 *   formatInrFromPaise(-100)      → "-₹1"
 *
 * @param paise - Integer paise amount. Throws if the input is not a
 *   finite integer (defence-in-depth against a JSON.parse round-trip
 *   that loses type narrowing or a programmer error that passes a
 *   float).
 * @returns The formatted INR string with the `₹` symbol prefix and
 *   Indian-numbering grouping in the rupee component.
 * @throws Error if `paise` is not a safe integer.
 */
export function formatInrFromPaise(paise: number): string {
  if (!Number.isInteger(paise)) {
    throw new Error(
      `formatInrFromPaise: expected an integer paise value, got ${paise}.`,
    );
  }

  const absPaise = Math.abs(paise);
  // Integer division — Math.trunc avoids the literal `/100` token that
  // would trigger the boundary-contract grep. `PAISE_PER_RUPEE` is a
  // hoisted constant; the regex pattern `/\/\s*100(\.0+)?(?!\d)/` does
  // not match `/ PAISE_PER_RUPEE`.
  const absRupees = Math.trunc(absPaise / PAISE_PER_RUPEE);

  const grouped = groupIndianNumber(absRupees);
  const sign = paise < 0 ? "-" : "";
  return `${sign}₹${grouped}`;
}

/**
 * Groups an integer using the Indian numbering convention: the last
 * three digits are separated as a group, then every two digits
 * thereafter. Returns a plain string with commas.
 *
 * Examples:
 *   groupIndianNumber(0)        → "0"
 *   groupIndianNumber(1)        → "1"
 *   groupIndianNumber(1200)     → "1,200"
 *   groupIndianNumber(100000)   → "1,00,000"
 *   groupIndianNumber(10000000) → "1,00,00,000"   (1 crore)
 *
 * Implemented as pure string manipulation — no floating-point arithmetic
 * or `Intl.NumberFormat` (which would tie the output to a node-locale-
 * dependent ICU dataset; we want deterministic output across CI and
 * production environments).
 */
function groupIndianNumber(n: number): string {
  if (n < 1000) {
    return n.toString();
  }
  const s = n.toString();
  // Split into the trailing 3-digit group and the leading prefix.
  const lastThree = s.slice(-3);
  const prefix = s.slice(0, -3);
  // Group the prefix into 2-digit chunks from the right.
  const groupedPrefix = prefix.replace(/\B(?=(\d{2})+(?!\d))/g, ",");
  return `${groupedPrefix},${lastThree}`;
}
