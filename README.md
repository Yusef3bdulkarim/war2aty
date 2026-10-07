<p align="center">
  <img src="assets/app_icon.png" width="120" alt="War2aty app icon" />
</p>

<h1 align="center">ورقتي — War2aty</h1>

<p align="center">
  <strong>«ورقتي بتقول إيه؟»</strong><br/>
  صوّر أي ورقة مطبوعة، والتطبيق يقرأها ويشرحلك بالعربي البسيط.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.41.9-02569B?logo=flutter&logoColor=white" alt="Flutter 3.41.9" />
  <img src="https://img.shields.io/badge/Dart-%5E3.11.5-0175C2?logo=dart&logoColor=white" alt="Dart ^3.11.5" />
  <img src="https://img.shields.io/badge/Platform-Android%20first%20%C2%B7%20iOS%20later-green" alt="Android first, iOS later" />
  <img src="https://img.shields.io/badge/Tests-2%2C263%20Dart%20%C2%B7%20812%20Deno-brightgreen" alt="2,263 Dart and 812 Deno tests" />
  <img src="https://img.shields.io/badge/License-All%20Rights%20Reserved-lightgrey" alt="All rights reserved" />
</p>

---

## About

A mobile app that photographs a printed document, extracts its text, and
explains it in simple **Egyptian Arabic** — written for people who struggle
with formal paperwork, including the elderly and those with limited reading
ability.

The user takes a photo; the app reads the text (on the phone when offline, or
through a reader service when online), then classifies and explains it:
what kind of paper it is, the key information, what is required of them, and
which dates are worth a reminder.

The interface is **Arabic and fully RTL**, portrait only. The document itself
may be Arabic, English or mixed.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 📸 **Smart capture** | Live camera with document edge detection and auto-crop |
| 🔍 **Dual OCR** | Online when connected; on-device Tesseract when offline, or as an explicit, flagged fallback for four specific online failures |
| 🤖 **Analysis** | Classifies the document, extracts key fields, and says what action is needed — in Egyptian Arabic, with per-field confidence |
| 🔊 **Audio reader** | Text-to-speech reads the extracted text or narrates the whole result |
| 💾 **Saved papers** | Browse, search and filter past documents, stored locally |
| ⏰ **Reminders** | Local notifications for deadlines found in a document — never scheduled without the user reviewing them |
| 🔒 **Privacy-first** | Nothing is stored on our servers, and the app states plainly what a free-tier provider may see rather than promising otherwise |
| ♿ **Accessible** | Large touch targets, RTL-first, high contrast, Large Text, reduced motion |

---

## 🏗️ Architecture

**Feature-based Clean Architecture**, with a strict three-layer separation per
feature and no cross-feature imports.

```
lib/
├── app/              # DI, routing, the 4-tab shell
├── core/             # Shared: database, network, crypto, logging, localization, time, …
└── features/
    ├── analysis/     # Classification and explanation
    ├── audio_reader/ # Text-to-speech
    ├── bootstrap/    # Splash and launch sequence
    ├── capture/      # Camera, edge detection, crop
    ├── home/         # Main screen
    ├── ocr/          # Text extraction, online and on-device
    ├── onboarding/   # First-launch consent flow
    ├── reminders/    # Deadline notifications
    ├── saved_papers/ # History and details
    └── settings/     # Permissions, privacy, about
```

Each feature:

```
feature/
├── data/           # Data sources, DTOs, mappers, repository impls
├── domain/         # Entities, repository interfaces, use cases
└── presentation/   # Cubit, screens, widgets, UI models
```

The rules that hold it together — domain is pure Dart, cubits depend only on
use cases, `Result<T, AppFailure>` instead of thrown exceptions — are in
[CONTRIBUTING.md](CONTRIBUTING.md).

---

## 🛠️ Tech stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter 3.41.9 · Dart ^3.11.5 (portrait only) |
| **State** | Cubit / Bloc (`flutter_bloc`) — no Riverpod, Provider or GetX |
| **DI** | `get_it`, modular registration |
| **Routing** | `go_router` with shell routes |
| **Local database** | Drift + SQLite — the local source of truth |
| **Backend** | Supabase Edge Functions (TypeScript / Deno) + Postgres for counters only |
| **Auth** | Supabase Anonymous Auth — no sign-in screen |
| **OCR, online** | Gemini Flash-Lite, behind the `ocr-document` function |
| **OCR, on-device** | Tesseract — the offline route, and the explicit fallback for four online failures |
| **Analysis** | Structured Output, text only: Mistral (Ministral) falling back to Groq, behind `analyze-document` |
| **Encryption** | AES-256-GCM for optionally-saved images; `flutter_secure_storage` for keys |
| **Notifications** | `flutter_local_notifications` |
| **TTS** | `flutter_tts` |
| **Camera** | `camera` + `doclens` |

Every upstream service runs on a **free tier**, deliberately and permanently.
Capacity is handled by caps and graceful degradation, never by paying.

No Firebase, no analytics SDK, no third-party crash reporter.

---

## 🔐 Privacy & security

The non-negotiable part of this project. `CLAUDE.md` §7 is authoritative.

**What we guarantee**

- **Nothing is stored on our servers.** Not the image, not the text. The
  database holds usage counters, anonymous identities and error codes — nothing
  from a document.
