# Handoff: One By Two — Expense-sharing app (iOS + Android)

## Overview
**One By Two** is an India-first expense-sharing app (think Splitwise, reimagined): friends, flatmates and families track shared expenses and settle up with the *fewest* payments. Brand promise: **"Split it. Settle it. Simple."**

This package documents the complete visual system, component library and all 30 screens so a developer can implement the app in a real codebase.

## About the design files
The files in `screens/` are **design references created in HTML** — streaming "Design Component" prototypes that show the intended look, layout and behaviour. **They are not production code to copy.** Your task is to **recreate these designs in the target codebase's environment** (SwiftUI / Jetpack Compose / React Native / Flutter, etc.) using its established patterns, navigation and component libraries. If no app project exists yet, pick the most appropriate stack for a cross-platform consumer app and build there.

> The HTML uses Google Fonts + Material Symbols (icon font) and a tiny runtime (`support.js`) only so the references render in a browser. None of that runtime is part of the product — map the tokens/specs below onto native equivalents.

## Fidelity
**High-fidelity (hifi).** Final colours, typography, spacing, radii, iconography and interaction states are all specified. Recreate the UI faithfully using the codebase's component primitives. Match the tokens exactly.

---

## Design tokens

### Colour — light → dark (semantic)
| Token | Light | Dark | Usage |
|---|---|---|---|
| background | `#FBF6EE` | `#1A1510` | App canvas |
| surface | `#FFFFFF` | `#241D16` | Cards, sheets, rows |
| surfaceVariant | `#FFF6E6` | `#2E2620` | Tonal fills, hero card, chips |
| primary | `#E0922E` | `#EAA24A` | Brand · FAB, primary buttons |
| primaryPressed | `#C77F22` | `#D08F3C` | Pressed primary |
| secondary | `#C75D3C` | `#E07A55` | Terracotta accent |
| onPrimary | `#2A211B` | `#1A1510` | **Ink** text/icon on marigold (NOT white — needed for AA) |
| success / balancePositive | `#0F7D6B` | `#34C0A4` | "You are owed", confirm |
| danger / balanceNegative | `#BC4030` | `#F2856B` | "You owe", errors, destructive |
| balanceZero | `#6F6557` | `#A99C8C` | "Settled up" (neutral) |
| warning | `#E8A33D` | `#F2B863` | Cautions, cooldowns |
| text-primary | `#2A211B` | `#F3EBDD` | Headings, amounts, names |
| text-secondary | `#6F6557` | `#B9AE9D` | Body |
| text-tertiary | `#9A8F82` | `#8A7E6E` | Meta, timestamps |
| outline / divider | `#E7DDCD` | `#3A322A` | Borders, hairlines |
| disabled (fill / text) | `#E4DCCE` / `#B8AC9B` | `#332B23` / `#6B6053` | Disabled |
| link (on light) | `#A35E16` | `#EAA24A` | Text/links on tonal |

### Balance trio (the single most important signal — colour + icon + label, NEVER colour alone)
- **Positive (owed):** success colour + `arrow_upward` + "owes you" / "you are owed"
- **Negative (owe):** danger colour + `arrow_downward` + "you owe"
- **Zero (settled):** balanceZero + `check` + "Settled up"

### Expense-category palette (8 hues, colour-blind-safe luminance spread; ≥3:1 on surface)
| Category | Light | Dark | Icon (Material Symbols) |
|---|---|---|---|
| Food & Drink | `#E8762B` | `#F59A52` | restaurant |
| Transport | `#2E78C9` | `#5B9BE8` | directions_bus / directions_car |
| Groceries | `#4FA13E` | `#73C463` | local_grocery_store |
| Entertainment | `#B5489B` | `#D470BC` | movie |
| Rent & Housing | `#6C4FC9` | `#9079E6` | home |
| Utilities | `#1FA39A` | `#3EC9BF` | bolt |
| Shopping | `#D94F87` | `#F074A6` | shopping_bag |
| Other | `#8A7B6B` | `#A99986` | category |
Category chip/tile backgrounds use the hue at ~10% opacity (`hue + "1A"`); icon uses full hue.

### Typography
Display/heading: **Bricolage Grotesque** (700/600). Text/UI: **Hanken Grotesk** (400/500/700). Amounts always use Bricolage with tabular figures.

