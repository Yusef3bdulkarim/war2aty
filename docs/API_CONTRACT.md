# API Contract — War2aty Analysis Service

Defines the JSON contract between the Flutter app and the Supabase Edge Function
(`analyze-document`).

**v2 (F13-T09) is a privacy-model change.** Through v1, the app sent text
only and the image never left the device. From v2, a request's `input_type`
picks one of two shapes: `"text"` (unchanged — OCR text + on-device
candidates, image never leaves the device) or `"image"` (new — the photo
itself is sent, gated behind an operator flag, so it can be read online —
historical: F13 read it with Azure/Google Document AI; F20 replaced both with
Gemini, see below). Every request, either shape, still declares
`schema_version: "2.0"`; a v1 body (no `input_type`) is rejected with
`UNSUPPORTED_SCHEMA`. See `docs/features/F13-ocr-provider-migration.md`
locked decisions #1 and #7.

**F20 update.** Since F20-T15 each endpoint takes one shape. `analyze-document`
accepts the text shape only; an image-shaped body is `400 INVALID_REQUEST`.
The image shape (§29b) is the request body of `ocr-document`, which reads the
photo with Gemini and returns the text and candidates for review, behind the
`online_ocr_enabled` operator flag (F20-T14; was `azure_ocr_enabled`). The text
is analysed by Mistral, falling back to Groq inside the same request (one
quota slot either way). When `ocr-document` fails with one of the four
failures in §31 client rule 7, the app reads the page on the device instead
and shows a warning; any other failure is shown as it is. See
`docs/features/F20-ocr-analysis-provider-refactor.md`.

**F36 addition — a second, independent contract.** §33 defines
`explain-document`, the F34 pivot's one-call endpoint: photo in, explanation
cards out. It is versioned on its **own** key (`explain_schema_version`,
starting at `"1.0"`) and shares no request or response shape with v2. Everything
above §33 describes the v2 endpoints, which are **frozen** while published 1.0.x
builds depend on them. See `docs/features/F36-server-explain-document.md`.

---

## §29 · Analysis Request — Text shape (JSON Schema v2)

### Endpoint

`POST /functions/v1/analyze-document`

**Auth header:** `Authorization: Bearer <supabase-anon-jwt>`

### Request body

```jsonc
{
  // ── envelope ──────────────────────────────────────────────────────
  "schema_version": "2.0",            // locked; reject if mismatch
  "session_id":     "uuid-v4",        // AnalysisSession.id
  "installation_id":"uuid-v4",        // per-install identity
  "app_version":    "1.0.0",          // semantic version of the app
  "input_type":     "text",           // discriminant (v2) — "text" | "image", see §29b

  // ── OCR payload ───────────────────────────────────────────────────
  "ocr_text":            "...",        // NormalizedOcrText.cleanedText
  "detected_languages":  ["ar","en"],  // BCP-47 tags from OCR engine

  // ── extracted candidates ──────────────────────────────────────────
  "candidates": {
    "dates": [
      {
        "raw_text":        "2024/03/15",
        "normalized_date": "2024-03-15", // ISO-8601 date or null
        "is_ambiguous":    false
      }
    ],
    "times": [
      {
        "raw_text":     "9:30 ص",
        "hour":         9,               // 0-23
        "minute":       30,              // 0-59
        "is_ambiguous": false
      }
    ],
    "amounts": [
      {
        "raw_text":     "850.50 جنيه",
        "value":        850.50,          // parsed number or null
        "currency":     "EGP",           // ISO-4217 code or null
        "is_ambiguous": false
      }
    ],
    "phones": [
      {
        "raw_text":           "0100-123-4567",
        "normalized_number":  "01001234567",
        "is_ambiguous":       false
      }
    ],
    "references": [
      {
        "raw_text":     "رقم الفاتورة 12345678",
        "value":        "12345678",
        "is_ambiguous": true             // always true for references
      }
    ]
  }
}
```

