# F27-T16 — Security review

`/security-review` over the branch, plus the manual checks F27's T16 row names —
encryption, logs, secure storage, network config, dependency audit — plus the
two F12 tasks Q7 folded in here: **F12-T07** (no secrets, no document content in
logs, encryption verified) and **F12-T06** (cache cleanup verified on a real
device, which T15 deliberately left behind).

Method: the branch diff against `main` is 2.5 MB — effectively the whole project
— so rather than hand one reviewer an unreadable diff, the review was split into
four domains read against the files on disk (Edge Functions, database, Flutter
client, native/build config). Every finding that survived was then verified
first-hand before being written down here, and the one that mattered was
verified against the live systems.

---

## 1. The finding: every `SECURITY DEFINER` function was callable by anyone

**Severity: High. Was live on production and staging. Now fixed on both.**

Every migration in this project wrote `revoke execute on function … from
public`. That revokes the built-in `PUBLIC` pseudo-role's grant and nothing
else. On a hosted Supabase project `anon` and `authenticated` hold their *own*
EXECUTE grant, from the default privileges the platform installs — and a revoke
from `PUBLIC` does not touch those.

So all five `SECURITY DEFINER` functions in `public` were callable by anyone
holding the **publishable key**, which ships inside the APK and sits in this
public repo at `config/prod.json`.

The worst of them takes its retention window **from the caller**:

```sql
delete from auth.users
 where is_anonymous
   and coalesce(last_sign_in_at, created_at) < now() - p_idle_for
```

`{"p_idle_for":"00:00:00"}` matched every row. One unauthenticated request
deleted **every anonymous user of the app** — the entire user base — taking
their `analysis_attempts`, `analysis_usage_daily` and `error_reports` with them
by cascade, and it was repeatable at will. The sibling purges wiped the abuse
ledger and all production error telemetry — the evidence of the attack itself.
`record_error_report` took both `p_user_id` and `p_daily_cap` from its caller,
so monitoring rows could be forged against real users with the flood guard
disabled by passing a large ceiling.

### How it was confirmed, without deleting anything

The destructive functions were **never called on a hosted project**. Instead the
probe used `retention_jobs_report()` — read-only, and carrying the identical
`revoke … from public`:

| | before the fix | after |
|---|---|---|
| production | **HTTP 200**, returned the live cron schedules | `42501` |
| staging | **HTTP 200** | `42501` |
| local stack | `42501` permission denied | `42501` |

A reachability probe against the purge function itself — designed to be
non-destructive, via an interval that cannot parse — was refused by the
permission classifier as a mass delete. It was not worked around: the read-only
result already proves the grant.

### Why no test caught it, and why the local stack never could

`pg_default_acl` for schema `public` holds **two** entries for functions:

| granted by | function default ACL |
|---|---|
| `supabase_admin` | `postgres=X, anon=X, authenticated=X, service_role=X` |
| `postgres` | `postgres=X` |

Which one applies depends on **which role creates the function**. `supabase db
reset` applies migrations as `postgres`, so locally `anon` never gets EXECUTE
and the hole is invisible. The hosted platform applies them as `supabase_admin`,
so hosted was open. The local integration suite passed while production stood
open — the tests were not weak, they were measuring a database that could not
exhibit the bug.

The existing guard did not help either: `slot-reservation.integration.test.ts`
asserted only `error !== null` against RPCs that are `SECURITY INVOKER`, so they
fail on a missing *table* grant regardless of EXECUTE. It passed for the wrong
reason and would have kept passing.

### The fix

[`20261007000000_restrict_function_execute.sql`](../../supabase/migrations/20261007000000_restrict_function_execute.sql),
in two independent layers, because layer 1 is one stray `grant` away from being
undone and what it protects is the whole user base.

1. **`revoke execute … from public, anon, authenticated`** on every function in
   `public` — the five definer functions, the three invoker quota RPCs, and
   `set_updated_at`, which had never been revoked at all and was the one
   function that read executable-by-`anon` even locally. Nothing legitimate is
   lost: the app never calls these RPCs, it goes through the Edge Functions,
   which hold `service_role`.
2. **Arguments that cannot widen the blast radius.** The windows are floored
   (`greatest(…, interval '30 days')` for the user purge, 7 days for the two
   row purges) and the report ceiling is clamped to its maximum
   (`least(coalesce(p_daily_cap, 100), 100)`), so a caller may only ever ask for
   *less*. `record_error_report` additionally refuses a `p_user_id` that is not
   the authenticated user, which does not affect the Edge Function because it
   arrives as `service_role` with `auth.uid()` null.

