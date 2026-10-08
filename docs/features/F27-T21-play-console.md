# F27-T21 · Play Console setup — exact answers, in order

**Written for the owner, filling the forms in Play Console.** Every answer here
is derived from what the code actually does, with the reasoning given wherever
an answer is a judgement rather than a fact. Where an answer is **yours to
supply**, it says so.

I cannot see your console. Play moves these forms and rewords their questions
every few months, so if a question below is not on your screen word for word,
match it by meaning and tell me what it actually says — do not guess. Nothing
here needs doing in one sitting; each section saves on its own.

**Order matters.** Play will not let you submit until everything in *Policy →
App content* is green, and the content rating questionnaire cannot be answered
before the app exists. Work top to bottom.

---

## 0 · Before you open the console

| | |
|---|---|
| Package name (final, unchangeable after the first upload) | **`com.war2aty.app`** (Q15) |
| App bundle to upload | `build/app/outputs/bundle/prodRelease/app-prod-release.aab` — rebuild it, don't reuse the T19 file (see §9) |
| Privacy policy URL | **`https://yusef3bdulkarim.github.io/war2aty/privacy.html`** |
| Terms URL (not asked for, but keep it to hand) | `https://yusef3bdulkarim.github.io/war2aty/terms.html` |
| Support email | **`war2aty.support@gmail.com`** |
| Developer of record | **شركة كيان وطموح للخدمات التجارية** / Kayan Wa Tomouh Commercial Services |
| Countries | **Egypt only** (Q4) |
| Store languages | **Arabic (ar)** as default, **English (en-US)** second (Q6) |

**You need to supply:** the company's registered address and phone for the
developer account's *verification* (Play requires both for an organisation
account, and the address appears publicly on your developer page), and the
D-U-N-S number if Play asks for one. I have none of these and will not guess
them.

---

## 1 · Create the app

**Play Console → All apps → Create app**

| Field | Answer |
|---|---|
| App name | `ورقتي بتقول إيه؟` |
| Default language | `العربية (ar)` |
| App or game | **App** |
| Free or paid | **Free** — and note this is one-way: a free app can never become paid |
| Declarations | tick both (developer programme policies, US export laws) |

The app name here is the fuller, explaining form rather than the launcher's
«ورقتي». That is deliberate: on the launcher the short name is all that fits,
while in a store listing the name is doing the explaining. Both are «ورقتي»-
based, so T14's decision holds.

---

## 2 · Store listing (Arabic — the default)

**Grow → Store presence → Main store listing**

**App name** (30 max — this is 16):

```
ورقتي بتقول إيه؟
```

**Short description** (80 max — this is 66):

```
صوّر ورقتك المطبوعة، والتطبيق يقراها ويشرحلك المطلوب منك ومواعيدها
```

**Full description** (4000 max):

```
وصلتك ورقة ومش فاهم هي بتقول إيه؟ صوّرها، و«ورقتي» يقراها ويشرحها لك بالعربي
وبكلام بسيط.

إيه اللي التطبيق بيعمله؟
• يقرا الورقة المطبوعة من صورة بالكاميرا أو من معرض الصور.
• يقولك نوع الورقة: فاتورة، موعد، إعلان رسمي، تحليل طبي، وغيرها.
• يلخّص أهم اللي فيها: المبالغ، التواريخ، وأرقام الحساب.
• يوضّح المطلوب منك بالظبط، ولحد إمتى.
• يعمل لك تذكير بالموعد المهم قبل ما يفوت.
• يقرا لك الشرح بصوت عالي، لو القراءة صعبة عليك.

معمول علشان يكون سهل
خط كبير وواضح، واجهة عربي بالكامل من اليمين للشمال، وأزرار كبيرة. وتقدر تكبّر
الخط أكتر من الإعدادات، والتطبيق بيحترم كمان حجم الخط اللي انت مظبّطه في
الموبايل نفسه.

خصوصيتك
• النتيجة والتذكيرات بتتحفظ على موبايلك، مش عندنا.
• صورة الورقة مش بتتحفظ على الموبايل إلا لو انت طلبت.
• بنبعت نص ورقتك مشفَّر لخدمة تحليل علشان نفهمه، ومانحفظش النص عندنا.
• ومن غير إنترنت، الورقة بتتقري على موبايلك بس.
• تقدر تحذف مستنداتك وتذكيراتك وكل بيانات التطبيق في أي وقت.
• مافيش إعلانات، ومافيش تتبّع، ومابنبيعش بياناتك.
اقرا التفاصيل كاملة: https://yusef3bdulkarim.github.io/war2aty/privacy.html

حاجة مهمة لازم تعرفها
«ورقتي» بيساعدك تفهم ورقتك، وهو مش استشارة قانونية ولا طبية ولا مالية. القراءة
الآلية ممكن تغلط في رقم أو تاريخ، والتطبيق بيعلّم المعلومة اللي قراءتها غير
مؤكدة. قبل أي قرار أو دفع، راجع الورقة الأصلية أو اسأل الجهة اللي أصدرتها.

التطبيق مجاني، وفيه حد 3 تحليلات في اليوم لكل مستخدم علشان الخدمة تفضل متاحة
للكل.

للتواصل: war2aty.support@gmail.com
```

