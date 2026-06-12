# Offline Support and Sync Design

> Addresses SRS section 4.10 (FR-OF-01 through FR-OF-03) and architectural
> decision ADR-0014 (Offline Persistence Strategy). Cross-references SRS
> section 7.3 (Key Architectural Decisions) and section 7.5 (Security Rules
> Principles).

> **Implementation status (current code).** This document describes the
> intended design. Against the present client code:
>
> - **Persistence is the SDK default, not an explicit setting.** Firestore
>   offline persistence is enabled by default on iOS and Android.
>   `lib/main.dart` does **not** call `Settings(persistenceEnabled: …)` or
>   set `cacheSizeBytes`; the behaviour below holds because the SDK default
>   is "persistence on". Any mention of `settings.persistenceEnabled = true`
>   below is the SDK default, not a configuration call in the codebase.
> - **There is no persistent global "offline banner" and no continuous
>   connectivity stream.** The only connectivity surface is
>   `lib/core/connectivity/connectivity_provider.dart`, a **one-shot**
>   `connectivityCheckProvider` (`Provider<IsOnline>`) read at write time.
>   Offline feedback is delivered as per-action snackbars (see §2.2).
> - **Client-side conflict detection/notification (§4.2) is not yet
>   implemented.** Firestore's last-write-wins default applies, but the
>   client does not compare local vs. server state or surface a conflict
>   snackbar.
> - **Emulator network-toggle integration tests (§6) are planned, not
>   present.** No `disableNetwork()` / `enableNetwork()` / `isFromCache`
>   call exists in `lib/` or `test/` today; offline behaviour is exercised
>   via `connectivityCheckProvider` overrides in unit/widget tests.

---

## 1. Local Cache Strategy

### 1.1 Firestore SDK Persistent Cache (ADR-0014)

The application relies exclusively on the Firestore SDK's built-in offline
persistence as the sole local data store. No secondary persistence layer
(Hive, Isar, SQLite) is introduced. This decision is recorded in ADR-0014
and is motivated by three factors:

1. The SRS offline requirements (FR-OF-01, FR-OF-02, FR-OF-03) map directly to
   capabilities the Firestore cache already provides — cached reads, queued
   writes, and last-write-wins conflict resolution.
2. A parallel data layer would create cache-invalidation complexity and risk
   consistency conflicts with Firestore's own cache.
3. Keeping a single cache source eliminates an entire class of bugs around
   stale-data divergence between two stores.

### 1.2 Cache Size Configuration

The Firestore cache size is left at the **SDK default**; `lib/main.dart`
does not set `cacheSizeBytes`. This is sufficient for the v1.0 data model,
which consists of lightweight JSON documents (expenses, settlements,
friendships, groups). Should telemetry indicate cache eviction pressure on
low-storage devices, the limit can be raised or set to
`CACHE_SIZE_UNLIMITED` via a `Settings` override (and optionally gated
behind a Remote Config flag) in a future release.

### 1.3 What Is Cached

The Firestore SDK caches every document that the client has read through a
snapshot listener or a one-shot `get()` call. For One By Two this includes:

- User profile documents.
- Friendship documents (including their `simplifiedBalances` maps).
- Expense and settlement documents for friendships the user has opened.
- Activity-feed entries the user has scrolled through.

Group documents carry a `simplifiedBalances` map server-side, but the client
has no Groups feature yet (see `lib/features/groups/README.md`), so group
documents are not read or cached by the app today.

### 1.4 What Is NOT Cached by Firestore

- **Images** (profile photos, receipt attachments) are stored in Firebase
  Storage. Their caching is managed entirely by `cached_network_image`
  (ADR-0011), which maintains its own disk and memory cache independent of
  Firestore.
- **Remote Config values** are fetched and cached by the Remote Config SDK with
  its own TTL; they are not part of the Firestore cache.

---

## 2. Offline Read Behaviour (FR-OF-01)

FR-OF-01 (P0) requires that users can view previously-loaded expenses, friends,
groups, and simplified balances when offline.

### 2.1 Cached Data Serving

