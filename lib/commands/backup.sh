#!/usr/bin/env bash

# Backup project for migration

# Load dependencies
source "${LIB_DIR}/core/database.sh"
source "${LIB_DIR}/core/secrets.sh"
source "${LIB_DIR}/ui/prompts.sh"

cmd_backup() {
    require_init

    local project_name="${1:-}"

    if [ -z "${project_name}" ]; then
        error "Project name required"
        echo "Usage: indie backup <project-name>"
        exit 1
    fi

    if ! project_exists "${project_name}"; then
        error "Project '${project_name}' not found"
        exit 1
    fi

    show_header "Backup Project '${project_name}'"

    local timestamp
    timestamp=$(date +"%Y%m%d-%H%M%S")
    local backup_dir="${INDIE_DIR}/backups/${project_name}-${timestamp}"
    local backup_archive="${INDIE_DIR}/backups/${project_name}-${timestamp}.tar.gz"

    mkdir -p "${backup_dir}"

    # Dump database
    info "Dumping database…"
    if ! dump_project_database "${project_name}" "${backup_dir}/database.sql"; then
        error "Failed to dump database"
        exit 1
    fi

    # Export secrets
    info "Exporting secrets…"
    local jwt_secret
    jwt_secret=$(get_project_secret "${project_name}" "jwt_secret")
    local anon_key
    anon_key=$(get_project_secret "${project_name}" "anon_key")
    local service_role_key
    service_role_key=$(get_project_secret "${project_name}" "service_role_key")

    cat > "${backup_dir}/.env" << EOF
JWT_SECRET=${jwt_secret}
ANON_KEY=${anon_key}
SERVICE_ROLE_KEY=${service_role_key}
EOF

    # Export project metadata
    info "Exporting metadata…"
    jq --arg name "${project_name}" '.[$name]' "${PROJECTS_FILE}" > "${backup_dir}/project.json"

    # Copy storage files if they exist
    local storage_dir="${INDIE_DIR}/volumes/${project_name}/storage"
    if [ -d "${storage_dir}" ]; then
        info "Copying storage files…"
        cp -r "${storage_dir}" "${backup_dir}/storage"
    fi

    # Create migration guide
    cat > "${backup_dir}/MIGRATION.md" << 'EOF'
# Migration Guide

This archive contains everything needed to migrate your Supabase project to a new server.

## Contents

- `database.sql` - Complete database dump
- `.env` - JWT secrets and API keys
- `project.json` - Project configuration
- `storage/` - Uploaded files (if any)

## Steps to Migrate

1. Set up a new Supabase instance (self-hosted or cloud)
2. Restore the database:
   ```bash
   psql -U postgres -d your_database < database.sql
   ```
3. Configure your new instance with the secrets from `.env`
4. Copy storage files to the new storage backend
5. Update your application connection strings

## Using Official Supabase

If migrating to official Supabase cloud:
1. Create a new project at supabase.com
2. Use the SQL Editor to run database.sql
3. Update your application with new project URL and keys
4. Upload storage files through the dashboard

For help: https://supabase.com/docs
EOF

    # Create archive
    info "Creating archive…"
    tar -czf "${backup_archive}" -C "${INDIE_DIR}/backups" "$(basename "${backup_dir}")"
    rm -rf "${backup_dir}"

    success "Backup created: ${backup_archive}"

    local size
    size=$(du -h "${backup_archive}" | cut -f1)

    show_success_box "Backup Complete!" "Archive: ${backup_archive}
Size: ${size}

This archive contains:
- Database dump
- API keys and secrets
- Storage files
- Migration guide

Use this to migrate your project to a dedicated server
or to official Supabase cloud.
"
}