The migration **asserts its own postcondition**: it queries the catalogue for
any function in `public` still executable by `anon`/`authenticated` and raises
if it finds one, and raises if `service_role` lost EXECUTE on
`record_error_report`. The entire defect was that a local result said nothing
about production, so the migration reports the truth on whatever platform runs
it rather than passing quietly and lying.

### Verified, not assumed

Each of these was run rather than reasoned about:

- **The hole, reproduced locally** — `grant execute … to anon, authenticated` on
  the local stack reproduced the HTTP 200, and the revoke turned it into
  `42501`, with `has_function_privilege` reading `f|f|t`. The fix was tested
  before it was written into a migration.
- **The clamp** — a real anonymous user was created, then
  `purge_idle_anonymous_users` was called with `"00:00:00"`, the exact call that
  was catastrophic before. It returned **0 rows** and the user survived.
- **Triggers still fire.** Revoking EXECUTE on `set_updated_at` could have
  broken the three tables that use it as a trigger. PostgreSQL checks EXECUTE at
  `CREATE TRIGGER` time, not at fire time — confirmed by watching `updated_at`
  advance on a real UPDATE as `service_role` after the revoke. (The first
  attempt measured nothing, because psql ran the whole script in one
  transaction and `now()` is transaction-scoped.)
- **The real error-reporting path still works.** Before production was touched,
  a real anonymous session was minted on staging and the live `report-error`
  Edge Function returned **202**, with the row read back from the table. That is
  what proved the new `auth.uid()` guard does not break the Edge Function.
- **After deployment**: all five definer functions return `42501` to the
  publishable key on **both** hosted projects, `service_role` still reads the
  schedules, and all three cron jobs are still active.

Applied to **staging first, then production**, with the owner's explicit
approval. Backend suite: **803 passed, 0 failed** against a real local stack.

### Tests

The three integration tests that broke were broken *correctly* — all three used
a zero window as a technique, which the clamp deliberately makes impossible.
They were rewritten against the new contract rather than weakened:

- the attempts purge now proves the parameter is the predicate by straddling a
  boundary the caller chose (20 days deleted, 5 days kept, with a 10-day window);
- the two cascade tests now delete the user directly, which is the event the
  purge causes and what the `on delete cascade` actually guarantees.

Five new tests pin the security properties: the zero window matching nothing in
both purges, the daily cap refusing to be raised past 100, and — asserting the
error **code** `42501`, never merely `error !== null` — that no client role may
execute the retention functions or record a report.

---

## 2. What the rest of the review found: nothing above Low

Three of the four domains came back with no High or Medium. The negative results
are worth recording, because they are the claims the app's privacy promises rest
on and they were checked rather than assumed.

**Edge Functions.** Closed top-level key allowlists on every request shape, so
an unknown key is rejected rather than ignored; prototype pollution unreachable
because `JSON.parse`'s `__proto__` is an own enumerable property the allowlist
sees. Every field type- and bounds-checked before use. No dynamic SQL anywhere —
only `.eq()` and `.rpc()`. `requireUser` is the first statement of all four
protected handlers, so the code does not lean on the gateway's `verify_jwt`, and
every row is keyed on `auth.user.id`; the client-supplied `installation_id` is
only ever salted-hashed into a diagnostic column. The anon-key-as-bearer bypass
was checked and fails (no `sub`). Non-2xx upstream bodies are cancelled unread,
`ApiError` messages are fixed factory strings, and provider identity never
reaches the client. Upstream base URLs are module constants — no SSRF.

**Database.** All five tables are RLS-enabled **and forced**, with zero policies
and explicit `revoke all … from anon, authenticated`; `error_reports` has no
UPDATE grant even for `service_role`. Every `SECURITY DEFINER` function pins its
`search_path`. A forged `usage_date` cannot mint a fresh quota counter — the day
is derived server-side.

**Flutter client.** AES-256-GCM is correct: `Random.secure()` key, a **fresh
12-byte nonce per encryption** generated by the library (no nonce is passed
anywhere in `lib/`, so the catastrophic GCM reuse case cannot arise), stored as
`nonce‖ciphertext‖tag`, MAC checked before any plaintext returns. The logger's
allowlist is real and enforced by construction — `LogEvent` has no free-form
field to leak through, `errorCode` is derived from a sealed `switch`, and
**no stack trace or exception message can leave the device**. Interceptors log
no headers and no bodies; there is no `print`/`debugPrint` in `lib/` at all, and
Drift statement logging is off. No TLS bypass of any kind — no
`badCertificateCallback`, no custom `HttpClient`, no `HttpOverrides`. The 401
replay path was read specifically for the classic bugs and has neither: the
retry guard is set before dispatch, and the refreshed token is carried
explicitly so a replay cannot reuse the token the server just rejected.

