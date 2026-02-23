# Dotfiles — Debian 13 (Trixie) + i3wm

Personal development environment. Console login → `startx` → i3 (no display manager).

Managed with [GNU Stow](https://www.gnu.org/software/stow/) and an automated setup script.

## Install

Start from a fresh Debian 13 install with XFCE desktop (base).

```bash
git clone https://github.com/knorg/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./setup-debian13.sh --install
```

The script is idempotent — safe to re-run.

## What the setup script does

1. Installs all Debian packages (i3, picom, alacritty, emacs, dev tools, etc.)
2. Removes lightdm (replaced by console login + `startx`)
3. Installs Neovim from GitHub releases (not Debian repos)
4. Installs tree-sitter CLI via npm
5. Installs CascadiaMono Nerd Font from GitHub
6. Configures tmux plugin manager (Debian package, symlinked for `prefix + I`)
7. HiDPI setup — GRUB font + xrandr scaling (auto-detects 4K, asks to confirm)
8. Deploys dotfiles via `stow`
9. Installs Doom Emacs (`doom install`) + enables emacs daemon
10. Installs Julia via juliaup (user-level)
11. Configures `.profile` + `.xinitrc` for auto-startx on tty1

Run `./setup-debian13.sh` without arguments to see all options.

## Script options

| Option | Description |
|---|---|
| `--install` | Full setup |
| `--hidpi-skip` | Full setup, skip HiDPI configuration |
| `--nvim-update` | Full setup + update Neovim to latest release |
| `--nvim-rollback` | Rollback Neovim to previous version (standalone) |
| `--hidpi-revert` | Remove all HiDPI settings (standalone) |
| `--hidpi-help` | How to change display resolution (standalone) |

## What's included

### Window manager
- **i3** — tiling window manager with i3status and i3blocks
- **picom** — compositor (transparency, shadows, fading via `~/.config/picom/picom.conf`)
- **rofi** — application launcher
- **feh** — wallpaper

### Terminal
- **Alacritty** — GPU-accelerated terminal (`~/.config/alacritty/alacritty.toml`)
- **tmux** — terminal multiplexer + tpm plugins
- **CascadiaMono Nerd Font** — patched with icons for devtools

### Editors
- **Doom Emacs** — config in `~/.config/doom/`, includes custom i3wm-config-mode
- **Neovim** — kickstart-based config (`~/.config/nvim/`), TJ DeVries template

### Languages
- **Julia** — installed via juliaup, Emacs integration

### Tools
- eza, ripgrep, fd-find, btop, mc, shellcheck, xclip

## Repo structure

Flat stow layout — the repo root mirrors `$HOME`:

```
.dotfiles/
├── .bashrc
├── .profile
├── .tmux.conf
├── .config/
│   ├── alacritty/
│   ├── btop/
│   ├── doom/          # Doom Emacs config (init.el, packages.el, etc.)
│   ├── i3/            # i3 config + lock.sh
│   ├── i3blocks/
│   ├── i3status/
│   ├── mc/
│   ├── nvim/          # Neovim kickstart config
│   └── picom/
├── setup-debian13.sh
└── README.md
```

Deploy with: `cd ~/.dotfiles && stow --no-folding -t ~ .`

## After install

```bash
# Choose i3 as the session manager
sudo update-alternatives --config x-session-manager

# Set GTK theme, icons, and fonts
lxappearance

# Install tmux plugins
# (inside tmux) prefix + I

# Adjust transparency
picom-conf
```

Then reboot.
