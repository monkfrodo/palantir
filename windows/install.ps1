# Palantir — Live Wallpaper for Windows
# Install: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

$REPO = "monkfrodo/palantir"
$INSTALL_DIR = "$env:USERPROFILE\.palantir"
$REG_PATH = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$REG_NAME = "Palantir"

# ── Colors ────────────────────────────────────────────────────────
function Info  { param($msg) Write-Host "==> " -ForegroundColor Cyan -NoNewline; Write-Host $msg }
function Ok    { param($msg) Write-Host "==> " -ForegroundColor Green -NoNewline; Write-Host $msg }
function Warn  { param($msg) Write-Host "==> " -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Fail  { param($msg) Write-Host "==> " -ForegroundColor Red -NoNewline; Write-Host $msg; exit 1 }

Write-Host ""
Write-Host "       * P A L A N T I R *" -ForegroundColor Cyan
Write-Host ""
Write-Host "   Live Wallpapers para Windows"
Write-Host ""

# ── 1. Check Windows ─────────────────────────────────────────────
if ($env:OS -ne "Windows_NT") {
    Fail "Palantir for Windows funciona apenas no Windows."
}

# ── 2. Check .NET 8 Runtime ──────────────────────────────────────
Info "Verificando .NET 8 runtime..."

$dotnetOk = $false
try {
    $dotnetOutput = & dotnet --list-runtimes 2>$null
    if ($dotnetOutput -match "Microsoft\.NETCore\.App 8\.") {
        $dotnetOk = $true
    }
} catch {}

if (-not $dotnetOk) {
    Write-Host ""
    Warn ".NET 8 runtime nao encontrado."
    Write-Host ""
    Write-Host "   Baixe e instale o .NET 8 Desktop Runtime:"
    Write-Host "   https://dotnet.microsoft.com/en-us/download/dotnet/8.0" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   Depois de instalar, rode esse script de novo."
    Write-Host ""
    exit 0
}

Ok ".NET 8 runtime encontrado."

# ── 3. Check Git ─────────────────────────────────────────────────
try {
    $null = & git --version 2>$null
} catch {
    Fail "Git nao encontrado. Instale em https://git-scm.com/download/win"
}

# ── 4. Clone or update repo ──────────────────────────────────────
if (Test-Path "$INSTALL_DIR\.git") {
    Info "Atualizando Palantir..."
    & git -C "$INSTALL_DIR" pull --ff-only -q 2>$null
} else {
    Info "Baixando Palantir..."
    if (Test-Path $INSTALL_DIR) {
        Remove-Item -Recurse -Force $INSTALL_DIR
    }
    & git clone -q "https://github.com/$REPO.git" "$INSTALL_DIR"
}

Set-Location $INSTALL_DIR
if (-not (Test-Path "wallpapers")) { New-Item -ItemType Directory -Path "wallpapers" | Out-Null }

# ── 5. Download wallpapers from GitHub Release ───────────────────
Info "Verificando wallpapers..."

$existing = @(Get-ChildItem -Path "wallpapers" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -match '\.(mov|mp4|m4v)$' })

if ($existing.Count -eq 0) {
    Info "Baixando wallpapers da ultima release..."

    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases/latest" -UseBasicParsing
        $assets = $release.assets
    } catch {
        $assets = @()
    }

    if ($assets.Count -eq 0) {
        Warn "Nenhuma release encontrada. Adicione arquivos .mov/.mp4 em $INSTALL_DIR\wallpapers\"
    } else {
        $count = 0
        foreach ($asset in $assets) {
            $filename = [System.Uri]::UnescapeDataString($asset.name)
            $ext = [System.IO.Path]::GetExtension($filename).TrimStart('.').ToLower()

            if ($ext -match '^(mov|mp4|m4v)$') {
                # GitHub replaces spaces with dots in release asset names — restore them
                $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($filename)
                $cleanName = ($nameWithoutExt -replace '\.', ' ') + "." + $ext
                $destPath = "wallpapers\$cleanName"

                if (-not (Test-Path $destPath)) {
                    Write-Host "   Baixando: $cleanName"
                    $downloadUrl = $asset.browser_download_url
                    Invoke-WebRequest -Uri $downloadUrl -OutFile $destPath -UseBasicParsing
                    $count++
                }
            }
        }
        Ok "$count wallpaper(s) baixados."
    }
} else {
    Ok "$($existing.Count) wallpaper(s) ja presentes."
}

# ── 6. Build ─────────────────────────────────────────────────────
Info "Compilando..."

$publishDir = "$INSTALL_DIR\publish"
& dotnet publish "$INSTALL_DIR\windows\Palantir.csproj" -c Release -r win-x64 --self-contained -o "$publishDir" 2>&1 | Out-Null

if (-not (Test-Path "$publishDir\Palantir.exe")) {
    Fail "Falha na compilacao. Verifique o projeto e tente novamente."
}

Ok "Compilacao concluida."

# ── 7. Registry auto-start ───────────────────────────────────────
Info "Configurando auto-start..."

$exePath = "$publishDir\Palantir.exe"
Set-ItemProperty -Path $REG_PATH -Name $REG_NAME -Value "`"$exePath`""

Ok "Auto-start configurado no Registry."

# ── 8. Launch ─────────────────────────────────────────────────────
Info "Iniciando Palantir..."

# Kill old instances
Get-Process -Name "Palantir" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

Start-Process -FilePath $exePath

# ── 9. Done ──────────────────────────────────────────────────────
Write-Host ""
Ok "Palantir instalado!"
Write-Host ""
Write-Host "   Procura o icone na system tray (bandeja do sistema)."
Write-Host "   Wallpapers: $INSTALL_DIR\wallpapers\"
Write-Host "   Desinstalar: powershell -File `"$INSTALL_DIR\windows\uninstall.ps1`""
Write-Host ""
Write-Host "   Abre a galeria pelo system tray pra comecar." -ForegroundColor Cyan
Write-Host ""
