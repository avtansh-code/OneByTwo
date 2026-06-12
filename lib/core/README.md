# core

Cross-cutting helpers and the shared design-system widget catalogue
used by every feature folder. Nothing here is feature-specific; code
that belongs to a single feature lives under
`lib/features/<feature>/`.

## Implemented scope

### Money and balances

- `formatters/inr_formatter.dart` — `formatInrFromPaise(int paise)`. The
  **single source of truth** for paise → INR conversion (Invariant 1).
  Uses Indian-numbering grouping (`₹1,23,456.78`), always two decimals,
  and the Unicode minus sign (U+2212) for negatives. All arithmetic is
  integer (`~/`, `%`); no `double` is ever produced from paise.
- `balances/net_balance.dart` — `netBalancePaise(...)`, a pure, read-only
  projection of a friendship's server-maintained `simplifiedBalances`
  map into a signed `int` net (positive = the other user owes you).
  Never mutates the map and is never called from write paths
  (Invariant 2).

### Telemetry

- `telemetry/event_id_hash.dart` — `hashFriendshipId()` and `hashId()`,
  SHA-256-truncated-to-16-hex helpers used to mask PII-adjacent
  identifiers (`friendship_id`, `expense_id`, etc.) before they reach
  analytics (ADR-0013). The parameter-key convention is to append
  `_hash`.

### Routing

- `routing/notification_deep_links.dart` — the `DeepLinkTarget` sealed
  union plus `NotificationDeepLinks.resolve` (pure, payload → target)
  and `NotificationDeepLinks.navigate`. Shared by the notifications
  feature (foreground banner / background tap / cold start) and the
  activity feed.

### Services

- `services/image_picker_service.dart` — `ImagePickerService`
  abstraction over `image_picker` plus `imagePickerServiceProvider`, so
  tests inject a fake without the platform plugin (used by profile
  avatar and expense receipt flows).

### Connectivity

- `connectivity/connectivity_provider.dart` — the `IsOnline` typedef and
  `connectivityCheckProvider` (`Provider<IsOnline>`). A **one-shot**
  reachability check backed by `connectivity_plus`, used at write time
  (e.g. the notification-preferences toggle); it swallows
  platform-channel exceptions and assumes online. There is no continuous
  connectivity stream or global offline banner in v1.0.

### Validation and input formatting

- `validators.dart` — Indian-mobile validation helpers (10 digits,
  first digit 6-9).
- `widgets/india_phone_input_formatter.dart` — `IndianPhoneInputFormatter`,
  a `TextInputFormatter` that strips `+91` / `91` / `091` prefixes from
  pasted input and caps at 10 digits.

### Result type

- `result.dart` — a lightweight `sealed class Result<T, E>` with
  `Success` / `Failure` for explicit error handling.

### Design-system widgets

Reusable OBT* primitives from the design-system catalogue
(`docs/design/02-design-system/components.md`):

- `widgets/dialogs/obt_confirmation_dialog.dart` — `OBTConfirmationDialog`
  with an `OBTConfirmationDialog.show` `await` helper and a destructive
  variant.
- `widgets/inputs/obt_amount_input.dart` — `OBTAmountInput`, the
  write-side dual of `formatInrFromPaise`: it converts rupee text and
  emits **integer paise** via `onChanged` (Invariant 1).
- `widgets/lists/obt_activity_row.dart` — `OBTActivityRow`, a single
  activity-feed row (icon + text + relative timestamp + optional
  amount).
- `widgets/nav/obt_bottom_nav.dart` — `OBTBottomNav`, the fixed five-tab
  bottom navigation bar (Home / Friends / Groups / Activity / Profile).
- `widgets/nav/obt_floating_action_button.dart` —
  `OBTFloatingActionButton`, the persistent Add-Expense FAB.

## Layout

```
core/
  result.dart
  validators.dart
  balances/
    net_balance.dart
  connectivity/
    connectivity_provider.dart
  formatters/
    inr_formatter.dart
  routing/
    notification_deep_links.dart
  services/
    image_picker_service.dart
  telemetry/
    event_id_hash.dart
  widgets/
    india_phone_input_formatter.dart
    dialogs/
      obt_confirmation_dialog.dart
    inputs/
      obt_amount_input.dart
    lists/
      obt_activity_row.dart
    nav/
      obt_bottom_nav.dart
      obt_floating_action_button.dart
```

## Invariants honoured

- **Invariant 1 (integer paise):** `formatInrFromPaise` is the only
  paise → INR conversion; `OBTAmountInput` is the only rupee → paise
  conversion. Both keep values as `int`.
- **Invariant 2 (`simplifiedBalances` read-only):** `netBalancePaise`
  reads the map and never writes it.
