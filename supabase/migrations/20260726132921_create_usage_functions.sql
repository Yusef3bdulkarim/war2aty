-- F06-T07 · Atomic slot reservation.
--
-- The quota is enforced here, in SQL, rather than in the Edge Function. A
-- read-then-write in TypeScript cannot be made race-safe: three taps arriving
-- together would each read `successful_count = 0`, each decide there is room,
-- and each proceed. Doing the check and the increment in one locked statement
-- is what actually caps the user at three.
--
-- Lifecycle: reserve -> (succeeded | failed | expired)
--   reserve   takes a slot before the AI is called
--   finalize  converts it to a success, or releases it on failure
--   expire    reclaims slots abandoned by a crash or a lost connection

-- ── usage_date on attempts ────────────────────────────────────────────────
-- Finalize must decrement the SAME daily row that reserve incremented. Without
-- this column it would decrement "today", so an analysis reserved at 23:59:58
-- and finished at 00:00:05 would release a slot on the new day (driving it to
-- 0 and failing the non-negative CHECK) while leaving yesterday's reservation
-- stranded — silently costing the user one analysis until the row aged out.

alter table public.analysis_attempts
  add column if not exists usage_date date;

update public.analysis_attempts
   set usage_date = (created_at at time zone 'Africa/Cairo')::date
 where usage_date is null;

alter table public.analysis_attempts
  alter column usage_date set not null;

comment on column public.analysis_attempts.usage_date is
  'The Cairo day whose counters this attempt reserved. Finalize must release the day it took, not the current one.';

-- Lets the sweep and finalize find the counter row directly.
create index if not exists analysis_attempts_user_day_idx
  on public.analysis_attempts (user_id, usage_date);

-- ── expire abandoned reservations ─────────────────────────────────────────

create or replace function public.expire_stale_reservations(
  p_user_id uuid default null
)
returns integer
language plpgsql
as $$
declare
  v_released integer;
begin
  -- One statement so the attempt flip and the counter release cannot diverge.
  with expired as (
    update public.analysis_attempts
       set status = 'expired',
           completed_at = now()
     where status = 'reserved'
       and expires_at <= now()
       and (p_user_id is null or user_id = p_user_id)
    returning user_id, usage_date
  ),
  grouped as (
    select user_id, usage_date, count(*)::integer as released
      from expired
     group by user_id, usage_date
  ),
  applied as (
    update public.analysis_usage_daily u
       set reserved_count = greatest(0, u.reserved_count - g.released)
      from grouped g
     where u.user_id = g.user_id
       and u.usage_date = g.usage_date
    returning g.released
  )
  select coalesce(sum(released), 0)::integer into v_released from applied;

  return v_released;
end;
$$;

comment on function public.expire_stale_reservations(uuid) is
  'Reclaims slots whose expires_at has passed. Without it a crashed request would hold a slot until midnight.';

-- ── reserve ───────────────────────────────────────────────────────────────

create or replace function public.reserve_analysis_slot(
  p_user_id           uuid,
  p_usage_date        date,
  p_request_id        uuid,
  p_installation_hash text,
  p_daily_limit       integer,
  p_ttl_seconds       integer
)
returns table (
  outcome        text,
  used_today     integer,
  reserved_today integer
)
language plpgsql
as $$
declare
  v_used     integer;
  v_reserved integer;