**Native / build.** No deep links or URL schemes on either platform. Only two
exported components: the launcher activity (`MAIN`/`LAUNCHER` only, no data
element) and AndroidX's profile installer, gated behind the signature-level
`DUMP` permission. Cleartext is restricted to `10.0.2.2`/`localhost`/`127.0.0.1`
on Android with no `<base-config>`, and iOS carries only
`NSAllowsLocalNetworking` with no `NSAllowsArbitraryLoads`. A prod release
cannot fall back to the debug key. **No secret is committed anywhere**, in the
tree or in history — the two live keys are `sb_publishable_`, which is the one
key §24 permits in the client.

### Dependency audit

- **All 191 locked Dart packages queried against OSV: zero advisories.** The
  method was validated against known-vulnerable packages (`http` 0.13.0,
  `archive` 3.3.1) so that a clean result means something rather than reflecting
  an empty database.
- `@supabase/supabase-js` likewise carries no advisory.
- `cryptography` is at **2.9.0, the latest**, from a verified publisher, with no
  discontinued marker — an early impression that it was abandoned came from a
  search summary and did not survive checking the package page.
- `flutter_secure_storage` is at 10.3.1 against 11.2.0, and that is **fine**:
  the security rework landed in **10.0.0** (Keystore RSA-OAEP wrapping AES-GCM,
  replacing the deprecated Jetpack `encryptedSharedPreferences`). Version 11 only
  removes what 10 deprecated.

**One real dependency finding**, recorded rather than fixed here because it is
not a code change: the backend has **no lockfile at all**. `supabase/functions/deno.json`
sets `"lock": false` and the only import is `npm:@supabase/supabase-js@2`,
unpinned — so the Edge Functions resolve whichever of 591-and-counting 2.x
releases is current at deploy time, with no integrity check, in a runtime that
holds the service-role key. `"lock": false` was set incidentally in the F06
scaffolding commit (`fdbcdab`) to scope the Deno LSP; it was never a security
decision and is recorded nowhere. **Recommendation: pin the specifier to an
exact version and commit a `deno.lock`.** Not done here because it changes what
every deploy ships and deserves its own verification against the live functions.

---

## 3. The three Low findings, all fixed

**Permissions the app never uses were reaching the shipped APK.** The
hand-written manifest was always clean; the *merged* prod-release manifest was
not. `camera_android_camerax` contributes `RECORD_AUDIO` and
`WRITE_EXTERNAL_STORAGE`, and the merger derives `READ_EXTERNAL_STORAGE` from
the WRITE — **without** the `maxSdkVersion="28"` the WRITE carries, so it stayed
live on API 29-32 where it grants read access to all shared media. Confirmed by
reading the real merged manifest. Neither was ever requested at runtime, which
is why it is a Low; it still mattered, because both appear in the Play listing
and in Android's app-info screen for an app whose whole promise is "we do not
keep your paper", and because the declaration is the gate — while it stood, a
later plugin upgrade could take the microphone without any manifest edit and so
without any review. **Fixed** with `tools:node="remove"` on all three (WRITE
included, or the merger re-derives the READ), guarded by
[`android_permissions_test.dart`](../../test/app/android_permissions_test.dart),
which also fails on any *new* permission appearing.

**The session was stored in plaintext while the code said it was encrypted.**
`Supabase.initialize` was called without `authOptions`, so the SDK installed
`SharedPreferencesLocalStorage` and wrote the serialized session — access JWT
and long-lived refresh token — to plain `SharedPreferences`. Meanwhile
`SecureStorageKeys.session` declared "contains a JWT — must stay encrypted" and
was referenced only by the dev-only stub repository. The exposure is narrow (an
attacker with the app's private directory already holds the Drift database,
which has the plaintext of every analysed paper and is the worse loss) — the
defect is that a control the code described was not the control the app had.
**Fixed** by [`SecureSessionLocalStorage`](../../lib/core/storage/secure_session_local_storage.dart),
which makes the declaration true. Its reads and writes are non-throwing by
design: they run inside `Supabase.initialize`, whose caller degrades the whole
app to "service unavailable" on any throw, so an unreadable store reports "no
session" and costs a fresh anonymous sign-in instead of blanking the config.
**No migration, deliberately** — an existing install gets a new anonymous
identity; nothing a user can see is lost, since documents, reminders and
settings are not keyed by the auth user, and reading the old value would mean
taking `shared_preferences` as a direct dependency to serve pre-launch installs.

