#!/bin/bash
# Live Wallpaper — install/update
# Uso: ./install.sh

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "Compilando Live Wallpaper..."
swiftc -o LiveWallpaper -parse-as-library App.swift \
    -framework AppKit -framework AVFoundation -framework CoreMedia -framework SwiftUI -framework CoreGraphics 2>&1 | grep -v warning || true

echo "Compilando Screen Saver..."
mkdir -p LoneKnightSaver.saver/Contents/MacOS LoneKnightSaver.saver/Contents/Resources
swiftc -emit-library -module-name LoneKnightSaver \
    -o LoneKnightSaver.saver/Contents/MacOS/LoneKnightSaver \
    LoneKnightSaver.swift \
    -framework ScreenSaver -framework AVFoundation -framework AppKit \
    -Xlinker -bundle 2>&1 | grep -v warning || true

# Copiar wallpaper ativo pro screen saver bundle
ACTIVE=$(defaults read com.apple.ScreenSaver moduleDict 2>/dev/null | grep -o 'path = ".*"' | head -1 || true)
if [ -f "$DIR/LoneKnightSaver.saver/Contents/Resources/wallpaper.mov" ]; then
    echo "Screen saver já tem wallpaper."
else
    FIRST=$(ls "$DIR/wallpapers/"*.mov "$DIR/wallpapers/"*.mp4 2>/dev/null | head -1)
    if [ -n "$FIRST" ]; then
        cp "$FIRST" "$DIR/LoneKnightSaver.saver/Contents/Resources/wallpaper.mov"
        echo "Wallpaper padrão copiado pro screen saver."
    fi
fi

# Instalar screen saver
rm -rf ~/Library/Screen\ Savers/LoneKnightSaver.saver
cp -R LoneKnightSaver.saver ~/Library/Screen\ Savers/
codesign --force --deep --sign - ~/Library/Screen\ Savers/LoneKnightSaver.saver 2>/dev/null
killall legacyScreenSaver 2>/dev/null || true

# LaunchAgent
PLIST=~/Library/LaunchAgents/com.imacke.livewallpaper.plist
cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.imacke.livewallpaper</string>
    <key>ProgramArguments</key>
    <array>
        <string>$DIR/LiveWallpaper</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo ""
echo "✓ Live Wallpaper instalado!"
echo "  Menu bar: ícone de TV"
echo "  Screen saver: Lone Knight Saver"
echo "  Auto-start: ativado"
