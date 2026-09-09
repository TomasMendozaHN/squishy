# Squishy — Project Plan

Squishy is an Android video compressor built to fix the flaws of the existing "Compressor" app.

## Backlog / Checklist

| # | Fix / Feature | Status |
|---|---------------|--------|
| 1 | Compress multiple videos at once (sequential queue) | Not started |
| 2 | Compression survives app backgrounding/minimizing | Done (PR #4) |
| 3 | Progress bar reports accurate 0-100% for the whole run (not stuck after ~20%) | In progress (PR #6) |
| 4 | Compression survives the screen turning off | Done (PR #4) |
| 5 | App is not killed when minimized (multitasking-friendly) | Done (PR #4) |
| 6 | Video library sortable by name, date modified, size, and duration | Done (PR #3) |

**Done (scaffold):**
- [x] Initial Android Studio project scaffold (Kotlin + Jetpack Compose + media3 dependencies)
- [x] GitHub Actions CI: `./gradlew lint testDebugUnitTest assembleDebug` on every PR
- [x] Branch protection on `main` requiring the CI `build` check to pass

## Architecture Decisions

### Foreground service drives compression
Fixes #2, #4, and #5 share a root cause: compression must run in an Android
**foreground service** (`android:foregroundServiceType="mediaProcessing"`), not a
plain background thread/coroutine. A foreground service with a persistent
notification is protected from OS process-killing when the app is backgrounded,
minimized, or the screen turns off.

- The service owns the compression lifecycle (start, progress, completion, failure).
- The notification shows which video is compressing, its live progress, and the
  overall queue position; it also carries a stop/cancel action.
- The activity observes service state (not the other way around), so re-entering
  the app restores live state.

### media3-transformer for transcoding
- `androidx.media3:media3-transformer` is Google's actively maintained transcoding
  API. It supports a progress listener that reports accurate progress.
- **Do not use FFmpegKit** — it is discontinued/archived and inappropriate for a
  new project.

### Queue
- The service supports a queue of videos, compressing them sequentially without
  the user needing to keep the app open.
- Overall queue progress (completed + current) is surfaced in the notification
  and in the UI.

### Progress reporting (fix #3)
- Accurate progress (0-100%) comes from the media3 transformer progress listener
  and is reported to both the in-app UI and the notification for the video
  currently compressing, plus overall queue progress.
- Progress is derived from the actual transcoded output size relative to the
  expected output, never from a coarse heuristic that stalls.

### Video library (fix #6)
- Library screen lists device videos via `MediaStore`.
- Sortable by: name, date modified, size, duration.

## Delivery Process

Each fix/feature is delivered as its own branch → PR → passing CI → auto-merge
(squash). No giant PRs.

PR order:
1. Scaffold + CI + empty app — **merged**
2. `PROJECT.md` (this document) — **merged**
3. Video library + sorting — **merged**
4. Foreground-service compression engine
5. Queue
6. Progress reporting polish

### Foreground service (PR #4)
- `CompressionService` runs as a `mediaProcessing` foreground service with a persistent,
  progress-updating notification and a Stop action.
- minSdk is 26 because `foregroundServiceType="mediaProcessing"` requires API 26+.
- media3 APIs are `@UnstableApi`; the project opts in via `app/lint.xml`.