When the device has no network connectivity, the Firestore SDK serves all
previously-fetched documents from its local cache. Snapshot listeners continue
to emit the most recent cached state, so Riverpod `AsyncValue` providers
transition normally and the UI renders without error.

### 2.2 Connectivity Signalling (per-action snackbars)

There is **no persistent global "Offline" banner** and no continuous
connectivity-state stream in the current client. Connectivity is surfaced
through a single, one-shot helper:

- `lib/core/connectivity/connectivity_provider.dart` exposes
  `connectivityCheckProvider`, a `Provider<IsOnline>` where
  `typedef IsOnline = Future<bool> Function()`. It performs a one-shot
  reachability check and is read at **write time** by controllers that want
  to tailor their messaging. On any error it assumes the device is online so
  that the Firestore write path is never blocked.

When a controller detects (or infers) that a write was made offline, it
surfaces a brief, per-action snackbar rather than a global banner. Examples
in the current code:

- **Notification preferences** — `notification_preferences_controller.dart`
  raises a one-shot `offlineWriteJustQueued` latch and the screen shows
  "You are offline. Changes will sync when you reconnect."
- **Settle Up** — the settlement flow shows an offline-aware error snackbar,
  "You're offline. The settlement will be recorded when you reconnect.",
  when the write is queued without server acknowledgement.

A persistent offline banner backed by a continuous connectivity stream
remains a possible future enhancement; it is not implemented today.

### 2.3 Real-Time Listener Behaviour

Firestore real-time listeners (`snapshots()`) do not throw errors when the
network is unavailable. They continue to emit the last-known server snapshot
with `SnapshotMetadata.isFromCache == true`. The UI does not branch on
`isFromCache` at the data layer, and there is no global offline indicator;
offline feedback is delivered only by the per-action snackbars described in
§2.2.

---

## 3. Pending Write Queue (FR-OF-02)

FR-OF-02 (P1) requires that users can add expenses and settlements while
offline, with automatic sync on reconnection and simplified-balance
recomputation.

### 3.1 Automatic Write Queueing

The Firestore SDK queues all write operations (set, update, delete) locally
when the device is offline. No application-level queue is needed. Writes are
stored in the SDK's internal persistence layer and survive app restarts,
provided the app was not force-cleared from device storage.

### 3.2 Persistence Across App Restarts

Because Firestore persistence is enabled (the SDK default on iOS and
Android), pending writes are persisted to disk. If the user kills the app,
restarts the device, and later opens the app with connectivity, all queued
writes are transmitted to Firestore in the order they were issued.

### 3.3 Sync and Cloud Function Triggers

When connectivity returns, the Firestore SDK replays queued writes to the
server. Each write that creates, updates, or deletes an expense or settlement
document triggers the `recomputeSimplifiedBalances` Cloud Function (SRS
section 7.3). The function runs inside a Firestore transaction, reading all
non-deleted expenses and settlements for the affected context (group or
friendship) and writing the recomputed `simplifiedBalances` map.

If multiple queued writes affect the same group or friendship, each write
triggers the function independently. The function is idempotent and
transactional, so the final `simplifiedBalances` state is always consistent
with the full set of committed documents.

### 3.4 Optimistic UI Updates

While a write is pending, the Firestore SDK applies the write to the local
cache immediately. Snapshot listeners emit the optimistic state, so the user
sees their new expense or settlement in the list instantly. If the write
ultimately fails on the server (e.g., due to a security rule rejection), the
local cache rolls back and the listener emits the corrected state. The
controller surfaces a snackbar informing the user that the write could not be
saved (for example, the Settle Up flow distinguishes an offline-queued write
from a hard failure — see §2.2).

---

## 4. Conflict Resolution (FR-OF-03)

FR-OF-03 (P1) requires last-write-wins conflict resolution with user
notification when a write is overridden, and simplified-balance recomputation
after every resolution.

### 4.1 Last-Write-Wins Semantics

Firestore's default conflict resolution strategy is last-write-wins at the
document level, keyed by server timestamp. This is the behaviour One By Two
adopts; no custom conflict resolution logic is implemented.

