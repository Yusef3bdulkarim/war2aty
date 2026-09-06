# Contributing to War2aty

Thank you for your interest in contributing to War2aty! This document outlines the development workflow and code standards.

## Development Setup

1. **Clone the repo** and install Flutter SDK (stable channel, ≥ 3.11).
2. **Copy config files:**
   ```bash
   cp config/prod.json.example config/prod.json
   cp android/key.properties.example android/key.properties
   ```
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

## Commit Messages

Use conventional commits:

```
feat(capture): add live edge detection overlay
fix(ocr): handle empty Azure response gracefully
test(analysis): add extractor tests for invoice dates
docs(readme): update architecture diagram
chore(deps): bump supabase_flutter to 2.16.0
```

## Privacy Rules (Non-Negotiable)

- Never log OCR text, AI prompts/responses, or personal data.
- Never store images on any server beyond the processing window.
- Never mention third-party provider names (Azure, Google, Groq) in user-facing text.
- All API keys stay in Supabase Secrets — only the publishable anon key is in the app.

## Branch Strategy

- `main` — production-ready code
- `develop` — integration branch
- `feature/*` — feature branches (branch from `develop`, PR back to `develop`)

## Questions?

Open an issue or reach out to the maintainer.
