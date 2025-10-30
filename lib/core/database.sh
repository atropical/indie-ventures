#!/usr/bin/env bash

# Database operations for Indie Ventures

# Execute SQL in PostgreSQL container
pg_exec() {
    local sql="$1"
    local dbname="${2:-postgres}"

    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)

    in_indie_dir ${compose_cmd} exec -T postgres psql -U postgres -d "${dbname}" -c "${sql}"
}

# Check if database exists
database_exists() {
    local dbname="$1"

    local result
    result=$(pg_exec "SELECT 1 FROM pg_database WHERE datname='${dbname}'" "postgres" 2>/dev/null | grep -c "(1 row)")

    [ "${result}" -eq 1 ]
}

# Create database for project
create_project_database() {
    local project_name="$1"
    local dbname
    dbname=$(slugify "${project_name}")

    if database_exists "${dbname}"; then
        warning "Database ${dbname} already exists"
        return 0
    fi

    info "Creating database: ${dbname}"

    if ! pg_exec "CREATE DATABASE ${dbname};" "postgres"; then
        error "Failed to create database ${dbname}"
        return 1
    fi

    # Initialize with Supabase schema
    info "Initializing Supabase schema…"

    # Enable required extensions
    pg_exec "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;" "${dbname}" || true
    pg_exec "CREATE EXTENSION IF NOT EXISTS pgcrypto;" "${dbname}" || true
    pg_exec "CREATE EXTENSION IF NOT EXISTS pgjwt;" "${dbname}" || true

    success "Database ${dbname} created"
    return 0
}

# Drop database
drop_project_database() {
    local project_name="$1"
    local dbname
    dbname=$(slugify "${project_name}")

    if ! database_exists "${dbname}"; then
        warning "Database ${dbname} does not exist"
        return 0
    fi

    info "Dropping database: ${dbname}"

    # Terminate connections to the database
    pg_exec "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${dbname}';" "postgres" || true

    if ! pg_exec "DROP DATABASE ${dbname};" "postgres"; then
        error "Failed to drop database ${dbname}"
        return 1
    fi

    success "Database ${dbname} dropped"
    return 0
}

# Dump database to file
dump_project_database() {
    local project_name="$1"
    local output_file="$2"
    local dbname
    dbname=$(slugify "${project_name}")

    if ! database_exists "${dbname}"; then
        error "Database ${dbname} does not exist"
        return 1
    fi

    info "Dumping database: ${dbname}"

    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)

    in_indie_dir ${compose_cmd} exec -T postgres pg_dump -U postgres -d "${dbname}" > "${output_file}"

    if [ $? -eq 0 ]; then
        success "Database dumped to ${output_file}"
        return 0
    else
        error "Failed to dump database"
        return 1
    fi
}

# Restore database from file
restore_project_database() {
    local project_name="$1"
    local input_file="$2"
    local dbname
    dbname=$(slugify "${project_name}")

    if ! [ -f "${input_file}" ]; then
        error "Dump file not found: ${input_file}"
        return 1
    fi

    info "Restoring database: ${dbname}"

    # Create database if it doesn't exist
    if ! database_exists "${dbname}"; then
        create_project_database "${project_name}"
    fi

    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)

    in_indie_dir ${compose_cmd} exec -T postgres psql -U postgres -d "${dbname}" < "${input_file}"

    if [ $? -eq 0 ]; then
        success "Database restored from ${input_file}"
        return 0
    else
        error "Failed to restore database"
        return 1
    fi
}

# List all databases (exclude system databases)
list_project_databases() {
    pg_exec "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres', 'template0', 'template1');" "postgres" 2>/dev/null | tail -n +3 | head -n -2 | tr -d ' '
}

# Get database size
get_database_size() {
    local dbname="$1"

    pg_exec "SELECT pg_size_pretty(pg_database_size('${dbname}'));" "postgres" 2>/dev/null | tail -n +3 | head -n -2 | tr -d ' '
}
