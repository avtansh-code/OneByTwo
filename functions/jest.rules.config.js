/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: [
    "<rootDir>/test/firestore-rules",
    "<rootDir>/test/storage-rules",
  ],
  testMatch: ["**/*.test.ts"],
  moduleFileExtensions: ["ts", "js", "json"],
  // Run serially — all suites share a single emulator and clearFirestore()
  // in one suite can race with seeds in another.
  maxWorkers: 1,
  globals: {
    "ts-jest": {
      tsconfig: "tsconfig.test.json",
    },
  },
};
