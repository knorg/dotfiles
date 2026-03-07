# Debian 13 (Trixie) — i3wm Development Environment

Automated setup for a keyboard-driven Linux desktop: console login → `startx` → i3
window manager, with Julia and a curated set of terminal tools. Neovim, Emacs (Doom),
and Tmux are available as optional selections during install.

Everything is managed through GNU Stow so dotfiles stay in one repo and deploy as
symlinks.

## Quick Start

```bash
git clone https://github.com/knorg/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./setup-debian13.sh --install
```

The script is safe to re-run — it skips already-installed packages, detects existing
configs, and backs up any files that would conflict with Stow before deploying.

## What the Script Does

1. Installs core Debian packages (i3, Alacritty, picom, rofi, dev tools, fonts, …)
2. Offers optional packages interactively — **Tmux + plugins**, **Neovim**,
   **Emacs (Doom)**, Brave, VS Code, Citrix Workspace, Dolphin, Konsole
3. Installs editor/tool-specific dependencies for any selected options
4. Removes `lightdm` (no display manager — console login + `startx`)
5. If Neovim was selected: installs from the latest GitHub release + tree-sitter CLI
6. Installs Nerd Fonts (CascadiaMono) and Monaspace fonts (Argon, Krypton, Neon, Radon, Xenon)
7. If Tmux was selected: configures tmux plugin manager (Debian package + user symlink)
8. Optionally applies HiDPI fixes (GRUB font + xrandr scaling) when `--hidpi` is passed
9. Backs up conflicting files and deploys dotfiles via `stow --no-folding`
10. If Emacs was selected: installs Doom Emacs, runs `doom sync`, enables the systemd user daemon
11. Installs Julia via juliaup (user-level)
12. Sets up `~/.xinitrc` and `.profile` for console login → `startx` → i3

On re-runs, already-installed editors and tools are auto-detected so their
maintenance steps (Neovim version check, `doom sync`, tmux plugin manager, etc.)
run without re-selecting them at the interactive prompt.

## Usage

```
./setup-debian13.sh --install             # full setup (editors offered interactively)
./setup-debian13.sh --install --hidpi     # full setup with HiDPI configuration

./setup-debian13.sh --nvim-update         # full setup + update Neovim to latest
./setup-debian13.sh --nvim-rollback       # restore previous Neovim version

./setup-debian13.sh --hidpi               # apply HiDPI fixes (standalone)
./setup-debian13.sh --hidpi-revert        # undo HiDPI changes
./setup-debian13.sh --hidpi-help          # display resolution tips

./setup-debian13.sh                       # show help
```

## Included Tools

The base install (before optional selections) includes:

| Category | Packages |
|---|---|
| **Terminal** | Alacritty, mc, btop, eza, ripgrep, fd-find |
| **i3 Desktop** | i3, i3blocks, picom, picom-conf, rofi, feh |
| **Screenshots** | maim + xclip (keyboard-driven capture to clipboard) |
| **Camera** | mpv + v4l-utils (UVC webcam preview and control) |
| **Appearance** | lxappearance, Arc/Greybird/Numix/Orchis themes, Papirus/Faenza/Moka icons, color-picker |
| **Dev** | npm, shellcheck, markdown |
| **Network** | gvfs-backends, smbclient |
| **Fonts** | CascadiaMono Nerd Font, Monaspace (5-family superfamily), DejaVu, Font Awesome, Symbola |

The `.bashrc` aliases `ls` to `eza` with icons, git status, and directory-first sorting.

## Neovim

Configuration based on [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim)
by TJ DeVries, extended with additional plugins and keybindings.

### Configured Plugins

| Plugin | Purpose |
|---|---|
| **Lazy.nvim** | Plugin manager with lazy-loading |
| **Telescope** | Fuzzy finder (files, grep, buffers, LSP symbols) with fzf-native and ui-select |
| **blink.cmp** | Autocompletion engine with LSP, snippet, and path sources |
| **mini.files** | Lightweight file browser |
| **mini.operators** | Replace and exchange text operators |
| **Neogit** | Git interface (Magit-inspired) |
| **tree-sitter** | Incremental syntax highlighting |
| **which-key** | Displays available keybindings after pressing a leader key |
| **LSP** (built-in) | Language server support for completions, diagnostics, go-to-definition |

The full configuration lives in `.config/nvim/init.lua`. Plugins are pinned via
`lazy-lock.json` for reproducibility across machines.

## Emacs

