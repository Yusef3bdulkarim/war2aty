# Operations

How to run War2aty's backend day to day: the switches you can throw, the quotas
you have to watch, the pause that can take the service down on its own, and what
to do when something breaks.

Written for whoever is on the hook when the app stops working. It assumes the
Supabase dashboard and nothing else — no local checkout, no CLI.

Produced by F27-T09. Companion documents: `docs/RELEASE.md` for shipping
(F27-T25), `supabase/README.md` for the backend's internals.

---

## 0. The two projects

| | Production | Staging |
|---|---|---|
| Project ref | `ivbpmzasxpphclundjyy` | `jecujrsvbmashkpobtsz` |
| Region | `eu-central-1` (Frankfurt) | `ap-northeast-2` (Seoul) |
| What points at it | the released app | nothing, by default |

**Check the project name before you touch anything.** Staging is still called
`war2aty` while production is `war2aty-prod`; picking the wrong one from the
dashboard's project list has already cost one wasted round trip. Production is
the Frankfurt one.

Both run identical schema and identical function code. They do **not** share a
database, users, quotas or counters.

---

## 1. The kill switches

Everything in this section lives in one table, `public.app_runtime_config`, and
**takes effect on the very next request**. There is no cache to wait out and
nothing to redeploy: every function reads this table fresh on each call.

### What each switch does

| Key | Set it to | Effect | If the value is missing or broken |
|---|---|---|---|
| `analysis_enabled` | `false` | **The master switch.** `analyze-document` *and* `ocr-document` both answer `503 ANALYSIS_DISABLED`, and the app explains that the service is off rather than failing oddly | falls back to **on** |
| `global_daily_call_cap` | a number | Total analyses allowed per Cairo day across all users. Over it, callers get `GLOBAL_CAPACITY_REACHED` | **fails OPEN — unlimited.** A typo here silently removes the cap |
| `online_ocr_enabled` | `true` / `false` | Whether photos may be read online. `false` sends every capture down the on-device route, and any `ocr-document` call that still arrives gets `OCR_UNAVAILABLE` | **off** (opt-in by design) |
| `daily_limit` | a number | Analyses per user per Cairo day | **fails CLOSED** — a broken value stops that user, it does not free them |
| `minimum_app_version` | a version | Clients below it get `400 UNSUPPORTED_APP_VERSION` | — |
| `max_ocr_characters` | a number | Upper bound on OCR text accepted for analysis | — |
| `max_image_bytes` | a number | Upper bound on a decoded image payload | — |
| `schema_version` | — | The request contract the server speaks. **Do not change this by hand**; it moves with an app release | — |

The two opposite fail directions are deliberate. `daily_limit` is a product
rule, so an unreadable value must not hand out free analyses.
`global_daily_call_cap` is a safety valve, so an unreadable value must not lock
every user out of a working service. The price of that choice is that **the cap
is the one switch whose failure is invisible** — see §4.6.

### `maintenance_message` does nothing — do not rely on it

The table has a `maintenance_message` row. **It is not wired up.** `get-usage`
does not return it, and while the app parses it into a model, nothing displays
it. Setting it posts no notice to anybody.

To take the service down with an explanation the user actually sees, use
`analysis_enabled = false`.

### Throwing a switch

Dashboard → **SQL Editor** → run, then confirm:

```sql
-- turn the service off
update public.app_runtime_config set value = 'false'::jsonb
 where key = 'analysis_enabled';

-- raise the day's ceiling to 800
update public.app_runtime_config set value = '800'::jsonb
 where key = 'global_daily_call_cap';

-- read everything back, most recent change first
select key, value, updated_at
  from public.app_runtime_config
 order by updated_at desc;
```

Values are JSONB, so quote and cast: `'false'::jsonb`, `'800'::jsonb`, and
`'"1.0.1"'::jsonb` for a string. Afterwards make one real request from the app
and confirm the behaviour changed — the table saying the right thing is not the
same as the service doing it.

---

## 2. Watching the quotas

Every analysis spends one call on an analysis provider and — only when
`online_ocr_enabled` is on — one on the reader. All users share one set of keys,
so these are service-wide budgets, not per-user ones. **No upstream service is
ever paid for**, which makes these ceilings hard.

### Look at our own counter first

It is free, instant, and the only one denominated in Cairo days:

```sql
-- the day's analyses: reserved = in flight, successful = finished and counted
select usage_date, successful_count, reserved_count
  from public.global_analysis_usage_daily
 order by usage_date desc limit 14;

-- what has been failing, and why, over the last day
select error_code, count(*)
  from public.analysis_attempts
 where created_at > now() - interval '1 day'
   and status = 'failed'
 group by error_code
 order by 2 desc;
```

A day climbing toward `global_daily_call_cap` is the most useful early warning
you have. A `reserved_count` that grows without becoming `successful_count`
means requests are starting and not finishing.

