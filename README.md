<p align="center">
  <img src="docs/logo.png" width="140" alt="Squishy logo">
</p>

<h1 align="center">Squishy</h1>

<p align="center">
  <b>Big videos in. Tiny videos out.</b><br>
  A video compressor for Android 16+ that keeps going in the background,
  cleans up after itself, and looks good doing it.
</p>

<p align="center">
  <img alt="Android 16+" src="https://img.shields.io/badge/Android-16%2B-3DDC84?logo=android&logoColor=white">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white">
  <img alt="Vibecoded" src="https://img.shields.io/badge/vibecoded-with%20Claude-8B5CF6">
</p>

> **Vibecoded.** Squishy was designed and written by an AI coding assistant
> (Claude, by Anthropic), directed by me (Tomas): I described what I wanted,
> made the decisions, and tested it; the AI wrote the code.

<p align="center">
  <img src="docs/screenshots/05_squishing.png" width="230" alt="Squishing in progress">
  <img src="docs/screenshots/03_files.png" width="230" alt="File browser">
  <img src="docs/screenshots/04_compress.png" width="230" alt="Choosing quality">
</p>

## What it does

- **Compresses whole folders.** Pick one video or fifty, then choose 360p, **480p** (default),
  720p or 1080p. Every option shows the **expected file size** and how much you'll save
  before you start.
- **Keeps working in the background.** Squishy runs as a foreground service with a wake lock.
  It keeps going when you switch apps, turn the screen off or swipe it out of Recents. If
  Android ever kills it, it resumes the queue by itself.
- **Keeps the screen on if you want.** One tap on the progress screen keeps the display awake
  while it works.
- **Deletes originals for you, safely.** An original is removed only after the new file
  has been checked: it plays, has the right length, and is actually smaller. If anything
  looks wrong, the original stays and the job is logged as failed with the reason.
- **Play & share instantly.** Tap a finished video to play it, or send it with one tap:
  **WhatsApp** (opens the contact picker), **Gmail** (new email with the video attached;
  Gmail turns files over 25 MB into a Drive link) or any other app.
- **Saves where you want.** By default each video goes into a `compressed` folder next to
  the original. You can also pick (or create) any other folder.
- **Runs several videos at once, or one after another.** 1 (default, the most reliable),
  2 or 3 videos at the same time. If one fails because the phone's encoder was overloaded,
  it retries automatically on its own.
- **Cuts & joins.** Mark as many segments of a video as you like, reorder them, preview them,
  and Squishy joins them into one clean file. The original is kept.
