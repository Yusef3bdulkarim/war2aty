-- F27-T12 · error_reports: production monitoring, in our own database.
--
-- Q13 chose this over a third-party crash reporter: our own table behind an
-- Edge Function that accepts only allowlisted error codes. The reasoning is
-- §7 — a hosted reporter could not be shown never to receive document
-- content, and "their scrubber probably catches it" is not a privacy model.
-- It also keeps the free-tier rule intact.
--
-- PRIVACY: no document content, by construction and not by filtering. Every
-- column is a closed code, a uuid, a bounded integer or a dotted version
-- string. There is deliberately NO column for a message, an exception, a
-- stack trace or a field value — so there is nowhere for the text of someone's
-- electricity bill to land even if a future client tried to send it. The
-- Edge Function (`error-report-codes.ts`) enforces the code allowlist; the
-- CHECK constraints below are the second line, so a direct service-role
-- insert cannot write a shape the API would have refused.
--
-- ── Why the per-user daily ceiling lives in SQL ───────────────────────────
--
-- A crash loop can emit thousands of errors a minute, and this endpoint is
-- reachable by every anonymous user (B3's lesson: a write path with no ceiling
-- is a free-tier drain waiting to be found). The client has its own cap of 20
-- per session, but a client-side limit protects nobody — a reinstall resets it
-- and a hostile caller ignores it.
--
-- Counting in TypeScript and then inserting would race with itself the moment
-- two reports arrive at once, which is exactly what a crash loop does. Counting
-- here is closer but still not enough on its own: `count` then `insert` inside
-- one function is a read-then-write, and under READ COMMITTED two concurrent
-- calls can both read the same count and both insert. Hence the per-user
-- advisory lock below — held to the end of the transaction, taken on the user
-- id, so a user's own reports serialise against each other and nobody else's
-- wait.

create table if not exists public.error_reports (
  id                  uuid        primary key default gen_random_uuid(),
  user_id             uuid        not null references auth.users (id) on delete cascade,
  -- One of the app's own codes: an AppFailure code or a LogCrashKind code.
  -- The shape check is intentionally narrow — upper snake case, no spaces, no
  -- punctuation — so even a bypassed API cannot store prose here.
  error_code          text        not null,
  stage               text,
  result_status       text,
  -- The `x-request-id` of the call that failed, when there was one: this is
  -- what lines a client report up with the server's own log line.
  request_id          uuid,
  -- Client-generated id for one analysis session. An identifier, not content.
  analysis_session_id uuid,
  http_status         integer,
  duration_ms         integer,
  app_version         text,
  schema_version      text,
  reported_at         timestamptz not null default now(),

  constraint error_reports_error_code_shape
    check (error_code ~ '^[A-Z][A-Z0-9_]{2,47}$'),
  constraint error_reports_stage_valid
    check (stage is null or stage in ('capture', 'ocr', 'analyze', 'save')),
  constraint error_reports_result_status_valid
    check (result_status is null or result_status in ('success', 'partial', 'failure')),
  constraint error_reports_http_status_valid
    check (http_status is null or http_status between 100 and 599),
  constraint error_reports_duration_ms_valid
    check (duration_ms is null or duration_ms between 0 and 600000),
  -- Shape AND length. The patterns alone allow an unbounded run of digits,
  -- which is not content but is not a version either.
  constraint error_reports_app_version_shape
    check (
      app_version is null
      or (app_version ~ '^\d+\.\d+\.\d+$' and length(app_version) <= 20)
    ),
  constraint error_reports_schema_version_shape
    check (
      schema_version is null
      or (schema_version ~ '^\d+(\.\d+)?$' and length(schema_version) <= 10)
    )
);

comment on table public.error_reports is
  'F27-T12 production error reports. Closed codes and envelope fields only — no document content, no stack traces, no messages.';
comment on column public.error_reports.error_code is
  'One of the app''s own closed codes (AppFailure or LogCrashKind); the Edge Function allowlist is authoritative.';
comment on column public.error_reports.request_id is
  'The failing call''s x-request-id, so a report can be matched to the server log line for the same call.';

-- "What is breaking right now", which is the only query an operator runs
-- under pressure.
create index if not exists error_reports_reported_at_idx
  on public.error_reports (reported_at desc);

-- The ceiling's own lookup: this user's rows today.
create index if not exists error_reports_user_reported_at_idx
  on public.error_reports (user_id, reported_at desc);

-- RLS on, NO policies — service role only (§26), same as the usage tables.
-- A client must never read anyone's reports, including its own: the rows are
-- operational data, not user data to be displayed.
alter table public.error_reports enable row level security;
alter table public.error_reports force row level security;

