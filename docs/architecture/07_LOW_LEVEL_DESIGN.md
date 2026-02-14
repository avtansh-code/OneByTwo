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
│      2: MigrationV2(),  // Add friends table, context_type to   │
│                         // expenses/settlements/activity_log/   │
│                         // sync_queue/notifications/drafts      │
│      // 3: MigrationV3(),  // Future: add tags table            │
│      // 4: MigrationV4(),  // Future: add OCR results           │
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
│  │  2. Initialize AppLogger (file + console outputs)         │  │
│  │     - Open/create log directory                           │  │
│  │     - Check existing log files for rotation               │  │
│  │     - Set log level based on build flavor                 │  │
│  │     - Log: "App bootstrap started" (with app version)     │  │
│  │                                                           │  │
│  │  3. Firebase.initializeApp() (parallel with step 4)       │  │
│  │                                                           │  │
│  │  4. Open sqflite database + run migrations                │  │
│  │     (parallel with step 3)                                │  │
│  │     - Log: each migration step with duration              │  │
│  │                                                           │  │
│  │  5. Initialize SharedPreferences                          │  │
│  │                                                           │  │
│  │  6. Check auth state (Firebase Auth)                      │  │
│  │     - Log: "Auth state: authenticated/unauthenticated"    │  │
│  │                                                           │  │
│  │  7. If authenticated:                                     │  │
│  │     a. Load current user from local DB                    │  │
│  │     b. Start Firestore listeners (background)             │  │
│  │     c. Initialize sync engine                             │  │
│  │     d. Register FCM token                                 │  │
│  │     - Log: each sub-step with duration                    │  │
│  │                                                           │  │
│  │  8. Initialize GoRouter with auth redirect                │  │
│  │                                                           │  │
│  │  9. Log: "Bootstrap complete" with total duration         │  │
│  │                                                           │  │
│  │  10. runApp(ProviderScope(child: App()))                  │  │
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

---

## 7. Logging & Debugging System

```
┌─────────────────────────────────────────────────────────────────┐
│              LOGGING SYSTEM ARCHITECTURE                         │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    AppLogger (Singleton)                  │   │
│  │                                                          │   │
│  │  interface LogOutput {                                   │   │
│  │    void write(LogEntry entry);                           │   │
│  │    Future<void> dispose();                               │   │
│  │  }                                                       │   │
│  │                                                          │   │
│  │  class AppLogger {                                       │   │
│  │    static AppLogger? _instance;                          │   │
│  │    final List<LogOutput> _outputs;                       │   │
│  │    final LogLevel _minLevel;                             │   │
│  │    final PiiSanitizer _sanitizer;                        │   │
│  │                                                          │   │
│  │    void verbose(String tag, String msg, [Map? data]);    │   │
│  │    void debug(String tag, String msg, [Map? data]);      │   │
│  │    void info(String tag, String msg, [Map? data]);       │   │
│  │    void warning(String tag, String msg, [Map? data]);    │   │
│  │    void error(String tag, String msg, [Object? error,    │   │
│  │               StackTrace? stack, Map? data]);            │   │
│  │    void fatal(String tag, String msg, [Object? error,    │   │
│  │               StackTrace? stack]);                       │   │
│  │                                                          │   │
│  │    Future<List<File>> getLogFiles();                     │   │
│  │    Future<String> exportLogs({DateTime? since});         │   │
│  │    Future<void> clearLogs();                             │   │
│  │  }                                                       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Four Log Outputs:                                              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────┐ ┌──────────┐  │
│  │ ConsoleOutput│ │  FileOutput  │ │Crashlytics│ │RingBuffer│  │
│  │              │ │              │ │  Output   │ │  Output  │  │
│  │ • debugPrint │ │ • JSON lines │ │ • warning+│ │ • Last N │  │
│  │ • Colored    │ │ • Rotation   │ │ • Non-PII │ │   entries│  │
│  │ • Dev only   │ │ • All envs   │ │ • Prod    │ │ • In-app │  │
│  │              │ │              │ │   only    │ │   viewer │  │
│  └──────────────┘ └──────┬───────┘ └──────────┘ └──────────┘  │
│                          │                                      │
│                          ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              FILE ROTATION ENGINE                         │   │
│  │                                                          │   │
│  │  class LogFileRotator {                                  │   │
│  │    final int maxFileSize;    // 5 MB (5 * 1024 * 1024)   │   │
│  │    final int maxFileCount;   // 3 files                  │   │
│  │    final String logDir;      // getApplicationDocuments  │   │
│  │                              //   Directory() / 'logs/'  │   │
│  │                                                          │   │
│  │    Rotation algorithm:                                   │   │
│  │    1. On each write, check current file size             │   │
│  │    2. If size > maxFileSize:                             │   │
│  │       a. Delete app.2.log (oldest)                       │   │
│  │       b. Rename app.1.log → app.2.log                   │   │
│  │       c. Rename app.log → app.1.log                     │   │
│  │       d. Create new app.log                             │   │
│  │    3. Append JSON log entry to app.log                  │   │
│  │                                                          │   │
│  │    File naming:                                          │   │
│  │    logs/                                                 │   │
│  │    ├── app.log       ← current (newest)                 │   │
│  │    ├── app.1.log     ← previous                         │   │
│  │    └── app.2.log     ← oldest (deleted on next rotate)  │   │
│  │                                                          │   │
│  │    Max disk usage: 3 × 5 MB = 15 MB                     │   │
│  │  }                                                       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.1 PII Sanitizer

```
┌─────────────────────────────────────────────────────────────────┐
│              PII SANITIZER                                       │
│                                                                  │
│  class PiiSanitizer {                                           │
│    String sanitize(String message) {                            │
│      return message                                             │
│        .replaceAll(RegExp(r'\b\d{10}\b'), '***PHONE***')       │
│        .replaceAll(                                             │
│          RegExp(r'[\w.]+@[\w.]+\.\w+'), '***EMAIL***')         │
│        .replaceAll(                                             │
│          RegExp(r'eyJ[A-Za-z0-9_-]+'), '***TOKEN***')          │
│        .replaceAll(                                             │
│          RegExp(r'\b\d{4,6}\b(?=.*otp)', caseSensitive: false),│
│          '***OTP***');                                          │
│    }                                                            │
│  }                                                              │
│                                                                  │
│  Applied to every log message BEFORE writing to any output.    │
│                                                                  │
│  Rules:                                                         │
│  • 10-digit numbers → ***PHONE***                              │
│  • Email patterns → ***EMAIL***                                │
│  • JWT-like strings (eyJ...) → ***TOKEN***                     │
│  • 4-6 digit numbers near "otp" → ***OTP***                   │
│  • User names are never logged (use userId instead)            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 Log Entry Format

