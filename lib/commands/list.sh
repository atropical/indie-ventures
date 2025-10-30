#!/usr/bin/env bash

# List all Supabase projects

# Load dependencies
source "${LIB_DIR}/ui/tables.sh"

cmd_list() {
    require_init

    # Get all projects
    local projects=()
    while IFS= read -r project; do
        projects+=("${project}")
    done < <(list_projects)

    if [ ${#projects[@]} -eq 0 ]; then
        info "No projects found"
        echo ""
        echo "Create your first project: indie add"
        exit 0
    fi

    echo ""
    show_projects_table "${projects[@]}"
    echo ""

    info "Total projects: ${#projects[@]}"
    echo ""
    echo "Commands:"
    echo "  indie add              - Add new project"
    echo "  indie domains <name>   - Manage project domains"
    echo "  indie backup <name>    - Export project for migration"
    echo "  indie remove <name>    - Remove project"
    echo "  indie status           - Check service health"
}
