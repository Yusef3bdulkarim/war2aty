-- F13-T02 · Global daily call-count circuit breaker.
--
-- The per-user daily_limit (F06-T07) caps what one installation can spend, but
-- an anonymous-auth app with no login screen makes multi-install abuse cheap:
-- nothing stops a burst of fresh installs from each taking their free 3/day
-- once Azure/Google Document AI calls cost real money per analysis (unlike the
-- free on-device Tesseract this quota was originally sized around). This adds a
-- SECOND, independent cap on total calls across all users per Cairo day.
--
-- Deliberately the opposite fail-direction from daily_limit: an unset or
-- non-positive global_daily_call_cap means UNLIMITED, not zero. daily_limit
-- fails closed because it is a mandatory, always-on product decision; this cap
-- is a new, optional safety valve being dark-launched (F13-T03) — before an
-- operator explicitly sets a real number, it must not silently block every
-- request in production.
--
-- Folded into the SAME atomic reserve/finalize functions used for the
-- per-user quota, not a separate pre-check: this codebase already rejected a
-- read-then-reserve shape for exactly this quota (see F06-T07's comment on
-- reserve_analysis_slot) because it cannot be made race-safe. A standalone
-- global check ahead of the per-user one would reintroduce that same race.

-- ── which attempts were also counted globally ────────────────────────────
-- Finalize must know, per attempt, whether reserve touched the global counter
-- (a cap only just got configured) — otherwise finalize could decrement a
-- global row that reserve never incremented for this request. Mirrors why
-- `usage_date` was added to this table in F06-T07.

alter table public.analysis_attempts
  add column if not exists counted_globally boolean not null default false;

comment on column public.analysis_attempts.counted_globally is
  'Whether reserve_analysis_slot also incremented global_analysis_usage_daily for this attempt. Finalize must only touch the global counter when this is true.';

-- ── global_analysis_usage_daily ───────────────────────────────────────────

create table if not exists public.global_analysis_usage_daily (
  usage_date       date        primary key,
  successful_count integer     not null default 0,
  reserved_count   integer     not null default 0,
  updated_at       timestamptz not null default now(),

  constraint global_analysis_usage_daily_successful_count_non_negative
    check (successful_count >= 0),
  constraint global_analysis_usage_daily_reserved_count_non_negative
    check (reserved_count >= 0)
);

comment on table public.global_analysis_usage_daily is
  'Cross-user daily AI-provider call counters (F13-T02): caps total Azure/Google/Groq spend exposure across all anonymous installs, independent of the per-user analysis_usage_daily. Service-role access only.';
comment on column public.global_analysis_usage_daily.usage_date is
  'Africa/Cairo calendar day, computed by the Edge Function — never by the database, same as analysis_usage_daily.usage_date.';

create trigger global_analysis_usage_daily_set_updated_at
  before update on public.global_analysis_usage_daily
  for each row execute function public.set_updated_at();

-- Same lockdown shape as analysis_usage_daily: RLS on, zero policies, service
-- role only. Do not add a client policy — that would let the app read/tamper
-- with a counter it must never see.
alter table public.global_analysis_usage_daily enable row level security;
alter table public.global_analysis_usage_daily force row level security;

revoke all on public.global_analysis_usage_daily from anon, authenticated;
grant select, insert, update on public.global_analysis_usage_daily to service_role;

-- ── expire: also release any global slots the expired attempts held ──────

create or replace function public.expire_stale_reservations(
  p_user_id uuid default null
)
returns integer
language plpgsql
as $$
declare
  v_released integer;
begin
  -- One statement so the attempt flip and both counter releases (per-user and,
  -- when applicable, global) cannot diverge.
  with expired as (
    update public.analysis_attempts
       set status = 'expired',
           completed_at = now()
     where status = 'reserved'
       and expires_at <= now()
       and (p_user_id is null or user_id = p_user_id)
    returning user_id, usage_date, counted_globally
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
  ),
  global_grouped as (
    select usage_date, count(*)::integer as released
      from expired
     where counted_globally
     group by usage_date
  ),
  global_applied as (
    update public.global_analysis_usage_daily gu
       set reserved_count = greatest(0, gu.reserved_count - gg.released)
      from global_grouped gg
     where gu.usage_date = gg.usage_date
    returning gg.released
  )
  -- global_applied is referenced here (not left dangling) so its UPDATE is
  -- guaranteed to run; the outer WHERE keeps it out of the per-user total this
  -- function has always returned.
  select coalesce(sum(x.released), 0)::integer
    into v_released
    from (
      select released, 'user'::text as scope from applied
      union all
      select released, 'global'::text as scope from global_applied
    ) x
   where x.scope = 'user';

  return v_released;
