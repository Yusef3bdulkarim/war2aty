# F12-T02 — RTL audit (Arabic layouts correct throughout)

Full-app sweep against the one acceptance criterion: Arabic (RTL) layouts
render correctly throughout. Method: grep sweeps across `lib/` for every
non-directional layout API that can silently break under RTL —
`Icons.arrow_*`/`chevron_*`/`keyboard_arrow_*`, `Alignment.*Left/Right`,
`Positioned(left:/right:)`, `EdgeInsets.fromLTRB`/`.only(left:/right:)`,
hardcoded `TextDirection`/`TextAlign.left/right`, custom page transitions,
and `Dismissible` swipe directions — followed by reading every hit in
context to classify it as a real bug, a deliberate non-mirrored exception
(a physical/decorative element), or a design question. `flutter test`'s
`pumpApp` helper already defaults to the Arabic locale
([`test/support/pump_app.dart`](../../test/support/pump_app.dart)), so most
existing widget tests already exercise RTL layout without having been
written with that in mind — a real head start that this audit built on top
of rather than from scratch.

## Fixed

**`PulsingDots`** (the splash screen's three-dot launch indicator,
[`pulsing_dots.dart`](../../lib/features/bootstrap/presentation/widgets/pulsing_dots.dart)) —
spaced its dots with `EdgeInsets.only(right: i == 2 ? 0 : 8)`, a literal
physical-right inset. `Row` mirrors its children under RTL (the app's
default locale), but `EdgeInsets.only(right:)` does not follow it: the gap
ends up stranded at the row's far edge instead of between dots, leaving two
of the three dots touching. Changed to
`EdgeInsetsDirectional.only(end: i == 2 ? 0 : 8)`, which resolves to the
correct physical side under either direction. Covered by
[`test/features/bootstrap/pulsing_dots_test.dart`](../../test/features/bootstrap/pulsing_dots_test.dart),
which renders the widget under the default (Arabic/RTL) locale and asserts
the gaps between the three dots are equal — verified to fail (9px vs 17px)
against the old code before the fix, and pass after.

## Checked, no change needed

- **Back/close icons** — every top-bar back button already reads
  `Directionality.of(context) == TextDirection.ltr` and wraps its arrow in
  `Transform.flip` (`TopBarIconButton` call sites in
  `extracted_text_only_view.dart`, `analysis_result_screen.dart`,
  `document_details_screen.dart`, `reminder_form_screen.dart`,
  `reminder_details_screen.dart`, plus the same pattern in
  `service_state_view.dart`) — correctly mirrored already, predating this
  audit.
- **`EdgeInsets.fromLTRB`** — 51 call sites across 40 files, all read.
  Every one passes the same value for `left` and `right` (e.g.
  `fromLTRB(_pageSide, _pageTop, _pageSide, _pageBottom)`), used only as a
  shorthand for "same horizontal inset, different vertical insets" — never
  as a way to give one side more padding than the other. Mirroring makes no
  visible difference to any of them, so none is an RTL bug. (Using
  `EdgeInsets.symmetric(horizontal:)` combined with top/bottom would read
  more intentionally, but that's a style cleanup, not a correctness fix —
  left alone here as out of scope.)
- **`EdgeInsets.only(left:/right:)`** outside the fixed case — two more
  hits (`scaffold_with_nav_bar.dart`, `document_note_card.dart`), both
  symmetric (`left: x, right: x`) for the same reason as above.
- **`Alignment`/`Positioned` in decorative illustrations** —
  `documents_empty_state.dart`, `home_empty_state.dart` (two overlapping
  "paper + camera" illustrations transcribed pixel-for-pixel from
  `Waraqti.dc.html`, per each file's own `// From Waraqti.dc.html →` header
  comment) and `viewfinder_frame.dart`/`crop_frame.dart` (the camera
  capture screen's four corner brackets) all use literal
  `Alignment.topLeft`/`Positioned(left:, right:)`. All four are physical
  compositions — a paper-and-camera graphic, a camera viewfinder overlay —
  that represent something in the physical world, not text or reading
  order; per CLAUDE.md the approved design is matched precisely and isn't
  redesigned unilaterally. Mirroring these would deviate from the approved
  design without the design itself calling for it. Same reasoning as
  F12-T01's `rotate_right` capture-screen icon.
- **`camera_capture_screen.dart`** already uses `AlignmentDirectional
  .centerStart` for its one non-decorative, direction-sensitive overlay
  (the permission hint row) — confirms RTL was already a deliberate
  consideration in this screen, not an oversight.
- **Localization plumbing** — `AppLocalizations.delegates` includes
  `GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations`, and
  `GlobalCupertinoLocalizations` alongside the app's own strings delegate,
  so the native `showDatePicker`/`showTimePicker` dialogs used by
  `snooze_sheet.dart`, `reminder_date_time_pickers.dart`, and
  `alert_offset_picker_sheet.dart` already localize and mirror correctly
  for Arabic — nothing app-specific to fix.
- **No hardcoded direction overrides found** — zero hits for
  `TextDirection.ltr`, `TextAlign.left`/`.right`, or a `Directionality`
  override anywhere outside the already-correct back-icon mirroring above;
  zero custom page transitions or `Dismissible` swipe widgets that would
  need direction-awareness of their own.

## Flagged for design (not resolved here)

- **`audio_options_sheet.dart`'s rewind/fast-forward skip buttons**
  (`Icons.fast_rewind_rounded` / `Icons.fast_forward_rounded`) are not
  mirrored under RTL. Media transport controls conventionally stay fixed
  regardless of interface direction (they represent a position in time, not
  a reading direction) — the same convention every video/audio player
  follows — so this is left as-is rather than changed unilaterally. Noted
  here in case design has a different intent for it.

## Addendum — extended over F11-T09..T12 (post-merge)

Same reason as F12-T01's addendum: F11-T09..T12 landed on `develop` after
this audit first ran, then `feature/hardening` was rebased on top. Re-swept
the same files for literal `EdgeInsets.only(left:/right:)`,
`Positioned(left:/right:)`, hardcoded `TextDirection`/`TextAlign.left/right`,
and directional icons.

**Checked, no change needed**: `settings_section.dart`, `settings_screen.dart`'s
new sections, `destructive_confirm_sheet.dart`, and `privacy_policy_content.dart`
use only symmetric `EdgeInsets`/`.fromLTRB` (equal left/right) or
`TextAlign.center`. `privacy_policy_screen.dart`'s top bar already checks
`Directionality.of(context) == TextDirection.ltr` and mirrors its back arrow
via `Transform.flip` — the same correct pattern this audit already found
everywhere else, present here from the start rather than a gap.

## Out of scope (deferred)

- Golden-image visual regression tests — no existing golden-test setup in
  the repo (same gap noted in F12-T01).
- A real-device manual pass toggling Settings → Language across every
  screen — this audit is a code-level sweep; the device pass belongs to the
  Exit DoD's "real-device pass on Android + iOS" line, not this task.
- Restyling the 51 symmetric `EdgeInsets.fromLTRB` call sites to
  `.symmetric(horizontal:)` — a style cleanup with no behavioral effect,
  not an RTL correctness issue.
