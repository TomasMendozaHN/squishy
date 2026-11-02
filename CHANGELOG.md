# Changelog

All notable changes to Squishy. Versions follow [Semantic Versioning](https://semver.org/);
each version has a matching git tag and a GitHub Release with the APK.

## [2.1.3] - 2026-11-02

### Fixed
- **A video that always gets stuck at the same spot** (seen at 35:17 of a 1:46:56 video, also
  with the app open and the screen on). The retry now decodes the video with the phone's
  **software decoder** instead of the hardware one, so it takes a different path past the
  spot where the hardware decoder hangs. It's slower, but it only runs on the retry.

### Added
- **Scan of the stuck spot.** When a video fails for good, Squishy reads about 25 seconds
  around the point where it stopped with FFmpeg's own decoder. It adds what it finds to
  **Send details**: damaged frames, a resolution change in the middle of the video,
  timestamp jumps, and where the keyframes are.
- `style.md`: Squishy's design philosophy (tokens, colors, components, motion, copy) as a
  guide other apps can follow.

### Changed
- Codec error messages no longer include Media3's full codec configuration dump.

## [2.1.2] - 2026-11-02

### Fixed
- **Healthy videos killed with `ERROR_CODE_MUXING_TIMEOUT` or "Encoder stalled".** Xiaomi
  (HyperOS/MIUI) and some other phones pause background apps for minutes at a time. As soon as
  Squishy was let go again, Media3's muxer timer and the stall detector both saw the long gap and
  killed the job, even though nothing was wrong with the video. Confirmed on the emulator: a
  90-second pause made 2.1.1 abort the export the instant the app resumed. Now:
  - Media3's muxer timer is off. Squishy's own stall detector notices when the app was paused
    and doesn't count that time
  - after a long pause the phone's codec service can drop its buffers, leaving the encoder dead
    for good (seen on the emulator after a 4-minute pause). If nothing moves within 45 s of
    the app resuming, that video simply starts over (up to 3 times, without using up its retry)
  - the stall detector also treats a growing output file as progress, so long movies (where 1%
    can take minutes) aren't mistaken for stuck
  - a real hang is detected after 3 minutes on the first try (it was 10)
- **The automatic retry is now a "safe mode":** the video is encoded on its own and FFmpeg adds
  the audio afterwards (re-encoded to AAC, gaps filled with silence). A broken or oddly timed
  audio track can't hold up the video anymore.

### Added
- Failure reasons say **where** it got stuck (e.g. `at 37% (41:10 of 1:51:00)`) and, if Android
  paused Squishy, how often and for how long, with a pointer to the battery setting to change.
- **Send details** now includes the last codec/muxer log lines.

## [2.1.1] - 2026-11-01

### Added
- **NAS: "Pick videos · biggest first".** Scans the folder and **all its subfolders** and lists
  every video sorted by size, with its library, quality and status (already squished, or
  skipped/failed before and why). Tick any videos and squish just those, in place.
- **"Send details"** on failed entries in History: shares a short report (app version, phone,
  file, reason, video format) by WhatsApp, email, etc.

### Fixed
- **`ERROR_CODE_MUXING_TIMEOUT` still happening on some phones, even when retried alone.**
  The automatic retry now:
  - turns off Media3's fixed muxer timer and uses Squishy's own stall detector instead, which
    only gives up if progress hasn't moved for 10 minutes (slow but working encodes are no
    longer killed)
  - uses H.264 if the first attempt was H.265 (some H.265 encoders stall)
- Failure reasons now include the source video's format and the encoder used, e.g.
  `[3840×2160 HEVC HDR10 60fps → 854×480 H.264]`.

## [2.1.0] - 2026-11-01

### Added
- **NAS / Plex mode.** Add an SMB share (address, share, login; the password is stored
  encrypted with the Android Keystore), pick a folder, and Squishy compresses every video in
  it and in all subfolders **in place, under the exact same file name**.
  - Only the video track is re-encoded (hardware encoder). **Every audio track, subtitle track,
    chapter, attachment and language/default/forced tag is copied untouched** (FFmpeg stream
    copy). MKV stays MKV, MP4 stays MP4. DTS/TrueHD/Atmos audio is kept as-is.
  - **Quality per library**: top-level folders (e.g. MOVIES, TV SHOWS) each get their own
    quality. Default is Movies 1080p and TV 720p.
  - **Safe swap**: upload as a hidden temp file, move the original aside, rename the new file
    into place, then delete the original. Interrupted swaps are repaired on the next run, and
    the original is restored if the new file never made it.
  - **Verification before replacing**: same length, same number of audio and subtitle tracks,
    the planned resolution (no silent encoder fallbacks) and a real size reduction.
  - **Stats stored on the NAS** (`.squishy/ledger.json`): total saved per NAS and files, GB saved,
    skipped and failed per library. Shown on the NAS screen and in History → Stats.
  - Skips files it already squished and files that are already near the target bitrate.
  - Runs in the foreground service (same "never killed" protection), keeps Wi-Fi awake,
    retries a file up to 3 times on network errors, can be stopped and **resumed**, and
    resumes by itself after a crash.
- NAS button in Files, a NAS card on the Squish screen, NAS entries in History.

### Changed
- APK is larger (about 53 MB for arm64) because it now includes FFmpeg and an SMB client.

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
