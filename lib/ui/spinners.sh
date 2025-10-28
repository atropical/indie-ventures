#!/usr/bin/env bash

# Spinner utilities for long-running tasks

# Run command with spinner (gum-based)
run_with_spinner() {
    local message="$1"
    shift
    local cmd="$@"

    if command_exists gum; then
        gum spin --spinner dot --title "${message}" -- bash -c "${cmd}"
        return $?
    else
        # Fallback: run command without spinner
        info "${message}..."
        eval "${cmd}"
        return $?
    fi
}

# Run command with progress indicator
run_with_progress() {
    local message="$1"
    shift
    local cmd="$@"

    if command_exists gum; then
        # Run in background and show spinner
        eval "${cmd}" &
        local pid=$!

        gum spin --spinner moon --title "${message}" -- bash -c "while kill -0 ${pid} 2>/dev/null; do sleep 0.1; done"

        wait ${pid}
        return $?
    else
        info "${message}..."
        eval "${cmd}"
        return $?
    fi
}
