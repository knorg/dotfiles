#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Debian 13 (Trixie) — i3wm Development Environment Setup
# Console login → startx → i3  (no display manager)
# Config: github.com/knorg/dotfiles.git  +  GNU Stow
#
# Neovim, Emacs (Doom), and Tmux are offered as optional selections.
#
# This script lives in the dotfiles repo. Usage:
#   git clone https://github.com/knorg/dotfiles.git ~/.dotfiles
#   cd ~/.dotfiles
#   ./setup-debian13.sh --install
# =============================================================================

# Resolve dotfiles dir from script location (works even through symlinks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"

NVIM_INSTALL_DIR="/opt/nvim-linux-x86_64"
NVIM_PREV_DIR="/opt/nvim-linux-x86_64.prev"
NVIM_SYMLINK="/usr/local/bin/nvim"
TMUX_CONF="${HOME}/.tmux.conf"
TMUX_PLUGIN_DIR="${HOME}/.tmux/plugins"

DOOM_EMACS_REPO="https://github.com/doomemacs/doomemacs"
DOOM_EMACS_DIR="${HOME}/.config/emacs"

JULIA_INSTALL_SCRIPT="https://install.julialang.org"

# HiDPI defaults
GRUB_FONT_SIZE=24
GRUB_FONT_PATH="/boot/grub/fonts/DejaVuSansMono${GRUB_FONT_SIZE}.pf2"
GRUB_FONT_SRC="/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
GRUB_GFXMODE="1920x1080"
XRANDR_FILE="/etc/X11/Xsession.d/45custom_xrandr-settings"

# -- CLI flags (set by parse_args) -------------------------------------------
OPT_INSTALL=false
OPT_NVIM_UPDATE=false
OPT_NVIM_ROLLBACK=false
OPT_HIDPI=false
OPT_HIDPI_REVERT=false
OPT_HIDPI_HELP=false

# -- Editor/tool selection (set by install_optional_packages) ----------------
OPT_WITH_NEOVIM=false
OPT_WITH_EMACS=false
OPT_WITH_TMUX=false

# -- Colors for output --------------------------------------------------------
# ANSI-C quoting ($'...') stores actual escape bytes — works with cat, echo, printf
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
BOLD=$'\033[1m'
NC=$'\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERR ]${NC}  $*" >&2; }

# -- Helpers ------------------------------------------------------------------

need_root() {
    if [[ $EUID -eq 0 ]]; then
        err "Don't run this script as root. It will call sudo when needed."
        exit 1
    fi
}

ask_yes_no() {
    local prompt="$1"
    local reply
    while true; do
        read -rp "$(echo -e "${YELLOW}[????]${NC}  ${prompt} [y/n]: ")" reply
        case "$reply" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) echo "  Please answer y or n." ;;
        esac
    done
}

install_missing_packages() {
    local -a to_install=()

    for pkg in "$@"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        ok "All packages already installed."
        return
    fi

    info "Installing ${#to_install[@]} missing package(s): ${to_install[*]}"
    sudo apt update -qq
    sudo apt install -y "${to_install[@]}"
    ok "Packages installed."
}

# -- Argument parsing ---------------------------------------------------------

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --install)        OPT_INSTALL=true ;;
            --nvim-update)    OPT_NVIM_UPDATE=true; OPT_INSTALL=true; OPT_WITH_NEOVIM=true ;;
            --nvim-rollback)  OPT_NVIM_ROLLBACK=true ;;
            --hidpi)          OPT_HIDPI=true ;;
            --hidpi-revert)   OPT_HIDPI_REVERT=true ;;
            --hidpi-help)     OPT_HIDPI_HELP=true ;;
            --help|-h)        ;; # no-op, bare call already shows help
            *)
                err "Unknown option: $1"
                err "Run with --help for usage."
                exit 1
                ;;
        esac
        shift
    done
}

show_help() {
    cat <<EOF
${BOLD}Debian 13 (Trixie) — i3wm Setup Script${NC}

${BOLD}Quick start:${NC}
  git clone https://github.com/knorg/dotfiles.git ~/.dotfiles
  cd ~/.dotfiles
  ./setup-debian13.sh --install

  Called without options, this help is shown.

${BOLD}Options:${NC}
  ${BOLD}Install${NC}
    --install           Run full setup (packages, dotfiles, julia, etc.)
                        Neovim, Emacs, and Tmux are offered interactively.
    --install --hidpi   Full install including HiDPI configuration

  ${BOLD}Neovim${NC}
    --nvim-update       Full install + update Neovim to latest GitHub release
    --nvim-rollback     Rollback Neovim to previous version (standalone, exits)

  ${BOLD}HiDPI${NC}
    --hidpi             Apply HiDPI fixes (GRUB font + xrandr scaling)
    --hidpi-revert      Revert HiDPI settings (standalone, exits)
    --hidpi-help        Show how to change display resolution (standalone, exits)

  ${BOLD}General${NC}
    --help, -h          Show this help

${BOLD}Post-install checklist:${NC}
  • If this is a fresh install, reboot to use console login → startx → i3
  • Verify i3 is the default: ${BOLD}sudo update-alternatives --config x-session-manager${NC}
  • Set GTK theme/icons/fonts: ${BOLD}lxappearance${NC}
  • Adjust compositor effects: ${BOLD}picom-conf${NC}
  • If Tmux was selected, install plugins (in a tmux session): ${BOLD}prefix + I${NC}
  • Check Julia: ${BOLD}juliaup status${NC}
  • If Emacs was selected: ${BOLD}systemctl --user status emacs${NC}

EOF
}

show_hidpi_help() {
    cat <<EOF
${BOLD}HiDPI — Changing Display Resolution${NC}

The script creates ${BOLD}/etc/X11/Xsession.d/45custom_xrandr-settings${NC}
which runs at X session startup and sets a scaled-down resolution.

${BOLD}Current default (for 4K panels):${NC}
  xrandr --output eDP-1 --mode 2048x1152

${BOLD}To switch to a different resolution:${NC}

  1. List available modes:
       xrandr

  2. Try a mode live (resets on logout):
       xrandr --output eDP-1 --mode 1920x1080

  3. To add a custom mode (e.g. 2304x1296):
       xrandr --newmode "2304x1296" 251.25 2304 2464 2712 3120 1296 1299 1304 1344 -hsync +vsync
       xrandr --addmode eDP-1 2304x1296
       xrandr --output eDP-1 --mode 2304x1296

     Use ${BOLD}cvt${NC} to calculate modeline parameters:
       cvt 2304 1296 60

  4. Make it permanent by editing:
       sudo nano ${XRANDR_FILE}

${BOLD}GRUB font:${NC}
  Configured via /etc/default/grub (GRUB_FONT, GRUB_GFXMODE).
  To change GRUB font size, re-run grub-mkfont:
    sudo grub-mkfont --output=/boot/grub/fonts/DejaVuSansMono<SIZE>.pf2 \\
        --size=<SIZE> /usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf
    # Then update GRUB_FONT= in /etc/default/grub and run:
    sudo update-grub

${BOLD}To revert all HiDPI changes:${NC}
  ./setup-debian13.sh --hidpi-revert

EOF
}

# -- Package lists ------------------------------------------------------------
# Grouped by purpose for readability

CORE_PACKAGES=(
    git
    stow
    vim
    make
    gcc
    curl
    unzip
    openssh-server
    xinit            # provides startx (no display manager)
    gvfs-backends    # virtual filesystem (MTP, SMB, SFTP in file managers)
    smbclient        # SMB/CIFS network shares
)

