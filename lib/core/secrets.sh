#!/usr/bin/env bash

# JWT secret generation and management for Indie Ventures

# Generate JWT secret (minimum 32 characters as per Supabase requirements)
generate_jwt_secret() {
    openssl rand -base64 32 | tr -d '\n'
}

# Generate SECRET_KEY_BASE (64+ characters, used by Realtime and Supavisor)
# According to Supabase: openssl rand -base64 48
generate_secret_key_base() {
    openssl rand -base64 48 | tr -d '\n'
}

# Generate encryption key (32+ characters, for PG_META_CRYPTO_KEY, VAULT_ENC_KEY)
generate_encryption_key() {
    openssl rand -base64 32 | tr -d '\n'
}

# Generate POOLER_TENANT_ID (unique tenant identifier for Supavisor)
generate_pooler_tenant_id() {
    # Generate a unique tenant ID (lowercase, alphanumeric with hyphens)
    openssl rand -hex 16 | tr '[:upper:]' '[:lower:]'
}

# Generate Supabase JWT tokens
# Based on: https://supabase.com/docs/guides/self-hosting/docker#securing-your-setup
# Note: Official Supabase docs recommend generating JWT using their online tool or jwt-cli
# For production, users should generate these keys using Supabase's official method
# This function attempts to generate a proper JWT, but may require jwt-cli for accuracy
generate_supabase_jwt() {
    local jwt_secret="$1"
    local role="$2"  # anon or service_role

    # Try to use jwt-cli if available
    if command_exists jwt; then
        local iat
        iat=$(date +%s)
        local exp
        exp=$((iat + 315360000))  # 10 years

        jwt encode \
            --secret "${jwt_secret}" \
            --alg HS256 \
            --iss "supabase-demo" \
            --iat "${iat}" \
            --exp "${exp}" \
            "{\"role\": \"${role}\"}" 2>/dev/null || return 1
    else
        # Fallback: generate a JWT-like token structure
        # WARNING: This is not a properly signed JWT, users should generate proper keys
        # This matches the format from Supabase's .env.example
        local header="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        local payload
        payload=$(echo -n "{\"role\":\"${role}\",\"iss\":\"supabase-demo\",\"iat\":1641769200,\"exp\":1799535600}" | base64 | tr -d '=\n')
        local signature
        signature=$(echo -n "${header}.${payload}" | openssl dgst -sha256 -hmac "${jwt_secret}" -binary | base64 | tr -d '=\n')
        echo "${header}.${payload}.${signature}"
    fi
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

# Generate all keys for a project (matches Supabase official requirements)
generate_project_keys() {
    local project_name="$1"

    # Generate JWT secret (32+ chars)
    local jwt_secret
    jwt_secret=$(generate_jwt_secret)

    # Generate SECRET_KEY_BASE (64+ chars for Realtime and Supavisor)
    local secret_key_base
    secret_key_base=$(generate_secret_key_base)

    # Generate encryption keys
    local pg_meta_crypto_key
    pg_meta_crypto_key=$(generate_encryption_key)
    local vault_enc_key
    vault_enc_key=$(generate_encryption_key)

    # Generate POOLER_TENANT_ID
    local pooler_tenant_id
    pooler_tenant_id=$(generate_pooler_tenant_id)

    # Generate JWT keys (anon and service_role)
    # Note: These should ideally be generated using Supabase's official JWT generator
    # We generate them here, but users can regenerate using Supabase's tool if needed
    local anon_key
    anon_key=$(generate_supabase_jwt "${jwt_secret}" "anon" 2>/dev/null || echo "")
    local service_role_key
    service_role_key=$(generate_supabase_jwt "${jwt_secret}" "service_role" 2>/dev/null || echo "")

    # If JWT generation failed, use example format (users should regenerate these)
    if [ -z "${anon_key}" ] || [ -z "${service_role_key}" ]; then
        warning "Could not generate proper JWT keys. Using placeholder format."
        warning "Please regenerate keys using Supabase's official JWT generator."
        anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.INVALID_PLACEHOLDER_REPLACE_WITH_PROPER_KEY"
        service_role_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJzZXJ2aWNlX3JvbGUiLAogICAgImlzcyI6ICJzdXBhYmFzZS1kZW1vIiwKICAgICJpYXQiOiAxNjQxNzY5MjAwLAogICAgImV4cCI6IDE3OTk1MzU2MDAKfQ.INVALID_PLACEHOLDER_REPLACE_WITH_PROPER_KEY"
    fi

    # Return as JSON
    cat << EOF
{
    "jwt_secret": "${jwt_secret}",
    "secret_key_base": "${secret_key_base}",
    "pg_meta_crypto_key": "${pg_meta_crypto_key}",
    "vault_enc_key": "${vault_enc_key}",
    "pooler_tenant_id": "${pooler_tenant_id}",
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
    local secret_key_base="${5:-}"
    local pg_meta_crypto_key="${6:-}"
    local vault_enc_key="${7:-}"
    local pooler_tenant_id="${8:-}"

    local project_name_upper
    project_name_upper=$(echo "${project_name}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

    # Append to .env.projects
    cat >> "${ENV_PROJECTS}" << EOF

# ===== Project: ${project_name} =====
${project_name_upper}_JWT_SECRET=${jwt_secret}
${project_name_upper}_ANON_KEY=${anon_key}
${project_name_upper}_SERVICE_ROLE_KEY=${service_role_key}
EOF

    # Add optional secrets if provided
    if [ -n "${secret_key_base}" ]; then
        echo "${project_name_upper}_SECRET_KEY_BASE=${secret_key_base}" >> "${ENV_PROJECTS}"
    fi
    if [ -n "${pg_meta_crypto_key}" ]; then
        echo "${project_name_upper}_PG_META_CRYPTO_KEY=${pg_meta_crypto_key}" >> "${ENV_PROJECTS}"
    fi
    if [ -n "${vault_enc_key}" ]; then
        echo "${project_name_upper}_VAULT_ENC_KEY=${vault_enc_key}" >> "${ENV_PROJECTS}"
    fi
    if [ -n "${pooler_tenant_id}" ]; then
        echo "${project_name_upper}_POOLER_TENANT_ID=${pooler_tenant_id}" >> "${ENV_PROJECTS}"
    fi

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
