# F12-T04 — Large-text pass (no overflow at largest text size)

Full-app sweep against the one acceptance criterion: no overflow at the
largest text size. "Largest" is a concrete, already-built app setting —
`TextSize.veryLarge` in
[`text_size.dart`](../../lib/core/accessibility/text_size.dart) applies
`TextScaler.linear(1.5)` to the whole tree via a `MediaQuery` wrap in
`app.dart`'s `_appBuilder`.

Method: grep every layout shape that can silently overflow under scale —
fixed-height containers wrapping text (`SizedBox(height:`, `.square`,
`BoxConstraints(...maxHeight`), `Row`s with two or more `Text`/`Icon`
children not wrapped in `Expanded`/`Flexible`, fixed-width chip/pill
containers, and every `maxLines`/`overflow: ellipsis` truncation — each hit
read in context and classified, matching T01–T03's method.

**A method finding that shaped the rest of this task**: the established
"large text" test idiom in this suite —
[`pumpApp(..., textScaler: TextScaler.linear(2))`](../../test/support/pump_app.dart)
plus `expect(tester.takeException(), isNull)` — only catches `RenderFlex`
overflow (a `Row`/`Column` whose children don't fit the main axis). It does
**not** catch a `Text` silently clipping inside a fixed-height `SizedBox` or
button: no `Flex` assertion fires there, because Flutter's box protocol
clamps a `RenderParagraph`'s own *reported* size down to whatever height
it's given (`size = constraints.constrain(textSize)`), whether or not the
content actually fit. Confirmed the hard way while writing this task's own
tests: an initial `tester.getSize(find.text(...))` assertion passed against
genuinely broken pre-fix code, because the label being measured was itself
the thing silently clamped. The fix used throughout below: read the label's
render object's own `getMaxIntrinsicHeight()` — the content's true height,
independent of the constraint it was actually laid out with — instead of
`getSize()`. Every new test in this task was verified red against the
pre-fix source and green after, specifically because of this trap (same
discipline T02's `pulsing_dots_test.dart` used).

## Fixed

**`reminder_details_screen.dart`'s `_ActionButton`** — the «تم التنفيذ»/
«تأجيل» (complete/snooze) buttons sat in `SizedBox(height: _actionHeight,
child: FilledButton(...))`, no `maxLines`. Its sibling widget,
`reminder_list_item.dart`'s `_ActionChip`, draws the identical two labels
and had already fixed this exact shape: a `minimumSize` on the button's own
style rather than an outer fixed-height box, so the button is free to grow.
Applied the same fix here. At `TextScaler.linear(2)` the label needs 135px;
the old fixed box gave it 52 — confirmed failing before the fix, passing
after, in
[`reminder_details_screen_test.dart`](../../test/features/reminders/reminder_details_screen_test.dart)'s
extended `'survives large text without overflowing'` test.

**`documents_category_filter_chips.dart`'s `_Chip` row** — the whole
horizontal chip strip sat in a `SizedBox(height: 34)` with the chip's own
vertical padding commented out and no `maxLines` on the label. At
`bodySmall` (14sp, line-height 1.6) scaled 1.5x a single line is ≈33.6px
against a 34dp box with zero vertical padding — already at the pixel budget
before font ascent/descent overshoot. Fixed by scaling the box's own height
with the text scaler (`MediaQuery.textScalerOf(context).scale(_height)`)
instead of leaving it fixed — preserves the exact same visual buffer ratio
at every scale rather than guessing a new constant. (A `Wrap`/
`IntrinsicHeight` swap was considered and rejected: `ListView.separated`
needs a genuinely bounded cross-axis extent from its parent to lay out a
horizontal scroll at all, and `IntrinsicHeight` doesn't work with a
`Viewport` — it asserts. Scaling the existing bound is the smaller, correct
fix.) Also added `maxLines: 1, overflow: TextOverflow.ellipsis` to the
label as a safety net. This widget had no test file before this task —
added
[`documents_category_filter_chips_test.dart`](../../test/features/saved_papers/documents_category_filter_chips_test.dart)
with basic render/interaction/semantics coverage plus the large-text
regression (confirmed failing pre-fix at 45px needed vs. 34px available,
passing after).

**`reminder_event_info_card.dart`'s `_Row`** (defensive) — the trailing
date/time value `Text` sat bare in a `Row` next to an `Expanded` label,
unlike every other label+value row in the codebase (`SettingsValueRow`
nests both in one `Expanded Column`). Not proven broken — content is short,
formatted dates/times — but wrapped the value in `Flexible` with
`TextOverflow.ellipsis` to match the established-safe pattern, since the
fix is one line and the alternative is a latent gap with no fallback.
Added a large-text case to
[`reminder_event_info_card_test.dart`](../../test/features/reminders/reminder_event_info_card_test.dart)
(previously zero `textScaler` coverage).

## Checked, no change needed

- **Bottom nav** (`scaffold_with_nav_bar.dart`) — the reference-correct
  pattern for this whole sweep: four `Expanded` destinations (*"four
  fixed-width destinations cannot fit a scaled-up label, and would overflow
  the row"*), the label's own `TextScaler` explicitly clamped
  (`.clamp(1, 1.3)`) with `maxLines: 1, overflow: ellipsis`, and the
  untruncated label still reaches screen readers through the `Semantics`
  node above it — deliberate, not a gap. Covered by
  `test/app/nav_bar_test.dart`'s `'fits four destinations at the largest
  text size'`.
- **`core/widgets/result_*.dart`** (every result card, `result_action_bar
  .dart`, `result_dates_card.dart`'s `_DateRow`/`_DayTile`) — every
  label/value `Text` in a `Row` is already `Expanded`/`Flexible`; the one
  fixed box (`_DayTile`) uses `BoxConstraints(minWidth/minHeight:)` — a
  minimum, already the correct shape. All have a passing large-text test.
- **`reminder_list_item.dart`**, **`value_caveat.dart`**,
  **`caveat_badge.dart`** — every `Text` in a `Row` already `Expanded`/
  `Flexible`; `_ActionChip` is the `minimumSize` pattern bug #1 above was
  brought in line with.
- **`recent_documents_strip.dart`/`document_list_item.dart`** — titles use
  `Wrap(spacing:, runSpacing:)` for the several short texts that might not
  all fit on one line, not a `Row` — safe regardless of scale by
  construction.
- **`audio_options_sheet.dart`'s `_SpeedPill` row** — no `Expanded`
  anywhere, which looks risky on paper, but `ReadingSpeed.label` values are
  locale-independent numeric literals (`"0.75x".."2x"`) — safe by content,
  not by layout. Confirmed by its own passing large-text test.
- **`settings_screen.dart`** — `SettingsValueRow`/`SettingsToggleRow` nest
  label and value in one `Expanded Column` (safe by construction);
  `SettingsStatusRow`'s trailing pill isn't wrapped but is tested against
  the fully-loaded state (real data, not the skeleton) at
  `TextScaler.linear(2)` and passes — a genuine `Row`-overflow proof, so
  classified safe.
- **`camera_permission_sheet.dart`'s `_SheetButton`**,
  **`primary_cta.dart`** — both already use the `minimumSize`-not-
  fixed-height pattern, with a comment saying so. The reference
  implementations bug #1 above was brought in line with.

## Flagged for cleanup (not resolved here)

- **Same `SizedBox(height: fixed)`-wraps-a-button shape as bug #1, but
  currently holding short static labels, so not proven broken today**:
  `destructive_confirm_sheet.dart`, `delete_reminder_sheet.dart`,
  `notification_permission_sheet.dart`, `note_editor_sheet.dart`,
  `title_editor_sheet.dart`, `save_mode_sheet.dart`, `document_note_card
  .dart`, `result_dates_card.dart`'s `_ReminderButton`, `reminder_success
  _screen.dart`, `reminder_form_screen.dart`'s `_SaveBar`,
  `service_state_view.dart`'s `_Action`, and `reminder_details_screen.dart`'s
  own delete button (`OutlinedButton`, full-width so lower risk than the
  half-width buttons fixed above — found while fixing bug #1, in the same
  file). None has a large-text test proving it safe. Recommend the same
  `minimumSize` migration as a follow-up rather than fixing unilaterally
  now — per project change discipline, a pattern that isn't proven broken
  for its current (short, static) content isn't blanket-rewritten across
  ~12 files in the same task that fixed the two proven cases.
- **`reminder_list_item.dart`'s title (`maxLines: 1`) vs.
  `recent_documents_strip.dart`'s title (`maxLines: 2`)** — the same kind of
  data (a reminder/document title) gets a different truncation budget in
  its two list-preview contexts. Not a bug, a design question: worth
  reconciling, not resolved here.
- **`reminder_list_item.dart`'s due-date/time line** (`maxLines: 1` +
  ellipsis) — the one truncation in this sweep that could hide genuinely
  actionable info (when the reminder is due) rather than just a label.
  Flagged for design, same as how T02 flagged the un-mirrored audio skip
  buttons instead of changing them unilaterally.

## Out of scope (deferred)

- The entire `features/ocr/presentation/widgets/` family (`field_review_
  sheet.dart`, `ocr_review_screen.dart`, `ocr_processing_screen.dart`,
  `candidate_chips.dart`) has zero test coverage at all, not just
  large-text — a pre-existing gap this task didn't create; noted for a
  future coverage pass rather than expanding scope here.
- Golden-image visual regression tests — no existing golden-test setup in
  the repo (same gap T01–T03 already noted).
- A real-device manual pass through Settings → حجم الخط at «كبير جدًا» —
  this audit is a code-level sweep; the device pass belongs to the Exit
  DoD's "real-device pass on Android + iOS" line, not this task.
