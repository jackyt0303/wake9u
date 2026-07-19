# Wake9u implementation orchestration

## Product contract

Wake9u is an iOS 26+ SwiftUI alarm app that rewards verified wake-up movement. It has one primary weekly schedule per signed-in user, no snooze, and at most one streak-counting occurrence per local calendar day. The phone is the authoritative v1 sensor: a scheduled occurrence succeeds when `CMPedometer` records at least 10 phone steps in the fixed interval `[scheduledAt, scheduledAt + 5 minutes]`. A paired Watch can contribute supplemental aggregate evidence but never blocks a phone-only success.

Alarm delivery is an AlarmKit responsibility, using a bundled sound. Spotify App Remote is an optional foreground enhancement, not an alarm transport. Critical Alerts, notification-loop workarounds, force-kill observers, Bluetooth-route checks, and attempts to make dismissal physically unbypassable are explicitly out of scope. A streak is enforcement through verification and auditability, not coercion.

Before an alarm can count toward a streak, the user must sign in with Apple and the configuration must be synchronized. An offline-only configuration may still alarm locally, but its occurrence is untrusted until configuration and evidence are accepted by the service.

## Decisions and invariants

| Area | Decision |
| --- | --- |
| Client | Native SwiftUI iOS app plus paired, optional watchOS app; Swift concurrency and SwiftData |
| Cloud | Supabase Auth/Postgres plus `pg_graphql`; no separate GraphQL server |
| Authentication | Sign in with Apple required for streak-counting scheduling |
| Alarm | AlarmKit, local bundled sound, no snooze |
| Schedule | One primary weekly schedule; IANA timezone; one resolved occurrence per scheduled local day including DST |
| Verification | Fixed five-minute phone-pedometer interval; success threshold is `>= 10` aggregate steps |
| Privacy | Aggregate counts and timestamps only; no raw motion or HealthKit samples leave the device |
| Recovery | Trusted local success can replace a provisional cloud failure when the recorded interval validates |
| Animation | Supplied Lottie files with static and Reduce Motion fallbacks |
| Handoff | Optional user-selected Shortcut via `shortcuts://run-shortcut?name=…` after success |

Every occurrence stores immutable configuration and remote-config snapshots, timezone, resolved schedule time, attempt window, and playlist selection metadata. Future occurrences are regenerated when a schedule or timezone changes; historical snapshots never change.

## Dependency order

1. Foundation, app contract, credentials, target layout, local models, and CI ([01](01_foundation_and_app_contract.md)).
2. Backend schema, RLS, GraphQL domain functions, and occurrence reconciler ([05](05_supabase_graphql_domain.md)).
3. AlarmKit scheduling and audio fallback ([02](02_alarmkit_and_spotify_audio.md)).
4. Phone verification and offline evidence journal ([03](03_phone_motion_verification.md)).
5. Dashboard, mascot, history, settings, and Shortcut handoff ([06](06_dashboard_mascot_and_handoff.md)).
6. Watch companion after phone flow is independently shippable ([04](04_watch_companion_motion.md)).
7. Cross-cutting verification, privacy, release gates ([07](07_quality_privacy_and_release.md)).

## Feature inventory

- Apple sign-in, profile creation, account deletion, auth/session restoration.
- One weekly alarm schedule, timezone-aware preview, configuration sync state, emergency-disable state.
- AlarmKit authorization, local scheduling/rescheduling, bundled sound, foreground Spotify best effort.
- Per-occurrence five-minute attempt, live progress, CoreMotion aggregate evidence, local persistence, cloud reconciliation.
- Streak summary/history and corrective audit events.
- Hostile/Coach/Defeated mascot states, accessibility and motion fallbacks.
- Optional watch schedule/progress screen and workout-driven supplemental aggregates.
- Shortcut preference and post-success URL handoff.
- Remote configuration, analytics limited to non-sensitive failures, operational dashboards.

## Sprint map

| Sprint | Outcome | Primary plans | Exit gate |
| --- | --- | --- | --- |
| 0 | Buildable skeleton and environments | 01 | App and watch targets build; secrets are excluded from source |
| 1 | Authenticated, secure domain slice | 05 | RLS and GraphQL integration tests prove tenant isolation |
| 2 | Dependable local alarm | 02 | Device test alarms through locked/Focus/silent scenarios |
| 3 | Verified phone wake-up and streak correction | 03, 05 | 9/10-step and offline/late-success cases pass |
| 4 | Complete daily product surface | 06 | Dashboard/history/settings accessible and handoff graceful |
| 5 | Optional Watch evidence | 04 | Pairing, denial, and no-watch cases are all valid |
| 6 | Ship readiness | 07 | CI, privacy, accessibility, TestFlight, and review checklists pass |

## Acceptance gates

**Architecture.** No cloud mutation writes raw tables directly. The app can reconstruct its local UI from SwiftData after termination, then reconcile idempotently. Every service mutation enforces identity from `auth.uid()` and takes an idempotency key.

**Scheduling.** Scheduled weekdays create exactly one occurrence for each local date, including DST transitions. Unschedule is neutral. A configuration edit affects only newly generated future occurrences. An inactive remote-config emergency switch prevents new counting schedules and is visible in the app.

**Verification.** The deadline never moves after dismissal. Exactly 9 steps fails and 10 steps succeeds. A duplicate upload produces no duplicate audit/streak event. A valid locally captured success may correct a provisional overdue failure atomically.

**Experience.** AlarmKit sound remains viable if Spotify is missing, unauthorized, disconnected, or fails. Missing Shortcuts and denied Watch/HealthKit permissions do not prevent phone success. VoiceOver, Dynamic Type, and Reduce Motion yield complete usable flows.

**Release.** See the explicit test and release matrix in [07](07_quality_privacy_and_release.md); physical-device acceptance is mandatory because AlarmKit, pedometer, audio routing, and Watch connectivity cannot be fully simulated.

## Delivery ownership and artifacts

Each plan should produce code, tests, and a brief implementation decision record for any deviation. Product/design supplies the production Lottie JSON and copy. Backend owns migrations/functions/jobs; iOS owns local scheduler, evidence journal, and UI; QA owns the physical-device matrix. Any new entitlement or Apple platform restriction discovered during implementation is a release blocker until recorded and reviewed.

