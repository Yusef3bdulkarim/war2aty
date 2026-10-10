# F29 · The reminders screen's empty space, and the empty-state shadows

- **Branch:** `feature/reminders-empty-state`, based on `feature/android-release` · **Milestone:** post-F28
- **Depends on:** F09 (the reminders list and the manual form this builds on), F25 (the notifications a quick reminder schedules), F27-T03 (Home's own empty-state redesign, the precedent for "fill the dead space")
- **Progress:** 8 / 14 · **T08 DONE**
- **PR:** one PR for both halves of this feature, into `feature/android-release` (the owner's call — F27 Phase 4 still batches its own PR separately)

Two requests from the owner on 2026-10-10, carried in one branch because they
are the same complaint about the same kind of screen — an empty state that
looks unfinished.

1. **The reminders screen's dead centre.** «التذكيرات» with nothing in it is a
   centred title and one line of grey text, 80 px down an otherwise blank
   page. The owner's words: *"an empty space in the middle of the screen…
   looks unprofessional and wastes central screen space."* The space has to
   earn its place.
2. **The empty-state illustrations' shadows.** The camera tile's teal glow and
   the paper sheet's grey drop shadow come off, on **both** «مستنداتي» and
   «الرئيسية». Nothing else on those two screens changes — same
   illustrations, same copy, same buttons.

## The design, and how it was chosen

Three concepts were drawn as a working HTML prototype at
[`docs/design/F29-reminders-empty-mockups.html`](../design/F29-reminders-empty-mockups.html)
— real `AppColors.light` / `AppRadii` / `AppTypography` values, the real
header, tabs and nav bar, with toggles for the three empty states and for text
scale 1×/1.3×/1.6×:

- **A** — «إزاي بيشتغل؟», a four-row numbered explainer.
- **C** — «التذكير بيعمل لك إيه؟», four value tiles.
- **D** — «تذكير سريع», three quick-date rows that open the form with the date
  already chosen.

The owner picked **D** on 2026-10-10. A and C stay in the prototype file as
the record of what was rejected; they are not to be revived without a new
decision.

This satisfies CLAUDE.md's "stop if no design exists for a screen" rule the
same way F28-T03 did: `Waraqti.dc.html` ships no comp for a populated
reminders empty state, so the prototype above **is** the approved design, and
the approval gate is the owner's pick of D.

## Locked decisions

Settled with the owner on 2026-10-10, in the questions that preceded the
prototype and in the pick itself.

1. **Concept D.** The empty space holds three quick-create rows — بكرة / بعد
   أسبوع / آخر الشهر — each opening the manual form with its date and time
   already filled in. Under them, a secondary «صوّر ورقة» button, and a hint
   line pointing back at the header's «إضافة تذكير» for a reminder entered
   from scratch.
2. **Scope includes the empty buckets.** «الفائتة» and «المكتملة» with nothing
   in them are redesigned too, not only the wholly-empty library. One visual
   vocabulary across all three, so القادمة/الفائتة/المكتملة never read as
   three different screens.
3. **The illustration carries no shadow.** A tilted paper (-7°) with a date
   chip and a brand bell resting on it. What lifts it off the page is a
   hairline `borderSoft` edge and a `surfaceTealAlt` ring around the bell —
   never a `BoxShadow`. This is the same rule as decision 8 below, applied to
   new art rather than old.
4. **New Arabic copy is allowed.** The owner approved adding keys to
   `AppStrings` (ar + en + the `app_strings_test` table). `reminderEmptyScanCta`
   («صوّر ورقة») already exists and has never been used by any screen — it
   finally gets its caller here.
5. **The tabs hide when the library is wholly empty**, and stay visible when
   only one bucket is empty. Three tabs that all lead to nothing are the main
   reason the current screen reads as broken; but a user looking at an empty
   «الفائتة» needs them to get back to «القادمة». *(Owner left this to
   judgement: "choose whichever approach is best.")*
6. **The content is top-anchored, not centred** — 24 px under the header,
   scrolling inside its own pane, with the existing 108 px bottom padding
   clearing the nav bar. Centring pushes the primary action below the fold on a
   small phone at 1.6× text scale. *(Owner left this to judgement.)*
7. **A quick row prefills the date and time only — never the title.** The user
   still types what the reminder is about; `canSave` requires a non-empty
   title ([`reminder_form_state.dart:71`](../../lib/features/reminders/presentation/cubit/reminder_form_state.dart#L71))
   and this feature does not weaken that. The honest claim is "one less step",
   not "one tap".
8. **The shadow removal takes both shadows, on both screens, and keeps the
   token.** Four `BoxShadow` sites come off: `AppShadows.paper` on the paper
   sheet and the hand-written teal glow `Color(0x4D0E7C86)` on the camera tile,
   in each of `home_empty_state.dart` and `documents_empty_state.dart`.
   `AppShadows.paper` stays in `app_shadows.dart` as a token even though
   nothing will reference it — the owner asked for it to be kept for future
   use, so its doc comment is updated to say it is currently unused rather
   than deleted.
9. **Nothing else on «مستنداتي» or «الرئيسية» changes.** The owner was
   explicit: *"I do not want any changes on the Documents screen other than
   removing the shadows — keep the illustrations and the button as they are."*
   No re-spacing, no recolouring, no copy edits.
10. **One PR for both halves**, into `feature/android-release`.

## The starting point, measured

What is on the branch today, so a reviewer can see exactly what moves.

| Thing | Where | State today |
|---|---|---|
| The empty-state body | [`reminders_list_screen.dart:357`](../../lib/features/reminders/presentation/screens/reminders_list_screen.dart#L357) `_EmptyState` | title + optional subtitle in a `SingleChildScrollView`, 80 px top pad, no art, no action |
| Wholly-empty library | same file, `_EmptyLibrary` | «مافيش تذكيرات لسه» + «اعمل تذكير يدوي، أو أنشئ تذكير من تاريخ موجود في ورقة.» |
| Empty bucket | same file, `_EmptyBucket` | one line of text, three variants, no way back to «القادمة» |
| The screen's callbacks | `RemindersListScreen` | `onAddReminder`, `onOpenReminder` only — no `onScan` |
| The manual form cubit | [`reminder_form_cubit.dart:65`](../../lib/features/reminders/presentation/cubit/reminder_form_cubit.dart#L65) | `ReminderFormEditing(title: '', isManual: true)` — starts **completely empty**, no way to seed a date |
| Its DI registration | [`service_locator.dart:912`](../../lib/app/di/service_locator.dart#L912) | `registerFactory` + `instanceName`, takes no parameters |
| Its route | [`app_router.dart:431`](../../lib/app/router/app_router.dart#L431) | `/reminders/manual`, ignores `state.extra` |
| `AppShadows.paper` users | `home_empty_state.dart:122`, `documents_empty_state.dart:143` | the only two callers in the app |
| The teal glow | `home_empty_state.dart:138`, `documents_empty_state.dart:186` | written inline in both, not a token |
| Tests pinning any of it | — | **none** pin a shadow; the reminders screen test pins the three empty titles only |

## Tasks

| # | ID | Task | Output | Status |
|---|---|---|---|---|
| 1 | F29-T01 | Feature doc, branch, index row | this doc; `feature/reminders-empty-state` cut from `feature/android-release`; `docs/features/README.md` row; the approved prototype committed | DONE 2026-10-10 |
| 2 | F29-T02 | **Shadows off** — the independent half | 4 `BoxShadow` sites removed; `AppShadows.paper` kept and marked unused; a mutation-proved test per screen, and «مستنداتي»'s art got its first test file at all — see "T02 record" | DONE 2026-10-10 |
| 3 | F29-T03 | The new strings | 8 new getters + 3 reworded, both languages, 13 `_accessors` rows; a new guard caught a quoted label that does not exist — see "T03 record" | DONE 2026-10-10 |
| 4 | F29-T04 | Quick-date arithmetic | `core/reminders/quick_reminder_date.dart`, 24 tests; end-of-month rolls forward once 09:00 passes, and the day is read off the real zone rather than the fixed +2 — see "T04 record" | DONE 2026-10-10 |
| 5 | F29-T05 | `ManualReminderSeed` + a seedable cubit | the seed model; `ReminderFormCubit.manual` takes an optional seed; **and a pre-existing stale-alert bug fixed**, found because the seeded form makes it the common case — see "T05 record" | DONE 2026-10-10 |
| 6 | F29-T06 | DI + route carry the seed | `registerFactoryParam<…, ManualReminderSeed?, void>`; `/reminders/manual` reads an **optional** `extra`; 3 router tests, the plumbing mutation-proved — see "T06 record" | DONE 2026-10-10 |
| 7 | F29-T07 | The illustration | `reminders_empty_art.dart` — paper + date chip + bell, no shadow, no text; 8 tests, the shadow and clipping ones mutation-proved — see "T07 record" | DONE 2026-10-10 |
| 8 | F29-T08 | The quick-create rows | `reminders_quick_create.dart` — three rows, callback-driven, no cubit knowledge; 10 tests, 1×/1.6×/2×-on-320, four mutations run — see "T08 record" | DONE 2026-10-10 |
| 9 | F29-T09 | The empty library assembled | `_EmptyLibrary` rebuilt: art + title + subtitle + kicker + quick rows + «صوّر ورقة» + hint; tabs hidden in this state only | TODO |
| 10 | F29-T10 | The two empty buckets | «الفائتة» as good news (success tint + tick), «المكتملة» as neutral (teal + check-square), both with a "back to القادمة" button that calls `setTab` | TODO |
| 11 | F29-T11 | `onScan` wired end to end | the new callback on `RemindersListScreen` → `AppRoutes.captureWith(CaptureSource.camera)`, mirroring the documents list's own wiring | TODO |
| 12 | F29-T12 | Screen tests | all three empty states, tabs hidden/shown, the quick rows' routing, 1.6× text, RTL + English, screen-reader labels | TODO |
| 13 | F29-T13 | Quality gate + reviews | `dart format` · `flutter analyze` · `flutter test`; then `/flutter-code-review`, then `@code-reviewer` | TODO |
| 14 | F29-T14 | Device pass, explanation, PR | RMX2001 (API 30) install and walk-through; `/explain-feature`; PR via `@git-expert` | TODO |

Tasks 2–4 touch nothing each other touches and could land in any order; 5 → 6
→ 8 → 9 is a hard chain (the seed must exist before a row can carry it, and
the rows before the state that holds them).

## The copy

Egyptian dialect, approved as part of concept D. Keys are added in T03 and
consumed from T09 on. `reminderEmptyTitle` and `reminderEmptySubtitle` already
exist; the subtitle's wording changes, because the old one describes the two
ways in rather than the quick rows now sitting under it.

| Key | عربي | English |
|---|---|---|
| `reminderEmptyTitle` *(kept)* | مافيش تذكيرات لسه | No reminders yet |
| `reminderEmptySubtitle` *(reworded)* | اختار ميعاد جاهز وابدأ على طول — تعدّله زي ما تحب بعد كده. | Pick a ready date and start right away — you can change it afterwards. |
| `reminderQuickCreateKicker` | تذكير سريع | Quick reminder |
| `reminderQuickTomorrow` | بكرة | Tomorrow |
| `reminderQuickNextWeek` | بعد أسبوع | In a week |
| `reminderQuickEndOfMonth` | آخر الشهر | End of the month |
| `reminderEmptyScanCta` *(kept, finally used)* | صوّر ورقة | Photograph a paper |
| `reminderEmptyScanHint` | أو اضغط «إضافة تذكير» فوق وحدّد كل حاجة بنفسك. | Or tap "Add reminder" above and set everything yourself. |
| `reminderEmptyMissedTitle` *(reworded)* | مفيش حاجة فاتتك | Nothing has slipped past you |
| `reminderEmptyMissedSubtitle` | كل تذكيراتك لسه في وقتها. لو فات ميعاد، هتلاقيه هنا. | Every reminder is still on time. If one is missed, it shows up here. |
| `reminderEmptyCompletedTitle` *(reworded)* | لسه مخلّصت ولا تذكير | You haven't finished a reminder yet |
| `reminderEmptyCompletedSubtitle` | أول ما تضغط «تم التنفيذ» على أي تذكير، هيتحرّك هنا. | As soon as you tap "Mark done" on a reminder, it moves here. |
| `reminderEmptyBackToUpcoming` | شوف التذكيرات القادمة | See upcoming reminders |

The quick rows' secondary line is the resolved date itself, built from the
existing `formatDocumentDate` + `formatWallClockTime` — not a new string.

## Rules this feature must not break

- **Architecture.** The quick-date arithmetic is domain-shaped and goes in
  `core/reminders/`, not in a widget. The screen gets callbacks; it never
  reaches a repository, a scheduler or `get_it` directly.
- **No `BoxShadow` in any empty-state illustration** — the new one included.
  That is the whole point of the second half of this feature.
- **Never colour alone.** Every state's colour is paired with an icon and a
  sentence («مفيش حاجة فاتتك» is green *and* says so).
- **RTL and Large Text.** Every new widget is checked at 1.6×; the quick rows
  were the concept chosen partly because they survive it best.
- **Cairo day.** Every date the quick rows produce goes through
  `core/time/cairo_day.dart`, like every other date in the app.
- **No new package.**

## T08 record (2026-10-10)

`RemindersQuickCreate` — the three rows from concept D's `.qbtn`: a teal
calendar box, the row's name over the date it resolves to, and a chevron.
Geometry and colours taken from the prototype.

**It is handed its slots, it does not fetch them.** `slots` is a required
argument and the only thing the widget draws; a tap goes back out through
`onSelected(slot)`. No cubit, no route, no `get_it`, and no `DateTime.now()`
inside `build` — which is what lets every date in its test be a literal
rather than a value recomputed by the code under test. T09 owns the single
clock read.

**The date line is `formatDocumentDate` + `formatWallClockTime`**, in exactly
the order and with exactly the separator `alertTimeLabel` uses — and exactly
what `reminder_date_time_pickers.dart` shows in the form the row opens, so the
date the user taps and the date they then see cannot read differently.

**Two deviations from the prototype, both deliberate:**

1. **No weekday name.** The prototype wrote «الخميس ١٦ أكتوبر — ٩:٠٠ ص». The
   app has no weekday names in either language, and the copy table settled
   this line as these two existing formatters rather than as new strings —
   seven more Arabic strings plus seven English ones for a word the date
   already implies.
2. **No `minHeight: 56`.** The icon box and the 13 px vertical padding put the
   row at ~65 px at 1×, so the prototype's `min-height` would never bind. It
   was written, measured with a mutation (`minHeight: 0`, test still green),
   and then **removed as dead weight** — the 56 px floor is asserted on the
   rendered height instead, where it catches the padding or the box being
   shrunk out from under it. The comment in the widget says so, so the next
   reader does not add the constraint back believing it does something.

**Tests** (10): the three names and the three dates; the tapped slot reported
**by value**; each row one screen-reader button labelled «بكرة. 16 أكتوبر
2026 — 9:00 صباحًا» (the house `excludeSemantics` pattern — two nodes per row
would make a user swipe twice to learn what it does); the calendar glyph
silent; English copy, date and chevron side; growth at 1.6×; wrapping at 2× on
a 320-wide phone; the 56 px floor; "draws what it is handed, in order"; and one
case through the **real** `quickReminderSlots`, so a slot kind the label switch
forgot cannot reach the screen as a blank row.

**Mutation-proved, four of them.** Every row wired to `slots.first` → only the
tap test failed. The merged semantics label removed → only the semantics test
failed. Two labels swapped in the switch → three tests failed, the pairing of
name to date being the property that actually matters. `Expanded` dropped from
the text column → a 105 px `RenderFlex` overflow, caught by the new 320 px /
2× case and **not** by the 1.6× one. That last one is why the narrow case
exists: at 1.6× on a 390-wide phone nothing wraps, so the test's original
"the date wraps" comment was an overstatement and was corrected rather than
left in the file.

Likewise the English test does not prove the chevron glyph *turns around* —
that is `ForwardChevron`'s own job. What it pins is that these rows go through
that shared widget instead of drawing the raw glyph, which is how four rows in
this app once ended up pointing backwards in English (F27-T15).

**Gate:** `dart format` clean · `flutter analyze` no issues in
`lib/features/reminders` or `test/features/reminders`, 18 project-wide and
unchanged from the baseline · `flutter test` 2,589 passing (2,579 + 10).
Nothing renders the rows yet; T09 places them and gives `onSelected` its
first real caller.

## T07 record (2026-10-10)

`RemindersEmptyArt` — a tilted paper (-7°) with three mock text lines, an
amber date chip, and a brand bell on the corner inside a pale
`surfaceTealAlt` ring. Geometry taken from concept D's small art in the
prototype.

**No `BoxShadow` anywhere**, per locked decision 3. The paper is separated
from the page by a hairline `borderSoft` edge and the bell by the ring — which
is what stands in for the teal glow T02 removed from the other two
illustrations. A third shadowed illustration would have undone half the
feature.

**Three deviations from the prototype, all deliberate:**

1. **The date chip holds a calendar glyph, not «١٥ / ١١».** The prototype
   wrote Arabic-Indic digits into the drawing. The whole art is
   `ExcludeSemantics`, so text in it is read by nobody and localized by
   nothing — and those digits would be wrong in English. A glyph says "there
   is a date on this paper" in either language. A test asserts the art
   contains no `Text` at all, so the shortcut cannot come back.
2. **The ring sits flush in the corner and the bell is inset**, rather than
   the ring hanging 5 px outside the box as the CSS had it. A `Stack` clips to
   its bounds, so the CSS arrangement would have lost two sides of the ring
   silently. The composition on screen is identical — the box is 5 px larger
   on those two sides and the bell inset by the same.
3. **Nothing animates.** Nothing asked for it, and a static drawing is the
   safer default on this screen.

**Tests** (8): no shadow in any decoration in the subtree; exactly three
borders, since those are what replaces the shadows; the semantics tree is
genuinely empty (asserted on the tree, not on the widget meant to produce it
— `StrokeIcon` adds `ExcludeSemantics` of its own, so counting widgets found
three and proved nothing); no `Text`; both glyphs present; everything inside
the box; the same composition in Arabic and English; and an unchanged size at
2× text, since nothing in it scales.

**Mutation-proved.** A shadow added to the bell fails the first test. The ring
moved back to a negative offset fails the bounds test. A third attempt —
shrinking the box back to 104×88 — did **not** fail it, because that moves the
ring without pushing it out; the test's comment was corrected to claim only
what it actually catches rather than leaving an overstatement in the file.

**One duplication, knowingly left.** `_lineDark`/`_lineLight` repeat the two
values `documents_empty_state.dart` holds privately for the same purpose.
Sharing them properly means lifting them into `core/`, which would edit that
file for something other than the shadow removal — locked decision 9. Noted
here rather than silently resolved either way.

**Gate:** `dart format` clean · `flutter analyze` no issues in
`lib/features/reminders` or `test/features/reminders` · `flutter test` 2,579
passing (2,571 + 8). Nothing renders it yet; T09 places it.

## T06 record (2026-10-10)

**DI.** The manual registration became
`registerFactoryParam<ReminderFormCubit, ManualReminderSeed?, void>` under the
same `manualReminderFormInstanceName`. The parameter is **nullable**, which is
what makes `param1: null` legal: get_it's `_validateFactoryParams` only
type-checks a parameter it was actually given, or one whose declared type
cannot be null — verified against get_it 9.2.1's own source rather than
assumed, since a non-nullable `P1` would have thrown on every tap of the
header button.

**Route.** `/reminders/manual` now reads `state.extra`, and is the one route
in `app_router.dart` that treats a missing or unusable `extra` as **normal**
rather than as a reason to bounce to Home: «إضافة تذكير» in the list header
sends nothing, and an empty manual form is exactly what that button should
open. Hence `extra is ManualReminderSeed ? extra : null` instead of the
`if (x is! T) return const _BackToHome();` guard the neighbouring routes use.

**Tests** — `test/app/manual_reminder_seed_routing_test.dart`, three cases
through the **real** `createAppRouter`, because the cubit test already covers
what a seed does and what can only break here is the plumbing between them:
a seed carried end to end (asserted as the date and time text the user sees,
and the pick-hints being gone), no `extra` opening the empty form, and a
wrong-typed `extra` opening the empty form rather than Home.

**Proved non-vacuous.** `param1: seed` was removed from the route; the first
test failed, the other two passed — exactly the right discrimination. Then
reverted.

**Gate:** `dart format` clean · `flutter analyze` 18 issues, unchanged from
the baseline · `flutter test` 2,571 passing (2,568 + 3). The seed now travels
end to end, but nothing sends one yet — the quick rows are T08.

## T05 record (2026-10-10)

`ManualReminderSeed` (`presentation/models/manual_reminder_seed.dart`) — an
event date and a **required** minute-of-day, with value equality. The sibling
of `ReminderFromDocumentArgs` for the manual flow. Kept separate from
`QuickReminderSlot`: the form has no business knowing a seed came from a quick
row. The minute is required where the from-document args' is nullable, because
a manual reminder's time is mandatory — a seed without one would open a form
that still could not be saved.

It deliberately does **not** carry a title (locked decision 7).

`ReminderFormCubit.manual` takes `ManualReminderSeed? seed`. The opening state
is built by `_manualInitialState`, which runs a seeded form through the very
same `_withDefaultAlertIfNeeded` that `setEventDate`/`setEventMinuteOfDay` use
— so a seeded form is **indistinguishable** from one filled in by hand, down
to the "at the event's time" alert. A test asserts that equivalence field by
field, which is what keeps the two paths from drifting. Without it a seeded
form would open with no alerts and `canSave` false, and the user would have to
add one by hand — more work than typing the date was.

### A pre-existing bug this task exposed, and fixed

While writing the "the seeded date is still the user's to change" test, the
assertion that the alert follows the date **failed**: the event moved to
1 December while its alert stayed on 13 October.

A `ReminderAlertDraft` stores an absolute instant, and `alertTimeLabel` labels
its row from the `offset` **alone** — «في وقت الحدث», «قبل الموعد بيوم». So
after changing the event date, the form showed the right words over the wrong
time, with nothing on screen to give it away, and the reminder fired on a day
the user had already moved away from.

This was always reachable by hand — pick a date and a time, then change the
date — and predates F29 entirely. What F29 changes is the likelihood: a seeded
form opens with an alert already in it, so the user's *first* edit of the date
hits it. Shipping concept D over it would have made a wrong reminder the
normal outcome of the feature's main path.

Fixed with `_reanchored`, which moves every preset-derived alert to follow the
new event instant and leaves a hand-picked one (`offset == null`) exactly
where the user put it — that instant was never a function of the event. Six
tests cover it: date change, time change, two alerts keeping their own
distances, the hand-picked one staying put, and the saved payload carrying the
moved time rather than the original.

**This is wider than F29 asked for.** It changes the existing hand-filled
form's behaviour too, and it is one hunk in
`reminder_form_cubit.dart` (`_reanchored` plus the two setters) if the owner
would rather split it into its own fix. It was not left for later because the
feature's primary path would have shipped producing wrong reminders.

**Gate:** `dart format` clean · `flutter analyze` no issues in
`lib/features/reminders` or `test/features/reminders` · `flutter test` 2,568
passing (2,555 + 13). Nothing routes a seed yet; T06 wires DI and the route.

## T04 record (2026-10-10)

`core/reminders/quick_reminder_date.dart` — pure Dart, no Flutter import, no
dependency on anything but `core/time/cairo_day.dart`. It exports
`QuickReminderDate` (the enum a widget switches on), `QuickReminderSlot` (a
calendar day plus a minute-of-day, with value equality), the constant
`kQuickReminderMinuteOfDay` (09:00), and `quickReminderSlots({DateTime? now})`
— `now` injected for tests, the house convention `reminder_due_label` and
`Reminder.isOverdue` already use.

Four decisions inside it worth a reviewer's eye:

1. **The day comes from `cairoWallClockOf`, not `cairoDateOf`.**
   `cairoDateOf` adds a flat +2, which is Egypt's *winter* offset, so for the
   first hour after midnight on summer time it names the previous day. That
   is harmless for the usage-day boundary it was written for and wrong for
   deciding what day it is for the user. Both behaviours are pinned in a
   test, so the "simplification" back to `cairoDateOf` fails loudly.
2. **Every slot is guaranteed strictly in the future.** The manual form seeds
   its first alert at the event's own time (`_withDefaultAlertIfNeeded` →
   `AlertTimeOffset.atEventTime`), so a slot in the past would show the
   user's very first reminder as «فائت» the instant they saved it. Only
   `endOfMonth` can breach it — on the 31st at noon, "the end of the month"
   is three hours gone — so it rolls to the last day of the following month.
   09:00 exactly counts as gone, not as still available. A sweep over 840
   consecutive hours across five month-ends (including the week Egypt's DST
   changes, a leap February and a year boundary) asserts the invariant.
3. **Dates are built from calendar fields, never by adding a `Duration`.**
   `DateTime(y, m, d + 7)` lets Dart normalise the overflow, so month ends,
   short months and leap days need no special case, and a DST transition
   cannot turn "+1 day" into 23 or 25 hours. `DateTime(y, m + 1, 0)` is the
   same idiom for "last day of this month" — and the roll-forward uses
   `m + 2`, so 31 January rolls to 28 February rather than inventing a
   «February 31st». That case has its own test.
4. **The event date is a *local* midnight, not `DateTime.utc`.** It matches
   what `showDatePicker` hands the manual form today, and `formatDocumentDate`
   and the Drift column both read `.year`/`.month`/`.day` as they stand — a
   UTC midnight would come back a day early on any device west of UTC.

**Gate:** `dart format` clean · `flutter analyze` no issues in
`lib/core/reminders` or `test/core/reminders` · `flutter test` 2,555 passing
(2,531 + 24). Nothing calls the helper yet; T05 is its first caller.

## T03 record (2026-10-10)

**Eight new getters**, in both languages, in the interface order the copy
table above lists them: `reminderQuickCreateKicker`, `reminderQuickTomorrow`,
`reminderQuickNextWeek`, `reminderQuickEndOfMonth`, `reminderEmptyScanHint`,
`reminderEmptyMissedSubtitle`, `reminderEmptyCompletedSubtitle`,
`reminderEmptyBackToUpcoming`.

**Three reworded.** `reminderEmptySubtitle` (it described the two ways in,
which the quick rows now show), and both bucket titles — «مافيش تذكيرات
فائتة.» became «مفيش حاجة فاتتك», and «التذكيرات اللي تنفذها هتظهر هنا.»
became «لسه مخلّصت ولا تذكير» with the explanation moved into the new
subtitle. The existing screen test asserts these through the getters, not
through literals, so the rewording broke nothing.

`reminderEmptyScanCta` («صوّر ورقة») is untouched — it has existed since F09
with no caller, and T11 finally gives it one.

**A bug caught by a new guard.** The first draft of
`reminderEmptyCompletedSubtitle` read «أول ما تضغط **«خلّصته»**…», quoting a
button that exists nowhere: the card's action is «تم التنفيذ»
([`reminder_list_item.dart`](../../lib/features/reminders/presentation/widgets/reminder_list_item.dart)
→ `reminderCompleteAction`). Copy that names a control the user cannot find is
worse than copy that names none, and this app's users are the least able to
absorb the mismatch. So `app_strings_test` gained a group that pins each
quotation to the label's own getter rather than to a literal — the hint to
`reminderAddAction`, the completed subtitle to `reminderCompleteAction`. The
bad wording was put back to confirm the guard fails on it, then reverted.

English quoting follows the file's existing ASCII convention — `"Mark done"`
inside a single-quoted Dart string, `"You haven't…"` double-quoted for the
apostrophe — not the typographic quotes the first draft used.

**Gate:** `dart format` clean · `flutter analyze` no issues in either
localization directory · `flutter test` 2,531 passing (2,529 + the two new
guards). No UI consumes any of this yet, which is why the suite stays green
on its own.

## T02 record (2026-10-10)

Four `BoxShadow` sites removed, two per screen — the paper's
`AppShadows.paper` and the camera tile's hand-written
`Color(0x4D0E7C86)` glow — in `home_empty_state.dart` and
`documents_empty_state.dart`. The now-unused `app_shadows.dart` import came
out of both files with them.

Nothing else moved. No re-spacing, no recolouring, no copy change, no new
border to stand in for the shadow — locked decision 9. Each `_EmptyArt` gained
a doc comment saying the flatness is deliberate and deviates from
`Waraqti.dc.html` on the owner's instruction, so the next person to compare
screen against comp does not "fix" it back.

`AppShadows.paper` stays, with its doc comment rewritten to say it is
currently unused and why (locked decision 8). The reference to it in
`documents_empty_state.dart`'s `_linedPaperFill` comment was reworded, since
that file no longer imports the type it was linking to.

**Tests.** `home_empty_state_test` gained a case; «مستنداتي»'s art had **no
test file at all**, so `documents_empty_state_test.dart` was written — the
shadow case plus the coverage that was missing (both empty variants, the CTA's
callback, the no-results variant dropping the CTA, English, screen readers,
2× text). Both shadow cases walk every `BoxDecoration` in the widget's
subtree, not just the two shapes that used to carry a shadow, so one cannot
reappear on a third shape unnoticed.

**Proved non-vacuous.** A shadow was temporarily put back on each screen —
the teal glow on Home's tile, `AppShadows.paper` on «مستنداتي»'s page — and
both tests failed; the mutation was then reverted. A test that cannot fail
would have been worse than none here, because the whole task is an absence.

**Gate:** `dart format` clean · `flutter analyze` 18 issues, identical to the
pre-change baseline measured on a stash, none in a touched file · `flutter
test` 2,529 passing.

**One thing for the device pass (T14).** Home's page is `colors.card`
(`#FFFFFF`) on `colors.surface` (`#F5F4EF`) and now carries nothing at all —
no shadow, no border, no content. On a real screen it may read as very faint.
«مستنداتي» is unaffected, because its lined second sheet has its own 2 px
border. This is reported, not acted on: decision 9 says only shadows come off,
and whether that page needs a hairline is the owner's call once they see it on
the RMX2001.

## T01 record (2026-10-10)

- Branch `feature/reminders-empty-state` cut from `feature/android-release` at
  `f150c8d`.
- The approved prototype, and the two rejected concepts with it, committed at
  `docs/design/F29-reminders-empty-mockups.html`.
- `docs/features/README.md` gains the F29 row; the total rises to 338 tasks
  across 27 features.