**iOS keychain items would have travelled in a backup.** The package default is
`KeychainAccessibility.unlocked` — `kSecAttrAccessibleWhenUnlocked`, *without*
`ThisDeviceOnly`. iCloud sync is off, but such an item is still included in an
encrypted iTunes/Finder backup and restored onto a different device. What lives
there is the AES-256 document key and the installation id, so on iOS the key
would have arrived on the new device beside the `original.enc` files it
decrypts. It also broke the reasoning `data_extraction_rules.xml` leans on
("Keystore material does not leave the device"), which was only ever true on
Android. **Fixed** to `first_unlock_this_device` — device-bound, and readable
after first unlock so background work does not depend on the screen being
unlocked. Pinned by
[`secure_storage_options_test.dart`](../../test/core/storage/secure_storage_options_test.dart),
including a negative check against the package default.

---

## 4. F12-T06 — cache cleanup, watched on a real filesystem

T15 fixed the analysis session folder outliving its scan but could not watch it
happen. Done here on the owner's **RMX2001 (Android 11)** over `adb`, with a
dev debug build and the cache emptied first. ColorOS refuses `pm clear` and
`pm grant` from adb, so the baseline was set by deleting the cache directly
through `run-as`.

| step | observed at `<app cache>/` |
|---|---|
| baseline | empty |
| photo captured | `CAP9061783486049080896.jpg` (the camera plugin's temp file) |
| «استخدم الصورة» → continue | `analysis_sessions/043898c4-…/processed.jpg` appears |
| ~10 s later | `CAP….jpg` **gone** — the capture temp is cleaned |
| on the result screen | session still present (correct — the analysis is live) |
| **leaving the result screen** | **session gone within 2 s** |

Then the accumulation half, which is what the original bug was:

- a second scan was **abandoned** at the OCR review screen by backing out — its
  `46452963-…/processed.jpg` **persisted**, which is the residual T15 recorded;
- starting a third scan **purged it**: only `3b378945-…` remained.

So the cache is bounded at one session no matter how many scans are abandoned,
and a completed scan leaves nothing. Both halves of T15's fix work on real
hardware. The phone was left clean — empty `analysis_sessions/`, no page image,
and the test artefacts removed.

**Observed, not explained.** Before the cache was cleared, the dev app's cache
root held four **empty** UUID-named directories alongside `analysis_sessions/`.
They contained no files, so no page image was leaking, and none reappeared
across three camera scans — so they come from some other path (most likely the
gallery flow, which could not be exercised: this device's DocumentsUI would not
respond to row taps). Recorded because "temp files reliably removed" is the
acceptance item, and empty directories accumulating is untidy even when it is
not an exposure.

---

## 5. Recorded, not changed

- **The backend has no dependency lockfile** (§2). The one finding from this
  task left open, with a recommendation.
- **`flutter_secure_storage`'s `resetOnError: true`** is the package default: a
  Keystore error silently wipes all secure storage, which would destroy
  `document_encryption_key` and make every saved image permanently unreadable.
  Changing it trades silent data loss for a hard error the app must then handle,
  which is a product decision about failure behaviour, not a security fix.
- **The `ocr-document` endpoint has nothing in front of it** — it takes no quota
  slot and is outside the global cap, so it is effectively free OCR on our key
  for any anonymous caller. Already recorded in the T06 migration and in T26's
  row; repeated here because it is the one unprotected path left.
- **A model-chosen field decides whether the quota is consumed.**
  `countsAsSuccess` is `status !== "unsupported"`, and `status` comes from the
  model, whose only input is attacker-controlled text. Gating on "did we return
  content" would be sounder than gating on the model's own verdict.
- **No length cap on candidate strings** in the analyze request — 100 entries
  per kind with unbounded strings go into the prompt, while `ocr_text` itself is
  capped at 12,000.

---

## Gate

`dart format .`, `flutter analyze` (**0 errors, 0 warnings**; 18 infos, none in
files this task touched) and `flutter test` — **2,418 passed** (+13). Backend:
`deno test` against a real local stack — **803 passed, 0 failed** (25 ignored
are the live-AI tests that need provider keys).
