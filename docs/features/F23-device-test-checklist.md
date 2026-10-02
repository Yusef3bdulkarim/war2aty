# F23 · Device Test Checklist (T14)

The owner tests on the phone; Claude prepares the backend and the app, and
switches each failure on and off between scenarios. Every scenario says who
does what, how the failure is triggered, and what must be seen. Mark each row
✅ or ❌ in **Results** at the end, with a note for anything off.

- **Device:** Android, serial `QCKFXSDAGMCIPB55`, over USB (`adb reverse`).
- **Build:** `--flavor dev -t lib/main_dev.dart`, real local backend (no mock),
  branch `feature/failure-screens-redesign`.
- **Design reference:** the F23 canvas, https://claude.ai/artifact/Y7R12wRrBSSDKCBTBbtjm6
  (Option B, and the four «— redesign» frames).

## 0 · Setup (Claude)

| Step | What | State |
|---|---|---|
| 0.1 | Docker + `supabase start` (core services up) | |
| 0.2 | `supabase functions serve --env-file supabase/.env` | |
| 0.3 | `adb reverse tcp:54321 tcp:54321` | |
| 0.4 | Local DB: `daily_limit = 3` (the production value), `analysis_enabled = true`, `online_ocr_enabled = true` | |
| 0.5 | `flutter run -d QCKFXSDAGMCIPB55 --flavor dev -t lib/main_dev.dart --dart-define=SUPABASE_URL=http://127.0.0.1:54321` | |
| 0.6 | Owner: Settings → «السماح بإرسال النص للتحليل» **on**, language **العربية**, text size normal, «تباين عالي» **off** | |

**On every failure page, always check:** the slim teal bar at the top with the
back arrow on the right (pointing right), white status-bar icons on it, **no**
big icon box above the title, title and message centred, the page scrolls if
needed, and the buttons stay pinned at the bottom.

## A · Unsupported paper (Option B)

**Trigger (owner):** photograph or pick any paper. On the review screen
(«الكلام اللي لقيناه»), delete all the text and type gibberish, e.g.
`ءءء ببب تتت ثثث ججج ححح خخخ`, then continue. If the analysis still explains
it, try a photo of something that is not a paper (a product box, a blurry
shot) and note it.

| ID | Do | Expect |
|---|---|---|
| A1 | Land on the page | Title «مقدرناش نشرح الورقة دي»; the message about unclear text or an unexplained kind; a **green pill with a check** «المحاولة دي متحسبتش من تحليلاتك النهارده» |
| A2 | Look at the content | A white card «عرض النص المستخرج» / «الكلام اللي قريناه من الورقة، وتقدر تنسخه» with a chevron pointing **left**; below it «الأوراق اللي بنشرحها»: four tiles in two rows (فواتير وإيصالات، مواعيد / أوراق حكومية، أوراق تعليمية) and one wide tile «أوراق تانية», each with its examples and its own coloured icon |
| A3 | Look at the buttons | «صوّر ورقة تانية» (filled, camera icon) and «اختار من الصور» (light teal, gallery icon) **side by side**, camera on the right; «العودة للرئيسية» below in readable grey; **no** «حاول تاني» |
| A4 | Tap the text card | «النص المستخرج» page: the note that there is no explanation, the gibberish text, **one** full-width «نسخ» button, no listen button |
| A5 | Tap «نسخ» | SnackBar «تم النسخ»; paste in any app — the text matches |
| A6 | Back arrow on the text page | Returns to the unsupported page (not home) |
| A7 | Tap «صوّر ورقة تانية» | Home, then the camera opens directly |
| A8 | Repeat A, tap «اختار من الصور» | Home, then the gallery picker opens directly |
| A9 | Repeat A, tap «العودة للرئيسية» | Home; the remaining analyses on Home did **not** go down |
| A10 | Repeat A, use the system back gesture, then the bar's back arrow | Both go home |

## B · No internet

**Trigger (Claude):** the owner reaches the review screen and says "ready";
Claude removes the USB tunnel (`adb reverse --remove tcp:54321`); the owner
taps continue. (Airplane mode is not enough here: the backend is reached over
USB, which airplane mode does not cut.)

