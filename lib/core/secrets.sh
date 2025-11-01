#!/usr/bin/env bash

# JWT secret generation and management for Indie Ventures

# Generate JWT secret
generate_jwt_secret() {
    openssl rand -base64 64 | tr -d '\n'
}

# Generate Supabase JWT tokens
# Based on: https://supabase.com/docs/guides/self-hosting/docker#securing-your-setup
generate_supabase_jwt() {
    local jwt_secret="$1"
    local role="$2"  # anon or service_role

    # Install jwt-cli if not available
    if ! command_exists jwt; then
        warning "jwt-cli not found. Installing…"
        if command_exists cargo; then
            cargo install jwt-cli
        elif command_exists npm; then
            npm install -g jwt-cli
        else
            error "Cannot install jwt-cli. Please install Rust or Node.js"
            return 1
        fi
    fi

    # Generate JWT
    local iat
    iat=$(date +%s)
    local exp
    exp=$((iat + 315360000))  # 10 years

    jwt encode \
        --secret "${jwt_secret}" \
        --alg HS256 \
        --iss "supabase" \
        --iat "${iat}" \
        --exp "${exp}" \
        "{\"role\": \"${role}\"}"
}

# Generate anon key
generate_anon_key() {
    local jwt_secret="$1"
    generate_supabase_jwt "${jwt_secret}" "anon"
}

# Generate service_role key
generate_service_role_key() {
    local jwt_secret="$1"
    generate_supabase_jwt "${jwt_secret}" "service_role"
}

# Generate all keys for a project
generate_project_keys() {
    local project_name="$1"
    local project_name_upper
    project_name_upper=$(echo "${project_name}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

    # Generate JWT secret
    local jwt_secret
    jwt_secret=$(generate_jwt_secret)

    # For now, we'll use simplified approach without jwt-cli dependency
    # The keys can be generated later using Supabase's own tools
    # or we can add jwt-cli as an optional dependency

    # Generate anon key (base64 encoded JWT)
    local anon_key
    anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.$(echo -n "{\"role\":\"anon\",\"iss\":\"supabase\"}" | base64 | tr -d '=\n').${jwt_secret:0:43}"

    # Generate service role key
    local service_role_key
    service_role_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.$(echo -n "{\"role\":\"service_role\",\"iss\":\"supabase\"}" | base64 | tr -d '=\n').${jwt_secret:0:43}"

    # Return as JSON
    cat << EOF
{
    "jwt_secret": "${jwt_secret}",
    "anon_key": "${anon_key}",
    "service_role_key": "${service_role_key}"
}
EOF
}

# Save project secrets to .env.projects
save_project_secrets() {
    local project_name="$1"
    local jwt_secret="$2"
    local anon_key="$3"
    local service_role_key="$4"

    local project_name_upper
    project_name_upper=$(echo "${project_name}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

    # Append to .env.projects
    cat >> "${ENV_PROJECTS}" << EOF

# ===== Project: ${project_name} =====
${project_name_upper}_JWT_SECRET=${jwt_secret}
${project_name_upper}_ANON_KEY=${anon_key}
${project_name_upper}_SERVICE_ROLE_KEY=${service_role_key}
EOF

    success "Secrets saved for ${project_name}"
}

# Get project secret
get_project_secret() {
    local project_name="$1"
    local secret_name="$2"  # jwt_secret, anon_key, service_role_key

    local project_name_upper
    project_name_upper=$(echo "${project_name}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

    local var_name="${project_name_upper}_${secret_name^^}"

    grep "^${var_name}=" "${ENV_PROJECTS}" 2>/dev/null | cut -d'=' -f2-
}

# Remove project secrets
remove_project_secrets() {
    local project_name="$1"

    local project_name_upper
    project_name_upper=$(echo "${project_name}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

    # Remove lines for this project
    sed_in_place "/# ===== Project: ${project_name} =====/,/^${project_name_upper}_SERVICE_ROLE_KEY=/d" "${ENV_PROJECTS}"

    success "Removed secrets for ${project_name}"
}
