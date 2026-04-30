# v1.0 Product Backlog

> Derived from the OneByTwo Software Requirements Specification v1.1, section 4.
> Priorities (P0 / P1 / P2) are as stated in the SRS. Story-point estimates use a
> Fibonacci scale (1, 2, 3, 5, 8) and reflect relative complexity including UI,
> backend, and test effort.

---

## Epic 1 — Authentication and Onboarding

| ID | Title | Priority | SP | Dependencies |
|---|---|---|---|---|
| FR-AU-01 | Phone sign-in with locked +91 prefix | P0 | 3 | — |
| FR-AU-02 | Reject invalid Indian mobile numbers | P0 | 1 | FR-AU-01 |
| FR-AU-03 | Trigger Firebase Phone Auth OTP on valid submit | P0 | 3 | FR-AU-02 |
| FR-AU-04 | Auto-read OTP on Android; manual entry on iOS | P0 | 3 | FR-AU-03 |
| FR-AU-05 | OTP resend with 30-second cooldown and retry cap | P0 | 2 | FR-AU-03 |
| FR-AU-06 | First-login onboarding (display name and photo) | P0 | 3 | FR-AU-03 |
| FR-AU-07 | Persist session and auto-login | P0 | 2 | FR-AU-03 |
| FR-AU-08 | Sign out from Profile screen | P0 | 1 | FR-AU-07, FR-PR-01 |
| FR-AU-09 | Account deletion with data anonymisation | P1 | 5 | FR-AU-07 |

---

## Epic 2 — Profile Management

| ID | Title | Priority | SP | Dependencies |
|---|---|---|---|---|
| FR-PR-01 | View and edit display name and profile photo | P0 | 3 | FR-AU-06 |
| FR-PR-02 | Update phone number via re-verification OTP | P1 | 3 | FR-AU-03, FR-PR-01 |
| FR-PR-03 | Set notification preferences per category | P1 | 2 | FR-PR-01 |
| FR-PR-04 | View list of friends and groups from profile | P0 | 2 | FR-PR-01, FR-FR-01, FR-GR-01 |
| FR-PR-05 | Contact Support via mailto with pre-filled fields | P0 | 2 | FR-PR-01 |

---

## Epic 3 — Friends

| ID | Title | Priority | SP | Dependencies |
|---|---|---|---|---|
| FR-FR-01 | Add friend by contact picker or +91 number | P0 | 3 | FR-AU-07 |
| FR-FR-02 | Link existing user or invite via system share sheet | P0 | 3 | FR-FR-01, FR-SH-01 |
| FR-FR-03 | Friends list with simplified net balance | P0 | 3 | FR-FR-01, FR-SE-01 |
| FR-FR-04 | Per-friend transaction history | P0 | 3 | FR-FR-01, FR-EX-01 |
| FR-FR-05 | Delete friend when balance is zero | P1 | 2 | FR-FR-03, FR-SE-01 |

---

## Epic 4 — Groups

| ID | Title | Priority | SP | Dependencies |
|---|---|---|---|---|
| FR-GR-01 | Create group (name, type, optional cover photo) | P0 | 3 | FR-AU-07 |
| FR-GR-02 | Invite members via picker, phone, or share-sheet link | P0 | 3 | FR-GR-01, FR-SH-01 |
| FR-GR-03 | Invite link expiry (7 days) and admin revocation | P0 | 3 | FR-GR-02 |
| FR-GR-04 | View group expenses, member balances, and activity | P0 | 5 | FR-GR-01, FR-EX-01, FR-SE-01 |
| FR-GR-05 | Admin remove member (zero balance guard) | P0 | 2 | FR-GR-04, FR-SE-01 |
| FR-GR-06 | Member leave group (zero balance guard) | P0 | 2 | FR-GR-04, FR-SE-01 |
| FR-GR-07 | Admin delete group (all balances zero guard) | P0 | 2 | FR-GR-04, FR-SE-01 |

---

## Epic 5 — Expense Management

