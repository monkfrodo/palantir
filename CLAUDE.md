# Palantir

## O que é
Live wallpapers nativos para macOS. App de menu bar com galeria, desktop animado e lock screen.

## Stack
- Swift / macOS nativo
- AVPlayer + AVFoundation
- LaunchAgent (auto-start)
- Sistema de aerials do macOS (lock screen)

## Distribuição
- Homebrew: `brew tap monkfrodo/palantir && brew install palantir`
- One-liner: `curl -fsSL ... | bash` (install.sh)

## Estrutura
```
src/
  App.swift              ← menu bar app + galeria
  LoneKnightSaver.swift  ← screen saver
screensaver/             ← bundle do screen saver
install.sh               ← compilação + instalação automática
uninstall.sh             ← remoção completa
```

## Repositórios relacionados
- Homebrew tap: github.com/monkfrodo/homebrew-palantir
- Dev local: ~/projetos/live-wallpaper

## Notas
- README.md é público e em inglês (voltado para usuários)
- Requer macOS 14+ (Sonoma)
- Wallpapers do usuário ficam em `~/.palantir/wallpapers/`
- Versão atual: v1.0 (tag usada pela fórmula Homebrew)

## Git
- Branch: main
- Commits: conventional commits em inglês
