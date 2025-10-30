#!/usr/bin/env bash

# SSL/TLS management with Let's Encrypt for Indie Ventures

# Check if Certbot container is running
certbot_running() {
    docker ps --format '{{.Names}}' | grep -q "indie-certbot"
}

# Run Certbot command
run_certbot() {
    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    in_indie_dir ${compose_cmd} run --rm certbot "$@"
}

# Obtain SSL certificate for domain
obtain_certificate() {
    local domain="$1"
    local email="${2:-}"

    if [ -z "${domain}" ]; then
        error "Domain required"
        return 1
    fi

    # Validate domain
    if ! validate_domain "${domain}"; then
        error "Invalid domain: ${domain}"
        return 1
    fi

    # Check if certificate already exists
    if certificate_exists "${domain}"; then
        warning "Certificate for ${domain} already exists"
        if ! confirm "Renew certificate?"; then
            return 0
        fi
    fi

    # Ensure email is provided
    if [ -z "${email}" ]; then
        info "Email is required for Let's Encrypt notifications"
        email=$(prompt_input "Email address" "" "admin@example.com")
    fi

    info "Obtaining SSL certificate for ${domain}…"
    info "This may take a minute…"

    # Use webroot method (Nginx serves the challenge)
    if run_certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "${email}" \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d "${domain}"; then

        success "Certificate obtained for ${domain}"

        # Reload Nginx to use new certificate
        if nginx_running; then
            reload_nginx
        fi

        return 0
    else
        error "Failed to obtain certificate for ${domain}"
        return 1
    fi
}

# Check if certificate exists
certificate_exists() {
    local domain="$1"
    local cert_path="${INDIE_DIR}/volumes/certbot/conf/live/${domain}/fullchain.pem"

    [ -f "${cert_path}" ]
}

# Get certificate expiry date
get_certificate_expiry() {
    local domain="$1"
    local cert_path="${INDIE_DIR}/volumes/certbot/conf/live/${domain}/fullchain.pem"

    if ! certificate_exists "${domain}"; then
        echo "N/A"
        return 1
    fi

    openssl x509 -enddate -noout -in "${cert_path}" 2>/dev/null | cut -d= -f2
}

# Get days until certificate expires
get_certificate_days_remaining() {
    local domain="$1"
    local cert_path="${INDIE_DIR}/volumes/certbot/conf/live/${domain}/fullchain.pem"

    if ! certificate_exists "${domain}"; then
        echo "0"
        return 1
    fi

    local expiry_date
    expiry_date=$(openssl x509 -enddate -noout -in "${cert_path}" 2>/dev/null | cut -d= -f2)

    local expiry_epoch
    expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "${expiry_date}" +%s 2>/dev/null)

    local now_epoch
    now_epoch=$(date +%s)

    local days_remaining=$(( (expiry_epoch - now_epoch) / 86400 ))

    echo "${days_remaining}"
}

# Renew all certificates
renew_certificates() {
    info "Checking for certificates to renew…"

    if ! run_certbot renew --quiet; then
        error "Certificate renewal failed"
        return 1
    fi

    success "Certificate renewal complete"

    # Reload Nginx
    if nginx_running; then
        reload_nginx
    fi

    return 0
}

# Setup automatic renewal
setup_auto_renewal() {
    info "Setting up automatic certificate renewal…"

    # Create renewal script
    local renewal_script="${INDIE_DIR}/scripts/renew-certs.sh"
    mkdir -p "${INDIE_DIR}/scripts"

    cat > "${renewal_script}" << 'EOF'
#!/usr/bin/env bash
# Automatic SSL certificate renewal for Indie Ventures

set -euo pipefail

INDIE_DIR="${INDIE_DIR:-/opt/indie-ventures}"
LOG_FILE="${INDIE_DIR}/volumes/logs/certbot-renewal.log"

echo "[$(date)] Starting certificate renewal check" >> "${LOG_FILE}"

cd "${INDIE_DIR}"

# Get docker-compose command
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    echo "[$(date)] ERROR: docker-compose not found" >> "${LOG_FILE}"
    exit 1
fi

# Run renewal
if ${COMPOSE_CMD} run --rm certbot renew --quiet >> "${LOG_FILE}" 2>&1; then
    echo "[$(date)] Certificate renewal successful" >> "${LOG_FILE}"

    # Reload Nginx
    ${COMPOSE_CMD} exec nginx nginx -s reload >> "${LOG_FILE}" 2>&1 || true

    echo "[$(date)] Nginx reloaded" >> "${LOG_FILE}"
else
    echo "[$(date)] ERROR: Certificate renewal failed" >> "${LOG_FILE}"
    exit 1
fi

echo "[$(date)] Certificate renewal check complete" >> "${LOG_FILE}"
EOF

    chmod +x "${renewal_script}"
    success "Created renewal script: ${renewal_script}"

    # Setup cron job
    local cron_entry="0 0,12 * * * ${renewal_script}"

    # Check if cron entry already exists
    if crontab -l 2>/dev/null | grep -q "${renewal_script}"; then
        info "Cron job already exists"
    else
        # Add cron job (runs twice daily at midnight and noon)
        (crontab -l 2>/dev/null; echo "${cron_entry}") | crontab -
        success "Added cron job for automatic renewal (twice daily)"
    fi

    info "Certificates will be automatically renewed when they have less than 30 days remaining"

    return 0
}