### The upstream ceilings

Limits as published on **2026-10-06**. They move — re-check before relying on a
number, and never raise our cap on the strength of this table alone.

| Provider | Role | Free ceiling | Where to look |
|---|---|---|---|
| **Mistral** `ministral-14b` | analysis, first choice | ~1B tokens/month | Admin Console → Usage, and → Limits |
| **Groq** `openai/gpt-oss-120b` | analysis, fallback | 1,000 req/day **but 200,000 tokens/day** | console.groq.com → Usage |
| **Gemini** 3.5 Flash-Lite | reading photos | **500 req/day**, 15 req/min | AI Studio → API keys / usage |
| **Supabase** | everything | 500,000 function calls/month, 500 MB database | Dashboard → Reports → Usage |

Three things that table does not say out loud:

- **Groq cannot carry the service.** Its 1,000 requests/day looks generous and is
  a decoy: at roughly 3,000 tokens an analysis, the 200,000 token/day ceiling
  binds about fifteen times sooner, around **66 analyses**. It is a cushion for a
  Mistral wobble, not a second engine. If Mistral is out for a day, expect the
  service to stop around 66 analyses however the cap is set.
- **Gemini has no headroom.** Its 500/day is exactly the launch target, and its
  15/minute throttles a burst even on a quiet day. Only relevant while
  `online_ocr_enabled` is on.
- **Nothing counts OCR calls.** `ocr-document` takes no quota slot, by design, so
  `global_daily_call_cap` does not protect Gemini at all. See §4.6.

### Database size

```sql
select pg_size_pretty(pg_database_size(current_database()));
```

11 MB as of 2026-10-06 against a 500 MB ceiling. Our own tables are a rounding
error; the growth comes from `auth` — one row per install plus its sessions and
refresh tokens. The nightly purges (§3) are what hold that down.

**One thing the purges do not reach:** `auth.refresh_tokens` for a user who keeps
coming back. Rotation writes a row per refresh, and the idle-user purge never
touches an active user.

```sql
select count(*) from auth.refresh_tokens;
```

If that climbs out of proportion to your user count, a revoked-token sweep is
cheap to add.

---

## 3. The inactivity pause, and why it is dangerous here

A free Supabase project **pauses after about 7 days of insufficient activity.**
API requests, database queries and function invocations all count. **Browsing
the dashboard does not.**

Why this is worse than it sounds: **pg_cron runs inside the database, so a
paused project stops the retention jobs — and they do not come back on their own
when you unpause.** A project that paused and was restored is a project whose
nightly purges are silently dead until someone re-applies them.

Once the app is live, production's own traffic keeps it awake. The exposure is
**before launch, and staging always** — staging has no users at all.

```sql
-- any real traffic in the last week?
select max(created_at) from public.analysis_attempts;

-- are the jobs still there and running?
select jobname, schedule, active from cron.job where jobname like 'purge-%';
```

Both jobs should read `active = true`: `purge-old-analysis-attempts` at
`30 1 * * *` and `purge-idle-anonymous-users` at `0 2 * * *`. Those are UTC, so
03:30 and 04:00 in Cairo, an hour later in summer.

### Keeping a project awake for nothing

One request a day is enough, and `health` needs no credentials. GitHub Actions
is free on this public repository, so this costs nothing:

```yaml
# .github/workflows/keep-alive.yml — not committed; add it if a pause bites
name: Keep alive
on:
  schedule: [{ cron: "17 5 * * *" }]
  workflow_dispatch:
permissions: {}
jobs:
  ping:
    runs-on: ubuntu-latest
    steps:
      - run: |
          for ref in ivbpmzasxpphclundjyy jecujrsvbmashkpobtsz; do
            curl -fsS "https://$ref.supabase.co/functions/v1/health" && echo " <- $ref"
          done
```

Two caveats if you add it. A scheduled workflow is disabled automatically after
60 days without repository activity, so it is not maintenance-free. And a ping
keeps the project *awake*; it does nothing about the storage and invocation
ceilings in §2.

**If a project has already paused:** restore it from the dashboard, then
immediately re-check `cron.job`. If the purges are gone, re-apply
`supabase/migrations/20261006100000_data_retention_jobs.sql` from the SQL Editor.

---

## 4. Incidents

No alerting exists yet. Detection is manual until the error-reporting table
(F27-T12) ships, so the queries in §2 are the whole monitoring story. Assume you
will hear about an outage from a user first.

For each case: how it reaches you, what to check, what to do, and how to know it
is over.

### 4.1 "The app says analyses are unavailable"

Users see the service-disabled copy. That is `ANALYSIS_DISABLED`, which comes
from exactly one place:

```sql
select value from public.app_runtime_config where key = 'analysis_enabled';
```

