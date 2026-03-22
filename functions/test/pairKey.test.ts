/**
 * Tests for pairKey utility functions.
 */

import { canonicalPairKey, splitPairKey, otherUserInPair } from "../src/utils/pairKey";

describe("canonicalPairKey", () => {
  it("should return userA_userB when userA < userB", () => {
    expect(canonicalPairKey("alice", "bob")).toBe("alice_bob");
  });

  it("should return userA_userB when arguments are in reverse order", () => {
    expect(canonicalPairKey("bob", "alice")).toBe("alice_bob");
  });

  it("should be deterministic regardless of argument order", () => {
    expect(canonicalPairKey("user1", "user2")).toBe(
      canonicalPairKey("user2", "user1")
    );
  });

  it("should throw if both users are the same", () => {
    expect(() => canonicalPairKey("alice", "alice")).toThrow(
      "Cannot create a pair key for the same user."
    );
  });
});

describe("splitPairKey", () => {
  it("should split a canonical pair key into two user IDs", () => {
    const [a, b] = splitPairKey("alice_bob");
    expect(a).toBe("alice");
    expect(b).toBe("bob");
  });

  it("should throw for an invalid pair key (no underscore)", () => {
    expect(() => splitPairKey("alicebob")).toThrow("Invalid pair key format");
  });

  it("should throw for a non-canonical pair key", () => {
    expect(() => splitPairKey("bob_alice")).toThrow(
      "Pair key is not in canonical order"
    );
  });
});

describe("otherUserInPair", () => {
  it("should return userB when given userA", () => {
    expect(otherUserInPair("alice_bob", "alice")).toBe("bob");
  });

  it("should return userA when given userB", () => {
    expect(otherUserInPair("alice_bob", "bob")).toBe("alice");
  });

  it("should throw if the user is not in the pair", () => {
    expect(() => otherUserInPair("alice_bob", "charlie")).toThrow(
      "User charlie is not part of pair alice_bob."
    );
  });
});
