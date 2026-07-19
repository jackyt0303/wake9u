# 02 — AlarmKit and Spotify audio

## Scheduling model

`AlarmSchedulingService` consumes server-approved configuration plus future occurrence snapshots. For each upcoming scheduled local day it schedules the corresponding AlarmKit alarm using its immutable occurrence ID as the alarm identifier. It maintains a bounded rolling local horizon (for example 14 days) and removes/replaces only future identifiers on configuration/timezone changes. It must be idempotent: a refresh computes desired IDs, cancels obsolete future IDs, and upserts desired IDs.

Resolve each weekday against the configuration's IANA timezone using an explicit calendar policy. For a nonexistent wall-clock time (spring-forward), choose the next valid local time; for an ambiguous time (fall-back), choose the first matching instant. Persist the resolution policy and resolved UTC instant in the occurrence; never produce two occurrences for one local date. Server and client share tested resolver fixtures, with the server authoritative for streak counting.

Only one primary schedule is enabled. Each schedule specifies weekdays, local time, timezone, enabled flag, and version. The app creates no occurrence for an unscheduled day. There is no snooze UI or AlarmKit snooze path. Dismissing the visual alarm never changes `verificationEndsAt`.

## Alarm experience

Use AlarmKit and a bundled, app-approved audio resource for dependable alert behavior. Configure the alert/presentation according to the installed iOS 26 AlarmKit API, including title, accessibility label, and action that opens the active verification screen. Verify entitlement and authorization status before arming. Do not implement Critical Alerts, notification escalation/reposting, background polling, force-kill detection, or audio-route/Bluetooth assumptions.

At scheduled time, persist/create the `LocalAttempt` first with fixed `startedAt` and `endsAt = scheduledAt + 300 seconds`; then present active verification UI when the app is available. If the system delivers the alarm while the app is locked, rely on AlarmKit's system alarm behavior and resume the same persisted attempt when opened. App termination/reboot behavior is accepted only to the extent supported by AlarmKit and is physically validated.

## Spotify enhancement

The configuration stores a user-curated list of Spotify playlist URIs. Validate local syntax, de-duplicate, and select one deterministically/randomly per occurrence (persist the chosen URI or a privacy-safe stable reference in the snapshot so retries do not change it). On entering foreground/active verification, reconnect Spotify App Remote and request playback of that selection only after authorization and connection succeed.

Spotify is optional. Keep bundled alarm audio as the initial and fallback sound. If the Spotify app is absent, callback fails, user denied authorization, App Remote disconnects, the URI is invalid, or playback errors/timeouts, record a non-sensitive reason and continue with bundled audio. On each app-active transition, reconnect as required by Spotify's lifecycle; never claim that background Spotify starts the alarm. Do not upload playlist URI in telemetry.

## Permission and failure UX

- Alarm authorization unavailable: schedule remains draft/unarmed; explain the system setting path.
- Sign-in missing: allow editing, but label schedule non-counting and block armed streak configuration.
- Offline configuration: can schedule locally only with a prominent `Awaiting sync — not yet streak-counting` state.
- Spotify unavailable: show a subtle fallback notice after alarm activity; do not interrupt verification.
- Emergency disable: cancel future counting alarms after config refresh; preserve historical evidence and explain state.

## Tests and device matrix

Unit-test desired-alarm diffing, calendar/DST resolver, deduplication, no-snooze behavior, and attempt deadline immutability. Test adapters with a fake AlarmKit scheduler and Spotify client. Physical device acceptance covers locked device, Focus, silent mode, reboot, terminated app, no network, Spotify absent/unauthorized, and Spotify disconnect. The alarm must remain audible through the supported system behavior with Spotify absent before this plan is accepted.

