# F03 · Capture & Review

- **Branch:** `feature/scan-to-text` · **Milestone:** M2
- **Depends on:** F00, permissions core · **Feeds:** F04 (processed image path)
- **Progress:** 10 / 10 DONE

Camera/gallery → crop/rotate → quality check → produces a processed image path for OCR.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F03-T01 | Camera permission flow | request on «صوّر ورقتك»; denied → «اسمح بالكاميرا» + choose-gallery fallback | DONE |
| 2 | F03-T02 | Camera capture | capture single photo (portrait) | DONE |
| 3 | F03-T03 | Gallery/system picker | system photo picker; single image | DONE |
| 4 | F03-T04 | Crop | «قص الصورة» with frame | DONE |
| 5 | F03-T05 | Rotate | rotate image | DONE |
| 6 | F03-T06 | Preview screen | confirm «استخدم الصورة» / cancel «إلغاء» | DONE |
| 7 | F03-T07 | Quality assessment engine | blur/resolution/brightness → good/acceptable/poor | DONE |
| 8 | F03-T08 | Quality-alert sheet | poor → «الصورة ممكن تكون أوضح» → retake/continue | DONE |
| 9 | F03-T09 | Analysis-session create | session id + file paths | DONE |
| 10 | F03-T10 | Temp-file lifecycle + cancel | files cleaned on cancel/exit; cancel flow | DONE |

## Notes
- **T04–T06** ship as one screen (`ImagePreviewScreen`, route `/preview`): the design (`Waraqti.dc.html` → `preview`, «قص الصورة») merges crop, rotate, and confirm/retake into a single screen. Crop is a **fixed** teal corner-bracket guide (not draggable — per design); rotate is a working 90° step shown live and baked into a file (`image` pkg, isolate) only on confirm; the footer is «استخدم الصورة» / «إعادة التصوير». Confirmed/retake hand-off is a placeholder (returns Home) until T07/T09 wire quality-check + session.

## Exit DoD
Image acquired → cropped → quality-checked → processed path produced; temp files cleaned on cancel/exit; no crash.
