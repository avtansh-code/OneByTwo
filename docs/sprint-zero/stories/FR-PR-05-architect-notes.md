# FR-PR-05: Contact Support (mailto) — Architect Notes

> These notes supplement the FR-PR-05 user story with architectural decisions,
> contract definitions, and testing guidance for the Contact Support surface.
> This PR also bundles **FR-SH-04** (no-mail-client fallback dialog) — same
> service, natural completion (story points 2 -> 3). The primary technical
> reference is `docs/sprint-zero/contact-support-dry-run.md`; the decision is
> ratified in **ADR-0006**. The orchestrator will merge these notes into the
> canonical story file.
>
> **PR-slot note.** This is the roadmap "PR #59" slot, but the GitHub PR number
> will be **>= #60**: roadmap label #59 was consumed by a docs-reconciliation
> PR. Do not encode a specific GitHub PR number in canonical artefacts (this is
> also why the decision log is left untouched — see section 9).

---

## Architect Notes

### 0. Scope, pick confirmation, and what does NOT change

**Pick confirmed:** FR-PR-05 (Contact Support `mailto:` flow, P0) on branch
`feat/contact-support-mailto`, bundling FR-SH-03 (the `mailto:` action, P0) and
**FR-SH-04** (fallback dialog, P1). All three are satisfied by one client-side
service. No story refinement back to PM is required.

**This feature is 100% client-side plus one Remote Config parameter.** The
following are explicitly **unchanged** — do not touch them and do not request a
backend agent:

| Surface | Change? | Why |
|---|---|---|
| `firestore.rules` | None | No document reads/writes in this flow. |
| `storage.rules` | None | No Storage access. |
| `firestore.indexes.json` | None | No new queries. |
| `functions/**` (Cloud Functions) | None | No server logic; the support address is a Remote Config string, not a callable. |
| Firestore schema / data model | None | Nothing is persisted. |

`firebase_remote_config: ^6.4.0` is **already declared** in `pubspec.yaml`
(line 22, currently unused) — this PR is its first consumer. No new Firebase
service is introduced.

#### 0.1 Locked orchestrator decisions (confirmed — do not relitigate)

1. **Remote Config key = `support_email_address`** (authoritative — dry-run
   DevOps section + wireframe 4.1). It is **not** `support_email`.
2. **In-app compiled default = `support@onebytwo.app`.** This is also the
   intended Remote Config **server** default. See the typo flag in section 9.
3. **FR-SH-04 is bundled into this PR.**
4. **Telemetry:** emit `support_email_opened` with a single `method` parameter
   (`mailto` on the happy path, `fallback_dialog` on the FR-SH-04 path). The
   payload carries **no PII** — see section 5.

---

### 1. Decision A — Diagnostic source plugins (CONFIRMED)

**Decision: add both `package_info_plus` and `device_info_plus`.** This
ratifies the dry-run architect approach and is required by QA test case 2.

Rationale (one sentence): `dart:io`'s `Platform` cannot supply the marketing
**device model** (`Platform.operatingSystemVersion` returns an opaque kernel
string, and there is no app-version API at all), so the QA case 2 fidelity
requirement "`Device Model: Pixel 6`" and the "App Version" line can only be met
with the two plugins.

**Field mapping (the only diagnostic source of truth):**

| Body field | Plugin | API | Android value | iOS value |
|---|---|---|---|---|
| App version | `package_info_plus` | `PackageInfo.fromPlatform().version` | `1.0.0` | `1.0.0` |
| Build number | `package_info_plus` | `PackageInfo.fromPlatform().buildNumber` | `1` | `1` |
| OS name | (constant) | — | `Android` | `iOS` |
| OS version | `device_info_plus` | Android `version.release` / iOS `systemVersion` | `14` | `17.4` |
| Device model | `device_info_plus` | Android `model` / iOS `utsname.machine` | `Pixel 6` | `iPhone15,3` |

iOS note: use `utsname.machine` (precise hardware id, e.g. `iPhone15,3`) for the
device-model line. `iosInfo.model` returns the generic `"iPhone"` and is not
useful for triage. Mapping `iPhone15,3` -> `"iPhone 15 Pro"` needs a lookup
table and is **out of scope** for v1.0.

