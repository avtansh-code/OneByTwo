/**
 * Unit tests for the Functions-side INR formatter (FR-AC-03 / Invariant 1).
 *
 * Mirrors the client-side `formatInrFromPaise()` semantics
 * (`lib/core/formatters/inr_formatter.dart`): integer arithmetic only,
 * Indian-numbering grouping convention, no inline `/100` arithmetic.
 *
 * The Functions-side flavour is INTEGER-RUPEE ONLY — the notification
 * templates per `docs/design/07-technical/notifications.md` §2.2 render
 * amounts without a paise component (e.g. `"₹1,200"`, not `"₹1,200.00"`).
 * The architect ratified this divergence in §2.1 of the FR-AC-03 story
 * (the formatter is a Functions-side helper for notification-body
 * rendering, not a general-purpose mirror of the Dart formatter).
 *
 * Expected outputs are encoded as string literals; the test file itself
 * MUST NOT contain inline `/100` arithmetic (would violate the existing
 * Functions-side boundary-contract grep at
 * `functions/test/boundary-contracts/no-double-on-money-fields.test.ts`).
 *
 * @module test/utils/format-inr.test.ts
 */

import {formatInrFromPaise} from "../../src/utils/format-inr";

describe("formatInrFromPaise — FR-AC-03 / Invariant 1", () => {
  it("renders zero as '₹0'", () => {
    expect(formatInrFromPaise(0)).toBe("₹0");
  });

  it("renders 100 paise (1 rupee) as '₹1'", () => {
    expect(formatInrFromPaise(100)).toBe("₹1");
  });

  it("renders 120000 paise (1,200 rupees) as '₹1,200'", () => {
    // From the canonical notifications.md §2.2 example.
    expect(formatInrFromPaise(120000)).toBe("₹1,200");
  });

  it("renders 10000000 paise (1 lakh rupees) using Indian lakh grouping", () => {
    expect(formatInrFromPaise(10000000)).toBe("₹1,00,000");
  });

  it("renders 100000000 paise (10 lakh rupees) using Indian 10-lakh grouping", () => {
    expect(formatInrFromPaise(100000000)).toBe("₹10,00,000");
  });

  it("renders large amounts (1 crore rupees) using Indian crore grouping", () => {
    // 1,00,00,00,000 paise = 1,00,00,000 rupees = 1 crore.
    expect(formatInrFromPaise(1000000000)).toBe("₹1,00,00,000");
  });

  it("renders a negative amount with a leading ASCII hyphen-minus", () => {
    // The Functions-side formatter uses the ASCII hyphen-minus, not the
    // Unicode minus (U+2212) — FCM payloads are 7-bit ASCII friendly,
    // and the simpler character avoids edge cases with platform-level
    // string normalisation in client notification UIs.
    expect(formatInrFromPaise(-100)).toBe("-₹1");
  });

  it("renders a negative large amount with Indian grouping after the sign", () => {
    expect(formatInrFromPaise(-12345600)).toBe("-₹1,23,456");
  });

  it("truncates sub-rupee paise (floors toward zero for positives)", () => {
    // 99 paise → 0 rupees. The notification body only displays integer
    // rupees; sub-rupee amounts are dropped from the display string.
    expect(formatInrFromPaise(99)).toBe("₹0");
    // 199 paise → 1 rupee (truncated, not rounded).
    expect(formatInrFromPaise(199)).toBe("₹1");
  });

  it("throws on a non-integer input (Number.isInteger defence-in-depth)", () => {
    // The contract is `paise: number` typed as integer. Defence-in-depth
    // catches a programmer error (or a JSON.parse round-trip that loses
    // type narrowing) at the formatter boundary instead of silently
    // emitting a malformed string.
    expect(() => formatInrFromPaise(1.5)).toThrow();
    expect(() => formatInrFromPaise(NaN)).toThrow();
    expect(() => formatInrFromPaise(Infinity)).toThrow();
  });

  it("throws on a non-finite negative input (NaN, -Infinity)", () => {
    expect(() => formatInrFromPaise(-Infinity)).toThrow();
  });
});
