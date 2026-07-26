# F06 · Backend + Groq

- **Branch:** `feature/analysis-backend` · **Milestone:** M4
- **Depends on:** F01 (session/JWT), F05 (contract) · **Feeds:** F07 (real data), Home (usage)
- **Progress:** 2 / 14 DONE

Real Supabase Edge Functions run **locally via Docker** (`supabase start` / `functions serve`), real Groq provider. **Blocker checklist before start:** Docker + Supabase CLI + Deno installed; obtain a Groq API key (into Supabase secrets / `.env` only — never Flutter/git). Tests stay fixture-backed (deterministic).

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F06-T01 | Local stack + config | `supabase start` runs; `config.toml`; Docker verified | DONE |
| 2 | F06-T02 | Migrations | `analysis_usage_daily`, `analysis_attempts`, `app_runtime_config` + RLS (no client policies) | DONE |
| 3 | F06-T03 | require-user JWT | rejects missing/invalid anon JWT before logic | TODO |
| 4 | F06-T04 | HTTP scaffolding | cors / response / request-id | TODO |
| 5 | F06-T05 | Error codes + `ApiError` | codes per §48 | TODO |
| 6 | F06-T06 | Daily-limit check | Africa/Cairo day boundary | TODO |
| 7 | F06-T07 | Atomic slot reservation | reserve→finalize/release; `expires_at`; race-safe | TODO |
| 8 | F06-T08 | Runtime-config service | reads `app_runtime_config` (kill-switch, limits) | TODO |
| 9 | F06-T09 | Groq client | calls Groq with timeout | TODO |
| 10 | F06-T10 | Prompts | system + analysis prompts per §33 | TODO |
| 11 | F06-T11 | Groq provider + structured output | `AiAnalysisProvider`; JSON schema-constrained | TODO |
| 12 | F06-T12 | Backend validation pipeline | number/date/source/business verification; invalid → needsReview | TODO |
| 13 | F06-T13 | Endpoints + Deno tests | analyze-document/get-usage/health; unit+integration tests | TODO |
| 14 | F06-T14 | Flutter real datasource + DI swap | Dio interceptors; dev flavor → localhost; flip mock→real | TODO |

## Exit DoD
Local end-to-end real analysis; usage enforced atomically; failed analysis not counted; Deno tests green; no secrets in Flutter/git; no doc content in logs.
