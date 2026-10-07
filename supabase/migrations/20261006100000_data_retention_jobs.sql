-- F27-T07 · Data retention, as pg_cron jobs.
--
-- Q11 fixed the two windows: `analysis_attempts` rows live **90 days**, and an
-- idle anonymous user is deleted after **12 months**. The reasoning recorded
-- there: the quota resets every Cairo day, so 90 days is far longer than any
-- quota decision needs while still being long enough to show an abuse pattern;
-- 12 months keeps a returning user's identity without holding dormant rows for
-- ever.
--
-- ── Why functions, and not DELETEs inlined into cron.schedule ─────────────
--
-- A DELETE living inside a cron job string is untestable: nothing can call it,
-- so the only way to find out whether the predicate is right is to wait a day
-- and look. These are ordinary SQL functions that the jobs call, which means
-- the integration tests can exercise the real predicates directly. It also
-- matches how this schema already works (`expire_stale_reservations`), and the
-- functions return the row count, so a job's effect is observable.
--
-- The retention window is a parameter with the policy as its default, so a test
-- can purge what it just inserted without redefining the policy, while the
-- scheduled call takes the default and keeps Q11's numbers in exactly one
-- place.
--
-- ── What cascades, and what that saves ───────────────────────────────────
--
-- Both `analysis_attempts.user_id` and `analysis_usage_daily.user_id` are
-- `references auth.users (id) on delete cascade`. So deleting an idle user
-- takes their attempts and their per-day counters with it, and the user purge
-- needs no companion cleanup. `global_analysis_usage_daily` is keyed by date
-- with no user column: one row per day, ~365 a year, so it is deliberately left
-- alone rather than given a job of its own.
--
-- ── Deleting straight from auth.users ────────────────────────────────────
--
-- GoTrue's own child tables (identities, sessions, refresh_tokens, mfa_*,
-- one_time_tokens) all cascade from `auth.users`, so a SQL delete is complete.
-- The alternative — scheduling an Edge Function that calls the admin API —
-- needs `pg_net`, a stored service-role key and an HTTP hop, to achieve the
-- same rows being removed. For identities that carry no email, no password and
-- no webhooks, there is nothing for GoTrue to be told about, so the simpler
-- path is the right one. `is_anonymous` is checked explicitly all the same: it
-- keeps this job from ever touching a real account if one is added later.
--
-- ── Why SECURITY DEFINER, and not a grant ────────────────────────────────
--
-- `service_role` has no DELETE on `auth.users` (verified: 42501, and Postgres
-- even suggests `GRANT SELECT, DELETE ON auth.users TO service_role`). Taking
-- that suggestion would hand every Edge Function permanent delete rights over
-- the whole users table in order to enable one nightly sweep. SECURITY DEFINER
-- instead confines the privilege to *this* function, whose predicate is fixed
-- in the body: anonymous identities, idle beyond the window. `search_path` is
-- pinned and every object fully qualified, so the definer rights cannot be
-- redirected at something else. Both purges are defined the same way, so a
-- cron run and a service-role call behave identically.

create extension if not exists pg_cron;

-- ── attempts: 90 days ─────────────────────────────────────────────────────

create or replace function public.purge_old_analysis_attempts(
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
    delete from public.analysis_attempts
     where created_at < now() - p_older_than
    returning 1
  )
  select count(*)::integer into v_deleted from purged;

  return v_deleted;
end;
$$;

comment on function public.purge_old_analysis_attempts(interval) is
  'Deletes analysis_attempts older than the given window (default 90 days, Q11). Returns the row count.';

-- ── idle anonymous users: 12 months ──────────────────────────────────────

create or replace function public.purge_idle_anonymous_users(
  p_idle_for interval default interval '12 months'
)
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_deleted integer;
begin
  -- coalesce, because "idle" has to mean "has not come back", and an identity
  -- that signed up and never returned can carry a null last_sign_in_at. Taking
  -- last_sign_in_at alone would then read as infinitely idle and delete a user
  -- created minutes ago.
  with purged as (
    delete from auth.users
     where is_anonymous
       and coalesce(last_sign_in_at, created_at) < now() - p_idle_for
    returning 1
  )
  select count(*)::integer into v_deleted from purged;

  return v_deleted;
end;
$$;

comment on function public.purge_idle_anonymous_users(interval) is
  'Deletes anonymous auth.users idle for longer than the given window (default 12 months, Q11); their attempts and usage rows follow by cascade. Returns the row count.';

-- ── who may call them ─────────────────────────────────────────────────────
-- Same shape as the quota functions: nothing public, service_role only. The
-- cron jobs run as the migration's own role, which is not subject to this.

revoke execute on function public.purge_old_analysis_attempts(interval) from public;
revoke execute on function public.purge_idle_anonymous_users(interval) from public;

grant execute on function public.purge_old_analysis_attempts(interval) to service_role;
grant execute on function public.purge_idle_anonymous_users(interval) to service_role;

-- ── reading back the schedule ─────────────────────────────────────────────
-- The functions existing is not the policy; the schedule is. PostgREST exposes
-- only `public`, so the `cron` schema is unreachable from a test — this is the
-- narrow, read-only window onto it, returning the two job names and their
-- schedules and nothing else.

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
     'purge-idle-anonymous-users'
   );
$$;

comment on function public.retention_jobs_report() is
  'Read-only view of the F27-T07 retention schedules, so a test can assert the jobs exist (the cron schema is not exposed to PostgREST).';

revoke execute on function public.retention_jobs_report() from public;
grant execute on function public.retention_jobs_report() to service_role;

-- ── the schedules ─────────────────────────────────────────────────────────
-- pg_cron runs on UTC. 01:30 and 02:00 UTC are 03:30 and 04:00 in Cairo
-- (04:30/05:00 in summer) — the quietest part of the day for an app people use
-- against office hours and bill deadlines. Staggered so the two never contend.
--
-- Unscheduled first so this migration can be re-applied: cron.schedule with an
-- existing jobname would otherwise add a duplicate job on some versions.

do $$
begin
  if exists (select 1 from cron.job where jobname = 'purge-old-analysis-attempts') then
    perform cron.unschedule('purge-old-analysis-attempts');
  end if;
  if exists (select 1 from cron.job where jobname = 'purge-idle-anonymous-users') then
    perform cron.unschedule('purge-idle-anonymous-users');
  end if;
end;
$$;

select cron.schedule(
  'purge-old-analysis-attempts',
  '30 1 * * *',
  $$select public.purge_old_analysis_attempts()$$
);

select cron.schedule(
  'purge-idle-anonymous-users',
  '0 2 * * *',
  $$select public.purge_idle_anonymous_users()$$
);
