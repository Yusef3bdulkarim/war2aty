# T48 · Comprehensive strings sweep — localization files + test parity

**Branch:** feature/capture-and-result  
**Gate:** format 0 changed · analyze 0 errors 0 warnings 13 info (pre-existing) · localization tests 31/31

---

## What was deleted

### `app_strings.dart` (interface)
- `homeUsageRemaining` getter
- All `ocr*` getters except `ocrTextCopied`: `ocrProcessing`, `ocrErrorTitle`, `ocrErrorMessage`, `ocrNoTextTitle`, `ocrNoTextMessage`, `ocrRetake`, `ocrPickAnother`, `ocrExtractedTextTitle`, `ocrCopyText`, `ocrContinue`, `ocrDatesSection`, `ocrTimesSection`, `ocrAmountsSection`, `ocrPhonesSection`, `ocrReferencesSection`, `ocrOnlineReviewTitle`, `ocrOnlineReviewSubtitle`, `ocrOnlineLoading`, `ocrOnlineAnalyze`, `ocrOnlinePoorQuality`, `ocrOnlineShowImage`, `ocrOnlineHideImage`, `ocrOnlineAmbiguityNotice`, `ocrOfflineQualityWarning`, `ocrOnlineFallbackWarning`, `ocrListenToText`
- `analysisRunningStatus`, `analysisWaitPhoto`, `analysisWaitReading`, `analysisWaitExplanation`, `analysisWaitReadyAnnouncement`
- `analysisFailedMessage`, `analysisNoInternetMessage`
- `analysisLimitReachedMessage` (getter) and `analysisLimitReachedMessageWithLimit` (method)
- `analysisLimitTipReadText`
- All `analysis*Supported*`/`*Unsupported*` members, `analysisPickFromGallery`, `analysisCaptureAnother`

### `ar_strings.dart` and `en_strings.dart`
- Parallel removal of all implementations listed above

### `app_strings_test.dart`
- Removed 50+ entries from `_accessors` parity map corresponding to deleted getters
- Removed test group `'the on-device reading warning does not blame the connection'` (tested `ocrOfflineQualityWarning`/`ocrOnlineFallbackWarning`)

### `failure_page_strings_test.dart`
- Removed group `'analysisLimitReachedMessageWithLimit'` (Arabic/English plural tests)
- Removed group `'truthfulness (F23 #6, #8)'` (tested `analysisNoInternetMessage`, `analysisFailedMessage`, `analysisAttemptNotCounted`, `analysisLimitReachedMessage`)

### `failure_widgets_test.dart`
- Removed group `'FailureNoteChip'` (tested `analysisAttemptNotCounted` display)
- Removed unused import of `failure_note_chip.dart`

### `test/features/home/usage_indicator_test.dart`
- Deleted entirely (all 9 tests used `homeUsageRemaining` which is gone)

## What was kept (and why)

`ocrTextCopied` was initially included in the OCR removal but restored after `flutter analyze` revealed two live consumers:
- `lib/core/widgets/result_details_card.dart:423` — `_copy()` SnackBar
- `lib/core/widgets/result_extracted_text_panel.dart:108` — `_copy()` SnackBar

## Findings from self-review

1. **Pre-existing test failures (25):** `shell_test`, `notifications`, `accessibility`, `reminder_routing` tests all fail on the prior commit too. Confirmed with `git stash` / `flutter test` / `git stash pop`. Not caused by T48.
2. **ocrTextCopied restoration:** Initial sweep accidentally removed a live string. `flutter analyze` caught it before finishing. Restored with targeted edits to all three localization files and the parity map. Pattern: always run `flutter analyze` as a gate before declaring a string removal complete.
3. **ar_strings.dart Unicode hazard:** No corruption detected this session (verified via `git diff numstat`; additions = 2, deletions = 179). The memory warning holds for future edits.
