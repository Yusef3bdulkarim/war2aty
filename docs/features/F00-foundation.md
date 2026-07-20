# F00 · Foundation

- **Branch:** `feature/project-setup` · **Milestone:** M0–M1
- **Depends on:** — · **Feeds:** everything
- **Progress:** 17 / 17 DONE

Substrate for the whole app: flavors, kernel types, theme, localization, navigation, DI, DB skeleton.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F00-T01 | Git init + harden ignore | repo init; `main`+`develop`; secrets/`.env`/build artifacts ignored; initial commit | DONE |
| 2 | F00-T02 | Flavors + entrypoints + env | `dev`/`prod` boot; `AppEnvironment` exposes placeholder Supabase URL/key + flavor name | DONE |
| 3 | F00-T03 | Lints + quality-gate script | strict lints (no `print`, prefer_const); `tool/check` runs format→analyze→test, non-zero on fail | DONE |
| 4 | F00-T04 | `Result<T,F>` | sealed Ok/Err; map/fold/when; zero deps; unit-tested | DONE |
| 5 | F00-T05 | `AppFailure` hierarchy | sealed base + local/network/business subtypes (§47); exhaustiveness test | DONE |
| 6 | F00-T06 | `AppLogger` (privacy-safe) | logs only allowed fields (§51); never emits doc content; unit-tested | DONE |
| 7 | F00-T07 | Color + spacing tokens | exact Waraqti hex + spacing scale; light + high-contrast variants | DONE |
| 8 | F00-T08 | Cairo typography + assets | Cairo 400–800 bundled; text styles; renders offline | DONE |
| 9 | F00-T09 | Theme assembly | `ThemeData` light + high-contrast wired to tokens/typography | DONE |
| 10 | F00-T10 | `AppStrings` + AR/EN | abstract interface; both impls define every key (compiler-enforced); parity test | DONE |
| 11 | F00-T11 | Localization delegate + locale + direction | resolves AR/EN; `LocaleController` switch; direction follows locale (RTL/LTR); persisted | DONE |
| 12 | F00-T12 | Router + bottom-nav shell | go_router 4 destinations; RTL-correct back nav | DONE |
| 13 | F00-T13 | DI container | get_it registers logger/db/localization/router; modules pattern | DONE |
| 14 | F00-T14 | Drift skeleton + core tables | `AppDatabase` + `app_settings` + `usage_cache` + migration v1 (doc/reminder tables deferred) | DONE |
| 15 | F00-T15 | Test harness | `pumpApp()` wrapper (theme+locale+direction+DI); core fakes | DONE |
| 16 | F00-T16 | Bootstrap wiring → empty shell | `MaterialApp.router`; boots to empty Home in AR(RTL) & EN(LTR); 4 placeholder tabs | DONE |
| 17 | F00-T17 | M0 gate + commit | format clean · analyze 0 · test green; commit → merge `develop` | DONE |

## Exit DoD
App launches (dev) to empty 4-tab shell, correct in AR(RTL) + EN(LTR), theme/Cairo applied; Result/AppFailure/logger/DI/Drift/localization in place and unit-tested; gate green. No feature UI / OCR / Supabase yet.
