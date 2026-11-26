# T47 · Delete result_* widgets, strings and assets used only by deleted screens

**Branch:** feature/capture-and-result  
**Gate:** format 0 changed · analyze 0 errors 0 warnings 13 info (pre-existing) · localization test 41/41

---

## What was deleted

- `AppStrings.analysisResultTitle` — abstract getter + its doc comment from `app_strings.dart`
- `ArStrings.analysisResultTitle` — Arabic implementation from `ar_strings.dart`
- `EnStrings.analysisResultTitle` — English implementation from `en_strings.dart`
- `'analysisResultTitle'` entry from `test/core/localization/app_strings_test.dart` parity map

## Why nothing else was deleted

All 9 `core/widgets/result_*` widgets are still used by `DocumentDetailsScreen` (F41's target), either directly imported or transitively:
- Direct: `result_action_bar`, `result_actions_card`, `result_details_card`, `result_extracted_text_panel`, `result_hero_scroll_view`, `result_list_card`, `result_warnings_card`
- Transitive: `result_date_row` (via `result_details_card`), `result_section_heading` (via `result_list_card`)

All `result_*` strings (`resultListen`, `resultSavePaper`, etc.) have at least one reference outside the localization files. `analysisResultBackLabel` is used as a generic back-tooltip across six screens and stays.

No result-related image or voice assets were orphaned.

## Findings from self-review

1. **ar_strings.dart Unicode hazard (caught and fixed):** The first Edit call to `ar_strings.dart` silently dropped a tanwin (U+064B) from `تحليلًا`, an ellipsis (U+2026) from `الكاميرا…`, and a shadda (U+0651) from `جرّب` — three untouched lines. Caught by inspecting `git diff` before finishing; each character restored with a targeted Edit. The `git diff` after the fix touches only the intended two-line block. This confirms the memory warning: always check `git diff` on `ar_strings.dart` after any edit.
