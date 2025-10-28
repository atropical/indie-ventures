#!/usr/bin/env bash

# Docker Compose management for Indie Ventures

# Get the docker-compose command (handles both old and new syntax)
get_compose_cmd() {
    get_docker_compose_cmd
}

# Initialize docker-compose.yml from template
init_docker_compose() {
    local template_file="${SCRIPT_DIR}/../templates/docker-compose.base.yml"
    local target_file="${INDIE_DIR}/docker-compose.yml"

    if [ -f "${target_file}" ]; then
        warning "docker-compose.yml already exists"
        return 0
    fi

    if ! [ -f "${template_file}" ]; then
        error "Template file not found: ${template_file}"
        return 1
    fi

    cp "${template_file}" "${target_file}"
    success "Created docker-compose.yml"
    return 0
}

# Start Docker services
start_services() {
    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    info "Starting Docker services..."

    if ! in_indie_dir ${compose_cmd} up -d; then
        error "Failed to start services"
        return 1
    fi

    success "Services started"
    return 0
}

# Stop Docker services
stop_services() {
    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    info "Stopping Docker services..."

    if ! in_indie_dir ${compose_cmd} down; then
        error "Failed to stop services"
        return 1
    fi

    success "Services stopped"
    return 0
}

# Restart Docker services
restart_services() {
    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    info "Restarting Docker services..."

    if ! in_indie_dir ${compose_cmd} restart; then
        error "Failed to restart services"
        return 1
    fi

    success "Services restarted"
    return 0
}

# Check if services are running
services_running() {
    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    in_indie_dir ${compose_cmd} ps --services --filter "status=running" | wc -l
}

# Pull latest images
pull_images() {
    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    info "Pulling latest images..."

    if ! in_indie_dir ${compose_cmd} pull; then
        error "Failed to pull images"
        return 1
    fi

    success "Images pulled"
    return 0
}

# Add shared services to docker-compose.yml
add_shared_services() {
    local template_file="${SCRIPT_DIR}/../templates/docker-compose.shared.yml"
    local target_file="${INDIE_DIR}/docker-compose.yml"

    if ! [ -f "${template_file}" ]; then
        error "Shared services template not found"
        return 1
    fi

    # Check if shared services already added
    if grep -q "# SHARED SUPABASE SERVICES" "${target_file}"; then
        info "Shared services already configured"
        return 0
    fi

    # Append shared services
    echo "" >> "${target_file}"
    cat "${template_file}" >> "${target_file}"

    success "Added shared Supabase services"
    return 0
}

# Add isolated project services to docker-compose.yml
add_isolated_project() {
    local project_name="$1"
    local ports_offset="$2"  # Used to calculate unique ports
    local template_file="${SCRIPT_DIR}/../templates/docker-compose.isolated.yml"
    local target_file="${INDIE_DIR}/docker-compose.yml"

    if ! [ -f "${template_file}" ]; then
        error "Isolated services template not found"
        return 1
    fi

    # Check if project already added
    if grep -q "# PROJECT: ${project_name}" "${target_file}"; then
        warning "Project ${project_name} already in docker-compose.yml"
        return 0
    fi

    # Generate project-specific compose fragment
    # Replace placeholders: {{PROJECT_NAME}}, {{PORTS_OFFSET}}
    local temp_file
    temp_file=$(mktemp)

    sed -e "s/{{PROJECT_NAME}}/${project_name}/g" \
        -e "s/{{PORTS_OFFSET}}/${ports_offset}/g" \
        "${template_file}" > "${temp_file}"

    # Append to docker-compose.yml
    echo "" >> "${target_file}"
    echo "  # PROJECT: ${project_name} (isolated)" >> "${target_file}"
    cat "${temp_file}" >> "${target_file}"
    rm -f "${temp_file}"

    success "Added isolated services for ${project_name}"
    return 0
}

# Remove project services from docker-compose.yml
remove_project_services() {
    local project_name="$1"
    local target_file="${INDIE_DIR}/docker-compose.yml"

    if ! grep -q "# PROJECT: ${project_name}" "${target_file}"; then
        info "Project ${project_name} not found in docker-compose.yml"
        return 0
    fi

    # Create backup
    cp "${target_file}" "${target_file}.bak"

    # Remove project section
    # This is a simplified approach; proper implementation would use yq or similar
    sed -i.tmp "/# PROJECT: ${project_name}/,/^$/d" "${target_file}"
    rm -f "${target_file}.tmp"

    success "Removed services for ${project_name}"
    return 0
}

# Reload services (pull + restart)
reload_services() {
    pull_images
    restart_services
}

# Show logs for a service
show_logs() {
    local service_name="$1"
    local follow="${2:-false}"
    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    if [ "${follow}" = "true" ]; then
        in_indie_dir ${compose_cmd} logs -f "${service_name}"
    else
        in_indie_dir ${compose_cmd} logs --tail=100 "${service_name}"
    fi
}

# Get service status
get_service_status() {
    local service_name="$1"
    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    in_indie_dir ${compose_cmd} ps "${service_name}" --format json 2>/dev/null | jq -r '.[0].State' 2>/dev/null || echo "unknown"
}
