# F01 · Bootstrap & Identity

- **Branch:** `feature/app-bootstrap` · **Milestone:** M2 (basics) / M4 (real Supabase)
- **Depends on:** F00, Supabase(M4) · **Feeds:** F06 (JWT), F09 (reconcile), Home (usage)
- **Progress:** 10 / 10 DONE

Anonymous identity, installation id, and the launch orchestration. Real Supabase parts land at M4; until then interfaces + local stubs.

**M4 status:** the real implementations landed in **F06-T14** — `SupabaseAuthRepository` replaces the stub for T03/T04, and `RemoteUsageRepository` (`get-usage`) replaces it for T10. The stubs stay registered only for an unconfigured build.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F01-T01 | Secure-storage wrapper | `SecureStorageService` read/write/delete; keyed; tested with fake | DONE |
| 2 | F01-T02 | Installation ID | UUID v4 generated once, persisted, stable across launches | DONE |
| 3 | F01-T03 | Anonymous session sign-in | `AuthRepository.signInAnonymously` (stub now, real Supabase @M4) | DONE |
| 4 | F01-T04 | Session recovery/refresh | existing session restored; refresh on expiry | DONE |
| 5 | F01-T05 | `InitializeApp` orchestrator | runs ordered init steps; returns Result; exposes current stage | DONE |
| 6 | F01-T06 | Bootstrap stage/error UI | splash shows progress; error state with retry | DONE |
| 7 | F01-T07 | Runtime-config loader | loads config (local defaults: analysisEnabled, dailyLimit, maxOcrChars, timeout, schemaVersion) | DONE |
| 8 | F01-T08 | Temp-file launch cleanup | stale `analysis_sessions` deleted on launch | DONE |
| 9 | F01-T09 | Notification reconcile hook | calls `ReminderScheduler.reconcile` on launch (no-op until F09) | DONE |
| 10 | F01-T10 | Usage sync | `get-usage` → `usage_cache` (stub until M4) | DONE |

## Exit DoD
App boots through the orchestrator; anonymous identity + installationId established (real at M4); no secrets in code; failures surfaced with retry.
