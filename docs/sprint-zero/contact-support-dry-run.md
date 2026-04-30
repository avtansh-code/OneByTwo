# Contact Support — Handoff Dry-Run

Sprint Zero wiring verification (A6). Each section below is a real artefact
produced by the indicated agent, exercising the full handoff chain for the
"Contact Support" feature (FR-PR-05, FR-SH-03, FR-SH-04, ADR-0006).

---

## 1. Product Manager — User Story

### US-SUPPORT-01: Contact Support via Email from Profile Screen

**Story:**
As a registered user,
I want to tap "Contact Support" on the Profile screen and have my device's mail
client open with a pre-filled email containing my diagnostic details,
so that I can quickly report issues or ask questions without having to manually
look up the support address or type device information.

**Preconditions:**
- The user is authenticated and on the Profile screen.
- Firebase Remote Config has been fetched and contains the `support_email_address`
  key.
- The app has access to the device's app version, OS version, and device model.

**Acceptance Criteria:**

**Scenario 1 (happy path): Mail client opens with pre-filled diagnostic context**
> Given the user is on the Profile screen and the device has a configured mail
> client
> When the user taps the "Contact Support" action
> Then the device's default mail client opens with a `mailto:` URL where the "to"
> field is set to the support address from Firebase Remote Config, and the email
> body contains the user's `userId`, app version, OS version, and device model

**Scenario 2: Support email address is driven by Remote Config**
> Given the support email address in Firebase Remote Config is updated to a new
> value
> When the app fetches the latest Remote Config and the user taps "Contact Support"
> Then the `mailto:` URL uses the newly configured support address, requiring no
> app update

**Scenario 3: User can edit the email before sending**
> Given the mail client has opened with the pre-filled diagnostic body
> When the user modifies the subject, body, or recipients
> Then the mail client respects the edits and sends the user's modified version;
> the app does not override or restrict editing

**Scenario 4 (negative): No mail client configured on the device (FR-SH-04)**
> Given the user is on the Profile screen and the device has no mail client
> configured
> When the user taps the "Contact Support" action
> Then the app displays a fallback dialog showing the support email address (from
> Remote Config) with a "Copy" button, and tapping "Copy" copies the address to
> the device clipboard and confirms the action with a brief visual indicator
> (e.g., snackbar)

**Scenario 5 (negative): Remote Config fetch fails or key is missing**
> Given the app cannot reach Firebase Remote Config or the `support_email_address`
> key is absent
> When the user taps the "Contact Support" action
> Then the app uses a hardcoded default support email address and the flow proceeds
> as in Scenario 1 or Scenario 4 depending on mail client availability

**Definition of Done:**
- [ ] Code implementing FR-PR-05, FR-SH-03, and FR-SH-04 is merged to `main` via
      approved PR.
- [ ] Unit tests cover: `mailto:` URL construction with all diagnostic fields,
      Remote Config address retrieval, fallback to default address, and fallback
      dialog trigger when no mail client is present.
- [ ] Widget/integration tests verify the "Contact Support" tap target on the
      Profile screen and the fallback dialog flow.
- [ ] QA has verified the feature on at least one iOS and one Android device (per
      SRS section 10.3 device matrix), including the no-mail-client fallback path.
- [ ] Analytics event `support_email_opened` is logged with `method` parameter
      (`mailto` or `fallback_dialog`) for telemetry.
- [ ] No third-party helpdesk SDK is introduced (per ADR-0006).
- [ ] Documentation updated: README or in-app copy reflects the support channel.

**References:** FR-PR-05 (P0), FR-SH-03 (P0), FR-SH-04 (P1), ADR-0006.

---

## 2. Solution Architect — Technical Approach

The "Contact Support" feature (FR-PR-05, FR-SH-03, FR-SH-04) lives in
`lib/features/profile/` per the SRS section 13.1 feature-first layout and uses
the `url_launcher` package to open a `mailto:` URI whose recipient is the support
email address fetched at app start-up from the Firebase Remote Config key
`support_email_address` (a plain string parameter, e.g.
`avtanshgupta@One By Two.app`). The mailto body is assembled from four diagnostic
fields: `userId` from `FirebaseAuth.instance.currentUser!.uid`, app version and
build number from the `package_info_plus` package
(`PackageInfo.fromPlatform()`), and OS version plus device model from the
`device_info_plus` package (`DeviceInfoPlugin`), all interpolated into a
URI-encoded body string so the user can review and edit before sending. Before
calling `launchUrl`, the client calls `canLaunchUrl` against the composed
`mailto:` URI; if it returns `false` (no mail client configured), the app shows a
fallback `AlertDialog` presenting the support email address as selectable text
alongside a "Copy" button that writes the address to the clipboard via
`Clipboard.setData` and confirms with a brief snackbar — satisfying FR-SH-04.
The corresponding Riverpod provider and any helper logic live under
`lib/features/profile/application/` (service layer) and
`lib/features/profile/presentation/` (widget), with the Remote Config read
abstracted behind a provider in `lib/data/` so other features can also access
Remote Config values. No Firestore schema, security rule, or Cloud Function
changes are required for this feature.

---

## 3. QA Engineer — Test Cases

