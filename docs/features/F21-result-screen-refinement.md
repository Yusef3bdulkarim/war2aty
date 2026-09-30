# F21 · Result Screen Refinement

- **Branch:** `feature/result-screen-refinement`, based on `feature/ocr-analysis-providers` (PR #20). Rebase onto `develop` once #20 is merged · **Milestone:** post-F20
- **Depends on:** F07 (the result screen and its cards), F08 (the saved-paper details screen, which shares the same cards), F09 (the reminder button in the dates card)
- **Progress:** 9 / 14 DONE
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
   holds the paper's menu. *(Superseded by #14: the arrow moves into the
   hero, on both screens. `PopScope` and the invisible heading stay.)*
5. **There is no new backend schema** (no "Parties"). The data card groups
   the types that already exist: Key Information, Amounts, Dates.
6. ~~**The header card** (type, title, confidence badge) **stays as it
   is.**~~ *Reversed 2026-09-30 — see #15.*
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
    - The partial-result banner takes the same compact style. *(Its place
      changed on 2026-09-30 — see #17.)*
11. **Cards are 12 px apart everywhere on the page** (today it is 14).
12. **The summary card is redesigned** — settled by #14: the star is
    removed, and the label is **«ملخص المستند»** / **"Document summary"**
    (owner, 2026-09-30).
13. **The two collapsible panels** (detailed explanation, extracted text)
    **slide open and closed smoothly in place.** Under reduced motion they
    open instantly.

### Second review (owner, 2026-09-30), from the mockups

Mockups: the private canvas «Waraqti result top · summary options»
(https://claude.ai/artifact/PigAUKupPSf73aTDPncTD2).

14. **Hero summary (mockup A), on both screens.** The page opens on a teal
    gradient block (brand teal → deep teal, rounded bottom corners) that
    holds the back arrow, a document icon, the label «ملخص المستند», and the
    summary text. It replaces both the top bar and the summary card. On the
    saved-paper screen, the ⋮ menu (rename, category, delete) sits in the
    hero's top row too.
15. **The document-type card is removed from both screens.** The type
    becomes the **first row of «أهم المعلومات»**, labelled «نوع المستند», with
    **no copy button**; when the analysis is unsure of the type, the row
    carries its chip like any other value. The paper's **title is not shown**
    in either view: renaming changes the name in the saved-papers list only.
    This departs from master plan §4 item 1 (document type and title first),
    at the owner's decision; it is recorded here.
16. **Compact one-line rows (mockup L2)** for key information and amounts:
    the label on the start side, the value on the end side, on one line. A
    row falls back to two lines (label above value) when its value does not
    fit, when it carries a caution chip, or under Large Text. Nothing is
    hidden. Date rows keep their tile layout.
17. **The banners sit right before «أهم المعلومات»** — the warnings, where
    §4 already puts them, and the partial-result banner, moved there from
    the top of the page.
18. **Contrast:** the data card's sub-headers and row labels use
    `textCaption` (#6B777C, 4.6:1 on white) instead of `textMuted` (3.0:1)
    and `iconSubtle` (3.7:1), which failed WCAG AA for 13 px text.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F21-T01 | Task file | This file and the README row, from the owner's decisions of 2026-09-30 | DONE |
| 2 | F21-T02 | Light top bar and `PopScope` | Back icon only, no bar styling (#4). The system back gesture runs `onClose` (usage hint, then Home), tested. The page title is still announced as a header, tested. RTL and LTR arrow direction. Large Text | DONE — the bar is a lone arrow on the page surface; the title is an invisible `Semantics(header)` over the rest of the row, with real bounds. `PopScope(canPop: onClose == null)` sends the back gesture through `onClose`; the test was mutation-checked (it fails with `canPop: true`). Page top padding 18 → 8, since the bar's own 12 px and border are gone. Ready page only: the failure and fallback pages keep their own bars |
| 3 | F21-T03 | Inline confidence chip | The caveat sits beside the value in key-information, amount and date rows and wraps under Large Text (#1). Icon and words, announced as its own sentence. Tests: each band, inferred, both at once, wrapping | DONE — new shared `CaveatedValue` (`core/widgets/`): the value and one `CaveatBadge` chip per caution in a `Wrap`, so the chips wrap under the value only when the line is full. The key-information, amount and date rows use it; `ValueCaveat` (the old caution under the value) is deleted. In dates the chip sits beside the written-out date, and the time line stays below it. Tests: the chip on the value's line, wrapping, two chips, Large Text, semantics |
| 4 | F21-T04 | Data card: key information and amounts | One card with neutral 13 sp sub-headers. Rows without the icon box, 1 px dividers. Amounts get a copy button that copies the number only (#9). Tests: copy payloads, only-info, only-amounts | DONE — new `ResultDetailsCard` (`core/widgets/`) replaces `ResultKeyInformationCard` and `ResultAmountsCard` (both deleted, with their tests ported). Sub-headers are `caption` 13 bold `textMuted`, announced as headings. Rows are label, then value with its chips (`CaveatedValue`), then a 16 px copy icon on a 48 dp target. `isResultDetailsSlot` draws the card once, at the first of its sections, so the §4 order stays the domain's. `formatAmountNumber` is split out of `formatDocumentAmount` for the amount copy (`250.50`), and its tests moved to `test/core/money/`. Both screens |
| 5 | F21-T05 | Data card: dates join it | The dates group inside the same card. Day tile kept, reminder button at the group's end, multi-date picking unchanged (§5.8). No copy on dates. Both screens. Tests: each combination of the three groups present or absent | DONE — `ResultDatesCard` became `result_date_row.dart`, with public `ResultDateRow` and `ResultReminderButton` and no card or heading of its own. `ResultDetailsCard` gains a third group, «التواريخ والمواعيد»: date rows with dividers between them, then the reminder button as the group's footer, inside the card. `resultDetailsSections` includes `dates`. Its tests are ported to `result_details_card_test.dart`, and `date_selection_test` (multi-date picking, §5.8) runs unchanged against the new card |
| 6 | F21-T06 | Compact warning banners | One banner per warning, minimum height 48, radius 8, grows under Large Text (#2, #10). Partial banner in the same style, still first on the page. Not colour alone (icon and text). Audio reader output unchanged, tested | DONE — new shared `CompactAlertBanner` (`core/widgets/`): warning tint, 1 px border, radius 8, `minHeight: 48`, an 18 px icon and 14 sp text that wraps. `ResultWarningsCard` draws one per warning, 8 px apart, with no drawn heading; each banner's screen-reader label is «تنبيه مهم: …», so the heading's meaning survives for TalkBack. `PartialResultBanner` uses the same banner and is still first on the page. The audio reader is untouched (it speaks from the strings, not the widgets), and its tests pass unchanged |
| 7 | F21-T07 | Hero summary | The hero (#14) on both screens: back arrow, ⋮ on the saved-paper screen, icon, «ملخص المستند» / "Document summary", summary text. `PopScope` and the invisible heading kept. `ResultSummaryCard` retired. Tests: both screens, RTL/LTR arrow, Large Text, back gesture, ⋮ menu still works. **Blocked** on two owner answers: how the hero behaves on scroll, and what it shows when a paper has no summary | BLOCKED |
| 8 | F21-T08 | 12 px card spacing | Every result card 12 px apart on both screens (#11) | DONE — one token, `AppSpacing.resultCardGap` (= `md`, 12), replaces the seven separate 14 px gaps (header, summary, actions, warnings, details, list cards, partial banner). The two result panels used to add a gap *above* (14 and 10), which stacked on the card before them (28 px). They now take the same 12 px *below*, through a new `ExpandablePanel.gapBelow`. Section headings above the list cards keep their own 20/12 spacing: they are headings, not cards. Test: the drawn gap between the header and summary cards is 12 |
| 9 | F21-T09 | Smooth panel slide | `ExpandablePanel` animates its height in place, and is instant under reduced motion (#13). The body is still built only while open. Tests: open, close, reduced motion | DONE — `ExpandablePanel` gets an `AnimationController` (220 ms, easeInOut) behind a top-aligned `SizeTransition`. The body is built while open or sliding shut, and dropped once the slide finishes. Under reduced motion both the body and the arrow change at once. Tests: shut at start, halfway taller than shut on the way open, shrinking and then dropped on the way shut, instant under reduced motion, `expanded` semantics. Both panels on both screens get this through the shared widget |
| 11 | F21-T11 | Contrast fix | Sub-headers and row labels in the data card, and date-row labels, use `textCaption` (#18). Test pins the colour | DONE — the sub-header (`textMuted` → `textCaption`), the row label (`iconSubtle` → `textCaption`), the date label (`iconSubtle`) and the date's time line «مافيهاش وقت محدد» (`textMuted`, 12.5 px; also failing AA, and §5.6 information) now use `textCaption`. The copy icon keeps `textMuted`: icons need 3:1, which it meets (3.04). Test: the four texts use `textCaption` |
| 12 | F21-T12 | Compact one-line rows | Key-information and amount rows on one line (#16), falling back to two lines when the value does not fit, with a caution chip, or under Large Text. Copy target stays 48 dp. Tests: one line when it fits, two lines for a long value, for a chip, and under Large Text; row height drops | TODO |
| 13 | F21-T13 | Document type as a row; header card removed | «نوع المستند» first in «أهم المعلومات», no copy, its chip when unsure (#15). `ResultHeaderCard` removed from both screens and deleted; the title is shown nowhere. The data card appears even when the paper has no key information, amounts or dates. Tests: type row first, no copy, chip, card present with only the type | TODO |
| 14 | F21-T14 | Banners before the data | The partial-result banner moves from the top to right before «أهم المعلومات», after the warnings (#17), on both screens. Tests: order on a partial paper | TODO |
| 10 | F21-T10 | End-to-end verification | Device pass on RMX2001: result screen and details screen, Arabic and English, Large Text, TalkBack; back gesture and back button; reminder from the dates group | TODO |

Execution order: T11 → T12 → T13 → T14 → T07 → T10.

## Exit DoD

The result screen and the saved-paper details screen show the refined layout.
Every value the analysis is unsure of says so in visible words beside it. The
page is left the same way by the back button and by the back gesture. Nothing
in the domain, data or audio reader changed. `dart format .`,
`flutter analyze` and `flutter test` all pass.
