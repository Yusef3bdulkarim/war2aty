# ورقتي — War2aty

> **«ورقتي بتقول إيه؟»** — صوّر أي ورقة مطبوعة، والتطبيق يقرأها ويشرحلك: نوعها إيه، أهم اللي فيها، المطلوب منك، والمواعيد اللي محتاج تفتكرها.

A mobile app that reads printed documents using OCR and explains them in simple Egyptian Arabic — built for users who struggle with formal paperwork, including the elderly and those with limited reading ability.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 📸 **Smart Capture** | Live camera with real-time document edge detection and auto-crop |
| 🔍 **Dual OCR** | Online (Azure AI Document Intelligence) with offline fallback (Tesseract) |
| 🤖 **AI Analysis** | Classifies the document type, extracts key info, and explains what action is needed — in simple Egyptian Arabic |
| 🔊 **Audio Reader** | Text-to-speech reads OCR text or narrates the full analysis screen |
| 💾 **Saved Papers** | Browse, search, and filter analyzed documents locally |
| ⏰ **Reminders** | Set reminders for deadlines mentioned in a document |
| 🔒 **Privacy-first** | Images are never stored on any server — processed and deleted immediately |
| ♿ **Accessible** | Large buttons, RTL-first, high contrast, reduced-motion support |

## 🏗️ Architecture

**Feature-based Clean Architecture** — each feature follows a strict three-layer separation:

```
lib/
├── app/              # DI, routing, shell
├── core/             # Shared logic (database, network, crypto, localization, …)
└── features/
    ├── analysis/     # AI document classification & explanation
    ├── audio_reader/ # Text-to-speech
    ├── bootstrap/    # Splash, initialization
    ├── capture/      # Camera, edge detection, crop
    ├── home/         # Main screen
    ├── ocr/          # OCR processing (online + offline)
    ├── onboarding/   # First-launch consent flow
    ├── reminders/    # Local notifications for deadlines
    ├── saved_papers/ # Document history & details
    └── settings/     # Permissions, privacy, about
```

Each feature:
```
feature/
├── data/           # Data sources, DTOs, mappers, repository impls
├── domain/         # Entities, repository interfaces, use cases
└── presentation/   # Cubit/Bloc, screens, widgets
```

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter (Android + iOS, portrait only) |
| **State Management** | Cubit / Bloc |
| **Local Database** | Drift + SQLite |
| **Backend** | Supabase Edge Functions (TypeScript / Deno) |
| **Auth** | Supabase Anonymous Auth |
| **OCR (online)** | Azure AI Document Intelligence → Supabase Edge Function |
| **OCR (offline)** | Tesseract (on-device) |
| **AI Analysis** | Groq Structured Output → Supabase Edge Function |
| **DI** | get_it |
| **Routing** | go_router |
| **Security** | AES-256-GCM encrypted local images, flutter_secure_storage |
| **Notifications** | flutter_local_notifications |
| **TTS** | flutter_tts |

## 🔐 Privacy

- **Images are never stored on any server** — processed in-memory and deleted immediately after OCR
- The AI model receives only extracted text, never the original image
- Local image storage (optional) is AES-256-GCM encrypted
- No analytics, no tracking, no Firebase
- User controls whether text is sent for analysis (consent gate)

## 🧪 Testing

**1,900+ tests** covering domain logic, data layer, cubits, and widget tests.

```bash
flutter test                    # Run all tests
flutter analyze                 # Static analysis
dart format --set-exit-if-changed .  # Format check
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (stable channel)
- Android SDK / Xcode
- A Supabase project with the edge functions deployed

### Build & Run

```bash
# Development
flutter run --flavor dev -t lib/main_dev.dart

# Production
flutter build apk --flavor prod --release \
  --dart-define-from-file=config/prod.json \
  -t lib/main_prod.dart
```

### Configuration

Copy the example and fill in your Supabase credentials:

```bash
cp android/key.properties.example android/key.properties
# Edit with your keystore details
```

Production config lives in `config/prod.json` (Supabase URL + anon key).

## 📁 Project Structure

```
config/         # Build-time config (Supabase URL, anon key)
docs/           # Feature specs, plans, test/build/rollout notes
lib/            # Dart source
supabase/       # Edge functions + migrations
test/           # Unit, widget, and integration tests
```

## 📄 License

All rights reserved © 2026

---

Built with ❤️ in Cairo, Egypt