TERMINAL_TOOLS=(
    alacritty
    mc
    btop
    eza
    ripgrep
    fd-find
    xclip
    maim
)

I3_DESKTOP=(
    i3
    i3blocks
    picom
    picom-conf
    rofi
    feh
)

APPEARANCE=(
    lxappearance
    arc-theme
    greybird-gtk-theme
    blackbird-gtk-theme
    bluebird-gtk-theme
    darkcold-gtk-theme
    darkfire-gtk-theme
    darkblood-gtk-theme
    numix-gtk-theme
    orchis-gtk-theme
    numix-icon-theme
    numix-icon-theme-circle
    faenza-icon-theme
    moka-icon-theme
    elementary-xfce-icon-theme
    papirus-icon-theme
    fonts-font-awesome
    fonts-symbola
    fonts-dejavu-core
    color-picker
)

DEV_TOOLS=(
    npm
    shellcheck
    markdown
)

# Editor/tool-specific dependencies (installed only when selected)
NEOVIM_DEPS=(
    cmake
    luarocks
)

EMACS_DEPS=(
    emacs
    cmake
    libvterm-dev
    libtool-bin
)

TMUX_DEPS=(
    tmux
    tmux-plugin-manager
)

HARDWARE=(
    mpv              # media player / camera viewfinder
    v4l-utils        # Video4Linux camera utilities
    xinput
    xserver-xorg-input-libinput
    sysfsutils
    fprintd
    libfprint-2-2
    libpam-fprintd
)

ALL_PACKAGES=(
    "${CORE_PACKAGES[@]}"
    "${TERMINAL_TOOLS[@]}"
    "${I3_DESKTOP[@]}"
    "${APPEARANCE[@]}"
    "${DEV_TOOLS[@]}"
    "${HARDWARE[@]}"
)

# -- Optional packages (interactive selection) --------------------------------
# Each entry: "label|package_name|repo_setup_function_or_empty"
#
# Virtual packages (prefixed with @) are not installed via apt:
#   @neovim  — installed from GitHub release
#   @emacs   — apt deps handled separately via EMACS_DEPS
#   @tmux    — apt deps handled separately via TMUX_DEPS

OPTIONAL_PACKAGES=(
    "Tmux + plugins|@tmux|"
    "Neovim (GitHub release)|@neovim|"
    "Emacs + Doom|@emacs|"
    "Brave Browser|brave-browser|_setup_brave_repo"
    "VS Code|code|_setup_vscode_repo"
    "Citrix Workspace|icaclient|_setup_citrix_workspace"
    "Dolphin (KDE file manager)|dolphin|"
    "Konsole (KDE terminal)|konsole|"
)

_setup_brave_repo() {
    local keyring="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
    local list="/etc/apt/sources.list.d/brave-browser.list"

    if [[ -f "$list" ]]; then
        ok "Brave repository already configured."
        return
    fi

    info "Adding Brave browser repository..."
    sudo curl -fsSLo "$keyring" \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

    echo "deb [signed-by=${keyring} arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        | sudo tee "$list" >/dev/null

    ok "Brave repository added."
}

_setup_vscode_repo() {
    local keyring="/usr/share/keyrings/packages.microsoft.gpg"
    local list="/etc/apt/sources.list.d/vscode.list"

    if [[ -f "$list" ]]; then
        ok "VS Code repository already configured."
        return
    fi

    info "Adding VS Code repository..."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | sudo gpg --dearmor -o "$keyring"

    echo "deb [arch=amd64 signed-by=${keyring}] https://packages.microsoft.com/repos/code stable main" \
        | sudo tee "$list" >/dev/null

    ok "VS Code repository added."
}

_setup_citrix_workspace() {
    # Citrix Workspace is not in any apt repo — it's a .deb downloaded
    # from citrix.com.  Look for a pre-downloaded .deb in ~/Downloads
    # or in the dotfiles directory.
    local deb=""
    for search_dir in "${HOME}/Downloads" "$DOTFILES_DIR"; do
        local found
        found=$(find "$search_dir" -maxdepth 1 -name 'icaclient_*.deb' -print -quit 2>/dev/null) || true
        if [[ -n "$found" ]]; then
            deb="$found"
            break
        fi
    done

    if [[ -z "$deb" ]]; then
        warn "No icaclient_*.deb found in ~/Downloads or ${DOTFILES_DIR}."
        info "Download the .deb from:"
        info "  https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html"
        info "Then re-run the script."
        return 1
    fi

    info "Installing Citrix Workspace from ${deb}..."
    sudo apt install -f -y "$deb"

    # Link system CA certificates so ICA sessions trust the server
    local ica_certs="/opt/Citrix/ICAClient/keystore/cacerts"
    if [[ -d "$ica_certs" ]]; then
        info "Linking system CA certificates into Citrix keystore..."
        sudo ln -sf /etc/ssl/certs/*.pem "$ica_certs/" 2>/dev/null || true
        sudo /opt/Citrix/ICAClient/util/ctx_rehash "$ica_certs" 2>/dev/null || true
        ok "Citrix CA certificates linked."
    fi

    # Configure Ctrl+F2 to exit fullscreen (useful inside VM sessions)
    _configure_citrix_hotkeys

    ok "Citrix Workspace installed."
}

_configure_citrix_hotkeys() {
    # Enable Ctrl+F2 to toggle fullscreen/window mode in Citrix sessions.
    # Disabled by default — requires FullScreenShortcutSupport in All_Regions.ini.
    # See: https://docs.citrix.com/en-us/citrix-workspace-app-for-linux/keyboard.html

    local system_ini="/opt/Citrix/ICAClient/config/All_Regions.ini"
    local user_ini="${HOME}/.ICAClient/All_Regions.ini"

    # 1. System-level: set FullScreenShortcutSupport=true
    if [[ -f "$system_ini" ]]; then
        if grep -q 'FullScreenShortcutSupport=true' "$system_ini"; then
            ok "System All_Regions.ini already has FullScreenShortcutSupport=true."
        elif grep -q 'FullScreenShortcutSupport' "$system_ini"; then
            info "Updating FullScreenShortcutSupport in system All_Regions.ini..."
            sudo sed -i 's/FullScreenShortcutSupport=.*/FullScreenShortcutSupport=true/' "$system_ini"
            ok "System All_Regions.ini updated."
        else
            info "Adding FullScreenShortcutSupport to system All_Regions.ini..."
            sudo sed -i '/\[Client Engine\\Application Launching\]/a FullScreenShortcutSupport=true' "$system_ini"
            ok "System All_Regions.ini updated."
        fi
    fi

    # 2. User-level: if ~/.ICAClient/All_Regions.ini exists (from a previous
    #    install), it overrides the system file.  Ensure it has the setting too.
    if [[ -f "$user_ini" ]]; then
        if grep -q 'FullScreenShortcutSupport=\*' "$user_ini"; then
            ok "User All_Regions.ini already has FullScreenShortcutSupport=*."
        elif grep -q 'FullScreenShortcutSupport' "$user_ini"; then
            info "Updating FullScreenShortcutSupport in user All_Regions.ini..."
            sed -i 's/FullScreenShortcutSupport=.*/FullScreenShortcutSupport=*/' "$user_ini"
            ok "User All_Regions.ini updated."
        elif grep -q '\[Client Engine\\Application Launching\]' "$user_ini"; then
            info "Adding FullScreenShortcutSupport to user All_Regions.ini..."
            sed -i '/\[Client Engine\\Application Launching\]/a FullScreenShortcutSupport=*' "$user_ini"
            ok "User All_Regions.ini updated."
        else
            info "Appending FullScreenShortcutSupport section to user All_Regions.ini..."
            cat >> "$user_ini" <<'CITRIX'

[Client Engine\Application Launching]
FullScreenShortcutSupport=*
CITRIX
            ok "User All_Regions.ini updated."
        fi
    fi

    ok "Ctrl+F2 fullscreen toggle enabled."
}

