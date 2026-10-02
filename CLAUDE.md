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
- **Backend:** Supabase Edge Functions (TypeScript/Deno) + Supabase Postgres (عداد الاستخدام فقط). **لا يوجد Firebase.** OCR أونلاين: Gemini (Flash-Lite) خلف الـEdge Function `ocr-document` (بـflag `online_ocr_enabled`)، ومعاه **fallback صريح** لـTesseract على الجهاز لفشل معيّن بس (rate limit / timeout / `OCR_UNAVAILABLE` / مفيش نت) وبانر تحذير — أي فشل تاني بيظهر زي ما هو (F20 §1)؛ Tesseract برضه هو مسار الـoffline. التصنيف والشرح النهائي: **Structured Output خلف `analyze-document`، نص بس** — Mistral (Ministral) وبعده Groq كـfallback في نفس الطلب (F20)؛ مزوّد التحليل ما بيشوفش الصورة أبدًا (نص الـOCR + candidates بس). كل المزوّدين على free tier — راجع §7. Azure و Google Document AI اتشالوا (F20-T16).
- **Auth:** Supabase **Anonymous Auth** — لا توجد شاشة تسجيل دخول ظاهرة. هوية تقنية فقط لحماية الخدمة + `installationId` في `flutter_secure_storage`.
- **Privacy (non-negotiable):** **الصورة** (أونلاين بس) بتتبعت لخدمة قراءة بره تقرا النص منها؛ إحنا مابنحفظهاش على أي سيرفر عندنا، بس الخدمة دي شغّالة على free tier ممكن تحتفظ بيها فترة ويراجعها موظفين عندها — فـ**ممنوع ندّعي إن محدش بيشوف الصورة** (F20-T24، §7). من غير إنترنت الصورة بتتقري على الموبايل بس. **النص** المستخرج بيتبعت مشفَّر لخدمة تحليل بره، وإحنا مانحفظوهوش ومانسجّلوهوش — بس **ممنوع ندّعي إن محدش بيقراه**، لأن التطبيق شغّال على free tier بيسمح للمزوّد بمراجعة المحتوى (F18-T02، §7). الحفظ الافتراضي على الجهاز = «النتيجة فقط». لا تذكير تلقائي بدون مراجعة المستخدم. لا تُسجَّل محتويات المستند في أي Log. النصوص اللي بتظهر للمستخدم متسميش أي مزوّد خدمة (Azure/Google/Gemini/Mistral/Groq) — راجع `docs/features/F20-ocr-analysis-provider-refactor.md` (وقبله F13 و F18).
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
- **Online pipeline** (خلف `onlineOcrEnabled`، F13 → F20): الصورة نفسها فقط (بدون Thumbnail/EXIF/GPS) تُرسَل للـEdge Function `ocr-document`، اللي بتبعتها لخدمة القراءة (Gemini free tier) — إحنا مابنخزّنهاش على أي سيرفر عندنا. الفشل الأونلاين **مايرجعش صامت** لـTesseract أبدًا: الـfallback للجهاز **صريح**، لأربع حالات بس (`shouldFallBackToOnDeviceOcr`: rate limit، timeout، `OCR_UNAVAILABLE`، مفيش نت)، ومعاه بانر تحذير (`ocrOnlineFallbackWarning`)؛ أي فشل تاني بيظهر للمستخدم يعيد المحاولة (F20 §1).
- أي نص يظهر للمستخدم (شاشات الخصوصية، رسائل الخطأ...) متسميش مزوّد خدمة (Azure/Google/Gemini/Mistral/Groq) ومتدّعيش إن الصورة "متطلعش من الموبايل خالص".
- **لا الصورة ولا النص فيهم «محدش بيشوفه/بيشوفها» (F18-T02 للنص، F20-T24 للصورة):** الصورة بتروح لـGemini free tier، وشروطه بتسمح بالاحتفاظ بالمحتوى ومراجعته بشريًا ([Gemini API terms](https://ai.google.dev/gemini-api/terms) — Unpaid Services)؛ والنص بيروح لـMistral (وGroq كـfallback) على free tier، ومانقدرش نضمن عنهم إن محدش بيشوفه (Mistral ممكن يستخدمه للتدريب لو الـopt-out مش متفعّل — قرار D2). فممنوع أي نص للمستخدم يدّعي إن الصورة أو النص محدش بيشوفهم، أو إن الصورة "مش بتتحفظ" من غير ما يحدّد إن ده عندنا/على الموبايل. اختبار `app_strings_test` بيفرض ده على كل نصوص `AppStrings`.
  - الصياغة المعتمدة للصورة (نقطة الخصوصية الأولى): «لما تكون متصل بالإنترنت، بنبعت صورة الورقة لخدمة خارجية تقرا النص منها. إحنا مابنحفظش الصورة، لكن الخدمة دي ممكن تحتفظ بيها فترة، وممكن يراجعها موظفين عندها لتحسين خدمتها. من غير إنترنت، الصورة بتتقري على موبايلك بس.»
  - الصياغة المعتمدة للنص (النقطة التانية): «بنبعت نص ورقتك مشفَّر لخدمة تحليل علشان نفهمه، ومانحفظش النص عندنا.»
  - اللي إحنا فعلًا بنضمنه: مانحفظش الصورة ولا النص على سيرفراتنا، ومانسجّلهمش في أي Log، وبنبعت النص مشفَّر؛ والصورة مش بتتحفظ **على الموبايل** إلا بموافقة المستخدم. مش «محدش بيشوفهم».
  - لو التطبيق اتحوّل لـpaid tier عند كل المزوّدين (مثلًا Gemini Tier 1 بيلغي حق الاستخدام والمراجعة البشرية) يجوز ساعتها بس مراجعة الصياغة — والقرار للمالك.
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
- On-device OCR sits behind an `OcrEngine` interface (Tesseract first, PaddleOCR as alternative) — the engine is never called directly from a Cubit/Widget; cubits reach it through the `ExtractDocumentText` use case.
- Online OCR flows exclusively through the `ocr-document` Edge Function (`OcrImage` use case). Falling back to on-device OCR is decided only on the client, only from the online reading's own failure, and only by the closed allowlist in `shouldFallBackToOnDeviceOcr` (F20 §1) — never silently, never from an analysis failure. `OcrReviewCubit` discards answers to requests the user left behind (F20 §4).
- Contract before Integration, Mock before the real service: the result screen is built against a Mock analyze-document before wiring up any real AI provider.
- Real analysis flows exclusively through the `analyze-document` Edge Function, text only — the app never knows or calls an AI provider directly, and never learns which provider (Mistral or its Groq fallback, F20) served it.

## 10) Testing & Quality Gate (before any task is "done")
```
dart format .
flutter analyze
flutter test
```
- Tests for domain/data (extractors, mappers, validators, cubits). Every bug fix must include a test that reproduces it.
- RTL and Large Text support for any new screen. Explicit Loading/Empty/Error/Partial states.