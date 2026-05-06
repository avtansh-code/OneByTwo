/**
 * Unit tests for the lookupUserByPhoneNumber algorithm module.
 *
 * These tests validate the pure lookup logic using a mock Firestore dependency.
 * The source module does not exist yet (test-first discipline) — these tests
 * will fail to compile until the implementation is created.
 */

import {
  lookupUserByPhoneNumber,
  LookupResult,
} from "../../src/lookup-user-by-phone-number/algorithm";

// ---------------------------------------------------------------------------
// Mock helpers
// ---------------------------------------------------------------------------

/** Allowed keys in a matched response. */
const MATCHED_RESPONSE_KEYS = ["matched", "displayName", "photoUrl", "otherUserId"];

/** Keys that must NEVER appear in any response (private user fields). */
const FORBIDDEN_KEYS = [
  "phoneNumber",
  "fcmTokens",
  "notificationPrefs",
  "locale",
  "createdAt",
  "updatedAt",
];

/**
 * Creates a mock Firestore that returns the given user documents when queried
 * with `db.collection('users').where('phoneNumber', '==', ...).limit(1).get()`.
 */
function createMockDb(userDocs: Array<{id: string; data: Record<string, unknown>}>) {
  const docs = userDocs.map((u) => ({
    id: u.id,
    exists: true,
    data: () => u.data,
  }));

  const mockDb = {
    collection: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        limit: jest.fn().mockReturnValue({
          get: jest.fn().mockResolvedValue({
            empty: docs.length === 0,
            docs,
          }),
        }),
      }),
    }),
  };

  return mockDb as unknown as FirebaseFirestore.Firestore;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("lookupUserByPhoneNumber algorithm", () => {
  // -------------------------------------------------------------------------
  // Case 1: Phone number not found
  // -------------------------------------------------------------------------
  it("returns { matched: false } when phone number is not in the users collection", async () => {
    const db = createMockDb([]);
    const result = await lookupUserByPhoneNumber("+919876543210", "caller-uid", {db});

    expect(result).toEqual({matched: false});
  });

  it("response contains only 'matched' key when not found", async () => {
    const db = createMockDb([]);
    const result = await lookupUserByPhoneNumber("+919876543210", "caller-uid", {db});

    expect(Object.keys(result)).toEqual(["matched"]);
  });

  // -------------------------------------------------------------------------
  // Case 2: Phone number found — correct fields returned
  // -------------------------------------------------------------------------
  it("returns matched result with correct fields when phone number is found", async () => {
    const db = createMockDb([
      {
        id: "other-user-id",
        data: {
          phoneNumber: "+919876543211",
          displayName: "Priya",
          photoUrl: "https://example.com/photo.jpg",
          fcmTokens: ["token1"],
          notificationPrefs: {newExpense: true, settlement: true, reminder: true},
          locale: "en-IN",
          createdAt: "2024-01-01T00:00:00Z",
          updatedAt: "2024-01-01T00:00:00Z",
        },
      },
    ]);

    const result = await lookupUserByPhoneNumber("+919876543211", "caller-uid", {db});

    expect(result).toEqual({
      matched: true,
      displayName: "Priya",
      photoUrl: "https://example.com/photo.jpg",
      otherUserId: "other-user-id",
    });
  });

  // -------------------------------------------------------------------------
  // Case 3: Phone number matches the calling user themselves
  // -------------------------------------------------------------------------
  it("still returns matched when phone number belongs to the caller", async () => {
    const db = createMockDb([
      {
        id: "caller-uid",
        data: {
          phoneNumber: "+919876543210",
          displayName: "Avtansh",
          photoUrl: null,
          fcmTokens: [],
          notificationPrefs: {newExpense: true, settlement: true, reminder: true},
          locale: "en-IN",
          createdAt: "2024-01-01T00:00:00Z",
          updatedAt: "2024-01-01T00:00:00Z",
        },
      },
    ]);

    const result = await lookupUserByPhoneNumber("+919876543210", "caller-uid", {db});

    expect((result as {matched: true}).matched).toBe(true);
    expect((result as {matched: true; otherUserId: string}).otherUserId).toBe("caller-uid");
  });

  // -------------------------------------------------------------------------
  // Case 4: Response keys are exhaustively validated — no private fields leak
  // -------------------------------------------------------------------------
  it("matched response contains ONLY matched, displayName, photoUrl, otherUserId", async () => {
    const db = createMockDb([
      {
        id: "other-user-id",
        data: {
          phoneNumber: "+919876543211",
          displayName: "Priya",
          photoUrl: "https://example.com/photo.jpg",
          fcmTokens: ["token1"],
          notificationPrefs: {newExpense: true, settlement: true, reminder: true},
          locale: "en-IN",
          createdAt: "2024-01-01T00:00:00Z",
          updatedAt: "2024-01-01T00:00:00Z",
        },
      },
    ]);

    const result = await lookupUserByPhoneNumber("+919876543211", "caller-uid", {db});

    // Exhaustive key check
    expect(Object.keys(result).sort()).toEqual(MATCHED_RESPONSE_KEYS.sort());

    // Explicitly verify no forbidden keys
    for (const key of FORBIDDEN_KEYS) {
      expect(result).not.toHaveProperty(key);
    }
  });

  it("unmatched response contains ONLY the 'matched' key", async () => {
    const db = createMockDb([]);
    const result = await lookupUserByPhoneNumber("+919999999999", "caller-uid", {db});

    expect(Object.keys(result)).toEqual(["matched"]);

    for (const key of FORBIDDEN_KEYS) {
      expect(result).not.toHaveProperty(key);
    }
  });

  // -------------------------------------------------------------------------
  // Case 5: User with null photoUrl
  // -------------------------------------------------------------------------
  it("returns photoUrl as null when the matched user has no photo", async () => {
    const db = createMockDb([
      {
        id: "no-photo-user",
        data: {
          phoneNumber: "+919876543212",
          displayName: "Rahul",
          photoUrl: null,
          fcmTokens: [],
          notificationPrefs: {newExpense: true, settlement: true, reminder: true},
          locale: "en-IN",
          createdAt: "2024-01-01T00:00:00Z",
          updatedAt: "2024-01-01T00:00:00Z",
        },
      },
    ]);

    const result = await lookupUserByPhoneNumber("+919876543212", "caller-uid", {db});

    expect(result).toEqual({
      matched: true,
      displayName: "Rahul",
      photoUrl: null,
      otherUserId: "no-photo-user",
    });
  });

  // -------------------------------------------------------------------------
  // Case 6: Firestore query is constructed correctly
  // -------------------------------------------------------------------------
  it("queries the users collection with the correct phone number", async () => {
    const db = createMockDb([]);
    await lookupUserByPhoneNumber("+919876543210", "caller-uid", {db});

    expect(db.collection).toHaveBeenCalledWith("users");
    const collection = (db.collection as jest.Mock).mock.results[0].value;
    expect(collection.where).toHaveBeenCalledWith("phoneNumber", "==", "+919876543210");
    const whereResult = collection.where.mock.results[0].value;
    expect(whereResult.limit).toHaveBeenCalledWith(1);
  });
});
