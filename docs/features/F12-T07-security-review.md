# F12-T07 — Security review (no secrets; no doc content in logs; encryption verified)

Full-app sweep against the three acceptance criteria, plus whatever else
turned up while tracing them. Method: read every logging call site on both
sides (`AppLogger`/`LogSink` and Flutter's `ApiLogInterceptor` on the client,
`logEvent`/`log.ts` on the Edge Functions) end to end against what CLAUDE.md
§7/§51 and API_CONTRACT.md §29/§29b allow; grepped the whole tree for
secret/key/token/credential patterns and high-entropy strings and checked
every hit against `.gitignore` and git history; re-read the encryption
pipeline (`AesGcmFileEncryptor`, `DocumentEncryptionKeyStore`,
`FlutterSecureStorageService`) and its existing test coverage; and traced
every path an image or an installation identifier travels from capture to
wire to confirm the "no thumbnail, no EXIF, no GPS" promise actually holds
for the bytes, not just for the JSON schema's field list.

## Fixed

**The backend's `analyze.completed` log line included `document_type`, the
AI's classification of the paper.** ([analyze-handler.ts](../../supabase/functions/_shared/analyze/analyze-handler.ts))
API_CONTRACT §29's privacy guarantee is explicit — "Only envelope fields
(`session_id`, `installation_id`, `schema_version`, `input_type`) and status
codes may be logged" — and `document_type.type` is derived analysis content,
not envelope: it is the model's own reading of the page, drawn from an enum
that includes `medical`, `legal` and `financial`. It is also joinable back to
a person: the same log line's `request_id` keys `analysis_attempts`, whose
`installation_hash` exists specifically so nobody can tell which install did
what — logging the document category next to the id that traces back to it
hands part of that back. Every other call site of `logEvent` was checked
against the same rule and found clean (envelope fields, counts, and closed
enums only — see `analyze.validated`, `ocr.completed`, `usage.read`, the
generic `request` line, and the Flutter side's `ApiLogInterceptor`, whose own
doc comment already explains why it replaces Dio's default `LogInterceptor`
rather than configuring it).

Fix: removed the field. New regression test in
[analyze-handler.test.ts](../../supabase/tests/unit/analyze-handler.test.ts) —
`console.log` captured for a full request, then asserted that none of
`document_type.type`, `document_type.title`, a key-information value, an
amount, a date, a label, or the raw OCR text ever appears in any emitted
line, plus a companion test asserting the completion line's remaining
envelope fields (`request_id`, `session_id`, `status`, `counted`) are still
present and `document_type` is explicitly `undefined` — so a well-meaning
re-add fails loudly instead of silently regressing.

**The online image pipeline could upload a photo's original EXIF metadata —
camera make/model, timestamp and, when the photo came from the gallery,
GPS coordinates — despite CLAUDE.md's explicit promise that the online route
sends "الصورة نفسها فقط (بدون Thumbnail/EXIF/GPS)".** Traced every write and
read of the file that becomes `AnalysisImageRequest.photo`
([default_analysis_repository.dart](../../lib/features/analysis/data/repositories/default_analysis_repository.dart)):

- A direct camera capture ([platform_camera_service.dart](../../lib/features/capture/data/services/platform_camera_service.dart))
  writes a JPEG straight from the `camera` plugin — carrying whatever EXIF
  the hardware/OS embedded.
- A gallery pick ([system_image_picker_service.dart](../../lib/features/capture/data/services/system_image_picker_service.dart))
  can carry another camera app's own EXIF, GPS included — very common for
  ordinary phone photos.
- Rotation ([image_package_rotator.dart](../../lib/features/capture/data/services/image_package_rotator.dart))
  does not strip it: `package:image`'s JPEG decoder parses the EXIF block
  into `Image.exif`, and its encoder writes `Image.exif` straight back out
  on re-encode — confirmed by reading `jpeg_data.dart`'s `_readExifData` and
  `jpeg_encoder.dart`'s `_writeExif` in the vendored package. Rotation
  round-trips EXIF, it does not clear it.
- Perspective correction (`doclens`) only runs when a page is detected; an
  undetected quad (`quad == null`) returns the original photo completely
  unmodified — no rotation, no correction, no re-encode of any kind.