#### 1.1 iOS pod consequence (MANDATORY for the implementing PR)

Adding `url_launcher` + `package_info_plus` + `device_info_plus` introduces
three new iOS plugin pods, changing the CocoaPods dependency graph. The
implementing PR **must**:

1. Run `cd ios && pod install --repo-update`, and
2. **Commit the regenerated `ios/Podfile.lock` in the same PR.**

The CI "Build iOS (no signing)" job runs `flutter build ios --no-codesign`
(`.github/workflows/pr.yml:309`), which performs a vanilla, non-`--repo-update`
`pod install` against the committed `Podfile.lock`. If the lock is stale (does
not contain the three new pods) the iOS build fails. This is the same failure
mode observed in the PR #55 lineage. Flutter Dev owns `ios/`; the Architect
flags it here.

#### 1.2 Android manifest consequence (MANDATORY — otherwise the happy path never fires)

`android/app/src/main/AndroidManifest.xml` currently declares a `<queries>`
block for `PROCESS_TEXT` **only**. On Android 11+ (API 30+) package-visibility
rules mean `canLaunchUrl(Uri(scheme: 'mailto', ...))` returns **`false` even
when a mail app is installed** unless a matching `<queries>` intent is declared.
Without it, every Android 11+ user is wrongly routed to the FR-SH-04 fallback
dialog. Flutter Dev **must** add, inside the existing `<queries>` element:

```xml
<intent>
    <action android:name="android.intent.action.SENDTO" />
    <data android:scheme="mailto" />
</intent>
```

iOS needs **no** `Info.plist` change: `mailto:` is a system scheme, so
`canLaunchUrl` resolves it without an `LSApplicationQueriesSchemes` entry.

**(`dart:io` was rejected** — it cannot satisfy QA case 2; the plugin route is
the only compliant option.)

---

### 2. Decision B — Remote Config: timing, placement, read-with-default (DECIDED)

#### 2.1 Fetch / activate timing — non-blocking at app start

In `lib/main.dart`, after `Firebase.initializeApp()` and before `runApp`, the
implementing PR initialises a `RemoteConfigService` whose `initialise()`:

1. `await setConfigSettings(...)` — `fetchTimeout: 10s`; `minimumFetchInterval`
   may stay at the SDK default (12 h) or be set to ~1 h (the address rarely
   changes; not critical for v1.0).
2. `await setDefaults({'support_email_address': 'support@onebytwo.app'})` —
   local and fast, so the in-app default is immediately readable.
3. `unawaited(fetchAndActivate())` — **fire-and-forget; do NOT await.** The
   first frame must not block on a network fetch.

The read path (`getString('support_email_address')`) therefore returns the
compiled-in default immediately on a cold/offline first launch, and silently
upgrades to the server value once the background fetch activates. This covers
dry-run Scenario 5 and wireframe 4.2 with **no user-facing error UI**.

#### 2.2 Placement — `lib/core/remote_config/` (cross-feature)

The Remote Config abstraction lives in **`lib/core/remote_config/`**, not under
`lib/features/profile/`.

Rationale: ADR-0006 frames Remote Config as the app's feature-flag and remote
configuration mechanism, and the v1.1 extension IA-EXT-05 already anticipates a
second key (`support_helpdesk_url`). It is a genuine cross-feature concern, so
colocating it under `profile/` would force unrelated features to reach into the
profile feature. `lib/data/README.md` says prefer feature-first "until a
genuine cross-feature concern emerges" — Remote Config qualifies. The placement
mirrors the established `lib/core/` precedent for cross-cutting plugin wrappers
(`lib/core/connectivity/connectivity_provider.dart`,
`lib/core/services/image_picker_service.dart`). The read-with-in-app-default
pattern established here is what the ADR-0006 feature-flag work will reuse.

#### 2.3 Missing-key guard

`FirebaseRemoteConfig.getString` returns `''` for an unknown key. Because we
call `setDefaults`, a present-but-unfetched key already returns the default; to
also cover a genuinely empty/missing remote value, the read must guard:

> if `getString(key)` is empty, fall back to the compiled-in
> `RemoteConfigDefaults.supportEmailAddress`.

