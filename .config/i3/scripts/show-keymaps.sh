#!/usr/bin/env bash
# show-keymaps.sh — Parse i3 config keybindings, using comments as descriptions

I3_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/i3/config"
[[ -n "$1" ]] && I3_CONFIG="$1"

BOLD='\033[1m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
DIM='\033[2m'
RESET='\033[0m'

# Only these modes will be shown in the output
SHOW_MODES=("Global" "resize")

if [[ ! -f "$I3_CONFIG" ]]; then
    echo "Error: i3 config not found at $I3_CONFIG" >&2
    exit 1
fi

format_key() {
    local k="$1"
    k="${k//\$mod/SUPER}"
    k="${k//Mod4/SUPER}"
    k="${k//Mod1/ALT}"
    k="${k//Mod5/ALTGR}"
    k="${k//Control/CTRL}"
    k="${k//Shift/SHIFT}"
    k="${k//Return/ENTER}"
    k="${k//Prior/PGUP}"
    k="${k//Next/PGDN}"
    k="${k//--release/}"
    k="${k//mod1/ALT}"
    echo "$k"
}

# ── Pass 1: collect variable definitions ────────────────────────────────────
declare -A vars
while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*set[[:space:]]+(\$[a-zA-Z0-9_]+)[[:space:]]+(.*) ]]; then
        varname="${BASH_REMATCH[1]}"
        varval="${BASH_REMATCH[2]}"
        varval=$(echo "$varval" | sed 's/^"//;s/"$//;s/^[0-9]*:[[:space:]]*//')
        vars["$varname"]="$varval"
    fi
done < "$I3_CONFIG"

# Cache sorted variable names (longest first) — do this ONCE, not per binding
declare -a sorted_var_names
mapfile -t sorted_var_names < <(printf '%s\n' "${!vars[@]}" | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-)

resolve_vars() {
    local s="$1"
    for v in "${sorted_var_names[@]}"; do
        s="${s//${v}/${vars[$v]}}"
    done
    echo "$s"
}

# ── Pass 2: parse bindings with preceding comment context ───────────────────
declare -A mode_blocks
declare -a mode_order
current_mode="Global"
mode_order=("Global")
last_comment=""
max_desc_len=0
key_col=30   # fixed width for key column

while IFS= read -r raw; do
    line="${raw#"${raw%%[![:space:]]*}"}"

    if [[ "$line" =~ ^#[[:space:]]*(.*) ]]; then
        candidate="${BASH_REMATCH[1]}"
        if [[ ${#candidate} -lt 120 ]] && \
           [[ ! "$candidate" =~ ^(This file|It will|Should you|Please see|http|These bindings|Pressing|same bind|back to|alternatively) ]]; then
            last_comment="$candidate"
        fi
        continue
    fi

    if [[ -z "$line" ]]; then
        last_comment=""
        continue
    fi

    if [[ "$line" =~ ^mode[[:space:]]+\"?(\$[a-zA-Z0-9_]+)\"? ]]; then
        raw_mode="${BASH_REMATCH[1]}"
        current_mode=$(resolve_vars "$raw_mode")
        [[ -z "${mode_blocks[$current_mode]+_}" ]] && mode_order+=("$current_mode")
        last_comment=""
        continue
    fi

    if [[ "$line" =~ ^mode[[:space:]]+\"([^\"]+)\" ]]; then
        current_mode="${BASH_REMATCH[1]}"
        [[ -z "${mode_blocks[$current_mode]+_}" ]] && mode_order+=("$current_mode")
        last_comment=""
        continue
    fi

    if [[ "$line" == "}" ]]; then
        current_mode="Global"
        last_comment=""
        continue
    fi

    if [[ "$line" =~ ^(bindsym|bindcode)[[:space:]]+([^[:space:]]+)[[:space:]]+(.*) ]]; then
        btype="${BASH_REMATCH[1]}"
        key="${BASH_REMATCH[2]}"
        action="${BASH_REMATCH[3]}"

        if [[ -n "$last_comment" ]]; then
            description="$last_comment"
        else
            description="$action"
            description="${description#exec_always --no-startup-id }"
            description="${description#exec_always }"
            description="${description#exec --no-startup-id }"
            description="${description#exec }"
            description="${description//\"/}"
            description=$(resolve_vars "$description")
            if [[ "$description" =~ ^workspace\ number\ (.+) ]]; then
                description="Switch to: ${BASH_REMATCH[1]}"
            elif [[ "$description" =~ ^move\ container\ to\ workspace\ number\ (.+) ]]; then
                description="Move to: ${BASH_REMATCH[1]}"
            fi
        fi

        pretty_key=$(format_key "$key")
        pretty_key=$(resolve_vars "$pretty_key")

        # Track longest description for auto-sizing
        [[ ${#description} -gt $max_desc_len ]] && max_desc_len=${#description}

        line_out=$(printf "  ${GREEN}${BOLD}%-${key_col}s${RESET}  %s\n" "$pretty_key" "$description")
        mode_blocks[$current_mode]+="${line_out}"$'\n'
        last_comment=""
        continue
    fi

    last_comment=""

done < "$I3_CONFIG"

# ── Auto-size width: key col + gap + description + side padding ──────────────
#   2 (indent) + key_col + 2 (gap) + max_desc_len + 4 (breathing room)
width=$(( 2 + key_col + 2 + max_desc_len + 4 ))

# Enforce a sensible minimum
(( width < 60 )) && width=60

# Resize the terminal window to fit (rows stay unchanged, cols = width)
printf '\033[8;0;%dt' "$width"

# ── Output ──────────────────────────────────────────────────────────────────
title=" i3 Keybindings — $(date '+%H:%M:%S') "
pad=$(( (width - ${#title}) / 2 ))

echo
printf "${CYAN}"
printf '%*s' "$pad" ''
printf "${BOLD}%s${RESET}${CYAN}" "$title"
printf '%*s' "$pad" ''
printf "${RESET}\n"
printf "${CYAN}%s${RESET}\n" "$(printf '═%.0s' $(seq 1 $width))"

for mode in "${SHOW_MODES[@]}"; do
    [[ -z "${mode_blocks[$mode]}" ]] && continue
    echo
    printf "  ${YELLOW}${BOLD}▸ %s${RESET}\n" "$mode"
    printf "  ${YELLOW}%s${RESET}\n" "$(printf '─%.0s' $(seq 1 $((width-2))))"
    echo -e "${mode_blocks[$mode]}"
done

printf "${CYAN}%s${RESET}\n" "$(printf '═%.0s' $(seq 1 $width))"
printf "${DIM}  %s${RESET}\n\n" "$I3_CONFIG"

echo -e "${DIM}  Press any key to close...${RESET}"
read -n1 -rs
