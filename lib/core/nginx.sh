#!/usr/bin/env bash

# Nginx configuration management for Indie Ventures

# Generate Nginx site config for project
generate_project_nginx_config() {
    local project_name="$1"
    local domains=("${@:2}")
    local architecture
    architecture=$(get_project_property "${project_name}" "architecture")

    if [ -z "${architecture}" ]; then
        error "Could not determine architecture for project '${project_name}'"
        return 1
    fi

    local output_file="${INDIE_DIR}/nginx/sites/${project_name}.conf"

    # Determine backend based on architecture
    local backend
    if [ "${architecture}" = "shared" ]; then
        backend="http://indie-kong:8000"
    else
        # For isolated, each project has its own Kong
        backend="http://indie-${project_name}-kong:8000"
    fi

    # Create server block for each domain
    local config=""
    for domain in "${domains[@]}"; do
        config+="
server {
    listen 80;
    server_name ${domain};

    # Let's Encrypt ACME challenge (for obtaining SSL certificates)
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass ${backend};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"upgrade\";
    }
}
"
    done

    # Write config file
    mkdir -p "$(dirname "${output_file}")"
    echo "${config}" > "${output_file}"

    success "Generated Nginx config for ${project_name}"
    return 0
}

# Remove Nginx config for project
remove_project_nginx_config() {
    local project_name="$1"
    local config_file="${INDIE_DIR}/nginx/sites/${project_name}.conf"

    if [ -f "${config_file}" ]; then
        rm -f "${config_file}"
        success "Removed Nginx config for ${project_name}"
    fi

    return 0
}

# Reload Nginx
reload_nginx() {
    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    info "Reloading Nginx…"

    if ! in_indie_dir ${compose_cmd} exec nginx nginx -s reload; then
        error "Failed to reload Nginx"
        return 1
    fi

    success "Nginx reloaded"
    return 0
}

# Test Nginx configuration
test_nginx_config() {
    local compose_cmd
    compose_cmd=$(get_compose_cmd)

    in_indie_dir ${compose_cmd} exec nginx nginx -t
}

# Generate Nginx site config with SSL enabled
generate_project_nginx_config_with_ssl() {
    local project_name="$1"
    local domains=("${@:2}")
    local architecture
    architecture=$(get_project_property "${project_name}" "architecture")

    if [ -z "${architecture}" ]; then
        error "Could not determine architecture for project '${project_name}'"
        return 1
    fi

    local output_file="${INDIE_DIR}/nginx/sites/${project_name}.conf"

    # Determine backend based on architecture
    local backend
    if [ "${architecture}" = "shared" ]; then
        backend="http://indie-kong:8000"
    else
        backend="http://indie-${project_name}-kong:8000"
    fi

    # Create server block for each domain
    local config=""
    for domain in "${domains[@]}"; do
        config+="
# HTTP server - Redirect to HTTPS and serve ACME challenge
server {
    listen 80;
    server_name ${domain};

    # Let's Encrypt ACME challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Redirect all other requests to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name ${domain};

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # HSTS (optional but recommended)
    add_header Strict-Transport-Security \"max-age=31536000; includeSubDomains\" always;

    location / {
        proxy_pass ${backend};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"upgrade\";
    }
}
"
    done

    # Write config file
    mkdir -p "$(dirname "${output_file}")"
    echo "${config}" > "${output_file}"

    success "Generated Nginx config with SSL for ${project_name}"
    return 0
}

# Check if Nginx is running
nginx_running() {
    docker ps --format '{{.Names}}' | grep -q "indie-nginx"
}
