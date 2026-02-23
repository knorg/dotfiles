#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Debian 13 (Trixie) — i3wm Development Environment Setup
# Console login → startx → i3  (no display manager)
# Config: github.com/knorg/dotfiles.git  +  GNU Stow
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
OPT_HIDPI_SKIP=false
OPT_HIDPI_REVERT=false
OPT_HIDPI_HELP=false

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
            --nvim-update)    OPT_NVIM_UPDATE=true; OPT_INSTALL=true ;;
            --nvim-rollback)  OPT_NVIM_ROLLBACK=true ;;
            --hidpi-skip)     OPT_HIDPI_SKIP=true; OPT_INSTALL=true ;;
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
    --install           Run full setup (packages, dotfiles, doom, julia, etc.)
    --hidpi-skip        Full install but skip HiDPI configuration

  ${BOLD}Neovim${NC}
    --nvim-update       Full install + update Neovim to latest GitHub release
    --nvim-rollback     Rollback Neovim to previous version (standalone, exits)

  ${BOLD}HiDPI${NC}
    --hidpi-revert      Revert HiDPI settings (standalone, exits)
    --hidpi-help        Show how to change display resolution (standalone, exits)

  ${BOLD}General${NC}
    --help, -h          Show this help

${BOLD}Post-install reminders:${NC}
  • Reboot to use console login → startx → i3
  • Run ${BOLD}sudo update-alternatives --config x-session-manager${NC} to choose i3
  • Run ${BOLD}lxappearance${NC} to set the system-wide GTK theme, icons, and fonts
  • Run ${BOLD}picom-conf${NC} to adjust transparency, shadows, fading
  • In a tmux session: ${BOLD}prefix + I${NC} to install tmux plugins
  • Julia is managed by ${BOLD}juliaup${NC} — run ${BOLD}juliaup status${NC} to see installed versions

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
    tmux
    tmux-plugin-manager
    mc
    btop
    eza
    ripgrep
    fd-find
    xclip
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
    darkcold-gtk-theme
    darkfire-gtk-theme
    darkblood-gtk-theme
    numix-icon-theme
    papirus-icon-theme
    fonts-font-awesome
    fonts-symbola
    fonts-dejavu-core
    color-picker
)

DEV_TOOLS=(
    cmake
    libvterm-dev
    libtool-bin
    luarocks
    npm
    shellcheck
    markdown
)

EMACS=(
    emacs
)

HARDWARE=(
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
    "${EMACS[@]}"
    "${HARDWARE[@]}"
)

# -- Remove lightdm -----------------------------------------------------------

remove_lightdm() {
    if dpkg -s lightdm &>/dev/null; then
        info "Removing lightdm display manager..."
        sudo apt remove --purge -y lightdm lightdm-gtk-greeter 2>/dev/null || true
        sudo apt autoremove --purge -y
        ok "lightdm removed."
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
    if [[ -f "$TMUX_CONF" ]]; then
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

    if [[ -f "$XRANDR_FILE" ]]; then
        ok "${XRANDR_FILE} already exists, skipping."
        return
    fi

    sudo mkdir -p "$(dirname "$XRANDR_FILE")"

    info "Creating ${XRANDR_FILE}..."
    sudo tee "$XRANDR_FILE" >/dev/null <<'EOF'
# Reduced resolution for 4K Display
 xrandr --newmode "2304x1296"  251.25  2304 2464 2712 3120  1296 1299 1304 1344 -hsync +vsync
 xrandr --addmode eDP-1 2304x1296
 xrandr --output eDP-1 --mode 2048x1152
EOF
    sudo chmod 644 "$XRANDR_FILE"

    ok "Created ${XRANDR_FILE}."
    warn "Log out and back in (or reboot) for the resolution change to take effect."
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
# Remove existing files/dirs at stow targets so symlinks can be created.
# Paths derived from actual dotfiles repo content.

STOW_CONFLICT_PATHS=(
    # Home-level dotfiles
    "${HOME}/.bashrc"
    "${HOME}/.profile"
    "${HOME}/.tmux.conf"
    # .config directories (matching dotfiles repo)
    "${HOME}/.config/i3"
    "${HOME}/.config/i3status"
    "${HOME}/.config/i3blocks"
    "${HOME}/.config/alacritty"
    "${HOME}/.config/btop"
    "${HOME}/.config/doom"
    "${HOME}/.config/mc"
    "${HOME}/.config/nvim"
    "${HOME}/.config/picom"
    # ICAClient (Citrix)
    "${HOME}/.ICAClient"
)

# Check if a directory is already managed by stow (contains symlinks)
# On a fresh install, default config dirs only contain real files.
# After stow --no-folding, they contain symlinks to dotfiles.
_is_stow_managed_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || return 1
    [[ -n "$(find "$dir" -mindepth 1 -maxdepth 1 -type l -print -quit 2>/dev/null)" ]]
}

