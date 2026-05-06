#!/usr/bin/env bash
# hypredro.sh — Complete Hypredro environment installation on Arch Linux

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

clear

if [[ $EUID -eq 0 ]]; then
    echo "Do not run this script as root. Use a user with sudo." >&2
    exit 1
fi

echo "==> Requesting sudo credentials (required only once)..."
sudo -v

# ──────────────────────────────────────────────────────────────
# Check/install dialog (mandatory dependency)
# ──────────────────────────────────────────────────────────────
if ! command -v dialog &>/dev/null; then
    echo "==> Installing dialog (required dependency)..."
    sudo pacman -S --needed --noconfirm dialog
fi

# ──────────────────────────────────────────────────────────────
# Welcome
# ──────────────────────────────────────────────────────────────
dialog --title "Hypredro Installation — Arch Linux" \
    --msgbox "\nWelcome! This script will guide you through the complete\nsetup of a Hyprland environment on Arch Linux.\n\nThe process includes:\n\n  • Pacman configuration and repositories\n  • Essential packages and Wayland environment\n  • NVIDIA drivers (optional)\n  • System services and ZSH\n  • Yay and AUR packages\n  • Fonts, Powerlevel10k theme\n  • Flatpak and final adjustments\n  • Optional packages (LaTeX, CUDA, VS Code...)\n\nBefore continuing, make sure that:\n  • You are on a clean Arch installation\n  • You have a stable internet connection\n  • The dotfiles are ready to be copied\n\nEstimated time: 30 to 90 minutes." \
    22 65
clear

dialog --title "Do you wish to continue?" \
    --yesno "\nStart the Hypredro environment installation?" \
    8 45
if [[ $? -ne 0 ]]; then
    clear
    echo "Installation cancelled by user."
    exit 0
fi
clear

# ──────────────────────────────────────────────────────────────
# Initial questions — NVIDIA
# ──────────────────────────────────────────────────────────────
INSTALL_NVIDIA=0
dialog --title "NVIDIA Drivers" \
    --yesno "\nDo you wish to install and configure NVIDIA packages?\n(nvidia-open-dkms, nvidia-utils, CUDA hooks, etc.)" \
    9 55
if [[ $? -eq 0 ]]; then
    INSTALL_NVIDIA=1
fi
clear

# ──────────────────────────────────────────────────────────────
# Initial questions — Optional packages
# ──────────────────────────────────────────────────────────────
CHOICES=$(dialog --stdout \
    --title "Optional Components" \
    --checklist "Select components to install:\n(Space: check/uncheck  |  Enter: confirm  |  Esc: skip)" \
    24 65 13 \
    "latex"      "LaTeX (TeX Live)"            off \
    "cuda"       "CUDA (NVIDIA GPU)"           off \
    "python"     "Python venv (PyTorch + ML)"  off \
    "vscode"     "Visual Studio Code"          off \
    "epson"      "Epson printer drivers"       off \
    "onlyoffice" "OnlyOffice"                  off \
    "slack"      "Slack"                       off \
    "steam"      "Steam"                       off \
    "discord"    "Discord"                     off \
    "claudecode" "Claude Code (CLI)"           off)
DIALOG_STATUS=$?
clear

if [[ $DIALOG_STATUS -ne 0 ]]; then
    CHOICES=""
fi

has() { [[ " $CHOICES " == *" $1 "* ]]; }

