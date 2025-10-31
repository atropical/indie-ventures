#!/usr/bin/env bash

# Database operations for Indie Ventures

# Wait for PostgreSQL to be ready
wait_for_postgres() {
    local max_attempts=30
    local attempt=1
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)

    # First check if container exists and is running
    local container_status
    container_status=$(in_indie_dir ${compose_cmd} ps postgres --format json 2>/dev/null | jq -r '.[0].State' 2>/dev/null || echo "missing")

    if [ "${container_status}" != "running" ]; then
        error "PostgreSQL container is not running (status: ${container_status})"
        error "Please ensure services are started with: indie status"
        return 1
    fi

    while [ ${attempt} -le ${max_attempts} ]; do
        if in_indie_dir ${compose_cmd} exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done

    error "PostgreSQL is not ready after ${max_attempts} seconds"
    return 1
}

# Execute SQL in PostgreSQL container
pg_exec() {
    local sql="$1"
    local dbname="${2:-postgres}"

    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)

    # Wait for postgres to be ready
    if ! wait_for_postgres; then
        return 1
    fi

    # Execute and capture both stdout and stderr
    local output
    local exit_code

    output=$(in_indie_dir ${compose_cmd} exec -T postgres psql -U postgres -d "${dbname}" -c "${sql}" 2>&1)
    exit_code=$?

    if [ ${exit_code} -ne 0 ]; then
        echo "${output}" >&2
        return ${exit_code}
    fi

    # Check for PostgreSQL errors in output
    if echo "${output}" | grep -qi "error\|fatal"; then
        echo "${output}" >&2
        return 1
    fi

    echo "${output}"
    return 0
}

# Check if database exists
database_exists() {
    local dbname="$1"

    local result
    result=$(pg_exec "SELECT 1 FROM pg_database WHERE datname='${dbname}'" "postgres" 2>/dev/null | grep -c "(1 row)" || echo "0")

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
