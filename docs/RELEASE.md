# Releasing War2aty

Produced by F27-T25, written while shipping `1.0.1+2` (F32-T08). Companion
documents: `docs/BUILD.md` for producing the artefact, `docs/OPERATIONS.md` for
running the backend once it is out.

This document owns four things nothing else does: the **version numbers**, the
**branch and tag scheme**, the **`minimum_app_version` policy**, and what
"rollback" actually means for an app that is already on people's phones.

Read the one rule that governs all of it first.

## 0. There is no un-ship

`1.0.0+1` went to Google Play Production on 2026-10-11. From that moment the
project lost two things it had while unpublished:

- **A published build number can never be reused.** Play refuses any upload
  whose versionCode is not strictly greater than one it has already accepted,
  and that refusal is permanent — not per-track, not per-rollout.
- **An update that has reached a phone stays on that phone.** Halting a rollout
  stops *further* distribution; it does not reach backwards. Nobody who already
  updated is moved back.

So the response to a bad release is **to ship the next one**, not to retract the
last one. Every section below is shaped by that.

## 1. Versioning

`pubspec.yaml` carries one line that produces both Android numbers:

```yaml
version: 1.0.1+2
#        ^^^^^ versionName (what the user and the backend see)
#              ^ versionCode (what Play orders releases by)
```

| | |
|---|---|
| **Build number** (`+N`) | Strictly increasing, forever, across every track. Next release is **`+3`**, whatever its name. Never reuse, never go back. |
| **Version name** | `MAJOR.MINOR.PATCH`, three numeric parts, nothing else. Patch for fixes to shipped behaviour, minor for something a user can newly do, major reserved. |

`1.0.1` rather than `1.1.0` for F32 is the worked example: forty-three commits
across reading aloud, the voice sample and the camera — every one of them a fix
to behaviour that already shipped — and the only new thing a user can see is a
stop control on a settings row. Count what a user gains, not how much work it
was.

### The three-part name is not a style preference

The backend validates it against `/^\d+\.\d+\.\d+$/`
(`supabase/functions/_shared/analyze/analyze-request.ts`). A name with a
pre-release suffix, a fourth component, or a letter is **refused outright** with
`400 INVALID_REQUEST` — not merely compared unfavourably. Keep to three numbers.

## 2. The version gate cannot see the build number

This is the single most surprising thing about releasing this app, and it
decides how a bad release is actually handled.

The app sends its version from `PackageInfo.fromPlatform()`
(`lib/bootstrap.dart`), which yields **`info.version` — the version *name*
only**. `1.0.1+2` and `1.0.1+3` both report themselves as exactly `1.0.1`. The
`+N` never leaves the phone.

Therefore `minimum_app_version` **cannot distinguish two builds that share a
version name.** The consequence is concrete:

> If `1.0.1+2` is broken, setting `minimum_app_version = 1.0.1` does **not**
> lock it out. It locks out `1.0.0` and below — everyone *except* the broken
> build.

**So: a fix release that may need the version gate must raise the version
*name*, not just the build number.** Ship `1.0.2+3`, not `1.0.1+3`. The extra
patch digit costs nothing and is the only thing that makes the floor usable. A
same-name rebuild is fine only when you are content never to gate on it.

### A version read can fail, and fails downwards

If `PackageInfo` throws, the app falls back to the compiled-in constant
`AppEnvironment.fallbackAppVersion`, which is **`'1.0.0'`** — deliberately, so
an unreadable version costs one gate decision instead of the whole launch
(`lib/bootstrap.dart`). Side effect: raising the floor above `1.0.0` also locks
out any client whose version read failed, on any build. Expect a small tail.

## 3. Branches and tags

Defined by being used, on F32:

```
develop ──┬──────────────────────────────── ... ──→ (merge) ──→ main ──→ tag
          └── release/1.0.1 ── commits ── PR ──┘
```

1. **Cut `release/<name>` from `develop`** — `release/1.0.1`, named for the
   version name, no `+N`. One release branch per version name.
2. **Do the release work on it**: the version bump, the copy, the docs, any fix
   the release itself turns up. One commit per task.
3. **One PR from `release/<name>` into `develop`** at the end, reviewed and
   merged normally.
4. **Merge `develop` into `main`.** `main` is the published line: it should
   match what is live. It is routinely far behind — 270 commits at the time of
   writing — and that is expected, not a problem to fix between releases.
5. **Tag `v<name>+<build>` on `main`** — `v1.0.1+2`. The build number belongs in
   the tag even though it is absent from the version name, because the tag's job
   is to identify **the artefact that was uploaded**, and the build number is
   the only thing that does that uniquely. `+` is legal in a git ref
   (`git check-ref-format` accepts `refs/tags/v1.0.1+2`).

### Open a PR early if you need CI

CI (`.github/workflows/ci.yml`) triggers only on `pull_request` and on pushes to
`main`/`develop`. **A push to a release branch runs nothing.** If the release
changes anything CI should vet — a Flutter pin, a dependency, a lint fix — open
the PR as a **draft** at that point rather than at the end, and let it collect
runs. F32 did this at T07 and found the pin needed two code fixes before it
would go green.

### `1.0.0+1` has no tag

