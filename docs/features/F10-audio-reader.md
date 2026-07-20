# F10 · Audio Reader

- **Branch:** `feature/audio-reader` · **Milestone:** M8
- **Depends on:** F07 (result content), TTS core · **Feeds:** — (leaf)
- **Progress:** 0 / 8 DONE

Local TTS reading of the result. Text built on-device; nothing sent to an external voice service.

## Tasks

| # | ID | Title | Acceptance criteria | Status |
|---|---|---|---|---|
| 1 | F10-T01 | `TextToSpeechService` abstraction | interface over flutter_tts | TODO |
| 2 | F10-T02 | Reading-text builder | 4 modes (summary/summary+key/full/extracted) built locally | TODO |
| 3 | F10-T03 | Mini-player UI | «الاستماع للورقة»; «بيقرأ:…» | TODO |
| 4 | F10-T04 | Play/speak | starts reading selected mode | TODO |
| 5 | F10-T05 | Pause/resume/stop | transport controls | TODO |
| 6 | F10-T06 | Speed control | «سرعة القراءة» | TODO |
| 7 | F10-T07 | Voice selection | «صوت القراءة» from device voices | TODO |
| 8 | F10-T08 | Progress tracking | progress stream reflected in UI | TODO |

## Exit DoD
Reads locally (no network); all 4 modes; mini-player controls work; rate/voice persist.
