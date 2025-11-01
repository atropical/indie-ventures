#!/usr/bin/env bash

# Add new Supabase project

# Load dependencies
source "${LIB_DIR}/core/database.sh"
source "${LIB_DIR}/core/secrets.sh"
source "${LIB_DIR}/core/docker.sh"
source "${LIB_DIR}/core/nginx.sh"
source "${LIB_DIR}/core/ssl.sh"
source "${LIB_DIR}/ui/prompts.sh"
source "${LIB_DIR}/ui/tables.sh"

cmd_add() {
    require_init

    show_header "Add New Supabase Project"

    # Track if we started services (for cleanup on error)
    local services_started_by_script=false

    # Cleanup function to stop services if they were started by this script
    cleanup_on_error() {
        if [ "${services_started_by_script}" = "true" ]; then
            info "Cleaning up: stopping Docker services…"
            stop_services >/dev/null 2>&1 || true
        fi
    }

    # Set trap to cleanup on error or exit
    trap cleanup_on_error ERR EXIT

    # Ensure base services (postgres) are running
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)
    
    local postgres_status
    postgres_status=$(in_indie_dir ${compose_cmd} ps postgres --format json 2>/dev/null | jq -r '.[0].State' 2>/dev/null || echo "missing")
    
    if [ "${postgres_status}" != "running" ]; then
        info "Starting base services…"
        if ! start_services; then
            error "Failed to start services. Please check Docker and try again."
            exit 1
        fi
        services_started_by_script=true
        info "Waiting for PostgreSQL to be ready…"
        sleep 3
    fi

    # Prompt for project name
    local project_name
    while true; do
        project_name=$(prompt_input "Project name" "" "my-blog")

        if validate_project_name "${project_name}"; then
            if project_exists "${project_name}"; then
                error "Project '${project_name}' already exists"
                continue
            fi
            break
        fi
    done

    # Prompt for architecture
    info "Choose architecture:"
    echo "  shared    - Efficient, shares services (recommended for most projects)"
    echo "  isolated  - Dedicated services, complete isolation (for production/important projects)"
    echo ""

    local architecture
    architecture=$(prompt_choice "Architecture" "shared" "isolated")

    # Prompt for domains
    local domains=()
    info "Enter domain(s) for this project (space-separated)"
    info "Example: blog.mydomain.com api.blog.mydomain.com"
    echo ""

    local domains_input
    domains_input=$(prompt_input "Domains" "" "project.yourdomain.com")

    # Split domains
    IFS=' ' read -ra domains <<< "${domains_input}"

    # Validate domains
    for domain in "${domains[@]}"; do
        if ! validate_domain "${domain}"; then
            error "Invalid domain: ${domain}"
            exit 1
        fi
    done

    # Confirm
    echo ""
    info "Summary:"
    echo "  Project: ${project_name}"
    echo "  Architecture: ${architecture}"
    echo "  Domains: ${domains[*]}"
    echo ""

    if ! confirm "Create project?"; then
        info "Cancelled"
        exit 0
    fi

    # Generate JWT secrets
    info "Generating JWT secrets…"
    verbose_log "Generating secure keys for project: ${project_name}"
    local secrets_json
    secrets_json=$(generate_project_keys "${project_name}")

    local jwt_secret
    jwt_secret=$(echo "${secrets_json}" | jq -r '.jwt_secret')
    local anon_key
    anon_key=$(echo "${secrets_json}" | jq -r '.anon_key')
    local service_role_key
    service_role_key=$(echo "${secrets_json}" | jq -r '.service_role_key')

    success "Generated secrets"

    # Save secrets
    save_project_secrets "${project_name}" "${jwt_secret}" "${anon_key}" "${service_role_key}"

    # Create database
    verbose_log "Starting database creation process for: ${project_name}"
    if ! with_spinner "Creating database" "create_project_database '${project_name}'"; then
        error "Failed to create database"
        exit 1
    fi

    # Add project to registry
    local created_at
    created_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local domains_json
    domains_json=$(printf '%s\n' "${domains[@]}" | jq -R . | jq -s .)

    local ports_offset=80  # Default for first isolated project
    if [ "${architecture}" = "isolated" ]; then
        # Calculate next available port offset
        local existing_count
        existing_count=$(jq 'to_entries | map(select(.value.architecture == "isolated")) | length' "${PROJECTS_FILE}")
        ports_offset=$((80 + existing_count + 1))
    fi

    jq --arg name "${project_name}" \
       --arg arch "${architecture}" \
       --arg db "$(slugify "${project_name}")" \
       --argjson domains "${domains_json}" \
       --arg created "${created_at}" \
       --arg ports "${ports_offset}" \
       '.[$name] = {
           "architecture": $arch,
           "database": $db,
           "domains": $domains,
           "created": $created,
           "ports_offset": $ports
       }' "${PROJECTS_FILE}" > "${PROJECTS_FILE}.tmp"

    mv "${PROJECTS_FILE}.tmp" "${PROJECTS_FILE}"
    success "Added project to registry"

    # Update Docker Compose
    if [ "${architecture}" = "shared" ]; then
        # Ensure shared services are added
        if ! add_shared_services; then
            error "Failed to add shared services"
            exit 1
        fi
    else
        # Add isolated services for this project
        if ! add_isolated_project "${project_name}" "${ports_offset}"; then
            error "Failed to add isolated services"
            exit 1
        fi
    fi

    # Generate Nginx config
    if ! generate_project_nginx_config "${project_name}" "${domains[@]}"; then
        error "Failed to generate Nginx config"
        exit 1
    fi

    # Restart services
    info "Starting services…"
    if ! with_spinner "Restarting Docker services" "restart_services"; then
        error "Failed to restart services"
        exit 1
    fi

    # Services are now running successfully, disable cleanup trap
    services_started_by_script=false
    trap - ERR EXIT

    # Reload Nginx
    sleep 2
    if nginx_running; then
        reload_nginx
    fi

    # Display connection info
    echo ""
    show_success_box "Project Created!" "Project '${project_name}' is ready!

