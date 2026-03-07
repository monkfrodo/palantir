#!/bin/bash
# Palantir — Live Wallpaper for macOS
# Install: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/monkfrodo/palantir/main/install.sh)"

set -e

REPO="monkfrodo/palantir"
INSTALL_DIR="$HOME/.palantir"
PLIST="$HOME/Library/LaunchAgents/com.palantir.livewallpaper.plist"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}==>${NC} $1"; }
ok()    { echo -e "${GREEN}==>${NC} $1"; }
warn()  { echo -e "${YELLOW}==>${NC} $1"; }
fail()  { echo -e "${RED}==>${NC} $1"; exit 1; }

echo ""
echo -e "${CYAN}  ◆ Palantir${NC} — Live Wallpaper for macOS"
echo ""

# ── 1. Check macOS ──────────────────────────────────────────────
[[ "$(uname)" == "Darwin" ]] || fail "Palantir only works on macOS."

# ── 2. Check Xcode CLI Tools ───────────────────────────────────
if ! xcode-select -p &>/dev/null; then
    info "Installing Xcode Command Line Tools (required to compile)..."
    xcode-select --install
    echo ""
    warn "After Xcode tools finish installing, run this script again."
    exit 0
fi

# ── 3. Clone or update repo ────────────────────────────────────
if [ -d "$INSTALL_DIR/.git" ]; then
    info "Updating Palantir..."
    git -C "$INSTALL_DIR" pull --ff-only -q 2>/dev/null || true
else
    info "Cloning Palantir..."
    rm -rf "$INSTALL_DIR"
    git clone -q "https://github.com/$REPO.git" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"
mkdir -p wallpapers .frames

# ── 4. Download wallpapers from GitHub Release ─────────────────
info "Checking for wallpapers..."

EXISTING=$(ls wallpapers/*.mov wallpapers/*.mp4 2>/dev/null | wc -l | tr -d ' ')

if [ "$EXISTING" -eq 0 ]; then
    info "Downloading wallpapers from latest release..."

    # Get asset URLs from latest release
    ASSETS=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep -o '"browser_download_url": *"[^"]*"' \
        | grep -oE 'https://[^"]+' || true)

    if [ -z "$ASSETS" ]; then
        warn "No release found. Add .mov/.mp4 files to $INSTALL_DIR/wallpapers/ manually."
    else
        COUNT=0
        for url in $ASSETS; do
            filename=$(basename "$url" | python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
            ext="${filename##*.}"
            ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

            if [[ "$ext_lower" == "mov" || "$ext_lower" == "mp4" || "$ext_lower" == "m4v" ]]; then
                if [ ! -f "wallpapers/$filename" ]; then
                    echo "   Downloading: $filename"
                    curl -sL -o "wallpapers/$filename" "$url"
                    COUNT=$((COUNT + 1))
                fi
            fi
        done
        ok "Downloaded $COUNT wallpaper(s)."
    fi
else
    ok "$EXISTING wallpaper(s) already present."
fi

# ── 5. Compile ─────────────────────────────────────────────────
info "Compiling Palantir..."

swiftc -o Palantir -parse-as-library App.swift \
    -framework AppKit -framework AVFoundation -framework CoreMedia \
    -framework SwiftUI -framework CoreGraphics 2>&1 | grep -v warning || true

# Screen saver
mkdir -p LoneKnightSaver.saver/Contents/MacOS LoneKnightSaver.saver/Contents/Resources

swiftc -emit-library -module-name LoneKnightSaver \
    -o LoneKnightSaver.saver/Contents/MacOS/LoneKnightSaver \
    LoneKnightSaver.swift \
    -framework ScreenSaver -framework AVFoundation -framework AppKit \
    -Xlinker -bundle 2>&1 | grep -v warning || true

# Copy first wallpaper as screen saver default
if [ ! -f "LoneKnightSaver.saver/Contents/Resources/wallpaper.mov" ]; then
    FIRST=$(ls wallpapers/*.mov wallpapers/*.mp4 2>/dev/null | head -1)
    if [ -n "$FIRST" ]; then
        cp "$FIRST" LoneKnightSaver.saver/Contents/Resources/wallpaper.mov
    fi
fi

# Install screen saver
rm -rf "$HOME/Library/Screen Savers/LoneKnightSaver.saver"
cp -R LoneKnightSaver.saver "$HOME/Library/Screen Savers/"
codesign --force --deep --sign - "$HOME/Library/Screen Savers/LoneKnightSaver.saver" 2>/dev/null || true
killall legacyScreenSaver 2>/dev/null || true

# ── 6. LaunchAgent (auto-start) ────────────────────────────────
info "Setting up auto-start..."

# Stop old versions
launchctl unload "$PLIST" 2>/dev/null || true
launchctl unload "$HOME/Library/LaunchAgents/com.imacke.livewallpaper.plist" 2>/dev/null || true

cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.palantir.livewallpaper</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/Palantir</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

launchctl load "$PLIST"

# ── 7. Done ────────────────────────────────────────────────────
echo ""
ok "Palantir installed!"
echo ""
echo "   Menu bar: look for the TV icon"
echo "   Wallpapers: $INSTALL_DIR/wallpapers/"
echo "   Uninstall: ~/.palantir/uninstall.sh"
echo ""
echo -e "   ${CYAN}Open the gallery from the menu bar to get started.${NC}"
echo ""
