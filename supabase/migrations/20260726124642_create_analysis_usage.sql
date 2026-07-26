-- F06-T02 · analysis_usage_daily
--
-- One row per (user, Cairo day) holding the daily analysis counters.
-- The Cairo day boundary is computed by the Edge Function (F06-T06) and passed
-- in as `usage_date`; Postgres never derives the date itself, so a server
-- timezone change can never silently shift the quota window.
--
-- Reached exclusively through the service role inside Edge Functions. RLS is on
-- with NO policies, so anon/authenticated JWTs can read nothing here (§26) —
-- the app cannot inspect or edit its own counter.

-- Shared helper: keeps `updated_at` honest without every writer remembering to.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

comment on function public.set_updated_at() is
  'Trigger helper: stamps updated_at = now() on every UPDATE.';

create table if not exists public.analysis_usage_daily (
  user_id          uuid        not null references auth.users (id) on delete cascade,
  usage_date       date        not null,
  -- Analyses that completed successfully — this is what the quota counts.
  successful_count integer     not null default 0,
  -- Slots currently reserved but not yet finalised (F06-T07). Counted against
  -- the quota while in flight so parallel requests cannot overshoot the limit.
  reserved_count   integer     not null default 0,
  updated_at       timestamptz not null default now(),

  primary key (user_id, usage_date),

  constraint analysis_usage_daily_successful_count_non_negative
    check (successful_count >= 0),
  constraint analysis_usage_daily_reserved_count_non_negative
    check (reserved_count >= 0)
);

comment on table public.analysis_usage_daily is
  'Per-user daily analysis counters. Service-role access only; the day is an Africa/Cairo day supplied by the Edge Function.';
comment on column public.analysis_usage_daily.usage_date is
  'Africa/Cairo calendar day, computed by the Edge Function — never by the database.';
comment on column public.analysis_usage_daily.reserved_count is
  'In-flight reservations; released on failure, converted to successful_count on success.';

create trigger analysis_usage_daily_set_updated_at
  before update on public.analysis_usage_daily
  for each row execute function public.set_updated_at();

-- Lock the table down: RLS on, and deliberately NO policies. With RLS enabled
-- and zero policies every non-superuser role is denied; the service role used
-- by the Edge Functions bypasses RLS. Adding a client policy here would let the
-- app tamper with its own quota — do not add one.
alter table public.analysis_usage_daily enable row level security;
alter table public.analysis_usage_daily force row level security;

-- Defence in depth: strip the grants Supabase hands to client roles by default,
-- so the table is unreachable even if RLS were ever switched off by mistake.
revoke all on public.analysis_usage_daily from anon, authenticated;

-- The service role needs an explicit grant. BYPASSRLS only skips RLS policies,
-- it does not imply table privileges — without this the Edge Functions get
-- "permission denied" even though they bypass RLS. No DELETE: counters are
-- never removed, only incremented and decremented.
grant select, insert, update on public.analysis_usage_daily to service_role;
