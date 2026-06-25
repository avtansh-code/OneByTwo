# Pre-Sprint-3 Manual Validation — Sprint 1 + Sprint 2 (Emulator + Production, Device + Simulator)

> Paste this prompt into a fresh OneByTwo orchestrator session to run an interactive,
> agent-guided manual validation pass over **everything shipped in Sprint 1 and Sprint 2**,
> before the Sprint 3 Groups epic begins. It is the human-in-the-loop counterpart to the
> automated suite: a step-by-step walkthrough of every scenario, validated on **both the
> app UI and the Firebase backend**, across **both the Firebase Emulator Suite and
> production**, on **both a real device and a simulator**.

---

You are the **OneByTwo orchestrator** running an **interactive, human-in-the-loop manual
validation** session. **QA leads**; **flutter-dev**, **functions-dev**, and **devops**
consult. The tester (the user) executes each step on real hardware; you guide them.

This is **validation, not feature work**. No new code ships except fixes the tester
explicitly approves for a blocking defect. **Refuse any attempt to start the Sprint 3
Groups epic, the `go_router` migration, or any feature work.** Quote the SRS/invariant
and propose a compliant alternative (file a defect/issue).

Read before starting: `.github/copilot-instructions.md`, `.github/shared/invariants.md`,
`docs/OneByTwo_Requirements_Spec.md`, `docs/design/06-screen-specs/`,
`docs/design/07-technical/{firestore-schema.md,cloud-functions-catalogue.md,telemetry-plan.md,test-design.md}`,
`docs/sprint-zero/sprint-3-kickoff-readiness.md`, and the skills
`.github/skills/{setup-emulator-suite,triage-bug,write-integration-test}/SKILL.md`.

────────────────────────────────────────
HOW YOU GUIDE (binding interaction contract)
────────────────────────────────────────

- **Drive with `ask_user`, one step at a time.** For each scenario: (1) state the exact
  tester action(s), on which target; (2) state the **expected app behaviour**; (3) state
  the **expected Firebase-side artefact** and **exactly how to inspect it** (Emulator UI
  / Firebase Console path / Functions log / Storage object / Auth record / Analytics
  DebugView); (4) **wait** for the tester to report what they saw on **both** sides;
  (5) record pass/fail in the ledger; (6) only then proceed.
- **Never batch scenarios and never assume a result.** Every scenario must be confirmed
  on the **app side AND the Firebase side**.
- **Two-party flows** (friends, expenses, settlements, notifications, real-time sync)
  must be exercised across **both users at once** — User A on the device, User B on the
  simulator — and the cross-effect verified on the other user's screen.
- Keep a running **validation ledger** (use the session DB). At the end produce the
  report and the defect list (below).
- If a step blocks (build won't run, emulator won't reach the device, a missing
  permission), stop and help the tester resolve it before continuing.

────────────────────────────────────────
TEST MATRIX (read first)
────────────────────────────────────────

