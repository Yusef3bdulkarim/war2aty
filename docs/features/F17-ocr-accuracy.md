# F17 · OCR Accuracy — Capture Fidelity & Handwriting Awareness

- **Branch:** `feature/ocr-accuracy` (off `develop`) · **Milestone:** post-F16
- **Depends on:** F13 (Azure `prebuilt-read`, the confidence/verification pipeline), F16 (`doclens` detection events), F04 (`ImageQualityService`), F15 (`PerspectiveCorrector`) · **Feeds:** nothing — this raises the fidelity of an already-working pipeline
- **Progress:** 0 / 5 phases DONE
- **Gate protocol:** no phase begins until the previous phase's gate is **signed off by the user**. See [Gate protocol](#gate-protocol).

The app reads Egyptian paperwork. It reads printed bills acceptably. It reads
**handwritten** pages badly, and — more dangerously — it has no way of knowing
that it read them badly, so it presents an unreliable reading with the same
confidence as a reliable one.

This feature does **not** add an image-enhancement stage. Investigation
(2026-09-09) found that the enhancement work originally proposed would have
*lowered* accuracy, and that the two real causes lie elsewhere: the camera
captures at roughly a tenth of the resolution the OCR model needs, and the
confidence machinery that already exists uses a single threshold that
collapses on handwriting.

---

## Context

Three findings, all verified against the code on 2026-09-09, reframe the work.

### 1 · Arabic handwriting is already supported — by the exact model we call

Azure Document Intelligence **v4.0** added Arabic to the handwritten-text
language set. The app is already on that version and model:

