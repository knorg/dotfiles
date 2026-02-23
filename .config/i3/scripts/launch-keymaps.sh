#!/usr/bin/env bash

exec alacritty \
    --class i3-keymaps \
    --option window.dimensions.columns=125 \
    --option window.dimensions.lines=45 \
    -e ~/.config/i3/scripts/show-keymaps.sh