### JSON Schema (draft-07)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://war2aty.app/schemas/analyze-request-text-v2.json",
  "title": "AnalyzeDocumentTextRequest",
  "description": "Text-shape request payload for the analyze-document Edge Function (v2).",
  "type": "object",
  "required": [
    "schema_version",
    "session_id",
    "installation_id",
    "app_version",
    "input_type",
    "ocr_text",
    "detected_languages",
    "candidates"
  ],
  "additionalProperties": false,
  "properties": {
    "schema_version": {
      "type": "string",
      "const": "2.0",
      "description": "Contract version. Server MUST reject unknown versions."
    },
    "session_id": {
      "type": "string",
      "format": "uuid",
      "description": "UUID v4 for this analysis session."
    },
    "installation_id": {
      "type": "string",
      "format": "uuid",
      "description": "Stable per-install identifier from flutter_secure_storage."
    },
    "app_version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$",
      "description": "Semantic version of the client app."
    },
    "input_type": {
      "type": "string",
      "const": "text",
      "description": "Discriminant. This schema only accepts \"text\" — see §29b for \"image\"."
    },
    "ocr_text": {
      "type": "string",
      "minLength": 1,
      "maxLength": 12000,
      "description": "Normalized OCR text (digits unified, whitespace collapsed). Max from RuntimeConfig.maxOcrCharacters."
    },
    "detected_languages": {
      "type": "array",
      "items": { "type": "string", "pattern": "^[a-z]{2,3}$" },
      "description": "BCP-47 language tags detected by the OCR engine."
    },
    "candidates": {
      "type": "object",
      "required": ["dates", "times", "amounts", "phones", "references"],
      "additionalProperties": false,
      "properties": {
        "dates": {
          "type": "array",
          "items": { "$ref": "#/definitions/date_candidate" }
        },
        "times": {
          "type": "array",
          "items": { "$ref": "#/definitions/time_candidate" }
        },
        "amounts": {
          "type": "array",
          "items": { "$ref": "#/definitions/amount_candidate" }
        },
        "phones": {
          "type": "array",
          "items": { "$ref": "#/definitions/phone_candidate" }
        },
        "references": {
          "type": "array",
          "items": { "$ref": "#/definitions/reference_candidate" }
        }
      }
    }
  },
  "definitions": {
    "date_candidate": {
      "type": "object",
      "required": ["raw_text", "is_ambiguous"],
      "additionalProperties": false,
      "properties": {
        "raw_text":        { "type": "string", "minLength": 1 },
        "normalized_date": { "type": ["string", "null"], "format": "date" },
        "is_ambiguous":    { "type": "boolean" }
      }
    },
    "time_candidate": {
      "type": "object",
      "required": ["raw_text", "hour", "minute", "is_ambiguous"],
      "additionalProperties": false,
      "properties": {
        "raw_text":     { "type": "string", "minLength": 1 },
        "hour":         { "type": "integer", "minimum": 0, "maximum": 23 },
        "minute":       { "type": "integer", "minimum": 0, "maximum": 59 },
        "is_ambiguous": { "type": "boolean" }
      }
    },
    "amount_candidate": {
      "type": "object",
      "required": ["raw_text", "is_ambiguous"],
      "additionalProperties": false,
      "properties": {
        "raw_text":     { "type": "string", "minLength": 1 },
        "value":        { "type": ["number", "null"] },
        "currency":     { "type": ["string", "null"] },
        "is_ambiguous": { "type": "boolean" }
      }
    },
    "phone_candidate": {
      "type": "object",
      "required": ["raw_text", "normalized_number", "is_ambiguous"],
      "additionalProperties": false,
      "properties": {
        "raw_text":          { "type": "string", "minLength": 1 },
        "normalized_number": { "type": "string", "minLength": 1 },
        "is_ambiguous":      { "type": "boolean" }
      }
    },
    "reference_candidate": {
      "type": "object",
      "required": ["raw_text", "value", "is_ambiguous"],
      "additionalProperties": false,
      "properties": {
        "raw_text":     { "type": "string", "minLength": 1 },
        "value":        { "type": "string", "minLength": 1 },
        "is_ambiguous": { "type": "boolean" }
      }
    }
  }
}
```

### Field mapping from domain entities

| JSON field | Source |
|---|---|
| `schema_version` | `RuntimeConfig.schemaVersion` (currently `"2.0"`) |
| `session_id` | `AnalysisSession.id` |
| `installation_id` | `InstallationIdProvider.getOrCreate()` |
| `app_version` | `PackageInfo.version` (package_info_plus) |
| `input_type` | `"text"` — literal, set by the offline/Tesseract capture path |
| `ocr_text` | `ExtractionResult.text.cleanedText` |
| `detected_languages` | `OcrResult.detectedLanguages` |
| `candidates.dates[].raw_text` | `DateCandidate.rawText` |
| `candidates.dates[].normalized_date` | `DateCandidate.normalizedDate?.toIso8601String()` (date part) |
| `candidates.dates[].is_ambiguous` | `DateCandidate.isAmbiguous` |
| `candidates.times[].raw_text` | `TimeCandidate.rawText` |
| `candidates.times[].hour` | `TimeCandidate.hour` |
| `candidates.times[].minute` | `TimeCandidate.minute` |
| `candidates.times[].is_ambiguous` | `TimeCandidate.isAmbiguous` |
| `candidates.amounts[].raw_text` | `AmountCandidate.rawText` |
| `candidates.amounts[].value` | `AmountCandidate.value` |
| `candidates.amounts[].currency` | `AmountCandidate.currency` |
| `candidates.amounts[].is_ambiguous` | `AmountCandidate.isAmbiguous` |
| `candidates.phones[].raw_text` | `PhoneCandidate.rawText` |
| `candidates.phones[].normalized_number` | `PhoneCandidate.normalizedNumber` |
| `candidates.phones[].is_ambiguous` | `PhoneCandidate.isAmbiguous` |
| `candidates.references[].raw_text` | `ReferenceCandidate.rawText` |
| `candidates.references[].value` | `ReferenceCandidate.value` |
| `candidates.references[].is_ambiguous` | `ReferenceCandidate.isAmbiguous` |

### Validation rules (server-side)

1. **Schema version** — reject `schema_version != "2.0"` with `400 UNSUPPORTED_SCHEMA`.
2. **App version** — reject if below `RuntimeConfig.minimumAppVersion` with `400 UNSUPPORTED_APP_VERSION`.
3. **OCR text** — reject if empty or exceeds `maxOcrCharacters` (12 000) with `400 INVALID_REQUEST`.
4. **Daily limit** — check `installation_id` usage count for the current `Africa/Cairo` day. Reject with `429 DAILY_LIMIT_REACHED` and include `reset_at` (Cairo midnight ISO-8601).
5. **Analysis disabled** — if `RuntimeConfig.analysisEnabled == false`, reject with `503 ANALYSIS_DISABLED`.
6. **Candidate arrays** — may be empty (document with no extractable fields is valid).
7. **Global capacity** — a second, independent cap on total calls across *all* users for the
   current `Africa/Cairo` day. Reject with `429 GLOBAL_CAPACITY_REACHED` (no `reset_at`).
   Checked atomically inside the same reservation as rule 4, never as a separate pre-check.
   Unlike rule 4 this cap **fails open**: an unset or non-positive `global_daily_call_cap`
   means unlimited, because it is an optional spend valve and a misconfigured row must not
   block every user.
8. **`input_type`** — must be exactly `"text"` on this shape. A body that otherwise matches
   §29 but carries a different (or missing) `input_type` is `400 INVALID_REQUEST`, not treated
   as a v1 client — v1 had no such field and would already fail rule 1.

### Privacy guarantees

- **No image data on this shape.** A text-shape request contains text only — no bytes,
  thumbnails, EXIF, or GPS. `additionalProperties: false` means an `image` key here is rejected
  outright, never silently ignored (§29b is the only shape that may carry image bytes, sent
  only to `ocr-document`, and only once `online_ocr_enabled` is on).
- **No logging of content.** The Edge Function MUST NOT log `ocr_text`, candidate values, image
  bytes, or any derived analysis content. Only envelope fields (`session_id`, `installation_id`,
  `schema_version`, `input_type`) and status codes may be logged.
- **Candidates are hints.** The AI uses them as structured hints alongside the raw text. They do not replace the AI's own reading of `ocr_text`.

---

## §29b · Image-intake shape (JSON Schema v2, F13-T09; `ocr-document` since F20)

The request body of `POST /functions/v1/ocr-document`, behind `RuntimeConfig.onlineOcrEnabled`
(`online_ocr_enabled`, off by default). `analyze-document` no longer accepts it (F20-T15).

### Request body

```jsonc
{
  // ── envelope — identical meaning to §29 ────────────────────────────
  "schema_version":  "2.0",
  "session_id":      "uuid-v4",
  "installation_id": "uuid-v4",
  "app_version":      "1.0.0",
  "input_type":       "image",

  // ── the photo ───────────────────────────────────────────────────────
  "image": {
    "data":      "<base64>",       // the capture as the user confirmed it (rotated/cropped), never a thumbnail
    "mime_type": "image/jpeg"      // "image/jpeg" | "image/png" only
  }
}
```

### JSON Schema (draft-07)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://war2aty.app/schemas/analyze-request-image-v2.json",
  "title": "AnalyzeDocumentImageRequest",
  "description": "Image-intake request payload for the analyze-document Edge Function (v2).",
  "type": "object",
  "required": ["schema_version", "session_id", "installation_id", "app_version", "input_type", "image"],
  "additionalProperties": false,
  "properties": {
    "schema_version": { "type": "string", "const": "2.0" },
    "session_id":      { "type": "string", "format": "uuid" },
    "installation_id": { "type": "string", "format": "uuid" },
    "app_version":     { "type": "string", "pattern": "^\\d+\\.\\d+\\.\\d+$" },
    "input_type": {
      "type": "string",
      "const": "image",
      "description": "Discriminant. This schema only accepts \"image\" — see §29 for \"text\"."
    },
    "image": {
      "type": "object",
      "required": ["data", "mime_type"],
      "additionalProperties": false,
      "properties": {
        "data": {
          "type": "string",
          "contentEncoding": "base64",
          "description": "Base64-encoded image bytes. Rejected 400 INVALID_REQUEST if the decoded size exceeds RuntimeConfig.maxImageBytes."
        },
        "mime_type": {
          "type": "string",
          "enum": ["image/jpeg", "image/png"]
        }
      }
    }
  }
}
```

