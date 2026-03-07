# Palantir — Uninstall (Windows)

$ErrorActionPreference = "SilentlyContinue"

$INSTALL_DIR = "$env:USERPROFILE\.palantir"
$REG_PATH = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$REG_NAME = "Palantir"

Write-Host ""
Write-Host "  * Palantir" -ForegroundColor Cyan -NoNewline
Write-Host " — Uninstall"
Write-Host ""

# Stop the app
Write-Host "==> " -ForegroundColor Cyan -NoNewline
Write-Host "Parando Palantir..."
Get-Process -Name "Palantir" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

# Remove Registry auto-start entry
Write-Host "==> " -ForegroundColor Cyan -NoNewline
Write-Host "Removendo auto-start do Registry..."
Remove-ItemProperty -Path $REG_PATH -Name $REG_NAME -ErrorAction SilentlyContinue

# Remove install directory
Write-Host "==> " -ForegroundColor Cyan -NoNewline
Write-Host "Removendo $INSTALL_DIR..."
if (Test-Path $INSTALL_DIR) {
    Remove-Item -Recurse -Force $INSTALL_DIR
}

Write-Host ""
Write-Host "==> " -ForegroundColor Green -NoNewline
Write-Host "Palantir desinstalado."
Write-Host "   Seu wallpaper voltou ao padrao do Windows."
Write-Host ""
