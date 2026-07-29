# F07 · Analysis Result

- **Branch:** `feature/analysis-result` · **Milestone:** M3 (start) / M5 (full)
- **Depends on:** F05/F06 · **Feeds:** F08 (save), F09 (reminder), F10 (audio)
- **Progress:** 5 / 14 DONE

The result experience — ordered sections, all statuses, and the branch point into save/reminder/audio.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F07-T01 | Result scaffold + ordering | `BuildAnalysisResult`; section order per §4 | DONE |
| 2 | F07-T02 | Header (type/title) | document type + title | DONE |
| 3 | F07-T03 | Summary | short + detailed | DONE |
| 4 | F07-T04 | Action-required | «المطلوب منك»; basis=inferred labeled | DONE |
| 5 | F07-T05 | Warnings | medical/government disclaimers | DONE |
| 6 | F07-T06 | Key-information items | confidence bands; «راجع المعلومة» label | TODO |
| 7 | F07-T07 | Dates & times | list with roles | TODO |
| 8 | F07-T08 | Multi-date selection | «اختار التاريخ» (event vs display) | TODO |
| 9 | F07-T09 | Missing-time rules | never fabricate time; «مافيهاش وقت» | TODO |
| 10 | F07-T10 | Amounts + required docs + instructions | sections render | TODO |
| 11 | F07-T11 | Detailed explanation + extracted text | copy/edit; original always available | TODO |
| 12 | F07-T12 | Partial/unsupported variants | «نتيجة جزئية» / «غير مدعومة» | TODO |
| 13 | F07-T13 | Service-state screens | no-net/limit/failed + OCR-only fallback (not counted) | TODO |
| 14 | F07-T14 | Action hooks | audio/reminder/save entry points | TODO |

## Exit DoD
All 4 templates + partial/unsupported + all error states match design; uncertain values labeled (never as fact); original OCR text always accessible.
