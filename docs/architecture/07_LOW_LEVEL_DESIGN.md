# One By Two — Low-Level Design

> **Version:** 1.1  
> **Last Updated:** 2026-02-14

> **Note:** All algorithms (split calculations, debt simplification, search ranking, recurring scheduling, guest migration, etc.) are documented in detail in **[10_ALGORITHMS.md](./10_ALGORITHMS.md)**.

---

## 1. Local Database Migration Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│              DATABASE MIGRATION SYSTEM                           │
│                                                                  │
│  class AppDatabase {                                             │
│    static const _dbName = 'onebytwo.db';                        │
│    static const _currentVersion = 1;                             │
│                                                                  │
│    Future<Database> open() async {                               │
│      return openDatabase(                                        │
│        _dbName,                                                  │
│        version: _currentVersion,                                 │
│        onCreate: (db, version) => _runMigrations(db, 0, version),│
│        onUpgrade: (db, old, new) => _runMigrations(db, old, new),│
│      );                                                          │
│    }                                                             │
│                                                                  │
│    Future<void> _runMigrations(Database db, int from, int to) {  │
│      for (version = from + 1; version <= to; version++) {        │
│        final migration = _migrations[version];                   │
│        if (migration != null) {                                  │
│          await migration.up(db);                                 │
│        }                                                         │
│      }                                                           │
│    }                                                             │
│                                                                  │
│    static final _migrations = {                                  │
│      1: MigrationV1(),  // Initial schema                       │
│      // 2: MigrationV2(),  // Future: add tags table            │
│      // 3: MigrationV3(),  // Future: add OCR results           │
│    };                                                            │
│  }                                                               │
│                                                                  │
│  Each migration:                                                 │
│  • Has up() and down() methods                                  │
│  • Runs inside a transaction                                    │
│  • Is idempotent (safe to re-run)                               │
│  • Preserves existing data                                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Receipt Image Upload Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│              RECEIPT UPLOAD PIPELINE                              │
│                                                                  │
│  User attaches photo                                             │
│       │                                                          │
│       ▼                                                          │
│  ┌──────────────────────────────────────┐                       │
│  │ 1. Pick image (camera or gallery)    │                       │
│  │    - image_picker package            │                       │
│  │    - Max resolution: 2048x2048       │                       │
│  └──────────────┬───────────────────────┘                       │
│                 │                                                │
│  ┌──────────────▼───────────────────────┐                       │
│  │ 2. Compress (flutter_image_compress) │                       │
│  │    - Quality: 80%                    │                       │
│  │    - Max size: 1MB                   │                       │
│  │    - Format: JPEG                    │                       │
│  └──────────────┬───────────────────────┘                       │
│                 │                                                │
│  ┌──────────────▼───────────────────────┐                       │
│  │ 3. Save locally                      │                       │
│  │    - App documents directory         │                       │
│  │    - Insert expense_attachments row  │                       │
│  │      with local_path, url = null     │                       │
│  └──────────────┬───────────────────────┘                       │
│                 │                                                │
│  ┌──────────────▼───────────────────────┐                       │
│  │ 4. Upload to Cloud Storage (async)   │                       │
│  │    - Path: groups/{gid}/receipts/    │                       │
│  │      {expenseId}/{uuid}.jpg          │                       │
│  │    - Resumable upload                │                       │
│  │    - On success: update url field    │                       │
│  │    - On failure: retry in sync queue │                       │
│  └──────────────┬───────────────────────┘                       │
│                 │                                                │
│  ┌──────────────▼───────────────────────┐                       │
│  │ 5. Generate download URL             │                       │
│  │    - Store in Firestore attachment   │                       │
│  │    - Cache locally for offline view  │                       │
│  └──────────────────────────────────────┘                       │
│                                                                  │
│  Offline behavior:                                               │
│  • Photo saved locally immediately                              │
│  • Displayed from local path while offline                      │
│  • Upload queued in sync_queue                                  │
│  • Uploaded when connectivity returns                           │
│  • URL updated in both local and Firestore                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Push Notification Handling

