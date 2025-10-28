#!/usr/bin/env bash

# Show service status

# Load dependencies
source "${LIB_DIR}/core/docker.sh"

cmd_status() {
    require_init

    show_header "Indie Ventures Status"

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running"
        exit 1
    fi

    success "Docker is running"
    echo ""

    # Show Docker Compose services
    info "Services:"
    echo ""

    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    in_indie_dir ${compose_cmd} ps

    echo ""

    # Count running services
    local running_count
    running_count=$(services_running)

    if [ "${running_count}" -gt 0 ]; then
        success "${running_count} services running"
    else
        warning "No services running"
        echo ""
        echo "Start services with: indie init"
    fi
}