install_optional_packages() {
    info "Optional packages:"
    echo ""

    local i=1
    for entry in "${OPTIONAL_PACKAGES[@]}"; do
        local label="${entry%%|*}"
        local pkg="${entry#*|}" ; pkg="${pkg%%|*}"
        local status=""
        if _is_pkg_installed "$pkg"; then
            status=" ${GREEN}(installed)${NC}"
        fi
        echo -e "    ${BOLD}${i})${NC}  ${label}${status}"
        ((i++))
    done

    echo ""
    echo -e "    ${BOLD}0)${NC}  Skip — install none"
    echo ""

    local reply
    read -rp "$(echo -e "${YELLOW}[????]${NC}  Enter numbers separated by spaces (e.g. 1 3): ")" reply

    # Skip if empty or 0
    if [[ -z "$reply" || "$reply" == "0" ]]; then
        ok "Skipping optional packages."
        return
    fi

    local -a repos_added=()
    local -a pkgs_to_install=()

    for num in $reply; do
        # Validate
        if [[ ! "$num" =~ ^[0-9]+$ ]] || (( num < 1 || num > ${#OPTIONAL_PACKAGES[@]} )); then
            warn "Ignoring invalid selection: ${num}"
            continue
        fi

        local entry="${OPTIONAL_PACKAGES[$((num-1))]}"
        local label="${entry%%|*}"
        local rest="${entry#*|}"
        local pkg="${rest%%|*}"
        local repo_fn="${rest#*|}"

        # Skip if already installed
        if _is_pkg_installed "$pkg"; then
            ok "${label} already installed."
            continue
        fi

        # Handle virtual packages (editors and tools)
        case "$pkg" in
            @tmux)
                OPT_WITH_TMUX=true
                ok "Tmux selected — will install with plugin manager."
                continue
                ;;
            @neovim)
                OPT_WITH_NEOVIM=true
                ok "Neovim selected — will install from GitHub."
                continue
                ;;
            @emacs)
                OPT_WITH_EMACS=true
                ok "Emacs + Doom selected — will install with dependencies."
                continue
                ;;
        esac

        # Set up external repo if needed
        if [[ -n "$repo_fn" ]]; then
            "$repo_fn"
            repos_added+=("$pkg")
        fi

        pkgs_to_install+=("$pkg")
    done

    if [[ ${#pkgs_to_install[@]} -eq 0 && "$OPT_WITH_NEOVIM" != true && "$OPT_WITH_EMACS" != true && "$OPT_WITH_TMUX" != true ]]; then
        ok "Nothing to install."
        return
    fi

    # Refresh apt if repos were added
    if [[ ${#repos_added[@]} -gt 0 ]]; then
        sudo apt update -qq
    fi

    if [[ ${#pkgs_to_install[@]} -gt 0 ]]; then
        install_missing_packages "${pkgs_to_install[@]}"
    fi
}

# Check if a package (real or virtual) is installed
_is_pkg_installed() {
    local pkg="$1"
    case "$pkg" in
        @tmux)   command -v tmux &>/dev/null ;;
        @neovim) command -v nvim &>/dev/null ;;
        @emacs)  command -v emacs &>/dev/null ;;
        *)       dpkg -s "$pkg" &>/dev/null ;;
    esac
}

# -- Remove lightdm -----------------------------------------------------------

remove_lightdm() {
    if dpkg -s lightdm &>/dev/null; then
        info "lightdm display manager is installed."
        info "This setup uses console login → startx → i3 (no display manager)."
        if ask_yes_no "Remove lightdm and lightdm-gtk-greeter?"; then
            info "Removing lightdm display manager..."
            sudo apt remove --purge -y lightdm lightdm-gtk-greeter 2>/dev/null || true
            sudo apt autoremove --purge -y
            ok "lightdm removed."
        else
            warn "Keeping lightdm. Console login via startx will still be configured,"
            warn "but lightdm may start instead on boot."
        fi
    else
        ok "lightdm not installed."
    fi
}

# -- Neovim from GitHub releases ---------------------------------------------
# Default:       install if missing, skip if present
# --nvim-update: install or update to latest
# --nvim-rollback: restore /opt/nvim-linux-x86_64.prev

get_nvim_latest_version() {
    curl -sI https://github.com/neovim/neovim/releases/latest \
        | grep -i '^location:' | grep -oP 'v[\d.]+' | head -1 || true
}

get_nvim_current_version() {
    if command -v nvim &>/dev/null; then
        nvim --version | head -1 | grep -oP 'v[\d.]+' || true
    fi
}

install_neovim() {
    info "Checking Neovim..."

    # Already installed → skip (default mode = install only)
    if command -v nvim &>/dev/null; then
        local current
        current=$(get_nvim_current_version)
        ok "Neovim ${current} already installed. Use --nvim-update to upgrade."
        return
    fi

    info "Installing Neovim..."
    _download_and_install_nvim
}

update_neovim() {
    info "Checking for Neovim updates..."

    local latest_version current_version
    latest_version=$(get_nvim_latest_version)
    current_version=$(get_nvim_current_version)

    if [[ -z "$latest_version" ]]; then
        err "Could not determine latest Neovim version."
        return 1
    fi

    if [[ "$current_version" == "$latest_version" ]]; then
        ok "Neovim ${current_version} is already the latest."
        return
    fi

    if [[ -n "$current_version" ]]; then
        info "Updating Neovim: ${current_version} → ${latest_version}"
        # Save current as rollback
        if [[ -d "$NVIM_INSTALL_DIR" ]]; then
            info "Saving current version to ${NVIM_PREV_DIR} for rollback..."
            sudo rm -rf "$NVIM_PREV_DIR"
            sudo mv "$NVIM_INSTALL_DIR" "$NVIM_PREV_DIR"
        fi
    else
        info "Installing Neovim ${latest_version}..."
    fi

    _download_and_install_nvim
}

rollback_neovim() {
    info "Rolling back Neovim..."

    if [[ ! -d "$NVIM_PREV_DIR" ]]; then
        err "No previous version found at ${NVIM_PREV_DIR}."
        err "Rollback is only available after --nvim-update."
        return 1
    fi

    local prev_version
    prev_version=$("${NVIM_PREV_DIR}/bin/nvim" --version 2>/dev/null | head -1 | grep -oP 'v[\d.]+') || true
    info "Restoring previous version: ${prev_version:-unknown}"

    sudo rm -rf "$NVIM_INSTALL_DIR"
    sudo mv "$NVIM_PREV_DIR" "$NVIM_INSTALL_DIR"
    sudo ln -sf "${NVIM_INSTALL_DIR}/bin/nvim" "$NVIM_SYMLINK"

    local restored
    restored=$(nvim --version | head -1)
    ok "Neovim rolled back: ${restored}"
}

_download_and_install_nvim() {
    local latest_url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
    local tmp_tar
    tmp_tar=$(mktemp /tmp/nvim-XXXXXX.tar.gz)

    curl -Lo "$tmp_tar" "$latest_url"

    sudo rm -rf "$NVIM_INSTALL_DIR"
    sudo mkdir -p "$NVIM_INSTALL_DIR"
    sudo chmod a+rX "$NVIM_INSTALL_DIR"
    sudo tar -C /opt -xzf "$tmp_tar"
    sudo ln -sf "${NVIM_INSTALL_DIR}/bin/nvim" "$NVIM_SYMLINK"

    rm -f "$tmp_tar"

    local installed
    installed=$(nvim --version | head -1)
    ok "Neovim installed: ${installed}"
}

# -- tree-sitter CLI (npm global) --------------------------------------------

install_treesitter_cli() {
    if command -v tree-sitter &>/dev/null; then
        ok "tree-sitter-cli already installed."
        return
    fi

    info "Installing tree-sitter-cli globally via npm..."
    sudo npm install -g tree-sitter-cli
    ok "tree-sitter-cli installed."
}

# -- Nerd Fonts from GitHub releases ------------------------------------------
# Not packaged in Debian — downloaded from ryanoasis/nerd-fonts

NERD_FONTS=(
    "CascadiaMono"
)
NERD_FONT_DIR="${HOME}/.local/share/fonts/NerdFonts"

MONASPACE_FONT_DIR="${HOME}/.local/share/fonts/Monaspace"
MONASPACE_FAMILIES=(
    "Argon"
    "Krypton"
    "Neon"
    "Radon"
    "Xenon"
)

install_nerd_fonts() {
    info "Checking Nerd Fonts..."

    local base_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
    local -a to_install=()

    for font in "${NERD_FONTS[@]}"; do
        if [[ -d "${NERD_FONT_DIR}/${font}" ]] && ls "${NERD_FONT_DIR}/${font}"/*.ttf &>/dev/null; then
            ok "${font} Nerd Font already installed."
        else
            to_install+=("$font")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        return
    fi

    mkdir -p "$NERD_FONT_DIR"

    for font in "${to_install[@]}"; do
        info "Downloading ${font} Nerd Font..."
        local tmp_tar
        tmp_tar=$(mktemp /tmp/nf-XXXXXX.tar.xz)
        local font_dir="${NERD_FONT_DIR}/${font}"

        if curl -fLo "$tmp_tar" "${base_url}/${font}.tar.xz"; then
            mkdir -p "$font_dir"
            tar -xJf "$tmp_tar" -C "$font_dir"
            rm -f "$tmp_tar"
            ok "${font} Nerd Font installed to ${font_dir}."
        else
            err "Failed to download ${font}. Check the font name and your connection."
            rm -f "$tmp_tar"
        fi
    done

    # Rebuild font cache
    info "Rebuilding font cache..."
    fc-cache -f "$NERD_FONT_DIR"
    ok "Font cache updated."
}

# -- Monaspace fonts from GitHub releases -------------------------------------
# Five-variant monospaced superfamily for code (OFL-licensed)
# Families: Argon, Krypton, Neon, Radon, Xenon
# https://monaspace.githubnext.com/

install_monaspace_fonts() {
    info "Checking Monaspace fonts..."

    # Quick check: if all 5 families have OTF files, skip
    local -a missing=()
    for family in "${MONASPACE_FAMILIES[@]}"; do
        if ! ls "${MONASPACE_FONT_DIR}"/Monaspace${family}*.otf &>/dev/null 2>&1; then
            missing+=("$family")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        ok "All Monaspace fonts already installed (Argon, Krypton, Neon, Radon, Xenon)."
        return
    fi

    # Get latest release tag via GitHub redirect
    local tag
    tag=$(curl -sI https://github.com/githubnext/monaspace/releases/latest \
        | grep -i '^location:' | grep -oP 'v[\d.]+' | head -1) || true

    if [[ -z "$tag" ]]; then
        err "Could not determine latest Monaspace version."
        return 1
    fi

    info "Downloading Monaspace ${tag} (OTF static fonts)..."

    local tmp_zip
    tmp_zip=$(mktemp /tmp/monaspace-XXXXXX.zip)

    # v1.300+ uses split packages; fall back to single zip for older releases
    local url="https://github.com/githubnext/monaspace/releases/download/${tag}/monaspace-static-${tag}.zip"

    if ! curl -fLo "$tmp_zip" "$url"; then
        info "Split package not found, trying single-archive format..."
        url="https://github.com/githubnext/monaspace/releases/download/${tag}/monaspace-${tag}.zip"
        if ! curl -fLo "$tmp_zip" "$url"; then
            err "Failed to download Monaspace. Check the release and your connection."
            rm -f "$tmp_zip"
            return 1
        fi
    fi

    # Extract OTF files into font directory
    local tmp_extract
    tmp_extract=$(mktemp -d /tmp/monaspace-extract-XXXXXX)

    unzip -qo "$tmp_zip" -d "$tmp_extract"
    rm -f "$tmp_zip"

    mkdir -p "$MONASPACE_FONT_DIR"

    # Find and copy all OTF files (static desktop fonts — all families × weights)
    local otf_count=0
    while IFS= read -r -d '' otf; do
        cp "$otf" "$MONASPACE_FONT_DIR/"
        ((++otf_count))
    done < <(find "$tmp_extract" -name '*.otf' -print0)

    rm -rf "$tmp_extract"

    if [[ "$otf_count" -eq 0 ]]; then
        err "No OTF files found in the Monaspace archive."
        return 1
    fi

    ok "Installed ${otf_count} Monaspace font files to ${MONASPACE_FONT_DIR}."

    # Rebuild font cache
    info "Rebuilding font cache..."
    fc-cache -f "$MONASPACE_FONT_DIR"
    ok "Font cache updated."
}

# -- Tmux plugin manager ------------------------------------------------------
# Debian package tmux-plugin-manager installs tpm to a system path.
# Plugins must still go in ~/.tmux/plugins/ — we need to ensure that
# TMUX_PLUGIN_MANAGER_PATH is set and the directory exists.

migrate_tpm() {
    info "Configuring tmux plugin manager..."

    # tmux-plugin-manager is already in the package list, so it's installed.
    local tpm_pkg_dir
    tpm_pkg_dir=$(dpkg -L tmux-plugin-manager 2>/dev/null \
        | grep '/tpm$' | head -1 | xargs dirname 2>/dev/null) || true

    if [[ -z "$tpm_pkg_dir" ]]; then
        warn "Could not determine tpm package path, skipping."
        return
    fi

    ok "Debian tpm directory: ${tpm_pkg_dir}"

    # tpm determines its plugin install dir from its own script location.
    # When it runs from /usr/share/..., it tries to install plugins there
    # (needs root → silently fails → prefix+I broken).
    #
    # Fix: symlink the Debian tpm dir into ~/.tmux/plugins/tpm so tpm thinks
    # it lives in the user dir and installs sibling plugins to ~/.tmux/plugins/.
    local user_tpm_dir="${TMUX_PLUGIN_DIR}/tpm"

    mkdir -p "$TMUX_PLUGIN_DIR"

    if [[ -L "$user_tpm_dir" ]]; then
        local current_target
        current_target=$(readlink -f "$user_tpm_dir")
        if [[ "$current_target" == "$(readlink -f "$tpm_pkg_dir")" ]]; then
            ok "Symlink already correct: ${user_tpm_dir} → ${tpm_pkg_dir}"
        else
            info "Updating symlink: ${user_tpm_dir} → ${tpm_pkg_dir}"
            ln -sfn "$tpm_pkg_dir" "$user_tpm_dir"
            ok "Symlink updated."
        fi
    elif [[ -d "$user_tpm_dir/.git" ]]; then
        # Old git clone — replace with symlink
        info "Replacing old git-cloned tpm with symlink to Debian package..."
        rm -rf "$user_tpm_dir"
        ln -sfn "$tpm_pkg_dir" "$user_tpm_dir"
        ok "Old clone replaced with symlink."
    elif [[ -d "$user_tpm_dir" ]]; then
        warn "${user_tpm_dir} exists but is not a symlink or git clone."
        warn "Remove it manually if tpm isn't working."
    else
        info "Creating symlink: ${user_tpm_dir} → ${tpm_pkg_dir}"
        ln -sfn "$tpm_pkg_dir" "$user_tpm_dir"
        ok "Symlink created."
    fi

    # tmux.conf should use the standard run line:
    #   run '~/.tmux/plugins/tpm/tpm'
    # which now follows the symlink to the Debian package.

    # If tmux.conf was previously patched to use the Debian path directly,
    # revert it to the standard path.
    # IMPORTANT: skip if tmux.conf is a symlink (stow-managed) — sed -i
    # replaces symlinks with regular files, which breaks stow on re-runs.
    # If the content needs fixing, edit the source file in the dotfiles repo.
    if [[ -f "$TMUX_CONF" && ! -L "$TMUX_CONF" ]]; then
        if grep -q "run '${tpm_pkg_dir}/tpm'" "$TMUX_CONF"; then
            info "Reverting tmux.conf run line to standard tpm path..."
            sed -i "s|^run '${tpm_pkg_dir}/tpm'|run '~/.tmux/plugins/tpm/tpm'|" "$TMUX_CONF"
            ok "tmux.conf restored to standard tpm path."
        fi

        # Clean up set-environment line if a previous run added it
        if grep -q 'TMUX_PLUGIN_MANAGER_PATH' "$TMUX_CONF"; then
            info "Removing TMUX_PLUGIN_MANAGER_PATH (no longer needed with symlink)..."
            sed -i '/TMUX_PLUGIN_MANAGER_PATH/d' "$TMUX_CONF"
            ok "Removed TMUX_PLUGIN_MANAGER_PATH line."
        fi
    elif [[ -L "$TMUX_CONF" ]]; then
        ok "tmux.conf is managed by stow — skipping content patches."
    fi

    warn "After setup, reload tmux config:  tmux source ~/.tmux.conf"
    warn "Then install plugins:             prefix + I"
}

# -- HiDPI detection and setup -----------------------------------------------

detect_hidpi() {
    # Check connected displays for high resolution (>= 2560 width)
    if command -v xrandr &>/dev/null; then
        local max_width
        max_width=$(xrandr --current 2>/dev/null \
            | grep -oP '\d+x\d+' | head -5 \
            | awk -Fx '{print $1}' | sort -rn | head -1) || true
        if [[ -n "$max_width" && "$max_width" -ge 2560 ]]; then
            return 0
        fi
    fi

    # Fallback: check for known HiDPI panel via sysfs
    local panel_width
    for edid_dir in /sys/class/drm/card*-*/; do
        if [[ -f "${edid_dir}modes" ]]; then
            panel_width=$(head -1 "${edid_dir}modes" 2>/dev/null \
                | grep -oP '^\d+') || true
            if [[ -n "$panel_width" && "$panel_width" -ge 2560 ]]; then
                return 0
            fi
        fi
    done

    return 1
}

setup_hidpi_grub() {
    info "Setting up HiDPI GRUB font..."

    if [[ ! -f "$GRUB_FONT_SRC" ]]; then
        warn "DejaVu Sans Mono not found at ${GRUB_FONT_SRC}."
        warn "Install fonts-dejavu-core and re-run."
        return
    fi

    # Generate larger GRUB font
    sudo grub-mkfont \
        --output="$GRUB_FONT_PATH" \
        --size="$GRUB_FONT_SIZE" \
        "$GRUB_FONT_SRC"
    ok "Generated GRUB font: ${GRUB_FONT_PATH}"

    # Patch /etc/default/grub
    local grub_default="/etc/default/grub"
    local needs_update=false

    # GRUB_GFXMODE
    if grep -q '^GRUB_GFXMODE=' "$grub_default"; then
        if ! grep -q "^GRUB_GFXMODE=${GRUB_GFXMODE}" "$grub_default"; then
            sudo sed -i "s|^GRUB_GFXMODE=.*|GRUB_GFXMODE=${GRUB_GFXMODE}|" "$grub_default"
            needs_update=true
        fi
    elif grep -q '^#GRUB_GFXMODE=' "$grub_default"; then
        sudo sed -i "s|^#GRUB_GFXMODE=.*|GRUB_GFXMODE=${GRUB_GFXMODE}|" "$grub_default"
        needs_update=true
    else
        echo "GRUB_GFXMODE=${GRUB_GFXMODE}" | sudo tee -a "$grub_default" >/dev/null
        needs_update=true
    fi

    # GRUB_FONT
    if grep -q '^GRUB_FONT=' "$grub_default"; then
        if ! grep -q "^GRUB_FONT=${GRUB_FONT_PATH}" "$grub_default"; then
            sudo sed -i "s|^GRUB_FONT=.*|GRUB_FONT=${GRUB_FONT_PATH}|" "$grub_default"
            needs_update=true
        fi
    elif grep -q '^#GRUB_FONT=' "$grub_default"; then
        sudo sed -i "s|^#GRUB_FONT=.*|GRUB_FONT=${GRUB_FONT_PATH}|" "$grub_default"
        needs_update=true
    else
        echo "GRUB_FONT=${GRUB_FONT_PATH}" | sudo tee -a "$grub_default" >/dev/null
        needs_update=true
    fi

    # GRUB_TERMINAL_OUTPUT
    if ! grep -q '^GRUB_TERMINAL_OUTPUT=.*gfxterm' "$grub_default"; then
        if grep -q '^GRUB_TERMINAL_OUTPUT=' "$grub_default"; then
            sudo sed -i 's|^GRUB_TERMINAL_OUTPUT=.*|GRUB_TERMINAL_OUTPUT="gfxterm"|' "$grub_default"
        elif grep -q '^#GRUB_TERMINAL_OUTPUT=' "$grub_default"; then
            sudo sed -i 's|^#GRUB_TERMINAL_OUTPUT=.*|GRUB_TERMINAL_OUTPUT="gfxterm"|' "$grub_default"
        else
            echo 'GRUB_TERMINAL_OUTPUT="gfxterm"' | sudo tee -a "$grub_default" >/dev/null
        fi
        needs_update=true
    fi

    if [[ "$needs_update" == true ]]; then
        sudo update-grub
        ok "GRUB updated for HiDPI."
    else
        ok "GRUB already configured for HiDPI."
    fi
}

setup_hidpi_desktop() {
    info "Setting up HiDPI desktop scaling via xrandr..."

    local expected_mode="2048x1152"
    local created_file=false

    if [[ -f "$XRANDR_FILE" ]]; then
        # Verify the file contains the expected resolution
        if grep -q -- "--mode ${expected_mode}" "$XRANDR_FILE"; then
            ok "${XRANDR_FILE} already configured (mode: ${expected_mode})."
        else
            local current_mode
            current_mode=$(grep -oP -- '--mode\s+\S+' "$XRANDR_FILE" | head -1) || true
            warn "${XRANDR_FILE} exists but uses ${current_mode:-an unknown mode}."
            info "Edit it manually or run --hidpi-revert then --hidpi to reset."
            return
        fi
    else
        sudo mkdir -p "$(dirname "$XRANDR_FILE")"

        info "Creating ${XRANDR_FILE}..."
        sudo tee "$XRANDR_FILE" >/dev/null <<'EOF'
# Reduced resolution for 4K Display
xrandr --newmode "2304x1296"  251.25  2304 2464 2712 3120  1296 1299 1304 1344 -hsync +vsync
xrandr --addmode eDP-1 2304x1296
xrandr --output eDP-1 --mode 2048x1152
EOF
        sudo chmod 644 "$XRANDR_FILE"
        created_file=true
        ok "Created ${XRANDR_FILE}."
    fi

    # Apply xrandr settings to the current X session so the user sees
    # the effect immediately — not only after reboot/relogin.
    if [[ -n "${DISPLAY:-}" ]]; then
        local current_res
        current_res=$(xrandr --current 2>/dev/null \
            | grep '\*' | head -1 | grep -oP '\d+x\d+') || true

        if [[ "$current_res" == "$expected_mode" ]]; then
            ok "Current resolution is already ${expected_mode}."
        else
            info "Applying xrandr settings to current session..."
            # newmode/addmode may fail if already defined — that's fine
            xrandr --newmode "2304x1296" 251.25 2304 2464 2712 3120 1296 1299 1304 1344 -hsync +vsync 2>/dev/null || true
            xrandr --addmode eDP-1 2304x1296 2>/dev/null || true

            if xrandr --output eDP-1 --mode "$expected_mode" 2>/dev/null; then
                ok "Resolution changed to ${expected_mode}."
            else
                warn "Could not apply resolution — your output may not be eDP-1."
                info "Run 'xrandr' to list outputs and edit ${XRANDR_FILE} accordingly."
            fi
        fi
    elif [[ "$created_file" == true ]]; then
        warn "No X session detected. Resolution will change on next login."
    fi
}

revert_hidpi() {
    info "Reverting HiDPI settings..."

    # 1. Remove xrandr Xsession.d script
    if [[ -f "$XRANDR_FILE" ]]; then
        sudo rm -f "$XRANDR_FILE"
        ok "Removed ${XRANDR_FILE}."
    else
        ok "No xrandr file to remove."
    fi

    # 2. Revert GRUB settings
    local grub_default="/etc/default/grub"
    local grub_changed=false

    if grep -q "^GRUB_FONT=" "$grub_default"; then
        sudo sed -i '/^GRUB_FONT=/d' "$grub_default"
        grub_changed=true
    fi
    if grep -q "^GRUB_GFXMODE=" "$grub_default"; then
        sudo sed -i 's|^GRUB_GFXMODE=.*|#GRUB_GFXMODE=auto|' "$grub_default"
        grub_changed=true
    fi
    if grep -q '^GRUB_TERMINAL_OUTPUT="gfxterm"' "$grub_default"; then
        sudo sed -i 's|^GRUB_TERMINAL_OUTPUT="gfxterm"|#GRUB_TERMINAL_OUTPUT=console|' "$grub_default"
        grub_changed=true
    fi

    if [[ "$grub_changed" == true ]]; then
        sudo update-grub
        ok "GRUB reverted to defaults."
    fi

    # 3. Remove custom GRUB font
    if [[ -f "$GRUB_FONT_PATH" ]]; then
        sudo rm -f "$GRUB_FONT_PATH"
        ok "Removed custom GRUB font."
    fi

    ok "HiDPI settings reverted. Reboot to apply."
}

# -- Stow pre-cleanup ---------------------------------------------------------
# Remove existing real files at stow targets so symlinks can be created.
# With --no-folding, stow creates individual file symlinks.  We check each
# file that stow would deploy and back up any real (non-symlink) target.

cleanup_for_stow() {
    info "Checking for files that would conflict with stow..."

    local -a conflicts=()

    # For every file in the repo that stow would deploy, check whether the
    # corresponding path under $HOME is a real file (not a symlink).
    while IFS= read -r -d '' rel_path; do
        local target="${HOME}/${rel_path}"

        # No file at target → no conflict
        [[ -e "$target" || -L "$target" ]] || continue

        # Already a symlink (from a previous stow run) → no conflict
        [[ -L "$target" ]] && continue

        # Real file exists where stow needs to create a symlink → conflict
        conflicts+=("$target")
    done < <(
        cd "$DOTFILES_DIR" && \
        find . -mindepth 1 \
            -not -path './.git/*' \
            -not -path './.git' \
            -not -name 'setup-debian13.sh' \
            -not -name 'README.md' \
            -not -name '.gitignore' \
            -not -name '.gitmodules' \
            -type f -printf '%P\0'
    )

    if [[ ${#conflicts[@]} -eq 0 ]]; then
        ok "No conflicting files found. Ready for stow."
        return
    fi

    info "Found ${#conflicts[@]} file(s) that would block stow:"
    for c in "${conflicts[@]}"; do
        echo "         $c"
    done

    if ! ask_yes_no "Back up and remove these so stow can create symlinks?"; then
        warn "Skipping cleanup. You may need to remove them manually before stow."
        return
    fi

    local backup_dir="${HOME}/.stow-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    info "Backing up to ${backup_dir}/ ..."

    for path in "${conflicts[@]}"; do
        local rel="${path#"${HOME}"/}"
        local parent
        parent=$(dirname "$rel")
        mkdir -p "${backup_dir}/${parent}"
        mv "$path" "${backup_dir}/${rel}"
        ok "  moved: ~/${rel}"
    done

    ok "Backup complete. Paths are clear for stow."
}

# -- Dotfiles: clone + stow --------------------------------------------------

deploy_dotfiles() {
    info "Deploying dotfiles from ${DOTFILES_DIR}..."

    # Verify we're in a git repo
    if [[ ! -d "${DOTFILES_DIR}/.git" ]]; then
        err "Not a git repo: ${DOTFILES_DIR}"
        err "Clone the dotfiles repo first, then run this script from inside it."
        return 1
    fi

    info "Running stow..."

    # Use -d (stow directory = parent) and package name (basename) rather
    # than `cd dir && stow .` — the "." package means stow dir and package
    # are the same thing, which breaks relative symlink path computation.
    local stow_parent stow_pkg
    stow_parent="$(dirname "$DOTFILES_DIR")"
    stow_pkg="$(basename "$DOTFILES_DIR")"

    # --no-folding: never replace a real directory with a symlink.
    # Without this, stow may "fold" ~/.config into a single symlink
    # to .dotfiles/.config, destroying configs for Firefox, Thunar, etc.
    # --restow: first unstow then restow — cleans up stale symlinks from
    # renamed/deleted files and ensures a consistent state on re-runs.
    # --ignore: stow's default ignore list covers .git, .gitignore, and
    # README.* — but NOT .gitmodules or setup-debian13.sh.  Exclude both.
    stow -d "$stow_parent" \
        --no-folding --restow \
        --ignore='setup-debian13\.sh' \
        --ignore='\.gitmodules' \
        -v -t "$HOME" \
        "$stow_pkg"

    ok "Dotfiles deployed via stow."
}

# -- Doom Emacs ---------------------------------------------------------------
# Doom needs: emacs, git, ripgrep, fd-find (all in package list)
# Must run AFTER stow deploys ~/.config/doom/
#
# Detection: checking bin/doom alone is not enough — git clone creates it,
# but doom isn't usable until `doom install` completes (creates .local/).

install_doom_emacs() {
    local doom_bin="${DOOM_EMACS_DIR}/bin/doom"

    if ! command -v emacs &>/dev/null; then
        warn "Emacs not found, skipping Doom install."
        return
    fi

    # Verify doom config is in place (from stow)
    if [[ ! -f "${HOME}/.config/doom/init.el" ]]; then
        warn "~/.config/doom/init.el not found — deploy dotfiles first."
        return
    fi

    # Stop the daemon — it may be running with stale/broken config.
    # We never restart it here; setup_emacs_daemon() will enable it
    # for the next boot/login so it starts with a clean, fully-built state.
    _stop_emacs_daemon

    # Detection: doom creates .local/straight/build-<hash>/ only after
    # packages are successfully built. The .local/ dir alone can exist
    # from a failed or interrupted install.
    local straight_builds="${DOOM_EMACS_DIR}/.local/straight"

    if [[ -x "$doom_bin" && -d "$straight_builds" ]] \
       && ls "${straight_builds}"/build-* &>/dev/null; then
        ok "Doom Emacs already installed."
        info "Running doom sync to pick up config changes..."
        "$doom_bin" sync
        return
    fi

    # Repo cloned but install incomplete — re-run doom install (no re-clone)
    if [[ -x "$doom_bin" ]]; then
        warn "Doom repo present but install incomplete — re-running doom install..."
        "$doom_bin" install
        info "Running doom sync to finalize..."
        "$doom_bin" sync
        ok "Doom Emacs installed."
        return
    fi

    # Nothing there — fresh clone + install
    if [[ -d "$DOOM_EMACS_DIR" ]]; then
        warn "Removing broken ${DOOM_EMACS_DIR} to start fresh..."
        rm -rf "$DOOM_EMACS_DIR"
    fi

    info "Cloning Doom Emacs..."
    git clone --depth 1 "$DOOM_EMACS_REPO" "$DOOM_EMACS_DIR"

    info "Running doom install (this may take a few minutes)..."
    "$doom_bin" install

    # doom sync after install ensures all packages are fully built
    # and native-compiled — without this, first boot often breaks
    info "Running doom sync to finalize..."
    "$doom_bin" sync

    ok "Doom Emacs installed."
    info "Doom binary: ${doom_bin}"
}

# Helper: stop emacs daemon before doom operations
_stop_emacs_daemon() {
    if systemctl --user is-active --quiet emacs 2>/dev/null; then
        info "Stopping emacs daemon for doom operations..."
        systemctl --user stop emacs
    fi
}

# -- Emacs daemon (systemd user service) -------------------------------------

setup_emacs_daemon() {
    info "Configuring Emacs daemon..."

    if ! command -v emacs &>/dev/null; then
        warn "Emacs not found, skipping daemon setup."
        return
    fi

    # Check if the stock systemd unit exists (Debian ships one with emacs)
    if [[ -f /usr/lib/systemd/user/emacs.service ]]; then
        ok "Found system emacs.service unit."
    else
        local unit_dir="${HOME}/.config/systemd/user"
        local unit_file="${unit_dir}/emacs.service"

        if [[ ! -f "$unit_file" ]]; then
            info "Creating ${unit_file}..."
            mkdir -p "$unit_dir"
            cat > "$unit_file" <<'EOF'
[Unit]
Description=Emacs text editor (daemon)
Documentation=info:emacs man:emacs(1) https://gnu.org/software/emacs/

[Service]
Type=notify
ExecStart=/usr/bin/emacs --fg-daemon
ExecStop=/usr/bin/emacsclient --eval "(kill-emacs)"
Restart=on-failure

[Install]
WantedBy=default.target
EOF
            ok "Created emacs.service unit."
        fi
    fi

    systemctl --user daemon-reload
    systemctl --user enable emacs

    # Don't start the daemon now — doom install/sync just finished and
    # native compilation may still be settling. The daemon will start
    # cleanly on next login/reboot with all packages fully built.
    ok "Emacs daemon enabled (will start on next login)."
    info "Connect with: emacsclient -c"
}

# -- Julia (via juliaup — user-level install) --------------------------------

install_julia() {
    info "Checking Julia..."

    if command -v juliaup &>/dev/null; then
        ok "juliaup already installed."
        info "Updating Julia channels..."
        juliaup update || true
        local jv
        jv=$(julia --version 2>/dev/null) || true
        [[ -n "$jv" ]] && ok "$jv"
        return
    fi

    info "Installing Julia via juliaup (user-level)..."
    # juliaup installer — installs to ~/.juliaup, adds to PATH
    curl -fsSL "$JULIA_INSTALL_SCRIPT" | sh -s -- --yes

    # Source the updated PATH so julia is available for the rest of this script
    export PATH="${HOME}/.juliaup/bin:${PATH}"

    if command -v julia &>/dev/null; then
        local jv
        jv=$(julia --version)
        ok "Julia installed: ${jv}"
        ok "Managed by juliaup — run 'juliaup status' to see channels."
    else
        warn "Julia installed but not in PATH yet. Restart your shell."
    fi
}

# -- startx / i3 login -------------------------------------------------------
# Console login on tty1 → automatic startx → i3

setup_startx_login() {
    info "Setting up console login → startx → i3..."

    # 1. Create ~/.xinitrc
    local xinitrc="${HOME}/.xinitrc"
    local needs_xinitrc=false

    if [[ -f "$xinitrc" ]]; then
        if grep -q 'exec i3' "$xinitrc"; then
            ok "${xinitrc} already starts i3."
        else
            warn "${xinitrc} exists but doesn't exec i3 — leaving it alone."
        fi
    else
        needs_xinitrc=true
    fi

    if [[ "$needs_xinitrc" == true ]]; then
        info "Creating ${xinitrc}..."
        cat > "$xinitrc" <<'EOF'
#!/bin/sh

# Source Xsession.d scripts (HiDPI xrandr, etc.)
if [ -d /etc/X11/Xsession.d ]; then
    for f in /etc/X11/Xsession.d/*; do
        [ -f "$f" ] && . "$f"
    done
fi

# Export DISPLAY to systemd user session so user services
# (e.g. emacs daemon) can open graphical frames.
# Without a display manager, systemd doesn't know about DISPLAY.
systemctl --user import-environment DISPLAY XAUTHORITY
systemctl --user start default.target

exec i3
EOF
        chmod +x "$xinitrc"
        ok "Created ${xinitrc}."
    fi

    # Patch existing xinitrc if it's missing the systemd import
    # Skip if xinitrc is a stow symlink — sed -i destroys symlinks.
    if [[ -f "$xinitrc" && ! -L "$xinitrc" ]] && ! grep -q 'import-environment DISPLAY' "$xinitrc"; then
        info "Adding systemd DISPLAY import to ${xinitrc}..."
        sed -i '/^exec i3/i \
# Export DISPLAY to systemd user session so user services\
# (e.g. emacs daemon) can open graphical frames.\
systemctl --user import-environment DISPLAY XAUTHORITY\
systemctl --user start default.target\
' "$xinitrc"
        ok "systemd DISPLAY import added to ${xinitrc}."
    fi

    # 2. Ensure .profile has startx block for tty1
    local profile="${HOME}/.profile"
    local startx_marker="# Start X on tty1"

    if [[ -f "$profile" ]] && grep -qF "$startx_marker" "$profile"; then
        ok ".profile already has startx block."
    elif [[ -L "$profile" ]]; then
        # .profile is a stow symlink — cat >> would modify the repo source.
        # The startx block should be added to the dotfiles repo instead.
        if ! grep -qF "$startx_marker" "$profile"; then
            warn ".profile is managed by stow but missing the startx block."
            warn "Add the startx block to .profile in your dotfiles repo."
        fi
    elif [[ -f "$profile" ]]; then
        info "Appending startx block to .profile..."
        cat >> "$profile" <<'EOF'

# Start X on tty1
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx
fi
EOF
        ok "startx block added to .profile."
    else
        warn ".profile not found — create it or deploy dotfiles first."
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"

    # -- Standalone actions (run and exit) ------------------------------------

    if [[ "$OPT_HIDPI_HELP" == true ]]; then
        show_hidpi_help
        exit 0
    fi

    if [[ "$OPT_HIDPI_REVERT" == true ]]; then
        need_root
        revert_hidpi
        exit 0
    fi

    if [[ "$OPT_NVIM_ROLLBACK" == true ]]; then
        need_root
        rollback_neovim
        exit 0
    fi

    # --hidpi without --install → standalone HiDPI setup
    if [[ "$OPT_HIDPI" == true && "$OPT_INSTALL" != true ]]; then
        need_root
        info "--- HiDPI (standalone) ---"
        local do_hidpi=false

        if detect_hidpi; then
            info "HiDPI display detected."
            if ask_yes_no "Apply HiDPI fixes (GRUB font + xrandr scaling)?"; then
                do_hidpi=true
            fi
        else
            info "No HiDPI display detected."
            if ask_yes_no "Apply HiDPI fixes anyway?"; then
                do_hidpi=true
            fi
        fi

        if [[ "$do_hidpi" == true ]]; then
            setup_hidpi_grub
            setup_hidpi_desktop
        else
            ok "No changes made."
        fi
        exit 0
    fi

    # No action flags → show help
    if [[ "$OPT_INSTALL" != true ]]; then
        show_help
        exit 0
    fi

    # -- Full setup -----------------------------------------------------------

    echo ""
    echo "==========================================="
    echo "  Debian 13 (Trixie) — i3wm Setup Script  "
    echo "==========================================="
    echo ""

    need_root

    # 1. Debian packages
    info "--- Debian Packages ---"
    install_missing_packages "${ALL_PACKAGES[@]}"
    echo ""

    # 2. Optional packages (interactive — includes editor/tool selection)
    info "--- Optional Packages ---"
    install_optional_packages
    echo ""

    # Auto-detect already-installed editors/tools so re-runs still maintain
    # them even if the user skips the optional selection prompt.
    command -v nvim  &>/dev/null && OPT_WITH_NEOVIM=true
    command -v emacs &>/dev/null && OPT_WITH_EMACS=true
    command -v tmux  &>/dev/null && OPT_WITH_TMUX=true

    # 3. Optional tool dependencies (apt packages for selected tools)
    if [[ "$OPT_WITH_TMUX" == true ]]; then
        info "--- Tmux Dependencies ---"
        install_missing_packages "${TMUX_DEPS[@]}"
        echo ""
    fi
    if [[ "$OPT_WITH_NEOVIM" == true ]]; then
        info "--- Neovim Dependencies ---"
        install_missing_packages "${NEOVIM_DEPS[@]}"
        echo ""
    fi
    if [[ "$OPT_WITH_EMACS" == true ]]; then
        info "--- Emacs Dependencies ---"
        install_missing_packages "${EMACS_DEPS[@]}"
        echo ""
    fi

    # 4. Remove lightdm
    info "--- Remove Display Manager ---"
    remove_lightdm
    echo ""

    # 5. Neovim
    if [[ "$OPT_WITH_NEOVIM" == true ]]; then
        info "--- Neovim (GitHub Release) ---"
        if [[ "$OPT_NVIM_UPDATE" == true ]]; then
            update_neovim
        else
            install_neovim
        fi
        echo ""

        # tree-sitter CLI (used by Neovim tree-sitter)
        info "--- tree-sitter CLI ---"
        install_treesitter_cli
        echo ""
    fi

    # 6. Nerd Fonts
    info "--- Nerd Fonts ---"
    install_nerd_fonts
    echo ""

    # 7. Monaspace fonts
    info "--- Monaspace Fonts ---"
    install_monaspace_fonts
    echo ""

    # 8. Tmux plugin manager
    if [[ "$OPT_WITH_TMUX" == true ]]; then
        info "--- Tmux Plugin Manager ---"
        migrate_tpm
        echo ""
    fi

    # 9. HiDPI setup
    info "--- HiDPI ---"
    if [[ "$OPT_HIDPI" == true ]]; then
        local do_hidpi=false

        if detect_hidpi; then
            info "HiDPI display detected."
            if ask_yes_no "Apply HiDPI fixes (GRUB font + xrandr scaling)?"; then
                do_hidpi=true
            fi
        else
            info "No HiDPI display detected."
            if ask_yes_no "Apply HiDPI fixes anyway?"; then
                do_hidpi=true
            fi
        fi

        if [[ "$do_hidpi" == true ]]; then
            setup_hidpi_grub
            setup_hidpi_desktop
        else
            ok "Skipping HiDPI setup."
        fi
    else
        ok "Skipping HiDPI setup (use --hidpi or --install --hidpi to configure)."
    fi
    echo ""

    # 10. Stow pre-cleanup
    info "--- Stow Pre-Cleanup ---"
    cleanup_for_stow
    echo ""

    # 11. Deploy dotfiles (stow from this repo)
    info "--- Dotfiles ---"
    deploy_dotfiles
    echo ""

    # 12. Doom Emacs (needs dotfiles for ~/.config/doom/, restarts daemon)
    if [[ "$OPT_WITH_EMACS" == true ]]; then
        info "--- Doom Emacs ---"
        install_doom_emacs
        echo ""

        # 13. Emacs daemon (enable for next boot — not started now)
        info "--- Emacs Daemon ---"
        setup_emacs_daemon
        echo ""
    fi

    # 14. Julia
    info "--- Julia ---"
    install_julia
    echo ""

    # 15. startx + i3 login
    info "--- Console Login → i3 ---"
    setup_startx_login
    echo ""

    # -- Summary --
    echo "==========================================="
    echo ""
    ok "Setup complete!"
    echo ""
    info "Post-install checklist:"
    echo "  • If this is a fresh install, reboot to use console login → startx → i3"
    echo "  • Verify i3 is the default: ${BOLD}sudo update-alternatives --config x-session-manager${NC}"
    echo "  • Set GTK theme/icons/fonts: ${BOLD}lxappearance${NC}"
    echo "  • Adjust compositor effects: ${BOLD}picom-conf${NC}"
    if [[ "$OPT_WITH_TMUX" == true ]]; then
        echo "  • Install tmux plugins (in a tmux session): ${BOLD}prefix + I${NC}"
    fi
    echo "  • Check Julia: ${BOLD}juliaup status${NC}"
    if [[ "$OPT_WITH_EMACS" == true ]]; then
        echo "  • Emacs daemon: ${BOLD}systemctl --user status emacs${NC}"
    fi
    echo "  • Run ${BOLD}./setup-debian13.sh${NC} for all available options"
    echo ""
}

main "$@"
