# Hypredro - Script de configuração mínima para o **Hyprland**

O Hypredro é um script de instalação automatizada para uma **configuração mínima do Hyprland** no **Arch Linux**. O Hypredro não é um ambiente de desktop completo — ele fornece apenas o essencial para que o Hyprland funcione, com dotfiles pré-configurados e suporte opcional a NVIDIA, LaTeX, CUDA e ferramentas de desenvolvimento.

O Hypredro instala e configura o mínimo necessário para ter o Hyprland funcionando de forma utilizável, deixando o restante para o usuário personalizar conforme sua preferência.

## 📋 Pré-requisitos

- Instalação limpa do Arch Linux
- Conexão estável com a internet
- Usuário com acesso sudo (não execute como root)

## 🚩 Uso

Tudo é feito por um único script:

```bash
./hypredro.sh
```

O script exibe uma série de diálogos **antes** de iniciar qualquer instalação, perguntando:

1. Se deseja instalar os drivers **NVIDIA** e hooks
2. Quais **componentes opcionais** instalar (lista de seleção)

Após isso, a instalação ocorre sem mais interrupções.

## 📦 Etapas de instalação

| Etapa | Ação |
|-------|------|
| 01/09 | Configurar o pacman (multilib, cor, downloads paralelos) |
| 02/09 | Instalar pacotes essenciais (Hyprland, Waybar, Kitty, Dolphin, etc.) |
| 03/09 | Configurar drivers NVIDIA open-dkms *(se selecionado)* |
| 04/09 | Ativar serviços do sistema (NetworkManager, Bluetooth, SDDM, CUPS) |
| 05/09 | Criar diretórios do usuário via `xdg-user-dirs` |
| 06/09 | Copiar dotfiles para `~/.config` |
| 07/09 | Instalar Oh My Zsh com plugins e definir ZSH como shell padrão |
| 08/09 | Instalar **yay**, fontes do AUR e tema **Powerlevel10k** |
| 09/09 | Instalar componentes opcionais selecionados |

## 🗳️ Componentes opcionais

Os seguintes pacotes podem ser instalados juntamente com o ambiente:

| Componente | Detalhes |
|------------|----------|
| LaTeX | TeX Live completo com suporte ao português |
| CUDA | Suporte a computação em GPU para NVIDIA |
| Python venv | PyTorch (CPU ou GPU, conforme escolha de NVIDIA) + NumPy, SciPy, Pandas, OpenCV, Jupyter |
| Visual Studio Code | Instalado via AUR (`visual-studio-code-bin`) |
| Drivers Epson | `epson-inkjet-printer-escpr` via AUR |
| OnlyOffice | `onlyoffice-bin` via AUR |
| LibreOffice | `libreoffice-fresh` + suporte ao português (`libreoffice-fresh-pt-br`) |
| Slack | `slack-desktop` via AUR |
| Steam | Instalado via pacman |
| Discord | Instalado via pacman |
| OBS Studio | `obs-studio` via pacman |
| Wine + Winetricks | `wine` + `winetricks` via pacman |
| Docker | `docker` + `docker-compose` via pacman; usuário adicionado ao grupo `docker` |
| Node.js + npm | `nodejs` + `npm` via pacman |
| Arduino | `arduino-cli` via pacman + `arduino-ide-bin` via AUR |