**Graphics** — all generated, see §8 for the files and where each one goes.

---

## 3 · Store listing (English)

**Grow → Store presence → Main store listing → Manage translations → Add your
own translation → English (United States)**

**App name** (30 max — this is 28):

```
War2aty — What's on My Paper
```

This is shorter than the app's own English name, `War2aty — What Does My Paper
Say?`, which is 33 characters and does not fit Play's 30-character field. A
deliberate difference, not a drift.

**Short description** (80 max — this is 78):

```
Photograph a printed paper and get it explained: what it is, what you must do.
```

**Full description:**

```
Got a paper you can't make sense of? Photograph it, and War2aty reads it and
explains it in plain language.

What it does
• Reads a printed paper from your camera or your gallery.
• Tells you what kind of paper it is: a bill, an appointment, an official
  notice, a lab result, and more.
• Pulls out what matters: amounts, dates and account numbers.
• Spells out what you are being asked to do, and by when.
• Sets a reminder for the date that matters, before it passes.
• Reads the explanation aloud, if reading is hard.

Built to be easy
Large, clear type, big buttons, and a fully Arabic right-to-left interface. You
can make the text larger in settings, and the app also respects the text size
you have set on the phone itself.

Your privacy
• The result and your reminders are stored on your phone, not on our servers.
• The photo is not saved on your phone unless you ask for it.
• Your paper's text is sent encrypted to an analysis service so we can
  understand it, and we do not keep the text.
• With no internet, the paper is read on your phone only.
• You can delete your documents, your reminders and all app data at any time.
• No ads, no tracking, and we never sell your data.
Full details: https://yusef3bdulkarim.github.io/war2aty/privacy.html

Something you should know
War2aty helps you understand your paper. It is not legal, medical or financial
advice. Automated reading can get a number or a date wrong, and the app marks
any reading it is unsure about. Before any decision or payment, check the
original document or ask whoever issued it.

The app is free, with a limit of 3 analyses per user per day so the service
stays available to everyone.