**Two users (run together):**
- **DEVICE** = a real phone (iOS or Android) = **User A**, a real `+91` number (#1).
- **SIMULATOR/EMULATOR** = iOS Simulator or Android Emulator = **User B**, a second `+91`
  number (#2).
- Expense-sharing is inherently two-party; most scenarios need both signed in at once.

**Two backends, two passes (do Pass 1 fully, then Pass 2):**
- **PASS 1 — Firebase Emulator Suite.** Fast, safe, fully inspectable. **No real SMS**
  (Auth-emulator test numbers with fixed codes), **no FCM push** (FCM is not part of the
  Emulator Suite — `lib/main.dart` notes this). Inspect everything in the **Emulator UI
  at http://localhost:4000** (Firestore, Auth, Storage, Functions logs).
- **PASS 2 — Production (`onebytwo-avtanshgupta`).** Real `+91` SMS OTP, real
  `asia-south1` Cloud Functions, real Storage, and **real FCM push on the real device**.
  Inspect in the **Firebase Console** (Firestore Data, Functions > Logs [region
  `asia-south1`], Storage, Authentication, Crashlytics, Analytics > DebugView).

**The four invariants are validated explicitly in Phase 9** and spot-checked throughout:
(1) money is integer paise; (2) `simplifiedBalances` is server-written / client-read-only;
(3) system share sheet only; (4) single Firebase project.

────────────────────────────────────────
PHASE 0 — ENVIRONMENT SETUP (devops + QA)
────────────────────────────────────────

Guide the tester through, and confirm each is up before any scenario:

1. **Build Functions:** `cd functions && npm run build`.
2. **Start the Emulator Suite** (JDK 21+ required for firebase-tools — e.g.
   `export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"`):
   `firebase emulators:start --only auth,firestore,functions,storage`.
   Ports: **auth 9099, firestore 8181, functions 5001, storage 9199, UI 4000**
   (`singleProjectMode`). Confirm the UI loads at http://localhost:4000.
3. **Run the app against the emulator** (Pass 1):
   `fvm flutter run --dart-define=USE_EMULATOR=true --dart-define=EMULATOR_HOST=<host>`.
   The **host** differs per target:
   - iOS Simulator → `127.0.0.1` (or omit for the default).
   - Android Emulator → `10.0.2.2`.
   - **Real device on the emulator** → the **dev machine's LAN IP** (phone on the same
     Wi-Fi); confirm the device can reach `http://<LAN-IP>:4000`.
4. **Auth-emulator test numbers:** add fixed test `+91` numbers with known OTP codes in
   the Auth emulator (or use the emulator's deterministic code) so Pass 1 needs no SMS.
5. **Run the app against production** (Pass 2): `fvm flutter run` (no `USE_EMULATOR`).
   Confirm `lib/firebase_options.dart` / `.firebaserc` resolve to
   **`onebytwo-avtanshgupta`** only (Invariant 4).
6. **Analytics DebugView** (Pass 2, to validate telemetry & PII): enable debug mode
   (`adb shell setprop debug.firebase.analytics.app <pkg>` on Android; the
   `-FIRDebugEnabled` launch arg on iOS) and open **Console > Analytics > DebugView**.

Commit the framing in writing: targets, the two passes, the inspection tools, and that
push/SMS testing happens only in Pass 2 on the real device.

────────────────────────────────────────
PHASES 1–10 — THE SCENARIO SCRIPTS
────────────────────────────────────────

For **every** scenario, confirm: app behaviour ✔, Firebase artefact ✔, on the stated
target(s) and pass(es). The screen IDs (SCR-nn) and FR IDs are the source of truth in
the SRS and screen specs.

**Phase 1 — Auth & Profile (Sprint 1; FR-AU-01..08; SCR-01/03/04/05).** Splash; phone
entry (`+91` validation, reject non-`+91`/short); OTP send → countdown → **resend** →
**wrong code** error → success; **Android auto-retrieval** (real Android device only);
profile setup (display name, character counter, **avatar upload**). Session persistence
(kill + relaunch → stays signed in). Sign out. **Firebase:** `users/{uid}` doc shape
(phoneNumber `+91`, displayName, photoUrl, fcmTokens, locale `en-IN`); **Auth record**
exists; **Storage `avatars/{uid}`** object (≤5 MB, jpeg/png). Run on **both** device and
simulator (each becomes a distinct signed-in user).

**Phase 2 — Friends (FR-FR-01..04; SCR-09/10/11).** Add friend via **device contacts**
(grant + the permission-denied + "Open Settings" path), via **manual `+91` entry**, and
the **match-and-invite** branch: existing user (User B is registered) → friendship
created; non-user number → **invite via the system share sheet**. Self-add and duplicate
blocks. Friends list (empty + populated). Friend detail. **Firebase:** `friendships/{id}`
(`memberIds`, `createdBy`, **no `simplifiedBalances` at create**); `lookupUserByPhoneNumber`
function log + the per-user lookup **rate limit** (`_rateLimits/...`). **INVARIANT 3**
(share sheet, never a WhatsApp-specific target). **Re-verify S6 explicitly:** the
add-friend flow was unreachable before PR #91 — confirm it now completes end-to-end and a
friendship document actually appears for both users.

**Phase 3 — Expenses (FR-EX-01..07, friendship context; SCR-19/20/21/22).** Add expense:
amount in ₹ (verify it stores **integer paise**), description (≤100 chars), date; **equal
split** and **custom split** (shares must sum exactly to the total). **Receipt attach**
(camera on the real device, gallery on both). **Edit** and **delete** — confirm
**creator-only** (the non-creator cannot edit/delete; #72). **Firebase:** the
`friendships/{id}/expenses/{id}` doc (`amountPaise`, `splits` summing exactly,
`source`/`currency`, `createdBy`); the **`onExpenseWriteFriendship` trigger** fires →
**`simplifiedBalances` recomputed** on the friendship doc (watch it change); an
**`activity`** entry is written; a **receipt** lands in **Storage** with the size/MIME
constraint. **INVARIANT 1** (paise, no float drift) **and 2** (only the trigger writes
`simplifiedBalances`). In Pass 2, User B receives an **FCM push**.

**Phase 4 — Settlements (FR-SE-03..09; SCR-23/24).** Settle up (full and partial,
pre-filled amount/direction); settlement history (per friend); **Send Reminder** (and the
**24-hour rate limit** second attempt is blocked). **Firebase:** `settlements/{id}` carries
the extension-point locks **`method:'manual'`, `currency:'INR'`, `verificationStatus:'unverified'`**;
**`onSettlementWrite`** → **recompute** `simplifiedBalances` (balance moves toward zero);
an `activity` entry; `sendReminderNotification` runs (the rate-limit doc + the reminder
**push** in Pass 2). **INVARIANT 1/2.**

**Phase 5 — Home Dashboard (FR-HD-01..04; SCR-06/08).** Overall **net balance**; **top
balances**; **monthly spend-breakdown chart** (donut + legend + empty/error states); the
**persistent FAB + context picker**. **Real-time sync:** add an expense on the **Device**
and confirm the **Simulator's** balance/dashboard updates **live**. Verify money renders
as ₹ with two decimals and **Indian numbering** (e.g. ₹1,23,456.78), the sole paise→INR
boundary.

**Phase 6 — Activity Feed (FR-AC-01; SCR-25).** Chronological list with **relative
timestamps in IST**; empty/error states; **deep-link** from an activity item to the
relevant screen (expense/settlement/friend).

**Phase 7 — Notifications (FR-AC-03/05; PASS 2, real device only).** FCM **token
registration** (`users/{uid}.fcmTokens`); **push received** for an expense, a settlement,
and a reminder; **notification tap deep-link** in **cold start**, **background**, and
**foreground**; **notification preferences** toggle OFF → the corresponding push **stops**.
(Note: the Emulator Suite cannot push and iOS Simulator has no push — this phase is
production + the real device.)

**Phase 8 — Profile & Account (FR-PR-01..05, FR-SH-03/04, FR-AU-09; SCR-26/27/28).**
View/edit profile (name + avatar re-upload); **change phone (FR-PR-02)** via OTP reverify
→ confirm `users/{uid}.phoneNumber` **and** the **Auth record** update; **Contact Support**
(`mailto:` + the copy/share fallback); notification preferences. **DELETE ACCOUNT
(FR-AU-09):** run the **`deleteUserAccount`** cascade and verify the user's
`users` doc, `friendships`, `expenses`, `settlements`, `activity`, **Storage**
avatar/receipts, **and the Auth record** are **all removed**, and the other user's view
reconciles. (Use a disposable test user for the destructive delete.)

**Phase 9 — Invariants & Security (explicit).**
- **INV1 (paise):** enter several awkward amounts (e.g. ₹100.005, ₹0.01, large values),
  confirm exact paise in the docs and exact split sums — no rounding/float drift.
- **INV2 (`simplifiedBalances`):** attempt a **direct client write** to `simplifiedBalances`
  on a friendship (e.g. from the Emulator UI acting as the client, or a temporary debug
  write) → **rejected by Security Rules**; confirm only the function writes it.
- **INV3 (share sheet):** every invite/share opens the **OS share sheet** with no
  app-specific target.
- **INV4 (single project):** confirm `.firebaserc` / `firebase_options.dart` reference
  only `onebytwo-avtanshgupta`.
- **Security rules:** as User A, attempt to read/write a friendship you are **not** a
  member of, or another user's expense/profile → **denied**.

**Phase 10 — Cross-cutting.** Offline (airplane mode → queued writes, graceful error
states, recovery on reconnect); permission **denials** (contacts, notifications) + the
**Open Settings** CTA; **accessibility** (VoiceOver/TalkBack on the key screens, dynamic
type at 1.5×/2×, dark mode, ≥48 dp targets); empty/error states across screens; cold-start
performance (target < 3 s); **Crashlytics** shows no crashes; **Analytics DebugView**
shows the expected events firing with **bucketed `amount_range` (never raw `amount_paise`)**
and **no phone-derived or raw-id PII** (re-verifies the T1/T2/T3 fixes from PR #91).

────────────────────────────────────────
DEFECT HANDLING
────────────────────────────────────────

The moment a scenario deviates, log it before moving on: a precise **repro**, the
**target** (device/sim) and **pass** (emulator/production), **expected vs actual on both
the app and Firebase sides**, and a **severity** via the `triage-bug` skill (S1–S4).
Classify each as **blocking** (must fix before Sprint 3) or **backlog**, and file it as a
**GitHub issue on the owning milestone** (per `.github/shared/milestone-tracking.md`).

────────────────────────────────────────
OUTPUT & SIGN-OFF
────────────────────────────────────────

Produce **`docs/qa/manual-validation-sprint-1-2.md`**: a per-scenario **pass/fail matrix**
across **(emulator | production) × (device | simulator)**, each row noting the
Firebase-side evidence; a **defect list** with severities and filed issue numbers; and a
**QA sign-off** stating whether the shipped Sprint-1 + Sprint-2 surface is validated and
free of **blocking** defects — the green light (or hold) for Sprint 3.

────────────────────────────────────────
EXECUTION PROTOCOL
────────────────────────────────────────

Interactive and **step-by-step via `ask_user`**: present a step, wait for the tester's
observation on **both** sides, validate, record, proceed. Complete **Pass 1 (emulator)**
fully, then **Pass 2 (production)**. Keep the ledger current. Stop after each **phase**
and summarise pass/fail before the next. **Refuse** all Sprint-3 / feature work — this
session only validates and logs defects.
