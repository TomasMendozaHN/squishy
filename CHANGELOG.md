# Changelog

All notable changes to Squishy. Versions follow [Semantic Versioning](https://semver.org/);
each version has a matching git tag and a GitHub Release with the APK.

## [2.0.1] - 2026-11-01

### Added
- **Play and share compressed videos right from the app.** Finished videos on the Squish
  screen, in History and in the file browser have **WhatsApp** (always first; opens the
  contact picker), **Gmail** (opens a new email with the video; Gmail sends files over 25 MB
  as a Google Drive link), **Play** (system video player) and **Share with…** buttons.
  Tapping a finished video plays it.

### Fixed
- **`ERROR_CODE_MUXING_TIMEOUT: Muxer Error` when compressing several videos at once.**
  Media3 aborted a job when its muxer got no frames for about 10 s, which happens when
  parallel jobs fight over the phone's hardware encoder or the phone throttles with the screen off.
  The watchdog now allows 60 s (single job) or 3 min (parallel).
- Jobs that fail with an encoder, decoder or muxer error are now **retried once
  automatically, on their own** (nothing else runs in parallel during the retry). The
  original is still only deleted after a verified success.

### Changed
- **Default is now 1 video at a time** (the most reliable). 2 or 3 at once is still available in Settings.

## [2.0.0] - 2026-11-01

Complete rewrite in Flutter, with a new native compression engine. Requires **Android 16+**.

### Added
- **Background engine that doesn't get killed:** a foreground service (specialUse type, no
  daily time limit), a wake lock, and a queue saved to disk so it resumes after a restart.
  Onboarding asks for unrestricted battery use, plus Autostart and "No restrictions" on Xiaomi/HyperOS.
- **Keep screen on** toggle while videos are compressing.
- **Folder browser** for the whole phone (and SD card), with shortcuts to Camera, Screen
  recordings, Movies, Downloads, WhatsApp and Telegram.
- **Sorting** by name, date, size, duration or resolution, ascending or descending.
- **Four file views:** grid, big cards, list, compact.
- **History log** of squished and failed videos with the reason for each failure, plus a
  **Stats** tab (space saved, average reduction, charts).
- **Automatic deletion of originals**, only after the compressed file is verified (it plays,
  has the right length and is smaller than the original).
- **Output folder:** `compressed/` next to each original by default, or any folder you pick or create.
- **Quality presets** 360p / 480p (default) / 720p / 1080p with the **expected file size**
  for every option, H.265 or H.264, and no upscaling.
- **Parallel jobs:** 1, 2 (default) or 3 videos at the same time.
- **Cut & join editor:** mark as many segments as you like, reorder them, preview them,
  and export them as one video.
- **Animated progress** in four styles: water tank, liquid orb, glow ring, equalizer.
- **Personalization tab** with live preview cards for 6 themes, progress styles, chart
  styles, file views, fonts and corner shapes, plus a reduce-motion switch.
- Animated splash, welcome tour, and the new Squishy mascot icon (adaptive and themed icon).

### Changed
- The v1 Kotlin/Compose app is replaced. You'll need to uninstall v1 before installing
  v2, because it's signed with a different key.

### Fixed
- The crash when starting compression on Android 16 (`InvalidForegroundServiceTypeException`).

## [1.2.0] - 2026-09-11
- Brand theme (Quicksand font, purple/teal palette) and video list refresh (Kotlin version).

## [1.1.0] - 2026-09-11
- Folder filter, grid view with thumbnails, delete-original option, compression history.

## [1.0.3] - 2026-09-10
- Bypass ServiceCompat when starting the foreground service.

## [1.0.0] - [1.0.2] - 2026-09-10
- First Kotlin release: MediaStore library with sorting, queue, quality options, crash log.