Connection Details:
  API URL: http://${domains[0]} (HTTPS available after SSL setup)
  Database: $(slugify "${project_name}")
  Architecture: ${architecture}

API Keys:
  anon key: ${anon_key}
  service_role key: ${service_role_key}

Studio Dashboard: http://localhost:3000
"

    success "Project '${project_name}' created successfully!"

    # Offer SSL setup
    echo ""
    info "Would you like to enable SSL/HTTPS now?"
    info "This will obtain free Let's Encrypt certificates for your domains."
    echo ""

    if confirm "Enable SSL now?"; then
        echo ""
        info "Make sure your DNS A records point to this server before continuing!"
        echo ""

        if confirm "DNS configured and ready to obtain certificates?"; then
            # Load SSL module
            source "${LIB_DIR}/core/ssl.sh"

            # Get email
            local email
            email=$(prompt_input "Email for Let's Encrypt notifications" "" "admin@${domains[0]}")

            # Enable SSL
            if enable_ssl_for_project "${project_name}" "${email}"; then
                echo ""
                show_success_box "SSL Enabled!" "Your project is now secured with HTTPS!

HTTPS URLs:
$(for domain in "${domains[@]}"; do echo "  https://${domain}"; done)

Certificates will be automatically renewed.
"
            else
                warning "SSL setup failed. You can try again later with:"
                echo "  indie ssl enable ${project_name}"
            fi
        else
            info "You can enable SSL later with:"
            echo "  indie ssl enable ${project_name}"
        fi
    else
        echo ""
        info "Next Steps:"
        echo "1. Point your domain DNS A records to this server's IP"
        echo "2. Enable SSL: indie ssl enable ${project_name}"
        echo "3. Use the API keys in your application"
    fi
}