| ID | Title | Priority | SP | Dependencies |
|---|---|---|---|---|
| FR-EX-01 | Add expense (amount, description, date, category, payer, split, notes) | P0 | 5 | FR-AU-07 |
| FR-EX-02 | Expense in friend or group context | P0 | 2 | FR-EX-01, FR-FR-01, FR-GR-01 |
| FR-EX-03 | Split methods: Equal, Unequal, Percentage, Shares, Exact | P0 | 5 | FR-EX-01 |
| FR-EX-04 | Validate splits sum to total; block save on mismatch | P0 | 2 | FR-EX-03 |
| FR-EX-05 | Attach receipt image (camera/gallery) to expense | P1 | 3 | FR-EX-01 |
| FR-EX-06 | Edit or delete own expense with real-time sync | P0 | 5 | FR-EX-01, FR-SE-04 |
| FR-EX-07 | Record edits and deletes in activity feed | P0 | 2 | FR-EX-06, FR-AC-01 |
| FR-EX-08 | Predefined expense categories with icons | P0 | 2 | FR-EX-01 |
| FR-EX-09 | INR symbol and Indian numbering format | P0 | 1 | — |

---

## Epic 6 — Settlements and Simplified Debts

| ID | Title | Priority | SP | Dependencies |
|---|---|---|---|---|
| FR-SE-01 | Display only Simplified Debts as canonical balance view | P0 | 3 | FR-SE-03 |
| FR-SE-02 | Deterministic min-transactions simplified-debts algorithm | P0 | 8 | — |
| FR-SE-03 | Cloud Function writes simplifiedBalances; client reads only | P0 | 5 | FR-SE-02 |
| FR-SE-04 | Atomic recomputation on expense/settlement write | P0 | 5 | FR-SE-03 |
| FR-SE-05 | Record settlement with pre-filled Settle Up UI | P0 | 3 | FR-SE-01 |
| FR-SE-06 | Real-time simplified balance update on settlement | P0 | 3 | FR-SE-04, FR-SE-05 |
| FR-SE-07 | Settle Up CTA on every non-zero balance screen | P0 | 2 | FR-SE-01 |
| FR-SE-08 | Settlement history per friend and per group | P0 | 3 | FR-SE-05, FR-FR-01, FR-GR-01 |
| FR-SE-09 | Send payment reminder (push, 1 per friend per 24h) | P1 | 3 | FR-SE-01, FR-AC-03 |

---

## Epic 7 — Activity Feed and Notifications

| ID | Title | Priority | SP | Dependencies |
|---|---|---|---|---|
| FR-AC-01 | Activity tab with chronological event feed | P0 | 5 | FR-AU-07 |
| FR-AC-02 | Deep-link from activity item to relevant screen | P0 | 3 | FR-AC-01 |
| FR-AC-03 | Push notifications via FCM for expenses, settlements, reminders | P0 | 5 | FR-AU-07 |
| FR-AC-04 | Notifications respect per-category preferences | P1 | 2 | FR-AC-03, FR-PR-03 |
| FR-AC-05 | Notification tap deep-links to relevant screen (incl. cold start) | P0 | 3 | FR-AC-03 |

---

## Epic 8 — Home Dashboard

| ID | Title | Priority | SP | Dependencies |
|---|---|---|---|---|
| FR-HD-01 | Overall net simplified balance as primary element | P0 | 3 | FR-SE-01 |
| FR-HD-02 | Top 5 friends/groups by balance with quick Settle Up | P0 | 3 | FR-SE-01, FR-FR-03, FR-GR-04 |
| FR-HD-03 | Current-month spend summary with category chart | P1 | 5 | FR-EX-01 |
| FR-HD-04 | Persistent FAB for adding expense from any tab | P0 | 2 | FR-EX-01 |

---

## Epic 9 — Search and Filters

| ID | Title | Priority | SP | Dependencies |
|---|---|---|---|---|
| FR-SR-01 | Search expenses by description, amount, category, member | P1 | 3 | FR-EX-01 |
| FR-SR-02 | Filter expenses by date range, group, category | P1 | 3 | FR-EX-01, FR-GR-01 |

---

## Epic 10 — Offline Support

| ID | Title | Priority | SP | Dependencies |
|---|---|---|---|---|
| FR-OF-01 | View cached expenses, friends, groups, balances offline | P0 | 3 | FR-AU-07 |
| FR-OF-02 | Queue expense/settlement writes offline; sync on reconnect | P1 | 5 | FR-EX-01, FR-SE-05 |
| FR-OF-03 | Last-write-wins conflict resolution with user notification | P1 | 3 | FR-OF-02, FR-SE-04 |

