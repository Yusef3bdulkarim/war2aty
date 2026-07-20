# F04 · Local OCR

- **Branch:** `feature/scan-to-text` · **Milestone:** M2
- **Depends on:** F03 · **Feeds:** F05 (OCR text + candidates)
- **Progress:** 0 / 13 DONE

Plain-text-first OCR (Option A) behind `OcrEngine`, normalization, and rule-based candidate extractors.
**Note:** spike port decision made at start of this feature (port from `war2aty_ocr_spike`, else build fresh with `flutter_tesseract_ocr`).

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F04-T01 | Light preprocessing | grayscale/resize service (no destructive changes) | TODO |
| 2 | F04-T02 | `OcrEngine` interface + `OcrResult` | interface + plain-text result model (boxes/confidence optional) | TODO |
| 3 | F04-T03 | Tesseract adapter | `ara+eng`, PSM 3; returns plain text | TODO |
| 4 | F04-T04 | `OcrRepository` + `ExtractDocumentText` | use case returns `Result` | TODO |
| 5 | F04-T05 | Normalization | AR/EN digits, currency, RTL line order; keeps original | TODO |
| 6 | F04-T06 | Date extractor | candidates + ambiguity flags; unit-tested | TODO |
| 7 | F04-T07 | Time extractor | candidates; unit-tested | TODO |
| 8 | F04-T08 | Amount extractor | value + currency; unit-tested | TODO |
| 9 | F04-T09 | Phone extractor | candidates; unit-tested | TODO |
| 10 | F04-T10 | Reference extractor | invoice/booking/txn numbers; unit-tested | TODO |
| 11 | F04-T11 | Uncertain-field review UI | «راجع المعلومات» edit / keep-as-is | TODO |
| 12 | F04-T12 | OCR failure / no-text states | «مالقيناش كلام واضح»; retake/choose | TODO |
| 13 | F04-T13 | Extracted-Text screen | slice terminal; copy; hand text+candidates onward | TODO |

## Exit DoD
One image → normalized AR+EN text + date/amount/phone candidates; extractors unit-tested; failure/no-text handled. Snippet/highlight intentionally deferred (Option A).