So an online-route photo that was neither rotated nor had a detectable page
reached `_buildImageRequest` — already documented there as "the one place in
the app that turns image bytes into something that leaves the device" — and
was read and base64-encoded as-is. `AnalysisImageRequestDto` having no
`thumbnail`/`exif`/`gps` *field* (the guarantee API_CONTRACT §29b's own
privacy note describes) says nothing about what is embedded inside the
`image.data` bytes themselves — a real gap, not a hypothetical one, since a
gallery-picked photo carrying GPS EXIF is an ordinary case, not an edge one.
No location permission is requested anywhere in the app (grepped both
manifests), which closes the *camera-capture* GPS vector specifically, but
does nothing for a gallery photo taken by a different app that did have
permission.

Fix: `_buildImageRequest` now strips EXIF before encoding, via a new
`_stripExif` helper reusing `package:image` (already a dependency — no new
package added). It decodes, clears `Image.exif` when non-empty, and
re-encodes (JPEG at quality 92, matching `ImagePackageRotator`'s own
constant; PNG losslessly) — skipping the recompression entirely when there
is nothing to strip, so doclens's already-EXIF-free warped output pays no
quality cost. Runs inside `Isolate.run`, same reasoning as
`ImagePackageRotator` and `AesGcmFileEncryptor`: decode/encode is CPU-heavy
on a full-resolution photo and must stay off the UI thread (F12-T05).

While building this, found that `img.decodeImage` is not a clean
"returns null for anything it cannot read": probing a tiny malformed byte
sequence against every registered format can throw before a decoder is even
chosen (reproduced — a 3-byte input drives the PSD sniffer's header read past
the end of its buffer with a raw `RangeError`, verified in isolation before
writing the surrounding `try`). Left unguarded, that would have turned a
privacy hardening pass into a *new* `ImageProcessingFailure` for uploads the
pre-F12-T07 code accepted without complaint — `_buildImageRequest`'s
existing `on Object` turns any exception into exactly that failure. Guarded
with its own `try`/`on Object` that falls back to the original bytes, which
is the correct outcome either way: there was nothing to strip.

New tests in
[default_analysis_repository_test.dart](../../test/features/analysis/data/repositories/default_analysis_repository_test.dart)
(`analyzeImage — EXIF stripping (F12-T07)`): a real JPEG built with
`package:image` carrying `Make`/`Model`/GPS tags comes out with `exif.isEmpty`
true on both `analyzeImage` and `ocrImage`; the underlying pixel content
still decodes as the same strongly-red image (not a corrupted or blanked
stand-in); the non-image `[1, 2, 3]` fixture every pre-existing test in this
file already relies on still passes through byte-for-byte unchanged (guards
the `RangeError` regression above); and a PNG source is re-encoded as PNG,
not silently upgraded to JPEG.

**Android's Auto Backup (and, on API 31+, device-to-device transfer) had no
opt-out**, so it would have copied `war2aty.sqlite` — every saved paper's
analysis in plain text: the summary, key information, amounts, dates — to
the user's Google Drive, directly contradicting the saved-papers screen's own
promise: «بنحفظ الملخص والتفاصيل وصورة الورقة مشفّرة على جهازك.» — on *your*
device. It would also have restored `flutter_secure_storage`'s wrapped key
material (including the AES-256 key that protects every saved photo) without
the Android Keystore key that unwraps it — that package's own README
documents this exact scenario as an `InvalidKeyException: Failed to unwrap
key` crash, not a graceful degrade. `AndroidManifest.xml` had no
`android:allowBackup` at all, which defaults to `true`.

Fix: `android:allowBackup="false"` plus a new
[data_extraction_rules.xml](../../android/app/src/main/res/xml/data_extraction_rules.xml)
(`android:dataExtractionRules`) excluding every domain from both
`<cloud-backup>` and `<device-transfer>` — `allowBackup` alone only covers
Auto Backup; API 31+'s device-to-device transfer is a separate switch this
file is what covers. Verified by building the dev-flavor debug APK twice
(before writing the manifest edit, and again after fixing an unrelated
line-ending issue in the diff) — both builds succeed, confirming the
`@xml/data_extraction_rules` reference resolves.