end;
$$;

comment on function public.expire_stale_reservations(uuid) is
  'Reclaims slots (per-user and, when applicable, global) whose expires_at has passed.';

-- ── reserve: add the global cap check ─────────────────────────────────────
-- The old 6-arg signature must be dropped, not just replaced: CREATE OR
-- REPLACE with an added parameter creates a second overload rather than
-- updating the existing one, and a caller that still resolves to the old
-- overload would silently skip the global check entirely.

drop function if exists public.reserve_analysis_slot(uuid, date, uuid, text, integer, integer);

create or replace function public.reserve_analysis_slot(
  p_user_id           uuid,
  p_usage_date        date,
  p_request_id        uuid,
  p_installation_hash text,
  p_daily_limit       integer,
  p_ttl_seconds       integer,
  p_global_daily_cap  integer default null
)
returns table (
  outcome        text,
  used_today     integer,
  reserved_today integer
)
language plpgsql
as $$
declare
  v_used             integer;
  v_reserved         integer;
  v_global_used      integer;
  v_global_reserved  integer;
  v_counted_globally boolean := false;
begin
  -- Fail closed: a missing or nonsensical PER-USER limit must never mean
  -- "unlimited". (The global cap below is the opposite by design — see the
  -- migration header.)
  if p_daily_limit is null or p_daily_limit < 1 then
    select coalesce(d.successful_count, 0), coalesce(d.reserved_count, 0)
      into v_used, v_reserved
      from public.analysis_usage_daily d
     where d.user_id = p_user_id and d.usage_date = p_usage_date;

    return query
      select 'limit_reached'::text, coalesce(v_used, 0), coalesce(v_reserved, 0);
    return;
  end if;

  -- Self-healing: reclaim abandoned slots before judging this request.
  --
  -- The sweep widens to ALL users when the breaker is on, and this is load-
  -- bearing. A stranded per-user slot only ever costs the user who stranded it,
  -- and their own next call reclaims it — so a per-user sweep is sufficient
  -- there. A stranded GLOBAL slot is held against everyone, and nothing else in
  -- the system ever sweeps it: a burst of crashed requests from installs that
  -- never return would ratchet the day's reserved_count up permanently and keep
  -- the breaker tripped until Cairo midnight. That would turn the mechanism
  -- meant to prevent an outage into one.
  --
  -- Cheap regardless of scope: the partial index on (expires_at) where
  -- status = 'reserved' matches this predicate exactly, and it is a narrower
  -- scan without the user_id filter than with it.
  if p_global_daily_cap is not null and p_global_daily_cap > 0 then
    perform public.expire_stale_reservations();
  else
    perform public.expire_stale_reservations(p_user_id);
  end if;

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

  -- The per-user atomic gate. ON CONFLICT DO UPDATE takes a row lock, so
  -- concurrent callers queue and re-evaluate the WHERE against the freshly
  -- committed counts.
  insert into public.analysis_usage_daily as u (user_id, usage_date, reserved_count)
  values (p_user_id, p_usage_date, 1)
  on conflict (user_id, usage_date) do update
     set reserved_count = u.reserved_count + 1
   where u.successful_count + u.reserved_count < p_daily_limit
  returning u.successful_count, u.reserved_count
       into v_used, v_reserved;

  if not found then
    -- No slot: undo the attempt so a later retry is not rejected as a
    -- duplicate of an analysis that never ran.
    delete from public.analysis_attempts where request_id = p_request_id;

    select coalesce(d.successful_count, 0), coalesce(d.reserved_count, 0)
      into v_used, v_reserved
      from public.analysis_usage_daily d
     where d.user_id = p_user_id and d.usage_date = p_usage_date;

    return query
      select 'limit_reached'::text, coalesce(v_used, 0), coalesce(v_reserved, 0);
    return;
  end if;

  -- The global cap is optional and dark by default (F13-T03): a null or
  -- non-positive value means the breaker is off, and no global row is ever
  -- touched or created — today's Groq-only pipeline is unaffected until an
  -- operator explicitly configures a cap.
  if p_global_daily_cap is not null and p_global_daily_cap > 0 then
    insert into public.global_analysis_usage_daily as gu (usage_date, reserved_count)
    values (p_usage_date, 1)
    on conflict (usage_date) do update
       set reserved_count = gu.reserved_count + 1
     where gu.successful_count + gu.reserved_count < p_global_daily_cap
    returning gu.successful_count, gu.reserved_count
         into v_global_used, v_global_reserved;

    if not found then
      -- The global breaker tripped: undo the per-user slot and the attempt
      -- row just taken, so this call leaves no trace of a reservation that
      -- never ran — the same rollback shape as the per-user limit_reached
      -- branch above.
      update public.analysis_usage_daily
         set reserved_count = greatest(0, reserved_count - 1)
       where user_id = p_user_id
         and usage_date = p_usage_date;

      delete from public.analysis_attempts where request_id = p_request_id;

      return query select 'global_capacity_reached'::text, v_used, v_reserved;
      return;
    end if;

    v_counted_globally := true;
  end if;

  if v_counted_globally then
    update public.analysis_attempts
       set counted_globally = true
     where request_id = p_request_id;
  end if;

  return query select 'reserved'::text, v_used, v_reserved;
