-- F06-T02 · analysis_attempts
--
-- One row per analysis attempt, keyed by the client-supplied request id. This
-- is what makes the quota race-safe and idempotent: a slot is `reserved` before
-- the AI call and finalised as `succeeded` / `failed` afterwards (F06-T07).
-- A retry carrying the same request_id collides on the primary key instead of
-- burning a second slot.
--
-- PRIVACY: this table holds NO document content — no OCR text, no candidate
-- values, no analysis output. Only the envelope needed to police usage.
-- `installation_hash` is a salted hash, never the raw installation id.

create table if not exists public.analysis_attempts (
  request_id        uuid        primary key,
  user_id           uuid        not null references auth.users (id) on delete cascade,
  -- Salted hash of installation_id (INSTALLATION_HASH_SALT). Lets us spot abuse
  -- across re-installs without ever storing the identifier itself.
  installation_hash text        not null,
  status            text        not null default 'reserved',
  created_at        timestamptz not null default now(),
  -- A reservation past this instant is abandoned (crash, timeout, lost network)
  -- and may be swept back into the pool rather than stranding the user's quota.
  expires_at        timestamptz not null,
  completed_at      timestamptz,
  -- Error code from §31 when status = 'failed'. Never a raw provider message,
  -- and never anything derived from the document.
  error_code        text,

  constraint analysis_attempts_status_valid
    check (status in ('reserved', 'succeeded', 'failed', 'expired')),
  -- Terminal states carry a completion time; reservations do not.
  constraint analysis_attempts_completed_at_matches_status
    check (
      (status = 'reserved' and completed_at is null)
      or (status <> 'reserved' and completed_at is not null)
    ),
  -- Only failures carry an error code.
  constraint analysis_attempts_error_code_only_on_failure
    check (error_code is null or status = 'failed')
);

comment on table public.analysis_attempts is
  'Per-attempt reservation ledger for the daily quota. Contains no document content — envelope fields only.';
comment on column public.analysis_attempts.request_id is
  'Client-supplied idempotency key; a retry with the same id cannot consume a second slot.';
comment on column public.analysis_attempts.installation_hash is
  'Salted hash of installation_id — the raw value is never stored.';
comment on column public.analysis_attempts.expires_at is
  'Reservations still open past this instant are abandoned and may be swept to expired.';

-- Sweeping abandoned reservations: "reserved rows whose expires_at has passed".
create index if not exists analysis_attempts_reserved_expiry_idx
  on public.analysis_attempts (expires_at)
  where status = 'reserved';

-- Counting a user's attempts for a given day.
create index if not exists analysis_attempts_user_created_idx
  on public.analysis_attempts (user_id, created_at desc);

-- RLS on, NO policies — service role only (§26). See analysis_usage_daily for
-- the full rationale. The app must never read another install's attempts.
alter table public.analysis_attempts enable row level security;
alter table public.analysis_attempts force row level security;

revoke all on public.analysis_attempts from anon, authenticated;

-- Explicit grant for the service role — BYPASSRLS does not confer table
-- privileges. DELETE is included so the expiry sweep can prune old attempts.
grant select, insert, update, delete on public.analysis_attempts to service_role;
