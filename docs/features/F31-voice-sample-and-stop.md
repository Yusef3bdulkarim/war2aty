# F31 · The voice sample says what the app does, and can be stopped

- **Branch:** `feature/voice-sample-and-stop`, based on `develop` · **Milestone:** post-F30
- **Depends on:** F11-T07 (the «تجربة الصوت» row and `PreviewDefaultVoice` this changes), F30 (which established that the preview speaks outside `ReadingQueue`, and why)
- **Progress:** 4 / 4
- **PR:** one PR into `develop`

The owner asked on 2026-10-18 for the «تجربة الصوت» sample to stop being a
bare greeting — «أهلًا بيك في تطبيق ورقتي بتقول إيه.» — and instead say
something about what the app does. Three drafts were put to them and the
third was approved as drafted, along with the stop control the length of it
made necessary.

## Why a stop control came with it

The sample is the one thing in the app that speaks **outside**
`ReadingQueue`: `PreviewDefaultVoice` hands it straight to the engine,
because it previews one specific voice rather than reading a paper (F30-T11
records why that exception exists). Three consequences, all of which shaped
the copy:

1. **There was no way to cut it short.** The row only started it, the
   mini-player is not on this screen, and leaving Settings did not stop it
   either — the cubit had no `close` of its own. One short sentence got away
   with that. Twenty seconds does not.
2. **No language segmentation and no number normalisation.** Those live in
   the queue (F30-T10, F30-T15) and in `BuildReadingText`. So the Arabic
   sample may contain **no Latin letters** — an Arabic voice names them one
   at a time, which is F30 RC-4's symptom — and no digits, which would be
   read by whatever rules the engine has rather than the app's.
3. **`speak` answers when the engine *accepts* the utterance**, not when it
   stops talking (F30-T09). So nothing could tell the row the sample had
   ended, and a row offering «إيقاف التجربة» would have gone on offering it
   over a silence.

## Locked decisions

1. **The third draft, approved as drafted** on 2026-10-18. The other two were
   a shorter version and one in «مع ورقتي» register.
2. **The app is the subject, not the first person.** The owner rejected the
   first pass for saying «أنا أقرالك وأفهمك»; the copy says what the app
   offers instead.
3. **The stop control was approved in the same breath** as the copy, for the
   reason above.
4. **No new glyph.** The design system has no stop mark, and inventing one is
   not this task's to do, so the row shows `speaker` while the sample plays
   and `play` when it is idle. The **label** is what carries the state —
   never the colour alone (design rules). A real stop glyph stays the
   owner's call.
5. **No privacy claim and no provider named** (§7), and nothing about the
   usage limit: the copy says what the app explains, not how often it may be
   asked. `app_strings_test`'s table covers both new keys like every other.

## Tasks

| # | ID | Task | Status |
|---|---|---|---|
| 1 | F31-T01 | Feature doc, branch, index row | DONE 2026-10-18 |
| 2 | F31-T02 | The approved sample copy, both languages | DONE 2026-10-18 |
| 3 | F31-T03 | Stop the sample from the same row: `StopVoicePreview`, `WatchVoicePreviewEvents`, the playing flag, and the two new strings | DONE 2026-10-18 |
| 4 | F31-T04 | Quality gate → PR | DONE 2026-10-18 |

**T02 and T03 landed in one commit, and the doc came after them** rather than
before as F30-T01 did. Worth recording honestly: the owner asked for copy,
the copy's length turned it into a control as well, and the two are not
separable — the stop button exists *because* of the new text, and shipping
the text without it would be shipping a twenty-second sample nobody can
interrupt.

## What the sample says

| | |
|---|---|
| Arabic | «أهلًا بيك في تطبيق ورقتي. التطبيق بيشرحلك أي ورقة رسمية أو فاتورة بالعامية البسيطة، وبيوضّح نوع الورقة وأهم المعلومات اللي فيها والمطلوب منك عمله وآخر ميعاد، وبيفكّرك بالمواعيد المهمة قبل ما تفوت، وبيقرالك الورقة كلها بصوت عالي زي ما بتسمع دلوقتي.» |
| English | "Welcome to the Waraqti app. The app explains any official paper or bill in plain words, shows what kind of paper it is, the important details in it, what you need to do and the final date, reminds you of important dates before they pass, and reads the whole paper out to you, just like you are hearing now." |

**The two new keys:**

| Key | Arabic | When |
|---|---|---|
| `settingsAudioPreviewStopLabel` | «إيقاف التجربة» | the row, while the sample plays |
| `settingsAudioPreviewStopFailedFeedback` | «تعذّر إيقاف عينة الصوت الآن.» | the engine would not stop |

## Where the pieces sit

`StopVoicePreview` and `WatchVoicePreviewEvents` are new use cases in
`core/audio/usecases/`, beside `PreviewDefaultVoice` and deliberately on the
same side of the line it draws. Routing the preview's stop through
`StopReading` would have claimed the engine from a reading `ReadingQueue`
might be sequencing and cleared a queue this screen knows nothing about; the
cancel the engine reports for the silenced sample is the one the queue
already ignores unless it had told itself a run of its own was speaking
(F30-T11).

`SettingsReady.voicePreviewPlaying` is what the row reads. It goes up when
the engine takes the sample, and down on a completion, a cancel, an engine
failure, a stop, or the screen closing — `_forgetPreview` is the one place
the flag and the subscription are dropped together, so neither can be left
behind without the other. `SettingsCubit.close` now stops a sample still
playing, which is the half "leaving the screen did not stop it either" was
about.

**One bug the tests caught, worth recording** because it is the kind that
looks like nothing: `_forgetPreview` originally awaited the stream
subscription's `cancel()`. That await does not settle inside a widget
pump, so the row never came back from «إيقاف التجربة» — three tests failed
on it at once. Nothing depends on the cancel having finished, so it is not
awaited, and the method is synchronous.

## Exit DoD

«تجربة الصوت» speaks the approved copy in both languages, and the same row
stops it while it plays, with the state in the label rather than the colour.
Leaving Settings silences it. A stop the engine refuses is reported rather
than swallowed. No Latin letter or digit in the Arabic sample, no provider
named, no privacy claim. `dart format .`, `flutter analyze` and
`flutter test` all pass.