| ID | Do | Expect |
|---|---|---|
| B1 | Land on the page | Title «النت فاصل دلوقتي»; message «علشان نشرح الورقة محتاجين إنترنت. الكلام اللي فيها اتقرا خلاص، فمش هتحتاج تصوّرها تاني.» — **no** «على موبايلك», **no** green pill |
| B2 | Look at the tracker | Three steps right to left: «الصورة ✓ تمام» (green), «قراية الكلام ✓ تمام» (green), «الشرح» with a **clock** on amber, «مستني النت»; a green line between the first two, a grey one before the last |
| B3 | Look at the tips | «جرّب الحاجات دي»: Wi-Fi, airplane mode, weak signal — each with its own icon |
| B4 | Look at the buttons | «حاول تاني» (filled), «عرض النص المستخرج» (light teal), «العودة للرئيسية» (grey); no camera/gallery |
| B5 | Tap «عرض النص المستخرج», then back | The text page, then back to this page |
| B6 | Tap «حاول تاني» while still offline | The wait screen, then this page again |
| B7 | Claude restores the tunnel; tap «حاول تاني» | The wait screen, then the explanation — **without** taking a new photo |

## C · Daily limit

**Trigger (Claude):** sets today's used count to 3 in the local DB (limit 3).
The owner then photographs a real paper and continues from review.

