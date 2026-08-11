# CLAUDE.md — Project

<!--
Global rules are in ~/.claude/CLAUDE.md — don't repeat them here.
Only project-specific overrides and Flutter rules go here.
The binding specification is: .claude/doc/war2aty_product_engineering_master_plan.md
When this file and the master plan disagree, the master plan wins.
-->

# Project Context
- **App:** "What Does My Paper Say?" (War2aty) — the user photographs a printed document, and the app extracts the text locally (OCR) and explains it to them: the document type, its key points, what's required of them, and any dates that need a reminder.
- **Market / Users:** Egypt — the average Egyptian user (with consideration for the elderly and those with reading/vision difficulties). Simple Egyptian dialect.
- **Platforms:** Android + iOS only. Portrait only. No Tablet/Web in the MVP.
- **Language / Direction:** Fully Arabic UI, fully **RTL**. The document itself may be Arabic/English/mixed.
- **Backend:** Supabase Edge Functions (TypeScript/Deno) + Supabase Postgres (usage counter only). **No Firebase.** AI: Groq Structured Output behind the Edge Function.
- **Auth:** Supabase **Anonymous Auth** — no visible login screen. Technical identity only, to protect the service + `installationId` in `flutter_secure_storage`.
- **Privacy (non-negotiable):** The document photo **never leaves the phone**. Only the extracted text is sent. Default save = "result only". No automatic reminders without user review. Document contents are never logged.
- **Local data:** Drift + SQLite (local source of truth), optional encrypted images (AES-256-GCM) inside the Application Private Directory, Local Notifications, Local TTS.
- **Usage limit:** 3 successful smart analyses per day (configurable from Backend runtime config), calculated per `Africa/Cairo` day.
- **Status:** Brand-new MVP from scratch. Implementation is **Vertical-Slice-first** (a complete electricity-bill path), then feature expansion. Not all screens are built at once.

---

# Design System (Waraqti.dc.html) — MANDATORY reference

- **Approved design source:** Claude Design project `Waraqti.dc.html` (imported via DesignSync / MCP). This **supersedes** any old reference to "Casaback" or "Stitch".
- **Font:** Cairo (weights 400–800).
- **Colors:**
  - Brand teal `#0E7C86` · Deep teal `#0A5C64`
  - Ink `#1D2B30` · Secondary text `#5A686E` · Muted `#8A969B`
  - Surfaces (warm off-white): `#E9E6DF` · `#F5F4EF` · `#F2EFE8`
  - Success `#2E9E63` / mint `#34D0B4` · Warning amber `#C77B12` on `#FBEFD8` · Error `#C4362A` on `#FBECEA`
- **Before building any screen/Widget:** match the corresponding design screen precisely — colors, spacing, typography, and states (empty / loading / error / partial).
- **If no design exists for a screen:** stop, tell the user which screen is missing, and wait for the design before writing any UI.
- **Never rely on color alone** to convey state (accompanying text/icon). Large buttons, readable text, support for Large Text and High Contrast.

---

# Section B — Flutter / Dart Specific Rules

<!--
Follow official Dart style guide, Effective Dart, and flutter_lints defaults.
Rules below only cover things that OVERRIDE defaults or encode project decisions.
-->

## 1) Architecture (Feature-Based Clean Architecture)
- Layers: `presentation → domain → data`. Never cross boundaries or mix responsibilities.
- Domain is **completely free of any Flutter/Supabase/Drift/Dio/OCR plugin imports**.
- Code shared across features lives in `core/` or `shared/` — no random cross-feature imports.

## 2) State Management
- **Cubit/Bloc** only — no Riverpod/Provider/GetX.
- Cubits depend on **Use Cases only** — never repositories/data sources/Dio/SQL/Supabase/OCR directly.
- No `BuildContext` inside a Cubit. No single app-wide Cubit.
- `setState` for local UI state only (toggles, focus), scoped to the smallest possible Widget.

## 3) Code Generation — Drift ONLY (strict; narrows global "no build_runner" rule)
- `build_runner` is allowed **exclusively for Drift** (schema/DAOs). Nothing else.
- **`json_serializable` is forbidden** — every DTO writes `fromJson`/`toJson` **manually** (no `.g.dart` files for DTOs).
- **Freezed is forbidden.** Use `sealed class` + pattern matching (Dart 3) for all Cubit states and domain unions (Failures, analysis stages, result variants). Entities/UI models are manually written immutable classes.

## 4) Feature Folder Structure
```
features/{feature_name}/
├── data/         (datasources, models[DTOs], mappers, repositories impl)
├── domain/       (entities, repositories[interfaces], usecases)
└── presentation/ (cubit, screens, widgets, models[UI models])
```

## 5) Error Handling Contract
- Data layer: catch exceptions and convert them into a classified `AppFailure` (`sealed class AppFailure`).
- Domain/Repositories/Use cases: return **`Result<T, AppFailure>`** — never throw Exceptions upward.
- Presentation: convert the Failure into an appropriate Arabic message and UI state. Never rely on the English error text coming from the server.

## 6) Dependency Injection
- **`get_it`** as the service locator. Registration lives in `app/dependency_injection/` (modules).
- Cubits/UseCases/Repositories are resolved via `get_it`, never manually.

## 7) Privacy & Security (hard rules)
- Never send an image/thumbnail/EXIF/GPS to the Backend — **OCR text + candidates only**.
- No secrets inside Flutter/Git (Groq key and Service Role live only in Supabase Secrets; only the Publishable key is allowed in the app).
- Never log OCR text, prompts, AI responses, or numbers/amounts/names.
- Saved images are encrypted; unencrypted copies and temp files are deleted once processing finishes.
- Never present an unconfirmed date/amount/number as fact — use "verify this info / unconfirmed reading". Confidence is per-field, not per-document.

## 8) Build Method Discipline
- Prefer `const`. Don't create `TextEditingController`/`AnimationController`/`FocusNode` inside `build()`; dispose of them in `dispose()`.
- Keep heavy operations (image processing / OCR / encryption / large JSON parsing) off the UI thread as much as possible.
- `BlocBuilder`/`BlocSelector` on the smallest Widget that needs the state, not higher up the tree.

## 9) OCR & Analysis boundaries
- OCR sits behind an `OcrEngine` interface (Tesseract first, PaddleOCR as alternative) — the engine is never called directly from a Cubit/Widget.
- Contract before Integration, Mock before the real service: the result screen is built against a Mock analyze-document before wiring up Groq.
- Real analysis flows exclusively through the Supabase Edge Function — the app never knows or calls Groq directly.

## 10) Testing & Quality Gate (before any task is "done")
```
dart format .
flutter analyze
flutter test
```
- Tests for domain/data (extractors, mappers, validators, cubits). Every bug fix must include a test that reproduces it.
- RTL and Large Text support for any new screen. Explicit Loading/Empty/Error/Partial states.