end;
$$;

comment on function public.reserve_analysis_slot(uuid, date, uuid, text, integer, integer, integer) is
  'Atomically takes a daily slot, and — when a global cap is configured — a global one too. Outcomes: reserved | duplicate | limit_reached | global_capacity_reached.';

-- ── finalize: release the global slot too, only when reserve took one ────

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
  v_user_id          uuid;
  v_usage_date       date;
  v_counted_globally boolean;
  v_used             integer;
  v_reserved         integer;
begin
  -- `and status = 'reserved'` makes this idempotent: a duplicate finalize (a
  -- retry, or a timeout racing the real answer) matches nothing and cannot
  -- double-count either counter.
  update public.analysis_attempts
     set status = case when p_success then 'succeeded' else 'failed' end,
         completed_at = now(),
         error_code = case when p_success then null else p_error_code end
   where request_id = p_request_id
     and status = 'reserved'
  returning user_id, usage_date, counted_globally
       into v_user_id, v_usage_date, v_counted_globally;

  if not found then
    return query select 'not_reserved'::text, 0, 0;
    return;
  end if;

  -- Release the per-user slot, and count it only if the analysis succeeded.
  update public.analysis_usage_daily
     set reserved_count   = greatest(0, reserved_count - 1),
         successful_count = successful_count
                            + case when p_success then 1 else 0 end
   where user_id = v_user_id
     and usage_date = v_usage_date
  returning successful_count, reserved_count into v_used, v_reserved;

  -- Mirror the release on the global counter, but only for attempts reserve
  -- actually counted globally — an attempt reserved before a cap existed must
  -- not decrement a row it never incremented.
  if v_counted_globally then
    update public.global_analysis_usage_daily
       set reserved_count   = greatest(0, reserved_count - 1),
           successful_count = successful_count
                              + case when p_success then 1 else 0 end
     where usage_date = v_usage_date;
  end if;

  return query
    select case when p_success then 'succeeded' else 'released' end::text,
           coalesce(v_used, 0),
           coalesce(v_reserved, 0);
end;
$$;

comment on function public.finalize_analysis_slot(uuid, boolean, text) is
  'Converts a reservation to succeeded (counts against quota) or failed (releases it), including the global counter when reserve took a global slot too. Idempotent.';

-- ── who may call these ────────────────────────────────────────────────────

revoke execute on function public.expire_stale_reservations(uuid) from public;
revoke execute on function public.reserve_analysis_slot(uuid, date, uuid, text, integer, integer, integer) from public;
revoke execute on function public.finalize_analysis_slot(uuid, boolean, text) from public;

grant execute on function public.expire_stale_reservations(uuid) to service_role;
grant execute on function public.reserve_analysis_slot(uuid, date, uuid, text, integer, integer, integer) to service_role;
grant execute on function public.finalize_analysis_slot(uuid, boolean, text) to service_role;