| Role | Font | Wt | Size / LH | Tracking |
|---|---|---|---|---|
| Amount-hero | Bricolage | 700 | 46–50 / 1.0 | −0.01em |
| H1 large title | Bricolage | 700 | 32 / 38 | −0.01em |
| H2 screen/sheet title | Bricolage | 700 | 22–24 / 30 | −0.01em |
| H3 section | Bricolage | 600 | 18–19 | 0 |
| Title / row name | Hanken | 700 | 14–16 | 0 |
| Amount-row | Bricolage | 700 | 13–17 | 0 |
| Body | Hanken | 400/500 | 15 / 22 | 0 |
| Body-sm | Hanken | 400 | 13 | 0 |
| Caption / meta | Hanken | 500 | 11–12 | .01em |
| Overline / kicker | Hanken | 700 | 11 | .12em, UPPERCASE |
| Button | Hanken | 700 | 15–16 | .01em |

### Shape, elevation, spacing
- Radii: pills/FAB-ish `18–19`, cards `16–22`, sheets `26–28` (top corners), buttons `14–16`, chips/inputs `12–14`, full pills `999`.
- Shadows are soft and warm, never hard borders: light `0 1px 3px rgba(42,33,27,.05)` for rows; hero/elevated `0 12px 30px -12px rgba(224,146,46,.3)`; dark theme uses `0 8px 22px -10px rgba(0,0,0,.6)` and 1px `outline` borders instead of shadows.
- Screen gutters `18–22px`. Row vertical padding `10–13px`. Tap targets ≥ **44pt iOS / 48dp Android**.
- Phone reference frame: **390 × 844** (also reads at 412 × 892). Keep layouts fluid.

### Motion
200–300ms, ease-in-out default. Page push/pop slide+fade (~280ms). Bottom sheet springs up with a grabber. FAB press a little spring (scale 0.92→1.04→1). List stagger 30ms/row. Skeleton→content cross-fade. Success = check pop + success haptic. Respect `prefers-reduced-motion` / Reduce Motion (instant cross-fades).

---

## Formatting rules (NON-NEGOTIABLE)
- **Currency:** ₹ INR only. **Indian numbering** (lakh/crore grouping), ₹ prefix, two decimals. Examples: `₹0.00`, `₹50.00`, `₹500.00`, `₹5,000.00`, `₹50,000.00`, `₹5,00,000.00`, `₹50,00,000.00`, `₹5,00,00,000.00`. Store integer paise internally; only the rupee *display* is designed.
- **Auth:** +91 only. Locked `+91` prefix + 10-digit field; OTP is 6 digits (30s resend cooldown, max 3 tries / 10 min).
- **Dates/times:** always IST, formatted `24 Jun 2026` (and `24 Jun 2026, 7:30 PM`). Relative timestamps welcome in feeds ("Just now", "2h ago", "Yesterday").
- **Phone display:** `+91 98765 43210`.
- **Simplified debts only:** settle-up always shows ONE pre-filled suggested payment (recipient + amount). Never render a raw who-paid-whom debt graph.
- **Sharing:** invites hand off to the **OS system share sheet** only. No WhatsApp/SMS/any-single-app buttons. A generic "Share invite" affordance; invite links expire in 7 days and are admin-revocable.
- **Accessibility:** WCAG 2.1 AA (≥4.5:1 body, ≥3:1 large/UI). Dynamic type to 2.0× without clipping. Every control labelled, screen-reader friendly. Verified pairings: ink `#2A211B` on background `#FBF6EE` 13.9:1 (AAA); ink on primary `#E0922E` 5.6:1 (AA); positive `#0F7D6B` on white 4.6:1; negative `#BC4030` on white 5.1:1; dark text `#F3EBDD` on `#1A1510` 14.2:1.

### Future "extension slots" (present but disabled, tagged "Coming soon" — do not build live)
- Settle Up → "Pay via UPI" row.
- Add Expense (Step 3) → "Make recurring" toggle.
- Profile → Notifications → "Language" row.

---

## Brand assets
- **Logo mark:** the division sign **÷** (two dots + a bar) — "one *by* two" = divide/split. Built from primitives: top dot `circle cx50 cy27 r9`, bar `rect x20 y45 w60 h9 rx4.5`, bottom dot `circle cx50 cy73 r9` (viewBox 0 0 100 100). Cream `#FFF7E8` on a marigold gradient `linear-gradient(150deg,#ECA64A,#D97A1E)`.
- **Wordmark:** "One**By**Two" in Bricolage Grotesque 700, the "By" in primary `#E0922E`.
- **App icon:** iOS rounded-square master (radius 22.4%, no transparency), marigold radial-gradient bg + cream ÷. Android adaptive: foreground = ÷ inside safe zone, background = marigold gradient.
- **Splash:** full-bleed marigold gradient, centred ÷ mark + wordmark, tagline.
- **Icons:** Material Symbols Rounded — default `FILL 0, wght 400`; active/selected `FILL 1, wght 500`. Replace with the platform's icon set or an equivalent rounded set in code.
- **Illustrations:** warm, flat, geometric spot illustrations from rounded shapes in the brand palette (coins, receipts, the ÷ between two avatars, a teal success check). Used for onboarding + empty states.
- **Fonts:** Bricolage Grotesque + Hanken Grotesk (Google Fonts). Bundle or use platform-appropriate embedding.

