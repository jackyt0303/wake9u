# 01 — Foundation and app contract

## Target and module layout

Create `Wake9u` (iOS 26+) and paired `Wake9u Watch App` targets. Keep feature code in local Swift packages/framework targets so platform-independent domain logic is unit-testable:

```
Wake9uApp / Wake9uWatchApp
  ├─ Wake9uDomain       (models, state machines, clocks, protocols)
  ├─ Wake9uData         (SwiftData, Keychain, Apollo/Supabase adapters)
  ├─ Wake9uAlarm        (AlarmKit, audio, Spotify adapter)
  ├─ Wake9uUI           (SwiftUI, Lottie, accessibility)
  └─ Wake9uWatch        (HealthKit and WatchConnectivity adapters)
```

Use Swift concurrency with `@MainActor` view models and protocol-injected clocks/services. Dependencies are Swift Package Manager: Apollo iOS, Supabase Swift, Lottie, and Spotify iOS SDK. Pin exact compatible versions in `Package.resolved`; update them in a dedicated dependency PR. Wrap vendor APIs behind local protocols so tests do not import them.

## Configuration and credentials

Commit `Config.example.xcconfig`, never values. Debug/release schemes select `Config.Debug.xcconfig` and `Config.Release.xcconfig`, both gitignored. Required non-secret build values are Supabase URL, GraphQL endpoint, Apple client identifiers, and environment name. The Supabase anonymous key is distribution-safe but still injected through config; service-role credentials never enter an Apple app or CI build artifact. Spotify client ID/callback scheme comes from build configuration; its client secret is never shipped.

Use `.env` only for local migration tooling and a secret manager/CI variables for deployment. Validate required values at launch with a developer-visible configuration error in debug and a safe unavailable state in release. Configure URL schemes for Spotify callback and `shortcuts` opening only through platform APIs.

## Entitlements and permissions

Enable Sign in with Apple, AlarmKit capability/entitlement if required by the installed SDK, and App Groups only if the watch data-sharing implementation needs it. Add HealthKit only to the Watch target and only for optional workout collection. Declare clear purpose strings for Motion & Fitness and HealthKit. Do not request permissions at first launch: request each immediately before its feature needs it and preserve a usable fallback.

The app requests AlarmKit authorization before enabling a schedule. If rejected, retain the draft configuration but do not represent it as armed. Sign in with Apple is required before the user can commit a streak-counting schedule. Motion denial means the attempt will resolve as unavailable/failure according to the displayed policy; it is not silently reported as successful.

## Local data and security

SwiftData is an offline cache, not an authority. Persist `CachedConfiguration`, `LocalOccurrence`, `LocalAttempt`, `EvidenceEnvelope`, `RemoteConfigCache`, and a durable mutation outbox. Each record has a server ID/UUID, schema version, updated timestamp, sync state (`draft`, `queued`, `synced`, `rejected`), and idempotency key where relevant. Encrypting the device is assumed; store no raw motion samples.

Keep Supabase access/refresh tokens in Keychain using `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. On sign-out or account deletion, cancel locally scheduled alarms, purge SwiftData/outbox and Keychain tokens, and clear Spotify/session state. Never put tokens in `UserDefaults`, logs, crash reports, or analytics.

## App lifecycle contract

At launch: restore session, load local cache, fetch remote config, reconcile the outbox, then refresh configurations/occurrences. Schedule only after the cloud configuration confirms its version unless the app labels an offline schedule as non-counting. On foreground: reconnect Spotify as applicable, refresh auth/config conservatively, reconcile evidence, and update active attempt presentation. Do not rely on launch callbacks to deliver alarms.

Use a single `AppEnvironment` composition root. It owns a `Clock`, network monitor, repository interfaces, and feature coordinators. Feature state is derived from persisted local attempt/configuration records, not transient views.

## CI and conventions

Run formatting/linting, iOS and watch build, unit tests, migration validation, GraphQL operation generation/validation, and secret scanning on every pull request. A protected release workflow signs from CI-managed credentials and uploads to TestFlight only after the gates in [07](07_quality_privacy_and_release.md). Use structured OSLog categories (`auth`, `alarm`, `verification`, `sync`, `watch`) with redacted IDs; never log playlist URI, exact motion count, token, or health data.

Definition of done: clean clone builds both targets with example config; auth/token persistence tests pass; sign-out purge is tested; no secret scans or direct vendor imports outside adapters are present.