```
┌─────────────────────────────────────────────────────────────────┐
│              LOG ENTRY STRUCTURE                                 │
│                                                                  │
│  class LogEntry {                                               │
│    final DateTime timestamp;       // ISO 8601 UTC              │
│    final LogLevel level;           // verbose..fatal            │
│    final String tag;               // Component name            │
│    final String message;           // Human-readable            │
│    final Map<String, dynamic>? data; // Structured context      │
│    final String? errorType;        // Exception class name      │
│    final String? stackTrace;       // For error/fatal           │
│  }                                                              │
│                                                                  │
│  JSON Lines format (one JSON object per line in file):          │
│                                                                  │
│  {"ts":"2026-02-14T15:30:00.123Z","lvl":"info",                │
│   "tag":"SyncEngine","msg":"Queue item processed",              │
│   "data":{"entityType":"expense","entityId":"e123",             │
│   "op":"create","ms":245}}                                      │
│                                                                  │
│  {"ts":"2026-02-14T15:30:01.456Z","lvl":"error",               │
│   "tag":"ExpenseRepo","msg":"Firestore write failed",           │
│   "data":{"groupId":"g1","expenseId":"e456"},                   │
│   "err":"FirebaseException","stack":"...truncated..."}          │
│                                                                  │
│  Abbreviated keys in file output to minimize disk usage:        │
│  ts=timestamp, lvl=level, msg=message, err=errorType            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.3 Per-Layer Logging Tags

```
┌─────────────────────────────────────────────────────────────────┐
│              LOGGING TAG CONVENTIONS                              │
│                                                                  │
│  Each layer uses a consistent tag prefix:                       │
│                                                                  │
│  ┌─────────────┬────────────┬──────────────────────────────┐   │
│  │ Layer       │ Tag Prefix │ Example Tags                 │   │
│  ├─────────────┼────────────┼──────────────────────────────┤   │
│  │ Bootstrap   │ Boot       │ Boot.Init, Boot.Migration    │   │
│  │ Auth        │ Auth       │ Auth.Login, Auth.Token       │   │
│  │ Domain      │ UC         │ UC.AddExpense, UC.Settle     │   │
│  │ Repository  │ Repo       │ Repo.Expense, Repo.Group     │   │
│  │ DAO/Local   │ DAO        │ DAO.Expense, DAO.SyncQueue   │   │
│  │ Firestore   │ FS         │ FS.Expense, FS.Listener      │   │
│  │ Sync Engine │ Sync       │ Sync.Queue, Sync.Conflict    │   │
│  │ Network     │ Net        │ Net.Status, Net.CF           │   │
│  │ FCM         │ FCM        │ FCM.Token, FCM.Message       │   │
│  │ UI/Provider │ UI         │ UI.ExpenseList, UI.Navigate  │   │
│  │ Storage     │ Storage    │ Storage.Upload, Storage.Cache│   │
│  │ Logger      │ Logger     │ Logger.Rotate, Logger.Export │   │
│  └─────────────┴────────────┴──────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.4 Log Export & In-App Debug Viewer

