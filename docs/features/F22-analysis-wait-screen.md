# F22 · Analysis Wait Screen

- **Branch:** `feature/analysis-wait-screen`, based on `develop` · **Milestone:** post-F21
- **Depends on:** F07 (the result screen and its `AnalysisProgressView`)
- **Progress:** 3 / 9 DONE
- **PR:** timing to be agreed with the owner once the tasks are done; base `develop`

The owner's redesign of the page shown while the analysis service works
(`AnalysisResultAnalyzing`), 2026-10-01. The old page — a teal gradient, a
sparkle, a title and a bar that eased towards 90% — is replaced by **C★, the
magnifier**: a paper drawing that a magnifying glass reads, right to left and
line by line, while a caption says what is being looked for.

Approved mockup (private canvas, frame «C★ · Magnifier, refined»):
https://claude.ai/artifact/SbAsqtURXgL96haaTg4Vx1. It is the design source for
this page; the Waraqti design is not updated by this feature. The owner
approved it in writing on 2026-10-01, after four rounds (concepts A–D → C →
C+ → C★).

**Presentation only.** The domain, data, the `AnalysisResultCubit` and its
states, and the Edge Functions are not touched. The screen stays fully
passive: no buttons, no touch response, no cancel.

## Locked decisions

1. **Scope is the analysis wait only** (`AnalysisResultAnalyzing`). The online
   reading wait gets its own, simpler animation later; it is not part of F22.
2. **The progress bar is removed completely**, with `_ApproachCurve`. Nothing
   on the page is a completion figure.
3. **The step text is timer-driven.** The server reports no stages, so the
   captions follow the clock. They never claim something was found: the
   lens's pauses are visual only (an outline, an underline, a glowing field),
   never a label such as "found a date".
4. **Pure Flutter.** One `Ticker` for continuous motion, one `CustomPainter`
   for the paper, drawn a second time inside the lens (clip → translate →
   scale ×1.7) for the magnification. No Lottie, no Rive, no new package.
5. **The timeline is presentation code**, not Cubit state. Continuous motion
   comes from the ticker; discrete events (caption steps, the 10 s subline,
   the 15 s announcement) come from one-shot `Timer`s built from the same
   constants. Reduced motion runs no ticker at all.
6. **The lens path** (one pass = 5.75 s): the title (pause), three body lines
   (a pause on one word, which keeps a mint underline), the two boxed fields
   (a pause on each, its border glows), then back to the top. Moves ease in
   and out; the handle swings up to ±10° with the lens's sideways speed; a
   glint crosses the glass every 3.2 s. Words turn teal while within 12 px of
   the lens centre, then «read».
7. **Captions follow the lens, then the clock:**

   | From | Caption | Subline |
   |---|---|---|
   | 0 s | «بنشوف نوع الورقة...» | «خليك معانا، ده بياخد ثواني» |
   | 1.6 s | «بنشوف المطلوب منك...» | |
   | 3.9 s | «بندوّر على أي مواعيد...» | |
   | 6 s | «لسه ثواني، الورقة فيها تفاصيل كتير...» | |
   | 10 s | «بنراجع كل حاجة كويس علشانك...» | «مش محتاج تعمل حاجة، هنكمّل لوحدنا» |
   | 15 s | «بتاخد وقت أطول من العادي، لسه شغالين عليها...» | |
   | finish | «جاهز!» | «بنفتح لك الشرح دلوقتي» |

   The trailing dots pulse one after another (still under reduced motion).
8. **Long runs (up to the 25 s deadline):** from the second pass on, a small
   green check appears beside each part as the lens leaves it (title, each
   line, each field); every pass starts with the checks cleared. Past the
   deadline the existing failure page takes over, unchanged.
9. **Entrance:** the paper rises 12 px and fades in (400 ms); the lens grows
   from 0.6 and fades in (350 ms).
10. **Finish, ≈ 650 ms before `onFinished`:** the lens glides to the paper's
    centre, shrinks to half and fades (350 ms); a green check springs in at
    +120 ms (440 ms) with a ring spreading out (900 ms); the paper gets a green
    outline. If the result arrives early, the remaining steps are skipped —
    no delay is ever added to finish them.
11. **One haptic:** `HapticFeedback.lightImpact()`, exactly once, as the check
    appears. Only on success; never during the wait or on failure.
12. **Reduced motion:** the lens rests over the title and magnifies it; the
    title outline and the underline are already drawn; captions change with
    fades only. On finish the check appears without motion, the haptic fires,
    and `onFinished` follows a 500 ms still hold.
13. **Screen reader:** one polite announcement at the start, from a fixed
    live-region label («بنجهّز لك شرح الورقة، استنى ثواني»). The scene and the
    rotating captions are excluded from semantics. One more announcement at
    15 s («بتاخد وقت أطول من العادي») and one at finish («الشرح جاهز»).
14. **Large Text and small screens:** the caption block has a minimum height,
    not a fixed one, and wraps; the scene scales down to fit. No overflow at
    text scale 2.0 on 320 × 568.
