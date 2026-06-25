# Claude Design Brief — "One By Two" (paste this into Claude)

> Copy everything below the line into Claude. It is fully self-contained — Claude does
> not need access to any repository. The brief asks Claude to design the complete visual
> identity, UI, and marketing assets for an India-first expense-sharing mobile app, and
> to deliver them as previewable artifacts (HTML/CSS mockups + SVG).

---

## ROLE

You are a senior product designer and brand designer. Design the **complete visual
system, UI, and launch assets** for a mobile app called **One By Two**. Deliver
everything as **previewable artifacts**: render screens and components as
**self-contained HTML/CSS mobile frames**, and logos/icons/illustrations as **inline
SVG**. Where a written spec is needed (tokens, rationale), give a tight table, not prose.

This is a **fresh, modern redesign**. An earlier version of the app shipped with a
palette and styling that felt flat and uninspired (see "Current styling — treat as
reference only" below). Your job is to make it look **genuinely premium, warm, modern,
and distinctly Indian** — the kind of money app people are happy to open. You have full
creative latitude on colour, type, shape, and illustration, **provided you honour the
non-negotiable product rules**. Treat the existing tokens as a starting reference to
**improve upon and replace**, not a constraint.

## HOW I WANT YOU TO WORK (phased — do not dump everything at once)

Deliver in this order, pausing after each phase so I can react:

1. **Phase 0 — Direction:** Propose **2–3 distinct visual directions** (mood, palette,
   type pairing, shape language, one hero screen each: the Home dashboard). One short
   paragraph of rationale per direction. **Stop and let me pick one.**
2. **Phase 1 — Brand & Foundations:** Logo, wordmark, app icon, splash, the full colour
   system (light + dark), typography system, iconography and illustration style, motion
   principles — all in the chosen direction.
3. **Phase 2 — Component library:** Every reusable component, all states.
4. **Phase 3 — Screens:** All screens below as high-fidelity mobile frames, grouped by
   flow, with the required states. Hero screens in both light and dark.
5. **Phase 4 — Marketing & store assets.**

If a phase is large, split it across messages and tell me when there is more to come.
Frame size for all screens: **390 × 844** (iPhone reference); keep layouts fluid so they
also read well at 412 × 892 (Android). Show a phone bezel/status bar for realism.

---

## 1. THE PRODUCT

**One By Two** is an expense-sharing app for India, in the spirit of Splitwise but
reimagined India-first. Friends, flatmates, families, and groups use it to track shared
expenses and settle up effortlessly.

- **Tagline / brand promise:** *"Split it. Settle it. Simple."*
- **Platforms:** iOS and Android (one unified brand; respect each platform's
  conventions where it matters — see Platform Guidance).
- **Market:** India only. Currency is **Indian Rupee (₹) only**. Sign-in is **+91
  phone numbers only**.
- **Personality:** Modern, friendly, warm, energetic, lightly playful, trustworthy.
  **Unmistakably Indian, but not clichéd** — evoke India through warmth, colour, and
  craft, not literal motifs. **Not corporate, not cold, not "enterprise fintech".**
- **Audience:** casual bill-splitters, power users (flatmates/trips/family tracking
  daily), and group admins. Tech comfort ranges low to high — clarity beats cleverness.

### Core mental model the UI must make obvious
- A **balance** is either "**you are owed ₹X**" (positive/green family) or "**you owe
  ₹Y**" (negative/red family) or "**all settled up**" (neutral). This positive/negative/
  settled trio is the single most important visual signal in the whole app — design it
  first and reuse it everywhere (dashboard, friend rows, group rows, settle-up).
- Balances are shown using **Simplified Debts**: the app always tells you the *minimum*
  set of payments to settle up. **Never show a raw "who paid whom for what" debt graph.**

---

## 2. CREATIVE DIRECTION (the ask)

Make it **fresh and premium**. Concretely, I'm looking for:

- A **distinctive, ownable colour story** — confident, warm, India-inspired, and modern.
  It must support a calm light theme and a true dark theme. Money-positive vs
  money-negative must be instantly readable and colour-blind-safe (never colour alone).
- **Beautiful typography** with a clear personality. A display/heading face with
  character paired with a highly legible text face. Prefer faces that ship on Google
  Fonts and have good Latin coverage (Indian-language support is a future-proofing plus).
- **Soft, modern shape language:** generous rounded corners, layered surfaces, subtle
  depth — depth without heaviness. Avoid heavy drop shadows and hard borders.
- **A delightful but quiet feel:** confident spacing, a strong number/amount treatment
  (amounts are the hero content of a money app), tasteful use of the accent colour.
- **Custom iconography feel** and a **light illustration style** for empty states,
  onboarding, and the app icon — cohesive with the brand, not generic stock.

### Current styling — treat as reference only (improve / replace freely)
- Old primary: Indigo Blue `#1F4E79` / `#2E86AB`; secondary Saffron/Marigold `#F4A261`;
  success Emerald `#2A9D8F`; danger Coral `#E76F51`; surfaces white / `#121212` dark.
- Old type: Plus Jakarta Sans (headings) + Inter (body). Radii 16/24. Material Symbols
  Rounded icons.
- **Why it underwhelms:** the palette reads muted and a bit corporate; the saffron feels
  bolted-on rather than integrated; little brand personality; amounts and balances don't
  feel special. You may keep what works (e.g. a warm Indian accent, dual-font pairing,
  soft radii) but raise the overall craft substantially and give it a real point of view.

---

## 3. NON-NEGOTIABLE RULES (these constrain the design; do not break them)

1. **Money is ₹ INR only, Indian numbering system, two decimals.** Format amounts as
   `₹1,23,456.00` (lakh/crore grouping: `₹50,00,000.00`), never `₹123,456.00`. The ₹
   symbol always prefixes. Show worked examples in the type/number spec for: ₹0.00,
   ₹50.00, ₹500.00, ₹5,000.00, ₹50,000.00, ₹5,00,000.00, ₹50,00,000.00, ₹5,00,00,000.00.
   (Internally the app stores integer paise; you only ever design the rupee display.)
2. **Balance semantics:** "you are owed" = positive/success colour; "you owe" =
   negative/danger colour; "settled up" = neutral. Always pair colour with text/icon —
   **never communicate by colour alone** (accessibility + colour-blind safety).
3. **Simplified Debts only.** Settle-up always shows a single suggested payment
   (recipient + amount pre-filled). No raw multi-edge debt graphs anywhere.
4. **Sharing uses the OS system share sheet only.** Invite/share flows hand off to the
   native share sheet — **do not design WhatsApp/Telegram/SMS-specific buttons or target
   any single app.** Show a generic "Share invite" affordance that opens the OS sheet.
5. **+91 phone auth only.** Phone entry has a **locked +91 prefix** and a 10-digit field.
   OTP is 6 digits.
6. **Light + dark themes are both required**, with WCAG 2.1 AA contrast (≥4.5:1 body
   text, ≥3:1 large text / UI components). Verify and note contrast for key pairings.
7. **Accessibility is first-class:** support dynamic type up to 2.0× without clipping;
   tap targets ≥ 44×44 pt (iOS) / 48×48 dp (Android); every control has a clear label;
   screen-reader friendly. Design layouts that survive large text.
8. **Dates/times are always IST** and formatted like `24 Jun 2026` regardless of device
   locale. Relative timestamps ("2h ago", "Yesterday") are welcome in feeds.
9. **Every list and detail screen needs four states:** populated, **empty** (friendly,
   with a clear call-to-action), **loading** (prefer **skeleton screens** over spinners),
   and **error** (with a **Retry** affordance and a path to Contact Support). Design
   these — they are not optional.
10. **Microcopy tone:** friendly, concise, lightly playful. Examples to match:
    *"You're all settled up — high five!"*, *"Looks like Rahul still owes you ₹350. Send
    a nudge?"*, *"Adding expense… hold tight."* No legalese outside privacy/terms.

### Out of scope for v1.0 (do not design these as live features)
Integrated UPI/payment-gateway payments; multi-currency; web/desktop; ads; AI expense
suggestions; recurring expenses; in-app language switching. **However**, leave tasteful,
non-committal "extension slots" so these can appear later without a redesign:
- A neutral slot in **Settle Up** where a future "Pay via UPI" option would sit.
- A neutral slot in **Add Expense** where a future "Make recurring" toggle would sit.
- A hidden-but-present **"Language"** row in Profile.
Mark these slots clearly as future placeholders in your designs.

---

## 4. DELIVERABLES

### A. Brand identity
- **Logo / wordmark** for "One By Two" + the tagline lockup. Consider a mark that plays
  on the idea of splitting/halving/sharing (e.g. a 1:2 or split motif) without being
  literal or childish.
- **App icon** for both stores: an **iOS icon** (rounded-square master, no transparency)
  and an **Android adaptive icon** (separate foreground + background layers, safe-zone
  aware). Show the icon on a home screen for context, light and dark wallpapers.
- **Splash screen** consistent with the icon/brand.
- Provide logo usage do's/don'ts, clear-space, and minimum sizes.

### B. Colour system (light + dark)
- A semantic token table with **semantic name → light hex → dark hex → usage**, covering
  at least: primary, primary-variant/accent, secondary, success, danger/error, warning
  (if used), surface, surface-variant, background, outline, divider, disabled, and the
  full text ramp (primary/secondary/tertiary, on-primary, on-danger).
- The **balance trio**: `balancePositive`, `balanceNegative`, `balanceZero` (light+dark).
- An **8-colour expense-category palette** (light + dark variants), one hue per category:
  **Food & Drink, Transport, Groceries, Entertainment, Rent & Housing, Utilities,
  Shopping, Other.** Must be distinguishable, colour-blind-safe (deliberate luminance
  spread), and each ≥3:1 against the card surface in both themes. This palette drives the
  Home monthly-spend donut and category chips.
- Note contrast ratios for the key foreground/background pairings.

### C. Typography & number system
- Chosen font pairing (display/heading + text), with the type scale: role name → font →
  weight → size → line-height → letter-spacing → usage. Include a big, confident
  **amount/balance** style — this is the brand's hero number.
- **₹ Indian-numbering** worked examples (see rule 1), negative-amount treatment, and the
  positive/negative/settled colour usage on amounts.
- **+91 phone display** format and **IST date** formats (absolute + relative).

### D. Iconography & illustration
- Icon style direction (rounded, consistent stroke) and the 8 category icons.
- A cohesive **illustration style** for: 3 onboarding slides, and empty states for
  Friends, Groups, Activity, Search, and "all settled up".

### E. Component library (design each with all states: default, pressed, disabled,
loading, error/empty where relevant; and light + dark)
- App bar / large-title header; Bottom navigation bar (5 tabs: Home, Friends, Groups,
  Activity, Profile); Floating Action Button (persistent "add expense").
