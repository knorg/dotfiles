#!/usr/bin/env bash

exec alacritty \
    --class i3-keymaps \
    --option window.dimensions.columns=125 \
    --option window.dimensions.lines=45 \
    -e bash -c 'julia --startup-file=no --compile=min ~/.dotfiles/.config/i3/scripts/show-keymaps.jl; echo; read -n1 -rsp "Press any key to close..."'
    # -e ~/.config/i3/scripts/show-keymaps.sh
