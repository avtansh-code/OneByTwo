/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/src", "<rootDir>/test/simplified-debts", "<rootDir>/test/lookup-user-by-phone-number", "<rootDir>/test/send-reminder-notification", "<rootDir>/test/delete-user-account", "<rootDir>/test/remove-friendship", "<rootDir>/test/triggers", "<rootDir>/test/triggers/on-friendship-create", "<rootDir>/test/utils", "<rootDir>/test/boundary-contracts", "<rootDir>/test/notifications"],
  testMatch: ["**/*.test.ts"],
  testPathIgnorePatterns: ["\\.integration\\.test\\.ts$"],
  moduleFileExtensions: ["ts", "js", "json"],
  globals: {
    "ts-jest": {
      tsconfig: "tsconfig.test.json",
    },
  },
};
