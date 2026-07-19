# 04 — Optional Watch companion motion

## Scope and non-negotiables

The Watch app is optional. The iPhone schedule and phone pedometer remain authoritative; pairing, Watch app installation, HealthKit authorization, workout start, connectivity, or Watch data failure must never prevent a phone success. The Watch displays the next schedule, current attempt progress, permission state, and a clear `supplemental` label.

## Workout and evidence flow

During an active phone attempt, the Watch may invite the user to explicitly start a visible workout. Only after the user action and HealthKit authorization, start the appropriate `HKWorkoutSession` and collect the minimum cadence/step aggregate permitted by HealthKit/CoreMotion. Stop/end the session at the fixed phone deadline or user end. Persist and transmit only occurrence ID, measurement interval, aggregate count/cadence summary, source version, and evidence UUID. Do not export raw HealthKit samples or routes.

Use `WCSession` application context for latest schedule/attempt state and queued `transferUserInfo` (or equivalent reliable transfer) for immutable terminal aggregate evidence. Messages must be idempotent and signed/validated by the authenticated phone session; include a schema version. The phone acknowledges receipt and retains its own durable copy. The Watch retries via its platform transfer mechanism, not custom wake loops.

## Phone reconciliation

The phone validates Watch evidence interval against the same occurrence window and stores it as supplemental evidence. It must not turn absent Watch evidence into failure or replace a phone success/failure threshold decision in v1. The backend accepts it for audit/product research only under the same owner/occurrence controls; any future policy that uses it requires a versioned remote-config and explicit product decision.

## States and recovery

- Unpaired/not installed: show no error on iPhone; offer optional companion install only where supported.
- HealthKit denied: show schedule/progress without workout controls.
- Workout not started: no Watch evidence; phone verification proceeds.
- Connectivity delayed: display local Watch terminal state; transfer later; phone remains authoritative.
- Watch session interrupted: end safely and send only a valid aggregate interval if one exists.

## Tests

Unit-test message schema, duplicate delivery, interval validation, and no-Watch fallbacks. Test with paired/unpaired devices, HealthKit denial, locked phone, delayed transfer, app termination, and an interrupted workout. Confirm HealthKit privacy strings, no raw sample egress, and that the iPhone can fully finish an attempt with the Watch switched off.

