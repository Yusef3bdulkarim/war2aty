# F13 · OCR Provider Migration (Azure + Google)

- **Branch:** `feature/ocr-provider-migration` · **Milestone:** post-M6
- **Depends on:** F04 (local OCR — Tesseract/extractors kept as offline fallback), F06 (backend + Groq — extended, not replaced) · **Feeds:** all future analysis quality
- **Progress:** 9 / 19 DONE

Replaces Tesseract as the primary OCR engine with Azure AI Document Intelligence (Read model); keeps Tesseract as an **offline-only** fallback; adds Google Document AI as a conditional second opinion when Azure is missing/invalid/low-confidence on a critical field; Groq stays the final classify/explain step, never shown the raw image, never allowed to invent or correct dates/amounts/times/phones/reference numbers. This is a privacy-model change (the image now transits the Edge Function to reach Azure/Google) — user-facing copy and `CLAUDE.md` are updated accordingly, never naming a provider, never claiming the image doesn't reach AI. All architectural decisions below were resolved with the user in a dedicated planning session (2026-07-30) and are fixed constraints, not open questions, for implementation.

## Locked decisions

1. **Two pipelines, not one swapped engine.** Online: capture → rotate (existing) → perspective-correct (new) → quality-check (existing) → image → Edge Function → Azure Read → server-side extraction/validation → conditional Google second opinion → Groq → response. Offline/fallback: genuine no-connectivity only (proactive check, not reactive-off-Dio-failure) — identical to today (Tesseract → Dart extractors → text+candidates → Edge Function → Groq only).
2. A failed-while-online call never silently falls back to Tesseract — it fails, user retries.
3. Azure's analyze result is explicitly deleted right after reading it (24h default retention otherwise). Google's *synchronous* `process` API only — never the batch/GCS-backed async API.
4. Google second-pass = whole-document resend (no region-cropping) for v1.
5. Groq sees per-field verification metadata and is prompted to hedge — but pipeline-computed `needsUserReview`/`confidence` always wins for the actual UI, never Groq's self-reported value.
6. Wire schema: `dates[]`/`amounts[]`/new `phones[]`/`references[]` gain `rawValue: string`. `verificationStatus` stays backend-only.
7. Privacy copy rewritten, not removed — no naming Azure/Google/Groq, no "image never reaches AI" claim (false). Approved framing: "we read the text using secure processing, but never save the image, no person ever sees it."
8. New global spend/call-count circuit breaker (config kill-switch), in scope now. Per-user daily limit stays 3/day.
9. New branch off `develop` via worktree, independent of `feature/saved-papers`. New doc (this file), not a reopening of F04/F06.
10. Perspective correction via `doclens` (pub.dev), used only for `detectInImage()`/crop — never its camera UI (no RTL support). Behind a new `PerspectiveCorrector` interface. Existing capture screen UI untouched.
11. Connectivity routing is proactive (`connectivity_plus`), used only to pick the pipeline before processing starts — never trusted as a reachability guarantee.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F13-T01 | Branch + doc scaffold | Worktree branch `feature/ocr-provider-migration` off `develop`; this doc + README row added | DONE |
| 2 | F13-T02 | Global spend/call-count circuit breaker | `global_daily_call_cap` config key (null = unlimited, fails **open**) + global counter checked atomically **inside** `reserve_analysis_slot`, not as a pre-check before `withReservedSlot` — a separate global check would reintroduce the read-then-reserve race F06-T07 rejected; mirrored `GLOBAL_CAPACITY_REACHED` code → `GlobalCapacityReachedFailure`; unit + concurrent integration tests for firing, release and reset | DONE |
| 3 | F13-T03 | Azure/Google secrets + dark kill-switch | `AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT`/`KEY`, Google service-account env vars, hard-fail-on-missing; new `azureOcrEnabled` flag defaults `false` | DONE |
| 4 | F13-T04 | Azure Document Intelligence client | Hand-rolled `fetch` (no SDK): submit → poll → read → mandatory delete in `finally`; tests cover poll-timeout, non-2xx, delete-called-exactly-once | DONE |
| 5 | F13-T05 | Port field extractors to TypeScript | Mirrors the 5 existing Dart extractors field-by-field; shared fixtures where practical; one behavior per test | DONE |
| 6 | F13-T06 | Per-field validation/confidence (Azure-only) | Computes `verificationStatus` (verified/unverified/conflicting, backend-only) + confidence; tests for all three statuses | DONE |
| 7 | F13-T07 | Google Document AI client | Service-account JWT auth; synchronous `process` API only, whole-document resend; test asserts batch/GCS endpoint never referenced | DONE |
| 8 | F13-T08 | Cross-provider validator | Decides when to call Google, merges Azure+Google, produces `needsUserReview`; wired as a peer input into existing `validateAnalysis()` | DONE |
| 9 | F13-T09 | Request/response contract v2 | New image-intake path; allow-list + privacy doc-comment consciously rewritten; `rawValue` added to date/amount responses; new typed `phones[]`/`references[]`; `ANALYSIS_SCHEMA_VERSION` bumped | DONE |
| 10 | F13-T10 | Groq prompt/schema extension | Groq receives per-field confidence/`needsUserReview` (never the image), instructed to hedge without inventing/correcting values | TODO |
| 11 | F13-T11 | `analyze-document` image-route wiring | Branches on request shape; image path gated behind `azureOcrEnabled` + `analysisEnabled`; text-only branch proven byte-for-byte unaffected | TODO |
| 12 | F13-T12 | `PerspectiveCorrector` interface + `doclens` adapter | Interface + impl using only `detectInImage()`/crop, never `doclens`'s camera UI; swappable via fake in tests | TODO |
| 13 | F13-T13 | Connectivity-aware routing decision | Proactive-only check (no network call) returns an `AnalysisRoute` enum; DI registered; tests cover both branches | TODO |
| 14 | F13-T14 | Online image-analysis domain/data layer | New image-carrying request entity, `AnalysisRepository.analyzeImage()`, new datasource (Dio multipart or documented base64) | TODO |
| 15 | F13-T15 | Capture-flow routing wiring | Offline → unchanged `OcrProcessingCubit`; online → `PerspectiveCorrector` then new use case, skipping OCR entirely; existing capture UI untouched | TODO |
| 16 | F13-T16 | No-silent-fallback guarantee | Once online is chosen, any failure maps to retry-only, never invokes `OcrEngine`/Tesseract; tests assert Tesseract never constructed on a failed-online run | TODO |
| 17 | F13-T17 | `rawValue` wire-through + confidence-parity test | `rawValue` added to date/amount entities; new phone/reference entities; `verificationStatus` proven absent from every Flutter-facing type | TODO |
| 18 | F13-T18 | Privacy copy + CLAUDE.md update | `privacyPointTextOnly` and siblings reworded, no provider names; `CLAUDE.md` §7/Project Context updated; README totals/critical-path updated | TODO |
| 19 | F13-T19 | End-to-end verification + kill-switch flip | Real Azure + Google sandbox run through the full pipeline incl. a Google-second-opinion case and a `needsUserReview: true` case; Azure delete verified via follow-up GET; only then `azureOcrEnabled` flipped on | TODO |

## Exit DoD
Online path fully wired with real Azure/Google sandbox verification passing. Offline path byte-for-byte unchanged. A failed-while-online call never silently falls back to Tesseract (T16 test-enforced). Privacy copy and `CLAUDE.md` no longer claim the image never leaves the device, never name a provider. Global spend circuit breaker live before Azure/Google are reachable by any client build. `dart format .` / `flutter analyze` / `flutter test` and the Deno equivalents all pass.
