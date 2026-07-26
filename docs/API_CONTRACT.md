# API Contract — War2aty Analysis Service

Defines the JSON contract between the Flutter app and the Supabase Edge Function
(`analyze-document`). The app sends **text only** — the image never leaves the
device (privacy §7).

---

## §29 · Analysis Request — JSON Schema v1

### Endpoint

`POST /functions/v1/analyze-document`

**Auth header:** `Authorization: Bearer <supabase-anon-jwt>`

### Request body

```jsonc
{
  // ── envelope ──────────────────────────────────────────────────────
  "schema_version": "1.0",            // locked; reject if mismatch
  "session_id":     "uuid-v4",        // AnalysisSession.id
  "installation_id":"uuid-v4",        // per-install identity
  "app_version":    "1.0.0",          // semantic version of the app

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
  "$id": "https://war2aty.app/schemas/analyze-request-v1.json",
  "title": "AnalyzeDocumentRequest",
  "description": "Request payload for the analyze-document Edge Function (v1).",
  "type": "object",
  "required": [
    "schema_version",
    "session_id",
    "installation_id",
    "app_version",
    "ocr_text",
    "detected_languages",
    "candidates"
  ],
  "additionalProperties": false,
  "properties": {
    "schema_version": {
      "type": "string",
      "const": "1.0",
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
| `schema_version` | `RuntimeConfig.schemaVersion` (currently `"1.0"`) |
| `session_id` | `AnalysisSession.id` |
| `installation_id` | `InstallationIdProvider.getOrCreate()` |
| `app_version` | `PackageInfo.version` (package_info_plus) |
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

1. **Schema version** — reject `schema_version != "1.0"` with `400 UNSUPPORTED_SCHEMA`.
2. **App version** — reject if below `RuntimeConfig.minimumAppVersion` with `400 UNSUPPORTED_APP_VERSION`.
3. **OCR text** — reject if empty or exceeds `maxOcrCharacters` (12 000) with `400 INVALID_REQUEST`.
4. **Daily limit** — check `installation_id` usage count for the current `Africa/Cairo` day. Reject with `429 DAILY_LIMIT_REACHED` and include `reset_at` (Cairo midnight ISO-8601).
5. **Analysis disabled** — if `RuntimeConfig.analysisEnabled == false`, reject with `503 ANALYSIS_DISABLED`.
6. **Candidate arrays** — may be empty (document with no extractable fields is valid).

### Privacy guarantees

- **No image data.** The request contains text only — no bytes, thumbnails, EXIF, or GPS.
- **No logging of content.** The Edge Function MUST NOT log `ocr_text`, candidate values, or any derived analysis content. Only envelope fields (`session_id`, `installation_id`, `schema_version`) and status codes may be logged.
- **Candidates are hints.** The AI uses them as structured hints alongside the raw text. They do not replace the AI's own reading of `ocr_text`.

---

## §30 · Analysis Response — JSON Schema v1

### Success response (`200 OK`)

```jsonc
{
  // ── envelope ──────────────────────────────────────────────────────
  "schema_version": "1.0",
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
      "confidence":         "high"
    }
  ],

  // ── amounts ───────────────────────────────────────────────────────
  "amounts": [
    {
      "label":      "إجمالي المبلغ",
      "value":      850.50,
      "currency":   "EGP",
      "confidence": "high"
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
  "$id": "https://war2aty.app/schemas/analyze-response-v1.json",
  "title": "AnalyzeDocumentResponse",
  "description": "Success response from the analyze-document Edge Function (v1).",
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
      "const": "1.0"
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
      "required": ["label", "date", "role", "is_reminder_worthy", "confidence"],
      "additionalProperties": false,
      "properties": {
        "label":              { "type": "string", "minLength": 1 },
        "date":               { "type": "string", "format": "date" },
        "time":               { "type": ["string", "null"], "pattern": "^([01]\\d|2[0-3]):[0-5]\\d$" },
        "role":               { "type": "string", "enum": ["deadline", "appointment", "issued", "expiry", "event", "period_start", "period_end"] },
        "is_reminder_worthy": { "type": "boolean" },
        "confidence":         { "$ref": "#/definitions/confidence" }
      }
    },
    "amount_item": {
      "type": "object",
      "required": ["label", "value", "currency", "confidence"],
      "additionalProperties": false,
      "properties": {
        "label":      { "type": "string", "minLength": 1 },
        "value":      { "type": "number" },
        "currency":   { "type": "string", "minLength": 1 },
        "confidence": { "$ref": "#/definitions/confidence" }
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
| 500 | `ANALYSIS_FAILED` | `AnalysisServiceFailure` | — | AI returned unusable output or internal error |
| 500 | `INTERNAL_ERROR` | `AnalysisServiceFailure` | — | Unexpected server error |
| 503 | `ANALYSIS_DISABLED` | `AnalysisDisabledFailure` | — | `analysisEnabled == false` (maintenance) |

### Error JSON Schema (draft-07)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://war2aty.app/schemas/analyze-error-v1.json",
  "title": "AnalyzeDocumentError",
  "description": "Error response from the analyze-document Edge Function.",
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
            "ANALYSIS_FAILED",
            "INTERNAL_ERROR",
            "ANALYSIS_DISABLED"
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
   to show the user when they can retry.
3. **Unknown codes** — treat any unrecognized `error.code` as `AnalysisServiceFailure`.
4. **Non-JSON responses** — treat as `AnalysisServiceFailure` (server returned HTML error page, etc.).
5. **Network errors** (no response) — map to `NoInternetFailure` or `RequestTimeoutFailure`
   based on the exception type.
6. **`status: "unsupported"`** in a 200 response — this is NOT an error. Map to
   `UnsupportedDocumentFailure` in the domain layer; the result screen shows the
   OCR-only fallback (F07-T12/T13). This analysis is **not counted** against the daily limit.
