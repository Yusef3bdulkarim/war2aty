# F19 · Offline First Launch

- **Branch:** `feature/offline-first-launch` (off `develop`) · **Milestone:** post-M9
- **Depends on:** F01 (the launch sequence, `EnsureActiveSession`, `SupabaseAuthRepository`), F06-T14 (the real Supabase Anonymous Auth and the `AuthInterceptor` this feature leans on) · **Feeds:** offline usability of the whole app
- **Progress:** 3 / 3 DONE · code complete, device verification outstanding

A clean install launched with **no internet** shows the launch error screen
(«حصلت مشكلة وإحنا بنجهّز التطبيق») instead of opening the app. Reproduced on a
**prod** build, 2026-09-27. Once online it launches normally — and then keeps
launching offline fine **for exactly one hour**, after which the same error
screen returns.

The app blocks its own launch on a network identity it does not yet need. Every
offline-capable feature the MVP has — saved papers, reminders, the audio reader,
on-device OCR — sits behind a wall the user cannot get through without the
connection those features exist to survive.

---

## Context — the traced root cause

### 1 · The launch chain

1. `Supabase.initialize` **succeeds offline.** The SDK
   (`supabase_flutter-2.17.1`) only touches SharedPreferences and starts the
   deep-link observer; it makes no network call. So `env.isConfigured` stays
   `true` and DI resolves `SupabaseAuthRepository` — **not** the offline
   `StubAuthRepository`. `bootstrap.dart`'s degraded path is never taken.
2. `EnsureActiveSession` finds no stored session → `signInAnonymously()` →
   network → `Err`.
3. `session` is the one **critical** step in `_buildLaunchSteps()`
   (`service_locator.dart:380`), so launch aborts → `BootstrapFailure` →
   `_LaunchError`.

### 2 · Why it stops reproducing, and why only for an hour

`SupabaseAuth.initialize()` **awaits** `setInitialSession(persistedSession)`,
so `currentSession` is already populated when `Supabase.initialize` returns —
that is what makes a warm offline launch work. But `setInitialSession` sets the
session **even when it is expired**, and our `restoreSession` then discards an
expired session and reports "no session", sending the flow back to
`signInAnonymously()`. Supabase access tokens live one hour.

Confirmed by the user on device: within the hour the app opens offline; after
the token expires, the identical error screen returns on a cold launch.

The persisted session itself survives — verified in the SDK: an offline refresh
raises `AuthRetryableFetchException`, which `_doRefresh` treats as retryable and
therefore keeps the session rather than signing out. The data is there; the app
simply refuses to use it.

### 3 · Three defects that compound, and must be fixed together

- **Misclassification.** gotrue wraps *every* transport failure in
  `AuthRetryableFetchException`, which **extends `AuthException`** — so
  `supabase_auth_repository.dart:35` catches it first and returns
  `UnauthorizedFailure`. The `on Object → NoInternetFailure` branch below it is
  dead code for network failures. Nothing downstream can branch on "is this
  offline?" until this is true. There is no test for this class at all today.
- **Expired ≠ absent.** An expired-but-present session is thrown away, forcing
  a network round-trip the app cannot make offline — even though
  `AuthInterceptor` exists precisely to refresh-and-replay a stale token on a
  401 (its own doc comment, lines 14-24).
- **Blocking launch on an identity nothing needs yet.** `AppSession`/`userId`
  never leaves `features/bootstrap/` (grep: six files, all inside it); the
  launch step itself discards the value (`result.map<void>((_) {})`). The only
  consumer is the Dio `accessToken` closure, whose contract already reads
  *"returns the current access token, or `null` when there is no session"*.

### 4 · Why a session-less launch is safe

- **No NPE surface.** There is no session singleton and no `currentUser` read
  anywhere in presentation; nothing can dereference a missing session.
- **No dirty local state.** `SupabaseAuthRepository` writes nothing at all — by
  design (lines 16-21: the SDK owns the rotating credential, two writers would
  lock the install out). No Drift table has a `user_id` column, so nothing local
  is keyed by the anonymous identity.
- **Analysis needs the network anyway.** Even the offline route only runs *OCR*
  on-device; classification always goes through the Edge Function (§9). So a
  session-less launch creates no new dead end — it changes only which screen a
  failure lands on, and *where* the user meets it.
- **Everything downstream already degrades.** `RemoteUsageRepository.syncUsage()`
  falls back to today's cached row; `watchUsage()` reads only Drift;
  `DecideAnalysisRoute` fails closed to the offline route on any failure.
- **It self-heals.** `SupabaseAuthRepository.refreshSession` mints a session
  when `currentSession == null` (line 69), and that is exactly the hook
  `AuthInterceptor._replay` calls on a 401. The identity arrives on the first
  authenticated call once the network is back, invisibly.

