#############################################################################################
#        ,--,                                                                     
#      ,--.'|                                                                     
#   ,--,  | :           ,-.----.                         ,---,                    
#,---.'|  : '           \    /  \   __  ,-.            ,---.'|  __  ,-.   ,---.   
#|   | : _' |           |   :    |,' ,'/ /|            |   | :,' ,'/ /|  '   ,'\  
#:   : |.'  |      .--, |   | .\ :'  | |' | ,---.      |   | |'  | |' | /   /   | 
#|   ' '  ; :    /_ ./| .   : |: ||  |   ,'/     \   ,--.__| ||  |   ,'.   ; ,. : 
#'   |  .'. | , ' , ' : |   |  \ :'  :  / /    /  | /   ,'   |'  :  /  '   | |: : 
#|   | :  | '/___/ \: | |   : .  ||  | ' .    ' / |.   '  /  ||  | '   '   | .; : 
#'   : |  : ; .  \  ' | :     |`-';  : | '   ;   /|'   ; |:  |;  : |   |   :    | 
#|   | '  ,/   \  ;   : :   : :   |  , ; '   |  / ||   | '/  '|  , ;    \   \  /  
#;   : ;--'     \  \  ; |   | :    ---'  |   :    ||   :    :| ---'      `----'   
#|   ,/          :  \  \`---'.|           \   \  /  \   \  /                      
#'---'            \  ' ;  `---`            `----'    `----'                       
#                  `--`
#############################################################################################
#
# Hypredro - Um script automatizado para instalação do Hyprland no ArchLinux
#
# Versão 0.2, por Pedro Thiago V. de Souza (pedrothiag)
#
#############################################################################################

#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

clear

if [[ $EUID -eq 0 ]]; then
    echo "Não execute este script como root. Use um usuário com sudo." >&2
    exit 1
fi

echo "==> Solicitando credenciais sudo (necessário apenas uma vez)..."
sudo -v

# ──────────────────────────────────────────────────────────────
# Verificar/instalar dialog (dependência obrigatória)
# ──────────────────────────────────────────────────────────────
if ! command -v dialog &>/dev/null; then
    echo "==> Instalando dialog (dependência necessária)..."
    sudo pacman -S --needed --noconfirm dialog
fi

# ──────────────────────────────────────────────────────────────
# Boas-vindas
# ──────────────────────────────────────────────────────────────
dialog --title "Instalação do Hypredro" \
    --msgbox "\nBem-vindo! Este script guiará você pela configuração completa\nde um ambiente Hyprland no Arch Linux.\n\nO processo inclui:\n\n  • Configuração do Pacman e repositórios\n  • Pacotes essenciais e ambiente Hyprland\n  • Drivers NVIDIA (opcional)\n  • Serviços do sistema e ZSH\n  • Yay e pacotes AUR\n  • Fontes e tema Powerlevel10k\n  • Flatpak\n  • Pacotes opcionais (LaTeX, CUDA, VS Code...)\n\nAntes de continuar, certifique-se de que:\n  • Você está em uma instalação limpa do Arch\n  • Você tem uma conexão de internet estável\n  • Os dotfiles estão prontos para serem copiados\n\nTempo estimado: 30 a 90 minutos." \
    22 65
clear

dialog --title "Deseja continuar?" \
    --yesno "\nIniciar a instalação do ambiente Hypredro?" \
    8 45
if [[ $? -ne 0 ]]; then
    clear
    echo "Instalação cancelada pelo usuário."
    exit 0
fi
clear

# ──────────────────────────────────────────────────────────────
# Perguntas iniciais — NVIDIA
# ──────────────────────────────────────────────────────────────
INSTALL_NVIDIA=0
dialog --title "Drivers NVIDIA" \
    --yesno "\nDeseja instalar e configurar os pacotes NVIDIA?\n(nvidia-open-dkms, nvidia-utils, hooks CUDA, etc.)" \
    9 55
if [[ $? -eq 0 ]]; then
    INSTALL_NVIDIA=1
fi
clear

# ──────────────────────────────────────────────────────────────
# Perguntas iniciais — Pacotes opcionais
# ──────────────────────────────────────────────────────────────
CHOICES=$(dialog --stdout \
    --title "Componentes Opcionais" \
    --checklist "Selecione os componentes para instalar:\n(Espaço: marcar/desmarcar  |  Enter: confirmar  |  Esc: pular)" \
    28 65 15 \
    "latex"        "LaTeX (TeX Live)"                   off \
    "cuda"         "CUDA (GPU NVIDIA)"                  off \
    "python"       "Ambiente virtual Pytho"             off \
    "vscode"       "Visual Studio Code"                 off \
    "epson"        "Drivers de impressora Epson"        off \
    "onlyoffice"   "OnlyOffice"                         off \
    "slack"        "Slack"                              off \
    "steam"        "Steam"                              off \
    "discord"      "Discord"                            off \
    "libreoffice"  "LibreOffice (pt-BR)"                off \
    "obs"          "OBS Studio"                         off \
    "wine"         "Wine + Winetricks"                  off \
    "docker"       "Docker + Docker Compose"            off \
    "nodejs"       "Node.js + npm"                      off \
    "arduino"      "Arduino CLI + IDE"                  off)
