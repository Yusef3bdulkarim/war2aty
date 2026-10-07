-- F27-T16 (security review) — close the SECURITY DEFINER execute hole.
--
-- THE DEFECT
--
-- Every earlier migration in this project wrote `revoke execute on function
-- ... from public`. That revokes the built-in PUBLIC pseudo-role's grant and
-- nothing else. On a hosted Supabase project `anon` and `authenticated` hold
-- their *own* EXECUTE grant, from the default privileges the platform's
-- initial schema installs, and a revoke from PUBLIC does not touch those. So
-- every SECURITY DEFINER function in `public` was callable by anyone holding
-- the publishable key — which ships in the APK and sits in this public repo.
--
-- The worst of them, purge_idle_anonymous_users, deletes from auth.users with
-- a caller-supplied window: `{"p_idle_for":"00:00:00"}` deleted every
-- anonymous user of the app, and their attempts, usage and error_reports by
-- cascade, in one unauthenticated request.
--
-- WHY NO TEST CAUGHT IT, AND WHY THE LOCAL STACK CANNOT
--
-- pg_default_acl holds two entries for functions in `public`: one granted by
-- `supabase_admin` ({postgres=X,anon=X,authenticated=X,service_role=X}) and
-- one by `postgres` ({postgres=X}). Which applies depends on which role
-- creates the function. `supabase db reset` applies migrations as `postgres`,
-- so locally anon never gets EXECUTE and the hole is invisible; the hosted
-- platform applies them as `supabase_admin`, so hosted was wide open.
-- Measured 2026-10-07 with the publishable key against the read-only
-- retention_jobs_report(), which carries the identical revoke:
-- production 200, staging 200, local 401/42501.
--
-- That asymmetry is why this migration does not merely revoke: it asserts its
-- own postcondition at the end, so it reports the truth on whatever platform
-- runs it instead of passing locally and lying about production.
--
-- THE FIX, IN TWO INDEPENDENT LAYERS
--
-- 1. Revoke EXECUTE from `anon` and `authenticated` explicitly, for every
--    function in `public`. Nothing legitimate is lost: the app never calls
--    these RPCs: it goes through the Edge Functions, which hold service_role.
-- 2. Make the arguments incapable of widening what a function destroys, so a
--    future grant regression is embarrassing rather than catastrophic. The
--    windows are clamped to a floor and the report ceiling to its maximum.
--
-- Layer 2 matters because layer 1 is one `grant` away from being undone, and
-- the thing it protects is the whole user base.

-- ── 1. who may execute ────────────────────────────────────────────────────
--
-- `from public, anon, authenticated` — all three, because each holds a grant
-- from a different source. service_role's grants are re-stated below so the
-- intent survives a reader skimming only this file.

revoke execute on function public.purge_old_analysis_attempts(interval)
  from public, anon, authenticated;
revoke execute on function public.purge_idle_anonymous_users(interval)
  from public, anon, authenticated;
revoke execute on function public.purge_old_error_reports(interval)
  from public, anon, authenticated;
revoke execute on function public.retention_jobs_report()
  from public, anon, authenticated;
revoke execute on function public.record_error_report(
  uuid, text, text, text, uuid, uuid, integer, integer, text, text, integer
) from public, anon, authenticated;

-- The quota RPCs are SECURITY INVOKER, so a reaching caller already failed on
-- the missing table grant. Revoked anyway: their protection should not depend
-- on a second mechanism holding.
revoke execute on function public.expire_stale_reservations(uuid)
  from public, anon, authenticated;
revoke execute on function public.reserve_analysis_slot(
  uuid, date, uuid, text, integer, integer, integer
) from public, anon, authenticated;
revoke execute on function public.finalize_analysis_slot(uuid, boolean, text)
  from public, anon, authenticated;

-- A trigger function, so a direct call errors on the missing trigger context
-- rather than doing anything. It was never revoked at all, which is why it is
-- the one function that still read executable-by-anon locally.
revoke execute on function public.set_updated_at()
  from public, anon, authenticated;

grant execute on function public.purge_old_analysis_attempts(interval) to service_role;
grant execute on function public.purge_idle_anonymous_users(interval) to service_role;
grant execute on function public.purge_old_error_reports(interval) to service_role;
grant execute on function public.retention_jobs_report() to service_role;
grant execute on function public.record_error_report(
  uuid, text, text, text, uuid, uuid, integer, integer, text, text, integer
) to service_role;
grant execute on function public.expire_stale_reservations(uuid) to service_role;
grant execute on function public.reserve_analysis_slot(
  uuid, date, uuid, text, integer, integer, integer
) to service_role;
grant execute on function public.finalize_analysis_slot(uuid, boolean, text) to service_role;

-- ── 2. arguments that cannot widen the blast radius ───────────────────────
--
-- Each purge keeps its parameter, because the tests need a window they can
-- choose, and the cron jobs pass none. What changes is that the parameter can
-- now only ever make the window *larger* than the floor. A caller asking for
-- "everything" gets the floor instead of the whole table.
--
-- The floors are far below the real retention windows (90 days and 12 months)
-- and far above zero, so the jobs and the tests are unaffected while
-- "delete everything" stops being expressible.

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
  v_window  interval;
begin
  -- A null argument means "use the policy", not "match everything".
  v_window := greatest(coalesce(p_older_than, interval '90 days'), interval '7 days');

  with purged as (
    delete from public.analysis_attempts
     where created_at < now() - v_window
    returning 1
  )
  select count(*)::integer into v_deleted from purged;

  return v_deleted;
end;
$$;

