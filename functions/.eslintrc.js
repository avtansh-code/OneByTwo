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
    tsconfigRootDir: __dirname,
  },
  ignorePatterns: [
    "/lib/**/*", // Ignore built files
    "jest.config.js",
    ".eslintrc.js",
  ],
  plugins: ["@typescript-eslint"],
  rules: {
    // TypeScript strict rules
    "@typescript-eslint/no-explicit-any": "warn",
    "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
    "@typescript-eslint/explicit-function-return-type": "off",
    "@typescript-eslint/no-floating-promises": "error",

    // General rules
    "no-console": "warn",
    "prefer-const": "error",
    "no-var": "error",
    "eqeqeq": ["error", "always"],
  },
};