- List tiles: **Friend row** (avatar, name, balance pill), **Group row** (cover/avatar,
  name, members, balance), **Activity row** (actor, action, amount, timestamp).
- **Balance pill / chip** (the positive/negative/settled signal).
- **Amount input** (big ₹ keypad-friendly field) and **OTP input** (6 boxes, auto-advance).
- **Contact picker** row, **avatar** (single + stacked group avatars), **category chip**,
  **segmented control** (split methods), **slider/stepper** for shares.
- **Settle-up card**, **empty state**, **error state**, **skeleton loader**, **snackbar/
  toast**, **bottom sheet** (with grabber), **confirmation dialog**, **banner** (offline).
- Buttons (filled / tonal / outlined / text / destructive) and form fields with inline
  validation errors.

### F. Motion & interaction principles
- Page push/pop, bottom-sheet entrance, FAB press (a little spring is welcome), list
  stagger on load, skeleton→content reveal, OTP auto-advance, success haptic on settle.
- Keep it 200–300 ms, ease-in-out, "delightful but quiet"; respect reduce-motion.

### G. Screens — design ALL of the following (high-fidelity mobile frames)
Group by flow. For list/detail screens, show populated + empty + loading + error
(at minimum a representative set; always show empty + populated). Show hero screens
(starred ★) in **both light and dark**.

