<p align="center">
  <br>
  <strong>◆ &nbsp; P A L A N T Í R &nbsp; ◆</strong>
  <br>
  <em>Wallpapers animados para macOS</em>
  <br><br>
  Nativo, leve, sem apps de terceiros.
  <br>
  ~0% de CPU — decodificação por hardware.
  <br><br>
</p>

---

## Instalação

Abre o Terminal e cola:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/monkfrodo/palantir/main/install.sh)"
```

Isso vai:
1. Baixar o Palantir pra `~/.palantir/`
2. Baixar os wallpapers automaticamente
3. Compilar o app
4. Configurar pra abrir junto com o Mac

Pronto. Procura o **icone de TV** na barra de menu.

## Como usar

Clica no icone de **TV** na menu bar e depois em **Open Gallery**.

Passa o mouse por cima de qualquer wallpaper e escolhe:

| Botao | O que faz |
|---|---|
| **Both** | Desktop + tela de bloqueio |
| **Desktop** | So o desktop animado |
| **Lock** | So a tela de bloqueio |

Pra parar, clica em **Stop Wallpaper** no menu.

### Adicionar wallpapers novos

Joga qualquer `.mov` ou `.mp4` na pasta `~/.palantir/wallpapers/` e clica **Refresh** na galeria.

## Como funciona

- **Desktop** — janela invisivel no nivel do desktop tocando video em loop com AVPlayer
- **Tela de bloqueio** — injeta os wallpapers no sistema nativo de aerials do macOS (mesmo mecanismo que apps como Wallux)
- **Resiliente** — sobrevive troca de espacos, sleep, unlock e restart

## Atualizar

```bash
~/.palantir/install.sh
```

## Desinstalar

```bash
~/.palantir/uninstall.sh
```

## Requisitos

- macOS 14+ (Sonoma)
- Xcode Command Line Tools (instalado automaticamente se nao tiver)

---

<p align="center">
  <em>"O que você vê na pedra?"</em>
</p>
