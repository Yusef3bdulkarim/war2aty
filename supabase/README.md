# War2aty — Local Supabase Stack

Everything in this folder runs **locally via Docker** during development
(`supabase start`). No hosted project is required to build or test F06.

## Prerequisites

| Tool | Verified with | Check | Install (Windows) |
|---|---|---|---|
| Docker Desktop | 4.83 (WSL2 backend, running) | `docker info` | `winget install Docker.DockerDesktop` — then launch it once |
| Supabase CLI | 2.109.1 | `supabase --version` | see below — no winget package exists |
| Deno | 2.9.4 | `deno --version` | `winget install DenoLand.Deno` |

The Supabase CLI ships as a GitHub release archive; unzip
`supabase_<ver>_windows_amd64.zip` from
<https://github.com/supabase/cli/releases/latest> into
`%LOCALAPPDATA%\Programs\supabase` and add that folder to `PATH`
(`scoop install supabase` also works if you use scoop).

Docker Desktop must be **running** — the CLI shells out to it for every
container. `supabase start` fails immediately if the daemon is down.

## First run

```bash
cp supabase/.env.example supabase/.env   # then fill in GROQ_API_KEY + salt
supabase start
```

`supabase start` prints the local credentials. The ones we use:

| Value | Where it goes |
|---|---|
| `API URL` (`http://127.0.0.1:54321`) | Flutter dev flavor (F06-T14) |
| `anon key` | Flutter dev flavor — publishable, safe in the client |
| `service_role key` | Edge Functions only — **never** the app |
| `DB URL` (`postgresql://postgres:postgres@127.0.0.1:54322/postgres`) | psql / migrations |

### Emulator note

`127.0.0.1` from inside an Android emulator is the emulator itself. The dev
flavor points at **`http://10.0.2.2:54321`**; iOS simulators use `127.0.0.1`
directly.

## Everyday commands

```bash
supabase status                                   # what is running + keys
supabase stop                                     # stop (keeps data)
supabase stop --no-backup                         # stop + wipe local data
supabase db reset                                 # re-apply every migration
supabase functions serve --env-file supabase/.env # hot-reload functions
deno test --allow-env --allow-net supabase/tests  # backend tests
```

## Ports

| Service | Port |
|---|---|
| API gateway | 54321 |
| Postgres | 54322 |
| Studio | 54323 |
| Edge runtime inspector | 8083 |

Change them in [`config.toml`](config.toml) if they clash locally.

## Verifying the stack

```bash
docker info                                       # daemon reachable
supabase status                                   # all services running
curl http://127.0.0.1:54321/functions/v1/health   # {"status":"ok",...} (after F06-T13)

# Anonymous auth issues a JWT (this is the app's only identity):
curl -X POST http://127.0.0.1:54321/auth/v1/signup \
     -H "apikey: <anon key>" -H "Content-Type: application/json" -d '{}'
# → access_token whose claims include "is_anonymous": true
```

Expected containers: `db`, `auth`, `rest`, `kong`, `edge_runtime`, `studio`,
`pg_meta`. `storage`, `realtime`, `analytics`, `pooler` and SMTP are switched
off in `config.toml` and correctly report as stopped.

### Known warnings

`supabase start` logs `failed to read file: ...functions/<name>/index.ts` for
each function declared in `config.toml` that doesn't exist yet. Harmless — the
stack starts anyway, and the warnings disappear as F06-T13 adds the endpoints.

`no files matched pattern: supabase/seed.sql` is also expected: there is no seed
data, only migrations (F06-T02).

## Database

Three tables, all service-role only (F06-T02):

| Table | Purpose |
|---|---|
| `analysis_usage_daily` | per-user daily counters, keyed by an **Africa/Cairo** `usage_date` the function supplies |
| `analysis_attempts` | reservation ledger keyed by `request_id`; makes the quota race-safe and retries idempotent |
| `app_runtime_config` | backend-tunable knobs (daily limit, kill switch, min app version) |

Each has RLS **enabled with zero policies** and client grants revoked, so `anon`
and `authenticated` are denied at both layers. `service_role` gets an explicit
grant — read/write on the two usage tables, **read-only** on the config table.

`analysis_attempts` stores no document content: only `request_id`, `user_id`, a
salted `installation_hash`, status and timing.

Re-check the lockdown after any schema change:

```bash
supabase db reset
# every table must show rls_on = t and a policy count of 0
docker exec -i supabase_db_war2aty psql -U postgres -d postgres -c "\
select tablename, rowsecurity from pg_tables where schemaname='public'; \
select count(*) from pg_policies where schemaname='public';"
```

### Gotcha: `BYPASSRLS` is not a grant

`service_role` has `BYPASSRLS`, which skips RLS *policies* but confers **no
table privileges**. A table that only enables RLS and revokes client grants is
unreachable by the Edge Functions too — `permission denied`. Every table needs
an explicit `grant ... to service_role`.

### Gotcha: `enable_signup`

`[auth] enable_signup` must stay `true`. GoTrue creates **anonymous** users
through the signup path, so setting it to `false` makes anonymous sign-in fail
with `signup_disabled`. Email/SMS signup is closed separately under
`[auth.email]` / `[auth.sms]`, which is what actually keeps registration shut.

## Rules

- **Secrets never leave `supabase/.env`** (git-ignored) or Supabase Project
  Secrets. Not in `config.toml`, not in Flutter, not in dart-defines (§24).
- **No client policies** on `analysis_usage_daily`, `analysis_attempts`,
  `app_runtime_config`. RLS on, service-role access from functions only (§26).
- **No document content in logs** — envelope fields (`session_id`,
  `installation_id`, `request_id`) and status codes only.

## Layout

```
supabase/
├── config.toml          # local stack config (this task)
├── .env.example         # secret template — copy to .env
├── functions/
│   ├── deno.json        # Deno fmt/lint/tasks for the functions workspace
│   ├── _shared/         # auth, http, errors, groq, prompts, usage, validators
│   ├── analyze-document/
│   ├── get-usage/
│   └── health/
├── migrations/          # F06-T02
└── tests/               # unit / integration / fixtures
```
