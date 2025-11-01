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

    if ! git clone --depth 1 --filter=blob:none https://github.com/supabase/supabase.git "${temp_dir}" >/dev/null 2>&1; then
        error "Failed to fetch Supabase official setup"
        rm -rf "${temp_dir}"
        return 1
    fi

    # Configure sparse checkout to only get docker directory
    cd "${temp_dir}" || return 1
    if ! git sparse-checkout init --cone >/dev/null 2>&1; then
        error "Failed to initialize sparse checkout"
        cd - >/dev/null || true
        rm -rf "${temp_dir}"
        return 1
    fi
    
    if ! git sparse-checkout set docker >/dev/null 2>&1; then
        error "Failed to configure sparse checkout for docker directory"
        cd - >/dev/null || true
        rm -rf "${temp_dir}"
        return 1
    fi
    
    # Checkout the docker directory (sparse checkout needs this to actually get the files)
    if ! git checkout >/dev/null 2>&1; then
        error "Failed to checkout docker directory"
        cd - >/dev/null || true
        rm -rf "${temp_dir}"
        return 1
    fi

    # Verify docker directory exists with volumes
    if ! [ -d "${temp_dir}/docker" ] || ! [ -d "${temp_dir}/docker/volumes" ]; then
        error "Docker directory or volumes not found after checkout"
        error "Directory structure at ${temp_dir}:"
        ls -la "${temp_dir}" >&2 || true
        cd - >/dev/null || true
        rm -rf "${temp_dir}"
        return 1
    fi

    # Copy docker directory to target
    mkdir -p "$(dirname "${target_dir}")"
    if ! cp -r "${temp_dir}/docker" "${target_dir}"; then
        error "Failed to copy docker directory to ${target_dir}"
        cd - >/dev/null || true
        rm -rf "${temp_dir}"
        return 1
    fi

    # Verify the copy succeeded
    if ! [ -d "${target_dir}/docker" ] || ! [ -d "${target_dir}/docker/volumes" ]; then
        error "Copy verification failed - files not found at ${target_dir}/docker"
        error "Copy source: ${temp_dir}/docker"
        error "Copy target: ${target_dir}"
        cd - >/dev/null || true
        rm -rf "${temp_dir}"
        return 1
    fi

    verbose_log "Copied Supabase setup to: ${target_dir}/docker"
    verbose_log "Volumes directory: ${target_dir}/docker/volumes"

    # Cleanup
    cd - >/dev/null || true
    rm -rf "${temp_dir}"

    success "Fetched Supabase official setup"
    verbose_log "Location: ${target_dir}/docker"
    return 0
}

# Get path to Supabase official docker-compose.yml
get_supabase_compose_path() {
    echo "${INDIE_DIR}/supabase-official/docker/docker-compose.yml"
}

# Get path to Supabase official .env.example
get_supabase_env_example_path() {
    echo "${INDIE_DIR}/supabase-official/docker/.env.example"
}

# Check if Supabase setup is available
supabase_setup_available() {
    [ -f "$(get_supabase_compose_path)" ] && [ -f "$(get_supabase_env_example_path)" ]
}

# Initialize Supabase volumes directory structure from official setup
init_supabase_volumes() {
    # fetch_supabase_setup copies docker/ to supabase-official/, so volumes are at docker/volumes
    local source_dir="${INDIE_DIR}/supabase-official/docker/volumes"
    local target_dir="${INDIE_DIR}/volumes/supabase"

    verbose_log "Looking for Supabase volumes at: ${source_dir}"

    if ! [ -d "${source_dir}" ]; then
        error "Supabase official volumes not found at: ${source_dir}"
        error "Expected location: ${INDIE_DIR}/supabase-official/docker/volumes"
        if [ -d "${INDIE_DIR}/supabase-official" ]; then
            error "Contents of ${INDIE_DIR}/supabase-official:"
            ls -la "${INDIE_DIR}/supabase-official" >&2 || true
        else
            error "${INDIE_DIR}/supabase-official does not exist"
        fi
        return 1
    fi

    verbose_log "Found Supabase volumes at: ${source_dir}"

    # Copy volumes structure (but not data)
    mkdir -p "${target_dir}"

    local copy_failed=false

    # Copy database init scripts (required for Postgres initialization)
    if [ -d "${source_dir}/db" ]; then
        mkdir -p "${target_dir}/db"
        if ! cp -r "${source_dir}/db"/* "${target_dir}/db/" 2>/dev/null; then
            error "Failed to copy database migration files"
            copy_failed=true
        else
            verbose_log "Copied database migration files"
        fi
    else
        error "Database migration directory not found: ${source_dir}/db"
        copy_failed=true
    fi

    # Copy Kong config (required for API gateway)
    if [ -d "${source_dir}/api" ]; then
        mkdir -p "${target_dir}/api"
        if ! cp -r "${source_dir}/api"/* "${target_dir}/api/" 2>/dev/null; then
            error "Failed to copy Kong configuration"
            copy_failed=true
        else
            verbose_log "Copied Kong configuration"
        fi
    else
        warning "Kong config directory not found: ${source_dir}/api"
    fi

    # Copy pooler config (required for Supavisor)
    if [ -d "${source_dir}/pooler" ]; then
        mkdir -p "${target_dir}/pooler"
        if ! cp -r "${source_dir}/pooler"/* "${target_dir}/pooler/" 2>/dev/null; then
            error "Failed to copy pooler configuration"
            copy_failed=true
        else
            verbose_log "Copied pooler configuration"
        fi
    else
        warning "Pooler config directory not found: ${source_dir}/pooler"
    fi

    # Copy logs config
    if [ -d "${source_dir}/logs" ]; then
        mkdir -p "${target_dir}/logs"
        if ! cp -r "${source_dir}/logs"/* "${target_dir}/logs/" 2>/dev/null; then
            warning "Failed to copy logs configuration (optional)"
        else
            verbose_log "Copied logs configuration"
        fi
    fi

    # Copy functions template
    if [ -d "${source_dir}/functions" ]; then
        mkdir -p "${target_dir}/functions"
        if ! cp -r "${source_dir}/functions"/* "${target_dir}/functions/" 2>/dev/null; then
            warning "Failed to copy functions template (optional)"
        else
            verbose_log "Copied functions template"
        fi
    fi

    # Verify critical files were copied
    if [ "${copy_failed}" = "true" ]; then
        error "Failed to copy required Supabase volume files"
        return 1
    fi

    # Verify database files exist (most critical)
    if ! [ -f "${target_dir}/db/realtime.sql" ] || ! [ -f "${target_dir}/db/roles.sql" ]; then
        error "Critical database migration files missing after copy"
        error "Expected files in: ${target_dir}/db/"
        return 1
    fi

    verbose_log "Initialized Supabase volumes structure"
    return 0
}

