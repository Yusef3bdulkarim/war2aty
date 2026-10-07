# F12 · Hardening & Release — **SUPERSEDED by F27 (2026-10-05)**

> **Closed, not finished.** F27 (production readiness) took this feature's
> remaining scope, by the owner's answer to F27's Q7. T01 and T02 stay DONE;
> **T03–T12 are not to be worked here** — see
> [F27-production-readiness.md](F27-production-readiness.md), whose "What F12
> leaves behind" section maps each one to its F27 task and records the single
> item (T08, the OCR regression dataset) that is deliberately deferred past
> launch rather than carried over.

- **Branch:** `feature/hardening` · **Milestone:** M9
- **Depends on:** all · **Feeds:** — (terminal)
- **Progress:** 2 / 12 DONE, the rest superseded

Cross-cutting sweeps against the Definition-of-Done (§16) and store readiness.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F12-T01 | Accessibility audit | semantics, tap targets, contrast | DONE |
| 2 | F12-T02 | RTL audit | Arabic layouts correct throughout | DONE |
| 3 | F12-T03 | LTR audit | English layouts correct throughout | TODO |
| 4 | F12-T04 | Large-text pass | no overflow at largest text size | TODO |
| 5 | F12-T05 | Performance profiling | heavy work off UI thread; jank check | TODO |
| 6 | F12-T06 | Cache cleanup verification | temp/session files reliably removed | TODO |
| 7 | F12-T07 | Security review | no secrets; no doc content in logs; encryption verified | TODO |
| 8 | F12-T08 | OCR regression dataset | labeled set + runner; baseline recorded | TODO |
| 9 | F12-T09 | Integration test: invoice | capture→OCR→analyze→result→reminder→save→home | TODO |
| 10 | F12-T10 | Integration test: appointment + failure | medical warning path + AI-timeout OCR-only path | TODO |
| 11 | F12-T11 | Android release build | signed build; permissions correct | TODO |
| 12 | F12-T12 | iOS build + release prep | build + privacy policy + store assets + crash handling | TODO |

## Exit DoD
Real-device pass on Android + iOS; no blocker bugs; DoD §16 satisfied; store-ready.

## Notes
- **F12-T01**: findings, fixes, and deferred items — see
  [F12-T01-accessibility-audit.md](F12-T01-accessibility-audit.md).
- **F12-T02**: findings, fixes, and deferred items — see
  [F12-T02-rtl-audit.md](F12-T02-rtl-audit.md).