Consequence, stated plainly, same as F12-T06's own pattern for a tradeoff
like this: a saved paper does not survive a phone replaced via Google's
backup/restore or its device-to-device transfer flow. It already effectively
did not — the encrypted picture was unreadable and secure storage broke on
restore — so this makes that existing behaviour honest and, in the same
change, stops the *unencrypted analysis text* from leaking into a Drive
backup in the meantime.

## Checked, no change needed

- **Every other backend log call site** (`analyze.validated`,
  `ocr.completed`, `usage.read`, the endpoint's generic `request` line) —
  read against §51's allowlist field by field; every value is a count, a
  status, a closed enum, or an id. `log.ts`'s own `MAX_VALUE_LENGTH`
  truncation backstop confirmed present and unrelated to this task (it
  guards length, not content).
- **The Flutter-side logger** (`AppLogger`/`LogEvent`/`LogSink`) — structurally
  cannot log free text: `LogEvent`'s fields ARE the §51 allowlist (no
  message/map field exists at all), and `StructuredAppLogger.event` asserts
  every emitted key is in `kAllowedLogFields` even in release builds
  (belt-and-suspenders on top of the type system). `avoid_print` is a
  build-breaking `error` in `analysis_options.yaml`, and a grep for
  `print(`/`debugPrint(`/`developer.log(` outside `log_sink.dart` found
  nothing.
- **`ApiLogInterceptor`** — deliberately replaces Dio's own `LogInterceptor`
  rather than configuring it, because that ships request/response *bodies*
  by default; its own doc comment already explains this. Confirmed it emits
  only `requestId`/`httpStatus`/`durationMs` and reads no header, body, URL
  or query string.
- **Secrets** — grepped the whole tree for API-key/secret/token/credential
  patterns and high-entropy strings (Groq/Azure/AWS-style prefixes, PEM
  headers). Every real secret (`GROQ_API_KEY`, `AZURE_DOCUMENT_INTELLIGENCE_KEY`,
  `GOOGLE_DOCUMENT_AI_PRIVATE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`,
  `INSTALLATION_HASH_SALT`) lives only in `Deno.env.get(...)` calls and
  `supabase/.env.example`'s blank template. `supabase/.env` itself (the real,
  filled-in file) exists locally, is git-ignored (`git check-ignore -v`
  confirmed), and `git status` shows it untracked — it was never staged or
  committed. Walked git history for the same patterns; the only hits are a
  doc comment's `<key>`/`<service_role key>` placeholders, not real values.
  The one key genuinely shipped in the client — `AppEnvironment
  .localStackAnonKey` — is the fixed, publicly-documented anon key every
  local Supabase stack prints, useless off this machine, and RLS-fenced from
  the usage tables regardless (§26). No `.pem`/`.p12`/`.jks`/`key.properties`
  tracked; Android release signing still falls back to the debug key with an
  explicit `// TODO: Add your own signing config` — a known, pre-existing gap
  that belongs to F12-T11 (Android release build), not this task.
- **Encryption** — re-read `AesGcmFileEncryptor` (AES-256-GCM via
  `package:cryptography`, random nonce per call via `SecretBox.concatenation`,
  runs off the UI thread via `Isolate.run` per F12-T05) and
  `DocumentEncryptionKeyStore` (256-bit key generated once, held in
  `flutter_secure_storage` — Android Keystore / iOS Keychain — never derived
  from anything document-related). Existing test suites already cover the
  properties that matter: round-trips its own output, produces a different
  nonce (and so different ciphertext) for identical plaintext on every call,
  rejects a tampered GCM tag, rejects a tampered ciphertext body, rejects
  data too short to be real, and fails closed under the wrong key
  (`aes_gcm_file_encryptor_test.dart`); the key store persists across
  instances, is stored as base64 not raw bytes, and is reused rather than
  regenerated (`document_encryption_key_store_test.dart`). No gap found;
  no change made.
- **`FileDocumentImageStore`** — the only writer of `.enc` files, deletes the
  plaintext source on success (`_deleteQuietly`, pre-existing, unchanged
  here) — re-confirmed as part of tracing where encrypted bytes come from.
