# F12-T01 — Accessibility audit (semantics, tap targets, contrast)

Full-app sweep against the three acceptance criteria: semantics, tap targets,
contrast. Method: every interactive control that Flutter does **not** already
give a correct default accessible name to — icon-only `IconButton`s and raw
`InkWell`/`GestureDetector` wrappers (46 call sites, enumerated with
`grep -rn` across `lib/`) — was read and checked by hand; `AppColors`' two
palettes were measured against the actual WCAG formula rather than assumed.
Widgets whose accessible name already comes for free (any `Text`,
`ElevatedButton`/`FilledButton`/`TextButton` with a text child) were left
alone — adding `Semantics` there would be redundant, not a fix.

## Contrast

New regression gate: [`test/core/theme/contrast_test.dart`](../../test/core/theme/contrast_test.dart).
Computes the real WCAG relative-luminance contrast ratio for every
text/background and status-ink/tint pair `AppColors` actually uses, for both
`AppColors.light` and `AppColors.highContrast`.

**`AppColors.highContrast`** passes every pair with margin (worst case
5.79:1, most 7–18:1) — the palette's own "targeting WCAG-AA" doc comment
holds up.

**`AppColors.light`** passes every pair except two:

| Pair | Ratio | WCAG AA needs | Status |
|---|---|---|---|
| `textMuted` on `surface` | **2.76:1** | 3:1 (large text/UI) | ❌ fails even the large-text floor |
| `textCaption` on `surface` | **4.19:1** | 4.5:1 (normal text — `caption` renders at 13sp, below the 18pt/14pt-bold large-text exception) | ❌ fails by a smaller margin |

Both are used widely (`textMuted` in 27 files, mostly hint text, muted
icons, and placeholder copy; `textCaption` in captions/timestamps
throughout). Per CLAUDE.md, `AppColors.light`'s hex values are sourced
exactly from the approved `Waraqti.dc.html` design and are not edited
unilaterally here. Both ratios are pinned in `contrast_test.dart` as a
**floor** (`KNOWN GAP` tests) — the values are documented, not silently
patched: the pin fails loudly if a future change makes either ratio worse,
and the test comments say to update it (as progress, not a break) if the
token is ever deepened.

**Recommendation for design**: darken `textMuted` and/or `textCaption` in
the light palette, or restrict `textMuted`'s use to non-text decorative
icons only.

## Tap targets

Found: a `SizedBox.square(dimension: 40, child: IconButton(...))` top-bar
back/close button, hand-duplicated across 6 files, all under the 48dp
Material/WCAG 2.5.5 minimum.

**Fixed**: extracted [`TopBarIconButton`](../../lib/core/widgets/top_bar_icon_button.dart)
(48dp, `core/widgets/`) and migrated the 5 plain-row usages to it:
`analysis_result_screen.dart`, `extracted_text_only_view.dart`,
`reminder_form_screen.dart`, `reminder_details_screen.dart`,
`document_details_screen.dart` (this file's trailing overflow-menu slot —
a `PopupMenuButton`, not an `IconButton` — was bumped to the same 48dp via
`TopBarIconButton.dimension` rather than forced through the shared widget).
`service_state_view.dart`'s back button sits in a floating circular card, a
different shape — its local `_backButton` constant was bumped 40→48
directly rather than folded into the shared widget. Covered by
[`test/core/widgets/top_bar_icon_button_test.dart`](../../test/core/widgets/top_bar_icon_button_test.dart).

**Checked, no change needed**: every other button size in the app (56dp
`PrimaryCta`, 52dp `ResultActionBar`/capture screens, 48dp full-width
`TextButton`s). `audio_mini_player_bar.dart`'s own circular icon controls
(the 42dp play/pause toggle, the 34dp stop button) already carry tooltips
and were left alone — a compact floating bar is accepted design intent, not
a gap. Four inline text links deliberately shrink below 48dp — the
"خيارات" options link in `audio_mini_player_bar.dart`, and one row each in
`recent_documents_strip.dart`, `reminder_alert_list_section.dart`,
`document_note_card.dart` — a standard Material pattern for inline text
links; spacing from neighboring targets was spot-checked and found
adequate.