### Validation rules (server-side)

1. **Schema version / `input_type`** — same as §29 rules 1 and 8, with `input_type` fixed to `"image"`.
2. **App version** — same as §29 rule 2.
3. **`image.mime_type`** — must be `image/jpeg` or `image/png`; anything else is `400 INVALID_REQUEST`.
4. **`image.data`** — must be well-formed base64; a decoded size over `RuntimeConfig.maxImageBytes`
   is `400 INVALID_REQUEST`, rejected before the bytes are ever handed to the reader.
5. **Gate** — `RuntimeConfig.onlineOcrEnabled`. Off (the default), `ocr-document` answers
   `502 OCR_UNAVAILABLE` before the body is parsed, so the app reads the page on the device
   instead (F20 matrix O10).

### Privacy guarantees

- **The image legitimately reaches `ocr-document`** — this shape exists specifically to send it.
  It is forwarded to Gemini for reading, and never logged or persisted on our side. Gemini's free
  tier may retain it and let people review it (F20 context §3, accepted by the owner); user-facing
  copy says so without naming the provider (F20-T24). No thumbnail, EXIF, or GPS field exists on
  this shape to accidentally include.
- **No logging of the image or its derived text.** Same rule as §29.

---

## §30 · Analysis Response — JSON Schema v2

### Success response (`200 OK`)

```jsonc
{
  // ── envelope ──────────────────────────────────────────────────────
  "schema_version": "2.0",
  "session_id":     "uuid-v4",           // echoed from request
  "status":         "success",           // "success" | "partial" | "unsupported"

  // ── document classification ───────────────────────────────────────
  "document_type": {
    "type":       "invoice",             // enum — see §30.1
    "title":      "فاتورة كهرباء",        // AI-generated Arabic display title
    "confidence": "high"                 // "high" | "medium" | "low"
  },

  // ── summary ───────────────────────────────────────────────────────
  "summary": {
    "short":    "فاتورة كهرباء لشهر مارس 2024 بمبلغ 850 جنيه.",
    "detailed": "دي فاتورة كهرباء من شركة جنوب القاهرة لتوزيع الكهرباء..."
  },

  // ── key information ───────────────────────────────────────────────
  "key_information": [
    {
      "label":      "رقم الحساب",
      "value":      "12345678",
      "confidence": "high",              // "high" | "medium" | "low"
      "source":     "extracted"          // "extracted" | "inferred"
    }
  ],

  // ── dates & times ─────────────────────────────────────────────────
  "dates": [
    {
      "label":              "آخر موعد للسداد",
      "date":               "2024-04-15",  // ISO-8601 date
      "time":               "14:30",       // HH:mm or null if not on document
      "role":               "deadline",    // enum — see §30.2
      "is_reminder_worthy": true,
      "confidence":         "high",
      "rawValue":           "15/4/2024"    // literal text this was read from, or null (v2, F13-T09)
    }
  ],

  // ── amounts ───────────────────────────────────────────────────────
  "amounts": [
    {
      "label":      "إجمالي المبلغ",
      "value":      850.50,
      "currency":   "EGP",
      "confidence": "high",
      "rawValue":   "850.50 جنيه"          // literal text this was read from, or null (v2, F13-T09)
    }
  ],

  // ── phones & references (v2, F13-T09) ──────────────────────────────
  // Always empty since F20-T15: they were filled only by the cross-provider
  // verification layer (F13-T08), which F20 deleted with the image-analysis
  // path. Kept on the v2 wire so clients need no change; never a raw,
  // unconfirmed regex hit.
  "phones": [
    {
      "rawValue":        "0100-123-4567",
      "value":           "01001234567",
      "needsUserReview": false
    }
  ],
  "references": [
    {
      "rawValue":        "رقم الفاتورة 12345678",
      "value":           "12345678",
      "needsUserReview": true
    }
  ],

  // ── actions required ──────────────────────────────────────────────
  "actions_required": [
    {
      "description": "سدد الفاتورة قبل 15 أبريل 2024.",
      "basis":       "explicit",         // "explicit" | "inferred"
      "priority":    "high"              // "high" | "normal"
    }
  ],

  // ── required documents (for government/official papers) ───────────
  "required_documents": [
    "بطاقة الرقم القومي",
    "إيصال سداد سابق"
  ],

  // ── instructions ──────────────────────────────────────────────────
  "instructions": [
    "توجه لأقرب فرع شركة الكهرباء.",
    "يمكنك السداد إلكترونيًا عبر فوري."
  ],

  // ── warnings / disclaimers ────────────────────────────────────────
  "warnings": [
    {
      "text": "المبالغ المذكورة قراءة غير مؤكدة — راجع الأصل.",
      "type": "general"                  // enum — see §30.3
    }
  ],

  // ── partial analysis metadata ─────────────────────────────────────
  "missing_fields": []                   // field names the AI couldn't resolve
}
```

### §30.1 · `document_type.type` enum

| Value | Description |
|---|---|
| `invoice` | Utility bill, telecom bill, subscription invoice |
| `receipt` | Payment receipt, purchase receipt |
| `appointment` | Medical appointment, official meeting, reservation |
| `government` | Government letter, official notice, tax notice |
| `exam` | Exam result, grade report, certificate |
| `medical` | Medical report, lab result, prescription |
| `legal` | Legal document, contract, court notice |
| `financial` | Bank statement, insurance document |
| `educational` | School notice, university letter, enrollment |
| `other` | Anything that doesn't fit the above |

### §30.2 · `dates[].role` enum

| Value | Description |
|---|---|
| `deadline` | Payment due date, submission deadline |
| `appointment` | Scheduled meeting, visit, reservation time |
| `issued` | Date the document was created/issued |
| `expiry` | Expiration date (license, certificate, offer) |
| `event` | General event date (exam, ceremony) |
| `period_start` | Start of a billing/coverage period |
| `period_end` | End of a billing/coverage period |

### §30.3 · `warnings[].type` enum

| Value | Description |
|---|---|
| `medical` | "هذا التقرير لا يغني عن استشارة الطبيب" |
| `legal` | "استشر محامي قبل اتخاذ أي إجراء قانوني" |
| `government` | "تأكد من صحة البيانات من الجهة الرسمية" |
| `financial` | "راجع البنك أو الجهة المالية للتأكيد" |
| `general` | Catch-all for unclassified warnings |

### §30.4 · `status` semantics

| Status | Meaning | Client behavior |
|---|---|---|
| `success` | Full analysis completed | Show all sections normally |
| `partial` | Analysis completed but some fields are uncertain/missing | Show result with `missing_fields` banner and "راجع المعلومة" labels |
| `unsupported` | Document type not supported or text too garbled | Show "غير مدعومة" screen; offer OCR-only fallback |

### §30.5 · Confidence bands

The AI assigns `"high"`, `"medium"`, or `"low"` per field. The client maps these:

| Band | UI treatment |
|---|---|
| `high` | Display value normally |
| `medium` | Display with "راجع المعلومة" badge |
| `low` | Display with "قراءة غير مؤكدة" warning; value is editable |