This repository had **no tags at all** before `v1.0.1+2`. The published
`1.0.0+1` was never tagged, and the commit it was built from is not recorded
anywhere a tag would be. Backfilling one is possible if that commit can be
identified with confidence; inventing one is worse than the gap. Left as the
owner's call.

## 4. The changelog

Two audiences, two artefacts, and deliberately **no `CHANGELOG.md`**:

- **For users — Play's "What's new".** Written per release in Egyptian Arabic,
  under the §7 copy rules: no provider is ever named, and no claim is made about
  who can see the image or the text. Say what changed in terms of what the user
  noticed being wrong.
- **For engineers — the feature docs and git history.** `docs/features/F*.md` is
  the real record: each release's contents are the feature docs it closes, and
  each task's reasoning is in its commit. A hand-maintained `CHANGELOG.md` would
  be a third copy of that, going stale between the two.

The release PR description is the natural summary of a release — it already has
to say what is in it and what is deferred.

## 5. `minimum_app_version` policy

Lives in `public.app_runtime_config`, takes effect on the **next request**, and
refuses older clients with `400 UNSUPPORTED_APP_VERSION`. See
`docs/OPERATIONS.md` §1 for the table and how to throw a switch — values are
JSONB, so a version is written `'"1.0.1"'::jsonb`.

**Default position: leave it alone.** It is the bluntest instrument in the
project. It does not degrade an old client, it stops it, and it stops everyone
who has not updated yet — including people who cannot update right now, and
(see §2) anyone whose version read failed.

Raise it only when an old client is actively harmful:

| Situation | Raise it? |
|---|---|
| Old version has a bug that misreads a paper, shows a wrong date, or crashes a flow | **Yes.** Being told to update beats being told something false about a bill. |
| Old version burns quota or hammers the backend | **Yes** — that one is damaging other users. |
| Old version merely lacks a new feature | **No.** |
| Old version is ugly, slow, or awkward | **No.** |

Before raising it, confirm from the app's own reports which version is actually
at fault (`docs/OPERATIONS.md` §4.7 has the query against `error_reports`) — a
code that appears only under the new `app_version` is the release, not the
backend. And remember §2: if the floor you need equals the version name of the
broken build, the floor cannot help you, and the answer is a new version name.

`schema_version` is the neighbouring row and is **not** a release lever. Do not
set it by hand; it moves with an app release.

## 6. When a release is bad

In order, fastest first. The first three need no upload.

1. **Is it the backend?** Check `docs/OPERATIONS.md` §4 before blaming the
   build. Most user-visible breakage this project has had was a switch, a quota
   or a provider, not the APK.
2. **Throw the narrowest kill switch that covers it** (`OPERATIONS.md` §1).
   These take effect on the next request, with nothing to redeploy:
   `online_ocr_enabled = false` sends every capture to on-device reading;
   `analysis_enabled = false` takes the whole service down *with an explanation
   the user sees*. Prefer the narrow one — the master switch stops people whose
   papers were working.
3. **Raise `minimum_app_version`** if, and only if, §5 says to — and only if §2
   says it can reach the broken build.
4. **Ship the next build.** `+3`, with a version name that the floor can
   exclude if there is any chance you will need to. This is the only real fix.

Two switches to know the direction of before you need them: `daily_limit` fails
**closed** (a broken value stops that user), `global_daily_call_cap` fails
**open** (a broken value removes the cap silently). `maintenance_message` is
wired to nothing and displays to nobody — do not reach for it in an incident.

## 7. The order of a release

Ordering that matters, rather than a full checklist — the task file of the
release in flight is the checklist.

1. **Backend before artefact.** Deploy any Edge Function the release depends on
   *before* the upload, not after. F32's case is the pattern: the error-code
   allowlist is a closed vocabulary, and a report carrying an unknown code is
   refused with a `400` the client's sink swallows **silently by design**. Upload
   first and the release headlined "every failure is now reported by cause"
   reports none of them, with nothing anywhere saying so.
2. **Apply pending migrations before the upload**, for the same reason.
3. **Gate, then build, then verify the artefact** — `docs/BUILD.md`, including
   both halves of `tool/check_play_compliance.dart`. More than half of what Play
   enforces here lives in prebuilt plugin binaries and the engine, which
   `flutter test` cannot see at all.
4. **Keep the symbols.** `build/symbols/<version>+<build>/`, archived before
   anything else builds at the same version — the directory is keyed by version
   only, so a second build overwrites it. Without them an obfuscated crash
   report cannot be read.
5. **Device pass on a real phone.** Not an emulator.
6. **Upload, then tag.** Tag what was uploaded, once it is uploaded.
7. **Watch for 72 hours**: `error_reports` by `app_version`, Play vitals and
   reviews, and any quota nothing counts for you.

## 8. What this document does not cover

- **iOS.** Nothing here is iOS-aware; the project has never built for it
  (F27-T23/T24, blocked on having no Mac).
- **Staged rollouts.** Every release so far went to Production at 100%. The
  percentages, and when a smaller first slice would be worth the slower
  feedback, are undecided.
- **Automated release builds.** CI runs the gate; it does not build, sign or
  upload anything, and deliberately holds no secrets.