`false` means somebody — possibly you, during an earlier incident — left the
master switch off. Set it back to `true`. If it is already `true`, the app is
working from a config it cached before it lost connectivity, and that clears
itself.

### 4.2 Analyses fail for everyone and the switch is on

Find out what the failures are called:

```sql
select error_code, count(*) from public.analysis_attempts
 where created_at > now() - interval '2 hours' and status = 'failed'
 group by error_code order by 2 desc;
```

| Mostly | Means | Do |
|---|---|---|
| `AI_RATE_LIMITED` | a provider is throttling or out of quota | §4.3 |
| `GLOBAL_CAPACITY_REACHED` | the day's cap is spent | §4.4 |
| `TIMEOUT` | providers are slow, not refusing | nothing at first; if it persists, raise `AI_TIMEOUT_SECONDS` in the project's secrets — but it must stay **below** the app's own 30 s timeout, or the app abandons analyses that still cost the user a slot |
| `ANALYSIS_FAILED` | the model answered with unusable output | usually a poor scan; a sudden spike suggests a provider changed a model under us |
| `INTERNAL_ERROR` | our bug | read the function logs in the dashboard |

### 4.3 A provider is out of quota

Confirm against the consoles in §2, and keep the legs straight: **Mistral first,
Groq as the fallback.** Groq alone tops out around 66 analyses a day.

- **Mistral out, Groq healthy** — the service keeps working at roughly a tenth of
  capacity, and recovers when Mistral's window resets. Consider dropping
  `global_daily_call_cap` to about `60` so the day degrades predictably instead
  of failing at an arbitrary point.
- **Both out** — set `analysis_enabled = false`. A clear "service is off" beats a
  stream of failures, and it stops the next window being burned the moment it
  opens.
- **Gemini out** (only possible with online reading on) — set
  `online_ocr_enabled = false`. Every capture then reads on the device, which
  needs no provider at all. This is the cheapest lever in the system and costs
  users only accuracy.

### 4.4 The day's cap is spent

```sql
select * from public.global_analysis_usage_daily order by usage_date desc limit 3;
```

`successful_count` sitting at the cap on an ordinary day means the cap is too low
for real demand — raise it, having first checked §2 that the providers can carry
the new number. At the cap by mid-morning is more likely abuse than success: §4.6.

The cap resets at Cairo midnight, not UTC midnight.

### 4.5 The project paused

See §3. Restore, then **check `cron.job`**.

### 4.6 Suspected abuse

The uncomfortable part, written down so it is not a discovery mid-incident: the
repository is public, so the production URL and publishable key are public;
anonymous sign-in is on and needs no human; and a reinstall resets the per-user
limit. `global_daily_call_cap` bounds the damage to one day's planned traffic —
and **it does not cover `ocr-document`**, because reading a photo takes no quota
slot. With `online_ocr_enabled` on, a script can exhaust Gemini's 500/day
without ever touching the analysis cap.

What you can see:

```sql
-- one install hammering, or many installs behind one pattern
select installation_hash, count(*), min(created_at), max(created_at)
  from public.analysis_attempts
 where created_at > now() - interval '1 day'
 group by installation_hash order by 2 desc limit 20;
```

What you can do, in order of how little it costs real users:

1. `online_ocr_enabled = false` — removes the unprotected surface entirely and
   leaves the app fully working on-device.
2. Lower `global_daily_call_cap` to just above honest demand.
3. Lower `daily_limit` from 3.
4. Tighten anonymous sign-ins (Dashboard → Authentication → Rate Limits; the
   default is 30/hour/IP). **Last resort, and know the cost:** Egyptian mobile
   users share carrier-NAT addresses, so a tight per-IP limit locks out real
   people while barely inconveniencing an abuser with a pool of addresses.
5. `analysis_enabled = false`, if it is bad enough to warrant stopping.

The durable fix is app attestation, which is deferred — so until then these five
levers are what exists.

### 4.7 A release is broken

Raise `minimum_app_version` to the first good version. Clients below it get
`400 UNSUPPORTED_APP_VERSION` and tell the user to update, instead of failing in
whatever way the bug produces. It is a blunt instrument: it locks out everyone
who cannot update yet. See `docs/RELEASE.md`.

---

## 5. What this document cannot do yet

- **No alerting.** Nothing tells you anything is wrong; F27-T12 adds the error
  table that makes alerting possible.
- **No backups on the free plan.** There is no point-in-time restore. What is in
  the database is all there is — survivable only because every document lives on
  the user's own phone and the server holds nothing but counters and anonymous
  identities. Treat that as a standing reason never to put anything else here.
- **The retention jobs have never run for real.** Their first meaningful sweep is
  90 days away for attempts and 12 months for idle users. They are proven by
  tests, not yet by a live sweep.
