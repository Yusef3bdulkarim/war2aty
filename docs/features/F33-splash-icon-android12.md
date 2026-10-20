# F33 · The Android 12+ splash icon, at the size the platform actually draws

- **Branch:** `release/1.0.2`, cut from `release/1.0.1` · **Milestone:** post-F32
- **Ships as:** `1.0.2+3`. The version **name** rises, not just the build
  number: `minimum_app_version` can only see the name, so a fix shipped as
  `1.0.1+3` could never be gated against the build it replaces
  ([RELEASE.md §2](../RELEASE.md)). Cut from `release/1.0.1` rather than from
  `develop` because the 1.0.1 release work has not merged back yet — this
  branch is `1.0.1+2` plus this fix, and nothing else.
- **Depends on:** F28 (the launch this repairs), F27-T18 (the device pass that measured the handover), F32 (the release the bug shipped in)
- **Progress:** 5 / 10
- **Reported:** 2026-10-20 by the owner, on a second phone, against the **published** `1.0.1+2` build from Google Play

## What the owner saw

The mark on the launch screen is enormous — about **half the width of the
phone** — its sides cut flat, and after a moment it snaps down to its real
size and the app opens. Their screenshot shows the ring sliced vertically on
both the left and the right.

It had never appeared in development. The project's test phone is the
**RMX2001, Android 11 (API 30)**, and the bug lives in a code path that only
exists from **API 31**. F28 said so itself and shipped anyway:

> *"The Android 12+ path. The only phone available is API 30. `values-v31`,
> the 288 dp icon canvas and the exit-animation listener are built to spec,
> guarded by tests that read the XML, and **unverified on hardware**."*
> — [F28 "Known limits"](F28-splash-redesign.md)

So: pre-12 correct, 12+ wrong, and the only hardware we had could not tell
the difference.

## Why it happened

F28-T05 wrote `drawable/splash_icon.xml` as a `layer-list` pinning the mark to
`128dp × 128dp`, on the belief that this "supplies the 288 dp canvas the
system is looking for". Neither half of that belief holds.

**The drawable's own size was never 288 dp.** `LayerDrawable.getIntrinsicWidth`
is `max(inset + width + inset)` over the layers. One layer, `128dp`, no
insets — the drawable measured **128 dp**. Nothing in the file said 288
anywhere.

**And the platform does not read that size at all.** From AOSP, for the
`windowSplashScreenAnimatedIcon` path with no icon background:

| Step | Source | Value |
|---|---|---|
| `starting_surface_icon_size` | `frameworks/base/core/res/.../dimens.xml` | 160 dp |
| `starting_surface_default_icon_size` (`srcIconSize`) | same | 108 dp |
| `splash_icon_no_background_scale_factor` | `WindowManager/Shell/res/values/dimen.xml` | 1.2 |
| `mFinalIconSize = mIconSize * mNoBackgroundScale` | `SplashscreenContentDrawer.build()` | **192 dp** |
| the icon view's size, forced | `SplashScreenView.Builder.build()`: `params.width = mIconSize` | 192 dp |
| a plain drawable is wrapped | `SplashscreenIconDrawableFactory.makeIconDrawable()` → `AdaptiveForegroundDrawable` | foreground viewport = **1.5 × 192 = 288 dp**, clipped by `config_icon_mask` |
| and rasterised then scaled | `ImmobileIconDrawable`: `scale = iconSize / srcIconSize` | **× 1.778** |

The drawable is handed a 288 dp viewport and stretched across it whatever it
claims to be. A layer with an explicit `android:width` is the one thing that
does **not** stretch with its bounds (`LayerDrawable.updateLayerBoundsInternal`
places it at exactly that size), so the mark was painted at 128 dp inside a
108 dp rasterisation canvas — overflowing it — and the whole thing was then
scaled by 1.778:

- intended: **128 dp**;
- drawn: **~227 dp**, cropped to the 192 dp mask circle, i.e. the mark filled
  the entire icon area and lost its edges to the mask;
- measured on the owner's screenshot: the mark spans **~50% of the screen
  width**, which on a 393 dp-wide phone is ~192 dp. The prediction and the
  photograph agree.

Then `MainActivity.removeSystemSplashExitAnimation` takes the splash off with
no animation and Flutter draws the same mark at 128 dp — the snap the owner
described.

## Why no test caught it

`native_splash_test` had a guard named *"the icon supplies its own canvas
instead of being scaled up"*, and what it asserted was that the XML contained
`android:width="128dp"` — **the bug itself**, written down as the expectation.
A guard can only be as right as the belief behind it. The replacement measures
the generated bitmaps (canvas, ink box, distance to the mask circle), because
those are what the platform reads, and both mutations — the XML returning, and
a bare 128 dp mark in place of the canvas — were confirmed to turn it red.

## The fix

Only the ratio inside the drawable survives the trip, so the mark is **128 of
288 dp** and the platform's scaling lands it at 128 dp wherever that viewport
ends up. Nothing about the pre-12 path, iOS, or Flutter's first frame changes.