- **Squishes your NAS / Plex library in place.** Point it at a shared folder (SMB) and it finds
  every video in every subfolder and compresses each one *where it is*, under the *exact same
  file name*, so Plex never sees anything missing. See [NAS / Plex](#nas--plex) below.
- **Browses your whole phone.** A real folder browser with shortcuts to Camera, Screen
  recordings, Movies, Downloads, WhatsApp and Telegram.
- **Sorts however you like:** by name, date, size, duration or resolution, ascending or descending.
- **Shows videos however you like:** grid, big cards, list, or compact.
- **Keeps a history.** Every squished and failed video is logged, with stats and charts of the
  space you've saved.
- **Lets you change the look.** Pick a theme, progress animation, chart style, file view,
  font and corner shape, each shown as a live preview card.

## Screenshots

| Welcome | Permissions | Squishing | Done |
|:---:|:---:|:---:|:---:|
| <img src="docs/screenshots/01_welcome.png" width="200"> | <img src="docs/screenshots/02_permissions.png" width="200"> | <img src="docs/screenshots/05_squishing.png" width="200"> | <img src="docs/screenshots/07_done.png" width="200"> |

| Cut & join | Play & share | Background notification | Settings |
|:---:|:---:|:---:|:---:|
| <img src="docs/screenshots/08_cut_editor.png" width="200"> | <img src="docs/screenshots/18_share.png" width="200"> | <img src="docs/screenshots/06_notification.png" width="200"> | <img src="docs/screenshots/14_settings.png" width="200"> |

**Personalization:** themes, progress animations and chart styles, each previewed live.

| Themes | Progress animations | Chart styles | Midnight Violet theme |
|:---:|:---:|:---:|:---:|
| <img src="docs/screenshots/10_style_themes.png" width="200"> | <img src="docs/screenshots/11_style_progress.png" width="200"> | <img src="docs/screenshots/12_style_charts.png" width="200"> | <img src="docs/screenshots/13_midnight_violet.png" width="200"> |

## Install

1. Download the latest `Squishy-vX.Y.Z.apk` from **[Releases](../../releases)**.
2. Open it on your phone and allow installing from that source when Android asks.
3. Open Squishy and follow the welcome tour. It asks for:
   - **All files access** (required) to browse folders and replace originals.
   - **Notifications** to show progress while it works in the background.
   - **Unrestricted battery** so Android doesn't pause long batches.

> Upgrading from Squishy 1.x? Uninstall the old version first. 2.0 is a new app signed with a new key.

### Xiaomi / Redmi / POCO (HyperOS, MIUI)

Xiaomi phones are very aggressive about closing background apps. On these phones the
welcome screen shows two extra buttons. Use both:

1. **Autostart** → turn Squishy **on**.
2. **Battery saver** → choose **No restrictions**.
3. Optional but recommended: open Recents and **lock** Squishy (pull its card down or tap the lock).

You can come back to these any time in **Settings → Background reliability**.

## How to use

1. **Files** tab: browse to a folder (or tap a shortcut). Tap a video for options, or
   long-press / **Select all** to pick several.
2. Tap **Squish**, choose the quality (the expected size is shown), and tap **Start squishing**.
3. Watch the **Squish** tab fill up, or just leave. A notification shows progress, and you
   get another one when the batch is done.
4. Tap a finished video to play it, or use the **WhatsApp** / **Gmail** buttons under it to send it.
5. To keep only parts of a video, tap it and choose **Cut segments**. Drag the slider,
   tap **Add segment**, repeat, then **Cut & join**.
6. **History** shows what worked, what failed and why. **Style** changes the look.

### Good to know

- Output files are MP4 (H.265 by default, or H.264 for maximum compatibility).
- Squishy never upscales: a 360p video stays 360p even if you choose 1080p.
- If a compressed file wouldn't be smaller than the original (some videos are already small),
  Squishy keeps the original and logs it as "No size gain".
- HDR phone videos are converted to standard colors so they play everywhere.
- Everything happens on your phone. Squishy never uploads your videos. The only internet
  access is to download the fonts.

## NAS / Plex

<p align="center">
  <img src="docs/screenshots/15_nas_libraries.png" width="230" alt="NAS libraries with stats">
  <img src="docs/screenshots/16_nas_done.png" width="230" alt="Finished NAS run">
  <img src="docs/screenshots/17_nas_stats.png" width="230" alt="NAS savings in History">
</p>

1. **Files → network icon (top right) → Add NAS.** Enter the address (e.g. `192.168.1.20`), the
   shared folder name (e.g. `media`) and your login, then tap **Test**. The password is stored
   encrypted on the phone.
2. Open it. The top-level folders show up as **libraries** (e.g. `MOVIES`, `TV SHOWS`), each with
   its own quality: **Movies 1080p and TV 720p by default**, changeable per library.
3. Tap **Squish everything**, or open a folder and tap **Squish this folder**. Every video in it
   and in all its subfolders is processed, one at a time.

For each file, Squishy:

- compresses **only the video picture**, on your phone's hardware encoder, reading straight from
  the NAS (nothing big is copied to the phone first)
- **copies everything else untouched**: every audio track and language, every subtitle track
  (text and image), chapters, fonts, default/forced flags. DTS/TrueHD audio is fine because it
  isn't decoded. `.mkv` stays `.mkv`, `.mp4` stays `.mp4`
- **checks the result** (same length, same number of audio and subtitle tracks, the planned
  resolution, actually smaller) before touching the NAS
- **swaps it in safely**: uploads it as a hidden temp file, moves the original aside, renames the
  new file to the **exact original name**, and only then deletes the original. If anything goes
  wrong, even a power cut halfway through, the original is put back
- **skips** files it already squished, and files that are already small enough (no point
  re-encoding them)

**Stats are kept on the NAS itself** (`.squishy/ledger.json`): total GB saved for that NAS and,
per library (TV SHOWS, MOVIES…), the number of files squished, GB saved, plus files skipped or
failed with the reason. They survive reinstalls and show up in **History → Stats**.

Good to know:
- Keep the phone **charging and on Wi-Fi**. A big library takes hours (roughly real-time or
  faster per movie, plus transfer time). You can stop at any time and **Resume** later from the
  same file. Squishy also picks up by itself after a crash or reboot.
- The phone needs free space for one compressed file at a time (Squishy checks before starting
  each file).
- Supported containers: `.mkv`, `.mp4`, `.m4v`, `.mov`. Others (`.avi`, `.ts`, …) are skipped and listed.
- Plex picks up the smaller files on its next library scan. Nothing gets renamed or moved.

## Under the hood

- **Flutter** UI with **FlexColorScheme** theming and **flutter_animate** motion. The
  progress animations are custom-painted.
- A **native Kotlin engine** using **Media3 Transformer** (hardware encoders, clipping and
  joining), driven by a `specialUse` foreground service with a saved queue.
- NAS: **smbj** (SMB 2/3) with a small local HTTP bridge so Media3 and **FFmpeg** (LGPL build,
  used only to rebuild the file with stream copy) can read and seek in files on the share.
- Details and design decisions: [PROJECT.md](PROJECT.md). Version history: [CHANGELOG.md](CHANGELOG.md).

## Building

Requires Flutter 3.47+, JDK 17 and the Android SDK (platform 36).

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Release builds are signed with the key described in `android/key.properties`, which is
gitignored and kept outside the repo. Without that file the build falls back to the debug key.

## Credits

- The videos in the screenshots are open-movie clips: *Big Buck Bunny* and *Sintel*
  (© Blender Foundation, CC BY 3.0) and *Jellyfish* (test footage by jell.yfish.us),
  via test-videos.co.uk.
- Squishy the mascot was drawn in code, like everything else here.
- Open-source libraries: [FFmpeg](https://ffmpeg.org) (LGPL v3, unmodified shared libraries via the
  community [FFmpegKit fork](https://github.com/ffmpegkit-maintained/ffmpeg)),
  [smbj](https://github.com/hierynomus/smbj) (Apache 2.0), [Bouncy Castle](https://www.bouncycastle.org)
  (MIT), [AndroidX Media3](https://developer.android.com/media/media3) (Apache 2.0) and the Flutter
  packages listed in `pubspec.yaml`.
