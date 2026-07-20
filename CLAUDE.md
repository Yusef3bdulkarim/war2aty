# CLAUDE.md — Project

<!--
Global rules are in ~/.claude/CLAUDE.md — don't repeat them here.
Only project-specific overrides and Flutter rules go here.
The binding specification is: .claude/doc/war2aty_product_engineering_master_plan.md
When this file and the master plan disagree, the master plan wins.
-->

# Project Context
- **App:** «ورقتي بتقول إيه؟» (War2aty) — يصوّر المستخدم ورقة مطبوعة، فيستخرج التطبيق النص محليًا (OCR) ويشرح له: نوع الورقة، أهم ما فيها، المطلوب منه، والمواعيد التي تحتاج تذكيرًا.
- **Market / Users:** مصر — المستخدم المصري العادي (مع مراعاة كبار السن وضعاف القراءة/البصر). اللهجة المصرية البسيطة.
- **Platforms:** Android + iOS فقط. Portrait فقط. لا Tablet/Web في الـMVP.
- **Language / Direction:** واجهة عربية بالكامل، **RTL** بالكامل. المستند نفسه قد يكون عربي/إنجليزي/مختلط.
- **Backend:** Supabase Edge Functions (TypeScript/Deno) + Supabase Postgres (عداد الاستخدام فقط). **لا يوجد Firebase.** الذكاء الاصطناعي: Groq Structured Output خلف الـEdge Function.
- **Auth:** Supabase **Anonymous Auth** — لا توجد شاشة تسجيل دخول ظاهرة. هوية تقنية فقط لحماية الخدمة + `installationId` في `flutter_secure_storage`.
- **Privacy (non-negotiable):** صورة الورقة **لا تخرج من الهاتف أبدًا**. يُرسَل النص المستخرج فقط. الحفظ الافتراضي = «النتيجة فقط». لا تذكير تلقائي بدون مراجعة المستخدم. لا تُسجَّل محتويات المستند في أي Log.
- **Local data:** Drift + SQLite (مصدر الحقيقة المحلي)، صور اختيارية مشفّرة (AES-256-GCM) داخل Application Private Directory، Local Notifications، Local TTS.
- **Usage limit:** 3 تحليلات ذكية ناجحة يوميًا (قابلة للتعديل من Backend runtime config)، بحساب يوم `Africa/Cairo`.
- **Status:** MVP جديد من الصفر. التنفيذ **Vertical-Slice-first** (مسار فاتورة كهرباء كامل)، ثم توسعة الميزات. لا تُبنى كل الشاشات دفعة واحدة.

---

# Design System (Waraqti.dc.html) — MANDATORY reference

- **مصدر التصميم المعتمد:** مشروع Claude Design `Waraqti.dc.html` (import عبر DesignSync / MCP). **يُلغي** أي إشارة قديمة لـ«Casaback» أو «Stitch».
- **الخط:** Cairo (أوزان 400–800).
- **الألوان:**
  - Brand teal `#0E7C86` · Deep teal `#0A5C64`
  - Ink `#1D2B30` · Secondary text `#5A686E` · Muted `#8A969B`
  - Surfaces (warm off-white): `#E9E6DF` · `#F5F4EF` · `#F2EFE8`
  - Success `#2E9E63` / mint `#34D0B4` · Warning amber `#C77B12` on `#FBEFD8` · Error `#C4362A` on `#FBECEA`
- **قبل بناء أي شاشة/Widget:** طابِق شاشة التصميم المقابلة بدقّة — الألوان، المسافات، Typography، والحالات (empty / loading / error / partial).
- **إن لم يوجد تصميم للشاشة:** توقّف، أخبر المستخدم بالشاشة الناقصة، وانتظر التصميم قبل كتابة أي UI.
- **لا تعتمد على اللون وحده** لتوضيح الحالة (نص/أيقونة مصاحبة). أزرار كبيرة، نصوص مقروءة، دعم Large Text وHigh Contrast.

---

# Section B — Flutter / Dart Specific Rules

<!--
Follow official Dart style guide, Effective Dart, and flutter_lints defaults.
Rules below only cover things that OVERRIDE defaults or encode project decisions.
-->

## 1) Architecture (Feature-Based Clean Architecture)
- الطبقات: `presentation → domain → data`. لا تتجاوز الحدود ولا تخلط المسؤوليات.
- Domain **خالٍ تمامًا من أي import لـ Flutter/Supabase/Drift/Dio/OCR plugin**.
- الشيفرة المشتركة بين feature+ تعيش في `core/` أو `shared/` — لا cross-feature imports عشوائية.

