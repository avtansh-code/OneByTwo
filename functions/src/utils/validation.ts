/**
 * Input validation helpers for callable functions.
 *
 * Every callable function should validate its inputs before
 * performing any Firestore reads/writes. These helpers throw
 * HttpsError with "invalid-argument" on failure.
 */

import { HttpsError } from "firebase-functions/v2/https";
import {
  EXPENSE_CATEGORIES,
  SPLIT_TYPES,
  GROUP_CATEGORIES,
  MEMBER_ROLES,
  type ExpenseCategory,
  type SplitType,
  type GroupCategory,
  type MemberRole,
} from "./constants";

/**
 * Validates that a value is a non-empty string.
 *
 * @param value - The value to check.
 * @param fieldName - The field name (used in error messages).
 * @returns The validated string.
 */
export function validateString(value: unknown, fieldName: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be a non-empty string.`
    );
  }
  return value.trim();
}

/**
 * Validates that a value is a string, but allows it to be undefined/null.
 *
 * @param value - The value to check.
 * @param fieldName - The field name (used in error messages).
 * @returns The validated string, or undefined.
 */
export function validateOptionalString(
  value: unknown,
  fieldName: string
): string | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be a string if provided.`
    );
  }
  return value.trim() || undefined;
}

/**
 * Validates that a value is a positive integer (> 0).
 * Used for monetary amounts in paise.
 *
 * @param value - The value to check.
 * @param fieldName - The field name (used in error messages).
 * @returns The validated integer.
 */
export function validatePositiveInt(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value <= 0) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be a positive integer.`
    );
  }
  return value;
}

/**
 * Validates that a value is a non-negative integer (>= 0).
 *
 * @param value - The value to check.
 * @param fieldName - The field name (used in error messages).
 * @returns The validated integer.
 */
export function validateNonNegativeInt(
  value: unknown,
  fieldName: string
): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value < 0) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be a non-negative integer.`
    );
  }
  return value;
}

/**
 * Validates a Firestore document ID (non-empty string, no slashes).
 *
 * @param value - The value to check.
 * @param fieldName - The field name (used in error messages).
 * @returns The validated document ID.
 */
export function validateDocumentId(value: unknown, fieldName: string): string {
  const id = validateString(value, fieldName);
  if (id.includes("/")) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must not contain slashes.`
    );
  }
  if (id.length > 1500) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} exceeds maximum length.`
    );
  }
  return id;
}

/**
 * Alias for validateDocumentId — validates a groupId.
 */
export function validateGroupId(value: unknown): string {
  return validateDocumentId(value, "groupId");
}

/**
 * Validates a userId (same rules as document ID).
 */
export function validateUserId(value: unknown): string {
  return validateDocumentId(value, "userId");
}

/**
 * Validates a friendPairId (canonical format: userA_userB where userA < userB).
 */
export function validateFriendPairId(value: unknown): string {
  const id = validateString(value, "friendPairId");
  const parts = id.split("_");
  if (parts.length !== 2 || parts[0] >= parts[1]) {
    throw new HttpsError(
      "invalid-argument",
      "friendPairId must be in canonical format (userA_userB where userA < userB)."
    );
  }
  return id;
}

/**
 * Validates that a value is a valid expense category.
 */
export function validateExpenseCategory(value: unknown): ExpenseCategory {
  const str = validateString(value, "category");
  if (!EXPENSE_CATEGORIES.includes(str as ExpenseCategory)) {
    throw new HttpsError(
      "invalid-argument",
      `Invalid category. Must be one of: ${EXPENSE_CATEGORIES.join(", ")}.`
    );
  }
  return str as ExpenseCategory;
}

/**
 * Validates that a value is a valid split type.
 */
export function validateSplitType(value: unknown): SplitType {
  const str = validateString(value, "splitType");
  if (!SPLIT_TYPES.includes(str as SplitType)) {
    throw new HttpsError(
      "invalid-argument",
      `Invalid splitType. Must be one of: ${SPLIT_TYPES.join(", ")}.`
    );
  }
  return str as SplitType;
}

/**
 * Validates that a value is a valid group category.
 */
export function validateGroupCategory(value: unknown): GroupCategory {
  const str = validateString(value, "groupCategory");
  if (!GROUP_CATEGORIES.includes(str as GroupCategory)) {
    throw new HttpsError(
      "invalid-argument",
      `Invalid group category. Must be one of: ${GROUP_CATEGORIES.join(", ")}.`
    );
  }
  return str as GroupCategory;
}

/**
 * Validates that a value is a valid member role.
 */
export function validateMemberRole(value: unknown): MemberRole {
  const str = validateString(value, "role");
  if (!MEMBER_ROLES.includes(str as MemberRole)) {
    throw new HttpsError(
      "invalid-argument",
      `Invalid role. Must be one of: ${MEMBER_ROLES.join(", ")}.`
    );
  }
  return str as MemberRole;
}

/**
 * Validates that a value is a boolean.
 */
export function validateBoolean(value: unknown, fieldName: string): boolean {
  if (typeof value !== "boolean") {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be a boolean.`
    );
  }
  return value;
}

/**
 * Validates that a value is a non-empty array.
 */
export function validateNonEmptyArray<T>(
  value: unknown,
  fieldName: string
): T[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be a non-empty array.`
    );
  }
  return value as T[];
}
