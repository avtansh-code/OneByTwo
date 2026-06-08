/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/src", "<rootDir>/test/simplified-debts", "<rootDir>/test/lookup-user-by-phone-number", "<rootDir>/test/triggers", "<rootDir>/test/utils", "<rootDir>/test/boundary-contracts"],
  testMatch: ["**/*.test.ts"],
  testPathIgnorePatterns: ["\\.integration\\.test\\.ts$"],
  moduleFileExtensions: ["ts", "js", "json"],
  globals: {
    "ts-jest": {
      tsconfig: "tsconfig.test.json",
    },
  },
};