This double-guard satisfies Scenario 5 ("fetch fails OR key is absent")
deterministically.

---

### 3. Decision C — Error-state "Still stuck? Contact Support" link (DECIDED: WIRE IT)

**Decision: wire the existing error-state link in this PR.**

`profile_screen.dart` lines ~157-170 contain a second Contact Support entry
point (the "Still stuck? Contact Support" link in the profile error state) that
today shows the same `'Coming soon'` snackbar. It reuses the exact same
controller and service introduced for the row at lines ~337-353.

Rationale: near-zero marginal cost (one `onTap` swap), removes a second
`'Coming soon'` stub on the same surface, and satisfies the error taxonomy /
SRS section 6.4 requirement for a "path to Contact Support" from error states
(`docs/design/07-technical/error-and-empty-state-taxonomy.md`, and wireframe
1.3 which states the error-state link "triggers the same Contact Support flow
described in section 4"). Both entry points invoke
`contactSupportControllerProvider`; `currentUserIdProvider` is bound by the
authenticated shell that hosts both, so the dependency resolves in the error
state too (see section 7.3).

---

### 4. Decision D — `mailto` template and percent-encoding (DECIDED — canonical contract)

This template **becomes the contract for all future support entry points**
(e.g. the delete-account error snackbar and settlement error states that route
to Contact Support per the wireframes). Be exact.

#### 4.1 Subject and body

Subject (literal): `One By Two Support Request`

Body (literal, with real newlines; `{...}` are runtime substitutions):

```
Hi One By Two team,



--- Diagnostic Info (do not delete) ---
User ID: {userId}
App Version: {appVersion} ({buildNumber})
OS: {osName} {osVersion}
Device Model: {deviceModel}
---
```

The blank lines after the greeting give the user space to type above the
diagnostic block. Each diagnostic field is clearly labelled on its own line,
inside a "do not delete" block, per wireframe 4.1 and FR-PR-05.

**Label reconciliation (this template is authoritative).** Two illustrative
labels in upstream artefacts differ from this canonical template; align test
assertions and copy to the labels above:

- Wireframe 4.1 shows `Device: {deviceModel}` -> canonical is
  **`Device Model:`** (more explicit; matches the QA intent).
- Dry-run QA case 2 shows `userId: uid_abc123` -> canonical is **`User ID:`**
  (proper sentence case, matches the wireframe copy). The QA `App Version: 1.0.0`
  substring still holds because `App Version: 1.0.0 (1)` contains it.

#### 4.2 Encoding — `Uri(scheme:, path:, query:)` with `Uri.encodeComponent`

**Build the URI like this (illustrative contract, not final code):**

```dart
final uri = Uri(
  scheme: 'mailto',
  path: supportEmailAddress, // e.g. support@onebytwo.app — '@' is path-legal
  query: <String>[
    'subject=${Uri.encodeComponent(subject)}',
    'body=${Uri.encodeComponent(body)}',
  ].join('&'),
);
```

**Why this exact approach (and why the obvious alternatives are wrong):**

- **Do NOT use `queryParameters: {...}`.** Dart's `queryParameters` map applies
  `application/x-www-form-urlencoded` encoding, which renders spaces as `+`.
  Several mail clients (Apple Mail, some Gmail builds) display the literal `+`
  in the body, corrupting the diagnostic text.
- **Do NOT use `Uri.encodeQueryComponent`** for the same reason — it also emits
  `+` for spaces by default.
- **`Uri.encodeComponent`** encodes space as `%20`, newline as `%0A`, and also
  escapes `&` (`%26`) and `=` (`%3D`) inside each value, so a body containing
  those characters cannot break out of its query parameter.
- Passing the already-encoded string through the **`query:`** named parameter
  (not `queryParameters:`) is safe: Dart's query normaliser preserves existing
  `%XX` escapes (it does not re-encode `%20`/`%0A` into `+`), and `@` in the
  `path` is left intact.

**Worked example** (address `support@onebytwo.app`) produces:

```
mailto:support@onebytwo.app?subject=One%20By%20Two%20Support%20Request&body=Hi%20One%20By%20Two%20team%2C%0A%0A%0A%0A---%20Diagnostic%20Info%20(do%20not%20delete)%20---%0AUser%20ID%3A%20...
```

#### 4.3 Launch and fallback decision

- Gate on `canLaunchUrl(uri)` (matches wireframe 4.1 flow and QA case 4). If
  `true`, call `launchUrl(uri, mode: LaunchMode.externalApplication)`.
- **Defensively** wrap `launchUrl` in try/catch and treat a `false` return or a
  thrown `PlatformException` as the fallback path too, so a `canLaunchUrl`
  false-positive never crashes the app.
- Any path that does not open the mail client -> show the FR-SH-04 fallback
  dialog (section 7.4).

---

### 5. Telemetry contract — `support_email_opened` (no PII, no hashing)

Create a constants holder mirroring
`lib/features/settlements/application/settlement_history_telemetry.dart`:

`lib/features/profile/application/contact_support_telemetry.dart`

```dart
abstract final class ContactSupportTelemetry {
  static const String supportEmailOpenedEvent = 'support_email_opened';
  static const String paramMethod = 'method';
  static const String methodMailto = 'mailto';
  static const String methodFallbackDialog = 'fallback_dialog';
}
```

- **Single parameter `method`** with value `mailto` (happy path) or
  `fallback_dialog` (FR-SH-04 path). Matches wireframe 4a/4b and SRS section
  5.10 (`support_email_opened` is a named v1.0 funnel).
- **Fire from the controller** (one place, fully unit-testable without a
  `BuildContext`): `mailto` after a successful launch; `fallback_dialog` when
  the controller returns the fallback result (the UI shows the dialog
  immediately, so "fallback determined" == "dialog shown"). The "Copy" button
  has **no** analytics event (none is specified).
- **No PII, no hashing.** The only parameter is the safe enum token `method`.
  The `userId`, the email address, and any device identifier are **never** put
  into analytics parameters. `lib/core/telemetry/event_id_hash.dart` (`hashId`)
  is **not needed here** — there are no identifiers in the payload to hash.
- **Channel distinction:** the `userId` and device details appear **only** in
  the user-visible `mailto` body, which the user reviews and consents to send
  to support (a user-controlled diagnostic channel) — this is categorically
  different from telemetry and does not violate the no-PII-in-analytics rule.

---

### 6. Invariant 3 clarification — `mailto` is compliant; do not route via the share sheet

Invariant 3 ("system share sheet only; the app must not target or import
packages for any specific messaging app") governs **outbound sharing** (friend
invites, group invites, "share my balance" — FR-SH-01). Contact Support is
**not** sharing.

- A `mailto:` URI opens the device's **default mail client** and targets **no
  specific app** — the OS resolves the user's chosen mail handler. This is
  exactly what FR-SH-03 mandates and is fully consistent with the spirit of
  Invariant 3 (no app-specific targeting).
- **Do NOT** route Contact Support through `ShareService` / `share_plus`
  (`lib/features/friends/data/share_service.dart`) — that is the FR-SH-01
  share-sheet path and is the wrong mechanism here.
- **Do NOT** add any app-specific or vendor mail SDK (no Gmail/Outlook SDK, no
  helpdesk SDK — also per ADR-0006).
- The mechanism is `url_launcher`'s `launchUrl(uri, mode:
  LaunchMode.externalApplication)`.

---

### 7. Flutter Dev contract — providers, services, and files

All abstractions follow the established **abstract-class + Riverpod provider**
testability pattern — mirror `lib/features/friends/data/share_service.dart`
(`ShareServiceBase` -> `ShareService` -> `shareServiceProvider`) and
`lib/features/auth/application/analytics_provider.dart`
(`AnalyticsService` -> `FirebaseAnalyticsService` -> `analyticsServiceProvider`).

#### 7.1 Files to create

| File | Layer | Responsibility | Precedent |
|---|---|---|---|
| `lib/core/remote_config/remote_config_service.dart` | core | `abstract RemoteConfigService` + `FirebaseRemoteConfigService` + `remoteConfigServiceProvider`. `initialise()` (defaults + non-blocking fetch) and guarded `getString`. | `lib/core/connectivity/connectivity_provider.dart` |
| `lib/core/remote_config/remote_config_keys.dart` | core | `RemoteConfigKeys.supportEmailAddress = 'support_email_address'`; `RemoteConfigDefaults.supportEmailAddress = 'support@onebytwo.app'` and the defaults map. | — |
| `lib/core/services/url_launcher_service.dart` | core | `abstract UrlLauncherService { Future<bool> canLaunch(Uri); Future<bool> launchExternal(Uri); }` + impl wrapping `url_launcher` (`LaunchMode.externalApplication`) + provider. | `lib/core/services/image_picker_service.dart` |
| `lib/features/profile/domain/support_diagnostics.dart` | profile/domain | Immutable value object: `appVersion`, `buildNumber`, `osName`, `osVersion`, `deviceModel`. | — |
| `lib/features/profile/data/device_diagnostics_service.dart` | profile/data | `abstract DeviceDiagnosticsService { Future<SupportDiagnostics> load(); }` + impl wrapping `package_info_plus` + `device_info_plus` + provider. | `lib/features/friends/data/share_service.dart` |
| `lib/features/profile/application/contact_support_controller.dart` | profile/application | Orchestrates: gather diagnostics, read `userId` + support address, build the `mailto` URI, launch-or-fallback, fire telemetry. Exposes `contactSupportControllerProvider`. | `lib/features/settlements/application/settle_up_controller.dart` |
| `lib/features/profile/application/contact_support_telemetry.dart` | profile/application | Telemetry constants (section 5). | `.../settlement_history_telemetry.dart` |
| `lib/features/profile/presentation/contact_support_fallback_dialog.dart` | profile/presentation | FR-SH-04 dialog (section 7.4). | wireframe 4b |

`DeviceDiagnosticsService` and `SupportDiagnostics` stay feature-local (the value
object is shaped for the support body, and no other feature needs device info
yet — feature-first per `lib/data/README.md`), whereas `RemoteConfigService` and
`UrlLauncherService` are generic, cross-feature plugin wrappers and so live in
`lib/core/`.

#### 7.2 Controller contract

```dart
// Illustrative contract — not final code.

