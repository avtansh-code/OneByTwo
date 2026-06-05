/**
 * Unit tests for the id-hash utility.
 *
 * @module test/utils/id-hash.test.ts
 */

import {hashId} from "../../src/utils/id-hash";

describe("hashId", () => {
  it("returns a 16-character hex string", () => {
    const h = hashId("user-aaa_user-bbb");
    expect(h).toMatch(/^[0-9a-f]{16}$/);
    expect(h).toHaveLength(16);
  });

  it("is deterministic — same input yields same hash", () => {
    expect(hashId("user-aaa_user-bbb")).toBe(hashId("user-aaa_user-bbb"));
  });

  it("returns different hashes for different inputs", () => {
    expect(hashId("user-aaa_user-bbb")).not.toBe(hashId("user-aaa_user-ccc"));
  });

  it("does not reveal the raw input in the hash", () => {
    const raw = "highly-sensitive-uid_other-sensitive-uid";
    const hashed = hashId(raw);
    expect(hashed).not.toContain("sensitive");
    expect(hashed).not.toContain("uid");
  });

  it("handles empty input deterministically", () => {
    // Empty string is a legitimate input — SHA-256 of "" has a well-known value.
    const h = hashId("");
    expect(h).toMatch(/^[0-9a-f]{16}$/);
    expect(h).toBe("e3b0c44298fc1c14");
  });
});
