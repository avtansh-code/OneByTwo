# Sprint 3 Plan

> **Sprint theme:** Design Conversion (Haldi visual system). **Status:** Planned.
> This plan executes the Design Conversion planning pack
> (`docs/audits/design-conversion/`) and ADR-0024. It migrates the already-built
> app and the shared component library onto the **"Direction A — Haldi"** visual
> system (`design_handoff_one_by_two/`). The migration is **visual/UX only**: it
> changes no data model, Firestore security rule, simplified-debts algorithm, or
> Cloud Function. The four invariants are re-affirmed, never weakened. This planning
> document touches no `lib/**` file; the first conversion PR (PR #1, the design-token
> foundation) is the next session.

---

## Sprint Goal

Migrate the built Flutter client and the shared component library onto the Haldi
visual system (`design_handoff_one_by_two/`, ADR-0024): land the token + type
foundation (`lib/app/theme.dart` → Haldi marigold palette with an ink `onPrimary`,
Bricolage Grotesque + Hanken Grotesk), reskin the six `OBT*` shared widgets and build
the new Haldi components in all states, convert every built flow (Auth, Home,
Friends, Expenses, Settlements, Activity, Profile) to its Haldi target, deliver
dark-mode parity for every converted hero screen, re-verify accessibility against the
new palette, and stand up a visual-regression / golden-test harness so the conversion
is provable and non-regressing — with **zero change** to the data model, security
rules, the simplified-debts algorithm, or Cloud Functions.

---

## Definition of Ready (applies to every DC story)

A DC story may be started only when:

