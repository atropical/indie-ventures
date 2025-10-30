#!/usr/bin/env bash

# Initialize Indie Ventures on the server

# Load dependencies
source "${LIB_DIR}/core/deps.sh"
source "${LIB_DIR}/core/docker.sh"
source "${LIB_DIR}/ui/prompts.sh"

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
        # Update dependent paths
        PROJECTS_FILE="${INDIE_DIR}/projects/registry.json"
        ENV_BASE="${INDIE_DIR}/.env.base"
        ENV_PROJECTS="${INDIE_DIR}/.env.projects"
        info "Using data directory: ${INDIE_DIR}"
    else
        info "Using default directory: ${INDIE_DIR}"
    fi
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

    local dashboard_password
    if [ -f "${ENV_BASE}" ] && grep -q "DASHBOARD_PASSWORD" "${ENV_BASE}"; then
        info "Using existing Dashboard password"
        dashboard_password=$(grep "DASHBOARD_PASSWORD" "${ENV_BASE}" | cut -d'=' -f2)
    else
        echo ""
        dashboard_password=$(prompt_password_confirm "Studio Dashboard password")
    fi

    # Create .env.base
    cat > "${ENV_BASE}" << EOF
# Indie Ventures Base Configuration
# Generated: $(date)

# PostgreSQL
POSTGRES_PASSWORD=${postgres_password}
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

# Studio Dashboard
DASHBOARD_PASSWORD=${dashboard_password}
STUDIO_DEFAULT_ORGANIZATION=Indie Ventures
STUDIO_DEFAULT_PROJECT=Default

# Default Settings
PGRST_DB_SCHEMAS=public,storage,graphql_public
JWT_EXPIRY=3600
DISABLE_SIGNUP=false
ENABLE_EMAIL_SIGNUP=true
ENABLE_EMAIL_AUTOCONFIRM=false

# SMTP (optional - configure for email features)
SMTP_ADMIN_EMAIL=admin@example.com
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
SMTP_SENDER_NAME=Indie Ventures
EOF

    success "Created base configuration"

    # Create .env.projects if it doesn't exist
    if ! [ -f "${ENV_PROJECTS}" ]; then
        touch "${ENV_PROJECTS}"
        success "Created projects configuration file"
    fi

    # Copy nginx.conf template
    if ! [ -f "${INDIE_DIR}/nginx/nginx.conf" ]; then
        cp "${SCRIPT_DIR}/../templates/nginx.conf" "${INDIE_DIR}/nginx/nginx.conf"
        success "Created Nginx configuration"
    fi

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
