#!/usr/bin/env bash

# Dependency checking and installation for Indie Ventures

# Detect OS and distribution
detect_os() {
    local os=""
    local distro=""
    local version=""

    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        os="linux"
        distro="${ID}"
        version="${VERSION_ID}"
    elif [ "$(uname)" = "Darwin" ]; then
        os="macos"
        distro="macos"
        version="$(sw_vers -productVersion)"
    else
        os="unknown"
    fi

    echo "${os}:${distro}:${version}"
}

# Get package manager
get_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists yum; then
        echo "yum"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists brew; then
        echo "brew"
    else
        echo "unknown"
    fi
}

# Check if Docker is installed
check_docker() {
    if command_exists docker; then
        return 0
    else
        return 1
    fi
}

# Check if Docker Compose is installed
check_docker_compose() {
    if command_exists docker && docker compose version >/dev/null 2>&1; then
        return 0
    elif command_exists docker-compose; then
        return 0
    else
        return 1
    fi
}

# Check if Gum is installed
check_gum() {
    command_exists gum
}

# Check if jq is installed
check_jq() {
    command_exists jq
}

# Install Docker (server mode only)
install_docker() {
    local pm
    pm=$(get_package_manager)

    info "Installing Docker..."

    case "${pm}" in
        apt)
            if ! is_root; then
                error "Root access required to install Docker"
                return 1
            fi

            # Install prerequisites
            apt-get update -qq
            apt-get install -y -qq ca-certificates curl gnupg lsb-release

            # Add Docker's official GPG key
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg

            # Add repository
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
              $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

            # Install Docker
            apt-get update -qq
            apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

            # Start and enable Docker
            systemctl start docker
            systemctl enable docker

            success "Docker installed successfully"
            return 0
            ;;
        brew)
            warning "Please install Docker Desktop for Mac from: https://www.docker.com/products/docker-desktop"
            return 1
            ;;
        *)
            error "Unsupported package manager: ${pm}"
            error "Please install Docker manually: https://docs.docker.com/engine/install/"
            return 1
            ;;
    esac
}

# Install Gum
install_gum() {
    local pm
    pm=$(get_package_manager)

    info "Installing Gum..."

    case "${pm}" in
        brew)
            brew install gum
            return $?
            ;;
        apt)
            # Install via Go binary or add Charm repository
            if ! is_root && ! command_exists sudo; then
                error "Root access or sudo required to install Gum"
                return 1
            fi

            local cmd_prefix=""
            if ! is_root; then
                cmd_prefix="sudo"
            fi

            # Add Charm repository
            $cmd_prefix mkdir -p /etc/apt/keyrings
            curl -fsSL https://repo.charm.sh/apt/gpg.key | $cmd_prefix gpg --dearmor -o /etc/apt/keyrings/charm.gpg
            echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | $cmd_prefix tee /etc/apt/sources.list.d/charm.list
            $cmd_prefix apt-get update -qq
            $cmd_prefix apt-get install -y -qq gum

            success "Gum installed successfully"
            return 0
            ;;
        *)
            # Try to install via Go
            if command_exists go; then
                go install github.com/charmbracelet/gum@latest
                return $?
            else
                error "Cannot install Gum automatically"
                error "Please install manually: https://github.com/charmbracelet/gum#installation"
                return 1
            fi
            ;;
    esac
}

# Install jq
install_jq() {
    local pm
    pm=$(get_package_manager)

    info "Installing jq..."

    case "${pm}" in
        apt)
            local cmd_prefix=""
            if ! is_root; then
                cmd_prefix="sudo"
            fi
            $cmd_prefix apt-get install -y -qq jq
            ;;
        yum|dnf)
            local cmd_prefix=""
            if ! is_root; then
                cmd_prefix="sudo"
            fi
            $cmd_prefix "${pm}" install -y -q jq
            ;;
        brew)
            brew install jq
            ;;
        *)
            error "Cannot install jq automatically"
            return 1
            ;;
    esac

    success "jq installed successfully"
    return 0
}

# Check all dependencies
check_dependencies() {
    local missing=()

    if ! check_docker; then
        missing+=("docker")
    fi

    if ! check_docker_compose; then
        missing+=("docker-compose")
    fi

    if ! check_gum; then
        missing+=("gum")
    fi

    if ! check_jq; then
        missing+=("jq")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Install missing dependencies (interactive)
install_missing_dependencies() {
    local auto_install="${1:-false}"

    info "Checking dependencies..."

    local missing=()

    if ! check_docker; then
        missing+=("docker")
    fi

    if ! check_docker_compose && check_docker; then
        # Docker Compose is part of Docker now, so skip if Docker is being installed
        if ! [[ " ${missing[*]} " =~ " docker " ]]; then
            warning "Docker Compose not found, but Docker is installed"
            warning "Consider upgrading to Docker with Compose plugin"
        fi
    fi

    if ! check_gum; then
        missing+=("gum")
    fi

    if ! check_jq; then
        missing+=("jq")
    fi

    if [ ${#missing[@]} -eq 0 ]; then
        success "All dependencies are installed"
        return 0
    fi

    warning "Missing dependencies: ${missing[*]}"

    if [ "${auto_install}" != "true" ]; then
        if ! confirm "Install missing dependencies?"; then
            error "Cannot continue without dependencies"
            return 1
        fi
    fi

    # Install each missing dependency
    for dep in "${missing[@]}"; do
        case "${dep}" in
            docker)
                if ! install_docker; then
                    error "Failed to install Docker"
                    return 1
                fi
                ;;
            gum)
                if ! install_gum; then
                    warning "Failed to install Gum (optional, but recommended)"
                fi
                ;;
            jq)
                if ! install_jq; then
                    error "Failed to install jq"
                    return 1
                fi
                ;;
        esac
    done

    success "Dependencies installed"
    return 0
}

# Show system information
show_system_info() {
    local os_info
    os_info=$(detect_os)
    local os distro version
    IFS=':' read -r os distro version <<< "${os_info}"

    local pm
    pm=$(get_package_manager)

    echo "System Information:"
    echo "  OS: ${os}"
    echo "  Distribution: ${distro} ${version}"
    echo "  Package Manager: ${pm}"
    echo ""
    echo "Dependencies:"

    if check_docker; then
        local docker_version
        docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
        echo "  ✓ Docker: ${docker_version}"
    else
        echo "  ✗ Docker: not installed"
    fi

    if check_docker_compose; then
        local compose_cmd
        compose_cmd=$(get_docker_compose_cmd)
        local compose_version
        compose_version=$(${compose_cmd} version --short 2>/dev/null || echo "unknown")
        echo "  ✓ Docker Compose: ${compose_version}"
    else
        echo "  ✗ Docker Compose: not installed"
    fi

    if check_gum; then
        local gum_version
        gum_version=$(gum --version 2>/dev/null | head -n1 || echo "unknown")
        echo "  ✓ Gum: ${gum_version}"
    else
        echo "  ✗ Gum: not installed"
    fi

    if check_jq; then
        local jq_version
        jq_version=$(jq --version 2>/dev/null || echo "unknown")
        echo "  ✓ jq: ${jq_version}"
    else
        echo "  ✗ jq: not installed"
    fi
}
