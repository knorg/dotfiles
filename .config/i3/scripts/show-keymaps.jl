#!/usr/bin/env julia --startup-file=no --compile=min
# show-keymaps.jl — Parse i3 config keybindings, using comments as descriptions

using Dates

const BOLD   = "\033[1m"
const CYAN   = "\033[0;36m"
const YELLOW = "\033[0;33m"
const GREEN  = "\033[0;32m"
const DIM    = "\033[2m"
const RESET  = "\033[0m"

const KEY_COL    = 30
const SHOW_MODES = ["Global", "resize"]

const IGNORED_COMMENTS = r"^(This file|It will|Should you|Please see|http|These bindings|Pressing|same bind|back to|alternatively)"

function format_key(k::AbstractString)::String
    k = replace(k, r"\$mod" => "SUPER")
    k = replace(k, "Mod4"      => "SUPER")
    k = replace(k, "Mod1"      => "ALT")
    k = replace(k, "mod1"      => "ALT")
    k = replace(k, "Mod5"      => "ALTGR")
    k = replace(k, "Control"   => "CTRL")
    k = replace(k, "Shift"     => "SHIFT")
    k = replace(k, "Return"    => "ENTER")
    k = replace(k, "Prior"     => "PGUP")
    k = replace(k, "Next"      => "PGDN")
    k = replace(k, "--release" => "")
    return k
end

function collect_vars(lines)
    vars = Dict{String,String}()
    for line in lines
        m = match(r"^\s*set\s+(\$[a-zA-Z0-9_]+)\s+(.*)", line)
        m === nothing && continue
        val = strip(m[2], '"')
        val = replace(val, r"^[0-9]+:\s*" => "")
        vars[m[1]] = val
    end
    # Sort longest-first so $mode_gaps matches before $mod
    return sort(collect(vars), by = kv -> -length(kv[1]))
end

function resolve_vars(s::AbstractString, sorted_vars)::String
    for (k, v) in sorted_vars
        s = replace(s, k => v)
    end
    return s
end

function parse_config(lines, sorted_vars)
    mode_blocks  = Dict{String, Vector{Tuple{String,String}}}("Global" => [])
    mode_order   = ["Global"]
    current_mode = "Global"
    last_comment = ""

    for line in lines
        line = lstrip(line)

        # Comment
        m = match(r"^#\s*(.*)", line)
        if m !== nothing
            candidate = m[1]
            if length(candidate) < 120 && match(IGNORED_COMMENTS, candidate) === nothing
                last_comment = candidate
            end
            continue
        end

        # Blank line
        if isempty(line)
            last_comment = ""
            continue
        end

        # Mode — variable form: mode "$mode_gaps"
        m = match(r"^mode\s+\"?(\$[a-zA-Z0-9_]+)\"?", line)
        if m !== nothing
            current_mode = resolve_vars(m[1], sorted_vars)
            if !haskey(mode_blocks, current_mode)
                mode_blocks[current_mode] = []
                push!(mode_order, current_mode)
            end
            last_comment = ""
            continue
        end

        # Mode — literal: mode "resize"
        m = match(r"^mode\s+\"([^\"]+)\"", line)
        if m !== nothing
            current_mode = m[1]
            if !haskey(mode_blocks, current_mode)
                mode_blocks[current_mode] = []
                push!(mode_order, current_mode)
            end
            last_comment = ""
            continue
        end

        # Closing brace
        if line == "}"
            current_mode = "Global"
            last_comment = ""
            continue
        end

        # bindsym / bindcode
        m = match(r"^(bindsym|bindcode)\s+(\S+)\s+(.*)", line)
        if m !== nothing
            key    = m[2]
            action = strip(m[3])

            if !isempty(last_comment)
                description = last_comment
            else
                description = action
                for prefix in ["exec_always --no-startup-id ", "exec_always ",
                               "exec --no-startup-id ", "exec "]
                    if startswith(description, prefix)
                        description = description[length(prefix)+1:end]
                        break
                    end
                end
                description = replace(description, "\"" => "")
                description = resolve_vars(description, sorted_vars)
                mm = match(r"^workspace number (.+)", description)
                if mm !== nothing
                    description = "Switch to: $(mm[1])"
                else
                    mm = match(r"^move container to workspace number (.+)", description)
                    mm !== nothing && (description = "Move to: $(mm[1])")
                end
            end

            pretty_key = resolve_vars(format_key(key), sorted_vars)
            push!(mode_blocks[current_mode], (pretty_key, description))
            last_comment = ""
            continue
        end

        last_comment = ""
    end

    return mode_blocks, mode_order
end

function main()
    i3_config = joinpath(get(ENV, "XDG_CONFIG_HOME",
                             joinpath(ENV["HOME"], ".config")), "i3", "config")
    isempty(ARGS) || (i3_config = ARGS[1])

    if !isfile(i3_config)
        println(stderr, "Error: i3 config not found at $i3_config")
        exit(1)
    end

    lines       = readlines(i3_config)
    sorted_vars = collect_vars(lines)
    mode_blocks, _ = parse_config(lines, sorted_vars)

    width = 72
    title = " i3 Keybindings — $(Dates.format(now(), "HH:MM:SS")) "
    pad   = div(width - length(title), 2)

    println()
    print(CYAN, " "^pad, BOLD, title, RESET, CYAN, " "^pad, RESET, "\n")
    println(CYAN, "═"^width, RESET)

    for mode in SHOW_MODES
        (!haskey(mode_blocks, mode) || isempty(mode_blocks[mode])) && continue
        println()
        println("  $(YELLOW)$(BOLD)▸ $mode$(RESET)")
        println("  $(YELLOW)$("─"^(width-2))$(RESET)")
        for (key, desc) in mode_blocks[mode]
            println("  $(GREEN)$(BOLD)$(rpad(key, KEY_COL))$(RESET)  $desc")
        end
        println()
    end

    println(CYAN, "═"^width, RESET)
    println(DIM, "  $i3_config", RESET)
    println()
    print(DIM, "  Press any key to close...", RESET)
    flush(stdout)
    run(`sh -c "stty -echo -icanon && dd bs=1 count=1 2>/dev/null; stty echo icanon"`)
    println()
end

main()
