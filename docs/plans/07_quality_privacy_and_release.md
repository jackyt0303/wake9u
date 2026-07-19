# 07 — Quality, privacy, and release

## Automated verification

Unit test domain state transitions with a fake clock: scheduled-day selection, DST resolver, immutable snapshots, deadline boundaries, 9 versus 10 steps, no upper count, dismissal/no-snooze, sensor denial, duplicates, offline success, late correction, mascot mappings, and Shortcut URL encoding. Test local SwiftData migrations and outbox replay after process relaunch.

Run backend integration tests against disposable Supabase/Postgres: GraphQL authorization and tenant isolation, denied raw writes, function idempotency, configuration-version snapshots, scheduled horizon generation, timezone/DST fixtures, scheduled expiry, provisional failure, valid correction and streak recomputation, emergency disable, account deletion, and remote-config publication access. Fail CI when generated GraphQL operations no longer match schema.

UI tests cover signed-out/signed-in paths, schedule labels, active verification, history, settings, error/retry states, VoiceOver focus, Dynamic Type, contrast, and Reduce Motion. Keep hardware API tests behind abstractions and use fakes in simulator.

## Mandatory physical-device matrix

Before TestFlight signoff, exercise iPhone alarm and verification on supported iOS versions for: locked device, Focus, silent switch, reboot, app termination, no network, Motion denied, Spotify absent, Spotify unauthorized, Spotify disconnect, missing Shortcut, offline evidence then reconnect, timezone change, and DST boundary where calendar permits. Exercise Watch behavior paired/unpaired, app not installed, HealthKit denied, transfer delayed, workout interrupted, and watch unavailable. Document device/OS, scenario, expected/actual result, and any platform limitation.

## Privacy and security review

Publish a privacy nutrition label and in-app explanation that phone motion is used only to calculate aggregate steps during the five-minute wake attempt. State that raw motion samples, HealthKit samples, workout routes, and Spotify playlist contents are not uploaded. Explain storage, retention, deletion, and contact path. Provide account deletion from settings and verify server-side deletion/anonymization policy plus local token/cache/alarm purge.

Review entitlements, purpose strings, OAuth redirect handling, Keychain accessibility, RLS/function grants, log redaction, dependency licenses, and crash-report filters. Pen-test the GraphQL API for owner impersonation, ID enumeration, direct table writes, input overposting, duplicate/mismatched evidence, and function `search_path` abuse. Threat-model clock manipulation as a bounded trust limitation and make server window validation/audit trail explicit.

## Observability

Emit structured, non-sensitive events for authorization outcome, alarm scheduling outcome, alarm presentation, Spotify fallback reason category, verification terminal state, outbox retries, GraphQL typed errors, job lag, and Watch transfer status. Use opaque occurrence IDs or privacy-preserving buckets; exclude raw counts, exact location, playlist URI/name, tokens, HealthKit payloads, and personal profile text. Alert on scheduler failure/lag, elevated mutation rejection, occurrence backlog, and reconciliation latency.

## Release gates and rollback

Release requires green CI builds/tests, migration rehearsal, GraphQL schema validation, no high-severity security findings, completed device matrix, accessibility signoff, privacy/entitlement review, and TestFlight validation. Confirm App Store metadata does not promise unbypassable alarms or unsupported behavior. Stage rollout and monitor the observability signals above.

For a production incident, publish a remote-config emergency disable to prevent new counting schedules while retaining historical data and communicating the state in-app. Roll back client releases through phased-release controls; repair server behavior with a reviewed forward migration/function deployment. Do not delete evidence or rewrite audit rows as an incident response.