begin
  -- Fail closed: a missing or nonsensical limit must never mean "unlimited".
  if p_daily_limit is null or p_daily_limit < 1 then
    select coalesce(d.successful_count, 0), coalesce(d.reserved_count, 0)
      into v_used, v_reserved
      from public.analysis_usage_daily d
     where d.user_id = p_user_id and d.usage_date = p_usage_date;

    return query
      select 'limit_reached'::text, coalesce(v_used, 0), coalesce(v_reserved, 0);
    return;
  end if;

  -- Self-healing: reclaim this user's abandoned slots before judging them.
  perform public.expire_stale_reservations(p_user_id);

  -- Idempotency. A retry carrying the same request_id must not take a second
  -- slot; the primary key decides that, not a prior SELECT that could race.
  insert into public.analysis_attempts (
    request_id, user_id, usage_date, installation_hash, expires_at
  )
  values (
    p_request_id, p_user_id, p_usage_date, p_installation_hash,
    now() + make_interval(secs => greatest(p_ttl_seconds, 1))
  )
  on conflict (request_id) do nothing;

  if not found then
    select coalesce(d.successful_count, 0), coalesce(d.reserved_count, 0)
      into v_used, v_reserved
      from public.analysis_usage_daily d
     where d.user_id = p_user_id and d.usage_date = p_usage_date;

    return query
      select 'duplicate'::text, coalesce(v_used, 0), coalesce(v_reserved, 0);
    return;
  end if;

  -- The atomic gate. ON CONFLICT DO UPDATE takes a row lock, so concurrent
  -- callers queue and re-evaluate the WHERE against the freshly committed
  -- counts. When the limit is already met no row is updated, FOUND is false,
  -- and the caller is refused — there is no window between check and increment.
  insert into public.analysis_usage_daily as u (user_id, usage_date, reserved_count)
  values (p_user_id, p_usage_date, 1)
  on conflict (user_id, usage_date) do update
     set reserved_count = u.reserved_count + 1
   where u.successful_count + u.reserved_count < p_daily_limit
  returning u.successful_count, u.reserved_count
       into v_used, v_reserved;

  if not found then
    -- No slot: undo the attempt so a later retry (after the quota resets) is
    -- not rejected as a duplicate of an analysis that never ran.
    delete from public.analysis_attempts where request_id = p_request_id;

    select coalesce(d.successful_count, 0), coalesce(d.reserved_count, 0)
      into v_used, v_reserved
      from public.analysis_usage_daily d
     where d.user_id = p_user_id and d.usage_date = p_usage_date;

    return query
      select 'limit_reached'::text, coalesce(v_used, 0), coalesce(v_reserved, 0);
    return;
  end if;

  return query select 'reserved'::text, v_used, v_reserved;
end;
$$;

comment on function public.reserve_analysis_slot(uuid, date, uuid, text, integer, integer) is
  'Atomically takes a daily slot. Outcomes: reserved | duplicate | limit_reached.';

-- ── finalize ──────────────────────────────────────────────────────────────

create or replace function public.finalize_analysis_slot(
  p_request_id uuid,
  p_success    boolean,
  p_error_code text default null
)
returns table (
  outcome        text,
  used_today     integer,
  reserved_today integer
)
language plpgsql
as $$
declare
  v_user_id    uuid;
  v_usage_date date;
  v_used       integer;
  v_reserved   integer;
begin
  -- `and status = 'reserved'` makes this idempotent: a duplicate finalize (a
  -- retry, or a timeout racing the real answer) matches nothing and cannot
  -- double-count the quota.
  update public.analysis_attempts
     set status = case when p_success then 'succeeded' else 'failed' end,
         completed_at = now(),
         error_code = case when p_success then null else p_error_code end
   where request_id = p_request_id
     and status = 'reserved'
  returning user_id, usage_date into v_user_id, v_usage_date;

  if not found then
    return query select 'not_reserved'::text, 0, 0;
    return;
  end if;

  -- Release the slot, and count it only if the analysis actually succeeded:
  -- a failed analysis must cost the user nothing.
  update public.analysis_usage_daily
     set reserved_count   = greatest(0, reserved_count - 1),
         successful_count = successful_count
                            + case when p_success then 1 else 0 end
   where user_id = v_user_id
     and usage_date = v_usage_date
  returning successful_count, reserved_count into v_used, v_reserved;

  return query
    select case when p_success then 'succeeded' else 'released' end::text,
           coalesce(v_used, 0),
           coalesce(v_reserved, 0);
end;
$$;

comment on function public.finalize_analysis_slot(uuid, boolean, text) is
  'Converts a reservation to succeeded (counts against quota) or failed (releases it). Idempotent.';

-- ── who may call these ────────────────────────────────────────────────────
-- EXECUTE is granted to PUBLIC by default, which would expose them as PostgREST
-- RPC to any anon caller. Revoke first, then grant only the service role.

revoke execute on function public.expire_stale_reservations(uuid) from public;
revoke execute on function public.reserve_analysis_slot(uuid, date, uuid, text, integer, integer) from public;
revoke execute on function public.finalize_analysis_slot(uuid, boolean, text) from public;

grant execute on function public.expire_stale_reservations(uuid) to service_role;
grant execute on function public.reserve_analysis_slot(uuid, date, uuid, text, integer, integer) to service_role;
grant execute on function public.finalize_analysis_slot(uuid, boolean, text) to service_role;
