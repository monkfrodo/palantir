#!/bin/bash
# Palantir — Uninstall

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="$HOME/.palantir"
PLIST="$HOME/Library/LaunchAgents/com.palantir.livewallpaper.plist"

echo ""
echo -e "${CYAN}  ◆ Palantir${NC} — Uninstall"
echo ""

# Stop the app
killall Palantir 2>/dev/null || true

# Remove LaunchAgent
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"

# Remove screen saver
rm -rf "$HOME/Library/Screen Savers/LoneKnightSaver.saver"

# Remove aerials injected by Palantir
rm -rf "$HOME/Library/Application Support/com.apple.wallpaper/aerials"
killall WallpaperAerialsExtension 2>/dev/null || true

# Remove install directory
rm -rf "$INSTALL_DIR"

echo -e "${GREEN}==>${NC} Palantir uninstalled."
echo "   Your desktop wallpaper has been reset to default."
echo ""
