#!/usr/bin/env bash

# Core utility functions for Indie Ventures

# Colors for output (if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    NC=''
fi

# Load configuration if it exists
if [ -f "/etc/indie-ventures.conf" ]; then
    # shellcheck source=/dev/null
    source "/etc/indie-ventures.conf"
elif [ -f "${HOME}/.indie-ventures.conf" ]; then
    # shellcheck source=/dev/null
    source "${HOME}/.indie-ventures.conf"
fi

# Project data directory
INDIE_DIR="${INDIE_DIR:-/opt/indie-ventures}"
PROJECTS_FILE="${INDIE_DIR}/projects/registry.json"
ENV_BASE="${INDIE_DIR}/.env.base"
ENV_PROJECTS="${INDIE_DIR}/.env.projects"

# Logging functions
info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

error() {
    echo -e "${RED}✗${NC} $*" >&2
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root
is_root() {
    [ "$(id -u)" -eq 0 ]
}

# Check if directory is initialized
is_initialized() {
    [ -d "${INDIE_DIR}" ] && [ -f "${PROJECTS_FILE}" ]
}

# Ensure directory is initialized
require_init() {
    if ! is_initialized; then
        error "Indie Ventures is not initialized."
        echo ""
        echo "Please run: indie init"
        exit 1
    fi
}

# Check if project exists
project_exists() {
    local project_name="$1"

    if ! is_initialized; then
        return 1
    fi

    if ! command_exists jq; then
        error "jq is not installed"
        return 1
    fi

    local exists
    exists=$(jq -r "has(\"${project_name}\")" "${PROJECTS_FILE}" 2>/dev/null || echo "false")

    [ "${exists}" = "true" ]
}

# Get project property
get_project_property() {
    local project_name="$1"
    local property="$2"

    if ! project_exists "${project_name}"; then
        return 1
    fi

    jq -r ".\"${project_name}\".${property}" "${PROJECTS_FILE}" 2>/dev/null
}

# List all projects
list_projects() {
    if ! is_initialized; then
        return 1
    fi

    jq -r 'keys[]' "${PROJECTS_FILE}" 2>/dev/null
}

# Generate random string
generate_random() {
    local length="${1:-32}"
    openssl rand -base64 "${length}" | tr -d "=+/" | cut -c1-"${length}"
}

# Slugify string (convert to safe identifier)
slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//;s/-$//'
}

# Validate project name
validate_project_name() {
    local name="$1"

    # Must not be empty
    if [ -z "${name}" ]; then
        error "Project name cannot be empty"
        return 1
    fi

    # Must contain only alphanumeric, dash, underscore
    if ! [[ "${name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Project name can only contain letters, numbers, dashes, and underscores"
        return 1
    fi

    # Must not start with number or dash
    if [[ "${name}" =~ ^[0-9-] ]]; then
        error "Project name cannot start with a number or dash"
        return 1
    fi

    # Must not be a reserved name
    local reserved=("postgres" "nginx" "docker" "api" "studio" "kong" "gotrue" "realtime" "storage" "meta" "analytics")
    for r in "${reserved[@]}"; do
        if [ "${name}" = "${r}" ]; then
            error "Project name '${name}' is reserved"
            return 1
        fi
    done

    return 0
}

# Validate domain
validate_domain() {
    local domain="$1"

    # Basic domain validation regex
    if ! [[ "${domain}" =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        error "Invalid domain: ${domain}"
        return 1
    fi

    return 0
}

# Confirm action
confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if command_exists gum; then
        gum confirm "${prompt}" && return 0 || return 1
    else
        # Fallback to simple prompt
        local yn
        if [ "${default}" = "y" ]; then
            read -rp "${prompt} [Y/n] " yn
            yn="${yn:-y}"
        else
            read -rp "${prompt} [y/N] " yn
            yn="${yn:-n}"
        fi

        case "${yn}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Show spinner with message
spinner() {
    local pid=$1
    local message="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % ${#spin} ))
        printf "\r${CYAN}%s${NC} %s" "${spin:$i:1}" "${message}"
        sleep 0.1
    done

    printf "\r"
}

# Get Docker Compose command (handles both docker-compose and docker compose)
get_docker_compose_cmd() {
    if command_exists docker && docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif command_exists docker-compose; then
        echo "docker-compose"
    else
        return 1
    fi
}

# Run command in indie directory
in_indie_dir() {
    ( cd "${INDIE_DIR}" && "$@" )
}