## Semantics

Walked all 46 `IconButton`/`InkWell`/`GestureDetector` call sites. Most
already do this correctly — `Semantics(button:, label:, excludeSemantics:
true, ...)` around a card row, or a `tooltip:` on an icon button — matching
patterns already established in `recent_documents_strip.dart`,
`document_list_item.dart`, `category_picker_sheet.dart`,
`documents_category_filter_chips.dart`, `expandable_panel.dart`,
`camera_capture_screen.dart`, `image_preview_screen.dart`, and
`reminders_list_screen.dart`. Two genuine gaps found, both the same shape:
a selectable option row where the **selected** state is conveyed only by
border/fill color (no icon, no text change) — invisible to a screen reader
even though the option's own label reads fine.

**Fixed** — added `Semantics(button: true, selected: selected, label: ...,
excludeSemantics: true, ...)`, matching the pattern already used correctly
elsewhere in the app:
- `settings_screen.dart` — the language, processing-mode, and text-size
  option rows (`_RadioOption`, `_TextSizeOption`, `_ModeOption`).
- `save_mode_sheet.dart` — the save-mode option row (`_ModeOption`).
- `audio_options_sheet.dart` — the speed pill and reading-mode option
  (`_SpeedPill`, `_ModeOption`).
- `audio_options_sheet.dart`'s `_SkipButton` (permanently-disabled
  rewind/forward placeholders, `onPressed: null`) — wrapped in
  `ExcludeSemantics` instead of labeled: a control that can never fire has
  nothing useful to announce, the same call `camera_permission_sheet.dart`'s
  dismiss-scrim already makes.

Covered by new/extended widget tests in `settings_screen_test.dart`,
`save_mode_sheet_test.dart`, and `audio_options_sheet_test.dart` (search
`F12-T01` in each).

**A note on scope**: the task file's per-feature `Semantics(` grep count
suggested `audio_reader`, `ocr`, and `onboarding` had zero coverage. In
practice this overstated the risk — those features' actual interactive UI
mostly lives in shared `core/widgets/` files (already covered above) or
uses plain `ElevatedButton`/`FilledButton`/`TextButton` with a text child,
which Flutter already exposes correctly with no `Semantics` wrapper needed.
The enumerable-call-site method above (not a per-feature file count) is the
one that found the real gaps.

## Addendum — extended over F11-T09..T12 (post-merge)

This audit originally ran against `develop` while `feature/settings` still had
F11-T09..T12 (notification permission, notification-privacy toggle,
delete-all, about/privacy-policy) sitting unmerged — those sections did not
exist yet and so were not swept. Once that work landed and `feature/hardening`
was rebased on top, the same method (enumerate every `IconButton`/`InkWell`/
`GestureDetector`, `SizedBox.square` tap target, and selection-by-color-only
row) was re-run against every file that PR touched.

**Fixed**: `privacy_policy_screen.dart`'s `_TopBar` — new in F11-T12, built
before this migration existed, so it still had the hand-duplicated
`SizedBox.square(dimension: 40, child: IconButton(...))` shape this audit
already replaced everywhere else. Migrated to
[`TopBarIconButton`](../../lib/core/widgets/top_bar_icon_button.dart) like
the rest.

**Checked, no change needed**: `settings_section.dart`'s new/reused rows
(`SettingsStatusRow`, `SettingsLinkRow`, `SettingsNavRow`,
`SettingsToggleRow`), `destructive_confirm_sheet.dart` (standard
`FilledButton`/`OutlinedButton`, 50dp), and `privacy_policy_content.dart` —
none introduce a new selectable-by-color-only state; the genuine gap category
this audit found (radio-style option rows) doesn't recur here.

## Out of scope (deferred)

- Golden-image visual regression tests — no existing golden-test setup in
  the repo.
- A custom accessibility lint rule/package — none currently in `pubspec.yaml`.
- Design sign-off on the two contrast gaps above — flagged for design, not
  resolved here.
