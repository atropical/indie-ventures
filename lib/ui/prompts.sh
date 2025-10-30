#!/usr/bin/env bash

# Gum-based interactive prompts for Indie Ventures

# Prompt for text input
prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local placeholder="${3:-}"

    if command_exists gum; then
        if [ -n "${default}" ]; then
            gum input --prompt "${prompt}: " --value "${default}" --placeholder "${placeholder}"
        else
            gum input --prompt "${prompt}: " --placeholder "${placeholder}"
        fi
    else
        # Fallback to read
        local result
        if [ -n "${default}" ]; then
            read -rp "${prompt} [${default}]: " result
            echo "${result:-${default}}"
        else
            read -rp "${prompt}: " result
            echo "${result}"
        fi
    fi
}

# Prompt for password input
prompt_password() {
    local prompt="$1"

    if command_exists gum; then
        gum input --prompt "${prompt}: " --password
    else
        # Fallback to read -s
        local result
        read -rsp "${prompt}: " result
        echo "" >&2
        echo "${result}"
    fi
}

# Prompt for password with confirmation
prompt_password_confirm() {
    local prompt="$1"
    local password
    local password_confirm

    while true; do
        password=$(prompt_password "$prompt")
        password_confirm=$(prompt_password "$prompt (confirm)")

        if [ "$password" = "$password_confirm" ]; then
            echo "$password"
            return 0
        else
            error "Passwords do not match. Please try again."
        fi
    done
}

# Prompt for choice from list
prompt_choice() {
    local prompt="$1"
    shift
    local options=("$@")

    if command_exists gum; then
        gum choose --header "${prompt}" "${options[@]}"
    else
        # Fallback to select
        echo "${prompt}"
        select opt in "${options[@]}"; do
            if [ -n "${opt}" ]; then
                echo "${opt}"
                break
            fi
        done
    fi
}

# Prompt for yes/no confirmation
prompt_confirm() {
    local prompt="$1"
    local default="${2:-false}"

    if command_exists gum; then
        if [ "${default}" = "true" ]; then
            gum confirm "${prompt}" --default=true && echo "true" || echo "false"
        else
            gum confirm "${prompt}" && echo "true" || echo "false"
        fi
    else
        # Use utility function
        if confirm "${prompt}"; then
            echo "true"
        else
            echo "false"
        fi
    fi
}

# Show spinner with task
with_spinner() {
    local message="$1"
    shift
    local cmd="$@"

    if command_exists gum; then
        gum spin --spinner dot --title "${message}" -- bash -c "${cmd}"
    else
        # Run without spinner
        echo "${message}…"
        eval "${cmd}"
    fi
}

# Show header/title
show_header() {
    local title="$1"

    if command_exists gum; then
        gum style \
            --border double \
            --border-foreground 212 \
            --padding "1 2" \
            --margin "1 0" \
            "${title}"
    else
        echo ""
        echo "╔══════════════════════════════════════╗"
        echo "║ ${title}"
        echo "╚══════════════════════════════════════╝"
        echo ""
    fi
}

# Show formatted code/output
show_code() {
    local content="$1"
    local language="${2:-}"

    if command_exists gum; then
        if [ -n "${language}" ]; then
            echo "${content}" | gum format -t code -l "${language}"
        else
            echo "${content}" | gum format -t code
        fi
    else
        echo "${content}"
    fi
}

# Show info box
show_info_box() {
    local title="$1"
    local content="$2"

    if command_exists gum; then
        gum style \
            --border rounded \
            --border-foreground 12 \
            --padding "0 1" \
            --margin "1 0" \
            "${title}" "" "${content}"
    else
        echo ""
        echo "┌─ ${title} ─"
        echo "│ ${content}"
        echo "└─"
        echo ""
    fi
}

# Show success box
show_success_box() {
    local title="$1"
    local content="$2"

    if command_exists gum; then
        gum style \
            --border rounded \
            --border-foreground 10 \
            --padding "0 1" \
            --margin "1 0" \
            "✓ ${title}" "" "${content}"
    else
        echo ""
        echo "✓ ${title}"
        echo "${content}"
        echo ""
    fi
}

# Show error box
show_error_box() {
    local title="$1"
    local content="$2"

    if command_exists gum; then
        gum style \
            --border rounded \
            --border-foreground 9 \
            --padding "0 1" \
            --margin "1 0" \
            "✗ ${title}" "" "${content}"
    else
        echo ""
        echo "✗ ${title}"
        echo "${content}"
        echo ""
    fi
}

# Multi-line text editor
prompt_editor() {
    local prompt="$1"
    local default="${2:-}"

    if command_exists gum; then
        echo "${prompt}"
        if [ -n "${default}" ]; then
            echo "${default}" | gum write
        else
            gum write
        fi
    else
        # Fallback to simple read
        echo "${prompt}"
        echo "(Press Ctrl+D when done)"
        cat
    fi
}

# Filter/search from list
prompt_filter() {
    local prompt="$1"
    shift
    local options=("$@")

    if command_exists gum; then
        printf "%s\n" "${options[@]}" | gum filter --placeholder "${prompt}"
    else
        # Fallback to choose
        prompt_choice "${prompt}" "${options[@]}"
    fi
}
