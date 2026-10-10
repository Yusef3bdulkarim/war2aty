# F29 · The reminders screen's empty space, and the empty-state shadows

- **Branch:** `feature/reminders-empty-state`, based on `feature/android-release` · **Milestone:** post-F28
- **Depends on:** F09 (the reminders list and the manual form this builds on), F25 (the notifications a quick reminder schedules), F27-T03 (Home's own empty-state redesign, the precedent for "fill the dead space")
- **Progress:** 1 / 14 · **T01 DONE**
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
| 2 | F29-T02 | **Shadows off** — the independent half | 4 `BoxShadow` sites removed in `home_empty_state.dart` + `documents_empty_state.dart`; `AppShadows.paper` kept, comment updated; a test per screen pinning "no `BoxShadow` in the art" | TODO |
| 3 | F29-T03 | The new strings | new `AppStrings` getters + `ar_strings.dart` + `en_strings.dart` + `app_strings_test` rows. No UI yet, so the gate stays green on its own | TODO |
| 4 | F29-T04 | Quick-date arithmetic | `core/reminders/quick_reminder_date.dart` — a pure helper giving بكرة / بعد أسبوع / آخر الشهر as a Cairo date + minute-of-day, with unit tests for month ends, February, leap years and the DST boundary | TODO |
| 5 | F29-T05 | `ManualReminderSeed` + a seedable cubit | the seed model under `presentation/models/`; `ReminderFormCubit.manual` takes an optional seed and runs it through the same default-alert seeding; cubit tests for seeded and unseeded construction | TODO |
| 6 | F29-T06 | DI + route carry the seed | `registerFactoryParam<…, ManualReminderSeed?, void>` under the same `instanceName`; `/reminders/manual` reads `state.extra`; the header's «إضافة تذكير» keeps passing nothing | TODO |
| 7 | F29-T07 | The illustration | `reminders_empty_art.dart` — paper + date chip + bell, `ExcludeSemantics`, **no shadow**, with its own test asserting that | TODO |
| 8 | F29-T08 | The quick-create rows | `reminders_quick_create.dart` — three rows, callback-driven, no cubit knowledge; widget test at 1× and 1.6× | TODO |
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
| `reminderEmptyCompletedSubtitle` | أول ما تضغط «خلّصته» على أي تذكير، هيتحرّك هنا. | As soon as you tap "Done" on a reminder, it moves here. |
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

## T01 record (2026-10-10)

- Branch `feature/reminders-empty-state` cut from `feature/android-release` at
  `f150c8d`.
- The approved prototype, and the two rejected concepts with it, committed at
  `docs/design/F29-reminders-empty-mockups.html`.
- `docs/features/README.md` gains the F29 row; the total rises to 338 tasks
  across 27 features.