cleanup_for_stow() {
    info "Checking for files that would conflict with stow..."

    local -a conflicts=()

    for path in "${STOW_CONFLICT_PATHS[@]}"; do
        # Skip if path doesn't exist or is already a symlink
        [[ -e "$path" ]] || continue
        [[ -L "$path" ]] && continue

        # With --no-folding, stow creates real dirs with symlinked files inside.
        # If the dir is already stow-managed, it's not a conflict.
        if [[ -d "$path" ]] && _is_stow_managed_dir "$path"; then
            continue
        fi

        conflicts+=("$path")
    done

    if [[ ${#conflicts[@]} -eq 0 ]]; then
        ok "No conflicting files found. Ready for stow."
        return
    fi

    info "Found ${#conflicts[@]} path(s) that would block stow:"
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
    cd "$DOTFILES_DIR"
    # --no-folding: never replace a real directory with a symlink.
    # Without this, stow may "fold" ~/.config into a single symlink
    # to .dotfiles/.config, destroying configs for Firefox, Thunar, etc.
    stow --no-folding -v -t "$HOME" .
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
    if [[ -f "$xinitrc" ]] && ! grep -q 'import-environment DISPLAY' "$xinitrc"; then
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

    # 2. Remove lightdm
    info "--- Remove Display Manager ---"
    remove_lightdm
    echo ""

    # 3. Neovim
    info "--- Neovim (GitHub Release) ---"
    if [[ "$OPT_NVIM_UPDATE" == true ]]; then
        update_neovim
    else
        install_neovim
    fi
    echo ""

    # 4. tree-sitter CLI
    info "--- tree-sitter CLI ---"
    install_treesitter_cli
    echo ""

    # 5. Nerd Fonts
    info "--- Nerd Fonts ---"
    install_nerd_fonts
    echo ""

    # 6. Tmux plugin manager
    info "--- Tmux Plugin Manager ---"
    migrate_tpm
    echo ""

    # 7. HiDPI setup
    info "--- HiDPI ---"
    if [[ "$OPT_HIDPI_SKIP" == true ]]; then
        ok "Skipping HiDPI setup (--hidpi-skip)."
    else
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
    fi
    echo ""

    # 8. Stow pre-cleanup
    info "--- Stow Pre-Cleanup ---"
    cleanup_for_stow
    echo ""

    # 9. Deploy dotfiles (stow from this repo)
    info "--- Dotfiles ---"
    deploy_dotfiles
    echo ""

    # 10. Doom Emacs (needs dotfiles for ~/.config/doom/, restarts daemon)
    info "--- Doom Emacs ---"
    install_doom_emacs
    echo ""

    # 11. Emacs daemon (enable for next boot — not started now)
    info "--- Emacs Daemon ---"
    setup_emacs_daemon
    echo ""

    # 12. Julia
    info "--- Julia ---"
    install_julia
    echo ""

    # 13. startx + i3 login
    info "--- Console Login → i3 ---"
    setup_startx_login
    echo ""

    # -- Summary --
    echo "==========================================="
    echo ""
    ok "Setup complete!"
    echo ""
    info "Post-install reminders:"
    echo "  • Reboot to use console login → startx → i3"
    echo "  • Run ${BOLD}sudo update-alternatives --config x-session-manager${NC} to choose i3"
    echo "  • Run ${BOLD}lxappearance${NC} to set GTK theme, icons, and fonts system-wide"
    echo "  • Run ${BOLD}picom-conf${NC} to adjust transparency, shadows, and effects"
    echo "  • In a tmux session: ${BOLD}prefix + I${NC} to install tmux plugins"
    echo "  • Julia is managed by juliaup — run ${BOLD}juliaup status${NC}"
    echo "  • Run ${BOLD}./setup-debian13.sh${NC} for all available options"
    echo ""
}

main "$@"
