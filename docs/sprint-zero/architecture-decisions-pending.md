# Pending Architecture Decisions

## Currently Proposed ADRs

### ADR-0004: Riverpod 2.x for State Management

- **Status:** Proposed — architect to confirm
- **Recommendation: Accept.** Riverpod 2.x is compile-safe, context-free, and
  well-suited to a greenfield Flutter project with heavy asynchronous Firestore
  streams; BLoC would add unnecessary event/state boilerplate for the team's use
  case.
- **What needs to happen:** The Solution Architect must change the status from
  "Proposed" to "Accepted", confirm whether `riverpod_generator` (code-gen) will
  be used or manual provider declarations preferred, and update
  `coding-standards.md` to remove the "(pending architect confirmation)"
  qualifier on the Riverpod reference.

---

## New Decisions Needed

The following architectural decisions are implied or left open by the SRS but
have no corresponding ADR. Proposed numbering continues from ADR-0006.

### ADR-0007: Navigation Library

- **Recommendation: Use GoRouter.** It is the officially recommended Flutter
  navigation package, supports declarative routing, deep linking from
  notifications and shared URLs (FR-AC-02, FR-AC-05, FR-SH-02), and integrates
  cleanly with Riverpod via `goRouterProvider`.

### ADR-0008: Theming Approach and Design Tokens

- **Recommendation: Define a single `AppTheme` class that builds `ThemeData` for
  both light and dark modes using Material 3 `ColorScheme.fromSeed` seeded with
  the SRS section 6.2 tokens.** This centralises the colour palette (Indigo Blue
  primary, Saffron secondary, Emerald success, Coral danger), typography (Inter /
  Plus Jakarta Sans), corner radii, and elevation values in one file under
  `lib/app/`, satisfying NFR-PE-06 (app size) by avoiding a design-system
  package and SRS section 5.6 (dark mode support).

### ADR-0009: Error-Handling Convention

- **Recommendation: Adopt a `Result<T, E>` sealed-class pattern (or the
  `result_dart` / `fpdart` `Either` type) for repository and service return
  values, reserving thrown exceptions only for truly unrecoverable programmer
  errors.** This makes error states explicit in type signatures, prevents
  unhandled `Future` rejections, and pairs well with Riverpod's `AsyncValue` for
  UI consumption.

### ADR-0010: Logging and Crash Reporting Strategy

- **Recommendation: Use `dart:developer` log for debug builds and Firebase
  Crashlytics `recordError` / `log` for release builds, with no additional
  logging package.** The SRS (section 5.10) already mandates Crashlytics and
  structured Cloud Function logs; a third-party logging library adds dependency
  weight without meaningful benefit at v1.0 scale.

### ADR-0011: Image Caching Strategy

- **Recommendation: Use `cached_network_image` for profile photos and receipt
  thumbnails.** Receipt images (FR-EX-05, P1) and avatars are loaded repeatedly
  across screens; `cached_network_image` provides disk and memory caching,
  placeholder/error widgets, and keeps app size within NFR-PE-06 limits.

### ADR-0012: HTTP Client for Non-Firebase Calls

- **Recommendation: No dedicated HTTP client package is needed for v1.0.** All
  data flows through Firebase SDKs (Firestore, Auth, Storage, FCM, Remote
  Config); there are no external REST APIs in scope. If a need arises (e.g., a
  webhook or third-party service), `package:http` should be preferred over Dio
  for its lighter footprint. Record this as a deferred decision.

### ADR-0013: Dependency Injection Approach

- **Recommendation: Use Riverpod as the sole dependency injection mechanism,
  including for non-UI services (repositories, formatters, Firebase SDK
  wrappers).** Adding `get_it` would introduce a parallel service-locator
  pattern, increase cognitive load, and fragment the provider graph. Riverpod
  providers can serve repositories and pure services equally well.

### ADR-0014: Offline Persistence Strategy

- **Recommendation: Rely on Firestore SDK's built-in offline persistence
  (`settings.persistenceEnabled = true`) as the sole offline mechanism.** The SRS
  (FR-OF-01, FR-OF-02, FR-OF-03) requires offline viewing and queued writes with
  last-write-wins conflict resolution — all of which Firestore's offline cache
  handles natively. Introducing Hive or Isar would create a parallel data layer,
  a cache-invalidation burden, and potential consistency conflicts with
  Firestore's own cache.

### ADR-0015: Deep Linking and Invite Link Implementation

- **Recommendation: Use iOS Universal Links and Android App Links (verified via
  `assetlinks.json` / `apple-app-site-association` hosted on a project-owned
  domain) rather than Firebase Dynamic Links, which have been deprecated.** Group
  invite links (FR-GR-02, FR-GR-03) and shared install links (FR-SH-02) should
  resolve through a lightweight Cloud Function or Firebase Hosting redirect that
  routes to the app or falls back to the store listing. This requires the
  architect to define the link schema and the Cloud Function contract.

### ADR-0016: Phone Number Input and Validation Approach

- **Recommendation: Use a bespoke validation widget with a hardcoded `+91`
  prefix and a simple 10-digit regex (`^[6-9]\d{9}$`), rather than a
  general-purpose phone-input package.** The SRS locks the country code to +91
  (FR-AU-01, FR-AU-02, section 3.4); a multi-country phone-input library (e.g.,
  `intl_phone_number_input`) adds unnecessary weight, complexity, and a broader
  attack surface for a single-country product. The validation logic should live
  in `lib/core/` as a shared utility.

### ADR-0017: Internationalisation Setup

- **Recommendation: Configure Flutter `intl` with `.arb` files from day one,
  with `en` as the sole v1.0 locale, to satisfy the SRS requirement (section
  5.9) that the architecture support Hindi and other languages in future without
  refactor.** All user-facing strings must be externalised; no hardcoded strings
  in widget code. This is an architectural constraint, not a feature toggle.

### ADR-0018: App Check Enforcement Strategy

- **Recommendation: Enable Firebase App Check with Play Integrity (Android) and
  DeviceCheck (iOS) in enforcement mode for Firestore, Storage, and Cloud
  Functions, with a debug provider for the Emulator Suite in CI.** The SRS
  (section 5.4) mandates App Check; the ADR must document the debug-token
  provisioning flow so that CI pipelines and local development are not blocked.