| Setting | Value | Source |
|---|---|---|
| Model | `prebuilt-read` | [`azure-client.ts:31`](../../supabase/functions/_shared/azure/azure-client.ts#L31) |
| API version | `2024-11-30` (v4.0 GA) | [`azure-client.ts:30`](../../supabase/functions/_shared/azure/azure-client.ts#L30) |
| Locale forced? | No — auto-detect | [`azure-client.ts`](../../supabase/functions/_shared/azure/azure-client.ts) sends no `locale` |

Handwritten languages in v4.0: `en`, `zh-Hans`, `fr`, `de`, `it`, `th`, `ja`,
`ko`, `pt`, `es`, `ru`, **`ar`**. v3.1 and earlier had no Arabic — being on
v4.0 is what makes this feature possible at all.

Not forcing a locale is correct and must stay that way. Microsoft's guidance:

> *"Don't provide the language code as the parameter unless you are sure of the
> language and want to force the service to apply only the relevant model.
> Otherwise, the service may return incomplete and incorrect text."*

Egyptian paperwork is routinely mixed Arabic/English, so a forced locale would
actively hurt. **No task in this feature adds a locale parameter.**

### 2 · The camera captures at ~90 DPI

[`platform_camera_service.dart:63`](../../lib/features/capture/data/services/platform_camera_service.dart#L63):

```dart
final controller = CameraController(
  back,
  // High enough for legible OCR without the memory cost of max — the
  // paper only has to be readable, not print-quality.
  ResolutionPreset.high,
```

The comment's premise is wrong. `ResolutionPreset.high` is **720p**:

| Preset | Pixels | A4 equivalent | Verdict for handwriting |
|---|---|---|---|
| `high` ← **current** | 1280×720 (0.92 MP) | ~90 DPI | Unusable |
| `veryHigh` | 1920×1080 (2.07 MP) | ~130 DPI | Marginal |
| `ultraHigh` | 3840×2160 (8.29 MP) | ~270 DPI | Good |
| `max` | Sensor maximum | Varies wildly | Unbounded — see risk below |

The arithmetic, which needs no vendor claim to stand: a portrait A4 page is
11.69 inches tall, so filling a 720-line frame puts it at roughly **60–110 DPI**
depending on orientation, against **185–260 DPI** at `ultraHigh`. Arabic
handwriting at 90 DPI resolves to roughly 15–25 pixels of x-height — the range
where stroke joins and dot placement, which is what distinguishes ب/ت/ث and
ج/ح/خ, stop being separable at all. No post-processing recovers information the
sensor never recorded.

> An earlier draft of this document asserted that Azure requires a text line
> "at least ~50 px tall". That conflated the documented minimum *image* size
> (50×50 px) with a line-height recommendation, and is withdrawn. The DPI
> arithmetic above is the argument; it does not depend on it.

This also puts the capture pipeline in direct contradiction with its own
quality gate. [`dart_image_quality_service.dart:41-46`](../../lib/features/capture/data/services/dart_image_quality_service.dart#L41):

```dart
static const _resGood = 2000000;        // 2 MP
static const _resAcceptable = 1000000;  // 1 MP
```

A 0.92 MP capture scores **below `_resAcceptable`**, and `_worst()` takes the
minimum across blur/resolution/brightness — so on Android `overall` may be
permanently `poor`. The constants carry the comment *"educated guesses, tuned
later against real Egyptian documents"*; that tuning never happened.

> ⚠️ **Unconfirmed on iOS.** `AVCaptureSessionPresetHigh` can yield a
> higher-resolution still than its preview. Phase 0 measures both platforms
> before any constant is changed.

### 3 · The confidence pipeline is built — and has one global threshold

An earlier reading of this codebase claimed per-word confidence was discarded.
That was wrong. It is wired end to end:

| Layer | Location | Status |
|---|---|---|
| Per-word confidence extraction | [`azure-client.ts:94`](../../supabase/functions/_shared/azure/azure-client.ts#L94) `flattenWords()` | Built |
| Per-field verdicts | [`field-verification.ts`](../../supabase/functions/_shared/verification/field-verification.ts) (F13-T06) | Built |
| `needsUserReview` decision | [`cross-provider-validator.ts`](../../supabase/functions/_shared/verification/cross-provider-validator.ts) (F13-T08) | Built |
| UI treatment | [`confidence_band.dart`](../../lib/core/documents/confidence_band.dart), [`value_caveat.dart`](../../lib/core/widgets/value_caveat.dart), [`caveat_badge.dart`](../../lib/core/widgets/caveat_badge.dart) | Built |

What is genuinely missing is **one signal**: Azure returns
`analyzeResult.styles[].isHandwritten`, and a repo-wide search finds **zero**
references to `styles` or `isHandwritten` anywhere in `supabase/` or `lib/`.

That omission hides a latent defect in
[`field-verification.ts:58`](../../supabase/functions/_shared/verification/field-verification.ts#L58):

```ts
export const VERIFIED_CONFIDENCE_THRESHOLD = 0.85;
```

One global threshold. Arabic handwriting routinely scores **0.60–0.80 while
being read correctly**. On a handwritten page every field therefore falls to
`unverified`, every value gets a caveat, and the UI's careful distinction
between a trustworthy amount and a doubtful one carries no information.

**A warning on everything is a warning on nothing.** This defect is invisible
on printed documents, which is why it has not surfaced.

### What this feature deliberately does not do

`warpImage()` in
[`doclens_perspective_corrector.dart:40`](../../lib/features/capture/data/services/doclens_perspective_corrector.dart#L40)
is called without an `enhancement` argument, so it defaults to
`ImageEnhancement.none`. **This is correct for the OCR path and stays.**

Adaptive thresholding, "magic color", and binarisation are pre-deep-learning
techniques built for engines like Tesseract that classify glyph shapes after
binarisation. Azure v4.0 is trained on natural photographs, and binarising
destroys the two signals handwriting recognition depends on most: pen-pressure
stroke gradient, and faint strokes (pencil, dry ink) that fall below the
threshold and vanish outright.

Enhancement appears in this feature exactly once — in Phase 4, on a **separate
rendition shown to the user**, never on the bytes sent to Azure.

---

## Locked decisions

1. **No image enhancement on the OCR path, ever.** The bytes sent to Azure are
   geometry-corrected only (perspective + rotation). No binarisation, no
   thresholding, no "magic color", no sharpening. Phase 4 introduces a second
   rendition for display; a test must prevent it from reaching the wire.
2. **No forced locale.** `prebuilt-read` auto-detects. Egyptian paperwork is
   mixed-script and a locale parameter would degrade it.
3. **Nothing changes without measurement.** No threshold, preset, or constant
   in this feature is chosen by judgement. Every number comes from Phase 0's
   measurement run over the golden set, and every change is re-measured.
4. **One phase at a time, user-gated.** See [Gate protocol](#gate-protocol).
   Phases are sequenced so each is independently shippable and revertible.
5. **The golden set never leaves the machine.** It is test material we own,
   not user documents. Git-ignored, never uploaded, never logged. It exists to
   produce numbers, and only numbers leave it.
6. **Handwriting lowers trust; it never raises it.** Phase 2 relaxes the
   *verification* threshold for handwritten words so the signal stays
   informative — but a handwritten date or amount is always surfaced for
   review regardless of score. This preserves F13-T06's invariant that
   verification only ever lowers trust.

---

## Gate protocol

**No phase begins until the previous phase's gate is signed off by the user.**

Every gate requires all four, with no exceptions:

| # | Requirement |
|---|---|
| **G1 · Numbers agreed** | Every constant introduced or changed is justified by a measurement, not judgement. The measurement is shown. |
| **G2 · Results verified** | The measurement script has been re-run over the golden set and the before/after table is presented in full — including regressions. |
| **G3 · Code proven** | `dart format .` · `flutter analyze` · `flutter test` all pass. Backend phases add `deno test`. Output is shown, not summarised. |
| **G4 · Explicitly approved** | The user reviews the above and says to continue. Silence is not approval. |

Failing a gate is a normal outcome, not a setback. If Phase 1 does not move
the numbers, that is a finding: the phase is reverted or reworked, and the
plan is amended before anything else proceeds.

Per `CLAUDE.md` §8, each phase additionally runs `/flutter-code-review`, then
`@code-reviewer`, then `/explain-feature`, then `@git-expert` — before its gate
is presented.

---

## Phase 0 · Measurement harness — *no production code changes*

Without this, "did it get better?" has no answer. Everything downstream depends
on it, and it changes no app behaviour.

| # | Task | Detail | Status |
|---|---|---|---|
| 1 | F17-T01 | **Golden set** — 25–30 real Egyptian documents. Composition below; it is not a free choice | TODO |
| 2 | F17-T02 | **Ground truth** — the correct text for each page, transcribed by hand into a sidecar file | TODO |
| 3 | F17-T03 | **Measurement script** — per document and per category: CER, WER, mean word confidence, `verified`-field rate, and **date+amount exact-match rate** (the verdict metric) | **DONE** — [`supabase/tools/ocr-benchmark.ts`](../../supabase/tools/ocr-benchmark.ts) |
| 4 | F17-T04 | **Capture-resolution probe** — log actual `takePicture()` output dimensions and byte size on a physical Android device and a physical iOS device | TODO |
| 5 | F17-T05 | **Baseline run** — the numbers as they stand today, recorded as the comparison point for every later phase | TODO |

### Golden set composition (F17-T01)

The set is not measured on "did it read the text", but on **"did it get the
date and the amount right"** — those are the only two field types that gate a
Google second opinion ([`cross-provider-validator.ts:61`](../../supabase/functions/_shared/verification/cross-provider-validator.ts#L61)),
and they are what the app exists to deliver. A page containing no dates,
amounts, references or phone numbers produces a CER figure and **no signal at
all** about the pipeline that matters.

| n | Category | Must contain |
|---|---|---|
| 10 | Printed, clean — utility bills, receipts | dates, amounts, reference numbers |
| 8 | Printed, poor — fax, photocopy, creased, low light | same |
| **4** | **Printed form with handwritten fields** 🔴 | handwritten dates/amounts on printed stock |
| 2 | Fully handwritten, containing figures — a hand-written receipt, a page of appointments | handwritten dates/amounts |
| 2 | Continuous handwritten Arabic prose — lecture notes, a letter | prose only; no figures needed |
| 4 | Mixed Arabic/English | any |

**The 4 printed-forms-with-handwritten-fields are the highest-value pages in
the set.** That combination — a filled-in official form, a receipt whose
figures are written in by hand, a doctor's prescription — is both the most
common way Egyptian paperwork carries handwriting and the exact case the single
global threshold in [`field-verification.ts:58`](../../supabase/functions/_shared/verification/field-verification.ts#L58)
collapses on: two styles on one page, scored against one bar. Phase 2 is
designed for this case and cannot be validated without it.

**Handwriting variety matters more than page count.** Eight pages in one
person's hand measures how well Azure reads *that hand*, not Arabic
handwriting. Aim for **3–4 different writers**.

### Capture methodology — photograph once, derive the rest

Each page is photographed **once, at the highest resolution the phone offers**,
and every lower resolution is produced by downscaling that master in software.

The naive alternative — re-photographing all 30 pages through the app at each
preset — fails twice. It is punishing to repeat every phase, and it is not a
controlled experiment: a second photo session brings different lighting, angle
and focus, so a change in the numbers cannot be attributed to resolution rather
than to a steadier hand on the day.

Downscaling one master isolates the single variable this feature turns.

| | |
|---|---|
| **Master** | Highest available resolution, JPEG at maximum quality, flat even light, page filling the frame, shot square-on |
| **Derived** | 1280×720 (simulates today's `high`), 1920×1080, 3840×2160 — produced by the benchmark, not by hand |
| **Stored** | Master only. Derived renditions are regenerated on each run and never committed |

**Simulation is not the real thing**, so F17-T04 also captures ~5 pages through
the actual app at the old and new presets and confirms the on-device numbers
track the simulated ones. If they diverge, the simulation is wrong and the
methodology is revisited before Phase 1 continues.

Where genuine documents are unavailable, hand-written stand-ins are acceptable
**provided the content is realistic** — amounts, dates, names, phone numbers
laid out as a real receipt would be. The content may be invented; the
recognition challenge must not be.

**Deliverable:** a baseline table, per category:

```
category              | n  | CER | WER | mean conf | verified % | date+amount ✓
----------------------|----|-----|-----|-----------|------------|---------------
printed clean         | 10 |  ?  |  ?  |     ?     |     ?      |       ?
printed poor          |  8 |  ?  |  ?  |     ?     |     ?      |       ?
form + handwritten 🔴 |  4 |  ?  |  ?  |     ?     |     ?      |       ?
handwritten w/ figures|  2 |  ?  |  ?  |     ?     |     ?      |       ?
handwritten prose     |  2 |  ?  |  ?  |     ?     |     ?      |       —
mixed script          |  4 |  ?  |  ?  |     ?     |     ?      |       ?
```

The last column — **did it get every date and amount on the page right** — is
the number this feature is judged on. CER is diagnostic; that column is the
verdict.

**T04 is the single most important task in this phase.** It confirms or refutes
the 720p finding, and Phase 1's entire design depends on the answer.

> 🔒 **Privacy:** golden set and ground truth are git-ignored. The measurement
> script prints aggregate metrics only — never document text, never a field
> value. It runs against a dev Supabase project, never production.

### Ground truth cannot be drafted by a reader alone — 2026-09-09

The drafts were corrected by reading the pages and flagging every field that
could not be settled (`needsOwnerCheck` in each sidecar). The owner then
settled them. On one page — a handwritten arrival card — the tally was:

| Field | Azure read | Draft read | Owner's answer |
|---|---|---|---|
| Flight number | `SV3321` ✅ | `SV3327` ✗ | **SV 3321** |
| Address | `قرية البنائين` ✅ | `قرب المخابز` ✗ | **بلطيم قريه البنائين** |
| Birth place | `كهر النبي` ✗ | `كفر الشيخ` ✅ | **كفر الشيخ** |
| Name (last word) | `سيوى` ✗ | `يسرى` ✗ | **بسيوني** |

Two right each, and on the name **both readers were wrong**. Had the draft been
adopted as truth, the benchmark would have recorded errors against Azure on two
fields it read correctly, and enshrined a name neither reader got right — and
Phase 2's threshold would then have been calibrated on those numbers.

**Rule this establishes:** a transcription produced by reading the page is a
second opinion, never ground truth. Anything a reader cannot certify goes in
`needsOwnerCheck` and is settled by the document's owner before the page is
scored. This is what `category: UNCATEGORISED` guards — the scorer refuses any
sidecar still carrying it, because an uncorrected draft holds Azure's own output
as its `text` and would score a flawless, meaningless CER.

### Notes from the first run — 2026-09-09

- **The Azure resource is rate-limited well below benchmark speed.** Five
  documents back to back returned `429 AI_RATE_LIMITED`. The harness now paces
  itself (`--delay`, default 4s) and backs off exponentially on 429. This is a
  property of the sandbox resource, not of the pipeline — it changes how long a
  run takes, never what it measures.
- **`.webp` is not an accepted input.** `prebuilt-read` takes JPEG, PNG, BMP,
  TIFF, HEIF and PDF. Any `.webp` in the set is skipped and reported.
- **Phase 1 and Phase 2 have different set requirements.** Phase 2 measures
  confidence behaviour on handwriting and is indifferent to resolution; Phase 1
  measures resolution itself and needs masters well above the app's current
  capture. See the ordering note below.

### Baseline — 2026-09-09 (`baseline.json`, 6 owner-verified pages)

```
category            n   avg MP    CER    WER   mean conf  verified  date+amount
────────────────────────────────────────────────────────────────────────────────
form_handwritten    3    1.92   35.0%  52.0%     74.3%     33.3%        0.0%
handwritten_prose   1    1.92   58.9%  79.4%     72.1%    100.0%      100.0%
printed_clean       2    1.92    0.0%   0.0%     97.2%      0.0%      100.0%
────────────────────────────────────────────────────────────────────────────────
ALL                 6    1.92   27.3%  39.2%     81.6%     33.3%       50.0%
```

**The confidence gap is the finding Phase 2 rests on, and it depends on no
transcription at all** — these are Azure's own per-word scores:

```
printed      97.2%
                    ← VERIFIED_CONFIDENCE_THRESHOLD = 0.85 sits here
handwritten  72–74%
```

The single global threshold is above the handwritten mean and below the printed
mean, exactly as Phase 2 predicts. It is not a hypothesis any more.

**Handwritten dates are not being read at all** (`form_handwritten`
date+amount = 0%). Every owner-confirmed date failed, and one failed in the
worst possible way:

| Truth | Azure read | |
|---|---|---|
| `٨/٥/٢٠٠٦` | `٥/٨/٢٠٠٦` | **day and month transposed** |
| `٢٢/٤/٢٠٢٥` | `٢/٢٥١ ٤/٢` | garbled |
| `٨/١٠/٢٠٢٥` | `٢٠٢/٥/١٠/٨` | garbled |

A garbled date is caught downstream; a *transposed* one is well-formed and
wrong, and would schedule a reminder on the wrong day. This is measured
justification for F17-T18 — handwritten dates and amounts always surface for
review regardless of score.

**Two anomalies to explain at the start of Phase 2.** Printed pages: 97%
confidence, zero CER, yet `verified` = 0%. Handwritten prose: the worst CER in
the set, yet `verified` = 100%. Verification is not tracking correctness in
either direction, which is a larger problem than the threshold value itself.

**CER and field recall measure different things.** `handwritten_prose` has the
set's worst CER (58.9%) and still recovered 100% of its amounts — prices are
short digit runs, while the prose around them is hard. For this app, field
recall is the number that matters; CER is diagnostic.

### One harness bug, caught by the numbers themselves

The first saved run reported `date+amount = 0%` for `handwritten_prose`. Azure
had in fact read both prices correctly and returned `10, 99€` for `10,99€` —
the comparison was failing on a space. Fixed by matching dates and amounts with
whitespace stripped. The headline metric moved 25% → 50% with no change to the
pipeline.

A measuring instrument gets its own errors before the thing it measures does.
This is why G3 below requires the harness to carry tests: the bug was in
`criticalRecall`, and a test over `"10, 99€"` would have caught it.

### A pipeline bug, found by `--explain` — 2026-09-09

Diagnosing why a 97%-confidence printed page scored `verified = 0%` required
seeing *why* each field failed, not just that it did — `verifiedRate` alone
conflates three unrelated causes: the T05 extractor flagging its own candidate
`is_ambiguous`, a span that could not be matched to any Azure word at all
(`confidence: null`), and confidence genuinely below
`VERIFIED_CONFIDENCE_THRESHOLD`. Only the third is the thresholding question
Phase 2 is about. The benchmark's `--explain` flag was added to report which of
the three actually occurred, per field.

Running it surfaced something upstream of all three: `extractDates`,
`extractAmounts`, `extractPhones`, `extractTimes` and `extractReferences` every
match on `\d`, which in JavaScript is `[0-9]` and never `٠-٩`. Confirmed
directly:

```
/\d/.test("٨")   →  false
/\d/.test("8")   →  true
```

Every owner-confirmed date and amount in the golden set is written in
Arabic-Indic numerals, and every one of them produced **zero candidates** —
not a low-confidence read, not `is_ambiguous`, nothing to verify at all. Three
of the six documents returned no date/amount candidates whatsoever before this
was found. The offline (Tesseract) path was never affected: the client already
normalises digits before sending (`TextNormalizer`, `lib/features/ocr`). The
online path reads Azure's text inside `image-analysis-pipeline.ts`, which had
no equivalent step — a gap specific to F13-T11's image-intake pipeline, not a
defect in the extractors themselves.

Fixed in the pipeline itself — folding `azureResult.content` through
`normaliseDigits` (already used by the T06 date validator) before it reaches
the extractors, `verifyCandidates`, or `ocrText`. `normaliseDigits` maps one
code point to one code point, so Azure's `words[].offset` — UTF-16, matching
`stringIndexType=utf16CodeUnit` — stays valid; `normaliseForMatching` would
have been wrong here, since it deletes separator characters and shifts every
offset after them. Four tests added to
`image-analysis-pipeline.test.ts`, confirmed to fail without the fix and pass
with it; the full backend suite (535 passed / 15 pre-existing, unrelated
failures — confirmed via `git stash` that the count is identical without this
change) shows nothing else moved.

**The benchmark itself needed a second fix to see the first one.** It had
been calling `runExtractors`/`verifyCandidates` directly rather than
`createImageAnalysisPipeline` — the header comment's warning against
reimplementing "a Dart harness would... measure a copy" turned out to apply to
this TypeScript tool as well, just via a different route. The first re-run
after the digit fix reported no change at all, because the benchmark's copy of
the pipeline had never carried the bug it was meant to catch. Rewired to drive
`createImageAnalysisPipeline` with a stub Azure client, which is also why the
extractor imports could be deleted from the tool entirely — confirmed as
evidence the benchmark no longer reimplements anything upstream of it.
`explain()` still re-derives T06's per-field confidence (T08 discards it before
the pipeline returns `CrossProviderFieldVerdict`), but now over
`analysis.ocrText` — the pipeline's own folded output — so it reflects what the
pipeline actually saw rather than a second calculation.

With the real pipeline wired in, the two previously-invisible dates appeared:

```
                                     confidence   verdict
روشتة د. ياسر (٨/١٠/٢٠٢٥)              0.29      ambiguous (day/month both ≤12)
استمارة الوصول (٨/٥/٢٠٠٦)              0.65      ambiguous (day/month both ≤12)
تاج الشنطة ×2 (25AUG, 1200Z/25AUG)     0.99, 1.00 ambiguous (month name, no year)
```

Every field above is `is_ambiguous`, not confidence-gated — the extractor is
correctly refusing to guess an unresolvable day/month order or a yearless
date. **Zero fields in this set failed on `VERIFIED_CONFIDENCE_THRESHOLD`
itself.** The confidence numbers are nonetheless exactly the split Phase 2
predicts (handwritten 0.29/0.65 vs. printed 0.99/1.00), and remain the
measured basis for it — but the mechanism Phase 2 was written to fix
(a single global threshold) has not yet been shown to be where any field in
this set actually fails. Phase 2's first task is now to determine that before
touching the threshold value.

`date+amount` recall for `form_handwritten` is still 0% after the digit fix —
correctly: Azure's own reading of the handwritten dates is wrong
(`٥/٨/٢٠٠٦` for `٨/٥/٢٠٠٦`; `٢/٢٥١ ٤/٢` for `٢٢/٤/٢٠٢٥`), so no fix to
extraction or verification could recover them. That failure belongs to OCR
fidelity on handwriting, not to this pipeline bug.

**Coverage gap this leaves.** The set has no printed Arabic document using
Arabic-Indic numerals — the tag/label pages are English/ASCII throughout. The
digit fix cannot be shown moving `printed_clean`'s numbers until such a page
(an Egyptian utility bill is the obvious candidate) is added.

### Gate 0
G1 baseline numbers recorded ✅ · G2 script reproducible across runs ✅ ·
G3 the digit fix is tested ✅ (4 tests, `image-analysis-pipeline.test.ts`),
full backend suite unaffected ✅ · G4 user reviews the baseline and the
measured capture resolution ⏳.

> **Descoped 2026-09-10 (user decision):** a unit-test suite for the benchmark
> tool itself (`ocr-benchmark.ts`) was proposed and rejected — the user chose
> to move directly to the next phase of work instead. The tool has now caught
> two of its own bugs by inspection in one session (the whitespace match in
> `criticalRecall`, and calling the extractors directly instead of
> `createImageAnalysisPipeline`), so a regression here is a known, live risk,
> accepted knowingly rather than mitigated. Any oddity in a future benchmark
> run — a metric that doesn't move when the pipeline changed, or moves when it
> didn't — is a reason to suspect the harness before the pipeline.

Phase 1 additionally remains blocked: no master image in the set exceeds
1.92 MP, so the resolution question cannot be measured yet. Phase 2's opening
question is now "which of the three unverified-causes actually accounts for
handwritten fields in a larger sample" rather than "what should the
handwritten threshold be" — the latter presumes an answer the data does not
yet give.

---

## Phase 1 · Capture fidelity — *a defect fix; the accuracy gain is unproven*

> **Reprioritised 2026-09-09.** This phase was written as "the largest expected
> gain". The one experiment available to test that claim did not support it —
> see [The resolution experiment](#the-resolution-experiment-2026-09-09) below.
> It is now sequenced **after Phase 2** and justified as a correctness fix, not
> an accuracy improvement.

### The resolution experiment — 2026-09-09

No masters above 1.92 MP will be available, so the planned 0.92 → 8.3 MP
comparison cannot be run. What could be run: downscale the six owner-verified
masters to 0.92 MP — exactly what `ResolutionPreset.high` produces today — and
score both sets against the same ground truth. `HighQualityBicubic`, JPEG
quality 95, so resolution is the only variable.

```
                    1.92 MP    0.92 MP     delta
form_handwritten
  CER                 35.0%  →   41.5%     +6.5   worse
  WER                 52.0%  →   58.8%     +6.8   worse
  mean confidence     74.3%  →   75.1%     +0.8   better
handwritten_prose
  CER                 58.9%  →   55.5%     −3.4   BETTER at lower res
printed_clean
  CER                  0.0%  →    0.0%        —
ALL
  CER                 27.3%  →   30.0%     +2.7   worse
  mean confidence     81.6%  →   82.2%     +0.6   better
  date+amount         50.0%  →   50.0%        —
```

**This is a null result, and it was called as one in advance** — a positive
result would have been strong evidence, a null one weak. One category degraded
by 6.5 CER points on n=3, comfortably inside noise; another *improved* at lower
resolution; the verdict metric did not move; and mean confidence — the only
figure here that depends on no transcription at all — did not fall.

It does not show resolution is irrelevant. The step tested is 2×, not the 9×
the phase proposes, and both points may sit in the same flat low region with
any gain appearing only above ~4 MP. **It removes the evidence for the phase
without supplying evidence against it.**

What it does settle is where the handwriting problem is *not*:

```
                 1.92 MP    0.92 MP
printed           97.2%  →   97.6%
handwritten       74.3%  →   75.1%
                        ↑
        the gap, and the 0.85 threshold inside it, are unchanged
```

Azure's confidence in handwriting is intrinsically low and does not move with
resolution. **The handwriting failure is a thresholding problem, not a pixel
problem** — which is Phase 2. `verified` also fell 33.3% → 0% on the same three
documents purely from downscaling, further evidence that verification is
unstable rather than merely mis-tuned.

### Remaining justification for this phase

The camera is configured to produce **0.92 MP** while the app's own quality gate
sets `_resAcceptable` at **1.00 MP**. Capture cannot satisfy the bar capture is
judged against. That is a self-contradiction in the codebase and is worth fixing
on its own terms — but the change must not be described as an accuracy
improvement, because no measurement supports that.

Risks stay unverified without devices: a ~5× payload on weak connections, OOM on
low-end Android, and presets a device refuses. They are handled defensively (a
descending fallback ladder and a byte ceiling), and recorded here as **accepted
assumptions, not verified results**.



Raising the acceptance bar without raising the capture resolution would tell
users their photo is inadequate while giving them no way to succeed. **These
must ship together.**

| # | Task | Detail | Status |
|---|---|---|---|
| 1 | F17-T06 | Raise `ResolutionPreset` with a **graceful descending fallback** (`ultraHigh` → `veryHigh` → `high`) for devices that reject the higher preset — mirroring the existing epoch-guarded init in [`platform_camera_service.dart:47`](../../lib/features/capture/data/services/platform_camera_service.dart#L47) | TODO |
| 2 | F17-T07 | Verify `takePicture()` keeps the highest JPEG quality available; confirm the frame stream still starts at the new preset (F16's detector reads the luma plane) | TODO |
| 3 | F17-T08 | Retune `_resGood` / `_resAcceptable` from T04's measured values — **per platform if T04 shows they differ** (see below) | TODO |
| 4 | F17-T09 | Retune `_blurGood` / `_blurAcceptable` from golden-set data — current values (100 / 50) are unmeasured guesses | TODO |
| 5 | F17-T10 | **Payload bound** — enforce a ceiling below `max_image_bytes` (8,000,000; [migration](../../supabase/migrations/20260801120000_bump_schema_version_v2.sql#L21)). Base64 inflates by ~33%, so 8 MB decoded ≈ 10.7 MB on the wire | TODO |
| 6 | F17-T11 | Memory + thermal check on a low-end Android device — 8 MP decode in [`DartImageQualityService`](../../lib/features/capture/data/services/dart_image_quality_service.dart) must not OOM | TODO |
| 7 | F17-T12 | Tests for the fallback ladder, the new thresholds, and the payload bound | TODO |

### T04 branches this phase — the two possible outcomes

`ResolutionPreset` is a Flutter-level name each platform translates into its
own native setting. Android maps `high` to roughly 1280×720 predictably. iOS
maps it to `AVCaptureSessionPresetHigh`, and iOS distinguishes the **session
preset** (which governs the preview/video stream) from the **photo output**
(which can capture at full sensor resolution regardless). So the same line may
produce 0.92 MP on Android and 12 MP on iOS.

| T04 finds | Phase 1 becomes |
|---|---|
| Both platforms ~720p | One shared fix; one set of thresholds |
| iOS already high-resolution | **Android-only fix**, and `_resGood`/`_resAcceptable` must be tuned **per platform** — a single shared constant would fix one platform by breaking the other |

This is why no constant may be chosen before T04 runs.

### Why `ultraHigh`, not `max`

`max` is unbounded — on a 108 MP sensor it produces a file far over
`max_image_bytes`, and the request is rejected with `400 INVALID_REQUEST`
*after* the user has waited through capture. `ultraHigh` is ~270 DPI on A4,
comfortably above Azure's 50 px line-height guidance, and predictable in size.

If T10 shows even `ultraHigh` exceeds the bound on some devices, the resolution
is a **bounded re-encode** — reduce JPEG quality toward a byte target while
holding pixel dimensions. Downscaling pixels is the last resort, because pixels
are exactly what this phase exists to add.

**Risk:** a ~5× larger payload on a weak Egyptian mobile connection. T10 must
record upload time on a throttled connection, not only on Wi-Fi.

### Gate 1
G1 every new constant traced to a T04/T05 measurement · G2 full re-run vs
baseline, per category · G3 format + analyze + test green, on-device smoke test
passed · G4 user approves.

**Continue when:** handwritten CER improves by **≥ 15 points**, the
**date+amount exact-match rate improves on every category** (no regression on
printed pages), and photo rejection stays **< 20%**. Any miss is a finding — we
stop, present it, and amend the plan rather than proceeding on hope.

---

## Phase 2 · Handwriting awareness — *the largest gain in trustworthiness*

This phase does not improve OCR accuracy. It makes the app **honest about**
its accuracy, which is what `CLAUDE.md` §7 requires: *"الثقة على مستوى
المعلومة لا المستند"*.

| # | Task | Detail | Status |
|---|---|---|---|
| 1 | F17-T13 | Parse `analyzeResult.styles[]`; extend `AzureReadResult` with handwritten spans. Follow `flattenWords()`'s tolerant shape — a malformed `styles` yields `[]`, never an error | TODO |
| 2 | F17-T14 | Map each word to printed/handwritten via span offsets (`AzureWord.offset`/`length` already carry them) | TODO |
| 3 | F17-T15 | Split `VERIFIED_CONFIDENCE_THRESHOLD` into `VERIFIED_PRINTED` (0.85, unchanged) and `VERIFIED_HANDWRITTEN` — **value set by Phase 0 data, not guessed** | TODO |
| 4 | F17-T16 | Carry a document-level "contains handwriting" flag to the client via `analyze-response.ts` → [`analysis_response_mapper.dart`](../../lib/features/analysis/data/mappers/analysis_response_mapper.dart). Note F13 locked decision #6: `VerificationStatus` itself never crosses the wire — only this boolean does | TODO |
| 5 | F17-T17 | Arabic banner in [`ar_strings.dart`](../../lib/core/localization/ar_strings.dart) + `en_strings.dart`: «الورقة دي مكتوبة بخط اليد — راجع الأرقام والتواريخ كويس». Reuse the existing banner widget; do not add a new one | TODO |
| 6 | F17-T18 | **Handwritten dates and amounts always surface for review**, whatever their score — they drive reminders and money | TODO |
| 7 | F17-T19 | Unit tests for both thresholds, span mapping, and the always-review rule | TODO |

**Backend deploy required.** Phase 2 changes Edge Functions, so its gate
includes a dev-project deploy and an end-to-end run before production.

### Gate 2
G1 `VERIFIED_HANDWRITTEN` justified by measured distribution · G2 `verified`
rate on handwritten pages is meaningfully between 0% and 100%, printed pages
unchanged · G3 `deno test` + Flutter suite green · G4 user approves.

---

## Phase 3 · Sharpness gate at capture

`doclens` already computes variance-of-Laplacian per frame and publishes it on
`DetectionEvent.sharpness` ([`platform_interface.dart:27`](file:///C:/Users/Darwish/AppData/Local/Pub/Cache/hosted/pub.dev/doclens-0.0.8/lib/src/platform_interface.dart)).
The app ignores it. Preventing a blurred capture is cheaper and more reliable
than detecting one afterwards.

| # | Task | Detail | Status |
|---|---|---|---|
| 1 | F17-T20 | Surface `sharpness` through the existing detection-event path | TODO |
| 2 | F17-T21 | Smooth over ~5 frames — a raw per-frame value flickers and would strobe the UI | TODO |
| 3 | F17-T22 | Calibrate the threshold against golden-set blur data | TODO |
| 4 | F17-T23 | Shutter shows a **visual warning** — «ثبّت الموبايل شوية» — while unsteady | TODO |
| 5 | F17-T24 | **The shutter is never disabled.** Older users and users with tremor may be unable to satisfy it; blocking them entirely is worse than a slightly blurred read (F16 locked decision #4 — graceful degradation is the default) | TODO |
| 6 | F17-T25 | RTL, Large Text, and never colour-alone (design-system rule) | TODO |
| 7 | F17-T26 | Widget tests for the warning state | TODO |

### Gate 3
G1 threshold measured · G2 fewer blur-rejected captures with no drop in capture
success · G3 suite green + on-device check · G4 user approves.

---

## Phase 4 · Split the display rendition from the OCR rendition

What the user looks at and what the model reads are different images with
different goals. This is what CamScanner actually does, and it is the *only*
place enhancement belongs.

| # | Task | Detail | Status |
|---|---|---|---|
| 1 | F17-T27 | Split the paths in [`doclens_perspective_corrector.dart:40`](../../lib/features/capture/data/services/doclens_perspective_corrector.dart#L40) | TODO |
| 2 | F17-T28 | **OCR rendition** — `ImageEnhancement.none`, unchanged (locked decision #1) | TODO |
| 3 | F17-T29 | **Display rendition** — `ImageEnhancement.enhanced` for the on-screen and saved image | TODO |
| 4 | F17-T30 | User choice: **ألوان محسّنة · أبيض وأسود · أصلي**, matching the approved design | TODO |
| 5 | F17-T31 | Display rendition is AES-256-GCM encrypted on save; the OCR rendition and every temp file are deleted immediately after the read (§7) | TODO |
| 6 | F17-T32 | **Regression test: the enhanced rendition must never reach `analyzeImage()`.** This is the guard that keeps locked decision #1 true as the code evolves | TODO |

> ⚠️ Two renditions means two files on disk at once. T31 must prove both are
> cleaned up on the success path, the failure path, and the cancel path.

### Gate 4
G1 no accuracy-affecting constants introduced · G2 OCR metrics **unchanged**
from Phase 3 — any movement means enhanced bytes leaked into the OCR path ·
G3 suite green, T32 proven to fail if the paths are swapped · G4 user approves.

---

## Phase 5 · Illumination flattening — *conditional; likely unnecessary*

> **Do not start this phase unless Phases 1–4 are complete and the measurements
> still show a specifically illumination-related failure mode.** This is the
> one phase that can make things worse.

| # | Task | Detail | Status |
|---|---|---|---|
| 1 | F17-T33 | Re-examine Phase 4 results: are the remaining errors actually shadow/lighting failures, or something else? | TODO |
| 2 | F17-T34 | If yes: illumination flattening (background division) on the OCR rendition — **grayscale preserved, no binarisation** | TODO |
| 3 | F17-T35 | Mandatory A/B over the golden set | TODO |
| 4 | F17-T36 | **If the gain is < 5 points, revert and delete the code.** Unmeasured image processing is a liability, not an asset | TODO |

### Gate 5
G1 measured gain ≥ 5 points, or the phase is reverted · G2 full A/B shown ·
G3 suite green · G4 user approves.

---

## Sequence

```
Phase 0  Measurement harness        no production code
   │
   └── Gate 0 ─── user sign-off required
Phase 1  Capture fidelity           ⭐ largest expected accuracy gain
   │
   └── Gate 1 ─── user sign-off required
Phase 2  Handwriting awareness      ⭐ largest trustworthiness gain · backend deploy
   │
   └── Gate 2 ─── user sign-off required
Phase 3  Sharpness gate
   │
   └── Gate 3 ─── user sign-off required
Phase 4  Display / OCR split
   │
   └── Gate 4 ─── user sign-off required
Phase 5  Illumination flattening    conditional — expected to be skipped
   │
   └── Gate 5
```

---

## Verification

Per phase, before its gate is presented:

```bash
dart format .
flutter analyze
flutter test
```

Backend phases (Phase 2) additionally:

```bash
deno test supabase/tests/unit/
```

Measurement, every phase from 1 onward:

```bash
# aggregate metrics only — never document text
deno run --allow-read --allow-env --allow-net \
  supabase/tools/ocr-benchmark.ts --set golden/ --baseline baseline.json
```

**Deno, not Dart, and it bypasses the Edge Function.** Two constraints force
this:

1. **It must reuse the real pipeline.** The extractors and the verification
   logic being measured live in
   [`_shared/extractors/`](../../supabase/functions/_shared/extractors/) and
   [`_shared/verification/`](../../supabase/functions/_shared/verification/) as
   TypeScript. A Dart harness would have to reimplement them, and would then be
   measuring a copy rather than the code that ships.
2. **It must not go through `analyze-handler.ts`.** That handler reserves a
   quota slot, and `dailyAnalysisLimit` is **3 per Cairo day** — a 30-document
   run would take ten days. The benchmark calls Azure directly using
   `azureOptionsFromEnv()` and the same model/API version as
   [`azure-client.ts`](../../supabase/functions/_shared/azure/azure-client.ts),
   then feeds the result through the real extractors and `verifyCandidates`.

Groq is never called: this feature measures OCR fidelity and field extraction,
not explanation quality.

On-device, Phases 1 and 3: physical Android **and** physical iOS, per the
`dev-run-on-physical-device` constraint (LAN `SUPABASE_URL` override plus a
running local Supabase, or the splash never completes).

---

## Resolved with the user — 2026-09-09

1. **Golden set sourcing.** The user supplies the documents, including the 8
   handwritten pages. Phase 0 cannot start until they arrive; F17-T03 (the
   measurement script) and F17-T04 (the capture probe) can be built in parallel
   while waiting, since neither needs the documents.
2. **Expectations — agreed.** 100% is not achievable by any OCR system.
   Realistic bands: printed clean 96–99%, printed poor 85–93%, **handwritten
   Arabic 70–88%**. The goal is to reach the top of those bands *and to be
   honest whenever we fall outside them* — not to eliminate error. This is what
   Phase 2 exists for.
3. **Rollout — no feature flag.** The app is not published and has no real
   users, so there is nobody to protect from a bad capture change and a
   `RuntimeConfig` entry would be unused complexity. The resolution is set
   directly in [`platform_camera_service.dart`](../../lib/features/capture/data/services/platform_camera_service.dart).
   > **Revisit before launch.** Capture resolution has device-dependent failure
   > modes (OOM on low-end Android, slow upload on weak connections, presets a
   > device refuses) that two test devices cannot cover. If this ships to real
   > users, promoting the tier to `RuntimeConfig` turns a store-review cycle
   > into a database update.

---

## Sources

- [Language and locale support for Read and Layout — Azure Document Intelligence v4.0](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/language-support/ocr?view=doc-intel-4.0.0)
- [Read model OCR data extraction](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/prebuilt/read?view=doc-intel-4.0.0)
