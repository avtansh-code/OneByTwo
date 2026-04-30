import {Request, Response} from "express";

// Mock firebase-functions/v2/https before importing the module under test.
const mockOnRequest = jest.fn(
  (_opts: unknown, handler: (req: Request, res: Response) => void) => handler
);

jest.mock("firebase-functions/v2/https", () => ({
  onRequest: mockOnRequest,
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