1. **Foundation merged.** For every story except DC-01, the token + type foundation
   (DC-01, PR #1) is merged to `main`. Converting a screen before the foundation
   exists would hard-code Haldi hex (token drift) or render Haldi layouts in the old
   Indigo/Plus-Jakarta skin (an un-reviewable mixed state) — see
   `docs/audits/design-conversion/03-foundation-plan.md` §0.
2. **Haldi target exists.** The screen or component has a Haldi design to convert *to*
   (per `docs/audits/design-conversion/02-conversion-checklist.md`). Every built
   screen now has a Haldi target — the change-phone flow (FR-PR-02) was designed as
   Haldi **Phase3g** on 2026-06-25 (see DC-10), closing the last gap.
3. **Acceptance criteria agreed.** At least three Given/When/Then criteria, including
   at least one negative case, are written and reviewed.
4. **Invariant check done.** The story is confirmed not to weaken any of the four
   invariants (`.github/shared/invariants.md`).
5. **Golden baseline available.** The light + dark golden baseline (or an explicit
   "new baseline" note) is available from the harness scaffold (DC-13).

## Definition of Done (applies to every DC story)

Matching `.github/ISSUE_TEMPLATE/user_story.md`, plus conversion-specific gates:

- [ ] Code merged to `main` via approved PR.
- [ ] Unit and widget tests written and passing in CI.
- [ ] QA reviewed and verified (light **and** dark where the surface is a hero).
- [ ] Telemetry / analytics events in place — for a visual conversion this means
      **existing events are preserved** (no renames, no removals); any genuinely new
      state emits an event only if `docs/design/07-technical/telemetry-plan.md`
      already defines one.
- [ ] Documentation updated if applicable (conversion checklist row marked done; ADR
      cross-reference where a decision was taken).
- [ ] **Golden / visual-regression** light + dark goldens updated and passing
      (DC-13 harness).
- [ ] **Contrast + dynamic-type** gates pass against the verified Haldi pairings
      (DC-12).
- [ ] **No backend contract changed** — no data path, provider contract, repository,
      Firestore read/write, Cloud Function call, or domain model touched
      (`docs/audits/design-conversion/02-conversion-checklist.md` §E).
- [ ] **No invariant weakened** — integer paise, `simplifiedBalances` read-only,
      OS share sheet, single Firebase project (Emulator Suite for pre-merge testing).

---

## Selected Stories

### Epic A — Token + Type Foundation

#### DC-01: Design-token and type foundation (`theme.dart` → Haldi) — PR #1

- **SRS / Source:** ADR-0024; `docs/audits/design-conversion/03-foundation-plan.md`
  §1–§3.
- **Priority:** P0 — Must have (blocking; the critical path for the whole sprint).
- **User Story:** As the Flutter team, I want `lib/app/theme.dart` migrated to the
  Haldi token and type system so that every screen reskin and new component can
  consume a single, correct source of truth instead of hard-coding hex or rendering
  in the old skin.
- **Preconditions:** ADR-0024 accepted; `google_fonts` confirmed to expose
  `bricolageGrotesque` and `hankenGrotesk` (else bundle the `.ttf` fallback per the
  foundation plan §3.1).
- **Acceptance Criteria:**
  1. **Given** PR #1 is merged, **When** the app builds, **Then**
     `ColorScheme.primary` is marigold `#E0922E` (dark `#EAA24A`),
     `ColorScheme.onPrimary` is the warm **ink `#2A211B`** (dark `#1A1510`), and the
     amount slots render in **Bricolage Grotesque with tabular figures** while body
     and UI text render in **Hanken Grotesk**, per the slot map in
     `03-foundation-plan.md` §1.1 and §3.3.
  2. **Given** the `OBTColors` theme extension is registered on both themes,
     **When** a widget reads `balanceZero`, `warning`, `primaryPressed`,
     `textTertiary`, `link`, or a category hue, **Then** the documented light + dark
     hex values are returned, and the named radius scale
     (`radiusChipInput 12`, `radiusButton 16`, `radiusCard 20`, `radiusPill 18`,
     `radiusSheet 28`, `radiusFull 999`) and the soft-warm shadow model are available.
  3. **Given** any primary affordance (FAB glyph, primary-button label, icon on a
     marigold fill), **When** it is rendered, **Then** its foreground is **ink, never
     white** (negative case — white on marigold measures ≈ 2.5:1 and fails WCAG 2.1
     AA; a white-on-marigold pairing must fail the contrast gate).
  4. **Given** amounts are restyled via the shared `OBTText.amount` /
     `OBTText.amountHero` helper, **When** any amount is displayed, **Then** it is
     still produced **only** by `formatInrFromPaise()` and no `paise / 100`
     arithmetic is introduced anywhere (Invariant 1).
- **Definition of Done:** the standard checklist, plus: the constant-by-constant
  colour map, the typeface swap, and the radius/shadow/motion tokens land in one PR;
  the six `OBT*` reskins may ride in this PR or its immediate follow-up (DC-02); no
  screen is converted in this PR.
- **Invariant Compliance:** Integer-paise rendering is unchanged — `OBTAmountInput`'s
  paise logic and the `formatInrFromPaise()` boundary are untouched (Invariant 1).
  No widget reads or writes `simplifiedBalances` here (Invariant 2). No share path or
  Firebase project surface is touched (Invariants 3, 4).
- **Responsible Agents:** Flutter Dev (implements), Architect (token/slot fidelity
  review), QA (contrast / dynamic-type / golden gates).
- **Story Points:** 8

---

### Epic B — Shared Component Library

#### DC-02: Reskin the six `OBT*` shared widgets (formatter conforms)

- **SRS / Source:** `02-conversion-checklist.md` §C; `03-foundation-plan.md` §4.1.
- **Priority:** P0 — Must have.
- **User Story:** As the Flutter team, I want the six existing shared widgets
  reskinned to Haldi tokens and type so that every screen that already uses them
  inherits the new visual language with no structural change.
- **Preconditions:** DC-01 merged.
- **Acceptance Criteria:**
  1. **Given** DC-01 is merged, **When** `OBTBottomNav`, `OBTFloatingActionButton`,
     `OBTAmountInput`, `OBTActivityRow`, `OBTConfirmationDialog`, and `OBTSettleUpCard`
     are reskinned, **Then** each consumes `Theme.of(context)` tokens / `OBTColors` /
     the radius scale with **no hard-coded Haldi hex**, and `OBTFloatingActionButton`
     is marigold with an **ink** glyph (not white).
  2. **Given** `OBTAmountInput`, **When** a user enters `₹150.50`, **Then** it still
     emits integer `15050` paise through the unchanged `onChanged(int paise)`
     contract and renders the value in Bricolage tabular figures (Invariant 1).
  3. **Given** `IndianPhoneInputFormatter`, **When** the reskin is reviewed, **Then**
     it is **unchanged** (pure formatter logic, no visual surface) and **no layout or
     structural change** is made to any of the six widgets (negative case — a diff
     that alters layout, the paise contract, or the formatter fails review).
  4. **Given** each reskinned widget, **When** captured, **Then** light + dark goldens
     exist and match the Haldi component spec.
- **Definition of Done:** the standard checklist; all six classified **reskin**
  (token/type only), the formatter **conform**.
- **Invariant Compliance:** `OBTAmountInput` and `OBTSettleUpCard` keep the
  `formatInrFromPaise()` boundary and the integer-paise contract (Invariant 1);
  `OBTSettleUpCard` continues to **read** the `simplifiedBalances` projection only and
  shows the single suggested payment (Invariant 2).
- **Responsible Agents:** Flutter Dev, Designer (visual review), QA.
- **Story Points:** 3

#### DC-03: Build the new Haldi shared components (all states)

- **SRS / Source:** `02-conversion-checklist.md` §C (the thirteen);
  `03-foundation-plan.md` §4.2.
- **Priority:** P0 — Must have.
- **User Story:** As the Flutter team, I want the new Haldi components built as
  reusable, fully-stated shared widgets so that every per-flow conversion wires a
  proven primitive instead of re-implementing it per screen.
- **Preconditions:** DC-01 merged.
- **Acceptance Criteria:**
  1. **Given** DC-01 is merged, **When** the **eleven** non-Groups components are
     built — skeleton-loader set (shimmer), balance pill, category chip/tile, 3-step
     add-expense sheet shell, segmented split-method control, settle-up bottom sheet,
     empty-state scaffold, offline / pending-sync banner, monthly-spend donut +
     6-category legend, OTP six-box auto-advance input, and the brand kit — **Then**
     each ships its four states (populated, empty, loading-skeleton/shimmer, error)
     with light + dark goldens, per the Haldi catalogue.
  2. **Given** the balance pill, **When** it renders any balance, **Then** it shows
     **colour and directional icon and label** (the `arrow_upward` / `arrow_downward`
     / `check` trio), **never colour alone**, and it reads the server
     `simplifiedBalances` projection only — it never writes it (Invariant 2).
  3. **Given** the settle-up bottom sheet, **When** it renders, **Then** it shows
     exactly **one pre-filled suggested payment (recipient + amount)** and the
     "Pay via UPI" row is present but **disabled / "Coming soon"** (negative case —
     rendering a raw who-owes-who debt graph, or wiring the UPI slot live, is a
     blocking defect; Invariant 2 + the inert extension-slot rule).
  4. **Given** the segmented split-method control, **When** split amounts do **not**
     sum exactly to the total, **Then** the red over/under state shows and Next is
     disabled; **When** they sum exactly, the green "adds up" state shows. All split
     amounts are integer paise rendered via `formatInrFromPaise()` (Invariant 1).
- **Definition of Done:** the standard checklist, plus: the two **Groups-specific**
  components — #10 **group segmented tab bar** and #12 **stacked-avatar cluster** —
  are **deferred to Sprint 4** and built fresh in Haldi with the Groups flow, per
  `02-conversion-checklist.md` §C and its critical-path table; this is recorded so
  Sprint 4 owns them on top of this foundation.
- **Invariant Compliance:** Components render money only via `formatInrFromPaise()`
  (Invariant 1); the balance pill and settle-up sheet **read** the projection and show
  the single suggested payment (Invariant 2); invite affordances delegate to the OS
  system share sheet only (Invariant 3); no project/config surface is touched
  (Invariant 4).
- **Responsible Agents:** Flutter Dev, Designer, QA.
- **Story Points:** 13

---

### Epic C — Per-Flow Screen Conversion

#### DC-04: Auth flow conversion (Haldi 1, 3, 4, 5)

- **SRS / Source:** FR-AU-01..06; Haldi screens 1, 3, 4, 5; `02-conversion-checklist.md`
  §B (Auth).
- **Priority:** P0 — Must have.
- **User Story:** As a user signing in, I want the splash, phone-entry, OTP, and
  profile-setup screens in the Haldi visual language so that my first impression of
  the app is consistent and on-brand.
- **Preconditions:** DC-01 merged; brand kit (DC-03 #13) available for the splash
  rebuild.
- **Acceptance Criteria:**
  1. **Given** the splash screen (Haldi 1, **rebuild**), **When** the app launches,
     **Then** the placeholder icon is replaced by the `÷` brand mark + "OneByTwo"
     wordmark on a full-bleed marigold gradient with **ink** (not white) on marigold,
     in light **and** dark.
  2. **Given** phone-entry (3), OTP (4) with `otp_input`, and profile-setup (5),
     **When** reskinned, **Then** they use marigold tokens + Bricolage/Hanken, the
     `+91` prefix stays **locked**, and the profile-setup camera badge icon is **ink,
     not white**; OTP, validation, and session behaviour are unchanged.
  3. **Given** `authenticated_screen.dart` (orphaned, no inbound references),
     **When** conversion runs, **Then** it is **deleted, not converted** (negative
     case — if any reference to `AuthenticatedScreen` is found, the deletion is
     blocked until the reference is removed).
- **Definition of Done:** the standard checklist; one of the three throwaways
  (`authenticated_screen.dart`) deleted here.
- **Invariant Compliance:** No money, balance, share, or project surface changes —
  all four invariants hold unchanged.
- **Responsible Agents:** Flutter Dev, Designer, QA.
- **Story Points:** 5

#### DC-05: Home dashboard conversion (Haldi 6 ★)

- **SRS / Source:** FR-HD-01..04; Haldi screen 6; `02-conversion-checklist.md`
  §B (Home, Shell).
- **Priority:** P0 — Must have.
- **User Story:** As a user, I want the Home dashboard in the Haldi visual language
  so that my net balance, top balances, and monthly spend read clearly and on-brand.
- **Preconditions:** DC-01 merged; skeleton-loader (#1), empty-state scaffold (#7),
  balance pill (#2), donut + legend (#9), category palette/chip (#3) available
  (DC-03).
- **Acceptance Criteria:**
  1. **Given** the Home dashboard (6 ★), **When** reskinned, **Then** the net header
     amount renders as a Bricolage tabular hero carrying the balance trio
     (colour + icon + label), the hand-rolled skeleton becomes the shimmer
     skeleton-loader, the empty `Icon` becomes the empty-state scaffold + illustration,
     and the spending donut re-points to the Haldi 8-hue palette — in light **and**
     dark.
  2. **Given** the net balance and top-balance tiles, **When** they render, **Then**
     they **read the server `simplifiedBalances` projection only** and display amounts
     via `formatInrFromPaise()` (Invariants 1 + 2 — the client never writes the
     projection).
  3. **Given** the Groups-tab stub `groups_list_placeholder.dart`, **When** conversion
     runs, **Then** it is **deleted, not converted** (negative case — the live Groups
     surface is built fresh in Haldi in Sprint 4; converting the stub is a defect).
- **Definition of Done:** the standard checklist; the `authenticated_shell.dart`
  5-tab + FAB structure **conforms** (no change); one throwaway
  (`groups_list_placeholder.dart`) deleted here.
- **Invariant Compliance:** Amounts via `formatInrFromPaise()` only (Invariant 1);
  balances are read-only projection reads showing simplified figures (Invariant 2);
  no share or project change (Invariants 3, 4).
- **Responsible Agents:** Flutter Dev, Designer, QA.
- **Story Points:** 5

#### DC-06: Friends flow conversion (Haldi 9 ★, 10, 11)

- **SRS / Source:** FR-FR-01..04; Haldi screens 9, 10, 11; `02-conversion-checklist.md`
  §B (Friends).
- **Priority:** P0 — Must have.
- **User Story:** As a user managing friends, I want the friends list, add-friend
  lookup, and friend-detail screens in the Haldi visual language so that balances and
  the add-friend branches are clear and on-brand.
- **Preconditions:** DC-01 merged; skeleton-loader (#1), empty-state scaffold (#7),
  balance pill (#2) available (DC-03).
- **Acceptance Criteria:**
  1. **Given** the friends list (9 ★), **When** reskinned, **Then** it gains the
     owed/owe summary band, balance-signal rows using the balance pill (colour + icon
     + label), shimmer skeleton, and the empty-state scaffold — in light **and** dark.
  2. **Given** add-friend (10), **When** converted, **Then** `match_and_invite_screen`
     is **rebuilt** so the bare `RateLimited` / `SelfAddBlocked` / `DuplicateFriendship`
     states become Haldi styled guard states, the looking-up spinner becomes a
     skeleton, and the no-match path becomes an empty-state invite.
  3. **Given** the no-match invite path, **When** the looked-up number has no account,
     **Then** the invite hands off to the **OS system share sheet only** — no
     WhatsApp/SMS/single-app button appears (negative case; Invariant 3).
  4. **Given** friend detail (11), **When** reskinned, **Then** the balance header and
     `OBTSettleUpCard` use the balance trio, amounts render via `formatInrFromPaise()`,
     and balances are **read** from the projection only (Invariants 1 + 2).
- **Definition of Done:** the standard checklist; `add_friend_flow.dart`
  **conforms** (pure navigation glue, no visual surface).
- **Invariant Compliance:** Integer paise via `formatInrFromPaise()` (Invariant 1);
  simplified balances read-only (Invariant 2); invites via OS share sheet only
  (Invariant 3); single project (Invariant 4).
- **Responsible Agents:** Flutter Dev, Designer, QA.
- **Story Points:** 5

#### DC-07: Expenses flow conversion (Haldi 21 ★, 22, and context picker 8)

- **SRS / Source:** FR-EX-01..08, FR-HD-04; Haldi screens 21, 22, 8;
  `02-conversion-checklist.md` §B (Expenses, Shell).
- **Priority:** P0 — Must have.
- **User Story:** As a user adding or viewing an expense, I want the 3-step add
  sheet, the expense detail, and the add-expense context picker in the Haldi visual
  language so that splitting is clear, validated, and on-brand.
- **Preconditions:** DC-01 merged; sheet shell (#4), segmented split control (#5),
  category chip (#3), skeleton-loader (#1) available (DC-03).
- **Acceptance Criteria:**
  1. **Given** the add-expense sheet (21 ★), **When** converted, **Then** the sheet
     shell gains the 28-radius top + grabber + visual stepper, **step 2 is rebuilt**
     to the segmented split-method control (Equally / Unequal / % / Shares / Exact),
     and **step 3** adds the note field plus the inert "Make recurring" slot
     ("Coming soon").
  2. **Given** step 2, **When** split amounts do **not** sum exactly to the total,
     **Then** Next is disabled and the red over/under state shows; the expense cannot
     be saved (negative case — amounts are integer paise via `formatInrFromPaise()`;
     `OBTAmountInput`'s paise contract is untouched; Invariant 1).
  3. **Given** expense detail (22), **When** reskinned, **Then** the per-person
     simplified split renders with balance tokens (payer "gets back", others "owe")
     **read from the projection**, the loading spinner becomes a skeleton, and the
     date renders in IST as `24 Jun 2026` (Invariants 1 + 2).
  4. **Given** the add-expense context picker (8), **When** reskinned, **Then** the
     Groups section shows "Coming soon", selecting a context opens the add sheet, and
     no backend call changes.
- **Definition of Done:** the standard checklist; the "Make recurring" slot ships
  inert.
- **Invariant Compliance:** Money is integer paise via `formatInrFromPaise()`
  (Invariant 1); the per-person split shows the **simplified** figure read from the
  projection, never a who-owes-who web (Invariant 2); no share/project change
  (Invariants 3, 4).
- **Responsible Agents:** Flutter Dev, Designer, QA.
- **Story Points:** 5

#### DC-08: Settlements flow conversion (Haldi 23 ★, 24)

- **SRS / Source:** FR-SE-05..09; Haldi screens 23, 24; `02-conversion-checklist.md`
  §B (Settlements).
- **Priority:** P0 — Must have.
- **User Story:** As a user settling up, I want the settle-up sheet and settlement
  history in the Haldi visual language so that the single suggested payment and the
  success moment are clear and on-brand.
- **Preconditions:** DC-01 merged; settle-up bottom sheet (#6), skeleton-loader (#1)
  available (DC-03).
- **Acceptance Criteria:**
  1. **Given** settle-up (23 ★), **When** **rebuilt**, **Then** it shows **one
     pre-filled suggested payment (recipient + amount)** from the projection, an
     editable amount, the disabled "Pay via UPI" slot ("Coming soon"), and the
     success moment ("You're all settled up — high five!" + haptic) replacing the
     placeholder — in light **and** dark.
  2. **Given** the settle-up sheet, **When** it renders, **Then** it shows exactly
     **one** suggested payment and **never a who-owes-who debt graph**; the client
     **reads** `simplifiedBalances` and never writes it; amounts render via
     `formatInrFromPaise()` (negative case — a raw debt-graph render or a client
     write is a blocking defect; Invariants 1 + 2).
  3. **Given** settlement history (24), **When** reskinned, **Then** rows gain a
     sent/received direction icon + sign and Bricolage tabular amounts; the
     **reminder-compose** and the **friend/group filter** are flagged as **PM-reconcile
     items** (per `01-coverage-gap.md` §C), not silently dropped.
- **Definition of Done:** the standard checklist; settlement recompute stays
  server-side (no client recompute introduced).
- **Invariant Compliance:** Integer paise via `formatInrFromPaise()` (Invariant 1);
  the single suggested payment is read-only from the projection (Invariant 2);
  reminders, if surfaced, do not introduce a per-app share path (Invariant 3); single
  project (Invariant 4).
- **Responsible Agents:** Flutter Dev, Designer, QA, PM (reminder/filter reconcile).
- **Story Points:** 3

#### DC-09: Activity and Notifications conversion (Haldi 25 ★, 26)

- **SRS / Source:** FR-AC-01..03, FR-AC-05; Haldi screens 25, 26;
  `02-conversion-checklist.md` §B (Activity, Notifications).
- **Priority:** P0 — Must have.
- **User Story:** As a user, I want the activity feed and the in-app notification
  surfaces in the Haldi visual language so that the event log and banners are clear
  and on-brand.
- **Preconditions:** DC-01 merged; skeleton-loader (#1), empty-state scaffold (#7)
  available (DC-03).
- **Acceptance Criteria:**
  1. **Given** the activity feed (25 ★), **When** reskinned via `OBTActivityRow`,
     **Then** the static skeleton becomes shimmer, the empty `Icon` becomes the
     empty-state scaffold, rows still deep-link to detail unchanged, and it renders in
     light **and** dark.
  2. **Given** the in-app banner and the pre-permission dialog (26), **When**
     reskinned, **Then** the **hard-coded hex** (`#2A9D8F` success, `#F4A261`
     secondary) is re-pointed to Haldi tokens and the lifecycle host **conforms** (no
     visual change).
  3. **Given** the in-app banner, **When** reviewed, **Then** **no hard-coded hex
     remains** — all colour flows from tokens (negative case — a literal hex in the
     widget fails review).
- **Definition of Done:** the standard checklist; the OS lock-screen banner is
  system-rendered and out of scope.
- **Invariant Compliance:** Any amounts in feed rows render via `formatInrFromPaise()`
  (Invariant 1); no projection write (Invariant 2); no notification trigger or share
  behaviour change (Invariants 3, 4).
- **Responsible Agents:** Flutter Dev, Designer, QA.
- **Story Points:** 3

#### DC-10: Profile and Settings conversion (Haldi 27, Phase3g, 28, 29, 30)

- **SRS / Source:** FR-PR-01..05, FR-SH-03/04, FR-AU-09; Haldi screens 27, 28, 29, 30;
  `02-conversion-checklist.md` §B (Profile).
- **Priority:** P1 — Should have (non-hero cluster; the descope-eligible buffer).
- **User Story:** As a user, I want my profile, notification preferences, contact
  support, and delete-account screens in the Haldi visual language so that settings
  are consistent and on-brand.
- **Preconditions:** DC-01 merged; `OBTConfirmationDialog` reskin (DC-02), photo
  picker pattern available.
- **Acceptance Criteria:**
  1. **Given** profile (27), edit-profile (27), notification preferences (28),
     delete-account (30), and contact-support (29), **When** reskinned, **Then** they
     use marigold tokens + Bricolage/Hanken, the inline sign-out `AlertDialog` becomes
     `OBTConfirmationDialog`, notification preferences gains the inert "Language" slot
     ("Coming soon"), and direct `AppTheme.radiusLarge`/`radiusXL` references are
     updated to the new radius scale; `+91` stays **locked** in edit.
  2. **Given** `change_phone_screen.dart` (FR-PR-02), **When** it is converted to the
     Haldi **Change Phone** design (Phase3g, added 2026-06-25), **Then** all five states
     (re-auth intro → re-auth OTP → new-phone entry → new-phone OTP → success) plus the
     "sync pending → Try again" recovery use Haldi tokens/type, masked numbers, and `+91`
     locked, while the two-OTP re-auth **behaviour is unchanged** (negative case —
     weakening or bypassing the re-auth flow, or showing an unmasked number, is a defect).
  3. **Given** `profile_placeholder_screen.dart` (superseded by Haldi 27), **When**
     conversion runs, **Then** it is **deleted, not converted**.
- **Definition of Done:** the standard checklist; the "Language" slot ships inert; one
  throwaway (`profile_placeholder_screen.dart`) deleted here; change-phone (Phase3g) is
  converted within this story — no carried follow-up.
- **Invariant Compliance:** No money path changes (Invariant 1); no projection write
  (Invariant 2); contact-support uses the device mail client / copy fallback, not a
  single-app target (Invariant 3); delete-account anonymisation is server-driven and
  unchanged on a single project (Invariant 4).
- **Responsible Agents:** Flutter Dev, Designer, QA.
- **Story Points:** 5

---

### Epic D — Dark-Mode Parity

#### DC-11: Dark-mode parity for every converted hero screen

- **SRS / Source:** ADR-0024; `03-foundation-plan.md` §1.3, §2.2;
  `02-conversion-checklist.md` critical-path table.
- **Priority:** P0 — Must have (Haldi ships heroes light **and** dark).
- **User Story:** As a user who prefers dark mode, I want every converted hero screen
  to render correctly in dark so that the app is fully usable and on-brand at night.
- **Preconditions:** the hero conversions (DC-04 splash, DC-05 home, DC-06 friends,
  DC-07 add-expense, DC-08 settle-up, DC-09 activity) merged.
- **Acceptance Criteria:**
  1. **Given** every converted hero (Splash 1, Home 6, Friends 9, Add-expense 21,
     Settle up 23, Activity 25), **When** toggled to dark, **Then** it renders the
     Haldi dark tokens (background `#1A1510`, surface `#241D16`, primary `#EAA24A`,
     `onPrimary` ink `#1A1510`) with 1px `outline` borders replacing the light
     soft-warm shadows.
  2. **Given** dark theme, **When** `onError` renders on the dark danger `#F2856B`,
     **Then** the foreground is **ink `#1A1510`**, not white (negative case — white on
     that light salmon is ≈ 2.5:1 and must fail the contrast gate; the same
     light/warm-fill-takes-ink rule applies to `onSecondary`).
  3. **Given** each converted hero, **When** captured, **Then** a **dark-mode golden**
     exists and matches alongside the light golden.
- **Definition of Done:** the standard checklist; every hero verified in both themes.
- **Invariant Compliance:** Dark-mode work is presentation only — no invariant is
  touched.
- **Responsible Agents:** Flutter Dev, Designer, QA.
- **Story Points:** 5

---

### Epic E — Accessibility Re-Verification

#### DC-12: Accessibility re-verification against the new palette

- **SRS / Source:** Haldi README (Accessibility); `03-foundation-plan.md` §1.2, §1.5,
  §2.3; the (planned) `docs/audits/design-conversion/04-qa-test-strategy.md`.
- **Priority:** P0 — Must have (a release gate).
- **User Story:** As any user, including those with low vision or colour-blindness, I
  want the Haldi palette and type to meet WCAG 2.1 AA so that the app is legible and
  operable after the conversion.
- **Preconditions:** DC-01 merged; the per-flow conversions in progress or merged.
- **Acceptance Criteria:**
  1. **Given** the new palette, **When** measured, **Then** the verified pairings hold:
     ink on marigold **5.6:1 (AA)**, ink on background **13.9:1 (AAA)**, positive
     `#0F7D6B` on white **4.6:1**, negative `#BC4030` on white **5.1:1**, and dark text
     `#F3EBDD` on `#1A1510` **14.2:1** — all meeting WCAG 2.1 AA (≥ 4.5:1 body,
     ≥ 3:1 large/UI).
  2. **Given** dynamic type scaled to **2.0×**, **When** every converted hero is
     rendered, **Then** no text clips or truncates and layouts reflow.
  3. **Given** any balance signal, **When** rendered in greyscale or under
     colour-blind simulation, **Then** it remains distinguishable because it carries
     **icon + label**, not colour alone (negative case — a colour-only balance signal
     fails the check); reduced-motion is honoured (animations collapse to instant
     cross-fades).
- **Definition of Done:** the standard checklist; the contrast and dynamic-type gates
  are wired into CI against the verified pairings.
- **Invariant Compliance:** Accessibility verification touches no data path — all four
  invariants hold unchanged.
- **Responsible Agents:** QA (owns the gate), Designer, Flutter Dev.
- **Story Points:** 3

---

### Epic F — Visual-Regression / Golden-Test Harness

#### DC-13: Visual-regression / golden-test harness

- **SRS / Source:** the (planned) `docs/audits/design-conversion/04-qa-test-strategy.md`;
  `03-foundation-plan.md` §6.
- **Priority:** P0 — Must have (makes the conversion provable and non-regressing).
- **User Story:** As the team, I want a golden / visual-regression harness so that the
  Haldi conversion is provable, reviewable, and protected from regression on every
  future PR.
- **Preconditions:** DC-01 merged (the harness scaffold is bootstrapped with PR #1 and
  accrues baselines as screens convert).
- **Acceptance Criteria:**
  1. **Given** the harness, **When** CI runs, **Then** it renders **light + dark**
     goldens for the six `OBT*` widgets, the eleven new components (all four states),
     and the converted hero screens, and **fails the build on any unintended pixel
     diff**.
  2. **Given** a converted screen, **When** its golden is intentionally updated,
     **Then** the baseline update is explicit and reviewed (no silent overwrite).
  3. **Given** a regression that reintroduces an old token (for example Indigo
     `#1F4E79`) or a white-on-marigold pairing, **When** CI runs, **Then** the golden /
     contrast gate **fails and blocks merge** (negative case).
- **Definition of Done:** the standard checklist; the harness and its baselines are
  documented and cross-referenced from
  `docs/audits/design-conversion/04-qa-test-strategy.md` (QA's strategy doc).
- **Invariant Compliance:** Test infrastructure only — no invariant is touched.
- **Responsible Agents:** QA (owns the harness), Flutter Dev, DevOps (CI wiring).
- **Story Points:** 5

---

## Sprint Capacity

| Epic | Stories | Points |
|---|---|---|
| A — Token + Type Foundation (DC-01) | 1 | 8 |
| B — Shared Component Library (DC-02, DC-03) | 2 | 16 |
| C — Per-Flow Screen Conversion (DC-04 … DC-10) | 7 | 31 |
| D — Dark-Mode Parity (DC-11) | 1 | 5 |
| E — Accessibility Re-Verification (DC-12) | 1 | 3 |
| F — Visual-Regression / Golden Harness (DC-13) | 1 | 5 |
| **Total** | **13** | **68** |

> **Roll-up note.** This **68 SP** is the additive enabling total that
> `docs/design/08-plan/sprint-sequence.md` records as "TBD / set in
> `sprint-3-plan.md`". It is **enabling** work (like INFRA-01 / FUNC-01 in Sprint 1):
> it delivers no new functional requirement, carries no P0 FR SP, and is therefore
> excluded from the 62-FR / programme FR-cumulative and P0-completion curves. The
> programme SP total advances by these 68 points; the FR totals are unchanged.

### Per-story SP rationale (for transparency)

| Story | SP | Rationale (grounded in `02-conversion-checklist.md` S/M/L) |
|---|---|---|
| DC-01 | 8 | Load-bearing, blocking foundation (ColorScheme + `OBTColors` + Bricolage/Hanken `TextTheme` + radius/shadow/motion + `OBTText` helper); comparable to INFRA-01. |
| DC-02 | 3 | Six widgets, all classified **reskin** (token/type only); formatter conforms. |
| DC-03 | 13 | Eleven components, each in four states + light/dark goldens; includes the greenfield segmented split control, offline banner, and brand kit. |
| DC-04 | 5 | Splash **rebuild** (brand-kit dependency) + three reskins + one delete. |
| DC-05 | 5 | Home hero ★ + six widgets + donut/skeleton/empty-state + one delete. |
| DC-06 | 5 | Friends list ★ + add-friend + `match_and_invite` **rebuild** + friend detail (rides on components). |
| DC-07 | 5 | Add-expense hero ★ (sheet shell + step-2 **rebuild** + step-3 additive) + detail + context picker. |
| DC-08 | 3 | Settle-up hero ★ **rebuild** (UPI slot + success moment via component) + history. |
| DC-09 | 3 | Activity hero ★ + shimmer + in-app banner / pre-permission reskins. |
| DC-10 | 5 | Profile cluster — six reskins (incl. change-phone, Haldi Phase3g, which reuses the reskinned `OtpInput` / phone input) + photo picker + one delete. |
| DC-11 | 5 | Bespoke dark-hero verification across six heroes. |
| DC-12 | 3 | Contrast gate + dynamic-type 2.0× + balance-trio + reduced-motion checks. |
| DC-13 | 5 | Golden harness + baselines for 6 widgets + 11 components + heroes, light + dark. |

---

## Milestone Ownership

Per `.github/shared/milestone-tracking.md`, the PM ensures the milestones for the
active and next sprint plus `Post-v1.0` exist and that every story is filed under
exactly one milestone at creation:

- **DC-01 … DC-13** are filed under the **`Sprint 3`** milestone at creation, each
  with a one-line rationale comment.
- **`Sprint 4`** (Groups and Settlements) is open as the next sprint; **`Post-v1.0`**
  exists.
- The **change-phone conversion** (DC-10) is **unblocked** — its Haldi design landed
  (Phase3g, 2026-06-25), so it converts within DC-10 under `Sprint 3` with no carried
  follow-up.
- Milestones are reconciled with each passing PR (verify the closed issue's milestone,
  re-home any re-scoped remainder, close the milestone when the last issue closes).

---

## Sprint-End Demo

Every converted hero screen — Home, Friends list, Add-expense, Settle up, Activity,
and Splash — renders in the Haldi visual language in **light and dark**. The six
`OBT*` components and the new Haldi components (skeleton loaders, balance pill,
category chip/tile, sheet shell, segmented split control, settle-up sheet, empty-state
scaffold, offline banner, donut + legend, OTP six-box, brand kit) are visibly in use.
The contrast gate passes against the verified Haldi pairings and dynamic type renders
to 2.0× without clipping. The golden-test harness runs green and demonstrates that a
deliberately-introduced old-token regression fails the build. Crucially, **no
application behaviour, balance figure, or backend contract changes**: the same
expenses, the same simplified balances, the same single suggested payment — only the
skin is new.

---

## Risks and Notes

1. **Change-phone design dependency (DC-10) — RESOLVED 2026-06-25.** The change-phone
   OTP re-verification flow (FR-PR-02) was the one built surface with no Haldi target;
   its Haldi **Change Phone** design has since landed (Phase3g), so DC-10 is fully
   unblocked and change-phone converts as a normal reskin within the cluster. No
   commission or carried follow-up remains.
2. **`google_fonts` exposure of Bricolage / Hanken.** PR #1 depends on the pinned
   `google_fonts` version exposing `bricolageGrotesque` and `hankenGrotesk`.
   *Mitigation:* if either is unavailable, bundle the `.ttf` fallback per
   `03-foundation-plan.md` §3.1 (a DevOps/Flutter-Dev call, not a scope change).
3. **Golden-test flakiness.** Font hinting and platform rasterisation can make goldens
   flaky across machines. *Mitigation:* pin the test platform/fonts in the DC-13
   harness, render at the Haldi reference frame (390 × 844), and gate baselines behind
   explicit review.
4. **Dark-mode contrast regressions.** The light/warm-fill-takes-ink rule (`onPrimary`,
   `onError`, `onSecondary`) is the most common reviewer surprise. *Mitigation:* the
   DC-12 contrast gate fails any white-on-light-fill pairing; the rule is restated in
   ADR-0024 and the foundation plan.
5. **The ink-`onPrimary` surprise.** White on marigold (≈ 2.5:1) fails AA; reviewers
   expecting white text on the brand colour must be reminded the foreground is ink.
6. **Scope creep into the backend.** A conversion PR that edits a data path, rule,
   function, or model is out of scope by definition. *Mitigation:* the DoD's
   "no backend contract changed" gate and `02-conversion-checklist.md` §E.
7. **Groups components deferred.** New components #10 (group tab bar) and #12
   (stacked-avatar cluster) are **not** built here; they are authored in Sprint 4 with
   the Groups flow. Sprint 4 owns them on top of this foundation.
8. **Descope buffer.** DC-10 (Profile cluster, P1) is the descope-eligible buffer if
   velocity slips; the heroes, foundation, components, dark-mode parity, accessibility
   gate, and golden harness are non-negotiable for a provable conversion.

---

## Sequencing and Critical Path

```
DC-01  Token + type foundation (PR #1)   ← blocks everything; the critical path
  │
  ├── DC-02  Six OBT* reskins
  ├── DC-03  New Haldi components (11; #10/#12 deferred to Sprint 4)
  └── DC-13  Golden harness scaffold bootstrapped (baselines accrue per PR)
        │
        ▼
  DC-04 Auth · DC-05 Home · DC-06 Friends · DC-07 Expenses ·
  DC-08 Settlements · DC-09 Activity · DC-10 Profile   (ride on DC-02 + DC-03)
        │
        ▼
  DC-11 Dark-mode parity  +  DC-12 Accessibility re-verification
        │
        ▼
  DC-13 Visual-regression / golden harness — final non-regression gate
```

1. **PR #1 (DC-01) is the single blocking dependency** for the whole sprint; nothing
   else may start until it merges (`03-foundation-plan.md` §0).
2. **Components before flows.** DC-02 and DC-03 deliver the primitives (in isolation,
   with goldens in all states); the per-flow stories then **wire** those primitives
   into the actual screens and reskin screen-specific chrome — a clean split with no
   double-counting.
3. **Heroes carry light + dark from their own story**, with DC-11 owning the dedicated
   dark-hero verification and bespoke polish pass end-to-end.
4. **DC-12 (accessibility) and DC-13 (goldens) are gates, not afterthoughts.** The
   DC-13 harness scaffold is bootstrapped alongside PR #1 so baselines accrue with
   each conversion PR; DC-13 as a story is the final, complete non-regression gate.
