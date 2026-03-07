<p align="center">
  <br>
  <img src="https://img.shields.io/badge/macOS-14%2B-000?style=flat-square&logo=apple&logoColor=white" />
  <img src="https://img.shields.io/badge/CPU-~0%25-22c55e?style=flat-square" />
  <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" />
  <br><br>
  <strong>◆ &nbsp; P A L A N T Í R &nbsp; ◆</strong>
  <br><br>
  <em>Live wallpapers for macOS — native, lightweight, zero third-party apps.</em>
  <br>
  Hardware-decoded video at ~0% CPU. Desktop + lock screen.
  <br>
  Survives sleep, spaces, and restarts.
  <br><br>
</p>

---

## Install

### Homebrew (recommended)

Don't have Homebrew? Install it first:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then:

```bash
brew tap monkfrodo/palantir
brew install palantir
```

### One-liner (no Homebrew needed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/monkfrodo/palantir/main/install.sh)"
```

Downloads, compiles, and configures everything automatically.

---

## Usage

Look for the **📺 TV icon** in your menu bar.

Click it → **Open Gallery** → hover any wallpaper and pick:

| Button | What it does |
|---|---|
| **Both** | Desktop + lock screen |
| **Desktop** | Animated desktop wallpaper |
| **Lock** | Lock screen wallpaper |

Click **Stop Wallpaper** in the menu to stop.

### Add your own wallpapers

Drop any `.mov` or `.mp4` into `~/.palantir/wallpapers/` and hit **Refresh** in the gallery.

---

## Under the hood

| Feature | How |
|---|---|
| **Desktop** | Borderless window at desktop level, AVPlayer looping video |
| **Lock screen** | Injects into macOS native aerials system |
| **Auto-start** | LaunchAgent — starts with your Mac |
| **Multi-monitor** | One window per screen, all in sync |
| **Resilient** | Survives space switches, sleep, unlock, restart |

---

## Update

```bash
brew upgrade palantir
```

Or: `~/.palantir/install.sh`

## Uninstall

```bash
brew uninstall palantir
```

Or: `~/.palantir/uninstall.sh`

## Requirements

- macOS 14+ (Sonoma)
- Xcode Command Line Tools (installed automatically)

---

<p align="center">
  <em>"What do you see in the stone?"</em>
</p>