Contact: war2aty.support@gmail.com
```

---

## 4 · App content → Privacy policy

**Policy → App content → Privacy policy → Start**

```
https://yusef3bdulkarim.github.io/war2aty/privacy.html
```

Paste it, **Save**. Play fetches the page, so it must stay reachable — it is on
the `gh-pages` branch and is live now (F27-T20).

---

## 5 · App content → the small declarations

Do these in one pass. Each is a single screen.

| Section | Answer | Why |
|---|---|---|
| **Ads** | **No, my app does not contain ads** | there are none, and no ad SDK is linked |
| **App access** | **All functionality is available without special access** | there is no login. The app signs in anonymously with no user action, so there is nothing to give Play credentials for |
| **Content ratings** | see §6 | |
| **Target audience** | see §7 | |
| **News apps** | **No** | not a news app |
| **COVID-19 contact tracing and status apps** | **No** | |
| **Data safety** | see §6B — the long one | |
| **Government apps** | **No** | the app is not made by or for a government body. It *reads* official papers, which is not the same thing, and the store listing must never imply otherwise |
| **Financial features** | **No** — "My app doesn't provide any financial features" | it reads a bill; it does not take a payment, lend, or deal in securities |
| **Health** | **not a health app** — leave the declaration off | the app has no Health Connect integration and no health permission. It can read a lab result, which is why this is a judgement, not a given: see the note in §6B |
| **Advertising ID** | **No, my app does not use advertising ID** | nothing in the app touches it, and `AD_ID` is not in the manifest. Answering yes here would require a permission the app does not have |

---

## 6 · Content rating

**Policy → App content → Content ratings → Start questionnaire**

| Field | Answer |
|---|---|
| Email address | `war2aty.support@gmail.com` |
| Category | **Utility, Productivity, Communication, or Other** |

Then every content question is **No**:

- Violence, blood, sexuality, nudity, profanity, crude humour → **No** to all
- Controlled substances (drugs, alcohol, tobacco) → **No**
- Gambling, simulated gambling, contests → **No**
- Horror/fear themes → **No**
- **Does the app allow users to interact or exchange content with each other?**
  → **No**. There is no account, no messaging, no sharing between users, no
  user-generated content that anyone else can see.
- **Does the app share the user's current location with other users?** → **No**
- **Does the app allow users to purchase digital goods?** → **No**
- **Does the app contain any content that could be considered sensitive?** →
  **No**

Expected outcome: **Everyone / 3+** in every rating body, with no interactive
elements declared.

A note for your own peace of mind: the app displays whatever is on the user's
own paper, which could be anything. That is not "content" in the rating sense —
the questionnaire asks what *the app* provides, and the app provides the
explanation, not the paper.

---

## 6B · Data safety — the form that matters

**Policy → App content → Data safety → Start**

This is the one form where a wrong answer is a policy violation rather than a
mistake, so read the three decisions below before you start filling it.

### Decision 1 — the photo counts as collected, even though it does not leave the phone today

Online reading is **off at launch** (`online_ocr_enabled = false`, Q12), so on
the day you publish, no photo ever leaves a user's phone. It would be
technically true to declare that no photos are collected.

**Declare them collected and shared anyway.** The flag is server-side: T26 can
turn it on with no app update, and the moment it does, a "we don't collect
photos" declaration becomes false — with no new submission for Play to notice
and no way for you to find out you are now in violation. Declaring the capability
up front costs nothing and matches what the privacy policy already tells users.

### Decision 2 — "shared" is yes, even though the providers process on our behalf

Play excludes transfers to a "service provider" from its definition of sharing.
A provider that only processed our data on our behalf would not count.

Ours are on **free tiers whose terms let them retain the content and have staff
review it to improve their own services** — which is more than processing on our
behalf. So this is sharing, and §7 of the project's own rules already forces the
privacy policy to say so. Under-declaring sharing is one of the most common
causes of enforcement action. **Answer yes.**

### Decision 3 — what is *not* collected, and why that surprises people

Play's "collected" means **transmitted off the device**. Almost everything this
app holds is local and therefore **not** collected:

- the saved papers, their text and extracted amounts and dates — on-device
  database only
- the reminders and their alerts — on-device only
- every setting — on-device only
- the saved page images — on-device, encrypted, only if the user asks

Do not declare any of it. Declaring local data as collected is both wrong and
needlessly alarming.

### The answers, type by type

Say **Yes** to "Does your app collect or share any of the required user data
types?", then declare exactly these four.

#### 1. Photos and videos → Photos

| Question | Answer |
|---|---|
| Collected | **Yes** |
| Shared | **Yes** |
| Processed ephemerally | **Yes** — our server holds it in memory for the request and writes it nowhere |
| Required or optional | **Required** — photographing the paper is the whole app |
| Purposes | **App functionality** only |

#### 2. Files and docs → Files and docs

This is the extracted text of the user's paper. Play has no "document content"
type; "Files and docs" is the closest honest container, and the text *is* the
document's content.

| Question | Answer |
|---|---|
| Collected | **Yes** |
| Shared | **Yes** |
| Processed ephemerally | **Yes** |
| Required or optional | **Optional** — «السماح بإرسال النص للتحليل» in settings turns it off, and it defaults on. With it off, nothing is sent |
| Purposes | **App functionality** only |

#### 3. Device or other IDs

The app's own installation identifier and the anonymous sign-in id.

| Question | Answer |
|---|---|
| Collected | **Yes** |
| Shared | **No** |
| Processed ephemerally | **No** — the usage counter and the attempt log persist, for up to 90 days |
| Required or optional | **Required** |
| Purposes | **App functionality** and **Fraud prevention, security, and compliance** |

**Shared is No, and I verified it rather than assuming it:** the request to the
reading service carries only the image bytes and a fixed prompt, and the request
to the analysis service only the text, the detected languages, the candidate
dates and amounts, and a fixed prompt. Neither carries the identifier. Our own
database stores a *salted hash* of it, never the identifier itself.

#### 4. App info and performance → Crash logs, and → Diagnostics

| Question | Answer |
|---|---|
| Collected | **Yes** (both) |
| Shared | **No** (both) |
| Processed ephemerally | **No** — error reports are kept 90 days |
| Required or optional | **Required** |
| Purposes | **App functionality** and **Analytics** |

There are no stack traces and no messages — a report is an error code, a stage,
a duration, an app version and some ids. Nothing from the paper ever reaches it.

#### Say No to everything else

Location, Personal info (name, email, phone, address, race, political or
religious beliefs, sexual orientation), Financial info, Health and fitness,
Messages, Audio, Music, Calendar, Contacts, App activity, Web browsing, Installed
apps, Search history, Purchase history.

**Two of those deserve a sentence, because a reviewer might wonder.** A user's
paper can obviously contain their name, an amount, or a lab result — but the app
does not seek, parse or use any of it *as* personal, financial or health data. It
treats the paper as an opaque document, which is why the honest declaration is
the container (Photos, Files and docs) and not a list of everything a document
might happen to contain. If you would rather over-declare, the cost is a
scarier-looking data card and a Health declaration you then have to fill in;
tell me and I will revise this section rather than you improvising it in the
form.

### The security section at the end

| Question | Answer |
|---|---|
| Is all of the user data collected by your app encrypted in transit? | **Yes** — every endpoint the release app calls is `https://`: the Supabase project URL and its Edge Functions. That is the whole guarantee, and it is enough. *Not* a platform block: the app's network security config exists to **permit** cleartext to three local development addresses, and Android only blocks cleartext by default from API 28, while `minSdk` is 24 (see the note below) |
| Do you provide a way for users to request that their data is deleted? | **Yes** |
| Deletion URL | `https://yusef3bdulkarim.github.io/war2aty/privacy.html` — the policy's §7 names the in-app controls and the support address |
| Has your app been independently reviewed against a global security standard? | **No** — leave it unticked; it is optional and we have no such review |