## Locked decisions

Resolved with the user in the session that opened this feature (2026-09-27).

1. **No connectivity listener.** The interceptor's existing 401 → refresh →
   replay path is the only recovery mechanism. Watching connectivity to
   re-run `EnsureActiveSession` earlier would add a listener for no behaviour
   the user can perceive.
2. **Only `NoInternetFailure` becomes tolerable at launch.** A genuinely
   *rejected* sign-in (anonymous sign-ups disabled, GoTrue 5xx) still aborts
   and still shows `_LaunchError` with its retry. A misconfigured backend stays
   loud, and `BootstrapFailure` / `_LaunchError` / their tests stay live rather
   than becoming dead code.
3. **No new user-facing strings.** `analysis_result_screen.dart:517-523` already
   maps `NoInternetFailure` to `_FailureKind.offline`, with correct Arabic copy
   *and* the raw-OCR-text fallback. T01 is what makes that path reachable; the
   user meets offline messaging where it is actionable, not at launch.
4. **The expiry rule lives in the domain.** `EnsureActiveSession`'s own doc
   comment already claims the policy ("keeping this here, not in the
   repository"). The repository's expired-session filter is that policy
   duplicated in the wrong layer, and it loses the information the policy needs.
5. **Privacy unchanged (§7/§51).** The new mapper reads only the exception's
   runtime type and `statusCode` — never `message`, which can carry a response
   body. No token, no document content, nothing new in any log.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F19-T01 | Classify auth failures correctly | New `data/mappers/auth_failure_mapper.dart`: `failureFromAuthException` — `AuthRetryableFetchException` with a null `statusCode` → `NoInternetFailure` (transport), with a set `statusCode` → `AnalysisServiceFailure` (the SDK sets it only in its `>= 500` branch), every other `AuthException` → `UnauthorizedFailure` (unchanged). Shaped after `failureFromDioException`, same privacy rule: never read `message`. Both call sites in `SupabaseAuthRepository` routed through it; `refreshSession` stops answering a *transport* failure with a second guaranteed-to-fail sign-in, while a rejected token still mints a fresh identity. Unit tests over real SDK exception objects — no mocking | DONE |
| 2 | F19-T02 | Accept an expired session offline | `restoreSession` stops discarding an expired session and reports what the SDK holds; `EnsureActiveSession` still refreshes an expired session, but when the refresh fails with `NoInternetFailure` it returns the stale session instead of `Err`. Any other refresh failure still propagates, and online behaviour is unchanged (the proactive refresh still happens, so the first analysis pays no 401). Consequence documented in code: the Dio closure now attaches a stale JWT → 401 → the interceptor's refresh-and-replay, one wasted round-trip. Extends `ensure_active_session_test.dart`; the `AuthRepository` interface doc now states that a restored session may be expired and that a refresh failure is classified — the two implementations disagreed on this before, since `StubAuthRepository` always returned what it held | DONE |
| 3 | F19-T03 | Launch without an identity when the network is the reason | The `session` step keeps `critical: true` but gains its own inner bound (shorter than `BootstrapStep.defaultTimeout`) resolving to `NoInternetFailure`, and tolerates *only* that failure by returning `Ok(null)` after logging it — `InitializeApp` logs only what it aborts on, so without that line a session-less launch leaves no signal. The inner bound is what covers the captive-portal case: the orchestrator applies its own timeout *outside* the step closure (`initialize_app.dart:89`), so a step timeout can never be tolerated by the step itself. No other file changes, no new strings. Inner bound set to 8s | DONE |

## Verification

Quality gate (CLAUDE.md §10) after every task: `dart format .` · `flutter analyze` · `flutter test`.

Then on a **physical device, prod flavor**:

1. **The bug.** Uninstall, airplane mode **on**, launch → reaches
   onboarding/Home, no error screen. Capture and on-device OCR work; an
   analysis attempt shows «مفيش إنترنت» with the raw-text fallback, *not*
   «خدمة التحليل فيها مشكلة» — that difference is what proves T01 landed.
2. **Lazy identity.** Same install, network **on**, run an analysis → succeeds.
   The dev log shows a 401 then a successful replay, and no `NO_INTERNET`.
3. **The one-hour regression.** Launch once online, kill the app, let the JWT
   expire (>1h, or move the device clock forward), airplane mode **on**, cold
   launch → opens normally.
4. **Captive portal.** Wi-Fi with no route to the backend → the app opens within
   the inner bound, no error screen.
5. **Rejection still blocks.** Point the build at a URL that rejects sign-in (or
   disable anonymous sign-ins in the project) → `_LaunchError` with its retry
   still appears.

Steps 4 and 5 are manual only — nothing in `flutter test` covers the DI
composition in `_buildLaunchSteps()`.