# Keep sudo token alive throughout the entire installation
( while true; do sudo -v; sleep 50; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

# ──────────────────────────────────────────────────────────────
# Step 1: Configuring Pacman
# ──────────────────────────────────────────────────────────────
echo ""
echo " [01/09] ==> Configuring Package Manager..."
echo ""

sudo sed -i '/^#\[multilib\]/{N;s/#\[multilib\]\n#Include/[multilib]\nInclude/}' /etc/pacman.conf
sudo sed -i 's/^#Color$/Color/' /etc/pacman.conf

if grep -q '^#ParallelDownloads' /etc/pacman.conf; then
    sudo sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
elif ! grep -q '^ParallelDownloads' /etc/pacman.conf; then
    sudo sed -i '/^Color/a ParallelDownloads = 5' /etc/pacman.conf
fi

echo ""
echo "==> Updating Package Manager..."
echo ""
sudo pacman -Syu --noconfirm

# ──────────────────────────────────────────────────────────────
# Step 2: Basic Packages
# ──────────────────────────────────────────────────────────────
echo ""
echo " [02/09] ==> Installing Basic Packages..."
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
# Step 3: NVIDIA (conditional)
# ──────────────────────────────────────────────────────────────
echo ""
echo " [03/09] ==> Configuring NVIDIA packages..."
echo ""

if [[ $INSTALL_NVIDIA -eq 1 ]]; then
    sudo pacman -S --needed --noconfirm \
        linux-headers nvidia-open-dkms nvidia-utils egl-wayland \
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
Target=nvidia-open-dkms
Target=linux
Target=linux-lts
Target=linux-zen
Target=linux-hardened

[Action]
Description=Updating initramfs after NVIDIA update...
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/usr/bin/mkinitcpio -P
EOF

    sudo mkinitcpio -P
    echo "  ✓ NVIDIA configuration complete."
else
    echo "  Skipping NVIDIA configuration."
fi

# ──────────────────────────────────────────────────────────────
# Step 4: System services
# ──────────────────────────────────────────────────────────────
echo ""
echo " [04/09] ==> Enabling services..."
echo ""
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth
sudo systemctl enable sddm
sudo systemctl enable cups.socket
sudo systemctl enable power-profiles-daemon

# ──────────────────────────────────────────────────────────────
# Step 5: User directories
# ──────────────────────────────────────────────────────────────
echo ""
echo " [05/09] ==> Creating user directories..."
echo ""
xdg-user-dirs-update

# ──────────────────────────────────────────────────────────────
# Step 6: Dotfiles
# ──────────────────────────────────────────────────────────────
echo ""
echo " [06/09] ==> Copying configuration files..."
echo ""

if [[ -d "$SCRIPT_DIR/.config" ]]; then
    cp -rv "$SCRIPT_DIR/.config/." ~/.config/
else
    echo "  Warning: $SCRIPT_DIR/.config not found. Skipping dotfiles."
fi

if [[ -f "$SCRIPT_DIR/.gtkrc-2.0" ]]; then
    cp -v "$SCRIPT_DIR/.gtkrc-2.0" ~/
else
    echo "  Warning: $SCRIPT_DIR/.gtkrc-2.0 not found. Skipping."
fi

# ──────────────────────────────────────────────────────────────
# Step 7: ZSH
# ──────────────────────────────────────────────────────────────
echo ""
echo " [07/09] ==> Configuring ZSH..."
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
    echo "  Warning: failed to change shell. Run manually: chsh -s $(which zsh)"

# ──────────────────────────────────────────────────────────────
# Step 8: Yay, fonts and essential AUR packages
# ──────────────────────────────────────────────────────────────
echo ""
echo " [08/09] ==> Installing yay and essential AUR packages..."
echo ""

if command -v yay &>/dev/null; then
    echo "  yay is already installed. Skipping."
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
echo "  Installing Powerlevel10k theme..."

if [[ -d "$HOME/powerlevel10k" ]]; then
    echo "  ~/powerlevel10k already exists. Skipping clone."
else
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
fi

if ! grep -q "powerlevel10k/powerlevel10k.zsh-theme" ~/.zshrc 2>/dev/null; then
    echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc
    echo "  ✓ Powerlevel10k registered in ~/.zshrc"
else
    echo "  Powerlevel10k is already in ~/.zshrc. Skipping."
fi

# ──────────────────────────────────────────────────────────────
# Step 9: Optional components
# ──────────────────────────────────────────────────────────────
echo ""
echo " [09/09] ==> Installing selected optional components..."
echo ""

if has "latex"; then
    echo "  Installing LaTeX..."
    sudo pacman -S --needed --noconfirm \
        texlive-basic texlive-latex texlive-latexrecommended texlive-latexextra \
        texlive-fontsrecommended texlive-fontsextra texlive-langportuguese \
        texlive-pictures texlive-mathscience texlive-binextra texlive-plaingeneric
    echo "  ✓ LaTeX installed."
fi

if has "cuda"; then
    echo "  Installing CUDA..."
    sudo pacman -S --needed --noconfirm cuda
    echo "  ✓ CUDA installed."
fi

if has "python"; then
    echo "  Setting up Python virtual environment..."
    if [[ -d "$HOME/.venvs/default" ]]; then
        echo "  Venv ~/.venvs/default already exists. Skipping creation."
    else
        python3 -m venv ~/.venvs/default/
    fi
    set +u
    source ~/.venvs/default/bin/activate
    pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu130
    pip install numpy scipy pandas matplotlib scikit-learn opencv-python notebook
    deactivate
    set -u
    if ! grep -q "alias startpython=" ~/.zshrc 2>/dev/null; then
        echo "alias startpython='source ~/.venvs/default/bin/activate'" >> ~/.zshrc
    fi
    echo "  ✓ Python environment configured at ~/.venvs/default"
fi

if has "vscode"; then
    echo "  Installing Visual Studio Code..."
    yay -S --needed --noconfirm visual-studio-code-bin
    echo "  ✓ VS Code installed."
fi

if has "epson"; then
    echo "  Installing Epson printer drivers..."
    yay -S --needed --noconfirm epson-inkjet-printer-escpr
    echo "  ✓ Epson drivers installed."
fi

if has "onlyoffice"; then
    echo "  Installing OnlyOffice..."
    yay -S --needed --noconfirm onlyoffice-bin
    echo "  ✓ OnlyOffice installed."
fi

if has "slack"; then
    echo "  Installing Slack..."
    yay -S --needed --noconfirm slack-desktop
    echo "  ✓ Slack installed."
fi

if has "steam"; then
    echo "  Installing Steam..."
    sudo pacman -S --needed --noconfirm steam
    echo "  ✓ Steam installed."
fi

if has "discord"; then
    echo "  Installing Discord..."
    sudo pacman -S --needed --noconfirm discord
    echo "  ✓ Discord installed."
fi

if has "claudecode"; then
    echo "  Installing Claude Code (CLI)..."
    if ! command -v npm &>/dev/null; then
        echo "  Installing Node.js and npm (Claude Code dependency)..."
        sudo pacman -S --needed --noconfirm nodejs npm
    fi
    sudo npm install -g @anthropic-ai/claude-code
    echo "  ✓ Claude Code installed. Run 'claude' to start."
fi

# ──────────────────────────────────────────────────────────────
# Flathub
# ──────────────────────────────────────────────────────────────
echo ""
echo "==> Adding Flathub repository..."
echo ""
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# ──────────────────────────────────────────────────────────────
# Final system configurations
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
# Completion
# ──────────────────────────────────────────────────────────────
dialog --title "Installation complete!" \
    --msgbox "\nAll components have been installed successfully!\n\nReminders:\n  • Reload your shell to use the new aliases\n    and the Powerlevel10k theme (or open a new terminal)\n  • On first zsh execution, the Powerlevel10k\n    wizard will start automatically. If not,\n    run: p10k configure\n  • Configure your services (Slack, Discord, etc.)\n    with your credentials when opening them for the first time\n\nEnjoy your new Hyprland environment!" \
    20 60
clear

dialog --title "Restart" \
    --yesno "\nDo you wish to restart the computer now?" \
    8 45
if [[ $? -eq 0 ]]; then
    clear
    sudo reboot
else
    clear
    echo "Remember to restart your computer before starting Hyprland!"
    echo ""
fi