DIALOG_STATUS=$?
clear

if [[ $DIALOG_STATUS -ne 0 ]]; then
    CHOICES=""
fi

has() { [[ " $CHOICES " == *" $1 "* ]]; }

# Manter o token sudo ativo durante toda a instalação
( while true; do sudo -v; sleep 50; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

# ──────────────────────────────────────────────────────────────
# Passo 1: Configurando o Pacman
# ──────────────────────────────────────────────────────────────
echo ""
echo " [01/09] ==> Configurando o Gerenciador de Pacotes..."
echo ""

sudo sed -i '/^#\[multilib\]/{N;s/#\[multilib\]\n#Include/[multilib]\nInclude/}' /etc/pacman.conf
sudo sed -i 's/^#Color$/Color/' /etc/pacman.conf

if grep -q '^#ParallelDownloads' /etc/pacman.conf; then
    sudo sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
elif ! grep -q '^ParallelDownloads' /etc/pacman.conf; then
    sudo sed -i '/^Color/a ParallelDownloads = 5' /etc/pacman.conf
fi

echo ""
echo "==> Atualizando o Gerenciador de Pacotes..."
echo ""
sudo pacman -Syu --noconfirm

# ──────────────────────────────────────────────────────────────
# Passo 2: Pacotes Básicos
# ──────────────────────────────────────────────────────────────
echo ""
echo " [02/09] ==> Instalando Pacotes Básicos..."
echo ""
sudo pacman -S --needed --noconfirm \
    git github-cli base-devel ttf-font-awesome ttf-dejavu noto-fonts noto-fonts-emoji \
    ttf-liberation ttf-firacode-nerd gst-libav gst-plugins-bad gst-plugins-good \
    gst-plugins-ugly ffmpeg gstreamer xdg-desktop-portal \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-desktop-portal-kde dolphin wofi hyprlock \
    hyprpolkitagent hyprpaper waybar pavucontrol cliphist wl-clipboard \
    ntfs-3g gnome-disk-utility cups system-config-printer ghostscript gsfonts \
    gutenprint unzip p7zip unrar tar gzip bzip2 xz firefox flatpak zsh breeze \
    breeze5 breeze-gtk breeze-icons kvantum-qt5 adw-gtk-theme nwg-look neovim \
    python-pip qalculate-gtk evince ark kate wget xdg-user-dirs htop \
    fastfetch curl hyprland sddm dunst kitty qt5-wayland qt6-wayland uwsm \
    xdg-user-dirs xdg-utils blueman bluez bluez-utils bluez-tools \
    network-manager-applet exfatprogs mpv grim slurp hypridle \
    hyprpicker power-profiles-daemon xorg-xwayland pipewire pipewire-pulse \
    pipewire-alsa wireplumber networkmanager brightnessctl gwenview archlinux-xdg-menu \
    gcc make git ripgrep fd tree-sitter-cli kolourpaint

# ──────────────────────────────────────────────────────────────
# Passo 3: NVIDIA
# ──────────────────────────────────────────────────────────────
echo ""
echo " [03/09] ==> Configurando pacotes NVIDIA..."
echo ""

if [[ $INSTALL_NVIDIA -eq 1 ]]; then
    sudo pacman -S --needed --noconfirm \
        linux-headers nvidia-open nvidia-utils egl-wayland \
        libva-nvidia-driver lib32-nvidia-utils nvidia-settings

    sudo sed -i 's/^MODULES=(.*)/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf

    sudo tee /etc/modprobe.d/nvidia.conf > /dev/null <<'EOF'
options nvidia-drm modeset=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF

    sudo mkdir -p /etc/pacman.d/hooks
    sudo tee /etc/pacman.d/hooks/nvidia.hook > /dev/null <<'EOF'
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-open
Target=linux
Target=linux-lts
Target=linux-zen
Target=linux-hardened

[Action]
Description=Atualizando o initramfs após atualização do NVIDIA...
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/usr/bin/mkinitcpio -P
EOF

    sudo mkinitcpio -P
    echo "  ✓ Configuração do NVIDIA concluída."
else
    echo "  Ignorando a configuração do NVIDIA."
fi

# ──────────────────────────────────────────────────────────────
# Passo 4: Serviços do sistema
# ──────────────────────────────────────────────────────────────
echo ""
echo " [04/09] ==> Habilitando serviços..."
echo ""
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth
sudo systemctl enable sddm
sudo systemctl enable cups.socket
sudo systemctl enable power-profiles-daemon

# ──────────────────────────────────────────────────────────────
# Passo 5: Diretórios do usuário
# ──────────────────────────────────────────────────────────────
echo ""
echo " [05/09] ==> Criando diretórios do usuário..."
echo ""
xdg-user-dirs-update

# ──────────────────────────────────────────────────────────────
# Passo 6: Dotfiles
# ──────────────────────────────────────────────────────────────
echo ""
echo " [06/09] ==> Copiando arquivos de configuração..."
echo ""

if [[ -d "$SCRIPT_DIR/.config" ]]; then
    cp -rv "$SCRIPT_DIR/.config/." ~/.config/
else
    echo "  Aviso: $SCRIPT_DIR/.config não encontrado. Ignorando dotfiles."
fi

if [[ -f "$SCRIPT_DIR/.gtkrc-2.0" ]]; then
    cp -v "$SCRIPT_DIR/.gtkrc-2.0" ~/
else
    echo "  Aviso: $SCRIPT_DIR/.gtkrc-2.0 não encontrado. Ignorando."
fi

# ──────────────────────────────────────────────────────────────
# Passo 7: ZSH
# ──────────────────────────────────────────────────────────────
echo ""
echo " [07/09] ==> Configurando ZSH..."
echo ""

set +u
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
set -u

ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

[[ -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" ]] || \
    git clone https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"

[[ -d "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" ]] || \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
        "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"

sed -i 's/^plugins=(git)$/plugins=(git archlinux zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc

sudo chsh -s "$(which zsh)" "$USER" || \
    echo "  Aviso: falha ao alterar o shell. Execute manualmente: chsh -s $(which zsh)"

# ──────────────────────────────────────────────────────────────
# Passo 8: Yay, fontes e pacotes AUR essenciais
# ──────────────────────────────────────────────────────────────
echo ""
echo " [08/09] ==> Instalando yay e pacotes AUR essenciais..."
echo ""

if command -v yay &>/dev/null; then
    echo "  yay já está instalado. Ignorando."
else
    rm -rf /tmp/yay-build
    git clone https://aur.archlinux.org/yay.git /tmp/yay-build
    (
        cd /tmp/yay-build
        makepkg -si --noconfirm
    )
    rm -rf /tmp/yay-build
fi

yay -S --needed --noconfirm \
    otf-san-francisco \
    grimblast \
    qt5ct-kde \
    qt6ct-kde

echo ""
echo "  Instalando o tema Powerlevel10k..."

if [[ -d "$HOME/powerlevel10k" ]]; then
    echo "  ~/powerlevel10k já existe. Ignorando clone."
else
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
fi

if ! grep -q "powerlevel10k/powerlevel10k.zsh-theme" ~/.zshrc 2>/dev/null; then
    echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc
    echo "  ✓ Powerlevel10k registrado em ~/.zshrc"
else
    echo "  Powerlevel10k já está em ~/.zshrc. Ignorando."
fi

# ──────────────────────────────────────────────────────────────
# Passo 9: Componentes opcionais
# ──────────────────────────────────────────────────────────────
echo ""
echo " [09/09] ==> Instalando componentes opcionais selecionados..."
echo ""

if has "latex"; then
    echo "  Instalando LaTeX..."
    sudo pacman -S --needed --noconfirm \
        texlive-basic texlive-latex texlive-latexrecommended texlive-latexextra \
        texlive-fontsrecommended texlive-fontsextra texlive-langportuguese \
        texlive-pictures texlive-mathscience texlive-binextra texlive-plaingeneric
    echo "  ✓ LaTeX instalado."
fi

if has "cuda"; then
    echo "  Instalando CUDA..."
    sudo pacman -S --needed --noconfirm cuda
    echo "  ✓ CUDA instalado."
fi

if has "python"; then
    echo "  Configurando ambiente virtual Python..."
    if [[ -d "$HOME/.venvs/default" ]]; then
        echo "  O venv ~/.venvs/default já existe. Ignorando criação."
    else
        python3 -m venv ~/.venvs/default/
    fi
    set +u
    source ~/.venvs/default/bin/activate
    if [[ $INSTALL_NVIDIA -eq 1 ]]; then
        pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu130
    else
        pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cpu
    fi
    pip install numpy scipy pandas matplotlib scikit-learn opencv-python notebook
    deactivate
    set -u
    if ! grep -q "alias startpython=" ~/.zshrc 2>/dev/null; then
        echo "alias startpython='source ~/.venvs/default/bin/activate'" >> ~/.zshrc
    fi
    echo "  ✓ Ambiente Python configurado em ~/.venvs/default"
fi

if has "vscode"; then
    echo "  Instalando Visual Studio Code..."
    yay -S --needed --noconfirm visual-studio-code-bin
    echo "  ✓ VS Code instalado."
fi

if has "epson"; then
    echo "  Instalando drivers de impressora Epson..."
    yay -S --needed --noconfirm epson-inkjet-printer-escpr
    echo "  ✓ Drivers Epson instalados."
fi

if has "onlyoffice"; then
    echo "  Instalando OnlyOffice..."
    yay -S --needed --noconfirm onlyoffice-bin
    echo "  ✓ OnlyOffice instalado."
fi

if has "slack"; then
    echo "  Instalando Slack..."
    yay -S --needed --noconfirm slack-desktop
    echo "  ✓ Slack instalado."
fi

if has "steam"; then
    echo "  Instalando Steam..."
    sudo pacman -S --needed --noconfirm steam
    echo "  ✓ Steam instalado."
fi

if has "discord"; then
    echo "  Instalando Discord..."
    sudo pacman -S --needed --noconfirm discord
    echo "  ✓ Discord instalado."
fi

if has "libreoffice"; then
    echo "  Instalando LibreOffice..."
    sudo pacman -S --needed --noconfirm libreoffice-fresh libreoffice-fresh-pt-br
    echo "  ✓ LibreOffice instalado."
fi

if has "obs"; then
    echo "  Instalando OBS Studio..."
    sudo pacman -S --needed --noconfirm obs-studio
    echo "  ✓ OBS Studio instalado."
fi

if has "wine"; then
    echo "  Instalando Wine + Winetricks..."
    sudo pacman -S --needed --noconfirm wine winetricks
    echo "  ✓ Wine e Winetricks instalados."
fi

if has "docker"; then
    echo "  Instalando Docker + Docker Compose..."
    sudo pacman -S --needed --noconfirm docker docker-compose
    sudo systemctl enable docker
    sudo usermod -aG docker "$USER"
    echo "  ✓ Docker instalado. Saia e entre novamente para que as alterações de grupo tenham efeito."
fi

if has "nodejs"; then
    echo "  Instalando Node.js + npm..."
    sudo pacman -S --needed --noconfirm nodejs npm
    echo "  ✓ Node.js e npm instalados."
fi

if has "arduino"; then
    echo "  Instalando Arduino CLI + IDE..."
    sudo pacman -S --needed --noconfirm arduino-cli
    yay -S --needed --noconfirm arduino-ide-bin
    echo "  ✓ Arduino CLI e Arduino IDE instalados."
fi

# ──────────────────────────────────────────────────────────────
# Flathub
# ──────────────────────────────────────────────────────────────
echo ""
echo "==> Adicionando repositório Flathub..."
echo ""
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# ──────────────────────────────────────────────────────────────
# Configurações finais do sistema
# ──────────────────────────────────────────────────────────────
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
gsettings set org.gnome.desktop.interface icon-theme 'breeze-dark'
sudo update-mime-database /usr/share/mime
rm -f ~/.cache/ksycoca6_*
sudo ln -sf /etc/xdg/menus/plasma-applications.menu /etc/xdg/menus/applications.menu
rm -f ~/.cache/ksycoca6_*
kbuildsycoca6 --noincremental --track menu
xdg-mime default org.kde.kate.desktop text/plain

# ──────────────────────────────────────────────────────────────
# Conclusão
# ──────────────────────────────────────────────────────────────
dialog --title "Instalação concluída!" \
    --msgbox "\nTodos os componentes foram instalados com sucesso!\n\nLembretes:\n  • Recarregue seu shell para usar os novos aliases\n    e o tema Powerlevel10k (ou abra um novo terminal)\n  • Na primeira execução do zsh, o assistente do\n    Powerlevel10k iniciará automaticamente. Se não,\n    execute: p10k configure\n  • Configure seus serviços (Slack, Discord, etc.)\n    com suas credenciais ao abri-los pela primeira vez\n\nAproveite seu novo ambiente Hyprland!" \
    20 60
clear

dialog --title "Reiniciar" \
    --yesno "\nDeseja reiniciar o computador agora?" \
    8 45
if [[ $? -eq 0 ]]; then
    clear
    sudo reboot
else
    clear
    echo "Lembre-se de reiniciar o computador antes de iniciar o Hyprland!"
    echo ""
fi