/// Result of a Contact Support attempt.
sealed class ContactSupportResult {}
class ContactSupportLaunched extends ContactSupportResult {}        // mail client opened
class ContactSupportFallbackRequired extends ContactSupportResult { // FR-SH-04
  ContactSupportFallbackRequired(this.supportEmailAddress);
  final String supportEmailAddress;
}

class ContactSupportController {
  ContactSupportController({
    required RemoteConfigService remoteConfig,
    required DeviceDiagnosticsService diagnostics,
    required UrlLauncherService launcher,
    required AnalyticsService analytics,
    required String userId,
  });

  /// Builds the mailto URI, launches the default mail client, and fires
  /// `support_email_opened`. Returns [ContactSupportFallbackRequired] when no
  /// mail client is available so the caller can show the FR-SH-04 dialog.
  Future<ContactSupportResult> contactSupport();
}

final contactSupportControllerProvider = Provider<ContactSupportController>((ref) {
  return ContactSupportController(
    remoteConfig: ref.watch(remoteConfigServiceProvider),
    diagnostics: ref.watch(deviceDiagnosticsServiceProvider),
    launcher: ref.watch(urlLauncherServiceProvider),
    analytics: ref.watch(analyticsServiceProvider),
    userId: ref.watch(currentUserIdProvider),
  );
});
```

The controller fires telemetry; the widget only invokes the controller and, on
`ContactSupportFallbackRequired`, shows the dialog. This keeps all branching
unit-testable with no widget tree.

#### 7.3 `userId` source

Read `userId` from **`currentUserIdProvider`**
(`lib/features/friends/application/friends_list_provider.dart`), not directly
from `FirebaseAuth.instance.currentUser!.uid` as the dry-run sketch suggested.
Same value, but injectable and testable, and it is the established codebase
idiom (activity feed, friends list, settle-up). The authenticated shell binds
this provider for its whole subtree (`lib/main.dart:141-144`), so it resolves
on the Profile screen for **both** the row and the error-state link. Tests
override `currentUserIdProvider` directly.

#### 7.4 FR-SH-04 fallback dialog contract

Implement per wireframe 4b (`docs/design/04-wireframes/profile-and-support.md`).
Use the design-system dialog/snackbar if present (`OBTConfirmationDialog`
adapted, `OBTSnackbar`); otherwise a standard `AlertDialog` + `ScaffoldMessenger`
`SnackBar` satisfying the same contract:

- Title: "No Mail App Found". Body: explanatory line + the support address as
  **selectable** text (`bodyLarge`, `primary`).
- Actions: "Close" (outlined, dismiss) and "Copy Address" (filled). "Copy
  Address" writes the address via `Clipboard.setData(ClipboardData(text:
  address))`, dismisses the dialog, then shows a snackbar reading **"Email
  address copied"** (4000 ms).
- Accessibility labels exactly per wireframe 4.4: dialog `"Alert: No Mail App
  Found"`; address `"Support email address: [address]"`; buttons
  `"Copy Address, button"` and `"Close, button"`.
