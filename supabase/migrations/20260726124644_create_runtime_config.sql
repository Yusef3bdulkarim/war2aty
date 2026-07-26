-- F06-T02 · app_runtime_config
--
-- Backend-tunable knobs, read by the Edge Functions at request time (F06-T08)
-- so the daily limit can change, analysis can be paused, or an old client can
-- be blocked without shipping a new app build. Mirrors `RuntimeConfig.defaults`
-- on the Flutter side (lib/core/config/runtime_config.dart) — the app keeps its
-- own conservative fallbacks for when the backend is unreachable.
--
-- Secrets never live here: this table is operational config only. Keys and
-- salts stay in Supabase Project Secrets (§24).

create table if not exists public.app_runtime_config (
  key        text        primary key,
  value      jsonb       not null,
  updated_at timestamptz not null default now()
);

comment on table public.app_runtime_config is
  'Backend-tunable runtime config read by Edge Functions. Operational values only — never secrets.';
comment on column public.app_runtime_config.value is
  'JSONB so each key keeps its natural type (number, boolean, string, null).';

create trigger app_runtime_config_set_updated_at
  before update on public.app_runtime_config
  for each row execute function public.set_updated_at();

-- Seed the documented keys (§25) with the same values the app falls back to.
-- ON CONFLICT DO NOTHING keeps this migration safe to re-run and stops a reset
-- from stomping values an operator has since tuned in production.
insert into public.app_runtime_config (key, value) values
  -- Locked product decision: 3 successful analyses per Africa/Cairo day.
  ('daily_limit',         '3'::jsonb),
  -- Kill switch. false → analyze-document returns 503 ANALYSIS_DISABLED.
  ('analysis_enabled',    'true'::jsonb),
  -- Upper bound on ocr_text length; requests above it are rejected 400.
  ('max_ocr_characters',  '12000'::jsonb),
  -- Clients below this are rejected with 400 UNSUPPORTED_APP_VERSION.
  ('minimum_app_version', '"1.0.0"'::jsonb),
  -- Analysis contract version the server speaks.
  ('schema_version',      '"1.0"'::jsonb),
  -- Shown to the user during maintenance; null means normal operation.
  ('maintenance_message', 'null'::jsonb)
on conflict (key) do nothing;

-- RLS on, NO policies — service role only (§26). The app receives these values
-- through get-usage / analyze-document responses, never by querying the table.
alter table public.app_runtime_config enable row level security;
alter table public.app_runtime_config force row level security;

revoke all on public.app_runtime_config from anon, authenticated;

-- Read-only for the service role: functions consume config, they never author
-- it. Operators change values through Studio/psql as `postgres`, which keeps an
-- accidental write from an Edge Function impossible.
grant select on public.app_runtime_config to service_role;
