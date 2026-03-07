# Palantir

Live wallpapers for macOS — native, lightweight, no third-party apps.

## Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/monkfrodo/palantir/main/install.sh)"
```

That's it. The script will:
- Clone the repo to `~/.palantir/`
- Download wallpapers from the latest release
- Compile the app
- Set up auto-start

## Usage

- Click the **TV icon** in the menu bar
- **Open Gallery** — browse all wallpapers
- Hover a wallpaper and choose:
  - **Both** — desktop + lock screen
  - **Desktop** — animated desktop only
  - **Lock** — lock screen only
- **Stop Wallpaper** — stop the active wallpaper
- Add your own `.mov`/`.mp4` files to `~/.palantir/wallpapers/` and hit Refresh

## How it works

- **Desktop**: borderless window at desktop level with hardware-accelerated video playback (AVPlayer)
- **Lock screen**: injects wallpapers into macOS native aerials system (same approach as Wallux/Wallper)
- **~0% CPU** thanks to hardware video decoding
- Survives space changes, wake, unlock, and restarts

## Update

```bash
~/.palantir/install.sh
```

## Uninstall

```bash
~/.palantir/uninstall.sh
```

## Requirements

- macOS 14+ (Sonoma or later)
- Xcode Command Line Tools (installed automatically if missing)