- **Auth / backend access control** — `require-user.ts` gates every protected
  endpoint before any parsing, quota check or provider call; the token is
  never logged, returned, or attached to an error (its own doc comment
  states this and the code matches). `config.toml` sets `verify_jwt = true`
  on `analyze-document`/`ocr-document`/`get-usage` and `false` only on the
  content-free `health` probe. Every table (`analysis_usage_daily`,
  `analysis_attempts`, `app_runtime_config`, `global_analysis_usage_daily`)
  has RLS on with the grant explicitly revoked from `anon`/`authenticated`
  and re-granted only to `service_role`; every RPC
  (`reserve_analysis_slot`/`finalize_analysis_slot`/`expire_stale_reservations`)
  has `EXECUTE` explicitly revoked from `PUBLIC` before being re-granted to
  `service_role` — closing off the default PostgREST RPC exposure. The one
  `SECURITY DEFINER` function found (`analysis_usage_daily`'s trigger) pins
  `search_path = ''`, the standard defence against a search-path hijack.
- **`analysis_attempts`/`analysis_usage_daily`** — both tables' own
  top-of-file comments assert "no document content", and the column lists
  confirm it: envelope fields only (ids, statuses, timestamps, counts). No
  OCR text, candidate value, or analysis output has a column anywhere.
  `installation_hash` is a salted SHA-256 (`installation-hash.ts`) with a
  `MIN_SALT_LENGTH` startup check — the raw `installation_id` is never
  stored, and the salt itself lives only in `Deno.env`/Supabase Secrets.
- **The system prompt's injection defence** — `system-prompt.ts` rule 15 and
  its dedicated "SAFETY OF THE DOCUMENT TEXT" section instruct the model to
  treat the photographed page as data, never instructions, and to ignore any
  "disregard these rules" text the paper itself might contain. Not this
  task's to test end-to-end (that is a prompt-behaviour question, not a code
  defect), but the defence exists and is documented.
- **Reminder notifications on a locked screen** — a reminder for a medical or
  legal document showing its real title/body on the lock screen would be a
  legitimate leak of document content to anyone glancing at the phone.
  Already handled by F09-T14's `hideSensitiveDetails` setting, confirmed
  default-on (`reminder_notification_content.dart`'s own doc comment: "the
  setting's own current value ... default on") — hidden shows only generic
  copy, never the reminder's real title or note. No change needed.
- **Network transport** — `network_security_config.xml` permits cleartext
  only to `10.0.2.2`/`localhost`/`127.0.0.1` (the dev flavor's local-stack
  hosts), never as a blanket `usesCleartextTraffic`; iOS's
  `NSAllowsLocalNetworking` is the equivalent narrow carve-out. A release
  build stays HTTPS-only with no separate manifest to maintain. `prod`
  flavor (`main_prod.dart`/`AppEnvironment.prod`) never falls back to
  `localStackUrl` and fails safe (reports itself unconfigured) if the
  dart-defines are omitted, rather than shipping a placeholder.
- **CORS** (`cors.ts`) — `Access-Control-Allow-Origin: *` is safe here
  specifically because auth is a Bearer token, never a cookie; a browser
  cannot silently attach one cross-origin, so this does not by itself expose
  anything a JWT-holding caller could not already reach directly. Confirmed
  the reasoning in the file's own header comment holds.

## Out of scope (deferred)

- **A real-device pass** confirming Android's Auto Backup/transfer opt-out
  and the EXIF strip both behave as expected on real hardware — same
  constraint every F12 task before this one has flagged for its own
  code-level findings; belongs to the Exit DoD's real-device pass.
- **iOS backup exposure** (iCloud/Finder/iTunes local backup) — this task's
  fix is Android-specific (`allowBackup`/`dataExtractionRules` are Android
  manifest concepts). iOS's own opt-out is `NSURLIsExcludedFromBackupKey` on
  individual files, which touches the Drift database's storage path and the
  document-image directory rather than a single manifest flag — a
  meaningfully different fix, not a copy-paste of this one, and out of this
  pass's diff for the same change-discipline reason F12-T06 gave for not
  fixing its own flagged-but-different-owner finding.
- **Android release signing** — still falls back to the debug key
  (`build.gradle.kts`'s own `TODO`). Pre-existing, explicitly named as
  F12-T11's job, not re-litigated here.
- **Prompt-injection behavioural testing** — verifying the system prompt's
  "ignore instructions embedded in the document" rule actually holds against
  an adversarial photographed page is a model-behaviour question, not a
  static code review; would belong to F12-T08's OCR regression dataset or a
  dedicated red-team pass, not this task.