A field's `source` indicates whether it was directly `"extracted"` from the text or
`"inferred"` by the AI. Inferred values always show a basis indicator in the UI
regardless of confidence.

### JSON Schema (draft-07)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://war2aty.app/schemas/analyze-response-v2.json",
  "title": "AnalyzeDocumentResponse",
  "description": "Success response from the analyze-document Edge Function (v2).",
  "type": "object",
  "required": [
    "schema_version",
    "session_id",
    "status",
    "document_type",
    "summary"
  ],
  "additionalProperties": false,
  "properties": {
    "schema_version": {
      "type": "string",
      "const": "2.0"
    },
    "session_id": {
      "type": "string",
      "format": "uuid"
    },
    "status": {
      "type": "string",
      "enum": ["success", "partial", "unsupported"]
    },
    "document_type": {
      "$ref": "#/definitions/document_type"
    },
    "summary": {
      "$ref": "#/definitions/summary"
    },
    "key_information": {
      "type": "array",
      "items": { "$ref": "#/definitions/key_info_item" },
      "default": []
    },
    "dates": {
      "type": "array",
      "items": { "$ref": "#/definitions/date_item" },
      "default": []
    },
    "amounts": {
      "type": "array",
      "items": { "$ref": "#/definitions/amount_item" },
      "default": []
    },
    "actions_required": {
      "type": "array",
      "items": { "$ref": "#/definitions/action_item" },
      "default": []
    },
    "required_documents": {
      "type": "array",
      "items": { "type": "string", "minLength": 1 },
      "default": []
    },
    "instructions": {
      "type": "array",
      "items": { "type": "string", "minLength": 1 },
      "default": []
    },
    "warnings": {
      "type": "array",
      "items": { "$ref": "#/definitions/warning_item" },
      "default": []
    },
    "missing_fields": {
      "type": "array",
      "items": { "type": "string" },
      "default": []
    },
    "phones": {
      "type": "array",
      "items": { "$ref": "#/definitions/phone_item" },
      "default": [],
      "description": "v2 (F13-T09). Always empty since F20-T15 deleted the cross-provider verification (F13-T08) that filled it."
    },
    "references": {
      "type": "array",
      "items": { "$ref": "#/definitions/reference_item" },
      "default": [],
      "description": "v2 (F13-T09). Always empty since F20-T15 deleted the cross-provider verification (F13-T08) that filled it."
    }
  },
  "definitions": {
    "confidence": {
      "type": "string",
      "enum": ["high", "medium", "low"]
    },
    "document_type": {
      "type": "object",
      "required": ["type", "title", "confidence"],
      "additionalProperties": false,
      "properties": {
        "type": {
          "type": "string",
          "enum": [
            "invoice", "receipt", "appointment", "government",
            "exam", "medical", "legal", "financial",
            "educational", "other"
          ]
        },
        "title":      { "type": "string", "minLength": 1 },
        "confidence": { "$ref": "#/definitions/confidence" }
      }
    },
    "summary": {
      "type": "object",
      "required": ["short", "detailed"],
      "additionalProperties": false,
      "properties": {
        "short":    { "type": "string", "minLength": 1, "maxLength": 200 },
        "detailed": { "type": "string", "minLength": 1 }
      }
    },
    "key_info_item": {
      "type": "object",
      "required": ["label", "value", "confidence", "source"],
      "additionalProperties": false,
      "properties": {
        "label":      { "type": "string", "minLength": 1 },
        "value":      { "type": "string", "minLength": 1 },
        "confidence": { "$ref": "#/definitions/confidence" },
        "source":     { "type": "string", "enum": ["extracted", "inferred"] }
      }
    },
    "date_item": {
      "type": "object",
      "required": ["label", "date", "role", "is_reminder_worthy", "confidence", "rawValue"],
      "additionalProperties": false,
      "properties": {
        "label":              { "type": "string", "minLength": 1 },
        "date":               { "type": "string", "format": "date" },
        "time":               { "type": ["string", "null"], "pattern": "^([01]\\d|2[0-3]):[0-5]\\d$" },
        "role":               { "type": "string", "enum": ["deadline", "appointment", "issued", "expiry", "event", "period_start", "period_end"] },
        "is_reminder_worthy": { "type": "boolean" },
        "confidence":         { "$ref": "#/definitions/confidence" },
        "rawValue":           { "type": ["string", "null"], "description": "v2 (F13-T09). Literal text this date was matched from; null when inferred." }
      }
    },
    "amount_item": {
      "type": "object",
      "required": ["label", "value", "currency", "confidence", "rawValue"],
      "additionalProperties": false,
      "properties": {
        "label":      { "type": "string", "minLength": 1 },
        "value":      { "type": "number" },
        "currency":   { "type": "string", "minLength": 1 },
        "confidence": { "$ref": "#/definitions/confidence" },
        "rawValue":   { "type": ["string", "null"], "description": "v2 (F13-T09). Literal text this amount was matched from; null when inferred." }
      }
    },
    "phone_item": {
      "type": "object",
      "required": ["rawValue", "value", "needsUserReview"],
      "additionalProperties": false,
      "properties": {
        "rawValue":        { "type": "string", "minLength": 1 },
        "value":           { "type": "string", "minLength": 1 },
        "needsUserReview": { "type": "boolean" }
      }
    },
    "reference_item": {
      "type": "object",
      "required": ["rawValue", "value", "needsUserReview"],
      "additionalProperties": false,
      "properties": {
        "rawValue":        { "type": "string", "minLength": 1 },
        "value":           { "type": "string", "minLength": 1 },
        "needsUserReview": { "type": "boolean" }
      }
    },
    "action_item": {
      "type": "object",
      "required": ["description", "basis", "priority"],
      "additionalProperties": false,
      "properties": {
        "description": { "type": "string", "minLength": 1 },
        "basis":       { "type": "string", "enum": ["explicit", "inferred"] },
        "priority":    { "type": "string", "enum": ["high", "normal"] }
      }
    },
    "warning_item": {
      "type": "object",
      "required": ["text", "type"],
      "additionalProperties": false,
      "properties": {
        "text": { "type": "string", "minLength": 1 },
        "type": { "type": "string", "enum": ["medical", "legal", "government", "financial", "general"] }
      }
    }
  }
}
```

---

## §31 · Error Response Contract

All errors return a JSON body with a single `error` object. The HTTP status code
carries the category; the `code` string is the machine-readable discriminator the
client maps to `AppFailure` subtypes and Arabic copy.

### Error body

```jsonc
{
  "error": {
    "code":    "DAILY_LIMIT_REACHED",
    "message": "Daily analysis limit exceeded.",   // English, machine-use only
    "details": {                                    // optional, code-specific
      "reset_at": "2024-03-16T00:00:00+02:00"
    }
  }
}
```

### Error codes

| HTTP | Code | AppFailure | Details | Description |
|---|---|---|---|---|
| 400 | `INVALID_REQUEST` | `InvalidRequestFailure` | — | Malformed JSON, missing required fields, `ocr_text` empty or too long |
| 400 | `UNSUPPORTED_SCHEMA` | `InvalidRequestFailure` | — | `schema_version` not recognized |
| 400 | `UNSUPPORTED_APP_VERSION` | `UnsupportedAppVersionFailure` | — | `app_version` below `minimumAppVersion` |
| 401 | `UNAUTHORIZED` | `UnauthorizedFailure` | — | Missing/invalid/expired JWT |
| 408 | `TIMEOUT` | `RequestTimeoutFailure` | — | Analysis took longer than `analysisTimeout` |
| 429 | `DAILY_LIMIT_REACHED` | `DailyLimitReachedFailure` | `{ "reset_at": "ISO-8601" }` | Daily quota exhausted for this `installation_id` |
| 429 | `AI_RATE_LIMITED` | `AiProviderRateLimitFailure` | — | Upstream AI provider rate-limited the request |
| 429 | `GLOBAL_CAPACITY_REACHED` | `GlobalCapacityReachedFailure` | — | Service-wide daily call cap (`globalDailyCallCap`) exhausted across **all** users — not this caller's own quota (F13-T02) |
| 500 | `ANALYSIS_FAILED` | `AnalysisServiceFailure` | — | AI returned unusable output or internal error |
| 500 | `INTERNAL_ERROR` | `AnalysisServiceFailure` | — | Unexpected server error |
| 502 | `OCR_UNAVAILABLE` | `OnlineOcrUnavailableFailure` (F20-T18) | — | `ocr-document` only (F20-T12). The online reader gave no usable reading: an upstream outage, a network failure, an unusable or blocked answer, or online reading switched off after the app chose the online route (F20 matrix O5, O10). A deploy fault (bad key or model) is `INTERNAL_ERROR` instead |
| 503 | `ANALYSIS_DISABLED` | `AnalysisDisabledFailure` | — | `analysisEnabled == false` (maintenance) |

### Error JSON Schema (draft-07)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://war2aty.app/schemas/analyze-error-v1.json",
  "title": "AnalyzeDocumentError",
  "description": "Error response from the analyze-document and ocr-document Edge Functions.",
  "type": "object",
  "required": ["error"],
  "additionalProperties": false,
  "properties": {
    "error": {
      "type": "object",
      "required": ["code", "message"],
      "additionalProperties": false,
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "INVALID_REQUEST",
            "UNSUPPORTED_SCHEMA",
            "UNSUPPORTED_APP_VERSION",
            "UNAUTHORIZED",
            "TIMEOUT",
            "DAILY_LIMIT_REACHED",
            "AI_RATE_LIMITED",
            "GLOBAL_CAPACITY_REACHED",
            "ANALYSIS_FAILED",
            "INTERNAL_ERROR",
            "ANALYSIS_DISABLED",
            "OCR_UNAVAILABLE"
          ]
        },
        "message": {
          "type": "string",
          "description": "English description for debugging. NOT user-facing."
        },
        "details": {
          "type": "object",
          "description": "Code-specific payload (e.g. reset_at for DAILY_LIMIT_REACHED).",
          "properties": {
            "reset_at": {
              "type": "string",
              "format": "date-time",
              "description": "Cairo-midnight ISO-8601 when the daily quota resets."
            }
          }
        }
      }
    }
  }
}
```

