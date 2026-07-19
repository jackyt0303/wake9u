# 03 — Phone motion verification

## Attempt state machine

```
scheduled → active(startedAt fixed) → succeededLocal ─┐
                    │                                  ├→ submitted → finalSuccess
                    └→ failedLocal / sensorUnavailable ─┘               │
                                      │                                  └→ correctedSuccess
                                      └→ provisionalFailure
```

An active attempt begins exactly at the occurrence's scheduled instant, regardless of when its alarm UI is dismissed or the app is opened. Its deadline is exactly five minutes later. The UI may show `awaiting app open` while unavailable, but cannot move the window. Terminal local records are immutable except sync metadata and an allowed server correction status.

## Evidence collection

Start `CMPedometer` live updates when the process can run and query the same fixed interval at completion/recovery. Treat the final query, not the number of UI update callbacks, as the authoritative local aggregate. Persist only: occurrence ID, measurement start/end timestamps, final integer phone step count, capture time, source version, and a generated evidence UUID. Do not persist location, raw accelerometer samples, cadence streams, health samples, or per-step events.

At expiry, normalize the aggregate count. `count >= 10` creates `succeededLocal`; `count < 10` creates `failedLocal`. A count of exactly 9 fails and exactly 10 succeeds. If authorization, hardware, or data availability prevents a trustworthy query, store `sensorUnavailable` with a non-sensitive reason and show it clearly; never manufacture a count. The service can apply its configured policy to that terminal state, normally a failed streak attempt.

The app must tolerate backgrounding/termination: on next launch, load any nonterminal attempt, query historical pedometer data for `[startedAt, endsAt]` if now possible, then finalize it. If it is already overdue and cannot query, submit unavailable evidence. Duplicate callbacks, relaunches, and retries reuse the same evidence UUID/idempotency key.

## Sync and reconciliation

`EvidenceOutbox` writes locally before network submission. It retries with exponential backoff and network reachability but also on app launch/foreground. `submitVerificationEvidence` receives the occurrence ID, evidence UUID, fixed interval, aggregate count, source, and app/build version. It does not accept client-provided user IDs, streak counts, or arbitrary outcome values.

The server validates ownership, occurrence snapshot/version, interval containment within the five-minute window (with only documented clock-skew tolerance), nonnegative integer count, and idempotency. A trusted local success submitted after the scheduler has created a provisional failure is valid if its recorded measurement interval is within the window; it appends an audit event, replaces the provisional outcome, and recomputes the affected streak atomically. A final failure policy must reject late, invalid, or conflicting correction attempts with a reason that the app preserves for support.

## Streak semantics

Count only scheduled, synced, enabled occurrences. Unscheduled dates are neutral: they neither add nor break a streak. A successful eligible occurrence appends a success event; a final failure breaks/resets according to the defined streak algorithm. Recompute from the earliest changed occurrence through the affected period transactionally, rather than trusting a cached counter. Display provisional status distinctly until reconciliation completes.

## UI and tests

The active screen shows deadline, progress toward 10, source/privacy statement, and a non-blocking retry/sync state. It does not show a snooze affordance. Accessibility announces meaningful progress at bounded intervals, not every step; Reduce Motion does not suppress status changes.

Unit tests cover boundary timestamps, 9/10 steps, no upper cap, relaunch recovery, duplicate evidence, offline success, invalid interval, and provisional-failure correction. Use a fake clock/pedometer for deterministic tests, then run device tests with Motion permission allowed/denied and with no network.

