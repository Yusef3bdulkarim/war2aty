# F27-T20 · Privacy policy and terms

The first thing this project has published to the open web, and the one both
stores demand before they will list the app: a privacy policy at a public URL
(**B4**), with the terms of use and the "not legal/medical/financial advice"
disclaimer beside it (**M5**).

Acceptance, from the F27 plan: *"Arabic privacy policy (wording consistent with
§7) and terms per Q18, at a public URL (Q17); linked from the in-app screen;
support contact."*

## Live now

| | URL |
|---|---|
| **Privacy policy** — the URL T21 gives Play | <https://yusef3bdulkarim.github.io/war2aty/privacy.html> |
| **Terms of use** | <https://yusef3bdulkarim.github.io/war2aty/terms.html> |
| Index, linking both | <https://yusef3bdulkarim.github.io/war2aty/> |

GitHub Pages, served from the **`gh-pages` branch** at commit `1d7ec44`, HTTPS
enforced, all four paths answering 200.

### Why a branch of its own

The source of truth is `legal/` on the development branch, under
`test/app/legal_pages_test.dart`. `gh-pages` holds a copy of that directory's
*contents* at the repository root, so the published paths are `/privacy.html`
rather than `/legal/privacy.html`.

The branch exists because of an ordering problem the plan did not anticipate:
**Phase 4 ships as one pull request** (owner, 2026-10-08), so anything that
publishes from `develop` or `main` goes live only after T22 — which is *after*
T21, the task that needs the URL. A `gh-pages` branch decouples the two. The
copy was verified byte-identical to `legal/` after pushing, and `.nojekyll` is
there so GitHub serves the files as written instead of running them through
Jekyll.

**This is a copy, and copies drift.** Re-run the sync when `legal/` changes;
the guard test covers the source, not the published branch.

## The owner's answers (Q17, Q18)

| | |
|---|---|
| Developer of record | **شركة كيان وطموح للخدمات التجارية** / Kayan Wa Tomouh Commercial Services |
| Support address | **war2aty.support@gmail.com** |
| Q18 — a terms page | **Yes**, published alongside the policy |
| Hosting | GitHub Pages, `gh-pages` branch |
| `url_launcher` | Approved |

The support address is **not** the owner's personal mailbox, which is what Q17
originally named. It appears on a public page and in a store listing, so a
dedicated free address was proposed and accepted — the personal one stays off
the open web.

## What the pages say, and why it is not boilerplate

The policy is written from the code, not from a template. Every factual claim
in it was read out of the repository first:

- **What leaves the phone**, field by field, from the two request DTOs:
  `schema_version`, `session_id`, `installation_id`, `app_version` and either
  the image (`image/jpeg`|`png`) or `ocr_text` + `detected_languages` +
  `candidates`. The page says "and nothing else" because that is literally the
  whole payload — no EXIF, no GPS, no thumbnail.
- **What our server keeps**: the daily counter, `analysis_attempts` (including
  that it stores a *salted hash* of the installation id and never the
  identifier itself) and `error_reports` (codes, stages, versions, durations —
  no messages, no content).
- **Retention**: 90 days and 12 months, the numbers in migrations
  `20261006100000` and `20261006150000`, not round numbers chosen for the page.
- **The deletion controls**: «حذف كل المستندات», «حذف كل التذكيرات», «حذف كل
  بيانات التطبيق», the consent switch and the notification-privacy switch —
  each a real settings row.
- **Permissions**: camera and notifications, and that the microphone is
  neither requested nor used, which is worth saying for an app that
  photographs private documents (and is only true because T16 removed it).
- **The daily limit**: 3, from `app_runtime_config`.

### §7 is binding on these pages too

The project forbids two things in any user-facing text, and both are easy to
slip into a privacy policy because both read as *reassuring*: naming a
provider, and claiming nobody sees the photo or the text. The pages state the
uncomfortable half plainly — the outside reader may keep the photo for a while
and let staff review it; the analysis provider's free tier permits content
review — and the two services are described by function, never named.

`test/app/legal_pages_test.dart` (16 tests) enforces that, reading the HTML off
disk the way `native_permission_copy_test` reads the native config. It also
asserts the retention windows, the daily limit, the deletion routes and the
permission list **match what is implemented**, so a page that drifts from the
code fails here rather than misleading a user.

Two findings came out of writing that guard:

1. **The honest wording quoted the claim it was denying.** The first draft said
   «مش بنقول إن محدش بيقرا النص» — "we don't say nobody reads the text". A
   substring guard cannot tell a denial from an assertion, and a page that
   prints the retired claim in order to deny it still prints it. Rewritten
   positively: «مانقدرش نضمنلك إن النص هيفضل من غير مراجعة». The app's own
   approved copy never needed the quote either.
2. **Phrase assertions against HTML were a coin toss.** The markup wraps
   sentences mid-phrase, so «ممكن تحتفظ بيها فترة» is broken by a newline and
   an indent on disk. Three tests were failing on correct copy. The guard now
   collapses whitespace and reads the text the way a browser does.

### Not naming the providers, in a legal document

Naming sub-processors is normal practice in a privacy policy, and §7 forbids
it. The owner approved keeping them unnamed: the market is Egypt only, the rule
is non-negotiable, and Play's Data safety form (T21) asks about sharing in
*categories*, not by provider name — so nothing downstream forces the issue.
Recorded here because it is a deliberate deviation from the usual shape of such
a document, not an oversight.