## 2) State Management
- **Cubit/Bloc** فقط — لا Riverpod/Provider/GetX.
- Cubits تعتمد على **Use Cases فقط** — never repositories/data sources/Dio/SQL/Supabase/OCR مباشرة.
- لا `BuildContext` داخل Cubit. لا Cubit واحد للتطبيق كله.
- `setState` لِـ local UI state فقط (toggles، focus)، وبأصغر Widget scope ممكن.

## 3) Code Generation — Drift ONLY (strict; narrows global "no build_runner" rule)
- `build_runner` مسموح **حصريًا لـ Drift** (schema/DAOs). لا شيء آخر.
- **ممنوع `json_serializable`** — كل DTO يكتب `fromJson`/`toJson` **يدويًا** (لا ملفات `.g.dart` للـ DTOs).
- **ممنوع Freezed.** استخدم `sealed class` + pattern matching (Dart 3) لكل Cubit states وunions في الدومين (Failures، analysis stages، result variants). Entities/UI models كلاسات immutable مكتوبة يدويًا.

## 4) Feature Folder Structure
```
features/{feature_name}/
├── data/         (datasources, models[DTOs], mappers, repositories impl)
├── domain/       (entities, repositories[interfaces], usecases)
└── presentation/ (cubit, screens, widgets, models[UI models])
```

## 5) Error Handling Contract
- Data layer: التقاط الاستثناءات وتحويلها إلى `AppFailure` مُصنّفة (`sealed class AppFailure`).
- Domain/Repositories/Use cases: ترجع **`Result<T, AppFailure>`** — لا ترمي Exceptions للأعلى.
- Presentation: تحويل الـFailure إلى رسالة عربية مناسبة وحالة UI. لا تعتمد على نص الخطأ الإنجليزي القادم من الخادم.

## 6) Dependency Injection
- **`get_it`** كـ service locator. التسجيل في `app/dependency_injection/` (modules).
- Cubits/UseCases/Repositories تُحلّ عبر `get_it` لا يدويًا.

## 7) Privacy & Security (hard rules)
- لا تُرسِل صورة/Thumbnail/EXIF/GPS للـBackend — **نص OCR + candidates فقط**.
- لا Secrets داخل Flutter/Git (Groq key وService Role داخل Supabase Secrets فقط؛ الـPublishable key فقط هو المسموح في التطبيق).
- لا تُسجِّل OCR text أو Prompt أو AI response أو أرقام/مبالغ/أسماء في الـLogs.
- الصور المحفوظة مشفّرة؛ تُحذف النسخة غير المشفّرة والملفات المؤقتة بعد الانتهاء.
- لا تعرض تاريخًا/مبلغًا/رقمًا غير مؤكد كأنه حقيقة — استخدم «راجع المعلومة / قراءة غير مؤكدة». الثقة على مستوى المعلومة لا المستند.

## 8) Build Method Discipline
- فضّل `const`. لا تُنشئ `TextEditingController`/`AnimationController`/`FocusNode` داخل `build()`؛ تخلّص منها في `dispose()`.
- العمليات الثقيلة (Image processing / OCR / Encryption / Large JSON parse) خارج الـUI thread قدر الإمكان.
- `BlocBuilder`/`BlocSelector` على أصغر Widget يحتاج الحالة، لا أعلى الشجرة.

## 9) OCR & Analysis boundaries
- OCR خلف `OcrEngine` interface (Tesseract أولًا، PaddleOCR بديل) — لا يُستدعى المحرك مباشرة من Cubit/Widget.
- Contract قبل Integration، Mock قبل الخدمة الحقيقية: تُبنى شاشة النتيجة على Mock analyze-document قبل ربط Groq.
- التحليل الحقيقي يمرّ حصريًا عبر Supabase Edge Function — لا يعرف التطبيق اسم Groq ولا يتصل به مباشرة.

## 10) Testing & Quality Gate (before any task is "done")
```
dart format .
flutter analyze
flutter test
```
- اختبارات لِـ domain/data (extractors، mappers، validators، cubits). إصلاح أي bug يصاحبه اختبار يعيد إنتاجه.
- دعم RTL وLarge Text لأي شاشة جديدة. حالات Loading/Empty/Error/Partial صريحة.
