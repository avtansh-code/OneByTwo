import {Request, Response} from "express";

// Mock firebase-admin/app before importing the module under test.
jest.mock("firebase-admin/app", () => ({
  initializeApp: jest.fn(),
}));

jest.mock("firebase-admin/firestore", () => ({
  getFirestore: jest.fn(),
}));

jest.mock("firebase-functions/logger", () => ({
  info: jest.fn(),
  error: jest.fn(),
}));

// Mock firebase-functions/v2/https before importing the module under test.
const mockOnRequest = jest.fn(
  (_opts: unknown, handler: (req: Request, res: Response) => void) => handler
);

const mockOnCall = jest.fn(
  (_opts: unknown, handler: unknown) => handler
);

jest.mock("firebase-functions/v2/https", () => ({
  onRequest: mockOnRequest,
  onCall: mockOnCall,
  HttpsError: class HttpsError extends Error {
    code: string;
    details: unknown;
    constructor(code: string, message: string, details?: unknown) {
      super(message);
      this.code = code;
      this.details = details;
    }
  },
}));

describe("healthcheck", () => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const {healthcheck} = require("../index");

  it("returns { ok: true, region: 'asia-south1' }", () => {
    const req = {} as Request;
    const json = jest.fn();
    const status = jest.fn().mockReturnValue({json});
    const res = {status} as unknown as Response;

    healthcheck(req, res);

    expect(status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({ok: true, region: "asia-south1"});
  });

  it("registers with the asia-south1 region", () => {
    expect(mockOnRequest).toHaveBeenCalledWith(
      expect.objectContaining({region: "asia-south1"}),
      expect.any(Function)
    );
  });
});
