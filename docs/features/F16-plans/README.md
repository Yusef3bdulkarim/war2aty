# F16 · Per-task implementation plans

One file per task of [`../F16-live-edge-detection.md`](../F16-live-edge-detection.md).
Each plan is written so work can start from it directly: files to create/modify,
the design decisions already settled, an ordered step list, the tests to write,
and the exit gate.

| Task | Plan | Depends on | Touches the working capture path? |
|---|---|---|---|
| F16-T02 · `DocumentQuad` + detector interface | [F16-T02.md](F16-T02.md) | — | no (new files only) |
| F16-T03 · Pure-Dart detector | [F16-T03.md](F16-T03.md) | T02 | no (new files only) |
| F16-T04 · Camera stream plumbing | [F16-T04.md](F16-T04.md) | T02 | **yes** — `imageFormatGroup` + shutter |
| F16-T05 · Frame → preview mapping | [F16-T05.md](F16-T05.md) | T02, T04 | no |
| F16-T06 · Guide box follows the quad | [F16-T06.md](F16-T06.md) | T02, T05 | yes — `ViewfinderFrame` |
| F16-T07 · Cubit/state wiring | [F16-T07.md](F16-T07.md) | T03, T04, T06 | yes — `CameraCaptureCubit` |
| F16-T08 · Crop follows the visible guide | [F16-T08.md](F16-T08.md) | T06, T07 | yes — capture crop |
| F16-T09 · Perf & thermal guard | [F16-T09.md](F16-T09.md) | T07 | yes (guard only) |
| F16-T10 · Device verification | [F16-T10.md](F16-T10.md) | all | verification only |

## Rules that apply to every task
- Gate before "done": `dart format .` → `flutter analyze` → `flutter test` (CLAUDE.md §B.10).
- Mark the row `DONE` + bump **Progress** in `../F16-live-edge-detection.md` **before** starting the next task.
- One commit per task, Conventional Commits with the ID in brackets, pushed after each.
- Locked decisions 1–5 of F16 are constraints, not options — every plan below stays inside them.