### Client error-handling rules

1. **Parse `error.code` only** — never show `error.message` to the user. Map each code
   to an `AppFailure` subtype and let the presentation layer produce Arabic copy.
2. **`DAILY_LIMIT_REACHED`** — parse `details.reset_at` into `DailyLimitReachedFailure.resetAtCairo`
   to show the user when they can retry. Do **not** treat `GLOBAL_CAPACITY_REACHED` as this
   code: the caller's own quota is untouched, there is no `reset_at`, and the copy must read
   as a temporary service-side limit rather than "you have used up your analyses".
3. **Unknown codes** — treat any unrecognized `error.code` as `AnalysisServiceFailure`.
4. **Non-JSON responses** — treat as `AnalysisServiceFailure` (server returned HTML error page, etc.).
5. **Network errors** (no response) — map to `NoInternetFailure` or `RequestTimeoutFailure`
   based on the exception type.
6. **`status: "unsupported"`** in a 200 response — this is NOT an error. Map to
   `UnsupportedDocumentFailure` in the domain layer; the result screen shows the
   OCR-only fallback (F07-T12/T13). This analysis is **not counted** against the daily limit.
7. **`OCR_UNAVAILABLE`** (from `ocr-document`) — the online reading failed for a reason the
   device can work around. The app reads the page on the device instead and shows a warning
   that the result may be less accurate (F20-T22/T23). It is one of the four failures that
   fall back this way, with `AI_RATE_LIMITED`, `TIMEOUT` and a network failure; any other
   code does not. An app released before F20-T18 treats it as an unknown code (rule 3).

---

## §32 · Supporting endpoints

### `GET /functions/v1/get-usage`

**Auth header:** `Authorization: Bearer <supabase-anon-jwt>` (required).

Returns today's quota for the caller. The user is taken from the **verified
token**, never from a parameter — a caller cannot read another install's quota.

```jsonc
{
  "schema_version":  "2.0",
  "usage_date":      "2026-07-26",              // Africa/Cairo calendar day (§27)
  "daily_limit":     3,
  "used_today":      1,                          // analyses actually consumed
  "remaining_today": 2,                          // how many may be STARTED now
  "resets_at":       "2026-07-27T00:00:00+03:00",// real Cairo offset, not fixed +02
  "analysis_enabled": true,                      // the backend kill switch
  "online_ocr_enabled": false,                   // online reading live? (F20-T14)
  "explain_enabled":    false                    // explain-document live? (F36-T05)
}
```

| Field | Maps to `DailyUsage` |
|---|---|
| `usage_date` | `usageDate` |
| `daily_limit` | `dailyLimit` |
| `used_today` | `usedCount` |
| `remaining_today` | `remainingCount` |
| `resets_at` | `resetsAt` |
| `online_ocr_enabled` | `onlineOcrEnabled` (F20-T17; was `azure_ocr_enabled` / `azureOcrEnabled`). Absent reads as `false`, so an older app stays on the on-device route |
| `explain_enabled` | `explainEnabled` (F36-T05). The capture gate for F34's one-call flow: absent, unreadable or "off" all read as `false`, and the app then shows the "our problem" screen rather than claiming the phone is offline. **Additive** — the published 1.0.2 app reads named keys only and ignores it |

`remaining_today` also subtracts **in-flight reservations**, so for the few
seconds an analysis is running it can be lower than `daily_limit - used_today`.
That is deliberate: it is the honest answer to "can I start one now?".

Errors use the §31 envelope. Only `UNAUTHORIZED` (401) and `INTERNAL_ERROR`
(500) are reachable.

### `GET /functions/v1/health`

Unauthenticated liveness probe (`verify_jwt = false`).

```jsonc
{ "status": "ok", "time": "2026-07-26T09:00:00.000Z" }
```

It reads no table and returns no config value, count or secret — it answers only
"is the edge runtime serving?". Anything richer would make an unauthenticated
endpoint do database work, and would make the probe fail for reasons that are
not liveness.

### Shared behaviour

Every endpoint (`analyze-document`, `ocr-document`, `get-usage`, `report-error`,
`health`):

