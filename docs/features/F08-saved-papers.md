# F08 · Saved Papers

- **Branch:** `feature/saved-papers` · **Milestone:** M6
- **Depends on:** F00 (db), F07 (analysis to save), security core · **Feeds:** Home (recent), F09 (link)
- **Progress:** 2 / 11 DONE

Local document library. Result-only save is default; image save is opt-in + encrypted. **Decision at start:** DB-encryption strategy (image files AES-256-GCM now; SQLCipher vs field-level revisited).

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F08-T01 | Document Drift schema + DAOs | documents + related tables (§12) + migration | DONE |
| 2 | F08-T02 | Save-result-only | default; no image; summary/info/dates persisted | DONE |
| 3 | F08-T03 | File encryption | AES-256-GCM; key in secure storage; random nonce | TODO |
| 4 | F08-T04 | Save-with-encrypted-image | encrypt to private dir; plaintext + temp deleted | TODO |
| 5 | F08-T05 | Documents list + stream | «مستنداتي»; reactive | TODO |
| 6 | F08-T06 | Search | by title | TODO |
| 7 | F08-T07 | Category filters | المواعيد/الفواتير/الحكومية/التعليمية/أخرى | TODO |
| 8 | F08-T08 | Document details | full record view | TODO |
| 9 | F08-T09 | Notes | add/edit/delete «ملاحظتي» | TODO |
| 10 | F08-T10 | Update | title/category | TODO |
| 11 | F08-T11 | Delete (+ linked reminder) | confirm; cascade/handle linked reminder | TODO |

## Exit DoD
Save → Home + list update; image encrypted, plaintext deleted; delete cascades correctly; no cloud upload.
