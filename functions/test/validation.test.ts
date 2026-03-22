/**
 * Tests for input validation helpers.
 */

import {
  validateString,
  validateOptionalString,
  validatePositiveInt,
  validateNonNegativeInt,
  validateDocumentId,
  validateGroupId,
  validateFriendPairId,
  validateBoolean,
  validateNonEmptyArray,
} from "../src/utils/validation";

describe("validateString", () => {
  it("should return trimmed string for valid input", () => {
    expect(validateString("hello", "field")).toBe("hello");
    expect(validateString("  world  ", "field")).toBe("world");
  });

  it("should throw for empty string", () => {
    expect(() => validateString("", "field")).toThrow("non-empty string");
  });

  it("should throw for whitespace-only string", () => {
    expect(() => validateString("   ", "field")).toThrow("non-empty string");
  });

  it("should throw for non-string types", () => {
    expect(() => validateString(123, "field")).toThrow("non-empty string");
    expect(() => validateString(null, "field")).toThrow("non-empty string");
    expect(() => validateString(undefined, "field")).toThrow("non-empty string");
  });
});

describe("validateOptionalString", () => {
  it("should return undefined for null/undefined", () => {
    expect(validateOptionalString(null, "field")).toBeUndefined();
    expect(validateOptionalString(undefined, "field")).toBeUndefined();
  });

  it("should return trimmed string for valid input", () => {
    expect(validateOptionalString("hello", "field")).toBe("hello");
  });

  it("should return undefined for empty string after trim", () => {
    expect(validateOptionalString("   ", "field")).toBeUndefined();
  });

  it("should throw for non-string types", () => {
    expect(() => validateOptionalString(123, "field")).toThrow("string");
  });
});

describe("validatePositiveInt", () => {
  it("should return the integer for valid positive ints", () => {
    expect(validatePositiveInt(1, "amount")).toBe(1);
    expect(validatePositiveInt(10000, "amount")).toBe(10000);
  });

  it("should throw for zero", () => {
    expect(() => validatePositiveInt(0, "amount")).toThrow("positive integer");
  });

  it("should throw for negative numbers", () => {
    expect(() => validatePositiveInt(-5, "amount")).toThrow("positive integer");
  });

  it("should throw for floating-point numbers", () => {
    expect(() => validatePositiveInt(1.5, "amount")).toThrow("positive integer");
  });

  it("should throw for non-number types", () => {
    expect(() => validatePositiveInt("100", "amount")).toThrow("positive integer");
  });
});

describe("validateNonNegativeInt", () => {
  it("should accept zero", () => {
    expect(validateNonNegativeInt(0, "count")).toBe(0);
  });

  it("should accept positive integers", () => {
    expect(validateNonNegativeInt(42, "count")).toBe(42);
  });

  it("should throw for negative numbers", () => {
    expect(() => validateNonNegativeInt(-1, "count")).toThrow("non-negative integer");
  });
});

describe("validateDocumentId", () => {
  it("should return the id for valid document ids", () => {
    expect(validateDocumentId("abc123", "docId")).toBe("abc123");
  });

  it("should throw for ids containing slashes", () => {
    expect(() => validateDocumentId("a/b", "docId")).toThrow("slashes");
  });

  it("should throw for empty strings", () => {
    expect(() => validateDocumentId("", "docId")).toThrow("non-empty string");
  });
});

describe("validateGroupId", () => {
  it("should validate a normal group id", () => {
    expect(validateGroupId("group123")).toBe("group123");
  });
});

describe("validateFriendPairId", () => {
  it("should validate a canonical friend pair id", () => {
    expect(validateFriendPairId("alice_bob")).toBe("alice_bob");
  });

  it("should throw for non-canonical order", () => {
    expect(() => validateFriendPairId("bob_alice")).toThrow("canonical format");
  });

  it("should throw for missing underscore", () => {
    expect(() => validateFriendPairId("alicebob")).toThrow("canonical format");
  });
});

describe("validateBoolean", () => {
  it("should return the boolean for valid input", () => {
    expect(validateBoolean(true, "flag")).toBe(true);
    expect(validateBoolean(false, "flag")).toBe(false);
  });

  it("should throw for non-boolean types", () => {
    expect(() => validateBoolean("true", "flag")).toThrow("boolean");
    expect(() => validateBoolean(1, "flag")).toThrow("boolean");
  });
});

describe("validateNonEmptyArray", () => {
  it("should return the array for valid non-empty arrays", () => {
    expect(validateNonEmptyArray([1, 2, 3], "items")).toEqual([1, 2, 3]);
  });

  it("should throw for empty arrays", () => {
    expect(() => validateNonEmptyArray([], "items")).toThrow("non-empty array");
  });

  it("should throw for non-array types", () => {
    expect(() => validateNonEmptyArray("abc", "items")).toThrow("non-empty array");
  });
});
