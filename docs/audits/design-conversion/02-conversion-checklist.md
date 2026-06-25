# 02 — Implementation Conformance Gap Analysis (Conversion Checklist)

**Phase 2 of the Design Conversion Sprint (Sprint 3).** Author: Flutter Developer
(consulting with the Designer's lens). Status: planning only — no `lib/**` file is
modified by this document.

Companion documents (binding context):

- `README.md` — canonical framing, the four invariants, the 30 Haldi screens and
  their numbering, the renumber mapping.
- `01-coverage-gap.md` — Designer's Phase-1 coverage matrix, the (now-resolved)
  change-phone gap (FR-PR-02 → Haldi Phase3g), and the three throwaways to delete.
- `03-foundation-plan.md` — Architect's Phase-3 token/type swap, the six `OBT*`
  reskins, and the thirteen new components.
- `design_handoff_one_by_two/README.md` — the Haldi per-screen spec and states.

---

## A. Intro — what this classifies, and the rules

This document classifies **every built screen and every shared component** against
its Haldi target ("Direction A — Haldi") into one of five buckets:

- **conform** — already matches the Haldi target; no change needed (typically pure
  navigation glue or logic-only files with no visual surface).
- **reskin** — tokens and type only. Colours, fonts, radii and shadows swap to the
  Haldi system; **no layout or structural change**. Includes minor additive single
  rows/slots (for example one inert "Coming soon" row) and swapping an inline
  element for its shared-component equivalent.
- **rebuild** — a genuine layout/structure change is needed to match the Haldi spec
  (a new control replaces an old one, a new sub-screen/state is built, or a bare
  unstyled state is replaced with the Haldi treatment).
- **delete** — internal throwaway; remove rather than convert.
- **blocked** — cannot be converted yet because the Haldi design does not exist.

**Scope discipline.** This conversion is **visual/UX only**. No data path, provider
contract, repository, Firestore read/write, Cloud Function call, or domain model
changes. Every row below rides on top of Sprint 3 PR #1 (the token + type
foundation from `03-foundation-plan.md`), **delivered by DC-01 (#113)**: the Haldi
`ColorScheme` (marigold `primary`, ink `onPrimary`), the `OBTColors` theme
extension, the named `AppTheme` radius scale + soft-warm shadow + motion tokens,
the Bricolage/Hanken type ramp, and the `OBTText.amount` / `OBTText.amountHero`
helpers have landed, so the bulk of the work below is mechanical swap-and-verify.
The integer-paise pipeline, `simplifiedBalances`
read-only contract, OS share sheet, and single-Firebase-project rules are untouched
(see §E).

**A note on "states to add".** The Haldi catalogue requires, where relevant, four
states per screen — populated, empty, **loading (skeleton)**, error — and hero
screens ship **light + dark**. Most built screens already implement all four
*logical* states, but their loading state is usually a hand-rolled static skeleton
(no shimmer) or a `CircularProgressIndicator`. Those are flagged so the loading
state is upgraded to the shared shimmer skeleton-loader component, and empty states
get the flat-illustration empty-state scaffold rather than a bare `Icon`.

---

## B. Per-screen conversion table

One row per built screen / bottom sheet / dialog / meaningful row-widget under
`lib/features/*/presentation/`, grouped by flow. Paths are relative to
`lib/features/`. Effort: **S** = token/type only (hours); **M** = token/type plus an
additive element or a new-component dependency (≈ a day); **L** = multi-element
rebuild or hero light+dark bespoke work (multi-day). Hero screens marked ★.

### Auth

| file | Haldi № | class | key changes | states to add | effort |
|---|---|---|---|---|---|
| `auth/presentation/splash_screen.dart` | 1 ★ | **rebuild** | Replace placeholder `Icons.vertical_split_rounded` with the ÷ brand mark + OneByTwo wordmark on a full-bleed marigold gradient; ink-on-marigold; tagline in Hanken. Depends on **brand kit**. | light + dark hero treatment (dark splash) | M |
| `auth/presentation/phone_entry_screen.dart` | 3 | reskin | Marigold tokens + Bricolage/Hanken; locked `+91` chip on `surfaceVariant`; field radius → chip/input 12; CTA → primary ink-on-marigold. | — (error + loading present) | S |
| `auth/presentation/otp_entry_screen.dart` | 4 | reskin | Marigold tokens + type; resend cooldown caption → tertiary text; error microcopy. | — | S |
| `auth/presentation/widgets/otp_input.dart` | 4 | reskin | Cell radius → chip/input 12; active/filled border → marigold; digit text → Bricolage tabular. (This **is** new-component #11 — already built; reskin only.) | — | S |
| `auth/presentation/profile_setup_screen.dart` | 5 | reskin | Marigold tokens + type; camera badge icon → **onPrimary ink (not white)**; avatar fallback from scheme; field radius. | — (validation present) | M |
| `auth/presentation/authenticated_screen.dart` | — | **delete** | Orphaned internal screen, no inbound references. Remove (do not convert). | — | S |

### Home

| file | Haldi № | class | key changes | states to add | effort |
|---|---|---|---|---|---|
| `home/presentation/home_dashboard_screen.dart` | 6 ★ | reskin | Marigold tokens + type; hand-rolled skeleton → shimmer **skeleton-loader**; empty `Icon` → **empty-state scaffold** + illustration; net header amount → Bricolage tabular hero. | loading-skeleton (shimmer); empty illustration; dark hero | M |
| `home/presentation/widgets/net_balance_header_card.dart` | 6 ★ | reskin | `tertiaryContainer`/`errorContainer` → Haldi surfaceVariant tonal hero + marigold-tinted soft shadow; amount → Bricolage tabular (46–50); **add directional icon** (balance trio = colour + icon + label). | dark hero | M |
| `home/presentation/widgets/top_balance_tile.dart` | 6 ★ | reskin | Name → Hanken; Settle Up button → marigold; balance pill gains icon via shared **balance pill**. | — | S |
| `home/presentation/widgets/spending_breakdown_card.dart` | 6 ★ | reskin | Card radius → 20; legend → Hanken; swatches → Haldi 8-hue; skeleton → shimmer. (This is **donut + legend**, new-component #9 — already built via fl_chart.) | loading-skeleton (shimmer) | M |
| `home/presentation/widgets/spending_donut_chart.dart` | 6 ★ | reskin | Re-point segment colours to Haldi 8-hue; centre total → Bricolage tabular; gap colour → surface. | — | S |
| `home/presentation/widgets/spending_category_palette.dart` | 6 | reskin | Re-point all eight light + dark category hues from the old hex (food `#B23A48`…) to the Haldi palette; or source from `OBTColors`. | — | S |

### Friends

| file | Haldi № | class | key changes | states to add | effort |
|---|---|---|---|---|---|
| `friends/presentation/friends_list_screen.dart` | 9 ★ | reskin | Marigold tokens + type; add owed/owe summary band (single additive card); hand-rolled skeleton → shimmer; empty `Icon` → empty-state scaffold; balance-signal rows. | loading-skeleton (shimmer); empty illustration; dark hero | M |
| `friends/presentation/widgets/friend_list_tile.dart` | 9 ★ | reskin | Name → Hanken 700; balance pill gains icon; row padding/shadow. | — | S |
| `friends/presentation/widgets/balance_pill.dart` | 6/9/11 | reskin | Re-point `tertiaryContainer`/`errorContainer` to the balance-trio tokens; **add directional icon** (`arrow_upward`/`arrow_downward`/`check`) to complete colour + icon + label; amount → Bricolage tabular; promote to shared `OBTBalancePill`. (New-component #2 — ~80% built; needs the icon.) | — | S |
| `friends/presentation/friend_detail_screen.dart` | 11 | reskin | Marigold tokens + type; `OBTSettleUpCard` reskin; FAB → marigold; skeleton → shimmer. | loading-skeleton (shimmer) | M |
| `friends/presentation/widgets/friend_detail_header.dart` | 11 | reskin | Large balance pill gains icon + balance-trio tokens; name → Bricolage/Hanken; amount → Bricolage tabular. | — | S |
| `friends/presentation/widgets/friend_detail_timeline.dart` | 11/12 | reskin | Category icon → Haldi hue bed; amounts → Bricolage tabular; share label → balance tokens; IST dates. | — | M |
| `friends/presentation/widgets/friend_detail_states.dart` | 11 | reskin | Skeleton → shimmer; empty `Icon` → empty-state scaffold; tokens. | loading-skeleton (shimmer); empty illustration | S |
| `friends/presentation/add_friend_screen.dart` | 10 | reskin | Marigold tokens + type; segmented Contacts/Manual reskin; search field radius; contacts `CircularProgressIndicator` → skeleton. | loading-skeleton (replace spinner) | M |
| `friends/presentation/add_friend_flow.dart` | 10 | **conform** | Pure navigation glue (route push helper); no visual surface. | — | — |
| `friends/presentation/match_and_invite_screen.dart` | 10 | **rebuild** | `RateLimited`/`SelfAddBlocked`/`DuplicateFriendship` are bare `Center(Text())`; build Haldi styled guard states; match-found → confirm-add card with mutual groups; looking-up spinner → skeleton; no-match → empty-state-scaffold invite. | loading-skeleton; styled guard states | M |
| `friends/presentation/widgets/manual_phone_entry_tab.dart` | 10 | reskin | Locked `+91` field + CTA tokens + type (mirrors phone-entry). | — | S |
| `friends/presentation/widgets/contact_list_tile.dart` | 10 | reskin | Name → Hanken; avatar + subtitle tokens. | — | S |
| `friends/presentation/widgets/empty_contacts_state.dart` | 10 | reskin | `Icon` + copy → empty-state scaffold + illustration; tokens. | — | S |
| `friends/presentation/widgets/permission_denied_view.dart` | 10 | reskin | Lock `Icon` + CTA tokens + type; manual-entry link styling. | — | S |
| `friends/presentation/widgets/phone_selector_bottom_sheet.dart` | 10 | reskin | Sheet top radius → 28; title → overline; rows → Hanken. | — | S |

### Expenses

| file | Haldi № | class | key changes | states to add | effort |
|---|---|---|---|---|---|
| `expenses/presentation/add_expense_bottom_sheet.dart` | 21 ★ | reskin | Sheet top radius → 28 + grabber; replace `(N/3)` text with a visual stepper; header → Bricolage. Formalise as **3-step add-expense sheet shell** (new-component #4 — built inline today). | — | M |
| `expenses/presentation/steps/step_1_amount_details.dart` | 21 ★ | reskin | `OBTAmountInput` amount → Bricolage tabular; category grid → **category chips/tiles**; date → IST `24 Jun 2026`; Next → marigold. | — | M |
| `expenses/presentation/steps/step_2_split_and_payer.dart` | 21 ★ | **rebuild** | Replace the `Wrap` of `ChoiceChip` split methods with the **segmented split-method control** (Equally / Unequal / % / Shares / Exact) and wire live "adds up" green/red validation; payer toggle reskin. | green "adds up" valid state | M |
| `expenses/presentation/steps/step_3_receipt_and_confirm.dart` | 21 ★ | reskin | Add a **note** field and the inert **"Make recurring"** extension slot (Coming soon); reskin receipt area + summary card. | — | M |
| `expenses/presentation/expense_detail_screen.dart` | 22 | reskin | Marigold tokens + type; category avatar → Haldi hue bed; amounts → Bricolage tabular; per-person split with balance tokens; loading `CircularProgressIndicator` → skeleton; IST date. | loading-skeleton (replace spinner) | M |
| `expenses/presentation/widgets/expense_category_grid.dart` | 21 | reskin | `ChoiceChip` grid → **category chip/tile**: full-hue icon on ~10%-opacity hue bed; radius 12. | — | S |
| `expenses/presentation/widgets/split_row.dart` | 21 | reskin | Amounts → Bricolage tabular; label → Hanken. | — | S |
| `expenses/presentation/widgets/split_validation_message.dart` | 21 | reskin | `errorContainer` pill → red over/under token; add the green "adds up" success variant for the segmented control. | green valid variant | S |
| `expenses/presentation/widgets/changed_field_indicator.dart` | 22 | reskin | 2px left border → Haldi secondary/terracotta token. | — | S |
| `expenses/presentation/widgets/receipt_fullscreen_viewer.dart` | 22 | reskin | Viewer chrome tokens (scrim, close affordance). | — | S |

### Settlements

| file | Haldi № | class | key changes | states to add | effort |
|---|---|---|---|---|---|
| `settlements/presentation/settle_up_bottom_sheet.dart` | 23 ★ | **rebuild** | Add the disabled **"Pay via UPI"** extension slot (Coming soon); build the success moment ("You're all settled up — high five!" + haptic) replacing the snackbar/`SizedBox` placeholder; reskin amount/date/note/record. New-component #6. | success-moment state; dark hero | M |
| `settlements/presentation/widgets/settle_up_header.dart` | 23 ★ | reskin | Payer → arrow → payee tints → marigold; suggested amount → Bricolage tabular. | — | S |
| `settlements/presentation/settlement_history_screen.dart` | 24 | reskin | Marigold tokens + type; loading `CircularProgressIndicator` → skeleton; rows gain sent/received direction icon + sign; amounts → Bricolage tabular. **Friend/group filter + "Send a reminder" compose are PM-reconcile flags** (per `01-coverage-gap` §C), not pure conversion. | loading-skeleton (replace spinner) | M |

### Activity

| file | Haldi № | class | key changes | states to add | effort |
|---|---|---|---|---|---|
| `activity/presentation/activity_feed_screen.dart` | 25 ★ | reskin | Marigold tokens + type; static skeleton → shimmer; empty `Icon` → empty-state scaffold; rows reskin via `OBTActivityRow`. | loading-skeleton (shimmer); empty illustration; dark hero | M |
| `activity/presentation/widgets/activity_feed_skeleton.dart` | 25 ★ | reskin | Static grey blocks → shimmer (the file's own comment defers shimmer); source from the shared skeleton-loader. | — | S |

### Notifications

| file | Haldi № | class | key changes | states to add | effort |
|---|---|---|---|---|---|
| `notifications/presentation/notifications_lifecycle_host.dart` | 26 | **conform** | Lifecycle/overlay host; no visual surface of its own (renders the banner + dialog below). | — | — |
| `notifications/presentation/widgets/in_app_notification_banner.dart` | 26 | reskin | Re-point **hard-coded** hex (`#2A9D8F` success, `#F4A261` secondary) to Haldi tokens; card radius → 20; black → warm shadow; type → Hanken. | — | S |
| `notifications/presentation/pre_permission_dialog.dart` | 26 | reskin | Marigold tokens; dialog radius → card 20; CTA → onPrimary ink + radius 16; replace literal `fontSize` with type slots; bell → brand illustration (optional). | — | S |

### Profile

| file | Haldi № | class | key changes | states to add | effort |
|---|---|---|---|---|---|
| `profile/presentation/profile_screen.dart` | 27 | reskin | Marigold tokens + type; avatar fallback → primaryContainer ink; rows → Hanken; inline sign-out `AlertDialog` → `OBTConfirmationDialog`; delete → error token. (`_ShimmerEffect` loading already present.) | — | M |
| `profile/presentation/edit_profile_screen.dart` | 27 | reskin | Marigold tokens + type; camera badge → onPrimary ink; field radius → 12; Save → marigold. **Updates direct `AppTheme.radiusLarge`/`radiusXL` references to the new radius scale.** | — | M |
| `profile/presentation/change_phone_screen.dart` | Phase3g | **reskin** | Haldi **Change Phone** design landed (Phase3g). Marigold tokens + Bricolage/Hanken across the five states; reuses the reskinned `OtpInput` + phone input; masked-number styling; the "sync pending → Try again" recovery uses the **warning** token (not danger); +91 stays locked. | sync-pending recovery state styled | M |
| `profile/presentation/notification_preferences_screen.dart` | 28 | reskin | Marigold tokens + type; toggles → marigold; OS-permission banner → warm tonal; **add the inert "Language" extension slot** (Coming soon); loading spinner → skeleton/simple. | loading-skeleton (replace spinner) | M |
| `profile/presentation/delete_account_screen.dart` | 30 | reskin | Marigold tokens + type; destructive warning → error token; re-auth `OtpInput` reskin; success-state Haldi treatment; update `AppTheme.radius*` references. | — | M |
| `profile/presentation/contact_support_fallback_dialog.dart` | 29 | reskin | Dialog radius → 20; selectable email → link token; buttons → Hanken/marigold. | — | S |
| `profile/presentation/profile_placeholder_screen.dart` | — | **delete** | Superseded by the real `profile_screen.dart` (Haldi 27). Remove (do not convert). | — | S |
| `profile/presentation/widgets/photo_picker_sheet.dart` | 5/27 | reskin | Sheet top radius → 28; ListTile rows → Hanken; destructive "Remove" → error token. | — | S |

### Shell / nav

| file | Haldi № | class | key changes | states to add | effort |
|---|---|---|---|---|---|
| `shell/presentation/authenticated_shell.dart` | global | **conform** | `IndexedStack` + 5-tab + FAB structure already matches the Haldi shell model; the visual change lives entirely in `OBTBottomNav` + `OBTFloatingActionButton` (see §C). No change in this file. | — | — |
| `shell/presentation/add_expense_context_picker_sheet.dart` | 8 | reskin | Sheet radius → 28; section headers → overline; friends loading spinner → skeleton; Groups stub copy → "Coming soon"; add the Haldi search field (additive). | loading-skeleton (replace spinner); search field | M |
| `shell/presentation/groups_list_placeholder.dart` | — | **delete** | Replaced by the real Haldi 14 Groups list, built fresh in **Sprint 4**. Remove (do not convert). | — | S |

> **Not in scope here.** Haldi 2 (Onboarding), 7 (Search), 13 (Remove friend),
> 14–20 (Groups: list, create, detail ★, invite, members, leave/delete, history)
> have **no built file** — `lib/features/groups/` is greenfield. Group detail
> (Haldi 16 ★) and the rest of the Groups flow are **built fresh in Sprint 4**, not
> converted in this sprint.

---

## C. Per-component conversion table

### Existing shared `OBT*` widgets + formatter

All six `OBT*` widgets are reskins (token/type only, no structural rebuild) per
`03-foundation-plan.md` §4.1, confirmed by reading each file.

| component | path | class | key changes | effort |
|---|---|---|---|---|
| `OBTBottomNav` | `core/widgets/nav/obt_bottom_nav.dart` | reskin | Active tint → primary marigold; filled/outlined icon pair stays; label → Hanken caption. *Optional follow-up:* migrate `BottomNavigationBar` → Material 3 `NavigationBar` to gain the Haldi active-pill (bumps to M). | S |
| `OBTFloatingActionButton` | `core/widgets/nav/obt_floating_action_button.dart` | reskin | `backgroundColor` secondary → **primary marigold**; `foregroundColor` white → **onPrimary ink**; radius → pill; optional press-spring. | S |
| `OBTAmountInput` | `core/widgets/inputs/obt_amount_input.dart` | reskin | Amount text → Bricolage tabular; `₹` prefix → primary; field radius → 12; error → error token. **Paise logic untouched (Invariant 1).** | S |
| `OBTActivityRow` | `core/widgets/lists/obt_activity_row.dart` | reskin | Event-icon colours → Haldi semantics; trailing amount → Bricolage tabular; primary/secondary → Hanken; avatar tint. | S |
| `OBTConfirmationDialog` | `core/widgets/dialogs/obt_confirmation_dialog.dart` | reskin | Dialog radius → card 20; destructive → error/onError ink; buttons → Hanken. | S |
| `OBTSettleUpCard` | `friends/presentation/widgets/obt_settle_up_card.dart` | reskin | Card fill → surfaceVariant hero; arrow → marigold; amount → Bricolage tabular; CTA radius/type; cooldown caption → tertiary text. | S |
| `IndianPhoneInputFormatter` (+ display formatter) | `core/widgets/india_phone_input_formatter.dart` | **conform** | Pure `TextInputFormatter` logic (strip/cap/group). No visual surface, no tokens — no change. | — |

### New components to create (Architect's thirteen, refined per-screen)

Effort folds in the built foundation discovered while reading the surface. Many
"new" components are really **promote-and-reskin an existing widget**, not
greenfield.

1. **Skeleton-loader set (shimmer)** — `S/M`. Haldi 6, 9, 11, 16, 21, 23, 25, and
   add-friend 10. Consolidates the hand-rolled static skeletons in home, friends,
   friend-detail, activity and profile and adds shimmer; also replaces the spinners
   in add-friend, match-and-invite, settlement-history, expense-detail,
   notification-prefs and the context picker.
2. **Balance pill** — `S`. Haldi 6, 9, 11, 16. `balance_pill.dart` exists but is
   colour + label only; **add the directional icon** to complete the trio and
   promote to shared `OBTBalancePill`.
3. **Category chip / tile** — `S/M`. Haldi 7, 21, 22, 6. `expense_category_grid` +
   `spending_category_palette` exist with old hex; re-point to the Haldi 8-hue and
   extract the chip (full-hue icon on ~10%-opacity bed).
4. **3-step add-expense sheet shell** — `M`. Haldi 21. Exists inline in
   `add_expense_bottom_sheet.dart`; formalise + add the visual stepper.
5. **Segmented split-method control** — `M`. Haldi 21 step 2. **Greenfield**
   (today a `Wrap` of `ChoiceChip`); includes live green/red "adds up" validation.
6. **Settle-up bottom sheet** — `M`. Haldi 23. Sheet exists; add the inert
   "Pay via UPI" slot + the success moment.
7. **Empty-state scaffold** — `S`. Haldi 6, 9, 14, 24, 25. Consolidates the ad-hoc
   `Icon` + text empties and hosts the flat brand illustrations.
8. **Offline / pending-sync banner** — `M`. **Global, greenfield** — no global
   offline banner exists today. Overlays every surface.
9. **Monthly-spend donut + 6-cat legend** — `S`. Haldi 6. Exists via fl_chart
   (`spending_donut_chart` + `spending_breakdown_card`); reskin to Haldi.
10. **Group segmented tab bar** — `M`. Haldi 16. **Greenfield** (Groups; Sprint 4).
11. **OTP six-box auto-advance input** — `S`. Haldi 4. `otp_input.dart` already
    exists (six-box, auto-advance, paste) — reskin only.
12. **Stacked-avatar cluster** — `S/M`. Haldi 14, 18. **Greenfield** (Groups;
    Sprint 4).
13. **Brand kit** — `M/L`. Haldi 1, 2. ÷ logo mark, wordmark, splash marigold
    gradient, onboarding illustrations. **Greenfield** (today a placeholder icon).

---

## D. Roll-up

### Counts by classification (all 56 table rows)

| classification | count |
|---|---|
| conform | 3 |
| reskin | 46 |
| rebuild | 4 |
| delete | 3 |
| blocked | 0 |
| **total** | **56** |

- **conform (3):** `add_friend_flow.dart`, `notifications_lifecycle_host.dart`,
  `authenticated_shell.dart` (logic/nav glue, no visual surface or change).
- **rebuild (4):** `splash_screen.dart` (brand moment), `match_and_invite_screen.dart`
  (bare guard states), `step_2_split_and_payer.dart` (segmented control + live
  validation), `settle_up_bottom_sheet.dart` (UPI slot + success moment).
- **delete (3):** `authenticated_screen.dart`, `profile_placeholder_screen.dart`,
  `groups_list_placeholder.dart`.
- **blocked (0):** none — the former blocker, `change_phone_screen.dart` (FR-PR-02), now has
  its Haldi design (**Phase3g**, added 2026-06-25) and converts as a **reskin** within DC-10.

### Total rough effort feel

The conversion is **broad but shallow**: ~80% of rows are **S/M reskins** that ride
on the Sprint 3 PR #1 token/type foundation and are largely swap-and-verify.
Concentrated effort lives in (a) the **4 rebuilds**, (b) the **greenfield new
components** (#5 segmented split control, #8 offline banner, #13 brand kit), and
(c) **hero light + dark** bespoke verification. The remaining new components are
"promote + reskin" of an existing foundation, not greenfield. Excluding PR #1 and
the Groups/Sprint-4 components (#10, #12), the screen conversion clusters into a
handful of L-sized efforts (add-expense hero, settle-up hero, home hero, brand kit)
plus many S reskins — a comfortable single-sprint body of work for one developer.

### Critical path (hero screens, ship light + dark)

| Haldi № | screen | this sprint? | depends on new components |
|---|---|---|---|
| 6 ★ | Home | yes — reskin | skeleton-loader (#1), empty-state scaffold (#7), balance pill (#2), donut + legend (#9), category palette (#3) |
| 9 ★ | Friends list | yes — reskin | skeleton-loader (#1), empty-state scaffold (#7), balance pill (#2) |
| 16 ★ | Group detail | **no — built fresh in Sprint 4** | group tab bar (#10), stacked avatars (#12), skeleton-loader (#1), balance pill (#2) |
| 21 ★ | Add expense (3-step) | yes — sheet shell reskin; steps 2/3 rebuild | sheet shell (#4), segmented split control (#5), category chip (#3) |
| 23 ★ | Settle up | yes — rebuild | settle-up sheet (#6) |
| 25 ★ | Activity feed | yes — reskin | skeleton-loader (#1), empty-state scaffold (#7) |
| 1 ★ | Splash | yes — rebuild | brand kit (#13) |

### New-component dependency call-outs

- **Every list/feed screen** (Home 6, Friends 9, Friend detail 11, Activity 25,
  Add-friend 10, Settlement history 24, Expense detail 22, Context picker 8) depends
  on **skeleton-loader (#1)** + **empty-state scaffold (#7)**.
- **Every balance surface** (Home 6, Friends 9, Friend detail 11; Group detail 16 in
  Sprint 4) depends on **balance pill (#2)** — and on its icon being added so the
  balance signal is colour + icon + label, never colour alone.
- **Home 6** additionally depends on **donut + legend (#9)** + **category palette/chip
  (#3)**.
- **Add expense 21** depends on **sheet shell (#4)** + **segmented split control (#5)**
  + **category chip (#3)**.
- **Settle up 23** depends on the **settle-up sheet (#6)**.
- **Splash 1 / Onboarding 2** depend on the **brand kit (#13)**.
- The **offline banner (#8)** is global and overlays every surface (no single owner
  screen).

---

## E. Invariants check (one line)

This conversion changes **presentation only**: integer-paise rendering stays via
`formatInrFromPaise()` (and `OBTAmountInput`'s paise logic is untouched),
`simplifiedBalances` stays read-only in the UI, the OS system share sheet remains the
only share path, and the single Firebase project / Emulator Suite is unaffected.
