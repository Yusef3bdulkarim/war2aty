# F12-T03 — LTR audit (English layouts correct throughout)

Full-app sweep against the one acceptance criterion: English (LTR) layouts
render correctly throughout. The app is Arabic/RTL by default (CLAUDE.md),
but ships a real English locale switch (`Settings → عام → اللغة`, F11-T04) —
so "LTR" here means the interface itself running left-to-right, not just
Latin text appearing inside an Arabic layout.

Method: the same grep sweep [F12-T02](F12-T02-rtl-audit.md) ran — every
non-directional layout API that can silently break under a direction change
(`Icons.arrow_*`/`chevron_*`, `Alignment.*Left/Right`, `Positioned(left:/
right:)`, `EdgeInsets.only(left:/right:)`, hardcoded `TextDirection`/
`TextAlign.left/right`, custom page transitions, `Dismissible` directions) —
re-run and re-read with the opposite question: does this still hold when
`Directionality` flips to `ltr`? Plus two sweeps specific to a real language
switch that a pure RTL-vs-decorative read wouldn't catch: every
`Directionality.of(context) == TextDirection.ltr`/`== TextDirection.rtl`
conditional in `lib/`, and every place a locale is branched on
(`languageCode == 'ar'`) to make sure the `en` side of each branch is real,
not a stub.

## Checked, no change needed

- **The directional-icon mirror pattern** — nine call sites across the app
  draw a chevron/arrow once for the design's Arabic default and flip it by
  hand when `Directionality` is left-to-right:
  `Transform.flip(flipX: Directionality.of(context) == TextDirection.ltr, …)`
  around a `StrokeIcon(StrokeGlyph.arrowBack)` or `.chevronForward`. Present
  in `service_state_view.dart`, `extracted_text_only_view.dart`,
  `analysis_result_screen.dart`, `reminder_form_screen.dart`,
  `document_details_screen.dart`, `reminder_details_screen.dart` (its own top
  bar *and* the linked-document row's chevron — two sites), `privacy_policy_
  screen.dart`, and `scan_actions.dart` (its own `isRtl`-named variant of the
  same logic). All nine read the same way and flip the same way — verified
  correct, not just present, by reading each one against
  `StrokeGlyph.arrowBack`'s own doc comment ("drawn once for the design's
  Arabic default; mirror it for LTR") in `stroke_icon.dart`.
- **The language switch itself** (`settings_screen.dart`'s `_LanguageSection`
  / `_LanguageSheet`, F11-T04) — reads `LocaleCubit` directly, writes through
  `SetLocale`, and `WaraqtiApp` rebuilds `MaterialApp`'s `locale:` from that
  cubit's state on every change (`app.dart`). Direction follows the locale
  automatically; nothing in the app pins `TextDirection` by hand anywhere
  outside the nine mirror sites above (zero hits for a `Directionality`
  override, a hardcoded `TextDirection.ltr`/`.rtl`, or `TextAlign.left`/
  `.right`).
- **Translation completeness is a compile-time guarantee, not a runtime
  risk** — `AppStrings` (`app_strings.dart`) is an `abstract interface
  class`; `EnStrings` and `ArStrings` both `implement` it. A getter present
  in one and missing in the other fails the build, not a screen at runtime —
  so there is no missing-English-string class of bug to sweep for here (by
  construction, unlike the two contrast/tap-target gaps F12-T01 had to
  actually measure).
- **`EdgeInsets.fromLTRB` and `Alignment`/`Positioned` in decorative
  illustrations** — the same call sites F12-T02 read and classified (the
  paper-and-camera empty-state graphics, the camera viewfinder/crop corners,
  the 51+ symmetric `fromLTRB` paddings). Both classifications are
  direction-agnostic facts (a physical composition, or the same value on
  both sides of a padding call) — true under LTR for the identical reason
  they were true under RTL, so nothing here needed re-litigating.
- **Arabic-Indic digit handling** — the only two hits in `lib/`
  (`normalize_spoken_numbers.dart`, `text_normalizer.dart`) operate on
  *document* content read off the paper, which the project spec explicitly
  allows to be Arabic, English, or mixed regardless of the interface
  language — not on interface strings, so out of scope for an interface
  direction audit.
- **No hardcoded direction overrides, custom transitions, or swipe
  directions** — same zero-hit result as F12-T02 (no `textDirection:`
  argument passed to any widget, no custom `PageTransitionsBuilder`, no
  `Dismissible`/`DismissDirection` anywhere in `lib/`).

## Fixed

No production bug — every directional call site already behaves correctly
under English. What the sweep *did* find: of the nine mirror sites above,
only `scan_actions.dart`'s had a regression test actually asserting the
flip (`the chevron points along the reading direction`,
`scan_actions_test.dart`); the other eight were correct by inspection only,
with nothing to catch a future regression.

Closed that gap: added a `mirrorScaleX(tester, glyph)` test helper
([`test/support/mirrored_icon.dart`](../../test/support/mirrored_icon.dart))
— reads the horizontal scale off the `Transform` wrapping a given
`StrokeGlyph`'s icon — and used it to lock in the flip for the remaining
eight sites, pumping each screen under both locales:
`service_state_test.dart` (the state page's own back icon, plus
`ExtractedTextOnlyView` pumped standalone for its own), `analysis_result_
screen_test.dart`, `reminder_form_screen_test.dart` (also added the missing
`locale` parameter to its `pumpScreen` helper), `document_details_screen_
test.dart`, `reminder_details_screen_test.dart` (both its top-bar back icon
*and* the linked-document row's chevron — the latter previously untested in
any locale, so this also closes a plain coverage gap, not just an LTR one),
and `privacy_policy_screen_test.dart` (extended its existing "renders in
English, left-to-right" test rather than adding a new one). `scan_actions_
test.dart`'s own pre-existing check was refactored onto the shared helper
too, so the ancestor-lookup now lives in one place instead of nine.

## Flagged for cleanup (not resolved here)

- The nine mirror call sites duplicate the same four-line pattern
  (`Directionality` read + `Transform.flip`) by hand rather than sharing a
  widget — the production-code analogue of the test duplication above. No
  bug follows from it (all nine are correct today), so per CLAUDE.md's
  smallest-change rule this is left alone rather than unilaterally
  extracted; a `MirroredIcon`/`DirectionalIcon` widget in `core/widgets/`
  would be a reasonable follow-up if a tenth site appears.

## Out of scope (deferred)

- Golden-image visual regression tests — no existing golden-test setup in
  the repo (same gap F12-T01 and F12-T02 both noted).
- A real-device manual pass toggling `Settings → اللغة` across every screen
  — this audit is a code-level sweep; the device pass belongs to the Exit
  DoD's "real-device pass on Android + iOS" line, not this task.
- English string *wording* quality (tone, idiom) — this task audits layout
  correctness, not translation copy.