```
┌─────────────────────────────────────────────────────────────────┐
│              DEBUG TOOLS                                         │
│                                                                  │
│  1. LOG EXPORT (for bug reports)                                │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  User path: Settings > Debug > Export Logs                │  │
│  │                                                           │  │
│  │  exportLogs({DateTime? since}) async {                    │  │
│  │    1. Read all log files (current + rotated)              │  │
│  │    2. Filter by date range if 'since' provided            │  │
│  │    3. Concatenate into single string                      │  │
│  │    4. Add device info header:                             │  │
│  │       - App version, build number                         │  │
│  │       - OS version, device model                          │  │
│  │       - Locale, timezone                                  │  │
│  │       - Available storage                                 │  │
│  │    5. Share via system share sheet (as .txt file)         │  │
│  │  }                                                        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  2. IN-APP DEBUG VIEWER (dev/staging builds only)              │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  RingBufferOutput stores last 500 log entries in memory   │  │
│  │                                                           │  │
│  │  Debug overlay (shake gesture or dev menu):               │  │
│  │  • Scrollable log list with color-coded levels            │  │
│  │  • Filter by tag, level, or keyword                       │  │
│  │  • Tap entry to expand full data/stack trace              │  │
│  │  • Copy single entry or filtered set                      │  │
│  │  • Clear button                                           │  │
│  │                                                           │  │
│  │  NOT available in production builds (tree-shaken out)     │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  3. SYNC DEBUGGER (dev/staging builds only)                    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Debug overlay panel showing:                             │  │
│  │  • Sync queue depth (pending/processing/failed/conflict)  │  │
│  │  • Active Firestore listeners count                       │  │
│  │  • Last sync timestamp                                    │  │
│  │  • Connectivity status                                    │  │
│  │  • Force sync button                                      │  │
│  │  • Clear failed items button                              │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7.5 Cloud Functions Logging

```
┌─────────────────────────────────────────────────────────────────┐
│              CLOUD FUNCTIONS LOGGING                              │
│                                                                  │
│  Cloud Functions use Google Cloud Logging (structured):          │
│                                                                  │
│  import { logger } from 'firebase-functions/v2';                │
│                                                                  │
│  // Structured log with context                                 │
│  logger.info('Balance recalculated', {                          │
│    groupId: 'g123',                                             │
│    memberCount: 5,                                              │
│    pairCount: 10,                                               │
│    durationMs: 340,                                             │
│  });                                                            │
│                                                                  │
│  // Error with stack trace                                      │
│  logger.error('Failed to send notification', {                  │
│    userId: 'u456',   // ID only, never name/phone              │
│    error: err.message,                                          │
│    stack: err.stack,                                             │
│  });                                                            │
│                                                                  │
│  Rules:                                                         │
│  • Use firebase-functions logger (maps to Cloud Logging)       │
│  • Always include groupId/userId/entityId for traceability      │
│  • Log duration for all Cloud Function invocations             │
│  • Log input validation failures (without PII)                  │
│  • Never log: phone numbers, emails, names, auth tokens        │
│  • Severity mapping: debug → DEBUG, info → INFO,               │
│    warn → WARNING, error → ERROR                               │
│                                                                  │
│  Cloud Logging query examples:                                  │
│  severity >= WARNING AND resource.type = "cloud_function"       │
│  jsonPayload.groupId = "g123"                                   │
│  jsonPayload.durationMs > 1000                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```
