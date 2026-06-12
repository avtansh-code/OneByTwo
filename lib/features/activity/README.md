# Activity

Feature-folder that owns the Activity Feed (SCR-25): a real-time,
read-only chronological list of the current user's expense and
settlement events (FR-AC-01) with deep-link navigation into the relevant
detail screen (FR-AC-02).

The feed reads `activity/{userId}/items`, a per-user subcollection
populated **server-side** by the activity fan-out trigger (FR-EX-07);
the client never writes to it.

## Implemented scope

### FR-AC-01 — Activity feed

- `domain/activity_event_type.dart` — `ActivityEventType` enum plus
  `ActivityEventTypeX.parseSnakeCase`, which converts the Firestore
  snake_case `type` discriminator and returns `null` for unknown values.
- `domain/activity_feed_item.dart` — `ActivityFeedItem` (`id`, `type`,
  `payload`, `createdAt`). The `payload` is deliberately schemaless and
  varies by `type`. Its strict `fromFirestore` factory returns `null`
  (via an `onParseFailure` sink) for an unknown / missing `type` or a
  non-map payload, mirroring `FriendshipDoc.fromFirestore`.
- `data/activity_feed_repository.dart` — the abstract
  `ActivityFeedRepository`, `FirestoreActivityFeedRepository`, the
  `ActivityParseFailureSink` typedef (routes malformed-item breadcrumbs
  through `developer.log`), and `activityFeedRepositoryProvider`.
  `watchItems(userId)` streams `activity/{userId}/items` ordered by
  `createdAt` descending, silently dropping malformed entries.
- `application/activity_feed_provider.dart` — `activityFeedProvider`
  (`StreamProvider<List<ActivityFeedItem>>`), which reads the UID from
  `currentUserIdProvider` and projects the repository stream into an
  unmodifiable list.
- `application/relative_timestamp_formatter.dart` —
  `formatRelativeTimestamp(...)`, a pure function rendering "Just now" /
  "X min ago" / "Yesterday" / `dd MMM` / `dd MMM yyyy` with all
  wall-clock comparisons performed in IST (UTC+05:30) per SRS §5.9.
- `presentation/activity_feed_screen.dart` — `ActivityFeedScreen`
  (`ConsumerStatefulWidget`), the SCR-25 screen rendering five states:
  loading (skeleton), populated (`ListView` of `OBTActivityRow`), empty,
  error (with Retry), and refreshing (pull-to-refresh). It resolves the
  other party's display name via `userProfileProvider` (friends feature).
- `presentation/widgets/activity_feed_skeleton.dart` —
  `ActivityFeedSkeleton`, the five-row loading placeholder.

### FR-AC-02 — Deep-link navigation

Row taps route through the shared `core/routing/notification_deep_links.dart`
resolver: `expenseAdded` / `expenseEdited` → `ExpenseDetailScreen`;
`settlementRecorded` → `FriendDetailScreen`; `expenseDeleted` → a
"no longer available" snackbar.

Telemetry:

- `activity_feed_viewed` — once per session in the populated / empty
  state.
- `activity_item_tapped` — every row tap.
- `activity_feed_refreshed` — pull-to-refresh.
- `activity_feed_error` — on stream error.

Friendship composite UIDs are hashed via `hashFriendshipId`; expense and
settlement IDs are opaque scalar IDs (not subject to ADR-0013 hashing).

## Layout

```
application/
  activity_feed_provider.dart          # StreamProvider<List<ActivityFeedItem>>
  relative_timestamp_formatter.dart    # pure IST relative-time formatter
data/
  activity_feed_repository.dart        # abstract repo + Firestore impl + provider
domain/
  activity_event_type.dart             # enum + parseSnakeCase
  activity_feed_item.dart              # strict-parsing value type
presentation/
  activity_feed_screen.dart            # SCR-25, five states
  widgets/
    activity_feed_skeleton.dart        # 5-row loading skeleton
```

## Invariants honoured

- **Invariant 1 (integer paise):** monetary fields in the payload remain
  `int`; `OBTActivityRow` renders them via `formatInrFromPaise`. The
  boundary-contract grep at
  `test/features/activity/activity_boundary_contract_test.dart` enforces
  no `.toDouble()` / `/ 100` on the read path.
- **Invariant 2 (`simplifiedBalances` server-maintained):** this feature
  reads `activity/{uid}/items`, never `simplifiedBalances`, and performs
  no writes (the activity collection rules permit server-only writes).
- **Invariant 3 (system share sheet only):** N/A.
- **Invariant 4 (single Firebase project):** all reads go through the
  single production project; pre-merge verification runs against the
  Firebase Emulator Suite.

## Hand-off boundaries

- **In (read-only):** `activity/{userId}/items` documents are written by
  the FR-EX-07 server-side fan-out trigger; this feature is read-only.
- **In (shared):** deep-link routing reuses
  `core/routing/notification_deep_links.dart` (the same resolver the
  notifications feature uses); display-name resolution reuses
  `features/friends/application/user_profile_provider.dart`.
- **Out:** row taps push `ExpenseDetailScreen` (expenses feature) and
  `FriendDetailScreen` (friends feature).
