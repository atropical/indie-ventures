#!/usr/bin/env bash

# Initialize Indie Ventures on the server

# Load dependencies
source "${LIB_DIR}/core/deps.sh"
source "${LIB_DIR}/core/docker.sh"
source "${LIB_DIR}/core/secrets.sh"
source "${LIB_DIR}/core/supabase.sh"
source "${LIB_DIR}/ui/prompts.sh"
source "${LIB_DIR}/core/server.sh"

cmd_init() {
    show_header "Indie Ventures Initialization"

    # Prompt for data directory
    echo ""
    info "Where would you like to store Indie Ventures data and projects?"
    echo "  This will contain Docker volumes, project configurations, and backups."
    echo "  Default: /opt/indie-ventures (recommended for production servers)"
    echo ""
    read -p "Data directory [/opt/indie-ventures]: " user_data_dir

    # Use default if empty, otherwise use provided path
    if [ -n "$user_data_dir" ]; then
        INDIE_DIR="$user_data_dir"
    fi

    # Convert to absolute path if relative
    if [[ ! "${INDIE_DIR}" = /* ]]; then
        INDIE_DIR="$(cd "$(dirname "${INDIE_DIR}")" && pwd)/$(basename "${INDIE_DIR}")"
        # If the directory doesn't exist yet, resolve from current directory
        if [ ! -d "${INDIE_DIR}" ]; then
            INDIE_DIR="$(pwd)/${user_data_dir:-indie-ventures}"
        fi
    fi

    # Update dependent paths
    PROJECTS_FILE="${INDIE_DIR}/projects/registry.json"
    ENV_BASE="${INDIE_DIR}/.env.base"
    ENV_PROJECTS="${INDIE_DIR}/.env.projects"

    info "Using data directory: ${INDIE_DIR}"
    echo ""

    # Check if already initialized
    if is_initialized; then
        warning "Indie Ventures is already initialized at ${INDIE_DIR}"
        if ! confirm "Reinitialize? This will not affect existing projects."; then
            exit 0
        fi
    fi

    # Show system info
    show_system_info
    echo ""

    # Offer server preparation on Linux servers
    if is_production_server; then
        prepare_server
        echo ""
    fi

    # Check and install dependencies
    info "Checking dependencies…"
    if ! install_missing_dependencies; then
        error "Failed to install dependencies"
        exit 1
    fi
    echo ""

    # Create directory structure
    info "Creating directory structure…"
    mkdir -p "${INDIE_DIR}"/{projects,nginx/sites,volumes,backups}

    # Save config to standard location so other commands can find it
    local config_file="/etc/indie-ventures.conf"
    if is_root; then
        echo "INDIE_DIR=${INDIE_DIR}" > "${config_file}"
        success "Saved configuration to ${config_file}"
    else
        # For non-root users, save to home directory
        config_file="${HOME}/.indie-ventures.conf"
        echo "INDIE_DIR=${INDIE_DIR}" > "${config_file}"
        success "Saved configuration to ${config_file}"
    fi

    # Initialize projects registry
    if ! [ -f "${PROJECTS_FILE}" ]; then
        echo "{}" > "${PROJECTS_FILE}"
        success "Created projects registry"
    fi

    # Prompt for base credentials
    show_header "Base Configuration"

    local postgres_password
    if [ -f "${ENV_BASE}" ] && grep -q "POSTGRES_PASSWORD" "${ENV_BASE}"; then
        info "Using existing PostgreSQL password"
        postgres_password=$(grep "POSTGRES_PASSWORD" "${ENV_BASE}" | cut -d'=' -f2)
    else
        echo ""
        postgres_password=$(prompt_password_confirm "PostgreSQL password (for superuser 'postgres')")
    fi

    local dashboard_username
    if [ -f "${ENV_BASE}" ] && grep -q "DASHBOARD_USERNAME" "${ENV_BASE}"; then
        dashboard_username=$(grep "DASHBOARD_USERNAME" "${ENV_BASE}" | cut -d'=' -f2)
    else
        dashboard_username=$(prompt_input "Dashboard username" "supabase" "supabase")
    fi

    local dashboard_password
    if [ -f "${ENV_BASE}" ] && grep -q "DASHBOARD_PASSWORD" "${ENV_BASE}"; then
        info "Using existing Dashboard password"
        dashboard_password=$(grep "DASHBOARD_PASSWORD" "${ENV_BASE}" | cut -d'=' -f2)
    else
        echo ""
        dashboard_password=$(prompt_password_confirm "Studio Dashboard password")
    fi

    # Generate base secrets (for shared services)
    info "Generating base secrets…"
    local jwt_secret
    jwt_secret=$(generate_jwt_secret)
    local secret_key_base
    secret_key_base=$(generate_secret_key_base)
    local pg_meta_crypto_key
    pg_meta_crypto_key=$(generate_encryption_key)
    local vault_enc_key
    vault_enc_key=$(generate_encryption_key)
    local pooler_tenant_id
    pooler_tenant_id=$(generate_pooler_tenant_id)

    # Generate base JWT keys for shared services
    local base_anon_key
    base_anon_key=$(generate_supabase_jwt "${jwt_secret}" "anon" 2>/dev/null || echo "")
    local base_service_role_key
    base_service_role_key=$(generate_supabase_jwt "${jwt_secret}" "service_role" 2>/dev/null || echo "")

    # If JWT generation failed, warn user
    if [ -z "${base_anon_key}" ] || [ -z "${base_service_role_key}" ]; then
        warning "Could not generate proper JWT keys. Please regenerate using Supabase's official tool."
        base_anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.REPLACE_WITH_PROPER_KEY"
        base_service_role_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJzZXJ2aWNlX3JvbGUiLAogICAgImlzcyI6ICJzdXBhYmFzZS1kZW1vIiwKICAgICJpYXQiOiAxNjQxNzY5MjAwLAogICAgImV4cCI6IDE3OTk1MzU2MDAKfQ.REPLACE_WITH_PROPER_KEY"
    fi

    # Prompt for URLs (can be updated later per project)
    echo ""
    info "Configure base URLs (these can be overridden per project)"
    local site_url
    site_url=$(prompt_input "SITE_URL (base URL for auth callbacks)" "" "http://localhost:8000")
    local public_url
    public_url=$(prompt_input "PUBLIC_URL (public API URL)" "" "http://localhost:8000")

    # Create .env.base
    cat > "${ENV_BASE}" << EOF
# Indie Ventures Base Configuration
# Generated: $(date)

# PostgreSQL
POSTGRES_PASSWORD=${postgres_password}
POSTGRES_HOST=postgres
POSTGRES_DB=postgres
POSTGRES_PORT=5432

# Studio Dashboard Authentication
DASHBOARD_USERNAME=${dashboard_username}
DASHBOARD_PASSWORD=${dashboard_password}
STUDIO_DEFAULT_ORGANIZATION=Indie Ventures
STUDIO_DEFAULT_PROJECT=Default

# Base Secrets (for shared services)
JWT_SECRET=${jwt_secret}
SECRET_KEY_BASE=${secret_key_base}
PG_META_CRYPTO_KEY=${pg_meta_crypto_key}
VAULT_ENC_KEY=${vault_enc_key}
POOLER_TENANT_ID=${pooler_tenant_id}

# Base API Keys (for shared services - will be replaced per project)
ANON_KEY=${base_anon_key}
SERVICE_ROLE_KEY=${base_service_role_key}

# URLs
SITE_URL=${site_url}
PUBLIC_URL=${public_url}
SUPABASE_PUBLIC_URL=${public_url}
API_EXTERNAL_URL=${public_url}

# Default Settings
PGRST_DB_SCHEMAS=public,storage,graphql_public
JWT_EXPIRY=3600
DISABLE_SIGNUP=false
ENABLE_EMAIL_SIGNUP=true
ENABLE_EMAIL_AUTOCONFIRM=false
ENABLE_ANONYMOUS_USERS=false
ENABLE_PHONE_SIGNUP=false
ENABLE_PHONE_AUTOCONFIRM=false
ADDITIONAL_REDIRECT_URLS=

# Mailer URL Paths
MAILER_URLPATHS_CONFIRMATION=/auth/v1/verify
MAILER_URLPATHS_INVITE=/auth/v1/verify
MAILER_URLPATHS_RECOVERY=/auth/v1/verify
MAILER_URLPATHS_EMAIL_CHANGE=/auth/v1/verify

# SMTP (optional - configure for email features)
SMTP_ADMIN_EMAIL=admin@example.com
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
SMTP_SENDER_NAME=Indie Ventures

# Kong API Gateway
KONG_HTTP_PORT=8000
KONG_HTTPS_PORT=8443

# Supavisor Pooler
POOLER_PROXY_PORT_TRANSACTION=6543
POOLER_DEFAULT_POOL_SIZE=20
POOLER_MAX_CLIENT_CONN=100
POOLER_DB_POOL_SIZE=5

# Image Proxy
IMGPROXY_ENABLE_WEBP_DETECTION=true

# Functions
FUNCTIONS_VERIFY_JWT=false

# Analytics (Logflare)
LOGFLARE_PUBLIC_ACCESS_TOKEN=$(openssl rand -hex 32)
LOGFLARE_PRIVATE_ACCESS_TOKEN=$(openssl rand -hex 32)

# Docker
DOCKER_SOCKET_LOCATION=/var/run/docker.sock
EOF

    success "Created base configuration"

    # Create .env.projects if it doesn't exist
    if ! [ -f "${ENV_PROJECTS}" ]; then
        touch "${ENV_PROJECTS}"
        success "Created projects configuration file"
    fi

    # Copy nginx.conf template
    if ! [ -f "${INDIE_DIR}/nginx/nginx.conf" ]; then
        cp "${TEMPLATES_DIR}/nginx.conf" "${INDIE_DIR}/nginx/nginx.conf"
        success "Created Nginx configuration"
    fi

    # Fetch Supabase official setup for migrations and configs
    # This is required - docker-compose.yml references SQL files from this setup
    info "Fetching Supabase official Docker setup (for migrations and configurations)…"
    if ! fetch_supabase_setup; then
        error "Failed to fetch Supabase official setup"
        error "This is required for proper Supabase initialization."
        error ""
        error "Please ensure:"
        error "  1. Git is installed and accessible"
        error "  2. You have network connectivity to github.com"
        error "  3. You can manually clone: https://github.com/supabase/supabase.git"
        error ""
        error "You can retry initialization or manually clone the repository to:"
        error "  ${INDIE_DIR}/supabase-official"
        exit 1
    fi

    # Initialize Supabase volumes (copy migration files, etc.)
    # This is also required - docker-compose.yml needs these files
    info "Initializing Supabase volumes and migration files…"
    if ! init_supabase_volumes; then
        error "Failed to initialize Supabase volumes"
        error "Migration files are required for proper database initialization."
        error ""
        error "Supabase setup was fetched, but volume initialization failed."
        error "Check file permissions and disk space."
        exit 1
    fi

    success "Initialized Supabase schema migrations"

    # Initialize docker-compose.yml
    info "Setting up Docker Compose…"
    if ! init_docker_compose; then
        error "Failed to initialize Docker Compose"
        exit 1
    fi

    # Pull images
    info "Pulling Docker images (this may take a few minutes)…"
    if ! with_spinner "Pulling images" "cd ${INDIE_DIR} && $(get_compose_cmd) pull"; then
        error "Failed to pull Docker images"
        exit 1
    fi

    # Start base services
    info "Starting base services…"
    if ! start_services; then
        error "Failed to start services"
        exit 1
    fi

    # Wait for PostgreSQL to be ready
    info "Waiting for PostgreSQL to be ready…"
    sleep 5

    # Summary
    echo ""
    show_success_box "Initialization Complete!" "Indie Ventures is ready at: ${INDIE_DIR}

Next steps:
1. Add your first project: indie add
2. List your projects: indie list
3. Check service status: indie status

Studio Dashboard: http://localhost:3000
(or http://your-server-ip:3000 from remote)
"

    success "Initialization complete!"
}