## In the app

The settings «عن التطبيق» section gained two rows, and the in-app privacy
screen a footer:

| Surface | What it does |
|---|---|
| Settings → «سياسة الخصوصية» | unchanged — the four in-app promises |
| Settings → **«شروط الاستخدام»** | opens the published terms |
| Settings → **«الدعم والتواصل»** | opens a mail to the support address |
| «سياسة الخصوصية» screen footer | **«اقرا سياسة الخصوصية الكاملة»** and the terms |

The footer is on `PrivacyPolicyScreen` and deliberately **not** in
`PrivacyPolicyContent`, which is shared with the first-run step: sending a user
to a browser before they have even agreed is the wrong moment.

### The chain, because the architecture asks for one

`url_launcher` is a plugin, so it sits behind the same shape
`permission_handler` does (CLAUDE.md §B1, §B5, §B9):

```
LegalLinksCubit → OpenLegalLink → LegalLinkRepository
                                  └ SystemLegalLinkRepository → ExternalLinkService
                                                                └ UrlLauncherExternalLinkService
```

`lib/core/legal/legal_links.dart` holds the three destinations as plain
constants with no Flutter import. One `LegalLink` enum rather than three use
cases: the only thing that differs is the destination, and a closed set makes
this the single audited way the app sends a user outside itself.

The cubit is app-scoped in `app.dart` beside `SettingsCubit` — it holds nothing
to load, and the two screens that use it sit in different branches of the tree
(the settings rows inside the shell, the privacy screen as a top-level route).

**No silent failures.** A phone with no browser, or no mail app, makes the tap
do nothing at all. `LegalLinkUnavailable` carries which link failed, and the
support case names the address in its message so a user with no mail app can
still write it down. The cubit emits idle before each attempt, because
otherwise a second failed tap emits a state equal to the current one,
`BlocListener` never fires, and the row looks dead — asserted directly, and the
emission order in that test is the mechanism itself.

### Two things that would have failed only on a real phone

- **Android package visibility.** At targetSdk 30+ an app cannot resolve an
  intent it has not declared, so without `<queries>` entries for an `https`
  VIEW and a `mailto` SENDTO, `url_launcher` finds nothing and **every row
  added by this task fails — on the phones the app ships to and nowhere else**.
  Both are now in the manifest and asserted by `legal_links_test`.
- **iOS is untouched.** `launchUrl` works for `https` and `mailto` without
  `LSApplicationQueriesSchemes`, which is only needed by `canLaunchUrl` — and
  the app does not call it. Recorded for T23 rather than guessed at, since
  nothing here can be built or seen without a Mac.

### What the self-review changed

`/flutter-review` found one real defect in the footer: the links were a bare
`GestureDetector` around a `Text`, which gave a tap target **one line tall
(~24 dp)** and announced nothing to a screen reader — in an app written for
readers with poor eyesight. They are now `Semantics(button:)` + `InkWell` with
vertical padding, matching `SettingsNavRow`'s own shape, and a test asserts
both the 48 dp minimum and the button flag. Mutation-checked by dropping the
padding to zero: *«اقرا سياسة الخصوصية الكاملة» is below the 48 dp minimum tap
target*.

## The ripple a new failure leaf causes

`ExternalLinkFailure` is a new `AppFailure` leaf, and the project's
exhaustive-switch discipline turned that into a short, useful chain of
compile errors and one test failure:

- `errorCodeOf` — a new code, `EXTERNAL_LINK`.
- `shouldFallBackToOnDeviceOcr` — listed as `false`, since opening a policy
  page has nothing to do with reading a paper (F20 §1's allowlist stays closed).
- `app_failure_test` — 32 leaves now, 16 of them local.
- **T12's cross-language guard caught the real one**: the server's allowlist in
  `error-report-codes.ts` had to learn `EXTERNAL_LINK`, because the app can
  produce a code the server would otherwise refuse with a 400 the sink
  swallows by design — the reports would simply never arrive. Exactly the
  failure that test was written for, and it fired on the first run.

**Deployment note:** that server change ships with the next `report-error`
deploy. Nothing reports `EXTERNAL_LINK` today (the cubit does not log), so the
window is harmless — but the backend and the app are briefly out of step, and
T26's rollout should carry it.

## Not done here

- **No store forms.** Play's Data safety and Apple's App Privacy labels are
  T21/T24 and need the owner's consoles. B4 is closed only for the *URL*
  half; the two forms are still open and still named in B4's row.
- **A policy URL on a personal GitHub account.** The developer of record is a
  company, and `yusef3bdulkarim.github.io` is a personal account. It is valid
  and it works, but a reviewer may read the mismatch; a custom domain or a
  company organisation would read better. Raised with the owner, who chose to
  proceed — recorded so T21 is not surprised by it.
- **The pages are not versioned or dated automatically.** «آخر تحديث» is a
  hand-edited line. If the policy changes materially, that date and the in-app
  copy change with it; nothing enforces that.

## Gate

`dart format` clean · `flutter analyze` 0 errors / 0 warnings (18 pre-existing
infos, none in new or touched files) · `flutter test` **2,503 green (+35)** ·
`deno test supabase/tests` 759 passed.