- The address shown is the same value the controller resolved (Remote Config
  with compiled-in-default guard) — pass it through `ContactSupportFallbackRequired`.

#### 7.5 Existing widgets and labels to PRESERVE (do not regress)

- **Row (lines ~337-353):** keep the `Semantics(button: true, label:
  'Contact Support, button', child: _ProfileRow(icon: Icons.mail, label:
  'Contact Support', trailing: <chevron>))`. Change **only** the `onTap` — from
  the `'Coming soon'` snackbar to invoking `contactSupportControllerProvider`.
  The `'Contact Support, button'` semantics label (line 339-342) is asserted by
  QA case 7 and must remain verbatim.
- **Error-state link (lines ~157-170):** keep the `GestureDetector` + underlined
  "Still stuck? Contact Support" `Text`. Change **only** the `onTap` to invoke
  the same controller (Decision C).
- Reuse the existing `_ProfileRow` widget; do not introduce a parallel row.

#### 7.6 `main.dart` wiring (Flutter Dev — illustrative)

```dart
final remoteConfig = FirebaseRemoteConfigService(FirebaseRemoteConfig.instance);
await remoteConfig.initialise(); // awaits setDefaults; fetchAndActivate is unawaited inside

runApp(
  ProviderScope(
    overrides: [
      // ...existing overrides...
      remoteConfigServiceProvider.overrideWithValue(remoteConfig),
    ],
    child: const OneBytwoApp(),
  ),
);
```

