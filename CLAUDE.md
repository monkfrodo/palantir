# Palantir

## O que e

App de live wallpapers nativos para macOS e Windows. Roda como menu bar app (macOS) ou system tray app (Windows), com galeria visual para selecionar wallpapers animados no desktop e lock screen. Wallpapers sao videos em loop com decodificacao hardware (~0% CPU). Repositorio publico no GitHub.

## Stack

### macOS
- **Linguagem:** Swift
- **Frameworks:** AppKit, SwiftUI, AVFoundation, CoreMedia, UserNotifications
- **Compilacao:** `swiftc` direto (sem Xcode project)
- **Auto-start:** LaunchAgent (`com.palantir.livewallpaper`)
- **Lock screen:** Injecao no sistema de aerials do macOS (entries.json)
- **Screen saver:** Bundle `.saver` com ScreenSaver framework

### Windows
- **Linguagem:** C# (.NET 8, WPF)
- **Frameworks:** WPF (MediaElement), System.Windows.Forms (multi-monitor), Win32 P/Invoke
- **Tecnica de wallpaper:** WorkerW injection hack (embeds window behind desktop icons)
- **Auto-start:** Registry `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
- **Build:** `dotnet publish` — single-file self-contained exe
- **CI:** GitHub Actions (`build-windows.yml`) compila e anexa .exe a releases
- **Dependencia NuGet:** `Hardcodet.NotifyIcon.Wpf` (system tray)

### Distribuicao
- **Homebrew:** `brew tap monkfrodo/palantir && brew install palantir`
- **One-liner macOS:** `curl -fsSL .../install.sh | bash`
- **Windows:** Download do Palantir.exe da release ou `install.ps1`

## Como usar

```bash
# macOS — instalar via Homebrew
brew tap monkfrodo/palantir && brew install palantir

# macOS — instalar via one-liner
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/monkfrodo/palantir/main/install.sh)"

# Desinstalar macOS
~/.palantir/uninstall.sh

# Windows — instalar
powershell -ExecutionPolicy Bypass -File install.ps1

