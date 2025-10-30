#!/usr/bin/env bash

# Manage project domains

# Load dependencies
source "${LIB_DIR}/core/nginx.sh"
source "${LIB_DIR}/ui/prompts.sh"

cmd_domains() {
    require_init

    local project_name="$1"

    if [ -z "${project_name}" ]; then
        error "Project name required"
        echo "Usage: indie domains <project-name>"
        exit 1
    fi

    if ! project_exists "${project_name}"; then
        error "Project '${project_name}' not found"
        exit 1
    fi

    show_header "Manage Domains for '${project_name}'"

    # Get current domains
    local current_domains
    current_domains=$(get_project_property "${project_name}" "domains" | jq -r '.[]' 2>/dev/null)

    echo "Current domains:"
    echo "${current_domains}"
    echo ""

    # Prompt for action
    local action
    action=$(prompt_choice "Action" "Add domain" "Remove domain" "Cancel")

    case "${action}" in
        "Add domain")
            local new_domain
            new_domain=$(prompt_input "New domain" "" "newdomain.com")

            if ! validate_domain "${new_domain}"; then
                error "Invalid domain"
                exit 1
            fi

            # Add domain to registry
            jq --arg name "${project_name}" \
               --arg domain "${new_domain}" \
               '.[$name].domains += [$domain]' \
               "${PROJECTS_FILE}" > "${PROJECTS_FILE}.tmp"

            mv "${PROJECTS_FILE}.tmp" "${PROJECTS_FILE}"

            # Regenerate Nginx config
            local domains=()
            while IFS= read -r domain; do
                domains+=("${domain}")
            done < <(get_project_property "${project_name}" "domains" | jq -r '.[]')

            generate_project_nginx_config "${project_name}" "${domains[@]}"
            reload_nginx

            success "Domain '${new_domain}' added"
            ;;

        "Remove domain")
            local domains_array=()
            while IFS= read -r domain; do
                domains_array+=("${domain}")
            done < <(echo "${current_domains}")

            local domain_to_remove
            domain_to_remove=$(prompt_choice "Select domain to remove" "${domains_array[@]}")

            # Remove from registry
            jq --arg name "${project_name}" \
               --arg domain "${domain_to_remove}" \
               '.[$name].domains -= [$domain]' \
               "${PROJECTS_FILE}" > "${PROJECTS_FILE}.tmp"

            mv "${PROJECTS_FILE}.tmp" "${PROJECTS_FILE}"

            # Regenerate Nginx config
            local domains=()
            while IFS= read -r domain; do
                domains+=("${domain}")
            done < <(get_project_property "${project_name}" "domains" | jq -r '.[]')

            generate_project_nginx_config "${project_name}" "${domains[@]}"
            reload_nginx

            success "Domain '${domain_to_remove}' removed"
            ;;

        *)
            info "Cancelled"
            exit 0
            ;;
    esac
}