---

### 8. Flutter Dev handoff checklist

- [ ] Add `url_launcher`, `package_info_plus`, `device_info_plus` to
      `pubspec.yaml` (latest stable). `firebase_remote_config` already present.
- [ ] `cd ios && pod install --repo-update` and **commit `ios/Podfile.lock`**
      (section 1.1).
- [ ] Add the `mailto` `<queries>` intent to `AndroidManifest.xml`
      (section 1.2) — without it the happy path never fires on Android 11+.
- [ ] Create the eight files in section 7.1 following the abstract-class +
      provider pattern.
- [ ] Wire `RemoteConfigService.initialise()` + provider override in
      `main.dart` (section 7.6); `fetchAndActivate` non-blocking.
- [ ] Build the `mailto` URI exactly per section 4.2 (`Uri(scheme:, path:,
      query:)` + `Uri.encodeComponent`; never `queryParameters` /
      `encodeQueryComponent`).
- [ ] Use the canonical subject/body labels from section 4.1
      (`User ID:`, `App Version: x (y)`, `OS:`, `Device Model:`).
- [ ] Swap both `onTap`s (row + error-state link) to the controller; preserve
      the `'Contact Support, button'` semantics label and existing widgets.
- [ ] Implement the FR-SH-04 fallback dialog per section 7.4.
- [ ] Fire `support_email_opened` (`method: mailto` / `fallback_dialog`) from
      the controller; assert **no PII** in any parameter.
- [ ] Tests per section 10; meet the >= 70% per-folder coverage floor for new
      `lib/core/remote_config/`, `lib/core/services/` (delta), and
      `lib/features/profile/` code.

---

### 9. DevOps flag — `support_email_address` Remote Config parameter

