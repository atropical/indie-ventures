#!/usr/bin/env bash

# SSL certificate management command

# Load dependencies
source "${LIB_DIR}/core/ssl.sh"
source "${LIB_DIR}/core/nginx.sh"
source "${LIB_DIR}/ui/prompts.sh"

cmd_ssl() {
    require_init

    local subcommand="${1:-}"

    case "${subcommand}" in
        enable)
            ssl_enable "${@:2}"
            ;;
        renew)
            ssl_renew
            ;;
        list)
            ssl_list
            ;;
        status)
            ssl_status "${@:2}"
            ;;
        remove)
            ssl_remove "${@:2}"
            ;;
        setup-auto-renewal)
            ssl_setup_auto_renewal
            ;;
        test)
            ssl_test "${@:2}"
            ;;
        *)
            ssl_help
            ;;
    esac
}

# Show SSL help
ssl_help() {
    cat << EOF
SSL Certificate Management

Usage:
  indie ssl <command> [options]

Commands:
  enable <project>       Enable SSL for a project (obtains certificates)
  renew                  Renew all certificates
  list                   List all certificates
  status <project>       Show certificate status for project
  remove <project>       Remove SSL certificate for project
  setup-auto-renewal     Setup automatic certificate renewal
  test <domain>          Test SSL configuration for domain

Examples:
  indie ssl enable my-blog              # Enable SSL for my-blog
  indie ssl renew                       # Renew all certificates
  indie ssl list                        # List all certificates
  indie ssl status my-blog              # Check certificate status
  indie ssl setup-auto-renewal          # Setup automatic renewal

Notes:
  - Certificates are automatically renewed by Certbot
  - Renewal checks happen twice daily
  - Certificates are renewed when < 30 days remain
  - DNS must be configured before obtaining certificates

EOF
}

# Enable SSL for project
ssl_enable() {
    local project_name="$1"

    if [ -z "${project_name}" ]; then
        error "Project name required"
        echo ""
        echo "Usage: indie ssl enable <project-name>"
        exit 1
    fi

    if ! project_exists "${project_name}"; then
        error "Project '${project_name}' not found"
        exit 1
    fi

    show_header "Enable SSL for '${project_name}'"

    # Get domains
    local domains=()
    while IFS= read -r domain; do
        domains+=("${domain}")
    done < <(get_project_property "${project_name}" "domains" | jq -r '.[]')

    if [ ${#domains[@]} -eq 0 ]; then
        error "No domains configured for ${project_name}"
        exit 1
    fi

    info "Domains: ${domains[*]}"
    echo ""

    # Verify DNS
    warning "Before obtaining SSL certificates, ensure:"
    echo "  1. DNS A records point to this server's IP"
    echo "  2. Domains are accessible via HTTP (port 80)"
    echo ""

    info "Checking DNS configuration…"
    local dns_ok=true
    for domain in "${domains[@]}"; do
        if host "${domain}" >/dev/null 2>&1; then
            success "${domain} - DNS configured"
        else
            warning "${domain} - DNS not found or not propagated"
            dns_ok=false
        fi
    done
    echo ""

    if [ "${dns_ok}" = "false" ]; then
        warning "Some domains may not have DNS configured correctly"
        if ! confirm "Continue anyway?"; then
            info "Cancelled"
            exit 0
        fi
    fi

    # Get email
    local email
    email=$(prompt_input "Email for Let's Encrypt notifications" "" "admin@${domains[0]}")

    if [ -z "${email}" ]; then
        error "Email is required"
        exit 1
    fi

    # Enable SSL
    if ! enable_ssl_for_project "${project_name}" "${email}"; then
        error "Failed to enable SSL"
        exit 1
    fi

    echo ""
    show_success_box "SSL Enabled!" "SSL certificates have been obtained for:
  ${domains[*]}

Your project is now accessible via HTTPS!

HTTPS URLs:
$(for domain in "${domains[@]}"; do echo "  https://${domain}"; done)

Certificates will be automatically renewed by Certbot.
"

    success "SSL enabled for ${project_name}"
}

# Renew certificates
ssl_renew() {
    show_header "Renew SSL Certificates"

    info "Checking for certificates to renew…"
    info "Certbot will only renew certificates with < 30 days remaining"
    echo ""

    if ! renew_certificates; then
        error "Certificate renewal failed"
        exit 1
    fi

    success "Certificate renewal complete"
}

# List certificates
ssl_list() {
    show_header "SSL Certificates"

    list_certificates
}

# Show certificate status
ssl_status() {
    local project_name="$1"

    if [ -z "${project_name}" ]; then
        error "Project name required"
        echo ""
        echo "Usage: indie ssl status <project-name>"
        exit 1
    fi

    if ! project_exists "${project_name}"; then
        error "Project '${project_name}' not found"
        exit 1
    fi

    show_header "SSL Status for '${project_name}'"

    # Get domains
    local domains=()
    while IFS= read -r domain; do
        domains+=("${domain}")
    done < <(get_project_property "${project_name}" "domains" | jq -r '.[]')

    for domain in "${domains[@]}"; do
        echo ""
        info "Domain: ${domain}"
        echo "─────────────────────────────"
        show_certificate_status "${domain}"
    done
}

# Remove SSL certificate
ssl_remove() {
    local project_name="$1"

    if [ -z "${project_name}" ]; then
        error "Project name required"
        echo ""
        echo "Usage: indie ssl remove <project-name>"
        exit 1
    fi

    if ! project_exists "${project_name}"; then
        error "Project '${project_name}' not found"
        exit 1
    fi

    show_header "Remove SSL for '${project_name}'"

    # Get domains
    local domains=()
    while IFS= read -r domain; do
        domains+=("${domain}")
    done < <(get_project_property "${project_name}" "domains" | jq -r '.[]')

    warning "This will remove SSL certificates for:"
    for domain in "${domains[@]}"; do
        echo "  - ${domain}"
    done
    echo ""

    if ! confirm "Are you sure?"; then
        info "Cancelled"
        exit 0
    fi

    # Remove certificates
    for domain in "${domains[@]}"; do
        if certificate_exists "${domain}"; then
            remove_certificate "${domain}"
        fi
    done

    # Regenerate Nginx config without SSL
    generate_project_nginx_config "${project_name}" "${domains[@]}"
    reload_nginx

    success "SSL removed for ${project_name}"
}

# Setup automatic renewal
ssl_setup_auto_renewal() {
    show_header "Setup Automatic Certificate Renewal"

    info "This will setup automatic renewal of SSL certificates"
    info "Certificates will be checked twice daily and renewed when < 30 days remain"
    echo ""

    if ! setup_auto_renewal; then
        error "Failed to setup automatic renewal"
        exit 1
    fi

    show_success_box "Auto-Renewal Configured!" "SSL certificates will be automatically renewed.

Schedule: Twice daily (00:00 and 12:00)
Renewal threshold: < 30 days remaining
Log file: /opt/indie-ventures/volumes/logs/certbot-renewal.log

You can manually trigger renewal with:
  indie ssl renew
"

    success "Automatic renewal configured"
}

# Test SSL
ssl_test() {
    local domain="$1"

    if [ -z "${domain}" ]; then
        error "Domain required"
        echo ""
        echo "Usage: indie ssl test <domain>"
        exit 1
    fi

    show_header "Test SSL for '${domain}'"

    test_ssl "${domain}"
}
