# 05 — Supabase GraphQL domain

## Database model

Use UUID primary keys, `timestamptz` for instants, `text` for IANA timezone, created/updated timestamps, and append-only audit rows. Add migrations in ordered, reversible-forward files and run them against an ephemeral database in CI.

| Table | Purpose / key fields |
| --- | --- |
| `profiles` | one row per `auth.users` ID; display/preferences metadata |
| `alarm_configurations` | owner, weekdays/local time/timezone, enabled/version, sync status; one primary active configuration constraint |
| `alarm_occurrences` | owner/config, local date, scheduled instant, window, immutable config and remote-config JSON snapshots, state |
| `verification_evidence` | occurrence, evidence UUID, source, interval, aggregate count, capture metadata; unique `(occurrence_id, evidence_uuid)` |
| `occurrence_outcome_events` | append-only outcome/audit transition and reason |
| `streak_events` | derived append-only successes/breaks with source occurrence |
| `streak_summary` | materialized/current derived summary per profile |
| `remote_config_releases` | versioned read-only threshold/mapping/policy/min-version/emergency-disable payload |

Add constraints: unique `(profile_id, configuration role)` for the single primary schedule; unique `(profile_id, local_date)` on streak-counting occurrences; `ends_at = scheduled_at + interval '5 minutes'`; nonnegative evidence count; valid time weekday/value checks; and foreign keys with deliberate deletion behavior. Store snapshots as JSONB validated by a function/schema version, never a mutable join.

## RLS and GraphQL surface

Enable RLS on every application table. Base table policies permit the owner to select only their own rows; client insert/update/delete policies are absent or narrowly limited for read-only bootstrap tables. `remote_config_releases` is client-selectable only for published releases, never client-writable. `profiles` is self-only. Admin/scheduler access uses server-only roles, never the anon key.

Expose `pg_graphql` with views for `my_dashboard`, `my_alarm_history`, `my_alarm_configuration`, and `published_remote_config`; views are security-invoker/appropriately RLS-safe and expose no raw sensitive fields. Prefer generated GraphQL queries over PostgREST for product reads. Generate Apollo operation types from checked-in `.graphql` operations and validate schema changes in CI.

Provide narrow `SECURITY DEFINER` domain functions with a locked `search_path`, explicit `auth.uid()` ownership check, input validation, result types, and execute grants only to authenticated users:

- `save_alarm_configuration(input, idempotency_key)`: validates one primary schedule, timezone/weekday/time, auth, and emergency/min-version policy; versions config; snapshots/creates future occurrence horizon; returns authoritative config and occurrence preview.
- `submit_verification_evidence(input, idempotency_key)`: validates fixed interval/count/ownership and idempotency; writes evidence/event; resolves or corrects provisional outcome; recomputes streak atomically.
- `save_shortcut_preference(input, idempotency_key)`: validates supported shortcut policy and stores name/reference; no URL execution server-side.
- `delete_my_account(idempotency_key)`: exports/deletes according to retention policy and revokes active product data.

GraphQL mutations call these functions only. Raw domain tables are not client writable.

## Jobs and reconciliation

Run a minute-level scheduled database job with a service role. It creates a rolling horizon for enabled, synced configurations, resolves local-day/DST policy once, and marks overdue unresolved occurrences provisional failures. It must lock/idempotently upsert by `(profile_id, local_date)` and never mutate historical snapshots. A second or combined transaction recalculates only impacted streak summaries/events when outcome changes.

The late-success path is deliberate: on an otherwise valid local success, insert evidence, append `late_local_success_accepted`, supersede the provisional failure event, resolve final success, then recompute streak in one transaction. Invalid window, identity mismatch, final non-correctable state, duplicate with different payload, or emergency-disabled future configuration returns a typed error.

## Remote config

Remote config is a signed/versioned, published read-only release with: success threshold (initially 10), mascot state mappings, supported Shortcut policy, minimum app version, and emergency disable. It cannot contain executable code, arbitrary URLs, user targeting, or authorization bypasses. The client caches the last valid release, honors an emergency disable on refresh, and snapshots release/version onto each occurrence. Server validation always uses the occurrence snapshot where appropriate, not a later mutable value.

## Tests and operations

Integration tests must prove GraphQL authorization/tenant isolation, unauthorized raw writes rejection, function idempotency, scheduler idempotency, DST/timezone fixture results, overdue provisional failures, valid late correction, duplicate conflict rejection, and emergency disable. Monitor job success/lag, function failures by typed code, occurrence backlog, and reconciliation latency with non-sensitive aggregate metrics. Back up Postgres and rehearse migration rollback via a new forward migration, never production table edits.

