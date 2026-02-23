# Debian 13 (Trixie) — i3wm Development Environment Setup

### Console login → startx → i3  (no display manager)

Config: github.com/knorg/dotfiles.git  +  GNU Stow

#### Install:

> Debian 13 + xfce desktop environment

```bash
git clone https://github.com/knorg/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./setup-debian13.sh --install
```

#### Included:

- i3
- i3status
- alacritty
- tmux + tpm
- neovim (kickstart, TJ DeVries)
- doom emacs
- julia + emacs edi
