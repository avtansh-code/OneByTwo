/**
 * Functions-side boundary-contract tests (Invariant 1 — paise integers).
 *
 * Greps functions/src/** for forbidden patterns that would violate the
 * load-bearing Invariant 1 (Money is integer paise):
 *
 *   - No `.toDouble()` calls anywhere on a monetary path.
 *   - No `parseFloat` / `Number.parseFloat` calls.
 *   - No `.toFixed(...)` calls (rupee-formatted strings have no place
 *     in the Functions write path).
 *   - No `/100` or `/100.0` divisions (paise → rupee conversion belongs
 *     exclusively at the client UI layer).
 *
 * Mirrors the Flutter-side contract at
 * test/features/expenses/expense_creation_boundary_contract_test.dart
 * shipped in PR #38 (FR-EX-01). Architect-ratified for FR-EX-07 per
 * architect notes §2.9 item 7 (defence-in-depth on the activity-payload
 * write path; functions/src/triggers/** is now a non-trivial monetary
 * surface).
 *
 * @module test/boundary-contracts/no-double-on-money-fields.test.ts
 */

import {readdirSync, readFileSync, statSync} from "fs";
import {join, resolve} from "path";

const SRC_ROOT = resolve(__dirname, "../../src");

/**
 * Lines that are pure comments (// ..., * ..., /* ..., etc.) are
 * exempt — explanatory text about "/100 paise" or "double-entry
 * bookkeeping" is allowed in comments.
 */
function isCommentLine(line: string): boolean {
  const trimmed = line.trimStart();
  return (
    trimmed.startsWith("//") ||
    trimmed.startsWith("*") ||
    trimmed.startsWith("/*")
  );
}

/** Recursively yields every .ts file under the given directory. */
function* walk(dir: string): Generator<string> {
  for (const entry of readdirSync(dir)) {
    const fullPath = join(dir, entry);
    const stat = statSync(fullPath);
    if (stat.isDirectory()) {
      yield* walk(fullPath);
    } else if (entry.endsWith(".ts") && !entry.endsWith(".d.ts")) {
      yield fullPath;
    }
  }
}

interface Violation {
  file: string;
  lineNumber: number;
  pattern: string;
  line: string;
}

function scan(
  predicate: (line: string) => string | null,
): Violation[] {
  const violations: Violation[] = [];
  for (const file of walk(SRC_ROOT)) {
    const content = readFileSync(file, "utf8");
    const lines = content.split("\n");
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (isCommentLine(line)) continue;
      const matchedPattern = predicate(line);
      if (matchedPattern !== null) {
        violations.push({
          file: file.replace(`${SRC_ROOT}/`, "functions/src/"),
          lineNumber: i + 1,
          pattern: matchedPattern,
          line: line.trim(),
        });
      }
    }
  }
  return violations;
}

function format(violations: Violation[]): string {
  return violations
    .map(
      (v) =>
        `  ${v.file}:${v.lineNumber}: forbidden ${v.pattern}\n    > ${v.line}`,
    )
    .join("\n");
}

describe("functions/src/** boundary contract — Invariant 1 (paise integers)", () => {
  it("contains no .toDouble() calls", () => {
    const violations = scan((line) =>
      line.includes(".toDouble()") ? ".toDouble()" : null,
    );
    if (violations.length > 0) {
      throw new Error(
        `Found ${violations.length} forbidden .toDouble() call(s):\n` +
          format(violations),
      );
    }
    expect(violations).toEqual([]);
  });

  it("contains no parseFloat / Number.parseFloat calls", () => {
    const violations = scan((line) => {
      if (line.includes("Number.parseFloat")) return "Number.parseFloat";
      // Match `parseFloat(` as a function call (rather than e.g. a
      // property name that happens to contain the substring).
      if (/\bparseFloat\s*\(/.test(line)) return "parseFloat()";
      return null;
    });
    if (violations.length > 0) {
      throw new Error(
        `Found ${violations.length} forbidden parseFloat call(s):\n` +
          format(violations),
      );
    }
    expect(violations).toEqual([]);
  });

  it("contains no .toFixed(...) calls (rupee-formatting belongs at the UI layer)", () => {
    const violations = scan((line) =>
      /\.toFixed\s*\(/.test(line) ? ".toFixed()" : null,
    );
    if (violations.length > 0) {
      throw new Error(
        `Found ${violations.length} forbidden .toFixed() call(s):\n` +
          format(violations),
      );
    }
    expect(violations).toEqual([]);
  });

  it("contains no /100 or /100.0 paise-to-rupee divisions", () => {
    const violations = scan((line) => {
      // Match `/ 100` or `/100` followed by a non-digit (so it does not
      // match `/1000`, `/1024`, etc.).
      if (/\/\s*100(\.0+)?(?!\d)/.test(line)) {
        return "/100 paise division (do paise->rupee conversion at UI layer)";
      }
      return null;
    });
    if (violations.length > 0) {
      throw new Error(
        `Found ${violations.length} forbidden /100 division(s):\n` +
          format(violations),
      );
    }
    expect(violations).toEqual([]);
  });

  it("declares the canonical monetary field shapes (amountPaise / sharePaise as 'number')", () => {
    // This is an affirmative anchor check: the canonical `: number`
    // shape MUST exist somewhere in the codebase. The activity-writer
    // and payload-builder use it; if a future refactor drifts to
    // `amountRupees` or float-typed fields, this check would fail.
    let foundCanonical = false;
    for (const file of walk(SRC_ROOT)) {
      const content = readFileSync(file, "utf8");
      if (
        /amountPaise\s*:\s*number/.test(content) ||
        /sharePaise\s*:\s*number/.test(content)
      ) {
        foundCanonical = true;
        break;
      }
    }
    expect(foundCanonical).toBe(true);
  });
});
