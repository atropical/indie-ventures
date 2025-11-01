#!/usr/bin/env bash

# Supabase official setup integration for Indie Ventures

# Fetch Supabase official Docker setup
fetch_supabase_setup() {
    local target_dir="${1:-${INDIE_DIR}/supabase-official}"

    verbose_log "Fetching Supabase official Docker setup…"

    if [ -d "${target_dir}/docker" ]; then
        verbose_log "Supabase setup already exists at ${target_dir}"
        # Update if it's a git repo
        if [ -d "${target_dir}/.git" ]; then
            verbose_log "Updating Supabase setup from repository…"
            cd "${target_dir}" && git pull --quiet >/dev/null 2>&1 || true
            cd - >/dev/null || true
        fi
        return 0
    fi

    info "Fetching Supabase official Docker setup (this may take a moment)…"

    # Create temp directory for cloning
    local temp_dir
    temp_dir=$(mktemp -d)

    if ! git clone --depth 1 --filter=blob:none --sparse https://github.com/supabase/supabase.git "${temp_dir}" >/dev/null 2>&1; then
        error "Failed to fetch Supabase official setup"
        rm -rf "${temp_dir}"
        return 1
    fi

    # Configure sparse checkout to only get docker directory
    cd "${temp_dir}"
    git sparse-checkout init --cone >/dev/null 2>&1
    git sparse-checkout set docker >/dev/null 2>&1

    # Copy docker directory to target
    mkdir -p "$(dirname "${target_dir}")"
    cp -r "${temp_dir}/docker" "${target_dir}"

    # Cleanup
    cd - >/dev/null || true
    rm -rf "${temp_dir}"

    success "Fetched Supabase official setup"
    return 0
}

# Get path to Supabase official docker-compose.yml
get_supabase_compose_path() {
    echo "${INDIE_DIR}/supabase-official/docker-compose.yml"
}

# Get path to Supabase official .env.example
get_supabase_env_example_path() {
    echo "${INDIE_DIR}/supabase-official/.env.example"
}

# Check if Supabase setup is available
supabase_setup_available() {
    [ -f "$(get_supabase_compose_path)" ] && [ -f "$(get_supabase_env_example_path)" ]
}

# Initialize Supabase volumes directory structure from official setup
init_supabase_volumes() {
    local source_dir="${INDIE_DIR}/supabase-official/volumes"
    local target_dir="${INDIE_DIR}/volumes/supabase"

    if ! [ -d "${source_dir}" ]; then
        error "Supabase official volumes not found"
        return 1
    fi

    # Copy volumes structure (but not data)
    mkdir -p "${target_dir}"

    # Copy database init scripts
    if [ -d "${source_dir}/db" ]; then
        mkdir -p "${target_dir}/db"
        cp -r "${source_dir}/db"/* "${target_dir}/db/" 2>/dev/null || true
    fi

    # Copy Kong config
    if [ -d "${source_dir}/api" ]; then
        mkdir -p "${target_dir}/api"
        cp -r "${source_dir}/api"/* "${target_dir}/api/" 2>/dev/null || true
    fi

    # Copy pooler config
    if [ -d "${source_dir}/pooler" ]; then
        mkdir -p "${target_dir}/pooler"
        cp -r "${source_dir}/pooler"/* "${target_dir}/pooler/" 2>/dev/null || true
    fi

    # Copy logs config
    if [ -d "${source_dir}/logs" ]; then
        mkdir -p "${target_dir}/logs"
        cp -r "${source_dir}/logs"/* "${target_dir}/logs/" 2>/dev/null || true
    fi

    # Copy functions template
    if [ -d "${source_dir}/functions" ]; then
        mkdir -p "${target_dir}/functions"
        cp -r "${source_dir}/functions"/* "${target_dir}/functions/" 2>/dev/null || true
    fi

    verbose_log "Initialized Supabase volumes structure"
    return 0
}

