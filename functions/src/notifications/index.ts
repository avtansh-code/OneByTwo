/**
 * Public surface of the FR-AC-03 FCM notifications module.
 *
 * Exports two trigger-facing entry points
 * (`sendExpenseNotification`, `sendSettlementNotification`) and the
 * shared `NotificationsApi` / payload / preference types referenced
 * from the trigger's `Dependencies` shape (architect §2.10 item 7).
 *
 * Internal helpers (`fcm-send`, `payload-renderer`, `prefs-filter`,
 * `format-inr`) are NOT re-exported — they are call-site-specific
 * details that the trigger should not depend on directly.
 *
 * @module notifications
 */

export {sendExpenseNotification} from "./send-expense-notification";
export {sendSettlementNotification} from "./send-settlement-notification";
export {sendReminderNotification} from "./send-reminder-notification";
export type {
  NotificationsApi,
  NotificationsDependencies,
  NotificationType,
  NotificationPayload,
  NotificationDispatchResult,
  RecipientPrefs,
  SendExpenseNotificationParams,
  SendSettlementNotificationParams,
  SendReminderNotificationParams,
} from "./types";
