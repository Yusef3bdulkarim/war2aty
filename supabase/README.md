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
supabase functions serve --env-file supabase/.env   # required — see below
```

### Gotcha: `supabase start` does not give the functions your secrets

`supabase start` injects only the platform variables into `edge_runtime`
(`SUPABASE_URL`, the two keys, `SUPABASE_DB_URL`). It does **not** read
`supabase/.env`, so `GROQ_API_KEY` and `INSTALLATION_HASH_SALT` are absent and
`analyze-document` fails at startup with a bare `500` and no body:

```
event loop error: Error: INSTALLATION_HASH_SALT must be set to at least 32 characters.
```

That failure is deliberate (see `installation-hash.ts`), but the fix is not the
code — it is to serve the functions yourself:

```bash
supabase functions serve --env-file supabase/.env
```

`health` and `get-usage` work either way, because neither needs a secret. Only
`analyze-document` does, which is exactly why the symptom looks like a broken
endpoint rather than a missing env file. Verify with:

```bash
docker inspect supabase_edge_runtime_war2aty \
  --format '{{range .Config.Env}}{{println .}}{{end}}' | cut -d= -f1
```

### Gotcha: `.env` must not have a UTF-8 BOM

An editor that saves `supabase/.env` as "UTF-8 with BOM" makes every CLI command
fail before it starts:

```
failed to parse environment file: .env (unexpected character '»' in variable name)
```

Save it as plain UTF-8. On Windows, PowerShell's `>` and `Out-File` add a BOM by
default — use `Set-Content -Encoding utf8NoBOM`, or an editor.

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
directly. `AppEnvironment.dev()` picks between them (F06-T14) — nothing to
configure by hand.

## Running the app against this stack (F06-T14)

```bash
supabase start
supabase functions serve --env-file supabase/.env
flutter run --flavor dev -t lib/main_dev.dart
```

The dev flavor needs no dart-defines: it resolves the local URL and the
well-known local anon key itself. Two overrides exist:

```bash
# A physical device on the same LAN as the dev machine:
--dart-define=SUPABASE_URL=http://192.168.1.5:54321

# UI work with no Docker and no Groq key — serves the bundled fixtures:
--dart-define=USE_MOCK_ANALYSIS=true
```

`prod` has no hosted project yet, so it takes `SUPABASE_URL` and
`SUPABASE_ANON_KEY` from the build. Without them it launches, reports itself
unconfigured, and refuses analyses with the normal maintenance copy rather than
pointing at a placeholder host.

### The one gateway behaviour worth knowing

Supabase enforces `verify_jwt` at the **gateway**, before the Edge Function
runs, so a 401 for an expired token carries GoTrue's body — not a §31 envelope.
`failureFromErrorBody` therefore takes the HTTP status as a fallback; without it
an expired session showed the generic «الخدمة غير متاحة» instead of the session
error. The app also refreshes and replays once on any 401, so the user normally
never sees it.

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

The endpoint tests need `functions serve` running as well — see the gotcha
above, or `analyze-document` answers 500 for everything.

**No test calls Groq by default.** One integration test performs a real
analysis and is gated behind an explicit opt-in, because a live call is billed,
non-deterministic and reserved against the 8000-token minute:

```bash
RUN_LIVE_ANALYSIS=1 SUPABASE_URL=... SUPABASE_ANON_KEY=... \
  deno test --allow-net --allow-env --filter live supabase/tests
```

It asserts shape only — field presence, enums, the quota moving by one. The
model's wording is not a contract and must never be asserted.

## The three endpoints

| Endpoint | Method | Auth | Contract |
|---|---|---|---|
| `analyze-document` | POST | anon JWT | request §29, response §30, errors §31 |
| `get-usage` | GET | anon JWT | §32 |
| `health` | GET | none | §32 |

Everything an endpoint does regardless of what it does — preflight, method
check, correlation id, error serialisation, one access-log line — is in
[`endpoint.ts`](functions/_shared/http/endpoint.ts). `Deno.serve` appears only
in the three `index.ts` files, which hold wiring and nothing else; the sequence
lives in `analyze-handler.ts` / `usage-handler.ts` so it can be tested with
fakes, offline.

### Why the response is rebuilt, not forwarded

`analyze-response.ts` is not defensive decoration. Groq's schema subset cannot
express `format: date`, `minLength` or the `HH:mm` pattern, and the Flutter
mapper **throws** on a date it cannot parse or a role it does not know — for the
*whole* body. So one date the model wrote as "next Tuesday" would destroy an
otherwise perfect analysis on someone's phone. That date is dropped instead,
named in `missing_fields`, and the status falls to `partial` so the review
banner shows.

### Order of checks in analyze-document

Each step is cheaper than the next, and each refuses a request that must never
reach the one after it:

```
auth → runtime config → kill switch → parse body → reserve slot → AI → validate
```

There is deliberately no daily-limit pre-check before the reservation: the
reserve is atomic and already answers `limit_reached`, so a read-then-reserve
would add a round-trip and a race it cannot win.

A `duplicate` reservation answers `ANALYSIS_FAILED`. §31 has no duplicate code,
results are not stored server-side, and the client maps it to a retryable
failure — which is the honest advice. A client sending a fresh `x-request-id`
per attempt (F06-T14) never reaches that branch.

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
curl http://127.0.0.1:54321/functions/v1/health   # {"status":"ok","time":"..."}

# Anonymous auth issues a JWT (this is the app's only identity):
curl -X POST http://127.0.0.1:54321/auth/v1/signup \
     -H "apikey: <anon key>" -H "Content-Type: application/json" -d '{}'
# → access_token whose claims include "is_anonymous": true

# Today's quota for that token:
curl http://127.0.0.1:54321/functions/v1/get-usage \
     -H "Authorization: Bearer <access_token>" -H "apikey: <anon key>"
```

Expected containers: `db`, `auth`, `rest`, `kong`, `edge_runtime`, `studio`,
`pg_meta`. `storage`, `realtime`, `analytics`, `pooler` and SMTP are switched
off in `config.toml` and correctly report as stopped.

### Known warnings

`no files matched pattern: supabase/seed.sql` is expected: there is no seed
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

## Groq model — must support `json_schema`

`GROQ_MODEL` is **not** free choice. Structured output (F06-T11) requires
`response_format: json_schema`, and most models answer HTTP 400 for it.
Verified against this account on 2026-07-26:

| Model | `json_schema` |
|---|---|
| `openai/gpt-oss-120b` (in use) | ✅ |
| `openai/gpt-oss-20b` | ✅ |
| `llama-3.3-70b-versatile` | ❌ 400 |
| `qwen/qwen3.6-27b`, `llama-3.1-8b-instant`, `allam-2-7b` | ❌ 400 |

Without it the model returns JSON that merely *parses*: an observed reply used
`"status": "complete"` and flat fields, none of §30. Re-check with
`GET /openai/v1/models` before changing the model.

### Rate limits shape the token budget

The tier allows **8000 tokens/minute** (`x-ratelimit-limit-tokens`), and
`max_tokens` is **reserved** against it rather than merely capping output. At
`max_tokens: 4000` a single analysis claimed over half the minute and three
back-to-back calls were rate-limited. It is now 2000 — about 4x the 468 tokens
a real electricity bill produced. Raising it directly reduces how many users
can be served per minute.

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
