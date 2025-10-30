#!/usr/bin/env bash

# Remove project

# Load dependencies
source "${LIB_DIR}/core/database.sh"
source "${LIB_DIR}/core/secrets.sh"
source "${LIB_DIR}/core/docker.sh"
source "${LIB_DIR}/core/nginx.sh"
source "${LIB_DIR}/ui/prompts.sh"

cmd_remove() {
    require_init

    local project_name="${1:-}"

    if [ -z "${project_name}" ]; then
        error "Project name required"
        echo "Usage: indie remove <project-name>"
        exit 1
    fi

    if ! project_exists "${project_name}"; then
        error "Project '${project_name}' not found"
        exit 1
    fi

    show_header "Remove Project '${project_name}'"

    warning "This will permanently delete:"
    echo "  - Database and all data"
    echo "  - Docker services"
    echo "  - Nginx configuration"
    echo "  - Secrets"
    echo ""

    if ! confirm "Are you sure you want to remove '${project_name}'?"; then
        info "Cancelled"
        exit 0
    fi

    # Create automatic backup
    info "Creating automatic backup first…"
    source "${LIB_DIR}/commands/backup.sh"
    cmd_backup "${project_name}"
    echo ""

    # Remove database
    info "Removing database…"
    drop_project_database "${project_name}"

    # Remove secrets
    info "Removing secrets…"
    remove_project_secrets "${project_name}"

    # Remove from registry
    info "Removing from registry…"
    jq --arg name "${project_name}" 'del(.[$name])' "${PROJECTS_FILE}" > "${PROJECTS_FILE}.tmp"
    mv "${PROJECTS_FILE}.tmp" "${PROJECTS_FILE}"

    # Remove Docker services (for isolated projects)
    local arch
    arch=$(get_project_property "${project_name}" "architecture" 2>/dev/null || echo "shared")

    if [ "${arch}" = "isolated" ]; then
        info "Removing Docker services…"
        remove_project_services "${project_name}"
    fi

    # Remove Nginx config
    info "Removing Nginx configuration…"
    remove_project_nginx_config "${project_name}"

    # Remove storage
    local storage_dir="${INDIE_DIR}/volumes/${project_name}"
    if [ -d "${storage_dir}" ]; then
        info "Removing storage files…"
        rm -rf "${storage_dir}"
    fi

    # Restart services
    info "Restarting services…"
    restart_services

    if nginx_running; then
        reload_nginx
    fi

    success "Project '${project_name}' removed"
    echo ""
    info "A backup was created in: ${INDIE_DIR}/backups/"
}
