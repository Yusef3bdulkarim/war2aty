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
deno fmt supabase/functions supabase/tests        # format
deno lint supabase/functions supabase/tests       # lint
```

### Tests

Unit tests use injected fakes, so they need no stack and always run. The
integration tests under `tests/integration/` talk to a live local stack and
**skip themselves** when `SUPABASE_URL` / `SUPABASE_ANON_KEY` are absent or the
stack is down — a bare `deno test` stays green either way. To actually run them
(the values come from `supabase status`):

```bash
SUPABASE_URL=http://127.0.0.1:54321 \
SUPABASE_ANON_KEY=<anon key> \
SUPABASE_SERVICE_ROLE_KEY=<service_role key> \
  deno test --allow-net --allow-env supabase/tests
```

The service-role key is required because the usage tables are unreachable
without it. All three values come from `supabase status`; none is committed.

## Quota lifecycle

`reserve → (succeeded | failed | expired)`, enforced in SQL by
[`create_usage_functions.sql`](migrations/20260726132921_create_usage_functions.sql).

The check and the increment happen in **one locked statement**. A read-then-write
in TypeScript cannot be made safe: three taps arriving together would each read
`successful_count = 0`, each decide there is room, and each proceed.

| Rule | Where it is enforced |
|---|---|
| At most `daily_limit` slots per user per Cairo day | `ON CONFLICT DO UPDATE … WHERE` takes a row lock |
| A retry of the same `request_id` takes no second slot | `analysis_attempts` primary key |
| A failed analysis costs the user nothing | `finalize(success = false)` releases |
| A crashed request does not strand a slot | `expire_stale_reservations`, run before each reserve |
| A double finalize cannot double-count | `… AND status = 'reserved'` |
| An `unsupported` document is not counted | `countsAsSuccess` in `withReservedSlot` |

`analysis_attempts.usage_date` exists so finalize releases the day the slot was
**taken on**. Without it, an analysis reserved at 23:59:58 and finished at
00:00:05 would release a slot on the new day and strand yesterday's.

Prefer `withReservedSlot()` over calling reserve/finalize directly — it settles
the slot on every path, including a throw.

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

## Error contract — §31 wins over §48

The two specs disagree, and **API_CONTRACT §31 is authoritative**:

| | master plan §48 | API_CONTRACT §31 (used) |
|---|---|---|
| envelope | `{ success, requestId, error{…, retryable} }` | `{ error: { code, message, details? } }` |
| names | `AI_TIMEOUT`, `INTERNAL_SERVER_ERROR`, … | `TIMEOUT`, `INTERNAL_ERROR`, … |

Why: §31 is the later artifact, ships a draft-07 JSON Schema, and the Flutter
client is **already built against it** — `analysis_error_mapper.dart` switches
on those exact strings, so §48's names would degrade every error to a generic
failure on the device. §31 also sets `additionalProperties: false`, which
forbids §48's `success` / `requestId` / `retryable` outright.

No §48 concept is lost; the full mapping is documented at the top of
[`functions/_shared/errors/error-codes.ts`](functions/_shared/errors/error-codes.ts).
Note `UNSUPPORTED_DOCUMENT` is **not** an error — it is a 200 with
`status: "unsupported"` (§31 rule 6) and is not counted against the quota.

Error codes are a machine contract: renaming one breaks shipped clients.

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