| ID | Do | Expect |
|---|---|---|
| C1 | Land on the page | Title «خلّصت تحليلات النهارده»; message «عندك 3 تحليلات ذكية كل يوم، واستخدمتهم كلهم. الكلام اللي في الورقة لسه متاح تقراه دلوقتي.» — nothing about listening |
| C2 | Look at the countdown | Light teal card: «تحليلاتك بتتجدد بعد», the time left in large text (e.g. «5 ساعات و 12 دقيقة»), «الساعة 12 بالليل بتوقيت مصر»; the time matches what is left until midnight Cairo time |
| C3 | Look at the pill | White pill: three teal dots and «استخدمت 3 من 3 النهارده» |
| C4 | Keep the page open across a minute (watch the phone's clock) | The minutes go down by one **as the minute turns**, not up to a minute late |
| C5 | Look at the tips | «تقدر تعمل إيه دلوقتي؟»: read and copy (teal icon), keep the paper and photograph it tomorrow (amber light bulb) |
| C6 | Look at the buttons | «عرض النص المستخرج» (filled) and «العودة للرئيسية» (grey) only — **no** «حاول تاني», home not shown twice |
| C7 | Tap «عرض النص المستخرج», copy, back | Works as in A4–A6 |

Covered by automated tests instead (not practical on the phone): the
«تحليلاتك اتجددت خلاص» state at midnight, a limit above 10 (no dots), an
unknown limit (no number, no pill).

**Reset (Claude):** today's used count back to 0.

## D · Service problem

**Trigger (Claude):** switches the online reading **off** (so the page is read
on the phone) and the analysis kill switch **off** (the server answers 503).
The owner photographs a paper and continues from review.

| ID | Do | Expect |
|---|---|---|
| D1 | Land on the page | Title «حصلت مشكلة أثناء الشرح»; message «مقدرناش نكمّل شرح الورقة دلوقتي. الكلام اللي قريناه لسه معانا، فتقدر تحاول تاني من غير ما تصوّر من الأول.»; **no** green pill |
| D2 | Look at the tracker | «الصورة ✓»، «قراية الكلام ✓»، «الشرح» with a **warning triangle** on amber, «ماكملش» |
| D3 | Look at the tips | «لو المشكلة اتكررت»: wait a minute (clock), check the internet (wifi), read the text meanwhile |
| D4 | Look at the buttons | «حاول تاني», «عرض النص المستخرج», «العودة للرئيسية» |
| D5 | Claude turns the analysis back on; tap «حاول تاني» | The explanation, without a new photo |

**Reset (Claude):** analysis on, online reading back on.

## E · Analysis consent off

**Trigger (owner):** Settings → turn **off** «السماح بإرسال النص للتحليل»;
photograph a paper and continue from review.

| ID | Do | Expect |
|---|---|---|
| E1 | Land on the page | Title «الشرح الذكي مقفول»; message «إنت قافل «السماح بإرسال النص للتحليل» من الإعدادات، وده اختيارك. …» |
| E2 | Look at the content | White card «لو فتحته، هنقولك:» with four tiles (نوع الورقة، أهم اللي فيها / المطلوب منك، المواعيد اللي محتاجة تذكير), then a light teal note with a shield: «بنبعت نص ورقتك مشفَّر لخدمة تحليل علشان نفهمه، ومانحفظش النص عندنا.» — word for word |
| E3 | Look at the buttons | «افتح الإعدادات» (filled), «عرض النص المستخرج», «العودة للرئيسية»; **no** retry, **no** switch on the page, no tracker, no green pill |
| E4 | Tap «افتح الإعدادات» | Settings opens; turn the permission back **on** |
| E5 | Photograph again and continue | A normal explanation (consent restored) |

## F · Accessibility and languages

Run each on **A (unsupported)** and **C (daily limit)**, plus where noted.

| ID | Do | Expect |
|---|---|---|
| F1 | Android: font size and display size at maximum | Nothing cut off or overlapping; the page scrolls; on A, camera and gallery **stack** (camera on top); buttons grow to fit their text |
| F2 | App language → English | Everything in English, mirrored: back arrow on the **left** pointing left, the text card's chevron pointing **right**, camera button on the left; the tracker (B) runs left to right |
| F3 | App «تباين عالي» on | Darker teal and greys, all text readable; tiles and pills still distinct |
| F4 | TalkBack on (A, B, E) | The title is read as a heading; the tracker (B) is read as **one sentence** («الصورة تمام، وقراية الكلام تمام، والشرح مستني النت»), not word by word; the text card is announced as a **button**; each paper tile is read **once** with its examples; the pill's dots are not read; tip headings are headings |
| F5 | Status bar on every failure page | White icons over the teal bar |

## G · Regression (what F23 touched indirectly)

| ID | Do | Expect |
|---|---|---|
| G1 | A normal successful analysis | The result page's teal bar and summary hero look as before (the bar is now shared code) |
| G2 | Open a saved paper | Its teal bar and ⋮ menu work as before |
| G3 | The wait screen (F22) before a failure | The magnifier runs, then the failure page replaces it at once |
| G4 | *(Best effort)* Create a reminder with an alert 2 minutes ahead; when the notification arrives, delete the reminder in the app first, then tap the notification | «not found» page under the same teal bar, no icon box; its back-to-the-list button works |

## Results

| ID | ✅ / ❌ | Notes |
|---|---|---|
| A1–A10 | ✅ | Owner, 2026-10-03 |
| B1–B7 | ✅ | Owner, 2026-10-03; tunnel cut before continue, restored for B7 |
| C1–C7 | ✅ | Owner, 2026-10-03; countdown read ≈ 23 h at 00:55 Cairo |
| D1–D4 | ✅ | Owner, 2026-10-03; read on the phone (online reading off), 503 from the kill switch |
| D5 | ✅ | Owner, 2026-10-03. The retry reached the server without a new photo; the server's answer to that retry was `unsupported` (the phone-read text was too rough), so the page after it was the unsupported page |
| E1–E4 | ✅ | Owner, 2026-10-03 |
| E5 | ✅ | Confirmed by the owner, 2026-10-03. Note: the local backend log showed no analysis request after the consent page (01:02 Cairo) up to 01:05 |
| F1–F5 | ✅ | Confirmed by the owner, 2026-10-03. Note: the local backend log showed no analysis request between 01:02 and 01:05 Cairo, and the daily-limit and no-internet triggers were not requested for F |
| G1–G4 | — | Not run: the owner closed the device pass after F |

Every ❌ is fixed on this branch, with a test that reproduces it, before T14 is
marked DONE.
