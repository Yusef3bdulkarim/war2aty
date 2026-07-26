# F05 · Analysis Contract + Mock

- **Branch:** `feature/analysis-contract` · **Milestone:** M3
- **Depends on:** F04 · **Feeds:** F06 (implements contract), F07 (domain analysis)
- **Progress:** 9 / 9 DONE

JSON Schema v1, hand-written DTOs, mappers, validator, fixtures, and a DI-selected mock datasource. Contract-first — locked before Groq.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F05-T01 | JSON Schema v1 — request | documented in `docs/API_CONTRACT.md` (§29) | DONE |
| 2 | F05-T02 | JSON Schema v1 — response | documented (§30) incl. error contract | DONE |
| 3 | F05-T03 | Request DTOs | hand-written `fromJson`/`toJson`; no codegen | DONE |
| 4 | F05-T04 | Response DTOs | hand-written `fromJson`/`toJson` | DONE |
| 5 | F05-T05 | Domain models | `DocumentAnalysis` + parts (dates/amounts/info/warnings…) | DONE |
| 6 | F05-T06 | Mappers | DTO → domain | DONE |
| 7 | F05-T07 | Local validator | schema version, confidence→UI band, safe parse; no crash on missing field | DONE |
| 8 | F05-T08 | Fixtures ×6 | invoice/appointment/gov/exam/partial/unsupported | DONE |
| 9 | F05-T09 | Mock datasource + repository | DI-selected; error mapping; parse tests | DONE |

## Exit DoD
Request built from OCR; mock returns fixtures; DTO/domain/UI separated; parse+validation tested; result screen consumes it.