The Emacs configuration is built on top of
[Doom Emacs](https://github.com/doomemacs/doomemacs) and lives in `.config/doom/`.
It adds custom behaviour on top of what Doom provides:

- **Dark/light theme toggle** — switch between a Doom theme and its `-light` variant
- **Julia IDE** — LSP via eglot, tree-sitter highlighting, vterm REPL
- **Relative line numbers** enabled by default
- **Magit** for Git operations

The **i3wm config syntax highlighting** (`i3wm-config-mode`) is a standalone major mode
and is _not_ part of the Doom Emacs layer — it provides custom font-lock rules with
monochrome rendering for uncommented lines and proper handling of `exec_always`,
`for_window`, and inline comments.

### Emacs Daemon

Emacs runs as a **systemd user service** so it stays loaded in the background and
new frames open instantly. The setup script enables the service automatically.

**Start / stop / check the daemon:**

```bash
systemctl --user start emacs       # start now
systemctl --user stop emacs        # stop now
systemctl --user restart emacs     # restart (e.g. after doom sync)
systemctl --user status emacs      # check if running
```

**Open a new frame** (connects to the running daemon):

```bash
emacsclient -c                     # graphical frame
emacsclient -t                     # terminal frame
```

The daemon starts automatically on login via `systemctl --user enable emacs`
(configured by the setup script). The `~/.xinitrc` exports `DISPLAY` into the
systemd user session so graphical frames work without a display manager.

After running `doom sync` or changing your Doom configuration, restart the daemon
so it picks up the changes:

```bash
doom sync && systemctl --user restart emacs
```

## Tmux

Tmux is offered as an optional selection during install. When selected, the script
installs tmux and the Debian-packaged `tmux-plugin-manager`, then creates a user-level
symlink (`~/.tmux/plugins/tpm`) pointing to the system package so that plugin
installation via `prefix + I` works without root.

After setup, reload the config and install plugins:

```bash
tmux source ~/.tmux.conf     # reload config
# then press: prefix + I     # install plugins
```

## HiDPI

HiDPI configuration is **not applied by default**. Use `--install --hidpi` to
enable it during setup, or `--hidpi` to apply it standalone. This is useful for
4K laptop panels where native resolution makes everything too small for an
i3/X11 desktop without scaling.

When enabled, the script:

- Generates a larger GRUB font (DejaVu Sans Mono, 24pt)
- Sets `GRUB_GFXMODE=1920x1080` for a readable boot menu
- Creates `/etc/X11/Xsession.d/45custom_xrandr-settings` with a scaled-down
  resolution via `xrandr`

**Manage HiDPI after install:**

```
./setup-debian13.sh --hidpi-help      # tips for changing resolution
./setup-debian13.sh --hidpi-revert    # remove all HiDPI changes
```

## Post-Install Checklist

After a fresh install (or a re-run), verify these items:

- [ ] Reboot (first install only — activates console login → startx → i3)
- [ ] Choose i3 as the default session: `sudo update-alternatives --config x-session-manager`
- [ ] Set GTK theme, icons, and fonts: `lxappearance`
- [ ] Adjust compositor effects: `picom-conf`
- [ ] If Tmux was selected: install plugins (inside a tmux session): `prefix + I`
- [ ] Check Julia: `juliaup status`
- [ ] If Emacs was selected: verify daemon — `systemctl --user status emacs`

On re-runs, the script skips what is already in place and auto-detects installed
editors and tools. The checklist items above are one-time actions — once configured,
they persist across re-runs.

## Repository Layout

```
~/.dotfiles/
├── .bashrc
├── .profile
├── .tmux.conf
├── .stow-local-ignore      # excludes setup script, README, .git from stow
├── .config/
│   ├── alacritty/
│   ├── doom/               # Doom Emacs config (init.el, config.el, packages.el)
│   ├── i3/                 # i3wm config
│   ├── i3status/
│   ├── i3blocks/
│   ├── mc/
│   ├── nvim/               # Neovim config (init.lua)
│   └── picom/
├── setup-debian13.sh        # this script
└── README.md
```

Files are deployed to `$HOME` via `stow --no-folding .` which creates per-file
symlinks inside real directories, keeping configs for other applications
(Firefox, Thunar, …) intact. Before deploying, the script scans the repo to
find which target paths already exist as real files and offers to back them up —
no hardcoded list, so adding or removing directories from the repo is all that's
needed. The `.stow-local-ignore` file prevents the setup script, README, and
`.git` directory from being deployed as dotfiles.
