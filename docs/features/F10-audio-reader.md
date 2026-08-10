# F10 · Audio Reader

- **Branch:** `feature/audio-reader` · **Milestone:** M8
- **Depends on:** F07 (result content), TTS core · **Feeds:** — (leaf)
- **Progress:** 7 / 8 DONE

Local TTS reading of the result. Text built on-device; nothing sent to an external voice service.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F10-T01 | `TextToSpeechService` abstraction | interface over flutter_tts | DONE |
| 2 | F10-T02 | Reading-text builder | 4 modes (summary/summary+key/full/extracted) built locally | DONE |
| 3 | F10-T03 | Mini-player UI | «الاستماع للورقة»; «بيقرأ:…» | DONE |
| 4 | F10-T04 | Play/speak | starts reading selected mode | DONE |
| 5 | F10-T05 | Pause/resume/stop | transport controls | DONE |
| 6 | F10-T06 | Speed control | «سرعة القراءة» | DONE |
| 7 | F10-T07 | Voice selection | «صوت القراءة» from device voices | DONE |
| 8 | F10-T08 | Progress tracking | progress stream reflected in UI | TODO |

**T07 scope note:** `Waraqti.dc.html` only has a voice picker on the Settings
screen (F11-T07, which explicitly depends on this feature for "audio
prefs") — the F10 options sheet's own design has no voice control. T07
therefore shipped as domain/data groundwork only: `SelectVoiceForReading`
picks a default device voice matching the text's script (ar/en), applied
automatically in `StartReading`. No picker UI, and no persisted user
choice — both are F11-T07's job once that screen exists.

## Exit DoD
Reads locally (no network); all 4 modes; mini-player controls work; rate persists across a reading session (voice: automatic default only until F11-T07 adds a picker).