# Desinstalar Windows
powershell -File ~/.palantir/windows/uninstall.ps1
```

Apos instalar, procurar o icone de TV na menu bar (macOS) ou system tray (Windows). Clicar > Open Gallery > hover no wallpaper > escolher Desktop, Lock ou Both.

## Estrutura de Arquivos

```
palantir/
├── src/
│   ├── App.swift                  # App principal macOS: entry point (@main),
│   │                              # AppDelegate (menu bar, galeria),
│   │                              # WallpaperManager (AVPlayer, aerials sync,
│   │                              # workspace observers, frame extraction),
│   │                              # WallpaperItem (model),
│   │                              # GalleryView + WallpaperCard (SwiftUI),
│   │                              # WallpaperUpdater (auto-update via GitHub API)
│   └── LoneKnightSaver.swift      # Screen saver (.saver bundle) — AVPlayer
│                                   # em loop, resolve video de ~/.palantir/
├── screensaver/
│   └── Info.plist                  # Bundle config do screen saver
│                                   # (com.imacke.LoneKnightSaver)
├── windows/
│   ├── App.xaml / App.xaml.cs      # Entry point Windows — init dirs,
│   │                               # download wallpapers, auto-start registry
│   ├── Palantir.csproj             # .NET 8 WPF project (win-x64, self-contained)
│   ├── TrayIconManager.cs          # System tray icon + context menu + galeria
│   ├── Core/
│   │   ├── WallpaperManager.cs     # Playback: MediaElement por monitor,
│   │   │                           # WorkerW embedding, lock screen via registry,
│   │   │                           # settings persistence (JSON)
│   │   ├── WallpaperItem.cs        # Model + thumbnail generation (MediaPlayer
│   │   │                           # em STA thread) + frame extraction
│   │   ├── WorkerWHack.cs          # Win32 P/Invoke: FindWindow, SendMessage
│   │   │                           # 0x052C, SetParent, WorkerW enumeration
│   │   └── AutoUpdater.cs          # Checa GitHub releases a cada 6h,
│   │                               # baixa novos wallpapers automaticamente
│   ├── Views/
│   │   ├── GalleryWindow.xaml/.cs  # Janela de galeria WPF (grid de cards)
│   │   └── WallpaperCard.xaml/.cs  # Card individual com thumbnail e acoes
│   ├── install.ps1                 # Instalador Windows (clone, build, registry)
│   ├── install.bat                 # Wrapper para install.ps1 (double-click)
│   └── uninstall.ps1               # Desinstalador Windows
├── install.sh                      # Instalador macOS: clone repo, baixa
│                                   # wallpapers da release, compila Swift,
│                                   # instala screen saver, cria LaunchAgent
├── uninstall.sh                    # Desinstalador macOS: para app, remove
│                                   # LaunchAgent, screen saver, aerials, ~/.palantir
├── .github/workflows/
│   └── build-windows.yml           # CI: compila Palantir.exe e anexa a releases
├── .gitignore                      # Ignora binarios, wallpapers, .frames, .DS_Store
├── README.md                       # Documentacao publica em ingles (voltada para usuarios)
└── CLAUDE.md                       # Este arquivo
```

## Regras de Desenvolvimento

### FAZER
- Commits em ingles, conventional commits (feat:, fix:, refactor:)
- README.md e em ingles (repo publico, voltado para usuarios)
- Testar em macOS antes de push (compilacao + execucao)
- Manter compatibilidade macOS 14+ (Sonoma)
- Manter compatibilidade Windows 10/11 (.NET 8)
- Auto-update: wallpapers novos sao baixados de GitHub releases
- Formatos de video suportados: .mov, .mp4, .m4v
- Diretorio de instalacao: `~/.palantir/` (ambas plataformas)

### NAO FAZER
- Nunca commitar wallpapers (arquivos grandes, vao via GitHub Releases)
- Nunca incluir `Co-Authored-By` nos commits
- Nunca quebrar o `install.sh` — e o entry point para usuarios
- Nunca mudar a tag `v1.0` sem atualizar `homebrew-palantir/Formula/palantir.rb`
- Nunca adicionar dependencias externas no macOS (zero deps, so frameworks Apple)
- Nunca hardcodar caminhos de usuario — usar `$HOME`/`~`/`Environment.SpecialFolder`

## Contexto

Palantir e a versao publica e polida do projeto `live-wallpaper` (que e a versao de desenvolvimento local). O fluxo e: desenvolver em `live-wallpaper`, quando estiver pronto, portar as mudancas para `palantir`.

### Repositorios relacionados
- **live-wallpaper** (`~/projetos/live-wallpaper`) — versao de dev, paths locais
- **homebrew-palantir** (`~/projetos/homebrew-palantir`) — formula Homebrew, aponta para tag v1.0
- **GitHub:** github.com/monkfrodo/palantir (publico)

### Como funciona internamente
- **Desktop macOS:** Janela borderless no nivel `desktopWindow` com AVPlayer em loop. Observers para space change, wake, unlock e screen config change recriam a janela.
- **Desktop Windows:** WorkerW hack — envia mensagem 0x052C ao Progman para criar WorkerW, depois embeda janela WPF como child. MediaElement por monitor.
- **Lock screen macOS:** Injeta videos no sistema de aerials (`~/Library/Application Support/com.apple.wallpaper/aerials/`), modifica entries.json, gera thumbnails, reinicia WallpaperAerialsExtension.
- **Lock screen Windows:** Extrai frame HQ do video e seta via Registry (PersonalizationCSP ou HKCU Lock Screen).
- **Auto-update:** Timer de 6h checa GitHub API `/releases/latest`, baixa assets .mov/.mp4 novos, corrige nomes (GitHub troca espacos por pontos).
- **Thumbnails:** Extrai frame no segundo 2 do video, cacheia como PNG em `.frames/`.

## Arquivos Importantes

| Arquivo | Descricao |
|---------|-----------|
| `src/App.swift` | Tudo do macOS: app, manager, galeria, updater (~880 linhas) |
| `windows/Core/WorkerWHack.cs` | Hack de injecao de wallpaper no Windows |
| `windows/Core/WallpaperManager.cs` | Gerenciamento de playback Windows |
| `install.sh` | Instalador principal macOS (compilacao + setup) |
| `windows/install.ps1` | Instalador principal Windows |
| `README.md` | Documentacao publica (ingles) |

## Git

- **Branch:** main
- **Commits:** conventional commits em ingles
- **Releases:** GitHub Releases com wallpapers como assets