When two users edit the same document concurrently (one online, one offline),
the write that reaches the server last overwrites the previous value. The
`recomputeSimplifiedBalances` function fires on each write, so the final
balances always reflect the last-committed state.

### 4.2 User Notification Mechanism

> **Not yet implemented.** The mechanism below is the intended design.
> The current client does **not** compare local writes against post-sync
> snapshots, does not detect overridden writes, and does not raise a
> conflict snackbar. Firestore's last-write-wins default (§4.1) applies and
> `recomputeSimplifiedBalances` keeps balances consistent, but no
> client-side conflict notification ships today.

When a user's offline write is overridden by a concurrent write from another
user, the application is intended to notify the affected user as follows:

1. **Detection:** The client compares the document state returned by the
   snapshot listener after sync with the state the user wrote locally. If the
   fields the user edited differ from what the listener returns, a conflict has
   occurred.

2. **Notification — Snackbar:** A snackbar is displayed with the message:
   "An expense you edited was updated by another member. The latest version is
   now showing." The snackbar includes a "View" action that scrolls to or
   navigates to the affected expense.

3. **Notification — Activity Feed Entry:** The standard activity-feed entry for
   the conflicting edit (e.g., "Priya edited 'Dinner at Bandra'") serves as
   the persistent record. No additional activity-feed entry type is created for
   conflicts; the existing edit-event entry is sufficient.

The snackbar approach is preferred over a dialog because conflicts are expected
to be rare and non-blocking; a dialog would interrupt the user's flow
unnecessarily.

### 4.3 Simplified-Balance Recomputation

After every conflict resolution, the `recomputeSimplifiedBalances` function
runs as part of the normal Firestore trigger pipeline (SRS section 7.3). The
function operates within a transaction, so concurrent recomputation calls are
serialised. The final `simplifiedBalances` map is always consistent with the
committed document set.

Clients never write to `simplifiedBalances` (Invariant 2; SRS section 7.5).
They observe the recomputed value through their snapshot listeners once the
Cloud Function completes.

---

## 5. Edge Cases

### 5.1 Concurrent Offline and Online Expense Addition

**Scenario:** User A adds an expense to a group while offline. User B adds a
different expense to the same group while online.

**Behaviour:** These are writes to different documents, so no conflict occurs.
When User A reconnects, their expense document is created on the server. The
`recomputeSimplifiedBalances` function fires for User A's write and
recomputes balances incorporating both expenses. User A's snapshot listeners
receive the updated group state including User B's expense and the recomputed
`simplifiedBalances`.

### 5.2 Offline Settlement with Balance Change

**Scenario:** User A records a settlement while offline. Meanwhile, User B
adds a new expense that changes the balance between A and B.

**Behaviour:** Both writes succeed (they are separate documents). The
settlement amount recorded by User A reflects the balance at the time User A
went offline, which may no longer match the actual balance after User B's
expense. The `recomputeSimplifiedBalances` function recomputes the net
balances from all expenses and settlements, producing the correct result.
The UI updates accordingly when User A's listeners receive the new
`simplifiedBalances`.

No automatic adjustment of the settlement amount occurs. If the settlement
was for a specific amount, that amount stands. The user is expected to review
the updated balances and record a further settlement if needed.

### 5.3 Long Offline Period (Days)

**Scenario:** A user is offline for several days and returns to the app.

**Behaviour:** On reconnection, the Firestore SDK replays all queued writes
and re-establishes snapshot listeners. The listeners receive the full current
server state, replacing the stale cache. If the cache has been evicted (due to
the SDK's cache-size limit or device storage pressure), the SDK fetches fresh
data from the server.

There is no staleness indicator and no offline banner; once connectivity is
restored and listeners have caught up, the UI reflects the current server
state. No special "catch-up" screen or reconciliation flow is presented.

### 5.4 App Killed While Writes Are Queued

**Scenario:** The user adds an expense offline and then force-kills the app
before reconnecting.

**Behaviour:** The Firestore SDK persists pending writes to disk because
persistence is enabled (the SDK default on iOS and Android). On the next app
launch with connectivity, the SDK transmits the queued writes. The expense is
created on the server and the `recomputeSimplifiedBalances` function fires
normally.

**Limitation:** If the user clears the app's data from device settings (not
merely killing the app), the Firestore cache and pending write queue are
deleted. Queued writes are lost. This is a platform-level constraint and is
documented in the app's help text.

