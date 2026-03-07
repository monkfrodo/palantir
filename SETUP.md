# Live Wallpaper

Wallpaper animado nativo para macOS — sem dependência de apps terceiros.

## O que faz

- **Menu bar app** — ícone de TV na barra de menu com galeria de wallpapers
- **Desktop animado** — vídeo em loop atrás de tudo, hardware accelerated
- **Lock screen animada** — injeta wallpapers no sistema de aerials do macOS (igual Wallux/Wallper)
- **Auto-start** — inicia com o Mac via LaunchAgent
- **Resiliente** — re-mostra o wallpaper após troca de espaço, wake, unlock e restart

## Setup numa máquina nova

```bash
# 1. O sync-tudo já clona o repo automaticamente

# 2. Copiar wallpapers via AirDrop ou pen drive para:
~/projetos/live-wallpaper/wallpapers/

# 3. Instalar
cd ~/projetos/live-wallpaper
./install.sh

# 4. Abrir a galeria pelo ícone de TV na menu bar
#    (isso sincroniza todos os wallpapers com o macOS)

# 5. Lock screen: System Settings > Wallpaper > Screen Saver...
#    Selecionar "Custom", rolar até a categoria "Live Wallpaper"
#    e escolher o wallpaper desejado. Fazer isso uma vez.
```

## Uso

- Clicar no ícone de TV na menu bar
- **Open Gallery** — janela com todos os wallpapers
- Hover num wallpaper mostra 3 opções:
  - **Both** — desktop + lock screen
  - **Desktop** — só desktop
  - **Lock** — só lock screen
- **Stop Wallpaper** — para o wallpaper ativo
- Adicionar novos vídeos (.mov/.mp4) em `~/projetos/live-wallpaper/wallpapers/` e clicar Refresh

## Como funciona

### Desktop
Janela borderless no nível do desktop com AVPlayer. Observa mudanças de espaço, wake e unlock para re-mostrar. Frame estático extraído como fallback para restart.

### Lock screen
Injeta os wallpapers no sistema nativo de aerials do macOS (mesmo mecanismo que Wallux/Wallper):
- Copia vídeos para `~/Library/Application Support/com.apple.wallpaper/aerials/videos/`
- Gera thumbnails em `~/Library/Application Support/com.apple.wallpaper/aerials/thumbnails/`
- Atualiza `entries.json` com categoria "Live Wallpaper"
- Cada wallpaper aparece como tile individual em System Settings > Wallpaper

## Notas

- Wallpapers ficam fora do git (muito grandes) — transferir via AirDrop entre máquinas
- Thumbnails demoram alguns segundos para gerar na primeira execução
- Usa ~0% CPU (hardware video decoding)