# Remove SSL certificate
remove_certificate() {
    local domain="$1"

    if ! certificate_exists "${domain}"; then
        warning "Certificate for ${domain} does not exist"
        return 0
    fi

    warning "This will remove the SSL certificate for ${domain}"
    if ! confirm "Are you sure?"; then
        info "Cancelled"
        return 0
    fi

    # Revoke and delete certificate
    if run_certbot revoke \
        --cert-path "/etc/letsencrypt/live/${domain}/cert.pem" \
        --delete-after-revoke; then

        success "Certificate removed for ${domain}"

        # Reload Nginx
        if nginx_running; then
            reload_nginx
        fi

        return 0
    else
        error "Failed to remove certificate"
        return 1
    fi
}

# List all certificates
list_certificates() {
    if ! run_certbot certificates 2>/dev/null; then
        info "No certificates found"
        return 0
    fi
}

# Show certificate status for domain
show_certificate_status() {
    local domain="$1"

    if ! certificate_exists "${domain}"; then
        echo "Status: No certificate"
        return 1
    fi

    local expiry
    expiry=$(get_certificate_expiry "${domain}")

    local days_remaining
    days_remaining=$(get_certificate_days_remaining "${domain}")

    echo "Status: Active"
    echo "Expires: ${expiry}"
    echo "Days remaining: ${days_remaining}"

    if [ "${days_remaining}" -lt 30 ]; then
        warning "Certificate will expire soon!"
    fi

    return 0
}

# Enable SSL for project
enable_ssl_for_project() {
    local project_name="$1"
    local email="${2:-}"

    if ! project_exists "${project_name}"; then
        error "Project '${project_name}' not found"
        return 1
    fi

    info "Enabling SSL for project: ${project_name}"

    # Get all domains for the project
    local domains
    mapfile -t domains < <(get_project_property "${project_name}" "domains" | jq -r '.[]')

    if [ ${#domains[@]} -eq 0 ]; then
        error "No domains configured for ${project_name}"
        return 1
    fi

    # Get email if not provided
    if [ -z "${email}" ]; then
        email=$(prompt_input "Email for Let's Encrypt notifications" "" "admin@${domains[0]}")
    fi

    # Obtain certificates for all domains
    local success_count=0
    for domain in "${domains[@]}"; do
        info "Processing ${domain}…"

        if obtain_certificate "${domain}" "${email}"; then
            ((success_count++))
        else
            warning "Failed to obtain certificate for ${domain}"
        fi
    done

    if [ ${success_count} -eq 0 ]; then
        error "Failed to obtain any certificates"
        return 1
    fi

    # Regenerate Nginx config with SSL enabled
    generate_project_nginx_config_with_ssl "${project_name}" "${domains[@]}"

    # Reload Nginx
    reload_nginx

    success "SSL enabled for ${project_name}"
    info "Your project is now accessible via HTTPS"

    return 0
}

# Test SSL configuration
test_ssl() {
    local domain="$1"

    info "Testing SSL configuration for ${domain}…"

    # Test with curl
    if curl -sSI "https://${domain}" >/dev/null 2>&1; then
        success "SSL is working correctly for ${domain}"

        # Show certificate info
        echo ""
        info "Certificate information:"
        echo | openssl s_client -servername "${domain}" -connect "${domain}:443" 2>/dev/null | openssl x509 -noout -dates

        return 0
    else
        error "SSL connection failed for ${domain}"
        return 1
    fi
}
