# War2aty — Feature Task Index

This folder holds the **task breakdown for every feature**, one file per feature.
The master specification is [`../.claude/doc/war2aty_product_engineering_master_plan.md`](../../.claude/doc/war2aty_product_engineering_master_plan.md).

## How to use
- Reference tasks as **"task N of feature XX"** → task `FXX-T0N` inside that feature's file.
- Task IDs are **per-feature** (`F00-T01`, `F01-T03`, …).
- **Rule:** when a task is completed, its row is marked **DONE** in the feature file **before** starting the next task.

## Status legend
`TODO` · `WIP` · `DONE` · `BLOCKED`

## Feature files

| Code | Feature | File | Branch | Milestone | Tasks |
|---|---|---|---|---|---|
| F00 | Foundation | [F00-foundation.md](F00-foundation.md) | `feature/project-setup` | M0–M1 | 17 |
| F01 | Bootstrap & identity | [F01-bootstrap-identity.md](F01-bootstrap-identity.md) | `feature/app-bootstrap` | M2/M4 | 10 |
| F02 | Onboarding & Home | [F02-onboarding-home.md](F02-onboarding-home.md) | `feature/onboarding-home` | M2 | 11 |
| F03 | Capture & review | [F03-capture-review.md](F03-capture-review.md) | `feature/scan-to-text` | M2 | 10 |
| F04 | Local OCR | [F04-local-ocr.md](F04-local-ocr.md) | `feature/scan-to-text` | M2 | 13 |
| F05 | Analysis contract + mock | [F05-analysis-contract.md](F05-analysis-contract.md) | `feature/analysis-contract` | M3 | 9 |
| F06 | Backend + Groq | [F06-backend-groq.md](F06-backend-groq.md) | `feature/analysis-backend` | M4 | 14 |
| F07 | Analysis result | [F07-analysis-result.md](F07-analysis-result.md) | `feature/analysis-result` | M3/M5 | 14 |
| F08 | Saved papers | [F08-saved-papers.md](F08-saved-papers.md) | `feature/saved-papers` | M6 | 11 |
| F09 | Reminders | [F09-reminders.md](F09-reminders.md) | `feature/reminders` | M7 | 14 |
| F10 | Audio reader | [F10-audio-reader.md](F10-audio-reader.md) | `feature/audio-reader` | M8 | 8 |
| F11 | Settings & privacy | [F11-settings-privacy.md](F11-settings-privacy.md) | `feature/settings` | M8 | 12 |
| F12 | Hardening & release | [F12-hardening-release.md](F12-hardening-release.md) | `feature/hardening` | M9 | 12 |

**Total: 145 tasks across 13 features.**

## Critical path
`F00 → F03 → F04 → F05 → F06 → F07` (sequential). F02/F08/F09/F10/F11 hang off F07 and parallelize.
