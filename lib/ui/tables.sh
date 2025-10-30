#!/usr/bin/env bash

# Table formatting for Indie Ventures

# Show projects table
show_projects_table() {
    local projects=("$@")

    if [ ${#projects[@]} -eq 0 ]; then
        info "No projects found"
        return 0
    fi

    if command_exists gum; then
        # Build table data
        local table_data="Project,Architecture,Status,Domains\n"

        for project in "${projects[@]}"; do
            local arch
            arch=$(get_project_property "${project}" "architecture")

            local domains
            domains=$(get_project_property "${project}" "domains" | jq -r 'join(", ")' 2>/dev/null || echo "")

            # Check if services are running
            local status="unknown"
            if [ "${arch}" = "shared" ]; then
                # For shared, check if shared services are running
                if docker ps --format '{{.Names}}' | grep -q "indie-kong"; then
                    status="up"
                else
                    status="down"
                fi
            else
                # For isolated, check project-specific services
                if docker ps --format '{{.Names}}' | grep -q "indie-${project}-kong"; then
                    status="up"
                else
                    status="down"
                fi
            fi

            table_data+="${project},${arch},${status},${domains}\n"
        done

        # Use gum table
        echo -e "${table_data}" | gum table --border rounded --border-foreground 12
    else
        # Fallback to simple formatting
        printf "%-20s %-12s %-8s %-40s\n" "PROJECT" "ARCHITECTURE" "STATUS" "DOMAINS"
        printf "%-20s %-12s %-8s %-40s\n" "─────────────────" "────────────" "──────" "────────────────────────────────────"

        for project in "${projects[@]}"; do
            local arch
            arch=$(get_project_property "${project}" "architecture")

            local domains
            domains=$(get_project_property "${project}" "domains" | jq -r 'join(", ")' 2>/dev/null || echo "")

            # Check status
            local status="unknown"
            if [ "${arch}" = "shared" ]; then
                if docker ps --format '{{.Names}}' | grep -q "indie-kong" 2>/dev/null; then
                    status="up"
                else
                    status="down"
                fi
            else
                if docker ps --format '{{.Names}}' | grep -q "indie-${project}-kong" 2>/dev/null; then
                    status="up"
                else
                    status="down"
                fi
            fi

            printf "%-20s %-12s %-8s %-40s\n" "${project}" "${arch}" "${status}" "${domains}"
        done
    fi
}

# Show simple key-value table
# Usage: show_kv_table "key1:value1" "key2:value2" ...
show_kv_table() {
    if command_exists gum; then
        local table_data="Key,Value\n"

        for item in "$@"; do
            local key="${item%%:*}"
            local value="${item#*:}"
            table_data+="${key},${value}\n"
        done

        echo -e "${table_data}" | gum table --border rounded --border-foreground 10
    else
        for item in "$@"; do
            local key="${item%%:*}"
            local value="${item#*:}"
            printf "%-30s: %s\n" "${key}" "${value}"
        done
    fi
}