- **Nothing from a document is ever logged.** The logger accepts a closed set of
  envelope fields and has no free-form message, so content cannot be logged even
  by mistake.
- **Images saved on the phone are encrypted** (AES-256-GCM, app-private
  directory), and only saved at all if the user asks. Temporary files are wiped.
- **The text is sent encrypted**, and only with the user's consent — the consent
  gate blocks the whole path otherwise.
- **No EXIF or GPS** leaves the device.
- **Keys stay server-side.** Only Supabase's publishable key is in the app.

**What we do not claim**

- **Not that nobody sees the image.** When online, the photo goes to an outside
  reader on a free tier whose terms permit keeping it for a while and having
  staff review it. Offline, it is read only on the phone. The app's privacy
  screen says exactly that.
- **Not that nobody reads the text.** It goes to an analysis provider on a free
  tier, under terms we cannot narrow.
- **No user-facing text names a provider**, and none claims an unscoped "not
  saved" — if something is not saved, the copy says *by whom*.

Error reporting (added for launch) sends **only** a closed error code plus an
envelope — app version, stage, a request id — to our own backend. No stack
traces, no messages, no content; the table has no column that could hold any.

Three test suites enforce the copy rules rather than trusting review; see
CONTRIBUTING.md.

---

## ⚙️ Backend

Supabase Edge Functions, each one `Request → Response` behind a shared endpoint
boundary that handles preflight, method checks, the correlation id, error
serialisation and one access-log line.

| Endpoint | Method | Auth | Purpose |
|---|---|---|---|
| `analyze-document` | POST | anon JWT | Classify and explain OCR **text** (never an image) |
| `ocr-document` | POST | anon JWT | Read text from a photo, behind the `online_ocr_enabled` flag |
| `get-usage` | GET | anon JWT | Today's quota, so the UI can say so before capture |
| `report-error` | POST | anon JWT | Allowlisted error codes only |
| `health` | GET | none | Liveness; touches no table |

- **3 successful analyses per user per Cairo day**, tunable from runtime config,
  plus a global daily cap in front of the shared provider quotas.
- **Kill switches** in `app_runtime_config` take effect on the next request:
  `analysis_enabled`, `online_ocr_enabled`, `minimum_app_version`, `daily_limit`,
  `global_daily_call_cap`.
- **RLS is forced with no policies** on every table; only the service role, from
  inside a function, can reach them.
- **Retention runs nightly** (`pg_cron`): attempts 90 days, idle anonymous users
  12 months, error reports 90 days.

Details in [docs/API_CONTRACT.md](docs/API_CONTRACT.md) and
[supabase/README.md](supabase/README.md). Day-to-day operation — switches,
quotas, incidents — is [docs/OPERATIONS.md](docs/OPERATIONS.md).

---

## 🧪 Testing

**2,263 Dart tests** across 231 files, and **812 Deno tests** across 47.

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
deno test --allow-env --allow-net supabase/tests
```

All four run in CI on every pull request. The backend's integration tests skip
themselves without a running stack, so a bare `deno test` stays green and
deterministic; bring up `supabase start` to run them for real.

---

## 🚀 Getting started

### Prerequisites

- Flutter SDK **3.41.9** (the version CI pins)
- Android SDK; Xcode and a Mac for iOS, which is not yet built
- Docker and the Supabase CLI for the local backend
- Deno for the backend tests

### Run

```bash
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart
```

The dev flavor's Supabase URL and key are compiled in and point at the local
stack. To run on a physical device, point it at your machine over the LAN:

```bash
flutter run --flavor dev -t lib/main_dev.dart \
  --dart-define-from-file=config/dev.usb.json
```

Backend, locally:

```bash
supabase start
supabase functions serve --env-file supabase/.env
```

### Build a release

```powershell
./tool/build_release.ps1 -Artifact apk    # or -Artifact aab for Play
```

Use the script rather than typing the command: a release build is a list of
flags that are **silent when forgotten**. A prod release **fails** without a
usable release key instead of quietly signing with the debug one. See
[docs/BUILD.md](docs/BUILD.md).

### Configuration

```bash
cp config/prod.json.example config/prod.json      # Supabase URL + publishable key
cp android/key.properties.example android/key.properties
cp supabase/.env.example supabase/.env            # provider keys, local only
```

`config/prod.json` carries no secret — the publishable key is the one key the
client is allowed to hold. Provider keys live in Supabase Secrets and
`supabase/.env`, which is git-ignored and must stay that way.

---

## 📚 Documentation

| Document | What it covers |
|---|---|
| [CONTRIBUTING.md](CONTRIBUTING.md) | Architecture rules, quality gate, privacy rules |
| [docs/BUILD.md](docs/BUILD.md) | Release builds, signing, obfuscation, symbols, Gradle memory |
| [docs/OPERATIONS.md](docs/OPERATIONS.md) | Kill switches, quotas, the inactivity pause, incident runbooks |
| [docs/API_CONTRACT.md](docs/API_CONTRACT.md) | Request/response shapes and the error-code vocabulary |
| [supabase/README.md](supabase/README.md) | Backend internals, tables, quota mechanics |
| [docs/features/](docs/features/) | 30 feature plans, each with its task table and decision record |

---

## 📄 License

All rights reserved. See [LICENSE](LICENSE).

---

<p align="center">Built in Cairo, Egypt.</p>