---

## Screens / views (30)
All screens have, where relevant, four states: **populated, empty (friendly + CTA), loading (skeleton, not spinners), error (Retry + Contact support)**. Hero screens ship light **and** dark.

**Auth & onboarding**
1. **Splash** — brand moment (marigold, ÷ mark). Light + dark.
2. **Onboarding** — 3 illustrated slides (Track / Split / Settle), Skip, pagination, "Get started" + Terms/Privacy links.
3. **Phone entry** — locked +91 + 10-digit field, numeric keypad, "Send OTP"; + error state (invalid number → disabled CTA).
4. **OTP** — 6-box auto-advance, 30s resend cooldown, Android auto-read hint; + wrong-code error (try counter, resend enabled).
5. **Profile setup** — required display name (validated) + optional photo.

**Home & search**
6. **Home dashboard** ★ (L+D) — net simplified balance hero, top balances (with quick Settle), monthly spend donut + 6-cat legend, FAB, 5-tab nav. + empty (new-user).
7. **Search** — initial (focused field, date/group/category filters, recent searches) + results (category-icon rows).
8. **Add-expense context picker** — search + Groups/Friends sections; selecting one opens the add sheet.

**Friends**
9. **Friends list** ★ (L+D) — owed/owe summary + balance-signal rows. + empty + skeleton.
10. **Add friend** — +91 entry or contact pick → **backend lookup** → branches: *looking up* (skeleton) · *user found* (confirm-add sheet w/ mutual groups) · *already friends* · *that's your own number* (self guard) · *no account → Invite* (OS share sheet). Invite only appears AFTER lookup fails.
11. **Friend detail** — net balance, Settle Up (non-zero) + Remind, transactions (expenses + settlements, reverse-chron).
12. **Friend history** — full reverse-chron log, month-grouped, signed amounts.
13. **Remove friend** — allowed only when settled (destructive confirm); blocked when a balance is outstanding (routes to Settle up).