The Remote Config parameter is DevOps-owned (Firebase Console; no CI secret, no
conditions). Set up per dry-run section 4 **with one correction**:

> **Typo correction (action required).** The dry-run DevOps section prints the
> default value as `avtanshgupta@One By Two.app`. That is a malformed
> product-name search-replace artefact — an email address cannot contain
> spaces. The ratified value, matching the wireframe fallback dialog and all QA
> cases, is **`support@onebytwo.app`** for **both** the in-app compiled default
> and the Remote Config **server** default. DevOps must set
> `support@onebytwo.app` in the Console (not the malformed string), and the
> dry-run document should be corrected.

- Key: `support_email_address` (String). Default: `support@onebytwo.app`.
- No GitHub secret (the address is intentionally user-visible, not a credential).
- No conditions / targeting for v1.0 (single global default).
- The customer must supply the final GA support address before launch
  (SRS section 3.5); rotating it later needs **no** client release (ADR-0006).
- Invariant 4 holds: no second Firebase project is introduced.

---

### 10. Testing guidance

- **Unit (controller / services):**
  - `mailto` URI construction: all five diagnostic lines present and correctly
    labelled; spaces -> `%20`, newlines -> `%0A` (assert the encoded string has
    no `+`); subject correct.
  - Remote Config: returns the server value when activated; returns the
    compiled-in default when `getString` is empty (Scenario 5 / case 6).
  - Address sourced from Remote Config, not hardcoded (case 3) — override the
    fake `RemoteConfigService` and assert the URI recipient changes.
  - Fallback decision: `canLaunch == false` (and the launch-throws path) ->
    `ContactSupportFallbackRequired` with the resolved address; happy path ->
    `ContactSupportLaunched` (cases 1, 2, 4).
  - Telemetry: `support_email_opened` fired with `method: mailto` /
    `fallback_dialog`; assert **no** parameter contains the `userId`, the email
    address, or a device id (mirror the friends PII-leak test posture).
- **Widget:**
  - Tapping the row invokes the controller; the `'Contact Support, button'`
    semantics label is present (case 7).
  - Fallback dialog renders address + "Copy Address"/"Close"; "Copy Address"
    writes to the clipboard and shows the "Email address copied" snackbar
    (cases 4, 5).
  - Error-state link invokes the same controller (Decision C).
- **Test seams:** override `remoteConfigServiceProvider`,
  `deviceDiagnosticsServiceProvider`, `urlLauncherServiceProvider`,
  `analyticsServiceProvider`, and `currentUserIdProvider` with fakes — no
  Firebase or platform plugin is touched in unit/widget tests.
- **Manual device verification (QA):** real iOS + Android devices including the
  no-mail-client path (per dry-run Definition of Done and SRS section 10.3).

---

### 11. Cross-references

| Artefact | Location |
|---|---|
| ADR-0006 (mailto + Remote Config) | `.github/shared/decision-log.md` |
| Handoff dry-run (primary reference) | `docs/sprint-zero/contact-support-dry-run.md` |
| Wireframe — Contact Support flow (section 4) | `docs/design/04-wireframes/profile-and-support.md` |
| Error/empty-state taxonomy (section 6.4 path) | `docs/design/07-technical/error-and-empty-state-taxonomy.md` |
| SRS FR-PR-05 / FR-SH-03 / FR-SH-04 | `docs/OneByTwo_Requirements_Spec.md` (lines 178, 272, 273) |
| `support_email_opened` funnel | `docs/OneByTwo_Requirements_Spec.md` section 5.10 |
| Abstract-class + provider pattern | `lib/features/friends/data/share_service.dart`, `lib/features/auth/application/analytics_provider.dart` |
| `lib/core/` plugin-wrapper precedent | `lib/core/services/image_picker_service.dart`, `lib/core/connectivity/connectivity_provider.dart` |
| Telemetry-constants precedent | `lib/features/settlements/application/settlement_history_telemetry.dart` |
| PII-hash helper (NOT needed here) | `lib/core/telemetry/event_id_hash.dart` |
| Current stub to replace | `lib/features/profile/presentation/profile_screen.dart` (rows ~157-170 and ~337-353) |
