# Squishy: project notes

Squishy is a personal Android video compressor. v1.x was Kotlin + Jetpack Compose;
**v2.0 is a full rewrite in Flutter** with a native Kotlin compression engine.
The v1 code is still in git history (tags `v1.0.0` to `v1.2.0`).

## Requirements (v2)

| # | Requirement | Where |
|---|-------------|-------|
| 1 | Keeps working in the background; nothing kills it | `CompressionService.kt` (specialUse FGS, wake lock, START_STICKY, persisted queue) + battery/Xiaomi onboarding |
| 2 | Optional keep-screen-on while working | `JobsController._syncScreen`, `FLAG_KEEP_SCREEN_ON` |
| 3 | Browse the phone's folders for videos | `features/browser` (All files access) |
| 4 | Sort videos (name, date, size, duration, resolution, asc/desc) | `BrowserController._resort` |
| 5 | Log of compressed and failed videos | `JobManager` → `log.json`; `features/history` |
| 6 | Delete originals automatically after a verified compression | `CompressionService.complete` |
| 7 | Grid / big cards / list / compact views | `ViewMode`, `video_tile.dart` |
| 8 | Output folder: default `<source folder>/compressed`, or any chosen folder | `JobsController.outputPathFor`, `folder_picker` |
| 9 | Modern animated progress (water tank, orb, ring, equalizer) | `widgets/progress_visuals.dart` |
| 10 | Several videos at once (1 to 3) or one after another | `JobManager.parallel` |
| 11 | Quality 360/480/720/1080p (default 480p) with expected size | `core/encoding_plan.dart` |
| 12 | Cut many segments and join them into one file | `features/editor` + Media3 `EditedMediaItemSequence` |
| 13 | Welcome, splash and loading animations | `features/splash`, `features/welcome` |
| 14 | Personalization tab with live preview cards (theme, progress, charts, view, font, corners) | `features/personalize` |

## Architecture decisions

- **Android 16+ only** (`minSdk = targetSdk = 36`). Built for a Xiaomi phone on HyperOS.
- **Sideloaded, not on the Play Store**, so it uses `MANAGE_EXTERNAL_STORAGE`
  for a real folder browser and for silent deletes.
- **Media3 Transformer** (not FFmpegKit, which is retired) does the transcoding, clipping
  and concatenation on the hardware encoders. HDR is tone-mapped to SDR.
- **The queue lives natively.** `JobManager` (state and persistence) and `CompressionService`
  (execution) run without the Flutter UI. Flutter sends commands over the
  `squishy/native` MethodChannel and watches the `squishy/jobs` EventChannel.
- **Foreground service type `specialUse`.** `mediaProcessing` and `dataSync` have a
  6 h/day timeout since Android 15. The type is always passed explicitly to
  `startForeground` (v1 crashed on Android 16 without it).
- **Verification before deleting:** the output must exist, have the expected duration
  (±max(2 s, 5 %)) and be smaller than the original. Otherwise the original is kept
  and the job is logged as failed. Cut jobs never delete the original.
- **Dart owns the encoding numbers** (`planFor`: target size, bitrate, size estimate),
  and native just executes them, so the estimate and the encode always agree.
- **Styling:** FlexColorScheme 8 for theming, flutter_animate for motion, design tokens
  in `SquishyTokens`. Raw colors are only allowed in `app/theme_presets.dart`.
  (FlexColorScheme 9 and google_fonts 9 use the new `material_ui` package and
  don't mix with Flutter's built-in material yet, so they are pinned to 8.x and 6.x.)

## Delivery

- Each change goes on a branch, then a PR, then green CI (`.github/workflows/ci.yml`:
  analyze, test, debug build), then a squash merge.
- Every release is tagged `vX.Y.Z`, described in `CHANGELOG.md`, and published as a
  GitHub Release with the signed APK attached.
- Release signing keys live outside the repo (`android/key.properties` is gitignored).