**Auth & onboarding**
1. **Splash** — brand moment. ★
2. **Onboarding** — 3 illustrated slides selling the value (track, split, settle),
   ending in a "Get started" CTA. Link to privacy/terms.
3. **Phone entry** — locked **+91** prefix, 10-digit field, validation, "Send OTP".
4. **OTP verification** — 6-digit input, 30s resend cooldown (max 3 tries / 10 min),
   auto-read hint on Android, manual on iOS, error state for wrong code.
5. **Profile setup** — display name (required) + optional photo upload.

**Home & search**
6. **Home dashboard** ★ — the hero. Primary element: overall net simplified balance
   ("You are owed ₹X" / "You owe ₹Y" / "All settled up"). Below: **top 5 friends/groups**
   by absolute balance with quick "Settle" access; a **current-month spend donut** with
   category breakdown + legend; persistent **FAB** to add expense. Design empty (new
   user, nothing yet) and populated.
7. **Search overlay** — search expenses by description/amount/category/member; filter by
   date range, group, category. Show empty, typing, and results states.
8. **Add-expense entry** — the context picker that launches the add-expense sheet
   (choose a friend or a group to add the expense in).

**Friends (1-to-1)**
9. **Friends list** ★ — every friend with net balance (owed / owes / settled). Empty +
   populated + loading skeleton.
10. **Add friend** — pick from contacts **or** enter a +91 number; if the contact isn't
    a user, show an "Invite" path that opens the **system share sheet** (generic).
11. **Friend detail** — net balance, **Settle Up** CTA when non-zero, transaction list
    (expenses + settlements, reverse chronological).
