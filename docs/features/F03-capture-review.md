# F03 · Capture & Review

- **Branch:** `feature/scan-to-text` · **Milestone:** M2
- **Depends on:** F00, permissions core · **Feeds:** F04 (processed image path)
- **Progress:** 0 / 10 DONE

Camera/gallery → crop/rotate → quality check → produces a processed image path for OCR.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F03-T01 | Camera permission flow | request on «صوّر ورقتك»; denied → «اسمح بالكاميرا» + choose-gallery fallback | TODO |
| 2 | F03-T02 | Camera capture | capture single photo (portrait) | TODO |
| 3 | F03-T03 | Gallery/system picker | system photo picker; single image | TODO |
| 4 | F03-T04 | Crop | «قص الصورة» with frame | TODO |
| 5 | F03-T05 | Rotate | rotate image | TODO |
| 6 | F03-T06 | Preview screen | confirm «استخدم الصورة» / cancel «إلغاء» | TODO |
| 7 | F03-T07 | Quality assessment engine | blur/resolution/brightness → good/acceptable/poor | TODO |
| 8 | F03-T08 | Quality-alert sheet | poor → «الصورة ممكن تكون أوضح» → retake/continue | TODO |
| 9 | F03-T09 | Analysis-session create | session id + file paths | TODO |
| 10 | F03-T10 | Temp-file lifecycle + cancel | files cleaned on cancel/exit; cancel flow | TODO |

## Exit DoD
Image acquired → cropped → quality-checked → processed path produced; temp files cleaned on cancel/exit; no crash.