**Groups**
14. **Groups list** — type icon, stacked members, your group net balance. + empty.
15. **Create group** — optional cover, name, type (Trip / Home / Couple / Other).
16. **Group detail** ★ (L+D) — cover header by type, your balance + Settle Up, Expenses/Balances/Activity tabs, FAB. The **Balances** tab shows each member's simplified net (gets back / owes / settled) plus the minimum set of payments to clear the whole group (e.g. "You pay Rahul ₹1,620"), with a note that we never show a tangled who-owes-who web.
17. **Invite members** — 7-day admin-revocable share link via OS sheet, +91 entry, multi-select contacts.
18. **Group members** — admin badge; settled members removable, owing members locked (admin can remove only when balance is zero).
19. **Leave / delete group** — leave only when your balance is zero (blocked state); admin delete only when ALL balances zero (lists who's outstanding).
20. **Group history** — chronological log (expenses, edits, settlements, joins).

**Expenses**
21. **Add expense — 3-step bottom sheet** ★ — Step 1 amount/description/IST date/category/payer · Step 2 split (Equally / Unequal / % / Shares / Exact) with **live validation that splits sum exactly** (valid = green "adds up"; invalid = red over/under, Next disabled) · Step 3 receipt + note + summary + "Make recurring" slot.
22. **View expense (detail)** — tap any expense → full detail: category + description + amount, payer/group/IST date, per-person simplified split (payer "gets back", others "owe"), receipt thumbnail, note. **Edit / delete expense** — creator-only editable form; delete confirm explains balance impact.

**Settle up & settlements**
23. **Settle up** ★ (L+D) — pre-filled recipient + amount from simplified debts, editable amount, date, note, "Pay via UPI" slot; success screen ("You're all settled up — high five!").
24. **Settlement history** — sent/received with direction icon + sign, friend/group filter; **Send a reminder** compose (pre-filled friendly nudge, rate-limited once/24h).

**Activity & notifications**
25. **Activity feed** ★ (L+D) — chronological (expenses, settlements, reminders, group changes); rows deep-link to detail. + empty.
26. **Push notifications** — lock-screen banners (new expense / settlement / reminder); tapping deep-links to the relevant screen.

**Profile & settings**
27. **Profile** view (avatar, +91, friends/groups counts, settings, sign out) + **edit** (name + photo; +91 locked).
28. **Notification preferences** — per-category toggles (new expense, settlement, reminders, group activity) + future **Language** row (disabled, "Coming soon").
29. **Contact support** — opens device mail client pre-filled; **copy-email fallback** dialog when no mail app.
30. **Delete account** — anonymises past expenses to "Former member" in shared groups, full removal within 30 days, explicit acknowledgement required.

**Global overlays** (design once, reuse): add-expense sheet, settle-up sheet, delete confirmations, **sign-out confirmation**, offline banner (pending-sync state), snackbars/toasts.

---

## Interactions & behaviour
- **Navigation:** 5-tab bottom nav (Home · Friends · Groups · Activity · Profile) on tab roots; pushed screens (detail/add/settle/history/settings) use a back button and no bottom nav. A persistent **FAB** (add expense) floats above the bar on tab roots. Primary actions reachable within ~2 taps of Home.
- **Add expense:** FAB → context picker → 3-step sheet → on "Add expense" returns to the launching screen with a success toast ("Expense added to <context>"); balances update.
- **Settle up:** Friend/Group detail "Settle up" → pre-filled sheet → "Record payment" → success moment (haptic) → back.
- **Validation:** phone (10 digits enables CTA), OTP (6 digits, wrong-code counter), split sums (must equal total exactly), name (required). Inline errors use danger colour + helper text + `error`/`info` icon.
- **Empty/loading/error:** skeleton screens for loading (shimmer), friendly empties with one clear CTA, error with Retry + Contact support.
- **Share:** any invite → OS share sheet (generic).

## State management
Per-user/session state the app needs: auth (phone, OTP, session), current user profile, friends list (each with net balance), groups (members, per-member simplified balances, group expenses), expenses (amount in paise, description, IST date, category, payer, split map), settlements (payer→payee, amount, date), activity feed, notification preferences, theme (light/dark/system), offline/queued-sync flag. Balances are derived via a **simplified-debts** algorithm (minimise number of transfers); the UI only ever shows the suggested single payment.

## Assets
- Fonts: Bricolage Grotesque, Hanken Grotesk (Google Fonts).
- Icons: Material Symbols Rounded (icon font) — substitute the platform's rounded icon set.
- Logo/icon/illustrations: ÷ mark + flat geometric spots, all reproducible from the specs above (no external image files — recreate as vectors/native drawables).

## Files (in `screens/`, design references)
- `Phase0 - Directions` — the three explored visual directions (Direction A “Haldi” was chosen).
- `Phase1 - Foundations` — brand, colour, type, number, iconography, motion specs.
- `Phase2 - Components` — full component library, all states, light + dark.
- `Phase3a Auth` · `Phase3b Home` · `Phase3c Friends` · `Phase3d Groups` · `Phase3e Expenses` · `Phase3f Profile` — all 30 screens grouped by flow.
- `Phase3g Change Phone` — **FR-PR-02 change-number / re-verify flow** (not in the original 30): a security-gated two-OTP flow reached from Profile → the locked +91 row. States: re-auth intro → re-auth OTP (current number, masked) → new-phone entry (+91, validateIndianMobile) → new-phone OTP (masked) → success, plus the ADR-0015 **“sync pending → Try again” recovery** (Auth updated but profile save failed — a one-tap retry, warning not danger), and the cross-cutting loading / wrong-code error states; light + dark. Numbers are masked everywhere except the locked current-number field; +91 only, no country picker.
- `Prototype - Complete` — **the primary interactive prototype**: every screen + scenario reachable, light/dark toggle, back stack, 5-tab nav, and an "All screens" jump menu. Validated end-to-end (add-expense, settle-up, add-friend lookup branches, blocked states, overlays/sheets, notification deep-links, group Balances).
- `Prototype - Click-through` — earlier slimmer prototype of just the core happy path (auth → home → add expense → settle up). Superseded by `Prototype - Complete`.
- `Phase4 - Marketing` — store screenshots, feature graphic, social, landing, listing copy (marketing reference, not app UI).
- `One By Two — Index & Acceptance` — index + acceptance checklist.

Open any `.dc.html` in a browser to view the reference (they load Google Fonts + the bundled `support.js` runtime).
