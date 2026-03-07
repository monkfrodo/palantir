# Live Wallpaper

Wallpaper animado nativo para macOS — sem dependência de apps terceiros.

## O que faz

- **Menu bar app** — ícone de TV na barra de menu com galeria de wallpapers
- **Desktop animado** — vídeo em loop atrás de tudo, hardware accelerated
- **Lock screen** — screen saver customizado que toca o mesmo vídeo
- **Auto-start** — inicia com o Mac via LaunchAgent

## Setup numa máquina nova

```bash
# 1. O sync-tudo já clona o repo automaticamente

# 2. Copiar wallpapers via AirDrop ou pen drive para:
~/projetos/live-wallpaper/wallpapers/

# 3. Instalar
cd ~/projetos/live-wallpaper
./install.sh
```

## Uso

- Clicar no ícone de TV na menu bar
- **Open Gallery** → janela com todos os wallpapers
- Hover num wallpaper mostra 3 opções:
  - **Both** — desktop + lock screen
  - **Desktop** — só desktop
  - **Lock** — só lock screen
- **Stop Wallpaper** — para o wallpaper ativo
- Adicionar novos vídeos (.mov/.mp4) em `~/projetos/live-wallpaper/wallpapers/` e clicar Refresh

## Notas

- Wallpapers ficam fora do git (muito grandes) — transferir manualmente entre máquinas
- Screen saver aparece em Ajustes > Protetor de Tela como "Lone Knight Saver"
- Usa ~0% CPU (hardware video decoding)