- accept `x-request-id` (a uuid) and **echo it** on every response, success or
  error. The same id keys `analysis_attempts`, so reusing one on a retry cannot
  consume a second slot.
- answer `204` to a CORS preflight, and `400 INVALID_REQUEST` to a method they
  do not serve (§31 is a closed enum with no method code).
- send `Cache-Control: no-store` — an analysis body describes someone's bill and
  must never sit in a proxy or a disk cache.

---

## §33 · `explain-document` — one call, photo in, cards out (v1.0)

**APPROVED by the owner 2026-11-09 (F36-T01).** Nothing implements it yet —
the endpoint is built across F36's Phases C–E. Four points were raised with the
draft and all four were decided: grounding by **omission** (§33.4) rather than
a confidence field; **`date.text` is drawn on the ميعاد card**, not voice-only,
which adds one line to that card in F40; `status: "unsupported"` shows the
ordinary result screen with one honest card and a **free** slot; and the length
caps hold at a ~75-second read (≤ 24-character title, 1–4 paragraphs of ≤ 220
characters, **≤ 850 characters for the whole page** — measured, not estimated:
see §33.3).

`POST /functions/v1/explain-document` replaces the two-call flow for the F34
non-reader pivot: the phone sends the photo **once**, the server reads it and
explains it, and the response is the cards the result screen draws and the voice
speaks. `ocr-document` and `analyze-document` are untouched and keep serving
published 1.0.x builds.

**Versioned on its own key.** The envelope field is `explain_schema_version`,
compared against `RuntimeConfig.explainSchemaVersion` (the
`explain_schema_version` row, `"1.0"`). It is deliberately **not**
`schema_version`: that row is exact-matched by every published build, so moving
it would stop them dead. The two version numbers move independently, forever.

