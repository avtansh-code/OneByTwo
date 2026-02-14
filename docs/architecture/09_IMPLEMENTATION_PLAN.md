# One By Two — Implementation Plan

> **Version:** 1.1  
> **Last Updated:** 2026-02-14

---

## 1. Phased Delivery Strategy

The project is delivered in **3 phases** aligned with the priority levels in the requirements document. Each phase is further broken into sprints with clear deliverables.

```
┌─────────────────────────────────────────────────────────────────┐
│                   DELIVERY TIMELINE                              │
│                                                                  │
│  Phase 1: MVP (P0)                                              │
│  ├── Sprint 1: Foundation & Auth                                │
│  ├── Sprint 2: Groups & Members                                 │
│  ├── Sprint 3: Expenses & Splits                                │
│  ├── Sprint 4: Balances & Settlements                           │
│  ├── Sprint 5: Offline Sync & Notifications                    │
│  ├── Sprint 6: Search, Analytics & Activity                     │
│  └── Sprint 7: Polish, Testing & Launch Prep                    │
│                                                                  │
│  Phase 2: Enhanced (P1)                                         │
│  ├── Sprint 8: Itemized Splits & Receipts                      │
│  ├── Sprint 9: Recurring Expenses & Roles                       │
│  ├── Sprint 10: Nudge, Export & Preferences                     │
│  └── Sprint 11: Web App (PWA)                                   │
│                                                                  │
│  Phase 3: Premium (P2)                                          │
│  ├── Sprint 12: Receipt OCR & Advanced Analytics                │
│  └── Sprint 13: Tags, Bulk Entry & Monetization                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Phase 1 — MVP (P0 Features)

### Sprint 1: Foundation & Auth

**Goal:** Project setup, CI/CD, authentication flow

| Task ID | Task | Description |
|---------|------|-------------|
| S1-01 | Flutter project initialization | Create Flutter project with flavors (dev, staging, prod), configure build settings for iOS 17+ / Android 15+ |
| S1-02 | Firebase projects setup | Create 3 Firebase projects (dev, staging, prod) in asia-south1. Configure Auth, Firestore, Cloud Functions, Storage, FCM |
| S1-03 | Architecture scaffolding | Set up Clean Architecture folder structure (core, data, domain, presentation). Configure Riverpod, GoRouter, sqflite |
| S1-04 | CI/CD pipeline | GitHub Actions: lint, analyze, test, build APK/IPA. Firebase deployment for rules and Cloud Functions |
| S1-05 | App theme & design system | Implement Material 3 theme, colors, typography. Light/dark mode. Shared widgets (loading, error, empty state) |
| S1-06 | Local database setup | sqflite initialization, migration system, encryption (SQLCipher). All table DDLs |
| S1-07 | Auth: Phone OTP flow | Firebase Auth phone login. Screens: Welcome, Phone Input, OTP Verification |
| S1-08 | Auth: Profile setup | Profile creation screen (name, email, avatar). User entity, model, mapper, DAO, Firestore source, repository |
| S1-09 | Auth: Session management | Auto-login, sign-out, auth state Riverpod provider, GoRouter redirect guard |
| S1-10 | Auth: Account deletion | GDPR-compliant account deletion (Cloud Function + client flow) |

**Deliverable:** User can sign up with phone OTP, create profile, sign in/out across sessions.

---

### Sprint 2: Groups & Members

**Goal:** Group CRUD, member management, invite links

| Task ID | Task | Description |
|---------|------|-------------|
| S2-01 | Group entity & data layer | Group entity, model, mapper, DAO, Firestore source, repository (full stack) |
| S2-02 | Create group screen | UI for creating group (name, category, cover photo). Category selector (trip, home, couple, event, other) |
| S2-03 | Group list (Home screen) | Home dashboard with group cards showing name, category, balance summary. Pinned groups first, then by recent activity |
| S2-04 | Group detail screen | Tabbed screen (Expenses, Balances, Settle Up). Group header with member count and total |
| S2-05 | Member management | Add/remove members. Member list with roles. GroupMember entity and full data layer |
| S2-06 | Invite via link | Generate invite Cloud Function. Share link (via share sheet). Join via invite screen. Deep link handling (GoRouter) |
| S2-07 | Guest users | Join as guest (name only, no account). Guest entity handling. Guest badge in member list |
| S2-08 | Group settings | Archive group, edit group details, manage members screen |
| S2-09 | Firestore security rules | Implement and test rules for users, groups, members collections |
| S2-10 | Group sync | Firestore listeners for groups and members. Local DB updates on remote changes |

**Deliverable:** User can create groups, invite members via link, manage group settings.

---

### Sprint 3: Expenses & Splits

**Goal:** Core expense entry with all split types

| Task ID | Task | Description |
|---------|------|-------------|
| S3-01 | Expense entity & data layer | Expense, ExpensePayer, ExpenseSplit entities, models, mappers, DAOs, Firestore sources, repository |
| S3-02 | Add expense screen | Amount input (large, auto-focused), description, date picker, category picker. FAB from home + group detail |
| S3-03 | Payer selection | Single payer selector (default: current user). Avatar-based picker with group members |
| S3-04 | Equal split | Default split type. Auto-calculate per-person amount. Participant toggle (include/exclude members) |
| S3-05 | Exact amount split | Manual amount input per person. Running total with balance check |
| S3-06 | Percentage split | Percentage input per person. Auto-calculate amounts. Validation: must sum to 100% |
| S3-07 | Shares split | Share count per person. Auto-calculate proportional amounts |
| S3-08 | Split preview | Visual preview showing each person's share. Balance indicator (total assigned vs expense amount) |
| S3-09 | Expense detail screen | View full expense details, split breakdown, audit info (created by, modified by) |
| S3-10 | Edit expense | Edit all expense fields. Version increment. Audit trail (before/after in activity log) |
| S3-11 | Delete expense | Soft delete with 30-second undo snackbar. Sync deletion to Firestore |
| S3-12 | Expense sync | Firestore listeners for expenses. Write-local-first. Sync queue for offline writes |
| S3-13 | Non-group expenses | Expense between two individuals (no group). Direct 1:1 expense entry |
| S3-14 | Friend pair entity & data layer | FriendPair entity, model, mapper, DAO, Firestore source, repository. Canonical pair ID generation |
| S3-15 | Add friend screen | Search users by phone/name. Create friend pair via Cloud Function (addFriend callable) |
| S3-16 | Friend detail screen | Display 1:1 expenses with friend, net balance, settle up. Tabs: Expenses, Settle Up |
| S3-17 | Dashboard friends section | MY FRIENDS section on home with balance per friend. Navigation to Friend Detail |
| S3-18 | Context chooser | When FAB tapped from home, show Group vs Friend context selector before Add Expense |
| S3-19 | 1:1 expense split | Add expense in friend context. Both users pre-selected. All split types supported (equal, exact, percentage, shares, itemized) |
| S3-20 | Friend Cloud Functions | onFriendExpenseCreated/Updated/Deleted triggers. 1:1 balance recalculation. userFriends denormalization |
| S3-21 | Friend settlement | Record settlement between friends. nudgeFriend callable. settleFriend callable |
| S3-22 | Friend security rules | Firestore rules for friends/{pairId}/**, userFriends/{uid}/**. isFriendPairMember() helper |

**Deliverable:** Full expense entry with equal, exact, percentage, and shares splits. 1:1 friend expense tracking.

---

### Sprint 4: Balances & Settlements

**Goal:** Balance calculation, debt simplification, settlement recording (group + friend)

| Task ID | Task | Description |
|---------|------|-------------|
| S4-01 | Balance calculation engine | Local balance recalculation from all expenses and settlements. Pairwise balance storage. Friend balance (single scalar) |
| S4-02 | Balance Cloud Function | Server-side balance recalculation triggered by expense/settlement writes. Update groups/{gid}/balances/ and friends/{fid}/balance/ |
| S4-03 | Debt simplification algorithm | Implement greedy net-balance algorithm. Unit tests for correctness (5+ test cases) |
| S4-04 | Balances tab (Group Detail) | Display pairwise balances. Show simplified debts. Color coding (red: owe, green: owed) |
| S4-05 | Overall balance (Home) | Aggregate balance across all groups and friends. Summary card on home screen |
| S4-06 | Settlement entity & data layer | Settlement entity, model, DAO, Firestore source, repository |
| S4-07 | Record settlement screen | From/To picker, amount (pre-filled from suggestion), date, notes. Confirmation |
| S4-08 | Settle up tab | Suggested settlements from debt simplification. One-tap "Record Payment" |
| S4-09 | Settle All | Batch record all suggested settlements. Cloud Function for atomic batch write |
| S4-10 | Settlement notifications | Push notification to recipient when payment is recorded |

**Deliverable:** Users can view balances, see simplified debts, and record settlements.

---

### Sprint 5: Offline Sync & Notifications

**Goal:** Robust offline-first experience, push notifications

| Task ID | Task | Description |
|---------|------|-------------|
| S5-01 | Sync engine implementation | SyncEngine class: queue processing, retry with exponential backoff, connectivity monitoring |
| S5-02 | Sync queue | sync_queue table operations. Enqueue on every local write. Process on connectivity change |
| S5-03 | Conflict resolution | Version-based conflict detection. Last-write-wins for non-critical fields. User prompt for amount conflicts |
| S5-04 | Sync status UI | Per-entity sync badges (✓ ↑ ⚠). Global sync progress bar. Offline banner |
| S5-05 | Firestore listener manager | Register/dispose listeners per screen via Riverpod. Pull remote changes into local DB |
| S5-06 | Manual sync trigger | Pull-to-refresh triggers full sync. Sync button in settings |
| S5-07 | FCM setup | Firebase Cloud Messaging initialization. Token management. Permission request flow |
| S5-08 | Push notification triggers | Cloud Functions: send push on expense added, edited, deleted, settlement recorded |
| S5-09 | In-app notification center | Notification list screen. Mark as read. Tap to navigate to entity |
| S5-10 | Notification preferences | Per-type toggle (expenses, settlements, reminders). Store in user profile |

**Deliverable:** App works fully offline with transparent sync. Push notifications for key events.

---

### Sprint 6: Search, Analytics & Activity

**Goal:** Search, filtering, spending insights, activity feed

| Task ID | Task | Description |
|---------|------|-------------|
| S6-01 | Search screen | Full-text search across expenses, groups, people. Local sqflite LIKE queries |
| S6-02 | Expense filters | Filter by: date range, category, payer, group, amount range. Filter chips UI |
| S6-03 | Expense sorting | Sort by: date, amount, category. Toggle ascending/descending |
| S6-04 | Category breakdown | Pie chart of spending by category. Filter by group and date range. fl_chart package |
| S6-05 | Group spending summary | Total expenses, per-member breakdown, category distribution per group |
| S6-06 | Activity log | Cloud Function writes activity on every expense/settlement/member change |
| S6-07 | Group activity feed | Chronological activity list in Group Detail. ActivityLog entity and data layer |
| S6-08 | Global activity feed | Activity feed tab in bottom nav. Aggregated across all groups |
| S6-09 | Expense audit trail | Per-expense change history. Show "created by", "last modified by", change diffs |
| S6-10 | Performance optimization | Lazy loading, pagination for large lists. Profile with DevTools. Target: smooth 60fps scroll |

**Deliverable:** Users can search, filter, view analytics and full activity history.

---

### Sprint 7: Polish, Testing & Launch Prep

**Goal:** Production readiness, comprehensive testing, store submission

| Task ID | Task | Description |
|---------|------|-------------|
| S7-01 | Unit tests | 80%+ coverage on domain layer (entities, use cases, algorithms). Split calculation tests |
| S7-02 | Widget tests | All core widgets: expense card, balance card, split preview, amount input |
| S7-03 | Integration tests | End-to-end: add expense → verify balance → settle up. Firebase Emulator Suite |
| S7-04 | Offline scenario tests | Add/edit/delete offline → sync → verify. Conflict resolution scenarios |
| S7-05 | Security rules tests | Firestore and Storage rules unit tests. Positive and negative cases |
| S7-06 | Performance testing | Cold start < 2s, expense save < 500ms, balance recalc < 1s. Measure on mid-range device |
| S7-07 | Accessibility | Screen reader labels (Semantics). Dynamic text sizing. Minimum tap targets 48x48 |
| S7-08 | Internationalization | All strings externalized to ARB files. English + Hindi translations |
| S7-09 | App store preparation | Screenshots, descriptions, privacy policy, app icons, splash screen |
| S7-10 | Production deployment | Deploy to prod Firebase. Release build (obfuscated). TestFlight + Play Internal Testing |
| S7-11 | Monitoring setup | Crashlytics dashboards. Analytics events. Performance monitoring baselines |

**Deliverable:** Production-ready MVP submitted to App Store and Play Store.

---

## 3. Phase 2 — Enhanced (P1 Features)

### Sprint 8: Itemized Splits & Receipts

| Task ID | Task | Description |
|---------|------|-------------|
| S8-01 | Itemized split UI | Add bill items screen. Item name, amount, assign-to-people picker |
| S8-02 | Itemized calculation | Tax/tip proportional distribution. Per-person total preview |
| S8-03 | ExpenseItem data layer | ExpenseItem entity, model, DAO, Firestore source |
| S8-04 | Receipt photo attachment | Image picker (camera/gallery). Compress, save locally, display in expense detail |
| S8-05 | Receipt upload pipeline | Cloud Storage upload. Resumable. Offline queue. Download URL in Firestore |
| S8-06 | Receipt viewer | Full-screen image viewer. Pinch to zoom. Download option |

### Sprint 9: Recurring Expenses & Roles

| Task ID | Task | Description |
|---------|------|-------------|
| S9-01 | Recurring expense UI | Frequency picker (daily/weekly/monthly/yearly). End date (optional). Toggle on expense form |
| S9-02 | Recurring Cloud Function | Scheduled function: process due recurring expenses daily. Create instances, update next date |
| S9-03 | Group roles & permissions | Owner/Admin/Member role assignment. Configurable edit/delete permissions |
| S9-04 | Role-based UI guards | Show/hide edit/delete buttons based on role. Permission checks in repository |
| S9-05 | Multiple payers | Multi-payer selector. Amount input per payer. Split-the-payment feature |
| S9-06 | Duplicate expense | One-tap duplicate with new date. Pre-filled form |
| S9-07 | Draft auto-save | Save partial expense to drafts table on back/close. Resume on re-open |
| S9-08 | Pin/favorite groups | Toggle pin on group. Pinned groups shown first on home |

### Sprint 10: Nudge, Export & Preferences

| Task ID | Task | Description |
|---------|------|-------------|
| S10-01 | Nudge feature | "Remind" button on balance. Cloud Function sends push to debtor. Rate limited (3/day per pair) |
| S10-02 | Settlement reminders | Scheduled function: weekly reminder for pending debts > 7 days |
| S10-03 | Data export (CSV) | Cloud Function generates CSV of expenses. Download via URL |
| S10-04 | Settlement summary export | Generate settlement summary as shareable image/PDF |
| S10-05 | Notification preferences | Per-group, per-type notification toggles. Weekly digest opt-in |
| S10-06 | Monthly spending trend | Line chart of monthly spending. fl_chart. Filter by group |
| S10-07 | Personal monthly summary | Summary card: total spent, top category, group breakdown |
| S10-08 | Phone number change | OTP verification on new number. Update across all references |
| S10-09 | Contact book integration | Find friends on app via contact matching. Invite from contacts |
| S10-10 | Biometric/PIN lock | local_auth integration. PIN setup flow. Auto-lock on background |

### Sprint 11: Web App (PWA)

| Task ID | Task | Description |
|---------|------|-------------|
| S11-01 | Flutter Web build | Configure Flutter Web. Responsive layout for desktop/tablet |
| S11-02 | PWA setup | Service worker, manifest, offline caching |
| S11-03 | Firebase Hosting | Deploy to Firebase Hosting. Custom domain setup |
| S11-04 | Web-specific adaptations | Mouse/keyboard navigation. Responsive breakpoints. No native features fallback |

---

## 4. Phase 3 — Premium (P2 Features)

### Sprint 12: Receipt OCR & Advanced Analytics

| Task ID | Task | Description |
|---------|------|-------------|
| S12-01 | Receipt OCR | Google Cloud Vision API via Cloud Function. Extract amount and line items |
| S12-02 | OCR result mapping | Auto-populate expense form from OCR results. User correction flow |
| S12-03 | Advanced analytics | Detailed charts: spending trends, group comparisons, category deep-dive |
| S12-04 | High contrast mode | Accessibility theme with high contrast colors |
| S12-05 | Haptic feedback | Haptic response on key actions (save, delete, settle) |

### Sprint 13: Tags, Bulk Entry & Monetization

| Task ID | Task | Description |
|---------|------|-------------|
| S13-01 | Expense tags | Custom tag input (#day1, #hotel). Tag-based filtering |
| S13-02 | Bulk expense entry | Quick-add mode: rapid sequential expense entry without leaving screen |
| S13-03 | Custom categories | User-defined categories with custom icons/colors |
| S13-04 | Pro subscription (IAP) | In-app purchase flow (RevenueCat). Entitlement checks. Paywall UI |
| S13-05 | Wi-Fi only sync | Setting to restrict sync to Wi-Fi. Connectivity service update |
| S13-06 | Weekly/monthly digest | Scheduled Cloud Function compiles spending digest. Push notification |

---

## 5. Testing Strategy Per Sprint

Each sprint includes testing as part of the deliverable:

| Test Type | When | Tool |
|-----------|------|------|
| Unit tests | Written with each feature (TDD where possible) | flutter_test |
| Widget tests | Written for each new screen/widget | flutter_test |
| Integration tests | End of each sprint (critical flows) | integration_test + Firebase Emulator |
| Security rules tests | Whenever rules change | @firebase/rules-unit-testing |
| Manual QA | End of each sprint | Physical devices (iOS + Android) |

---

## 6. Definition of Done (Per Task)

A task is "done" when:

1. ✅ Code implemented and compiles without errors
2. ✅ Unit tests pass (80%+ coverage for domain logic)
3. ✅ Widget tests pass for new UI components
4. ✅ No lint warnings (`flutter analyze` clean)
5. ✅ Works offline (if applicable)
6. ✅ Sync works correctly (if applicable)
7. ✅ Firestore security rules cover the new data
8. ✅ Accessibility: screen reader labels, min tap targets
9. ✅ Strings externalized for i18n
10. ✅ Code reviewed and merged to main branch

---

## 7. Key Flutter Dependencies

| Package | Purpose | Sprint |
|---------|---------|--------|
| `flutter_riverpod` + `riverpod_annotation` | State management | S1 |
| `go_router` | Navigation & deep linking | S1 |
| `sqflite` + `sqflite_sqlcipher` | Local database | S1 |
| `shared_preferences` | App settings | S1 |
| `firebase_core` | Firebase initialization | S1 |
| `firebase_auth` | Phone/OTP authentication | S1 |
| `cloud_firestore` | Firestore SDK | S1 |
| `firebase_storage` | File uploads | S8 |
| `firebase_messaging` | Push notifications | S5 |
| `firebase_crashlytics` | Crash reporting | S1 |
| `firebase_analytics` | Usage analytics | S1 |
| `firebase_remote_config` | Feature flags | S1 |
| `flutter_secure_storage` | Secure token storage | S1 |
| `connectivity_plus` | Network state monitoring | S5 |
| `uuid` | ID generation | S1 |
| `intl` | Internationalization & formatting | S1 |
| `flutter_local_notifications` | Local notifications | S5 |
| `image_picker` | Camera/gallery image selection | S8 |
| `flutter_image_compress` | Image compression | S8 |
| `cached_network_image` | Image caching & display | S2 |
| `fl_chart` | Charts (pie, bar, line) | S6 |
| `share_plus` | Share sheet (invite links) | S2 |
| `local_auth` | Biometric authentication | S10 |
| `path_provider` | File system paths | S1 |
| `logger` | Structured logging | S1 |
| `freezed` + `json_serializable` | Immutable models & JSON | S1 |
| `build_runner` | Code generation | S1 |

---

## 8. Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Offline sync conflicts at scale | Data inconsistency | Version-based conflict detection; user-prompted resolution for critical fields |
| Firestore read/write cost overrun | Budget | Aggressive local caching; listener management; pagination; cost monitoring alerts |
| Cold start > 2s | Poor first impression | Parallel initialization; minimal splash work; lazy-load non-critical services |
| OTP delivery failures | User can't sign up | Firebase Auth fallback; error messages with retry; support contact |
| Large group performance (50+ members) | Slow balance calculation | Server-side calculation in Cloud Function; cached balances; pagination |
| App size > 30MB | Store rejection / slow download | Tree-shaking; deferred loading; asset optimization; track with CI |
| Store rejection (Apple/Google) | Launch delay | Follow platform guidelines; no undisclosed data collection; privacy policy |
