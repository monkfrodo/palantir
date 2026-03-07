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
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}==>${NC} $1"; }
ok()    { echo -e "${GREEN}==>${NC} $1"; }
warn()  { echo -e "${YELLOW}==>${NC} $1"; }
fail()  { echo -e "${RED}==>${NC} $1"; exit 1; }

echo ""
echo -e "${BOLD}${CYAN}"
echo "       ◆ P A L A N T Í R ◆"
echo -e "${NC}"
echo "   Live Wallpapers para macOS"
echo ""

# ── 1. Check macOS ──────────────────────────────────────────────
[[ "$(uname)" == "Darwin" ]] || fail "Palantir funciona apenas no macOS."

# ── 2. Check Xcode CLI Tools ───────────────────────────────────
if ! xcode-select -p &>/dev/null; then
    info "Instalando Xcode Command Line Tools (necessario pra compilar)..."
    xcode-select --install
    echo ""
    warn "Depois que o Xcode tools terminar de instalar, roda esse script de novo."
    exit 0
fi

# ── 3. Clone or update repo ────────────────────────────────────
if [ -d "$INSTALL_DIR/.git" ]; then
    info "Atualizando Palantir..."
    git -C "$INSTALL_DIR" pull --ff-only -q 2>/dev/null || true
else
    info "Baixando Palantir..."
    rm -rf "$INSTALL_DIR"
    git clone -q "https://github.com/$REPO.git" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"
mkdir -p wallpapers .frames

# ── 4. Download wallpapers from GitHub Release ─────────────────
info "Verificando wallpapers..."

EXISTING=$(ls wallpapers/*.mov wallpapers/*.mp4 2>/dev/null | wc -l | tr -d ' ')

if [ "$EXISTING" -eq 0 ]; then
    info "Baixando wallpapers da ultima release..."

    ASSETS=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" \
        | grep -o '"browser_download_url": *"[^"]*"' \
        | grep -oE 'https://[^"]+' || true)

    if [ -z "$ASSETS" ]; then
        warn "Nenhuma release encontrada. Adicione arquivos .mov/.mp4 em $INSTALL_DIR/wallpapers/"
    else
        COUNT=0
        for url in $ASSETS; do
            filename=$(basename "$url" | python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))")
            ext="${filename##*.}"
            ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

            if [[ "$ext_lower" == "mov" || "$ext_lower" == "mp4" || "$ext_lower" == "m4v" ]]; then
                # GitHub replaces spaces with dots in release asset names — restore them
                clean_name=$(echo "${filename%.*}" | sed 's/\./ /g')."$ext_lower"
                if [ ! -f "wallpapers/$clean_name" ]; then
                    echo "   Baixando: $clean_name"
                    curl -sL -o "wallpapers/$clean_name" "$url"
                    COUNT=$((COUNT + 1))
                fi
            fi
        done
        ok "$COUNT wallpaper(s) baixados."
    fi
else
    ok "$EXISTING wallpaper(s) ja presentes."
fi

# ── 5. Compile ─────────────────────────────────────────────────
info "Compilando..."

swiftc -o Palantir -parse-as-library src/App.swift \
    -framework AppKit -framework AVFoundation -framework CoreMedia \
    -framework SwiftUI -framework CoreGraphics 2>&1 | grep -v warning || true

# Screen saver
mkdir -p build/LoneKnightSaver.saver/Contents/MacOS build/LoneKnightSaver.saver/Contents/Resources

swiftc -emit-library -module-name LoneKnightSaver \
    -o build/LoneKnightSaver.saver/Contents/MacOS/LoneKnightSaver \
    src/LoneKnightSaver.swift \
    -framework ScreenSaver -framework AVFoundation -framework AppKit \
    -Xlinker -bundle 2>&1 | grep -v warning || true

cp screensaver/Info.plist build/LoneKnightSaver.saver/Contents/Info.plist

# Copy first wallpaper as screen saver default
if [ ! -f "build/LoneKnightSaver.saver/Contents/Resources/wallpaper.mov" ]; then
    FIRST=$(ls wallpapers/*.mov wallpapers/*.mp4 2>/dev/null | head -1)
    if [ -n "$FIRST" ]; then
        cp "$FIRST" build/LoneKnightSaver.saver/Contents/Resources/wallpaper.mov
    fi
fi

# Install screen saver
rm -rf "$HOME/Library/Screen Savers/LoneKnightSaver.saver"
cp -R build/LoneKnightSaver.saver "$HOME/Library/Screen Savers/"
codesign --force --deep --sign - "$HOME/Library/Screen Savers/LoneKnightSaver.saver" 2>/dev/null || true
killall legacyScreenSaver 2>/dev/null || true

# ── 6. LaunchAgent (auto-start) ────────────────────────────────
info "Configurando auto-start..."

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
ok "Palantir instalado!"
echo ""
echo "   Procura o icone de TV na barra de menu."
echo "   Wallpapers: $INSTALL_DIR/wallpapers/"
echo "   Desinstalar: ~/.palantir/uninstall.sh"
echo ""
echo -e "   ${CYAN}Abre a galeria pelo menu bar pra comecar.${NC}"
echo ""