**A hardening gap this turned up, not a Data safety problem.** On Android
7.0–8.1 (API 24–27), which the app supports, nothing in the app refuses a plain
`http://` URL: the network security config lists only exceptions, and the
platform default that blocks cleartext starts at API 28. No such URL exists in
a release build today, so no data travels unencrypted and the answer above is
true. But one `base-config cleartextTrafficPermitted="false"` line would make it
true by construction rather than by every URL happening to be right. It is an
app change with a test, so it belongs in a task of its own — recorded here so it
is not lost.

Play may also show an **account deletion** requirement. It applies to apps that
let users create an account. This app has none — the anonymous sign-in happens
without the user doing anything and exposes no account UI — so the requirement
does not apply. If the console insists on a URL anyway, give it the policy URL.

---

## 7 · Target audience

**Policy → App content → Target audience and content**

| Question | Answer |
|---|---|
| Target age groups | **18 and over**, and nothing below it |
| Appeal to children | **No** |
| Store presence (Google Play for Families) | leave out |

Why 18+ and not 13+: the app exists to help someone act on an official document
— a bill, a court notice, a medical result. Declaring any age band below 18
pulls the app into Play's Families policy, which brings its own ad, content and
data rules for no benefit here.

**One consistency fix this creates.** The privacy policy currently says the app
is not directed at children **under 13**, which is the usual wording but does not
match an 18+ declaration. A reviewer comparing the two could reasonably call that
out. Say the word and I will change the page to «تحت 18 سنة» / "under 18" and
re-sync the published branch — it is a two-line edit.

---

## 8 · Graphics

All six files are generated and committed under `store/`, already in the
format each Play field demands.