comment on function public.purge_old_analysis_attempts(interval) is
  'Deletes analysis_attempts older than the given window (default 90 days, Q11; floored at 7 days by F27-T16 so the argument cannot widen it to everything). Returns the row count.';

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
  v_window  interval;
begin
  -- The floor that stops this from ever being a one-request wipe of the user
  -- base. 30 days is two orders of magnitude inside the 12-month policy, so
  -- no legitimate call notices it.
  v_window := greatest(coalesce(p_idle_for, interval '12 months'), interval '30 days');

  -- coalesce, because "idle" has to mean "has not come back", and an identity
  -- that signed up and never returned can carry a null last_sign_in_at. Taking
  -- last_sign_in_at alone would then read as infinitely idle and delete a user
  -- created minutes ago.
  with purged as (
    delete from auth.users
     where is_anonymous
       and coalesce(last_sign_in_at, created_at) < now() - v_window
    returning 1
  )
  select count(*)::integer into v_deleted from purged;

  return v_deleted;
end;
$$;

comment on function public.purge_idle_anonymous_users(interval) is
  'Deletes anonymous auth.users idle for longer than the given window (default 12 months, Q11; floored at 30 days by F27-T16 so the argument cannot widen it to the whole user base); their attempts and usage rows follow by cascade. Returns the row count.';

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
  v_window  interval;
begin
  v_window := greatest(coalesce(p_older_than, interval '90 days'), interval '7 days');

  with purged as (
    delete from public.error_reports
     where reported_at < now() - v_window
    returning 1
  )
  select count(*)::integer into v_deleted from purged;

  return v_deleted;
end;
$$;

comment on function public.purge_old_error_reports(interval) is
  'Deletes error_reports older than the given window (default 90 days, matching Q11''s attempts window; floored at 7 days by F27-T16). Returns the row count.';

-- record_error_report: two caller-supplied values decided its own limits.
--
-- p_daily_cap is now a ceiling the caller can only lower, never raise, so
-- passing 2147483647 no longer disables the flood guard this function exists
-- to provide.
--
-- p_user_id is whose report it is. Its intended caller is the Edge Function,
-- which has already taken the id from a verified JWT and reaches here as
-- service_role with no user context, so auth.uid() is null and the check does
-- not apply. A caller that *does* arrive with a user JWT may now only file
-- reports against itself, so monitoring rows can no longer be forged against
-- another user.
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
  v_cap   integer;
  v_caller uuid;
begin
  v_caller := auth.uid();
  if v_caller is not null and v_caller <> p_user_id then
    raise exception 'record_error_report: p_user_id must be the authenticated user'
      using errcode = '42501';
  end if;

  -- A ceiling, not a parameter: the caller may ask for less, never for more.
  v_cap := least(coalesce(p_daily_cap, 100), 100);

  -- Serialises this user's concurrent reports, so the count below cannot be
  -- read by two callers that then both insert. Per user, so one crash loop
  -- never makes another user's report wait.
  perform pg_advisory_xact_lock(hashtext(p_user_id::text));

  select count(*)
    into v_today
    from public.error_reports r
   where r.user_id = p_user_id
     and r.reported_at >= date_trunc('day', now());

  if v_today >= v_cap then
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
  'Records one F27-T12 error report, or returns rate_limited past the per-user daily ceiling (100, which F27-T16 made a ceiling the caller can only lower). A caller bearing a user JWT may only file against itself.';

-- `create or replace` preserves the existing ACL, so the five replaced
-- functions keep the revokes above. Re-stated regardless, because relying on
-- that is exactly the kind of assumption this migration exists to retire.
revoke execute on function public.purge_old_analysis_attempts(interval)
  from public, anon, authenticated;
revoke execute on function public.purge_idle_anonymous_users(interval)
  from public, anon, authenticated;
revoke execute on function public.purge_old_error_reports(interval)
  from public, anon, authenticated;
revoke execute on function public.record_error_report(
  uuid, text, text, text, uuid, uuid, integer, integer, text, text, integer
) from public, anon, authenticated;

grant execute on function public.purge_old_analysis_attempts(interval) to service_role;
grant execute on function public.purge_idle_anonymous_users(interval) to service_role;
grant execute on function public.purge_old_error_reports(interval) to service_role;
grant execute on function public.record_error_report(
  uuid, text, text, text, uuid, uuid, integer, integer, text, text, integer
) to service_role;

-- ── 3. the migration proves itself ────────────────────────────────────────
--
-- The whole defect was that the local result said nothing about production.
-- So rather than trust the statements above, ask the catalogue: is there any
-- function left in `public` that a client role may execute? On the platform
-- where this actually matters, this is the line that would have caught it.
--
-- It raises rather than warns: a half-applied security migration should fail
-- the deploy, not leave a notice in a log nobody reads.

do $$
declare
  v_leaked text;
begin
  select string_agg(p.oid::regprocedure::text, ', ' order by p.oid::regprocedure::text)
    into v_leaked
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and (has_function_privilege('anon', p.oid, 'execute')
          or has_function_privilege('authenticated', p.oid, 'execute'));

  if v_leaked is not null then
    raise exception
      'F27-T16: anon/authenticated can still execute: %. Revoke before deploying.',
      v_leaked;
  end if;

  -- And the legitimate caller must still work, or this migration has broken
  -- the Edge Functions instead of protecting them.
  if not has_function_privilege('service_role',
       'public.record_error_report(uuid, text, text, text, uuid, uuid, integer, integer, text, text, integer)',
       'execute') then
    raise exception 'F27-T16: service_role lost EXECUTE on record_error_report';
  end if;
end $$;