---

## 6. Testing Strategy

> **Implementation status.** The emulator network-toggle tests in §6.1–6.3
> below are the **planned** target. They are **not present** in the
> repository today: there is no `disableNetwork()`, `enableNetwork()`, or
> `isFromCache` usage anywhere in `lib/` or `test/`. What ships today is
> connectivity-provider override coverage at the unit/widget tier — see
> §6.5.

### 6.1 Emulator-Based Integration Test (planned)

The primary offline test corresponds to **CUJ-7** from the canonical test
matrix (`.github/shared/test-strategy.md`):

> "Offline: add expense without network, reconnect, verify sync and
> recomputation."

The test procedure is:

1. **Setup:** Start the Firebase Emulator Suite (Auth, Firestore, Functions).
   Seed a test group with two members and one existing expense.
2. **Disable network:** Call `FirebaseFirestore.instance.disableNetwork()` to
   simulate offline mode within the emulator environment.
3. **Add expense offline:** Create a new expense document via the app's
   repository layer. Verify that the local snapshot listener emits the new
   expense with `SnapshotMetadata.isFromCache == true`.
4. **Re-enable network:** Call `FirebaseFirestore.instance.enableNetwork()`.
5. **Verify sync:** Assert that the expense document exists on the server
   (query the emulator's Firestore REST endpoint or read via a fresh
   `get(source: Source.server)` call).
6. **Verify recomputation:** Assert that the `simplifiedBalances` map on the
   group document has been updated by the Cloud Function to reflect the new
   expense. All amounts must be integer paise (Invariant 1).

### 6.2 Conflict Resolution Test (planned)

1. **Setup:** Two authenticated users (A and B) in a shared group.
2. User A calls `disableNetwork()`.
3. User A edits an existing expense (changes the amount).
4. User B (online) edits the same expense (changes the description).
5. User A calls `enableNetwork()`.
6. Assert that the server document reflects the last write to arrive.
7. Assert that `simplifiedBalances` is recomputed and consistent.
8. Assert that User A's snapshot listener emits the server-resolved state.

### 6.3 Queued Write Persistence Test (planned)

1. Add an expense while offline.
2. Dispose the Firestore instance (simulating app restart).
3. Re-initialise Firestore with persistence enabled and enable network.
4. Assert that the expense appears on the server.

### 6.4 Coverage Expectations

Offline tests fall under the integration-test tier of the test pyramid. They
are executed in CI against the Firebase Emulator Suite as part of the PR
pipeline (SRS section 9.2). No real Firebase project is used (Invariant 4).

### 6.5 Connectivity coverage that ships today

In the absence of the emulator network-toggle tests above, offline messaging
is exercised at the unit/widget tier by overriding `connectivityCheckProvider`
with an `IsOnline` fake:

- `test/features/profile/notification_preferences_controller_test.dart` and
  `test/features/profile/notification_preferences_screen_test.dart` — assert
  (under the "AC-10" groups) that the first offline write latches
  `offlineWriteJustQueued` and surfaces the one-shot snackbar "You are offline.
  Changes will sync when you reconnect." exactly once per session, never on
  online flips, and never when the connectivity check itself throws.
- `test/features/settlements/settle_up_bottom_sheet_widget_test.dart` —
  "network failure shows the offline snackbar"; with
  `test/features/settlements/settle_up_controller_test.dart` and
  `test/features/settlements/settlement_create_error_test.dart` asserting the
  offline-aware error copy "You're offline. The settlement will be recorded
  when you reconnect."

These tests do not toggle Firestore network state; they drive the
`IsOnline` callback directly, which matches how the production code consumes
connectivity (§2.2).