15. **Colours come from `AppColors`.** The paper's greys map to existing
    tokens, each with a high-contrast value (T03) — no new tokens.
16. **Strings:** `analysisRunningTitle` and `analysisRunningMessage` are
    removed (the page has no title any more); `analysisRunningStatus` stays
    as the start announcement with the copy above. None of the new strings
    names a provider or claims who sees the text (`app_strings_test`).
17. **`AnalysisProgressView` keeps its API** (`finishing`, `onFinished`), so
    `_FinishProgressFirst` in the result screen is unchanged.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F22-T01 | Task file | This file and the README row, from the owner's decisions of 2026-10-01 | DONE |
| 2 | F22-T02 | Lens timeline and paper geometry | Pure Dart `lens_timeline.dart`: the waypoints, `lensAt(t)` with easing, `stepAt(elapsed)`, pass helpers, review-check times, each word's `readAt`. `paper_layout.dart`: the paper's geometry (moved here from T03, because `readAt` and the checks need it). Tests: exact positions at waypoints and pauses, wrap across passes, monotone moves, every step boundary, `readAt` order, checks only from the second pass | DONE — `LensTimeline` (abstract final, plain seconds): the 16-waypoint path (pass 5.75 s) with a cubic ease-in-out between points, `restingPoint`/`centre`, the title/key-word/field beats, six `ReviewCheck`s, `stepStarts` [0, 1.6, 3.9, 6, 10, 15], the entrance/finish/glint/handle constants, `passOf`/`timeInPass`, `handleSwingAt`, and `wordReadAt` (closest approach sampled every 10 ms, computed once). `PaperLayout`: 260 × 340, logo, title and its outline, subtitle, divider, two `PaperField`s, footer, and 14 `PaperWord`s (three right-to-left lines of four, one `isKey`, then the two field values). 23 tests in `test/features/analysis/presentation/reading_lens/lens_timeline_test.dart` |
| 3 | F22-T03 | Paper frame and painting | `paper_frame.dart`: a pure `PaperFrame.at(seconds)` for every reaction on the paper, plus `resting` (reduced motion) and `finished`. `paper_painting.dart`: the stack and the content, drawn in paper units; the magnified pass reuses `paintContent`. Colours from `AppColors` in both palettes | DONE — `PaperFrame`: per-word `wordLit` (smoothstep, full within 8, none past 16 paper units) and `wordRead`, `titleLit`, `titleOutline` (0.35 s), `keyUnderline` (0.42 s), per-field glow around its pause and `fieldVisited`, per-check amounts (pop 0.32 s from the second pass, fade out over the first 0.25 s of the next). `PaperPainting`: `paintStack` (two tilted sheets, shadows, the paper, the green finish ring), `paintContent`, `paintChecks`, `paintCheckDisc` (shared with the finish check), `easeOutBack`/`easeOutCubic`. **No new colour tokens** — every paper colour maps to an existing one with a high-contrast value (unread `border`, read `iconMuted`, label `borderStrong`, footer/divider `borderSoft`, sheets `bgBase`/`surfaceAlt`, title `textSecondary`), which amends #15. The `CustomPainter` itself is composed in T04, with the lens. 15 tests in `paper_frame_test.dart` |
| 4 | F22-T04 | Lens scene | `reading_lens_scene.dart`: one ticker, repaint through `repaint:` (no per-frame `setState`), `RepaintBoundary`; entrance, path, handle swing, glint, review checks, finish sequence. Tests with a fake clock: lens position at set times, ticker disposed, finish reported once, none after removal | TODO |
| 5 | F22-T05 | Captions and strings | `wait_caption.dart` (caption, subline, pulsing dots) rebuilt only on a step change. All strings added in `AppStrings`/`ar`/`en` and the `app_strings_test` map; the two old ones removed. Tests: caption at each boundary, subline at 10 s, dots still under reduced motion | TODO |
| 6 | F22-T06 | Progress view rewrite | `AnalysisProgressView` builds the scene and the captions; semantics, haptic, reduced-motion path; the bar deleted. Tests: haptic exactly once and only on finish; announcements once each; reduced motion schedules no frames and still finishes; no overflow at 2.0× on 320 × 568; RTL | TODO |
| 7 | F22-T07 | Screen tests | `analysis_result_screen_test` and `analysis_progress_view_test` updated. «Finish before the result» and «failure replaces the page at once» still pass, mutation-checked | TODO |
| 8 | F22-T08 | Quality gate | `dart format .`, `flutter analyze` (no new issues), `flutter test`; `/flutter-code-review`; `@code-reviewer` offered | TODO |
| 9 | F22-T09 | Device pass | The owner on the phone: smoothness (DevTools, no dropped frames), TalkBack, the haptic, 2.0× text, a 22 s run | TODO |

## Exit DoD

While a paper is analysed, the magnifier reads it and the caption says what is
being looked for; long runs keep changing and never look stuck; the result
arrives with one check and one haptic. Reduced motion and TalkBack get a calm,
complete version of the same page. Nothing outside the analysis presentation
layer (plus its strings and colour tokens) changed. `dart format .`,
`flutter analyze` and `flutter test` all pass.
