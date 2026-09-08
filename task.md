Build an Android app called "Squishy" — a video compressor app that fixes the flaws of an existing app called "Compressor":
1. Can only compress one video at a time
2. Compression breaks if the app is left/backgrounded
3. Progress bar stops updating correctly after ~20%
4. Compression dies when the screen turns off
5. App gets killed as soon as it's minimized — no multitasking
6. No way to sort the video list (by name/date/size/duration) to find the video you want

Root cause of 2/4/5: compression must run in an Android foreground service with a persistent notification (not a plain background thread/coroutine), so the OS doesn't kill it when the app isn't visible.

Architecture requirements:
- Kotlin, Jetpack Compose for UI.
- Use androidx.media3:media3-transformer for video compression/transcoding — it's Google's actively maintained transcoding API with progress listener support. Do NOT use FFmpegKit — it was discontinued/archived and shouldn't be used for a new project.
- A foreground Service (mediaProcessing type) drives compression, survives backgrounding/screen-off/minimizing, shows live progress in its notification, and supports a queue so multiple videos compress sequentially without the user needing to keep the app open.
- Video library screen lists device videos (via MediaStore) and supports sorting by name, date modified, size, and duration.
- Accurate progress (0-100%) reported to both the in-app UI and the notification for whichever video is currently compressing, plus overall queue progress.

Process:
1. Create a new private GitHub repo "squishy" under my account (gh is already authenticated) and push an initial Android Studio project scaffold.
2. Add a GitHub Actions workflow that runs `./gradlew lint testDebugUnitTest assembleDebug` on every PR.
3. Set branch protection on main requiring that CI check to pass, and enable auto-merge on the repo.
4. Create a PROJECT.md in the repo listing these 6 fixes as a backlog/checklist, and the architecture decisions above, so future work stays consistent.
5. Build this feature-by-feature: each fix/feature gets its own branch, PR, passing CI, and auto-merge — not one giant PR. Start with the scaffold + CI + empty app as PR #1, then the video library + sorting, then the foreground-service compression engine, then the queue, then progress reporting polish.
6. After each PR is opened, enable auto-merge on it (`gh pr merge --auto --squash`) and move to the next piece of work once it merges.