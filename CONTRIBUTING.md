# Contributing to War2aty

Thank you for your interest in contributing to War2aty! This document outlines the development workflow and code standards.

## Development Setup

1. **Clone the repo** and install the Flutter SDK. CI pins **3.41.9**
   (`.github/workflows/ci.yml`); match it, or expect to meet differences
   CI will not.
2. **Copy config files.** Neither is needed to run the dev flavor — its
   Supabase URL and key are compiled in — so do this when you need a prod
   build:
   ```bash
   cp config/prod.json.example config/prod.json
   cp android/key.properties.example android/key.properties
   ```
   `storeFile` in `key.properties` resolves relative to `android/app/`, and a
   **prod release build fails** without a usable key rather than falling back
   to the debug one (`docs/BUILD.md`).
3. **Install dependencies:**
   ```bash
   flutter pub get
   ```
4. **Run in development mode:**
   ```bash
   flutter run --flavor dev -t lib/main_dev.dart
   ```

## Architecture Rules

This project follows **Feature-based Clean Architecture**. Every change must respect these boundaries:

| Layer | Responsibility | Can depend on |
|-------|---------------|---------------|
| `presentation/` | UI, Cubits, state observation | Domain only |
| `domain/` | Entities, use cases, repo interfaces | Nothing (pure Dart) |
| `data/` | API calls, DTOs, DB, repo impls | Domain interfaces |

- **Domain is pure Dart** — no Flutter, Supabase, Drift, or plugin imports.
- **Cubits depend on Use Cases only** — never on repositories or data sources directly.
- **Shared code** goes in `core/` — check before creating duplicates.

## State Management

- **Cubit/Bloc only** — no Riverpod, Provider, or GetX.
- Cubit states use **sealed classes** (Dart 3 pattern matching), not Freezed.
- No `BuildContext` inside a Cubit.

## Code Generation

- `build_runner` is allowed **only for Drift** (database schema).
- `json_serializable` and Freezed are **forbidden** — write `fromJson`/`toJson` manually.

## Error Handling

- Data layer catches exceptions → converts to `AppFailure` (sealed class).
- Use Cases return `Result<T, AppFailure>` — never throw.
- Presentation converts failures to Arabic user-facing messages.

## Quality Checklist

Before submitting a PR, ensure **all three pass**:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

- Every bug fix must include a reproducing test.
- New screens must support RTL, Large Text, and have explicit loading/empty/error states.
- No PII (names, amounts, dates, OCR text) in log statements.

If you touched `supabase/`, the backend half too — CI runs it either way:

```bash
deno test --allow-env --allow-net supabase/tests
```

The integration tests skip themselves without a running stack. To actually run
them, `supabase start`, then export `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
`SUPABASE_SERVICE_ROLE_KEY` from `supabase status -o env`. A migration should
never be pushed without having run them for real.

## Commit Messages

Use conventional commits:

```
feat(capture): add live edge detection overlay
fix(ocr): fall back to the device only on the four allowed failures
test(analysis): add extractor tests for invoice dates
docs(readme): update architecture diagram
chore(deps): bump supabase_flutter to 2.16.0
```

## Privacy Rules (Non-Negotiable)

These are the project's hardest rules. `CLAUDE.md` §7 is authoritative; this is
the short version.

- **Never log** OCR text, AI prompts or responses, amounts, dates, names, or a
  raw installation id. The logger takes a closed set of fields and has no
  free-form message, by design.
- **Never name a provider in user-facing text** (Gemini, Mistral, Groq — or any
  future one). Naming them in code comments and docs is fine and encouraged;
  the ban is on copy a user can read.
- **Never claim nobody sees the image or the text.** We do not store either on
  our servers and do not log them, and the image is only kept **on the phone**
  with the user's consent — but every provider runs on a free tier whose terms
  permit retention and human review, so the app says so plainly instead of
  promising otherwise. An unscoped "not saved" is also banned: say who.
- **All API keys stay in Supabase Secrets.** Only the publishable key belongs in
  the app. No secret in Flutter, `config.toml`, a dart-define or any committed
  file.

Three test suites enforce this rather than trusting review, and they will fail
your PR:

- `test/core/localization/app_strings_test.dart` — every `AppStrings` member,
  both languages: no provider names, no retired claims.
- `test/app/native_permission_copy_test.dart` — the same rules applied to the
  iOS permission prompts and the Android manifests, read off disk.
- `test/core/logging/error_report_codes_test.dart` — the error codes the app may
  report must match the ones the backend accepts, in both directions.

## Branch Strategy

- `main` — production-ready code
- `develop` — integration branch
- `feature/*` — feature branches (branch from `develop`, PR back to `develop`)

## Questions?

Open an issue or reach out to the maintainer.
