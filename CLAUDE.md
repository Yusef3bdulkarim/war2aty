# CLAUDE.md — Project

<!--
Global rules are in ~/.claude/CLAUDE.md — don't repeat them here.
Only project-specific overrides and Flutter rules go here.
The binding specification is: .claude/doc/war2aty_product_engineering_master_plan.md
When this file and the master plan disagree, the master plan wins.
-->

# Project Context
- **App:** «ورقتي بتقول إيه؟» (War2aty) — يصوّر المستخدم ورقة مطبوعة، فيستخرج التطبيق نصّها (محليًا عند تعذّر الاتصال، أو بمعالجة آمنة أونلاين عند توفره) ويشرح له: نوع الورقة، أهم ما فيها، المطلوب منه، والمواعيد التي تحتاج تذكيرًا.
- **Market / Users:** مصر — المستخدم المصري العادي (مع مراعاة كبار السن وضعاف القراءة/البصر). اللهجة المصرية البسيطة.
- **Platforms:** Android + iOS فقط. Portrait فقط. لا Tablet/Web في الـMVP.
- **Language / Direction:** واجهة عربية بالكامل، **RTL** بالكامل. المستند نفسه قد يكون عربي/إنجليزي/مختلط.
- **Backend:** Supabase Edge Functions (TypeScript/Deno) + Supabase Postgres (عداد الاستخدام فقط). **لا يوجد Firebase.** OCR: Azure AI Document Intelligence (أساسي، أونلاين فقط) + Google Document AI (رأي ثانٍ شرطي) خلف الـEdge Function؛ Tesseract محلي كـfallback offline فقط (F13). التصنيف والشرح النهائي: Groq Structured Output خلف الـEdge Function — Groq لا يرى الصورة أبدًا.
- **Auth:** Supabase **Anonymous Auth** — لا توجد شاشة تسجيل دخول ظاهرة. هوية تقنية فقط لحماية الخدمة + `installationId` في `flutter_secure_storage`.
- **Privacy (non-negotiable):** بنقرا نص الورقة بمعالجة آمنة، لكن **صورتها نفسها متتحفظش خالص ومحدش بيشوفها** — لا تُخزَّن على أي سيرفر، وتتمسح فورًا بعد قراءتها. الحفظ الافتراضي على الجهاز = «النتيجة فقط». لا تذكير تلقائي بدون مراجعة المستخدم. لا تُسجَّل محتويات المستند في أي Log. النصوص اللي بتظهر للمستخدم متسميش أي مزوّد خدمة (Azure/Google/Groq) — راجع `docs/features/F13-ocr-provider-migration.md`.
- **Local data:** Drift + SQLite (مصدر الحقيقة المحلي)، صور اختيارية مشفّرة (AES-256-GCM) داخل Application Private Directory، Local Notifications، Local TTS.
- **Usage limit:** 3 تحليلات ذكية ناجحة يوميًا (قابلة للتعديل من Backend runtime config)، بحساب يوم `Africa/Cairo`.
- **Status:** MVP جديد من الصفر. التنفيذ **Vertical-Slice-first** (مسار فاتورة كهرباء كامل)، ثم توسعة الميزات. لا تُبنى كل الشاشات دفعة واحدة.

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
- **Offline pipeline** (لا اتصال — الوضع الافتراضي القديم): لا تُرسِل غير **نص OCR + candidates** للـBackend — لا صورة، لا Thumbnail، لا EXIF/GPS.
- **Online pipeline** (خلف `azureOcrEnabled`، F13): الصورة نفسها فقط (بدون Thumbnail/EXIF/GPS) تُرسَل للـEdge Function لمعالجة آمنة تقرأ النص منها، وتُحذف فورًا بعد القراءة — لا تُخزَّن على أي سيرفر لأكثر من مدة القراءة نفسها. فشل أونلاين لا يرجع صامت لـTesseract أبدًا — المستخدم يعيد المحاولة.
- أي نص يظهر للمستخدم (شاشات الخصوصية، رسائل الخطأ...) متسميش مزوّد خدمة (Azure/Google/Groq) ومتدّعيش إن الصورة "متطلعش من الموبايل خالص" — الصياغة المعتمدة: «بنقرا النص بمعالجة آمنة، لكن مانحفظش الصورة، ومحدش بيشوفها».
- لا Secrets داخل Flutter/Git (كل الـAPI keys داخل Supabase Secrets فقط؛ الـPublishable key فقط هو المسموح في التطبيق).
- لا تُسجِّل OCR text أو Prompt أو AI response أو أرقام/مبالغ/أسماء في الـLogs.
- الصور المحفوظة محليًا (باختيار المستخدم بعد التحليل) مشفّرة؛ تُحذف النسخة غير المشفّرة والملفات المؤقتة بعد الانتهاء.
- لا تعرض تاريخًا/مبلغًا/رقمًا غير مؤكد كأنه حقيقة — استخدم «راجع المعلومة / قراءة غير مؤكدة». الثقة على مستوى المعلومة لا المستند.
- المستخدم يتحكم في السماح للتحليل عبر إعداد «السماح بإرسال النص للتحليل» (F11-T02) — عند رفض الإذن لا تُرسَل أي بيانات (F11 consent gate).

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