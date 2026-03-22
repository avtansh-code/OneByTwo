/**
 * Tests for onUserCreated trigger.
 *
 * Tests the exported `initializeNewUser` helper which contains the
 * batch-write logic executed when a new user document is created.
 */

// ── Mock firebase-functions modules ─────────────────────────────────────────
jest.mock("firebase-functions/v2/firestore", () => ({
  onDocumentCreated: jest.fn().mockReturnValue("mock-trigger"),
}));

jest.mock("firebase-functions", () => ({
  logger: {
    info: jest.fn(),
    error: jest.fn(),
  },
}));

// ── Mock firebase-admin/firestore ───────────────────────────────────────────
const mockBatchSet = jest.fn();
const mockBatchCommit = jest.fn().mockResolvedValue(undefined);
const mockBatch = jest.fn(() => ({
  set: mockBatchSet,
  commit: mockBatchCommit,
}));

const mockDocRef = jest.fn((path: string) => ({
  path,
  id: path.split("/").pop(),
}));

const mockAutoDocRef = {
  path: "users/testUid/notifications/auto-id",
  id: "auto-id",
};
const mockCollectionDoc = jest.fn().mockReturnValue(mockAutoDocRef);
const mockCollection = jest.fn().mockReturnValue({ doc: mockCollectionDoc });

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: jest.fn(() => ({
    batch: mockBatch,
    doc: mockDocRef,
    collection: mockCollection,
  })),
  FieldValue: {
    serverTimestamp: jest.fn(() => "SERVER_TIMESTAMP"),
  },
}));

// ── Import after mocks are established ──────────────────────────────────────
import { initializeNewUser, onUserCreated } from "../src/triggers/onUserCreated";

describe("onUserCreated", () => {
  describe("module exports", () => {
    it("should export onUserCreated", () => {
      expect(onUserCreated).toBeDefined();
    });

    it("should export initializeNewUser as a function", () => {
      expect(initializeNewUser).toBeDefined();
      expect(typeof initializeNewUser).toBe("function");
    });
  });

  describe("initializeNewUser", () => {
    const testUid = "user_abc123";

    it("should create a Firestore batch", async () => {
      await initializeNewUser(testUid);

      expect(mockBatch).toHaveBeenCalledTimes(1);
    });

    it("should perform exactly 3 batch set operations", async () => {
      await initializeNewUser(testUid);

      expect(mockBatchSet).toHaveBeenCalledTimes(3);
    });

    it("should create userGroups metadata document with correct data", async () => {
      await initializeNewUser(testUid);

      expect(mockDocRef).toHaveBeenCalledWith(`userGroups/${testUid}`);
      expect(mockBatchSet).toHaveBeenCalledWith(
        expect.objectContaining({ path: `userGroups/${testUid}` }),
        {
          userId: testUid,
          createdAt: "SERVER_TIMESTAMP",
        }
      );
    });

    it("should create userFriends metadata document with correct data", async () => {
      await initializeNewUser(testUid);

      expect(mockDocRef).toHaveBeenCalledWith(`userFriends/${testUid}`);
      expect(mockBatchSet).toHaveBeenCalledWith(
        expect.objectContaining({ path: `userFriends/${testUid}` }),
        {
          userId: testUid,
          createdAt: "SERVER_TIMESTAMP",
        }
      );
    });

    it("should create welcome notification in the user notifications collection", async () => {
      await initializeNewUser(testUid);

      expect(mockCollection).toHaveBeenCalledWith(
        `users/${testUid}/notifications`
      );
      expect(mockCollectionDoc).toHaveBeenCalled();
    });

    it("should set welcome notification with correct English fields by default", async () => {
      await initializeNewUser(testUid);

      expect(mockBatchSet).toHaveBeenCalledWith(mockAutoDocRef, {
        type: "welcome",
        title: "Welcome to One By Two!",
        body: "Start splitting expenses with friends and groups.",
        isRead: false,
        createdAt: "SERVER_TIMESTAMP",
      });
    });

    it("should set welcome notification with Hindi fields when language is 'hi'", async () => {
      await initializeNewUser(testUid, "hi");

      expect(mockBatchSet).toHaveBeenCalledWith(mockAutoDocRef, {
        type: "welcome",
        title: "वन बाय टू में आपका स्वागत है!",
        body: "दोस्तों और ग्रुप के साथ खर्चे बाँटना शुरू करें।",
        isRead: false,
        createdAt: "SERVER_TIMESTAMP",
      });
    });

    it("should fall back to English for an unsupported language code", async () => {
      await initializeNewUser(testUid, "fr");

      expect(mockBatchSet).toHaveBeenCalledWith(mockAutoDocRef, {
        type: "welcome",
        title: "Welcome to One By Two!",
        body: "Start splitting expenses with friends and groups.",
        isRead: false,
        createdAt: "SERVER_TIMESTAMP",
      });
    });

    it("should commit the batch", async () => {
      await initializeNewUser(testUid);

      expect(mockBatchCommit).toHaveBeenCalledTimes(1);
    });

    it("should propagate errors from batch.commit()", async () => {
      const commitError = new Error("Firestore write failed");
      mockBatchCommit.mockRejectedValueOnce(commitError);

      await expect(initializeNewUser(testUid)).rejects.toThrow(
        "Firestore write failed"
      );
    });
  });
});