12. **Friend history** — full reverse-chronological log.
13. **Delete-friend** confirmation — only allowed when balance is zero (show the blocked
    state when there's an outstanding balance).

**Groups**
14. **Groups list** — every group with simplified member balances. Empty + populated.
15. **Create group** — name, **type (Trip / Home / Couple / Other)**, optional cover photo.
16. **Group detail** ★ — expenses, per-member simplified balances, group activity, FAB to
    add, Settle Up CTA.
17. **Invite members** — contact picker, +91 entry, **or** a shareable invite link via the
    **system share sheet**; note the link expires in 7 days and is revocable by admin.
18. **Group members** — member list with balances; admin actions (remove a member only
    when their balance is zero — show enabled vs blocked).
19. **Delete / leave group** — leave only when your balance is zero; admin delete only
    when all balances are zero (show the blocked states).
20. **Group history** — chronological group log.

**Expenses**
21. **Add expense — multi-step bottom sheet** ★:
    - Step 1 **Amount & details:** big ₹ amount, description, date (IST), **category**
      (8 categories with icons), payer.
    - Step 2 **Split:** methods = **Equally, Unequal (by amount), By Percentage, By
      Shares, By Exact Amounts.** Live validation that splits **sum exactly** to the
      total, with a clear inline error when they don't. Show per-person breakdown.
    - Step 3 **Receipt & confirm:** optional receipt image (camera/gallery), optional
      note, summary, "Add expense" CTA. Include the neutral future "Make recurring" slot.
22. **Edit / delete expense** — editable form (creator only) + delete confirmation.

**Settle up & settlements**
23. **Settle up** ★ — **pre-filled** recipient + amount from the simplified-debts
    suggestion; amount (editable), date, optional note. Include the neutral future "Pay
    via UPI" slot. Success state ("You're all settled up — high five!").
24. **Settlement history** — per friend and per group, reverse chronological.
    Also design the **send-a-reminder** action (free-text nudge to someone who owes you;
    rate-limited to once per friend per 24h) — e.g. a small compose sheet/dialog.

**Activity & notifications**
25. **Activity feed** ★ — chronological feed of everything involving the user (expenses
    added/edited/deleted, settlements, group changes). Tapping a row deep-links to the
    relevant detail. Empty + populated.
26. Design representative **push notifications** (lock-screen/banner) for: new expense,
    settlement received, reminder — and show how a tapped notification deep-links in.

**Profile & settings**
27. **Profile (view/edit)** — name, photo, **list of my friends and groups**, and a clear
    **Contact Support** action (opens the device mail client, pre-filled). Sign-out.
28. **Notification preferences** — per-category toggles (new expense, settlement,
    reminders). Include the hidden-but-present future **Language** row.
29. **Contact support** — mail-client handoff; plus a fallback "copy email" dialog when no
    mail app is configured.
30. **Delete account** — confirmation flow explaining anonymisation in shared groups and
    removal within 30 days.

**Global overlays** — design these once and reuse: add-expense sheet, settle-up sheet,
delete confirmations, sign-out confirmation, **offline banner**, snackbars.

### H. Marketing & store assets
- **App Store + Google Play screenshots** (6–8): branded, captioned device frames that
  sell the value props (track shared spends, split any way, see who owes whom, settle in
  a tap, group trips, dark mode). Light and dark mix.
- **Google Play feature graphic** (1024×500) and any store hero/banner.
- **Social launch set:** a square (1080×1080) and a story (1080×1920) announcement.
- **One landing-page hero** section (headline, subcopy, app mockups, store badges).
- App **store listing copy**: short tagline, long description, and a keyword list — in the
  brand's friendly-but-clear voice.

---

## 5. PLATFORM GUIDANCE (modern iOS + Android)
- One brand, **platform-aware execution**: lean on **Material 3 (Material You / expressive)**
  for Android and **Apple HIG** for iOS where it matters — e.g. large-title navigation,
  bottom sheets with a grab handle, segmented controls, native-feeling switches, edge-to-
  edge layouts, safe-area/notch awareness, and a comfortable bottom nav.
- Use contemporary patterns: prominent FAB / persistent add action, rounded card surfaces,
  pill-shaped controls, generous whitespace, big legible numerals, haptic-backed actions,
  and graceful skeleton loading.
- Keep all primary actions reachable within ~2 taps from Home.

## 6. OUTPUT FORMAT & ACCEPTANCE
- Deliver screens/components as **self-contained HTML/CSS artifacts** (one artifact per
  flow group is fine), 390×844 frames, fluid layout, real-looking Indian sample data
  (names like Rahul, Priya, Aditya; amounts in ₹ Indian format; IST dates). Logos/icons/
  illustrations as **inline SVG**. Tokens and type/number specs as compact tables.
- Use the **chosen Phase 0 direction** consistently across everything.
- Before you finish, give me a short **acceptance checklist** confirming: light+dark done;
  empty/loading/error states present; ₹ Indian-number formatting correct; balance colour
  + text (never colour alone); +91 lock; system-share-sheet generic (no app targeting);
  no raw debt graph; AA contrast noted; large-type safe; extension slots marked.

**Start with Phase 0: three visual directions, each with a Home-dashboard hero. Then stop
and ask me to choose.**