revoke all on public.error_reports from anon, authenticated;

-- BYPASSRLS does not confer table privileges. DELETE is included for the
-- retention job below.
grant select, insert, delete on public.error_reports to service_role;

-- ── the write path ────────────────────────────────────────────────────────
--
-- Returns 'recorded' or 'rate_limited'. The ceiling is per user per UTC day:
-- the Cairo-day machinery exists for the user-visible quota, where the day
-- boundary is a product promise. Here it is a flood guard, and a guard does
-- not need a timezone.
--
-- 100 rows/user/day is far above anything a working app produces (the client
-- stops at 20 per session) and far below anything that threatens the 500 MB
-- free-tier database: 100 rows is ~15 kB.

create or replace function public.record_error_report(
  p_user_id             uuid,
  p_error_code          text,
  p_stage               text default null,
  p_result_status       text default null,
  p_request_id          uuid default null,
  p_analysis_session_id uuid default null,
  p_http_status         integer default null,
  p_duration_ms         integer default null,
  p_app_version         text default null,
  p_schema_version      text default null,
  p_daily_cap           integer default 100
)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_today integer;
begin
  -- Serialises this user's concurrent reports, so the count below cannot be
  -- read by two callers that then both insert. Per user, so one crash loop
  -- never makes another user's report wait.
  perform pg_advisory_xact_lock(hashtext(p_user_id::text));

  select count(*)
    into v_today
    from public.error_reports r
   where r.user_id = p_user_id
     and r.reported_at >= date_trunc('day', now());

  if v_today >= p_daily_cap then
    return 'rate_limited';
  end if;

  insert into public.error_reports (
    user_id, error_code, stage, result_status, request_id,
    analysis_session_id, http_status, duration_ms, app_version, schema_version
  ) values (
    p_user_id, p_error_code, p_stage, p_result_status, p_request_id,
    p_analysis_session_id, p_http_status, p_duration_ms, p_app_version,
    p_schema_version
  );

  return 'recorded';
end;
$$;

comment on function public.record_error_report is
  'Records one F27-T12 error report, or returns rate_limited past the per-user daily ceiling (default 100).';

revoke execute on function public.record_error_report(
  uuid, text, text, text, uuid, uuid, integer, integer, text, text, integer
) from public;

grant execute on function public.record_error_report(
  uuid, text, text, text, uuid, uuid, integer, integer, text, text, integer
) to service_role;

-- ── retention ─────────────────────────────────────────────────────────────
--
-- 90 days, the same window Q11 fixed for `analysis_attempts`, deliberately
-- rather than a third number to remember: a report older than a release cycle
-- answers no question anyone is still asking. Built exactly like T07's purges
-- (parameterised window, returns the row count, callable from a test) and
-- scheduled after both of them so the three never contend.

create or replace function public.purge_old_error_reports(
  p_older_than interval default interval '90 days'
)
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_deleted integer;
begin
  with purged as (
    delete from public.error_reports
     where reported_at < now() - p_older_than
    returning 1
  )
  select count(*)::integer into v_deleted from purged;

  return v_deleted;
end;
$$;

comment on function public.purge_old_error_reports(interval) is
  'Deletes error_reports older than the given window (default 90 days, matching Q11''s attempts window). Returns the row count.';

revoke execute on function public.purge_old_error_reports(interval) from public;
grant execute on function public.purge_old_error_reports(interval) to service_role;

-- Extends T07's read-only window onto the schedule so this job is testable
-- the same way (PostgREST does not expose the `cron` schema).
create or replace function public.retention_jobs_report()
returns table (jobname text, schedule text, active boolean)
language sql
stable
security definer
set search_path = cron, pg_catalog
as $$
  select j.jobname::text, j.schedule::text, j.active
    from cron.job j
   where j.jobname in (
     'purge-old-analysis-attempts',
     'purge-idle-anonymous-users',
     'purge-old-error-reports'
   );
$$;

revoke execute on function public.retention_jobs_report() from public;
grant execute on function public.retention_jobs_report() to service_role;

-- Unscheduled first so the migration can be re-applied without duplicating
-- the job (same reasoning as T07).
do $$
begin
  if exists (select 1 from cron.job where jobname = 'purge-old-error-reports') then
    perform cron.unschedule('purge-old-error-reports');
  end if;
end;
$$;

select cron.schedule(
  'purge-old-error-reports',
  '30 2 * * *',
  $$select public.purge_old_error_reports()$$
);