---

## Epic 11 — Sharing and Support

| ID | Title | Priority | SP | Dependencies |
|---|---|---|---|---|
| FR-SH-01 | All outbound sharing via system share sheet only | P0 | 2 | — |
| FR-SH-02 | Shared messages include deep link and store fallback URL | P0 | 2 | FR-SH-01 |
| FR-SH-03 | Contact Support mailto with Remote Config support address | P0 | 2 | FR-PR-05 |
| FR-SH-04 | Fallback dialog with copy button when no mail client | P1 | 1 | FR-SH-03 |

---

## Cross-Epic Dependencies

| Downstream FR | Upstream FR(s) | Rationale |
|---|---|---|
| FR-FR-01, FR-GR-01, FR-EX-01, FR-AC-01, FR-OF-01 | FR-AU-07 | All feature areas require an authenticated session. |
| FR-FR-02, FR-GR-02 | FR-SH-01 | Friend and group invitations use the system share sheet. |
| FR-FR-03, FR-GR-04, FR-HD-01, FR-HD-02, FR-SE-07 | FR-SE-01, FR-SE-03 | Balance display depends on the Cloud Function writing simplifiedBalances. |
| FR-SE-04 | FR-SE-02, FR-SE-03 | Atomic recomputation requires the algorithm and the Cloud Function to exist. |
| FR-EX-06, FR-SE-06 | FR-SE-04 | Edits, deletes, and settlements trigger recomputation. |
| FR-EX-07 | FR-AC-01 | Edit/delete audit entries write to the activity feed. |
| FR-AC-04 | FR-PR-03 | Notification filtering requires saved preferences. |
| FR-SE-09 | FR-AC-03 | Reminders are delivered as push notifications. |
| FR-OF-02, FR-OF-03 | FR-SE-04 | Offline sync triggers server-side recomputation on reconnect. |
| FR-PR-04 | FR-FR-01, FR-GR-01 | Friends/groups list on profile requires those features. |
| FR-SH-03 | FR-PR-05 | Sharing implementation of the Contact Support action. |

---

## Summary

### Story Points by Epic

| # | Epic | P0 SP | P1 SP | P2 SP | Total SP |
|---|---|---|---|---|---|
| 1 | Authentication and Onboarding | 18 | 5 | 0 | 23 |
| 2 | Profile Management | 7 | 5 | 0 | 12 |
| 3 | Friends | 12 | 2 | 0 | 14 |
| 4 | Groups | 20 | 0 | 0 | 20 |
| 5 | Expense Management | 24 | 3 | 0 | 27 |
| 6 | Settlements and Simplified Debts | 32 | 3 | 0 | 35 |
| 7 | Activity Feed and Notifications | 16 | 2 | 0 | 18 |
| 8 | Home Dashboard | 8 | 5 | 0 | 13 |
| 9 | Search and Filters | 0 | 6 | 0 | 6 |
| 10 | Offline Support | 3 | 8 | 0 | 11 |
| 11 | Sharing and Support | 6 | 1 | 0 | 7 |
| — | **Totals** | **146** | **40** | **0** | **186** |

### Story Points by Priority

| Priority | Count of FRs | Total SP |
|---|---|---|
| P0 | 46 | 146 |
| P1 | 16 | 40 |
| P2 | 0 | 0 |
| **Total** | **62** | **186** |

### Execution Guidance

- **P0 items (146 SP)** form the critical path for v1.0 launch readiness. No P0 may
  be deferred.
- **P1 items (40 SP)** are strongly desired for v1.0 but may be descoped to a
  fast-follow release if timeline pressure demands it, per SRS section 11.
- The **Settlements and Simplified Debts** epic (35 SP) is the highest-effort epic
  and the algorithmic core of the product. It should be staffed and started early;
  the Cloud Function (FR-SE-02 through FR-SE-04) is on the critical path for nearly
  every balance-related screen.
- **Authentication and Onboarding** (23 SP) must be completed first as it gates all
  other epics.
- **Sharing and Support** (7 SP) and **Search and Filters** (6 SP) are the
  lowest-effort epics and can be parallelised late in the schedule.
