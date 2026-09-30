# F21 · Result Screen Refinement

- **Branch:** `feature/result-screen-refinement`, based on `feature/ocr-analysis-providers` (PR #20). Rebase onto `develop` once #20 is merged · **Milestone:** post-F20
- **Depends on:** F07 (the result screen and its cards), F08 (the saved-paper details screen, which shares the same cards), F09 (the reminder button in the dates card)
- **Progress:** 2 / 10 DONE
- **PR:** one PR at the end of the feature

The owner's UI/UX review of the analysis result screen (2026-09-30). The screen
already had most of the proposal: the teal summary card, the amber warnings,
visible confidence text, row dividers and copy buttons. This feature changes
what it did not have. **Presentation only:** the domain and data layers, the
section order in `AnalysisSection` (master plan §4), and the audio reader are
not touched.

The approved Waraqti design is **not** updated by this feature. The owner
approved the deviations below in writing on 2026-09-30. The design itself
could not be opened from the session (DesignSync needs `/design-login`).

## Locked decisions

1. **Confidence is always visible — never a tap-only tooltip.** A compact
   inline chip («راجع المعلومة» / «قراءة غير مؤكدة» /
   «استنتاج من محتوى الورقة») sits beside the value, with an icon and words.
   It wraps below the value when there is no room (Large Text, long values).
   Master plan §5.11 and §5.16, CLAUDE.md §7.
2. **Warning banners have a minimum height of 48 px, not a fixed one.** They
   grow with their text (Large Text, long legal disclaimers).
3. **Labels are 13 sp (`caption`)**, the size the rows already use. Values
   keep their current size and weight.
4. **The top bar becomes a light back button.** There is no title bar
   styling, no card background and no bottom border. Its tap and the system
   back gesture both run `onClose`, through `PopScope`. The page title stays
   for screen readers as an invisible `Semantics(header: true)`. This applies
   to the result screen only; the details screen keeps its own bar, which
   holds the paper's menu.
5. **There is no new backend schema** (no "Parties"). The data card groups
   the types that already exist: Key Information, Amounts, Dates.
6. **The header card** (type, title, confidence badge) **stays as it is.**
7. **Every section stays, in the §4 order.** Key Information, Amounts and
   Dates are already adjacent in `AnalysisSection`, so merging them into one
   card is a presentation choice. The domain order does not change.
8. **The shared cards change for both screens.** The result screen and the
   saved-paper details screen draw the same cards from `core/widgets/`, so
   both get the refinement. Nothing is forked.
9. **Inside the data card:**
   - Rows lose the 40 px teal icon box.
   - Dates keep their day/month tile.
   - «إنشاء تذكير» stays at the end of the dates group, inside the card.
   - Copy: key information copies the value as it does today. Amounts copy
     the **number only** (e.g. `150`, for payment apps). Dates have no copy.
10. **Warnings:**
    - Each warning gets its own compact banner (icon and text), with no
      «تنبيه مهم» heading. The heading string stays, because the audio reader
      still speaks it.
    - The partial-result banner takes the same compact style and **stays at
      the very top**, so a half-read paper never looks complete.
11. **Cards are 12 px apart everywhere on the page** (today it is 14).
12. **The summary card is redesigned:**
    - The star is removed.
    - The label changes from «الخلاصة» to **«الملخص الذكي»** (recommended,
      pending the owner's confirmation; «ملخص المستند» is the alternative).
      With the star gone, the label is the only thing telling the user the app
      wrote this text, so "الذكي" keeps that signal in words.
    - The wider visual redesign **waits for the owner's direction**
      (a reference or a mockup).
13. **The two collapsible panels** (detailed explanation, extracted text)
    **slide open and closed smoothly in place.** Under reduced motion they
    open instantly.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F21-T01 | Task file | This file and the README row, from the owner's decisions of 2026-09-30 | DONE |
| 2 | F21-T02 | Light top bar and `PopScope` | Back icon only, no bar styling (#4). The system back gesture runs `onClose` (usage hint, then Home), tested. The page title is still announced as a header, tested. RTL and LTR arrow direction. Large Text | DONE — the bar is a lone arrow on the page surface; the title is an invisible `Semantics(header)` over the rest of the row, with real bounds. `PopScope(canPop: onClose == null)` sends the back gesture through `onClose`; the test was mutation-checked (it fails with `canPop: true`). Page top padding 18 → 8, since the bar's own 12 px and border are gone. Ready page only: the failure and fallback pages keep their own bars |
| 3 | F21-T03 | Inline confidence chip | The caveat sits beside the value in key-information, amount and date rows and wraps under Large Text (#1). Icon and words, announced as its own sentence. Tests: each band, inferred, both at once, wrapping | TODO |
| 4 | F21-T04 | Data card: key information and amounts | One card with neutral 13 sp sub-headers. Rows without the icon box, 1 px dividers. Amounts get a copy button that copies the number only (#9). Tests: copy payloads, only-info, only-amounts | TODO |
| 5 | F21-T05 | Data card: dates join it | The dates group inside the same card. Day tile kept, reminder button at the group's end, multi-date picking unchanged (§5.8). No copy on dates. Both screens. Tests: each combination of the three groups present or absent | TODO |
| 6 | F21-T06 | Compact warning banners | One banner per warning, minimum height 48, radius 8, grows under Large Text (#2, #10). Partial banner in the same style, still first on the page. Not colour alone (icon and text). Audio reader output unchanged, tested | TODO |
| 7 | F21-T07 | Summary card redesign | Star removed, the new label in ar and en (#12). The visual redesign follows the owner's direction. **Blocked** on that direction and on the label confirmation | BLOCKED |
| 8 | F21-T08 | 12 px card spacing | Every result card 12 px apart on both screens (#11) | TODO |
| 9 | F21-T09 | Smooth panel slide | `ExpandablePanel` animates its height in place, and is instant under reduced motion (#13). The body is still built only while open. Tests: open, close, reduced motion | TODO |
| 10 | F21-T10 | End-to-end verification | Device pass on RMX2001: result screen and details screen, Arabic and English, Large Text, TalkBack; back gesture and back button; reminder from the dates group | TODO |

## Exit DoD

The result screen and the saved-paper details screen show the refined layout.
Every value the analysis is unsure of says so in visible words beside it. The
page is left the same way by the back button and by the back gesture. Nothing
in the domain, data or audio reader changed. `dart format .`,
`flutter analyze` and `flutter test` all pass.