- `tool/branding/generate_brand_assets.dart` gains `_splashIconCanvasDp = 288`
  and writes `drawable-{bucket}/splash_icon.png`: the same `squareSymbol`, same
  `_markSharpen`, cut to `_splashMarkDp` and centred on a transparent 288 dp
  canvas.

  | bucket | canvas | mark |
  |---|---|---|
  | mdpi | 288 px | 128 px |
  | hdpi | 432 px | 192 px |
  | xhdpi | 576 px | 256 px |
  | xxhdpi | 864 px | 384 px |
  | xxxhdpi | 1152 px | 512 px |

- `drawable/splash_icon.xml` is **deleted**. The theme attribute is unchanged —
  `@drawable/splash_icon` now resolves to those bitmaps — so `values-v31` and
  `values-night-v31` only gain a comment recording what the platform really
  does with them.
- The ink's farthest corner sits at r ≈ 82 dp against the mask's 96 dp radius:
  ~15% of margin, on the tightest mask shape there is (a circle). Squircle and
  rounded-square masks are larger, so no device clips it.
- Regeneration was byte-identical for every other asset, so this branch adds
  five files and changes no existing image.

## Known limits

1. **The 12+ mark is slightly softer than Flutter's.** `ImmobileIconDrawable`
   rasterises the icon into a canvas of `srcIconSize` (108 dp) and scales it
   up by 1.778, so the mark reaches the screen with about 72 dp-worth of
   resolution however sharp the source is. This is inherent to the attribute
   path — `loadInDetail` is hard-coded `false` there — and it was equally true
   of the shipped build; the fix does not add it and cannot remove it. The one
   escape is an `Animatable` drawable (a one-frame `<animation-list>`), which
   AOSP draws live into a `SurfaceView` with no intermediate bitmap. **Not
   taken**: it trades a geometry we can prove for a code path that is rarer,
   OEM-sensitive and would need its own device pass. Revisit only if the
   softness is visible at the handover on real hardware (T05).
2. **The mask shape is the device's, not ours.** The icon is clipped by
   `config_icon_mask`, so the mark sits in a circle on one phone and a
   squircle on another. With 15% of margin nothing is cut on either, but the
   *silhouette* of the splash icon area is out of our hands on 12+.
3. **Two different splashes on 12+.** The theme still sets
   `windowBackground = @drawable/launch_background` (teal + a 128 dp mark)
   alongside the splash-screen attributes. When the platform picks a
   solid-colour starting window instead of the icon one, that is what shows.
   Both now put the mark at 128 dp on the same teal, so the two agree — but it
   is two paths, not one.
4. **iOS is still unbuilt.** No Mac; unchanged by this feature either way.

## Tasks

| # | ID | Task | Notes | Status |
|---|---|---|---|---|
| 1 | F33-T01 | Find the cause, with proof | AOSP sizing chain read end to end; prediction (192 dp, masked) matched the owner's screenshot (~50% of screen width) | DONE 2026-10-20 |
| 2 | F33-T02 | The 288 dp canvas, in the generator | `_splashIconCanvasDp`, `_onCanvas(..., sharpen:)`, five buckets; every other asset regenerated byte-identical | DONE 2026-10-20 |
| 3 | F33-T03 | Wire the theme, delete the XML | attribute value unchanged; both `v31` themes document the real contract | DONE 2026-10-20 |
| 4 | F33-T04 | Guards that measure, not quote | canvas per density, ink = Flutter's mark, centred, inside the mask circle; both mutations proved red; `dart format` / `flutter analyze` (19 infos = baseline) / `flutter test` (2902) green | DONE 2026-10-20 |
| 5 | F33-T05 | Device pass on an Android 12+ phone | the mark at ~1/3 of the screen width, uncut, and no size change when the app's own screen appears; owner's second phone | TODO |
| 6 | F33-T06 | `pubspec.yaml` → `1.0.2+3`, on `release/1.0.2` | the name rises so the version gate can reach `1.0.1+2` if it ever has to | DONE 2026-10-20 |
| 7 | F33-T07 | Play "What's new", Arabic + English, under §7 | below; **owner's approval needed before upload** | TODO |
| 8 | F33-T08 | Build the bundle, archive the symbols first, run both compliance halves | see "Build record" | TODO |
| 9 | F33-T09 | **(owner)** Upload to Play Production with T07's notes | | TODO |
| 10 | F33-T10 | PR `release/1.0.2` → `develop`; `develop` → `main`; tag `v1.0.2+3` | note `v1.0.1+2` was never actually tagged — the repo still has no tags | TODO |

## T07 · Play "What's new" — draft, awaiting the owner

Play allows 500 characters per language. Neither text names a provider, and
neither says anything about who can see the image or the text (§7). The app's
listing carries an English translation, so leaving English blank would show the
Arabic to an English-locale user.

**Release → Production → create release → Release notes → Arabic (الافتراضي)**:

```
صلّحنا شكل شاشة البداية.

على بعض الموبايلات كان شعار التطبيق بيظهر كبير قوي ومقصوص من الأطراف أول ما تفتح التطبيق، وبعدين يصغر فجأة. دلوقتي بيفتح بحجمه الصح وثابت على كل الموبايلات.

مفيش أي تغيير تاني في التطبيق.
```

**→ Release notes → English (United States)**:

```
We fixed how the app looks while it opens.

On some phones the logo appeared far too large and cut off at the edges, then suddenly shrank. It now opens at the right size, and stays there, on every phone.

Nothing else in the app changed.
```

Both describe only what a user saw and what they will see — the claim is
checked against the screenshot the owner sent, not against the task list.
