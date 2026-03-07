@echo off
:: Palantir — Live Wallpaper for Windows
:: This wrapper runs the PowerShell installer for users who double-click.
powershell -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