1. **Happy path: mail client opens with correct address and diagnostic body**
   - **Given** the user is logged in, a mail client is configured on the device,
     and Firebase Remote Config has been fetched successfully with a
     `support_email_address` value of `support@onebytwo.app`
   - **When** the user navigates to the Profile screen and taps the "Contact
     Support" button
   - **Then** the device's default mail client opens via a `mailto:` URL with the
     `To` field set to `support@onebytwo.app` and the email body contains
     pre-filled diagnostic text

2. **Verify diagnostic fields are all present in the pre-filled body**
   - **Given** the user is logged in with userId `uid_abc123`, the app version is
     `1.0.0`, the OS is `Android 14`, the device model is `Pixel 6`, and a mail
     client is configured on the device
   - **When** the user taps the "Contact Support" button on the Profile screen
   - **Then** the pre-filled email body contains all four diagnostic fields:
     `userId: uid_abc123`, `App Version: 1.0.0`, `OS: Android 14`, and
     `Device Model: Pixel 6`, each on its own line and clearly labelled

3. **Verify support address is sourced from Remote Config, not hardcoded**
   - **Given** Firebase Remote Config is configured with `support_email_address`
     set to `help-rotated@onebytwo.app` (a non-default value) and the user is
     logged in with a mail client configured
   - **When** the user taps the "Contact Support" button on the Profile screen
   - **Then** the `mailto:` URL uses `help-rotated@onebytwo.app` as the
     recipient address, confirming the value is read from Remote Config at
     runtime and not hardcoded in the client

4. **Negative case: no mail client configured — fallback dialog appears**
   - **Given** the user is logged in, Firebase Remote Config has a valid
     `support_email_address`, and **no** mail client is configured on the device
   - **When** the user taps the "Contact Support" button on the Profile screen
   - **Then** a fallback dialog is displayed containing the support email address
     in plain text and a "Copy" button; the device mail client is **not**
     launched and no unhandled error or crash occurs

5. **Negative case: fallback dialog "Copy" button copies the email to clipboard**
   - **Given** the fallback dialog is displayed showing the support email address
     `support@onebytwo.app` and a "Copy" button
   - **When** the user taps the "Copy" button
   - **Then** the string `support@onebytwo.app` is written to the system
     clipboard, a confirmation message (e.g., a snackbar reading "Email address
     copied") is shown to the user, and the clipboard contents can be pasted
     into another application

6. **Edge case: Remote Config fetch fails — graceful degradation**
   - **Given** the user is logged in and Firebase Remote Config fetch fails
     (e.g., due to network timeout or service unavailability)
   - **When** the user taps the "Contact Support" button on the Profile screen
   - **Then** the app does not crash or show an unhandled error; it uses the
     Remote Config default (compiled-in fallback) support email address in the
     `mailto:` URL or fallback dialog, and the diagnostic fields are still
     present and correct

7. **Accessibility: Contact Support button is accessible via screen readers**
   - **Given** the user has TalkBack (Android) or VoiceOver (iOS) enabled and is
     on the Profile screen
   - **When** the user navigates to the "Contact Support" button using the
     screen reader's swipe or focus gestures
   - **Then** the screen reader announces a meaningful label (e.g., "Contact
     Support, button"), the element is focusable and has a correct semantic
     role, and the user can activate it via the screen reader's activation
     gesture

---

## 4. DevOps Engineer — Remote Config Specification

### Parameter Key

```
support_email_address
```

Convention: `snake_case`, descriptive. Not a feature flag (which would use a
`feature_` prefix).

### Default Value

| Property | Value |
|---|---|
| **Remote Config server default** | `avtanshgupta@One By Two.app` |
| **In-app default (compiled into Flutter)** | `avtanshgupta@One By Two.app` |

The in-app default is required so the `mailto:` link still works if the device
has never fetched Remote Config (first launch offline, fetch failure, etc.). The
customer must supply the final address before GA per SRS section 3.5.

### GitHub Secrets Requirement

**No GitHub secret is required.** The support email address is not a credential
and is intentionally visible to end users. It is set directly in the Firebase
Console, not injected through CI/CD pipelines.

### Conditions / Targeting Rules

**None required for v1.0.** A single global default serves all users.

### Setup Steps

1. Open the Firebase Console and select the One By Two production project.
2. Navigate to **Engage > Remote Config**.
3. Click **"Add parameter"**.
4. Enter:
   - **Parameter key:** `support_email_address`
   - **Default value:** `avtanshgupta@One By Two.app`
   - **Description:** Support email address used in the Contact Support mailto
     link on the Profile screen. Change here to update across all clients
     without a release. See ADR-0006.
   - **Value type:** String
5. Leave **Conditions** empty.
6. Click **"Save"**, then **"Publish changes"**.

### Verification Checklist

- [ ] Parameter `support_email_address` exists in Remote Config with the correct
      default.
- [ ] The Flutter client declares a matching in-app default in its Remote Config
      initialisation.
- [ ] The fallback dialog (FR-SH-04) correctly displays the address when no mail
      client is available.
- [ ] No second Firebase project was introduced (Invariant 4 compliance).
- [ ] The email address value does not appear in any GitHub secret.
