# T45 · Delete OCR feature, Tesseract, tessdata, AppFailure leaves

**Branch:** feature/capture-and-result  
**Gate:** format 0 changed · analyze 0 errors 0 warnings 13 info (pre-existing) · test 3241 passed 26 failed (all pre-existing, same as T44 baseline)

---

## What was deleted

- `lib/features/ocr/` — 28 files (domain entities, services, usecases, data repo/services, presentation cubit/screen/widgets)
- `test/features/ocr/` — 13 test files
- `assets/tessdata/ara.traineddata`, `assets/tessdata/eng.traineddata`, `assets/tessdata_config.json`
- `flutter_tesseract_ocr: ^0.4.31` from pubspec.yaml + tessdata assets block

## AppFailure leaves removed

- `OcrInitializationFailure` (LocalFailure) — error code `OCR_INIT`
- `OcrFailure` (LocalFailure) — error code `OCR`
- `NoTextDetectedFailure` (LocalFailure) — error code `NO_TEXT_DETECTED`
- `OnlineOcrUnavailableFailure` (NetworkFailure) — error code `ONLINE_OCR_UNAVAILABLE`

Leaf count: 37 → 33 (3 removed in earlier T43/T44 cleanup + 4 here).

## keptForOldBuilds entries added

`OCR_INIT`, `OCR`, `NO_TEXT_DETECTED`, `ONLINE_OCR_UNAVAILABLE` added to `keptForOldBuilds` in `test/core/logging/error_report_codes_test.dart`.  
1.0.x builds still call `ocr-document` and still report these codes; removing them from the server's allowlist would silently delete those reports.

## api_error_mapper change

`'OCR_UNAVAILABLE'` case removed from `failureFromErrorBody`; falls to the existing `_ => AnalysisServiceFailure()` default. `api_error_mapper_test.dart` updated accordingly.

## Findings from self-review

1. **Gate failure (fixed):** Previous session removed OCR error codes from `error_code.dart` but forgot to add them to `keptForOldBuilds` → `error_report_codes_test.dart` failed. Fixed by adding all four codes.
2. **Task gap (fixed):** `OnlineOcrUnavailableFailure` was explicitly listed in T45 for removal but was missed. Removed from `app_failure.dart`, `error_code.dart`, `api_error_mapper.dart`, and all test files.
3. **Pre-existing:** `app_failure_test.dart` test name says "18 local" but localLeaves has 15 items (`hasLength(18)` fails). Not a T45 issue — broken by earlier tasks; left for a future sweep.

## APK build / size

Deferred to device pass (consistent with other tasks on this branch; build requires Gradle + physical device environment).
