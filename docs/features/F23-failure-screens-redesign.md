# F23 · Failure Screens Redesign

- **Branch:** `feature/failure-screens-redesign`, based on `develop` · **Milestone:** post-F22
- **Depends on:** F07 (the result screen and its failure page), F21 (the teal result bar)
- **Progress:** 10 / 14 DONE
- **PR:** timing to be agreed with the owner once the tasks are done; base `develop`

The owner's redesign of the five pages the result screen shows when there is
no analysis to show (`AnalysisResultFailed`): **unsupported paper**, **no
internet**, **daily limit reached**, **service problem** and **analysis
consent off**, 2026-10-01. The old pages were one bare layout (a floating
round back button, an icon panel, a title, a message, buttons). The new ones
sit under the result screen's teal bar and fill the page with content that
helps, so a failure does not feel like a dead end.

Approved mockups (private canvas):
https://claude.ai/artifact/Y7R12wRrBSSDKCBTBbtjm6 — frame «Unsupported —
Option B (chosen)» and the four «— redesign» frames. They are the design
source for these pages; the Waraqti design is not updated by this feature.
The owner approved them in writing on 2026-10-01 (Option A was not chosen).

**Presentation, plus one read.** No Edge Function, schema or repository
changes. The only non-UI change is that the result cubit reads the cached
daily limit for the limit page (#14).

## Locked decisions

1. **All five pages change**, and keep sharing one layout:
   `ServiceStateView` (`lib/core/widgets/service_state_view.dart`). Its two
   other users, the reminder and saved-paper «not found» pages, get the same
   new bar and lose their icon panel too (the owner's own change below already
   hides it for them).
2. **The top bar is the result screen's teal bar alone**: the back arrow on
   the teal, bottom corners rounded 28, no hero, no visible title. It is
   extracted from `ResultHeroScrollView`'s private `_PinnedBar` into
   `core/widgets/` so both screens draw the same widget. On the failure pages
   it carries no screen-reader heading: the page's own title is the heading.
3. **Back (the arrow and the system gesture) still goes home**, through
   `onClose`, as now.
4. **No icon panel.** The owner's uncommitted change that hid it is kept and
   finished: the commented-out code and the `glyph`/`tint`/`iconColor`
   parameters are removed, along with the three `unused_element` warnings
   they caused.
5. **Unsupported paper = Option B:**
   - Title «مقدرناش نشرح الورقة دي». One honest message for both causes (the
     server does not say which): «ممكن يكون الكلام اللي فيها مش واضح كفاية،
     أو نوعها لسه مش من الأوراق اللي بنشرحها. جرّب تصوّرها تاني في نور كويس،
     أو صوّر ورقة من الأنواع اللي تحت.»
   - A green line with a check: «المحاولة دي متحسبتش من تحليلاتك النهارده».
     True: an `unsupported` answer is a 200 that never takes a slot (§31
     rule 6).
   - A tappable card «عرض النص المستخرج» / «الكلام اللي قريناه من الورقة،
     وتقدر تنسخه», opening the existing `ExtractedTextOnlyView` (copy and the
     «تم النسخ» SnackBar live there). Hidden when there is no text.
   - «الأوراق اللي بنشرحها»: a 2 × 2 grid of the four categories plus a
     full-width «أوراق تانية» tile, each with examples. Icons and tints come
     from `DocumentCategoryStyle`:
     | Tile | Examples |
     |---|---|
     | فواتير وإيصالات | كهربا، مية، غاز، تليفون |
     | مواعيد | ميعاد دكتور، حجز، مقابلة |
     | أوراق حكومية | إخطار، خطاب رسمي |
     | أوراق تعليمية | نتيجة امتحان، ورقة مدرسة |
     | أوراق تانية | تقرير طبي، ورقة قانونية، ورقة من البنك |
     «أوراق تانية» is listed because medical, legal and financial papers are
     analysed (they file under `other`).
   - Actions: «صوّر ورقة تانية» (camera, filled) and «اختار من الصور»
     (gallery, tinted) **side by side**, each opening its capture route
     directly; then «العودة للرئيسية». No step tracker on this page.
6. **No internet:** title «النت فاصل دلوقتي»; message «علشان نشرح الورقة
   محتاجين إنترنت. الكلام اللي فيها اتقرا خلاص، فمش هتحتاج تصوّرها تاني.»; the
   step tracker (#10) with «الشرح» waiting («مستني النت»); a tips card «جرّب
   الحاجات دي»: Wi-Fi or mobile data, airplane mode off, weak signal. Actions
   «حاول تاني», «عرض النص المستخرج», «العودة للرئيسية».
   - **Amended from the mockup (truthfulness):** «على موبايلك» is dropped
     from the message and from the tracker's second step. The page also shows
     when the online reading succeeded and the connection fell only before the
     analysis, and the app cannot tell the two apart (`ExtractionResult`
     carries no reader). The step reads «تمام».
   - **Amended from the mockup:** no «متحسبتش» line. A socket that dies
     after the request reached the server is also mapped to
     `NoInternetFailure`, and the server may have counted that run.
7. **Daily limit:** title «خلّصت تحليلات النهارده»; message «عندك 3 تحليلات
   ذكية كل يوم، واستخدمتهم كلهم. الكلام اللي في الورقة لسه متاح تقراه
   دلوقتي.» (the number and its Arabic plural come from the limit); a teal
   countdown card «تحليلاتك بتتجدد بعد» + «5 ساعات و 12 دقيقة» + «الساعة 12
   بالليل بتوقيت مصر» + a pill «استخدمت 3 من 3 النهارده» with one dot per
   analysis; a card «تقدر تعمل إيه دلوقتي؟» (read and copy the text, which
   costs nothing; keep the paper and photograph it tomorrow). Actions
   «عرض النص المستخرج», «العودة للرئيسية».
8. **Service problem:** title «حصلت مشكلة أثناء الشرح»; message «مقدرناش
   نكمّل شرح الورقة دلوقتي. الكلام اللي قريناه لسه معانا، فتقدر تحاول تاني من
   غير ما تصوّر من الأول.»; the step tracker with «الشرح» failed («ماكملش»);
   a card «لو المشكلة اتكررت» (wait a minute, check the connection, read the
   text meanwhile). Actions «حاول تاني», «عرض النص المستخرج», «العودة
   للرئيسية». No «متحسبتش» line: a client timeout can still be counted by the
   server.
9. **Consent off:** title «الشرح الذكي مقفول»; message «إنت قافل «السماح
   بإرسال النص للتحليل» من الإعدادات، وده اختيارك. علشان كده مقدرناش نشرح
   الورقة، بس الكلام اللي فيها متاح تقراه.»; a card «لو فتحته، هنقولك:» with
   four tiles (نوع الورقة / أهم اللي فيها / المطلوب منك / المواعيد اللي
   محتاجة تذكير); the approved privacy wording, word for word: «بنبعت نص
   ورقتك مشفَّر لخدمة تحليل علشان نفهمه، ومانحفظش النص عندنا.» Actions
   «افتح الإعدادات», «عرض النص المستخرج», «العودة للرئيسية».
10. **Step tracker** (no internet, service problem): three steps, right to
    left, «الصورة» ✓ «تمام», «قراية الكلام» ✓ «تمام», «الشرح» (waiting:
    a clock, or failed: a warning triangle, on amber). State is shown by icon
    and words, never by colour alone. Its own screen-reader label reads the
    three steps as one sentence.
11. **«عرض النص المستخرج» only when there is text**, on every page (as now).
    Both routes reach the result screen through the OCR review, so the text is
    normally there; the stale F13 comment saying otherwise is corrected.
12. **Listen is dropped** from the failure pages: the `onListen` parameter of
    `AnalysisResultScreen` (never wired by the router) and its secondary
    action are removed. The limit message no longer mentions listening.
13. **Large Text:** the side-by-side pair stacks (camera above gallery) once
    the text scale reaches 1.3. Every page scrolls between the bar and the
    pinned actions. No overflow at 2.0× on 320 × 568.
14. **The limit number comes from the cached usage.** On a
    `DailyLimitReachedFailure` the cubit reads `GetDailyUsage` (local cache,
    no network) and carries `dailyLimit` in `AnalysisResultFailed`. If the
    cache is empty or fails, the message drops the number («استخدمت كل
    تحليلات النهارده.» + the text sentence) and the pill is hidden. Dots are
    drawn only up to 10.
15. **The countdown** counts to the failure's `resetAtCairo`, refreshed every
    minute by a widget timer (presentation state; the clock is injectable for
    tests). Minutes round up, so it never reads zero while time is left; at
    or past the reset it reads «تحليلاتك اتجددت خلاص». Arabic plurals for
    hours and minutes (ساعة / ساعتين / 3–10 ساعات / 11+ ساعة; دقيقة /
    دقيقتين / 3–10 دقايق / 11+ دقيقة).
16. **The quiet last action uses `textSecondary`** (#5A686E), not
    `textMuted`, which fails contrast on the page background.
17. **Colours come from `AppColors`**, so the high-contrast palette applies;
    no new tokens. New stroke glyphs: `wifi`, `airplane`, `signal`,
    `lightbulb`.
18. **Strings:** every new string in `AppStrings`/`ar`/`en`, covered by
    `app_strings_test` (no provider names, no «nobody sees it» claims). The
    old unsupported/limit/failed messages that the pages no longer use are
    removed.
19. **Out of scope** (owner, 2026-10-01): auto-retry when the connection
    returns, a «remind me tomorrow» notification, and turning consent on from
    the page.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F23-T01 | Task file | This file and the README row, from the owner's decisions of 2026-10-01 | DONE |
| 2 | F23-T02 | Shared teal bar | `TealTopBar` in `core/widgets/` (back arrow, optional screen-reader heading, optional trailing, light status-bar icons); `ResultHeroScrollView` uses it with no visual change. Tests: back tap, tooltip, heading only when given, mirrored arrow in LTR | DONE — `lib/core/widgets/teal_top_bar.dart` (`TealTopBar`, `TealTopBar.heightOf`); `ResultHeroScrollView` draws it and its private `_PinnedBar` is deleted, with no visual change (its 16 tests and the result and saved-paper screen suites, 54, pass unchanged). 5 tests in `test/core/widgets/teal_top_bar_test.dart` |
| 3 | F23-T03 | New stroke glyphs | `wifi`, `airplane`, `signal`, `lightbulb` in `StrokeGlyph` and `svg_path.dart`. Existing glyph test covers them | DONE — the four glyphs and their paths live in `lib/core/icons/stroke_icon.dart` (the path table is there, not in `svg_path.dart`); the airplane is centred on x = 12 (the mockup's was 1.5 off). The existing glyph tests (every glyph draws, stays in the 24×24 box) cover them: 10/10 |
| 4 | F23-T04 | `ServiceStateView` rework | Teal bar; no icon panel (the owner's change finished, the three parameters removed, callers updated); title, message, optional `note`, `content` widgets; actions with optional glyphs, an optional side-by-side primary pair that stacks at text scale ≥ 1.3; the quiet action in `textSecondary`. Tests: no icon panel, content order, pair in one row vs stacked at 1.3, back calls `onBack`, no overflow at 2.0× on 320 × 568 | DONE — `ServiceStateView(title, message, primary, secondary?, tertiary?, note?, content, pairPrimaryActions, onBack)`; `ServiceStateAction.glyph`; `pairedActionsStackScale` = 1.3; the pair sits in an `IntrinsicHeight` row so both buttons match when a label wraps; buttons take a minimum height and grow with Large Text instead of clipping. The owner's icon-panel change is finished: the panel, `glyph`/`tint`/`iconColor` and the reminder/saved-paper `_StateBody` copies of them are gone. `flutter analyze` 20 → 17 (the three WIP warnings). 10 tests in `test/core/widgets/service_state_view_test.dart`; the result, saved-paper and reminder screen suites (77) pass unchanged |
| 5 | F23-T05 | Strings | Every string of #5–#9, #14 and #15 in `AppStrings`/`ar`/`en`, with the plural functions (limit, hours, minutes) unit-tested; `app_strings_test` map updated | DONE — 41 new members and 7 rewritten values (the five titles/messages, `analysisCaptureAnother` → «صوّر ورقة تانية»), Arabic and English; the consent page reuses `privacyPointTextOnly` (the approved wording) instead of a copy. `resultListenToExtractedText` stays until T07 stops using it. 12 tests in `test/core/localization/failure_page_strings_test.dart` (hour/minute/limit plurals, the usage pill, the tracker sentence, and the truthfulness rules of #6/#8: no «موبايلك» offline, «متحسبتش» only on unsupported, no listening on the limit page); `app_strings_test` covers every new member (privacy and provider-name checks included) |
| 6 | F23-T06 | Limit in the failure state | `AnalysisResultFailed.dailyLimit` (nullable); the cubit reads `GetDailyUsage` only on `DailyLimitReachedFailure`; DI updated. Tests: limit carried from the cache, `null` on an empty cache and on a cache failure, not read for other failures | DONE — `AnalysisResultFailed(failure, extractedText, {dailyLimit})` (in equality); the cubit takes `GetDailyUsage` and, only on `DailyLimitReachedFailure`, reads the cache (no network) before emitting, with an `isClosed` guard after the read; the state's stale F13 comment is corrected (#11). DI passes the registered `GetDailyUsage`. `FakeUsageRepository.cachedReadCount` added. 5 tests in `analysis_result_cubit_test.dart` (limit carried, empty cache, failing cache, no read for other failures, nothing emitted when closed mid-read — the last mutation-checked by removing the guard); the three other cubit constructions in tests updated |
| 7 | F23-T07 | Screen API and router | `onPickFromGallery` added (go home, push the gallery capture route); `onCaptureAnother` opens the camera directly; `onListen` removed from the screen. Tests: each callback fires from its button | DONE — `AnalysisResultScreen.onPickFromGallery` (router: `go(home)` then `push(captureWith(gallery))`, the same shape as the camera's); `onListen` removed from the screen and the failure body, and `resultListenToExtractedText` from the strings. Until T08 lays the page out as Option B, the gallery is the unsupported page's secondary action, so every commit keeps a working page. The stale F13 comments on the failure body are corrected (#11). Tests in `service_state_test.dart`: the gallery fires from the unsupported page and appears on no other; the two listen tests become «offers no listening». The router wiring has no route-level test, like the camera's before it; T14 checks both on the phone. 398 analysis/app/localization tests pass |
| 8 | F23-T08 | Unsupported page | Option B (#5) built from failure widgets in `features/analysis/presentation/widgets/failure/`: the note chip, the text-entry card, the supported-documents grid. Tests: tiles and examples, chip, text card only with text and opening the text view, camera/gallery/home callbacks | DONE — `widgets/failure/`: `FailureNoteChip` (check + words in `successInk` on `successTint`), `ExtractedTextEntryCard` (a button to screen readers too — `InkWell` alone was not, a test caught it; the chevron mirrors in LTR), `SupportedDocumentsSection` (two `IntrinsicHeight` pairs + the wide «أوراق تانية» tile, `DocumentCategoryStyle` icons, each tile one semantics stop). The failure body gives the unsupported page the chip, `[text card if text, papers]` and camera + gallery paired (glyphs), home as the quiet action; with neither capture route, home leads and is not repeated. The T07 interim (gallery as secondary, text as a button) is gone. Tests: 8 in `failure_widgets_test.dart`, 8 more in `service_state_test.dart` (chip, card above papers, card opens the text, pair layout + both callbacks — mutation-checked by unpairing, no text button, home-only fallback, no card without text, 2.0× on 320 × 568 in both languages). Full suites: 1159 pass |
| 9 | F23-T09 | No-internet page | #6 with the step tracker (#10) and the tips card. Tests: steps and their semantics label, tips, retry/text/home actions, no «متحسبتش» line | DONE — `widgets/failure/analysis_steps_card.dart` (`AnalysisStepsCard(explanation: ExplanationStep.waiting / failed)`: three `Expanded` steps and two connectors so the words wrap under Large Text; done = check on `successTint`, the explanation = clock or warning on `warningTint`; one `Semantics` sentence over `ExcludeSemantics`) and `failure_tips_card.dart` (`FailureTipsCard(title, tips)`, `FailureTip(glyph, text, tone: teal / amber)`, the title a heading), both shared with T10/T11. The no-internet page shows the tracker (waiting) and the three tips. Tests: 6 widget tests (glyph order, failed variant, right-to-left order, one sentence — strengthened after a mutation, swapping `ExcludeSemantics` for `MergeSemantics`, first slipped past it — 2.0× on 320 × 568, tips heading/icons/tones) and 5 page tests (tracker waiting + its sentence, tips under it, no «متحسبتش» chip, retry/text/home and no capture actions, 2.0× in both languages). Full suites: 1170 pass |
| 10 | F23-T10 | Daily-limit page | #7 with the countdown card (#14, #15). Tests with a fixed clock: the countdown text, the minute refresh, «اتجددت» at the reset, pill and dots with a limit, no number and no pill without one | DONE — `widgets/failure/limit_reset_card.dart` (`LimitResetCard(resetAt, dailyLimit?, now)`): one `Timer` set to fire exactly when the rounded-up minute changes, re-armed on each tick and cancelled on dispose, none once renewed; past the reset it reads «تحليلاتك اتجددت خلاص»; the pill draws one dot per analysis up to 10 (decorative, excluded from semantics), words only above that, nothing without a limit. The page's message names the limit when the cubit carried one; content = the card (from the failure's `resetAtCairo`) + «تقدر تعمل إيه دلوقتي؟» (the read-and-copy tip only when there is text, the lightbulb tip in amber). Tests: 10 widget tests with an injected clock (the countdown, rounding up, the exact minute change and the renewal — both mutation-checked against a loose one-minute timer —, already renewed, dots, no dots above 10, no pill, timer stopped on removal, 2.0× on 320 × 568) and 4 page tests (the failure's reset reaches the card, tips under it, the limit named from a seeded cache, 2.0× in both languages). Full suites: 1184 pass |
| 11 | F23-T11 | Service-problem page | #8 with the tracker (failed) and its tips card. Tests: steps, tips, actions | TODO |
| 12 | F23-T12 | Consent page | #9 with the value tiles and the privacy note. Tests: tiles, the exact privacy wording, settings/text/home actions | TODO |
| 13 | F23-T13 | Quality gate | `dart format .`, `flutter analyze` (no new issues; the three WIP warnings gone), `flutter test`; RTL and 2.0× text on every page; `/flutter-code-review`; `@code-reviewer` offered | TODO |
| 14 | F23-T14 | Device pass | The owner on the phone: all five pages, TalkBack, Large Text, camera and gallery from the unsupported page | TODO |

## Exit DoD

Each of the five failure pages sits under the teal bar, says plainly what
happened and what still works, and offers a way forward that matches the
approved mockups (with the two truthfulness amendments in #6). The reminder
and saved-paper «not found» pages share the new layout. Nothing outside the
presentation layer changed except the cubit's cached-limit read. `dart format
.`, `flutter analyze` and `flutter test` all pass.