**Gated twice.** `analysis_enabled` (the service-wide kill switch) and
`explain_enabled` (this endpoint's opt-in flag) must both be on. Either one off
answers `503 ANALYSIS_DISABLED`, which the app shows as the "our problem"
screen. `explain_enabled` is also reported by `get-usage` (§32) so the app can
say so before the user photographs anything.

### Request body

```jsonc
{
  "explain_schema_version": "1.0",
  "session_id":      "uuid-v4",   // a fresh id per attempt; echoed back
  "installation_id": "uuid-v4",   // hashed server-side, never stored raw
  "app_version":     "1.1.0",     // refused below RuntimeConfig.minimumAppVersion
  "image": {
    "data":      "<base64>",      // the capture as the user cropped it; never a thumbnail
    "mime_type": "image/jpeg"     // "image/jpeg" | "image/png"
  }
}
```

There is **no `input_type` discriminant**: this endpoint serves exactly one
shape. `additionalProperties: false`, so an `analyze-document` body (which always
carries `input_type`) is refused `400 INVALID_REQUEST`.

Decoded `image.data` above `RuntimeConfig.maxImageBytes` → `400 INVALID_REQUEST`.

### Success response (`200 OK`)

```jsonc
{
  // -- envelope ------------------------------------------------------
  "explain_schema_version": "1.0",
  "session_id": "uuid-v4",            // echoed from the request
  "status":     "success",            // "success" | "partial" | "unsupported"

  // -- the header ----------------------------------------------------
  "paper": {
    "title": "جواب من مدرسة النور"    // <= 24 characters -- see §33.1
  },

  // -- the cards, in the order the screen draws and the voice speaks --
  // Every card below `explain` may be null; a null card is not drawn and
  // not spoken. `explain` and `todo` are never null.

  "explain": [                        // 1-4 paragraphs, each <= 220 chars; page <= 850
    "دي ورقة من مدرسة النور لولي أمر الطالب أحمد محمود في الصف الرابع. المدرسة بتعزمك على اجتماع أولياء الأمور عشان يكلموك عن مستوى أحمد في نص السنة.",
    "الاجتماع هيبقى مع مدرّس الفصل، وهيوريك درجات أحمد في الامتحانات اللي فاتت."
  ],

  "todo": {
    "required": true,                 // false -> the paper asks nothing of the user
    "text": "روح الاجتماع بنفسك، وخد معاك بطاقتك الشخصية وكراسة الواجب بتاعة أحمد."
  },

  "date": {                           // null when the paper carries no date worth a card
    "date": "2026-11-20",             // ISO-8601 date, always present when `date` is not null
    "time": "10:00",                  // "HH:mm" or null when no time is printed
    "text": "اجتماع أولياء الأمور"     // the date's MEANING; drawn AND spoken -- §33.3
  },

  "caution": {                        // null unless the paper carries a real warning
    "text": "لو مش هتقدر تروح، لازم تبلّغ المدرسة قبل الميعاد."
  },

  "contact": {                        // null unless a phone number is printed on the paper
    "name":  "مدرسة النور",
    "phone": "0453312244"             // digits only, as printed; the app formats it
  },

  "place": {                          // null unless an address is printed on the paper
    "text": "مدرسة النور، شارع الجمهورية، دمنهور"
  }
}
```

### §33.1 · `paper.title` — the header line

- **≤ 24 characters**, Egyptian Arabic, no trailing punctuation.
- **Word count is free.** F34 said "two words"; the approved design's own header
  reads «جواب من مدرسة النور» — four words, 19 characters. The real constraint
  is the one line it has to fit: at 17 px Cairo 800 in a 390 px header beside a
  back arrow, a 46 px thumbnail and a help button, ~24 characters is the
  measured limit. مستنداتي's rows ellipsise at about the same width.
- It names the paper the way its owner would («فاتورة الكهربا», «عقد إيجار
  الشقة», «إيصال التأمينات»), not its category.

### §33.2 · There is no `paper_type`, no `confidence`, and no `basis`

All three were in F34's sketch. **The approved design renders none of them**, and
each was checked against the artboards rather than assumed:

- **`paper_type`** was to drive an icon. The Result header's circle is the
  **photo thumbnail**, not a type icon; the six card icons are fixed per card;
  and مستنداتي's row glyph is a generic sheet of paper whose accent colour
  follows the row's **section and playing state**, not the paper's kind. So no
  consumer exists. A model-chosen enum nothing reads can only be wrong.
- **`confidence`** and **`basis`** were rendered by the OLD result screen as
  «قراءة غير مؤكدة» / «راجع المعلومة». The new design has **no uncertainty
  affordance at all**, and the user cannot read a hedge in any case.

Instead, truth is enforced by **omission**: see §33.4. Anything the server
cannot ground in the page is left out, `status` becomes `"partial"`, and a fixed
voice line tells the user something on the paper was not clear. This keeps
CLAUDE.md §7's rule — never present an unconfirmed number as fact — with the
screen the design actually specifies.

### §33.3 · What each card is for, and who formats it

| Field | Card | Drawn as | Notes |
|---|---|---|---|
| `explain` | شرح الورقة | one paragraph per element | always present; never restates another card (§33.5) |
| `todo` | أعمل إيه؟ | **one** paragraph | always present. Money and required documents live *inside this text*, not in fields of their own |
| `date` | ميعاد | month, day, weekday, time, bell | the app formats `date`/`time` into «نوفمبر / 20 / يوم الخميس / الساعة 10 الصبح». `text` says **what the date is for**, and is both drawn and spoken. The approved artboard has no slot for it, so F40 adds one line to this card (owner's decision, 2026-11-09) |
| `caution` | خلي بالك | one paragraph | only a real warning. Not a reminder to keep the paper |
| `contact` | تكلم مين | name, number, call button | `phone` is digits only; the app groups them LTR for display |
| `place` | تروح فين | one line + "enlarge for the driver" | plain address text |

The model writes **no card titles** — the app owns every title and icon.
`todo.required: false` still produces text: it says what to do with the paper
when the paper asks nothing (e.g. «الورقة دي للعلم بس، احفظها عندك.»).

**The page total: ≤ 850 characters**, counting every string the voice reads —
`paper.title`, every `explain` paragraph, `todo.text`, `date.text`,
`caution.text`, `contact.name` and `place.text`. The per-card caps above still
hold individually; this is the ceiling on their sum, and the server trims or
re-asks rather than answering over it.

The number is measured, not guessed. F36-T02's Live spike read a
304-character page in ~26 s of 24 kHz 16-bit mono PCM — **11.3–12.1 characters
a second** — so 850 characters is the ~75-second read the design was approved
against, and the ~0.3 MB of stored audio F38 budgets per paper. The earlier
~1,100-character figure was an estimate made before that measurement and would
have read for ~95 s. Enforced server-side in F36-T11/T12; see
`docs/features/F36-live-spike.md` for the run.

### §33.4 · Grounding — omission, not hedging

A phone number, an amount or a date may appear **only if it literally appears in
the reading** of the page, after digit folding (Arabic-Indic digits → ASCII).
Checked with the same `number-validator` / `date-validator` / `text-matching`
the v2 pipeline uses.

- Ungrounded value → **removed**, not downgraded.
- Anything removed → `status: "partial"`.
- The reading itself is **never returned**. It exists only inside the request,
  to ground these values. There is no `ocr_text` field, by design, and nothing
  in the response may be derived verbatim from it beyond grounded values.

### §33.5 · No repetition

`explain` never restates `todo`, `date`, `caution`, `contact` or `place`. The
server checks and strips duplicate sentences before responding — the page is
read aloud top to bottom, and a repeated sentence is heard twice.

### §33.6 · `status`

| Value | Means | Quota |
|---|---|---|
| `success` | the paper was read and explained | **counts** |
| `partial` | explained, but something was omitted for want of grounding (§33.4) | **counts** |
| `unsupported` | the photo is not a paper this app can explain | **free** — the slot is released, exactly as §31 rule 6 does for `analyze-document` |

### §33.7 · Errors

The §31 envelope, unchanged. Both AI stages' failures collapse onto the closed
`ERROR_CODES` list:

| Stage / cause | Code | HTTP | The app |
|---|---|---|---|
| Either gate off | `ANALYSIS_DISABLED` | 503 | "our problem" screen |
| Bad body, oversized image | `INVALID_REQUEST` | 400 | "our problem" screen |
| `explain_schema_version` mismatch | `UNSUPPORTED_SCHEMA` | 400 | "our problem" screen (a build older than the server) |
| Below `minimum_app_version` | `UNSUPPORTED_APP_VERSION` | 400 | update prompt |
| Missing or invalid token | `UNAUTHORIZED` | 401 | silent re-auth, then retry |
| Caller's 5/day spent | `DAILY_LIMIT_REACHED` | 429 | "daily limit" screen + its voice line |
| Service-wide cap spent | `GLOBAL_CAPACITY_REACHED` | 429 | "our problem" screen |
| Every reading leg rate-limited | `AI_RATE_LIMITED` | 429 | "try later" voice line |
| Our budget ran out | `TIMEOUT` | 408 | "try later" voice line |
| Every reading leg failed otherwise | `ANALYSIS_FAILED` | 500 | "unreadable" screen + its voice line |
| Every explaining leg failed | `ANALYSIS_FAILED` | 500 | "our problem" screen |
| Our bug, or a missing credential | `INTERNAL_ERROR` | 500 | "our problem" screen |

**`OCR_UNAVAILABLE` is not reachable here.** That code exists to tell the app it
may read the page on the device instead; after F39 there is no on-device reader,
so emitting it would be an instruction the client cannot follow.

#### Per-`ProviderFailureKind` mapping (T17)

Both the reading stage and the explaining stage map every `ProviderFailureKind`
onto the same `ERROR_CODE`, through `analysisApiErrorFor`. The mapping is
identical to `analyze-document`'s and is pinned by
`explain-error-mapping.test.ts`.

| `ProviderFailureKind` | `ERROR_CODE` | HTTP | Failover | Why |
|---|---|---|---|---|
| `rate_limited` | `AI_RATE_LIMITED` | 429 | yes | the provider's bucket is spent; another may have room |
| `timeout` | `TIMEOUT` | 408 | yes | our budget ran out; if enough remains, try a faster provider |
| `upstream_unavailable` | `ANALYSIS_FAILED` | 500 | yes | the provider is down; the next one might not be |
| `network` | `ANALYSIS_FAILED` | 500 | yes | DNS/TLS/connection failure — transient |
| `invalid_output` | `ANALYSIS_FAILED` | 500 | yes | unusable answer; another model may do better |
| `auth` | `INTERNAL_ERROR` | 500 | **no** | bad key — our deploy fault, must be seen, not hidden |
| `bad_request` | `INTERNAL_ERROR` | 500 | **no** | bad model name or malformed request — our fault |

`auth` and `bad_request` never fail over because they are deploy faults: asking
a second provider the same broken question only hides the bug from the operator.
None of the seven kinds maps to `OCR_UNAVAILABLE`, which is the closed claim
trap #3 requires.

### §33.8 · Time budget

One request now does **two** AI calls where the v2 flow did one each. Measured
p95s (F20-T09): reading 5.5 s, explaining 12.7 s (slowest 14.7 s), Groq 2.5-3.1 s.

- `EXPLAIN_TIMEOUT_SECONDS` — the whole request's budget, env-sourced, **30 s**.
- Split into a **read stage (10 s)** and an **explain stage (20 s)**, each with
  its own deadline, per-attempt cap and "is there time for another leg?" rule.
- `aiTimeoutSeconds` (25 s) is untouched, so `ocr-document` and
  `analyze-document` keep the timing F20-T09 tuned them to.
- The slot's TTL is the budget plus the 10 s reservation grace.
- The client's own timeout must be **longer** than this, or the client stops
  being second to give up and abandons a request that still holds a slot.

A useful property of the deep chains: a rate limit returns **instantly**, so
when a Gemini daily bucket is exhausted — the case leg 2 and leg 3 exist for —
there is nearly the whole stage left for them. A slow primary, by contrast, eats
the budget and the stage answers with its failure rather than starting a leg it
cannot finish.

### §33.9 · Provider chains (server-side only; never named to the user)

| Stage | Legs |
|---|---|
| Reading | `gemini-3.5-flash-lite` → `gemini-3.1-flash-lite` → `gemini-3.5-flash` |
| Explaining | Mistral `ministral-14b` → Groq `gpt-oss-120b` → Gemma 4 26B (native `generateContent`, `responseJsonSchema`) |

Failover only on the closed allowlist in `provider-failure.ts` (rate limit,
upstream outage, network, timeout, unusable output). Never on `auth` or
`bad_request` — those are deploy faults and must be seen, not papered over.

All three reading legs are Gemini model ids over the same client and the same
key, each with its own free-tier bucket (**15 RPM, 1 M TPM, 1,500 RPD** for the
two Flash-Lite legs, measured 2026-11-09). Mistral OCR was the planned third
leg and is **out**: its free plan answers `/v1/ocr` with 429 at the first call,
while chat on the same key answers 200, and the project takes no paid tier.
Groq has no vision model to put there instead.

The third leg therefore buys **burst headroom, not daily headroom**: 45 reads a
minute instead of 30. It cannot help with a provider-wide outage, because all
three legs share one account — but our own traffic cannot exhaust 3,000 reads a
day behind a 900-call cap, so a daily ceiling was never the risk. It also means
one model id being retired (as both 2.5 ids were) costs one leg, not the chain.

### §33.10 · Worked examples

One per paper kind in the golden set. Only the fields that differ from the
school-letter example above are shown; `explain_schema_version`, `session_id`
and `status` are omitted for brevity.

**Electricity bill** — money lives inside `todo`, not in a field of its own.

```jsonc
{
  "paper":   { "title": "فاتورة الكهربا" },
  "explain": ["دي فاتورة كهربا من شركة شمال القاهرة، عن شهر أكتوبر. القراءة الجديدة ٤٢٠ وحدة، والمبلغ اللي عليك ٢٨٥ جنيه."],
  "todo":    { "required": true, "text": "ادفع ٢٨٥ جنيه قبل ٢٥ نوفمبر. تقدر تدفع من ماكينة الدفع أو من محفظة الموبايل." },
  "date":    { "date": "2026-11-25", "time": null, "text": "آخر ميعاد للدفع" },
  "caution": { "text": "لو اتأخرت عن الميعاد، بيتضاف رسم تأخير على الفاتورة اللي بعدها." },
  "contact": { "name": "شركة شمال القاهرة", "phone": "121" },
  "place":   null
}
```

**Bank letter** — nothing is required of the user, so `todo.required` is `false`.

```jsonc
{
  "paper":   { "title": "جواب من البنك" },
  "explain": ["دي ورقة من البنك الأهلي بتقولك إن حسابك اتغير رقمه بعد ما البنك طوّر نظامه. الرقم الجديد مكتوب في الورقة."],
  "todo":    { "required": false, "text": "مش مطلوب منك حاجة. احفظ الورقة دي عندك، وخد الرقم الجديد معاك أول مرة تروح البنك." },
  "date":    null,
  "caution": null,
  "contact": { "name": "البنك الأهلي", "phone": "19623" },
  "place":   null
}
```

**Government form** — the required documents live inside `todo`.

```jsonc
{
  "paper":   { "title": "استمارة الأحوال المدنية" },
  "explain": ["دي استمارة من الأحوال المدنية لاستخراج بطاقة رقم قومي بدل تالفة."],
  "todo":    { "required": true, "text": "املا الاستمارة وروح بيها السجل المدني. خد معاك البطاقة القديمة، وصورة شخصية حديثة، و٧٠ جنيه رسوم." },
  "date":    null,
  "caution": { "text": "الاستمارة لازم تتسلّم في خلال ٣٠ يوم من تاريخ ختمها." },
  "contact": null,
  "place":   { "text": "السجل المدني، شارع الجيش، طنطا" }
}
```

**Appointment card**

```jsonc
{
  "paper":   { "title": "ميعاد عند الدكتور" },
  "explain": ["دي كارتة ميعاد من عيادة الدكتور محمد سالم، أخصائي العظام."],
  "todo":    { "required": true, "text": "روح العيادة في الميعاد، وخد معاك الأشعة اللي عملتها قبل كده." },
  "date":    { "date": "2026-11-14", "time": "18:30", "text": "ميعاد الكشف" },
  "caution": null,
  "contact": { "name": "عيادة الدكتور محمد سالم", "phone": "01012345678" },
  "place":   { "text": "٢٢ شارع النصر، المنصورة، الدور التالت" }
}
```

**Rent contract** — a long paper, explained in four paragraphs.

```jsonc
{
  "paper":   { "title": "عقد إيجار الشقة" },
  "explain": [
    "ده عقد إيجار شقة بينك وبين المالك أحمد كامل. العقد مدته سنة، بيبدأ أول ديسمبر ٢٠٢٦.",
    "الإيجار ٣٥٠٠ جنيه في الشهر، بيتدفع في أول كل شهر.",
    "العقد بيقول إن الصيانة الصغيرة عليك، والكبيرة على المالك.",
    "فيه تأمين ٧٠٠٠ جنيه بترجعلك آخر العقد لو الشقة مفيهاش تلفيات."
  ],
  "todo":    { "required": true, "text": "امضي على العقد ومعاك صورة بطاقتك، وادفع الإيجار أول كل شهر. خلي نسخة من العقد عندك." },
  "date":    { "date": "2026-12-01", "time": null, "text": "بداية العقد" },
  "caution": { "text": "لو عايز تسيب الشقة قبل آخر السنة، لازم تبلّغ المالك قبلها بشهرين، وإلا بتخسر التأمين." },
  "contact": { "name": "أحمد كامل", "phone": "01122334455" },
  "place":   null
}
```

**Prescription — interim behaviour.** No drug names, no doses, no diagnosis.
The app does not interpret medicine; it tells the user who can.

```jsonc
{
  "paper":   { "title": "روشتة من الدكتور" },
  "explain": ["دي روشتة من الدكتور سامي فؤاد، بتاريخ ٣ نوفمبر، وفيها ٤ أدوية."],
  "todo":    { "required": true, "text": "خد الروشتة للصيدلي، وخليه هو اللي يقرالك الأدوية ومواعيدها. متاخدش أي دوا من نفسك." },
  "date":    null,
  "caution": null,
  "contact": null,
  "place":   null
}
```

**Lab result — interim behaviour.** Numbers are never interpreted.

```jsonc
{
  "paper":   { "title": "نتيجة تحاليل" },
  "explain": ["دي نتيجة تحاليل من معمل البرج، بتاريخ ٥ نوفمبر."],
  "todo":    { "required": true, "text": "وري النتيجة دي لدكتورك، هو اللي يعرف يشرحها لك. الأرقام اللي فيها محتاجة دكتور يقراها." },
  "date":    null,
  "caution": null,
  "contact": { "name": "معمل البرج", "phone": "19911" },
  "place":   null
}
```

**Not a paper** — `status: "unsupported"`, and the slot is released.

```jsonc
{
  "status":  "unsupported",
  "paper":   { "title": "صورة مش ورقة" },
  "explain": ["الصورة دي مفيهاش ورقة فيها كلام أقدر أشرحه. صوّر الورقة نفسها وهي كلها جوه الصورة."],
  "todo":    { "required": false, "text": "صوّر الورقة تاني في نور أوضح." },
  "date":    null,
  "caution": null,
  "contact": null,
  "place":   null
}
```
