-- Wake9u's client role reads RLS-protected views and invokes the narrow
-- functions below. It must not receive write grants to domain tables.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  shortcut_name text,
  constraint shortcut_name_length check (shortcut_name is null or char_length(shortcut_name) between 1 and 200)
);

create table if not exists public.remote_config_releases (
  id uuid primary key default gen_random_uuid(),
  version integer not null unique check (version > 0),
  payload jsonb not null,
  is_published boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  constraint remote_config_payload_is_object check (jsonb_typeof(payload) = 'object')
);

create table if not exists public.alarm_configurations (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  weekdays smallint[] not null,
  local_time time not null,
  timezone text not null,
  is_enabled boolean not null default false,
  version integer not null default 1 check (version > 0),
  is_primary boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint alarm_config_weekdays_not_empty check (cardinality(weekdays) > 0),
  constraint alarm_config_weekdays_valid check (weekdays <@ array[1,2,3,4,5,6,7]::smallint[]),
  constraint alarm_config_timezone_not_blank check (char_length(timezone) between 1 and 128)
);
create unique index if not exists alarm_configurations_one_primary_per_profile
  on public.alarm_configurations(profile_id) where is_primary;

create table if not exists public.alarm_occurrences (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  configuration_id uuid not null references public.alarm_configurations(id) on delete restrict,
  local_date date not null,
  scheduled_at timestamptz not null,
  verification_ends_at timestamptz not null,
  timezone text not null,
  configuration_snapshot jsonb not null,
  remote_config_snapshot jsonb not null,
  selected_playlist_reference text,
  outcome text not null default 'scheduled' check (outcome in ('scheduled', 'active', 'success', 'provisional_failure', 'failure', 'sensor_unavailable')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint alarm_occurrences_window_is_five_minutes check (verification_ends_at = scheduled_at + interval '5 minutes'),
  constraint alarm_occurrences_config_snapshot_is_object check (jsonb_typeof(configuration_snapshot) = 'object'),
  constraint alarm_occurrences_remote_snapshot_is_object check (jsonb_typeof(remote_config_snapshot) = 'object')
);
create unique index if not exists alarm_occurrences_one_per_local_day
  on public.alarm_occurrences(profile_id, local_date);
create index if not exists alarm_occurrences_reconciliation_index
  on public.alarm_occurrences(outcome, verification_ends_at);

create table if not exists public.verification_evidence (
  id uuid primary key,
  occurrence_id uuid not null references public.alarm_occurrences(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  source text not null check (source in ('phone_pedometer', 'watch_supplemental')),
  measurement_started_at timestamptz not null,
  measurement_ended_at timestamptz not null,
  aggregate_step_count integer not null check (aggregate_step_count >= 0),
  source_version text not null,
  captured_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint verification_evidence_measurement_order check (measurement_ended_at >= measurement_started_at)
);
create unique index if not exists verification_evidence_occurrence_evidence_id
  on public.verification_evidence(occurrence_id, id);

create table if not exists public.occurrence_outcome_events (
  id bigint generated always as identity primary key,
  occurrence_id uuid not null references public.alarm_occurrences(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  outcome text not null check (outcome in ('scheduled', 'active', 'success', 'provisional_failure', 'failure', 'sensor_unavailable')),
  reason text not null,
  evidence_id uuid references public.verification_evidence(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists occurrence_outcome_events_occurrence_index
  on public.occurrence_outcome_events(occurrence_id, created_at);

create table if not exists public.streak_events (
  id bigint generated always as identity primary key,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  occurrence_id uuid not null references public.alarm_occurrences(id) on delete cascade,
  event_type text not null check (event_type in ('success', 'break', 'recomputed')),
  created_at timestamptz not null default now()
);

create table if not exists public.streak_summary (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  current_streak integer not null default 0 check (current_streak >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.domain_mutation_idempotency (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  operation text not null,
  idempotency_key uuid not null,
  response jsonb not null,
  created_at timestamptz not null default now(),
  primary key (profile_id, operation, idempotency_key)
);

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.create_profile_for_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id) values (new.id) on conflict (id) do nothing;
  insert into public.streak_summary(profile_id) values (new.id) on conflict (profile_id) do nothing;
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
drop trigger if exists alarm_configurations_set_updated_at on public.alarm_configurations;
create trigger alarm_configurations_set_updated_at before update on public.alarm_configurations for each row execute function public.set_updated_at();
drop trigger if exists alarm_occurrences_set_updated_at on public.alarm_occurrences;
create trigger alarm_occurrences_set_updated_at before update on public.alarm_occurrences for each row execute function public.set_updated_at();
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.create_profile_for_new_user();

alter table public.profiles enable row level security;
alter table public.remote_config_releases enable row level security;
alter table public.alarm_configurations enable row level security;
alter table public.alarm_occurrences enable row level security;
alter table public.verification_evidence enable row level security;
alter table public.occurrence_outcome_events enable row level security;
alter table public.streak_events enable row level security;
alter table public.streak_summary enable row level security;
alter table public.domain_mutation_idempotency enable row level security;

create policy "profiles are self readable" on public.profiles for select using (id = auth.uid());
create policy "published config is readable" on public.remote_config_releases for select using (is_published);
create policy "configurations are self readable" on public.alarm_configurations for select using (profile_id = auth.uid());
create policy "occurrences are self readable" on public.alarm_occurrences for select using (profile_id = auth.uid());
create policy "evidence is self readable" on public.verification_evidence for select using (profile_id = auth.uid());
create policy "outcome events are self readable" on public.occurrence_outcome_events for select using (profile_id = auth.uid());
create policy "streak events are self readable" on public.streak_events for select using (profile_id = auth.uid());
create policy "streak summaries are self readable" on public.streak_summary for select using (profile_id = auth.uid());

create or replace view public.my_dashboard with (security_invoker = true) as
select
  s.current_streak,
  s.updated_at as streak_updated_at,
  o.id as occurrence_id,
  o.local_date,
  o.scheduled_at,
  o.verification_ends_at,
  o.outcome
from public.streak_summary s
left join lateral (
  select * from public.alarm_occurrences
  where profile_id = s.profile_id and scheduled_at >= now() - interval '1 day'
  order by scheduled_at asc limit 1
) o on true
where s.profile_id = auth.uid();

create or replace view public.my_alarm_history with (security_invoker = true) as
select id, local_date, scheduled_at, verification_ends_at, outcome, created_at, updated_at
from public.alarm_occurrences where profile_id = auth.uid();

create or replace view public.my_alarm_configuration with (security_invoker = true) as
select id, weekdays, local_time, timezone, is_enabled, version, updated_at
from public.alarm_configurations where profile_id = auth.uid() and is_primary;

create or replace function public.recompute_streak(p_profile_id uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare
  v_row record;
  v_streak integer := 0;
begin
  for v_row in
    select id, outcome from public.alarm_occurrences
    where profile_id = p_profile_id and outcome in ('success', 'failure', 'sensor_unavailable')
    order by local_date desc
  loop
    if v_row.outcome = 'success' then
      v_streak := v_streak + 1;
    else
      exit;
    end if;
  end loop;
  insert into public.streak_summary(profile_id, current_streak, updated_at)
  values (p_profile_id, v_streak, now())
  on conflict (profile_id) do update set current_streak = excluded.current_streak, updated_at = excluded.updated_at;
  insert into public.streak_events(profile_id, occurrence_id, event_type)
  select p_profile_id, id, 'recomputed' from public.alarm_occurrences
  where profile_id = p_profile_id order by local_date desc limit 1;
  return v_streak;
end;
$$;

create or replace function public.save_alarm_configuration(
  p_weekdays smallint[],
  p_local_time time,
  p_timezone text,
  p_is_enabled boolean,
  p_idempotency_key uuid
) returns public.alarm_configurations
language plpgsql security definer set search_path = public as $$
declare
  v_profile uuid := auth.uid();
  v_existing public.alarm_configurations;
  v_result public.alarm_configurations;
  v_cached_response jsonb;
begin
  if v_profile is null then raise exception 'authentication_required' using errcode = '28000'; end if;
  select response into v_cached_response from public.domain_mutation_idempotency
  where profile_id = v_profile and operation = 'save_alarm_configuration' and idempotency_key = p_idempotency_key;
  if found then
    select * into v_result from jsonb_populate_record(null::public.alarm_configurations, v_cached_response);
    return v_result;
  end if;
  if cardinality(p_weekdays) = 0 or not (p_weekdays <@ array[1,2,3,4,5,6,7]::smallint[]) then
    raise exception 'invalid_weekdays' using errcode = '22023';
  end if;
  if p_timezone is null or not exists (select 1 from pg_timezone_names where name = p_timezone) then
    raise exception 'invalid_timezone' using errcode = '22023';
  end if;
  select * into v_existing from public.alarm_configurations where profile_id = v_profile and is_primary for update;
  if found then
    update public.alarm_configurations
    set weekdays = p_weekdays, local_time = p_local_time, timezone = p_timezone,
        is_enabled = p_is_enabled, version = v_existing.version + 1
    where id = v_existing.id returning * into v_result;
  else
    insert into public.alarm_configurations(profile_id, weekdays, local_time, timezone, is_enabled)
    values (v_profile, p_weekdays, p_local_time, p_timezone, p_is_enabled)
    returning * into v_result;
  end if;
  insert into public.domain_mutation_idempotency(profile_id, operation, idempotency_key, response)
  values (v_profile, 'save_alarm_configuration', p_idempotency_key, to_jsonb(v_result))
  on conflict (profile_id, operation, idempotency_key) do nothing;
  return v_result;
end;
$$;

create or replace function public.submit_verification_evidence(
  p_evidence_id uuid,
  p_occurrence_id uuid,
  p_source text,
  p_measurement_started_at timestamptz,
  p_measurement_ended_at timestamptz,
  p_aggregate_step_count integer,
  p_source_version text,
  p_captured_at timestamptz,
  p_idempotency_key uuid
) returns public.alarm_occurrences
language plpgsql security definer set search_path = public as $$
declare
  v_profile uuid := auth.uid();
  v_occurrence public.alarm_occurrences;
  v_threshold integer;
  v_outcome text;
  v_prior_outcome text;
  v_cached_response jsonb;
begin
  if v_profile is null then raise exception 'authentication_required' using errcode = '28000'; end if;
  select response into v_cached_response from public.domain_mutation_idempotency
  where profile_id = v_profile and operation = 'submit_verification_evidence' and idempotency_key = p_idempotency_key;
  if found then
    select * into v_occurrence from jsonb_populate_record(null::public.alarm_occurrences, v_cached_response);
    return v_occurrence;
  end if;
  if p_source not in ('phone_pedometer', 'watch_supplemental') or p_aggregate_step_count < 0 then
    raise exception 'invalid_evidence' using errcode = '22023';
  end if;
  select * into v_occurrence from public.alarm_occurrences where id = p_occurrence_id and profile_id = v_profile for update;
  if not found then raise exception 'occurrence_not_found' using errcode = 'P0002'; end if;
  if exists (select 1 from public.verification_evidence where id = p_evidence_id) then return v_occurrence; end if;
  if p_measurement_started_at < v_occurrence.scheduled_at or p_measurement_ended_at > v_occurrence.verification_ends_at then
    raise exception 'evidence_outside_window' using errcode = '22023';
  end if;
  insert into public.verification_evidence(id, occurrence_id, profile_id, source, measurement_started_at, measurement_ended_at, aggregate_step_count, source_version, captured_at)
  values (p_evidence_id, p_occurrence_id, v_profile, p_source, p_measurement_started_at, p_measurement_ended_at, p_aggregate_step_count, p_source_version, p_captured_at);
  if p_source = 'watch_supplemental' then return v_occurrence; end if;
  v_threshold := coalesce((v_occurrence.remote_config_snapshot #>> '{thresholds,phoneSteps}')::integer, 10);
  v_outcome := case when p_aggregate_step_count >= v_threshold then 'success' else 'failure' end;
  v_prior_outcome := v_occurrence.outcome;
  update public.alarm_occurrences set outcome = v_outcome where id = v_occurrence.id returning * into v_occurrence;
  insert into public.occurrence_outcome_events(occurrence_id, profile_id, outcome, reason, evidence_id)
  values (v_occurrence.id, v_profile, v_outcome,
    case
      when v_outcome = 'success' and v_prior_outcome = 'provisional_failure' then 'late_local_success_accepted'
      when v_outcome = 'success' then 'phone_threshold_met'
      else 'phone_threshold_not_met'
    end,
    p_evidence_id);
  perform public.recompute_streak(v_profile);
  insert into public.domain_mutation_idempotency(profile_id, operation, idempotency_key, response)
  values (v_profile, 'submit_verification_evidence', p_idempotency_key, to_jsonb(v_occurrence))
  on conflict (profile_id, operation, idempotency_key) do nothing;
  return v_occurrence;
end;
$$;

create or replace function public.mark_overdue_occurrences()
returns integer language plpgsql security definer set search_path = public as $$
declare v_count integer;
begin
  with updated as (
    update public.alarm_occurrences set outcome = 'provisional_failure'
    where outcome in ('scheduled', 'active') and verification_ends_at < now()
    returning id, profile_id
  ), events as (
    insert into public.occurrence_outcome_events(occurrence_id, profile_id, outcome, reason)
    select id, profile_id, 'provisional_failure', 'verification_window_expired' from updated returning profile_id
  ) select count(*) into v_count from events;
  return v_count;
end;
$$;

revoke all on all tables in schema public from anon, authenticated;
grant select on public.profiles, public.remote_config_releases, public.alarm_configurations, public.alarm_occurrences,
  public.verification_evidence, public.occurrence_outcome_events, public.streak_events, public.streak_summary to authenticated;
grant select on public.my_dashboard, public.my_alarm_history, public.my_alarm_configuration to authenticated;
grant execute on function public.save_alarm_configuration(smallint[], time, text, boolean, uuid) to authenticated;
grant execute on function public.submit_verification_evidence(uuid, uuid, text, timestamptz, timestamptz, integer, text, timestamptz, uuid) to authenticated;