| Play field | File | Size | Format Play requires |
|---|---|---|---|
| App icon | `store/icon-512.png` | 512 × 512 | 32-bit PNG — this is RGBA, fully opaque |
| Feature graphic | `store/feature-graphic.png` | 1024 × 500 | JPEG or 24-bit PNG, **no alpha** — this is RGB |
| Phone screenshot 1 | `store/screenshots/ar/1-home.png` | 1080 × 1920 | 24-bit PNG, no alpha |
| Phone screenshot 2 | `store/screenshots/ar/2-result.png` | 1080 × 1920 | 〃 |
| Phone screenshot 3 | `store/screenshots/ar/3-reminder.png` | 1080 × 1920 | 〃 |
| Phone screenshot 4 | `store/screenshots/ar/4-privacy.png` | 1080 × 1920 | 〃 |

Upload the screenshots **in filename order** — Home, the explained paper, the
reminder, the privacy promises. Play shows them in upload order.

**Upload them to the Arabic listing only.** Play shows a translation the
default language's screenshots when it has none of its own, so the English
listing inherits these. That is the honest choice as well as the easy one: the
app *is* Arabic, and an English screenshot would show a language mode most of
its users will never switch to. If you want English screenshots anyway, say so
— it is one more run of the same generator.

**No tablet screenshots.** The app is portrait phone only, so leave the 7-inch
and 10-inch slots empty. Play will warn that the app will not be promoted on
tablets — the correct outcome, not a problem to fix.

### What the graphics are, and how to remake them

- **The icon** is the launcher icon, not a redrawing of it: the two adaptive
  layers composited and cropped to the 72 dp Android actually shows, so the
  store and the home screen show the same picture. It is *not*
  `assets/app_icon.png`, which has rounded transparent corners — Play rounds
  the corners itself, and a pre-rounded icon gets rounded twice.
- **The feature graphic** is drawn in Flutter with the real Cairo font,
  because Arabic needs shaping and an image library would print «ورقتي» as
  four disconnected letters.
- **The screenshots are the real app**, not mock-ups: the real dependency
  graph walked through the real invoice journey by the integration harness
  (F27-T17), so what a buyer sees is what the app does. The only thing changed
  for them is the sample bill's prose, which the bundled fixture dates 2024 —
  it is rewritten to a deadline a week from the day they are rendered.

After any change to a screen they show, regenerate both, in this order:

```powershell
flutter test test/store/generate_store_assets.dart --update-goldens
dart run tool/store/finalize_store_assets.dart
```

The first renders; the second builds the icon and strips the alpha channel
Play refuses — after checking no pixel actually used it, because a transparent
pixel flattened to RGB turns black.

## 9 · Play App Signing and the upload (Q14)

**Release → Setup → App signing** — accept **Play App Signing**, which is the
default for a new app and what Q14 decided. It means Play holds the key it
signs the delivered app with, and `android/app/war2aty-release.jks` becomes the
*upload* key only. If that file is ever lost, an upload key can be reset; a lost
app-signing key could not be. **Back the keystore up off this machine anyway** —
losing it is still days of inconvenience.

**Rebuild the bundle before uploading.** The T19 bundle was `versionCode 6`,
built before T20 added the policy links, so it does not contain the settings
rows that point at the pages this listing links to:

```powershell
./tool/build_release.ps1 -Artifact aab
dart run tool/check_play_compliance.dart build/app/outputs/bundle/prodRelease/app-prod-release.aab
```

Expect `✓ every check passed`. Then **Release → Testing → Internal testing**
(not Production) and upload there first — that is T22's smoke test, and it costs
nothing to have the artefact sitting in a track while the forms are being
reviewed.

---

## 10 · What I cannot do from here, and what I will check

Everything above is yours: the console is tied to your Google account, and
nothing in it is reachable from this machine. Once you have filled it in, I can
verify from the repo side:

- that the uploaded bundle's `versionCode`, package name and signing certificate
  are the ones this document names,
- that the privacy and terms URLs still answer 200 and still carry no
  placeholder,
- that the store listing text matches the strings above, if you paste back what
  the console shows.

Tell me what Play says if it rejects or queries anything. A rejection message is
usually precise about which declaration it disbelieves, and that is far quicker
to fix than guessing.
