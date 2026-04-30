// @ts-check

/** @type {import('eslint').Linter.Config} */
module.exports = {
  root: true,
  env: {
    es2022: true,
    node: true,
    jest: true,
  },
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json"],
    sourceType: "module",
  },
  ignorePatterns: [
    "/lib/**/*",
    "/node_modules/**/*",
    "jest.config.js",
  ],
  plugins: ["@typescript-eslint"],
  rules: {
    // Coding standards: strict TypeScript
    "@typescript-eslint/no-unused-vars": ["error", {argsIgnorePattern: "^_"}],
    "@typescript-eslint/explicit-function-return-type": "warn",
  },
};