```
┌─────────────────────────────────────────────────────────────────┐
│              FCM NOTIFICATION FLOW                                │
│                                                                  │
│  ── SERVER SIDE (Cloud Function) ─────────────────────────────  │
│                                                                  │
│  onExpenseCreated trigger:                                       │
│    1. Get group members (except creator)                         │
│    2. For each member:                                           │
│       a. Check notification preferences                         │
│       b. Get FCM tokens from user doc                           │
│       c. Build notification payload                             │
│       d. Send via admin.messaging().sendEachForMulticast()      │
│    3. Write to users/{uid}/notifications (in-app log)           │
│    4. Handle stale tokens (remove on send failure)              │
│                                                                  │
│  ── CLIENT SIDE (Flutter) ────────────────────────────────────  │
│                                                                  │
│  Initialization (in bootstrap.dart):                            │
│    1. Request notification permissions (iOS: provisional first)  │
│    2. Get FCM token                                             │
│    3. Save token to users/{uid}/fcmTokens                       │
│    4. Listen for token refresh → update in Firestore            │
│                                                                  │
│  Message handling:                                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                                                           │  │
│  │  Foreground:                                              │  │
│  │  • Show in-app banner (overlay, auto-dismiss 5s)          │  │
│  │  • Tap banner → navigate to relevant screen               │  │
│  │  • Don't show system notification                         │  │
│  │                                                           │  │
│  │  Background / Terminated:                                 │  │
│  │  • System notification displayed                          │  │
│  │  • Tap notification → deep link to screen via data.route  │  │
│  │  • GoRouter handles the deep link                         │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. App Initialization Sequence

```
┌─────────────────────────────────────────────────────────────────┐
│              APP BOOTSTRAP SEQUENCE                              │
│                                                                  │
│  main() → bootstrap() → runApp()                                │
│                                                                  │
│  bootstrap() steps (target: < 2s total):                        │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                                                           │  │
│  │  1. WidgetsFlutterBinding.ensureInitialized()             │  │
│  │                                                           │  │
│  │  2. Firebase.initializeApp() (parallel with step 3)       │  │
│  │                                                           │  │
│  │  3. Open sqflite database + run migrations                │  │
│  │     (parallel with step 2)                                │  │
│  │                                                           │  │
│  │  4. Initialize SharedPreferences                          │  │
│  │                                                           │  │
│  │  5. Check auth state (Firebase Auth)                      │  │
│  │                                                           │  │
│  │  6. If authenticated:                                     │  │
│  │     a. Load current user from local DB                    │  │
│  │     b. Start Firestore listeners (background)             │  │
│  │     c. Initialize sync engine                             │  │
│  │     d. Register FCM token                                 │  │
│  │                                                           │  │
│  │  7. Initialize GoRouter with auth redirect                │  │
│  │                                                           │  │
│  │  8. runApp(ProviderScope(child: App()))                   │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Parallel initialization reduces cold start:                    │
│  Firebase.init ──┐                                               │
│  sqflite.open ───┤── await Future.wait([...])                   │
│  SharedPrefs ────┘                                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Biometric / PIN Lock

```
┌─────────────────────────────────────────────────────────────────┐
│              APP LOCK MECHANISM                                  │
│                                                                  │
│  Using local_auth package for biometric + PIN fallback          │
│                                                                  │
│  Flow:                                                           │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                                                           │  │
│  │  App resumed from background (if lock enabled):           │  │
│  │                                                           │  │
│  │  1. Check: was app in background > 30 seconds?            │  │
│  │     If no → skip lock screen                              │  │
│  │                                                           │  │
│  │  2. Show lock screen overlay                              │  │
│  │     • Biometric prompt (FaceID / Fingerprint)             │  │
│  │     • PIN fallback input                                  │  │
│  │                                                           │  │
│  │  3. On success → dismiss overlay, resume app              │  │
│  │  4. On failure → remain on lock screen                    │  │
│  │     3 failed attempts → show "Try again in 30s"           │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Storage:                                                        │
│  • PIN hash stored in flutter_secure_storage (Keychain/Keystore)│
│  • Lock enabled flag in SharedPreferences                       │
│  • Never store PIN in plain text                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Analytics Data Aggregation

```
┌─────────────────────────────────────────────────────────────────┐
│              LOCAL ANALYTICS COMPUTATION                         │
│                                                                  │
│  All analytics computed locally from sqflite for speed and      │
│  offline access. No server-side aggregation needed.             │
│                                                                  │
│  Category Breakdown:                                             │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  SELECT category, SUM(amount) as total                    │  │
│  │  FROM expenses                                            │  │
│  │  WHERE is_deleted = 0                                     │  │
│  │    AND ({group_filter})                                   │  │
│  │    AND date BETWEEN {start} AND {end}                     │  │
│  │  GROUP BY category                                        │  │
│  │  ORDER BY total DESC                                      │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Monthly Trend:                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  SELECT                                                   │  │
│  │    strftime('%Y-%m', datetime(date/1000, 'unixepoch'))    │  │
│  │      AS month,                                            │  │
│  │    SUM(amount) as total                                   │  │
│  │  FROM expenses                                            │  │
│  │  WHERE is_deleted = 0                                     │  │
│  │    AND date >= {12_months_ago}                            │  │
│  │  GROUP BY month                                           │  │
│  │  ORDER BY month ASC                                       │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Rendering: fl_chart package for pie/bar/line charts            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```
