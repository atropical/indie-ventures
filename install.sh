#!/usr/bin/env bash

set -euo pipefail

# Indie Ventures - Server Installation Script
# https://github.com/atropical/indie-ventures

# Parse arguments
INDIE_VERSION="latest"
SKIP_DEPS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        *)
            INDIE_VERSION="$1"
            shift
            ;;
    esac
done

INSTALL_DIR="/opt/indie-ventures"
BIN_LINK="/usr/local/bin/indie"
REPO="atropical/indie-ventures"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root or with sudo"
        echo ""
        echo "Please run: curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | sudo bash"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [ ! -f /etc/os-release ]; then
        error "Cannot detect OS. Only Linux systems are supported for direct installation."
        echo "For macOS, use Homebrew: brew install indie-ventures"
        exit 1
    fi

    . /etc/os-release
    
    case "$ID" in
        ubuntu|debian)
            info "Detected: $PRETTY_NAME"
            ;;
        centos|rhel|fedora)
            info "Detected: $PRETTY_NAME"
            ;;
        *)
            warn "OS not officially supported: $PRETTY_NAME"
            warn "Installation will continue, but issues may occur"
            ;;
    esac
}

# Get latest version from GitHub
get_latest_version() {
    info "Fetching latest version…"
    
    local latest
    # Try to get the latest non-prerelease first
    latest=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    # If that fails (404 or no stable releases), get the most recent release including prereleases
    if [ -z "$latest" ]; then
        warn "No stable release found, checking for prereleases…"
        latest=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases" 2>/dev/null | grep '"tag_name"' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
    fi
    
    if [ -z "$latest" ]; then
        error "Failed to fetch latest version from GitHub"
        error "Please specify a version explicitly (e.g. v0.1.0-alpha):"
        echo "  curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | sudo bash -s <version>"
        exit 1
    fi
    
    echo "$latest"
}

# Validate that a specific version exists
validate_version() {
    local version="$1"
    
    info "Validating version ${version}…"
    
    # Check if the tag exists
    local status_code
    status_code=$(curl -fsSL -o /dev/null -w "%{http_code}" "https://api.github.com/repos/${REPO}/git/refs/tags/${version}")
    
    if [ "$status_code" != "200" ]; then
        error "Version ${version} not found in repository"
        echo ""
        echo "Available versions: https://github.com/${REPO}/releases"
        echo ""
        echo "Try using 'latest' to install the most recent version:"
        echo "  curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | sudo bash"
        exit 1
    fi
}

# Download and extract release
download_and_extract() {
    local version="$1"
    local download_url="https://github.com/${REPO}/archive/${version}.tar.gz"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    info "Downloading Indie Ventures ${version}…"
    
    if ! curl -fsSL "$download_url" -o "${temp_dir}/indie-ventures.tar.gz"; then
        error "Failed to download from ${download_url}"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    info "Extracting to ${INSTALL_DIR}…"
    
    # Create install directory
    mkdir -p "$INSTALL_DIR"
    
    # Extract (strip first directory component)
    tar -xzf "${temp_dir}/indie-ventures.tar.gz" -C "$temp_dir"
    
    # Find the extracted directory
    local extracted_dir
    extracted_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "indie-ventures-*" | head -n 1)
    
    if [ -z "$extracted_dir" ]; then
        error "Failed to find extracted directory"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Move contents to install directory
    cp -r "${extracted_dir}"/* "$INSTALL_DIR/"
    
    # Set executable permissions
    chmod +x "${INSTALL_DIR}/bin/indie"
    find "${INSTALL_DIR}/lib" -type f -name "*.sh" -exec chmod +x {} \;
    
    # Clean up
    rm -rf "$temp_dir"
    
    success "Installed to ${INSTALL_DIR}"
}

# Create symlink
create_symlink() {
    info "Creating symlink…"
    
    # Remove existing symlink if it exists
    if [ -L "$BIN_LINK" ]; then
        rm -f "$BIN_LINK"
    elif [ -e "$BIN_LINK" ]; then
        error "${BIN_LINK} exists and is not a symlink"
        error "Please remove it manually before continuing"
        exit 1
    fi
    
    ln -s "${INSTALL_DIR}/bin/indie" "$BIN_LINK"
    
    success "Created symlink: ${BIN_LINK} -> ${INSTALL_DIR}/bin/indie"
}

# Check dependencies
check_dependencies() {
    info "Checking dependencies…"
    
    local missing=()
    
    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if ! command -v gum &> /dev/null; then
        missing+=("gum")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "${missing[@]}"
        return 1
    else
        return 0
    fi
}

# Install dependencies
install_dependencies() {
    info "Installing dependencies…"
    
    local missing
    missing=$(check_dependencies) || true
    
    if [ -z "$missing" ]; then
        success "All dependencies are already installed"
        return 0
    fi
    
    warn "Missing dependencies: ${missing}"
    echo ""
    
    # Detect package manager
    local pm=""
    if command -v apt-get &> /dev/null; then
        pm="apt"
    elif command -v yum &> /dev/null; then
        pm="yum"
    elif command -v dnf &> /dev/null; then
        pm="dnf"
    else
        error "Unsupported package manager"
        echo "Please install dependencies manually:"
        echo "  - Docker: https://docs.docker.com/engine/install/"
        echo "  - jq: your package manager"
        echo "  - gum: https://github.com/charmbracelet/gum#installation"
        return 1
    fi
    
    # Install jq
    if [[ "$missing" =~ "jq" ]]; then
        info "Installing jq…"
        case "$pm" in
            apt)
                apt-get update -qq
                apt-get install -y -qq jq
                ;;
            yum|dnf)
                $pm install -y -q jq
                ;;
        esac
        success "jq installed"
    fi
    
    # Install gum
    if [[ "$missing" =~ "gum" ]]; then
        info "Installing gum…"
        case "$pm" in
            apt)
                # Add Charm repository
                mkdir -p /etc/apt/keyrings
                curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg
                echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | tee /etc/apt/sources.list.d/charm.list > /dev/null
                apt-get update -qq
                apt-get install -y -qq gum
                ;;
            yum|dnf)
                # Install from binary
                local gum_version="v0.14.0"
                local arch="amd64"
                if [[ "$(uname -m)" == "aarch64" ]]; then
                    arch="arm64"
                fi
                curl -fsSL "https://github.com/charmbracelet/gum/releases/download/${gum_version}/gum_${gum_version#v}_Linux_${arch}.tar.gz" -o /tmp/gum.tar.gz
                tar -xzf /tmp/gum.tar.gz -C /tmp
                mv /tmp/gum /usr/local/bin/
                chmod +x /usr/local/bin/gum
                rm -f /tmp/gum.tar.gz
                ;;
        esac
        success "gum installed"
    fi
    
    # Install Docker
    if [[ "$missing" =~ "docker" ]]; then
        info "Installing Docker…"
        case "$pm" in
            apt)
                # Install prerequisites
                apt-get update -qq
                apt-get install -y -qq ca-certificates curl gnupg lsb-release
                
                # Add Docker's official GPG key
                install -m 0755 -d /etc/apt/keyrings
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                chmod a+r /etc/apt/keyrings/docker.gpg
                
                # Detect distribution for Docker repo
                . /etc/os-release
                local distro="ubuntu"
                if [ "$ID" = "debian" ]; then
                    distro="debian"
                fi
                
                # Add repository
                echo \
                  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${distro} \
                  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                
                # Install Docker
                apt-get update -qq
                apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
                
                # Start and enable Docker
                systemctl start docker
                systemctl enable docker
                ;;
            yum|dnf)
                # Install Docker using convenience script
                curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
                sh /tmp/get-docker.sh
                rm -f /tmp/get-docker.sh
                systemctl start docker
                systemctl enable docker
                ;;
        esac
        success "Docker installed"
    fi
    
    success "All dependencies installed successfully"
    return 0
}

# Main installation
main() {
    echo "======================================"
    echo "  Indie Ventures - Server Installer"
    echo "======================================"
    echo ""
    
    check_root
    detect_os

    # Determine version to install
    local install_version="$INDIE_VERSION"
    if [ "$install_version" = "latest" ]; then
        install_version=$(get_latest_version)
    else
        # Validate user-specified version exists
        validate_version "$install_version"
    fi
    
    info "Installing version: ${install_version}"
    echo ""
    
    # Check if already installed
    if [ -d "$INSTALL_DIR" ]; then
        warn "Indie Ventures is already installed at ${INSTALL_DIR}"
        read -p "Overwrite? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Installation cancelled"
            exit 0
        fi
        info "Removing old installation…"
        rm -rf "$INSTALL_DIR"
    fi
    
    # Install
    download_and_extract "$install_version"
    create_symlink
    
    # Install dependencies unless --skip-deps was specified
    echo ""
    if [ "$SKIP_DEPS" = true ]; then
        info "Skipping dependency installation (--skip-deps)"
        local missing
        missing=$(check_dependencies) || missing="$missing"
        if [ -n "$missing" ]; then
            warn "Missing dependencies: ${missing}"
            echo "These can be installed later with: indie init"
        fi
    else
        if ! install_dependencies; then
            warn "Some dependencies failed to install"
            echo "You can try installing them manually or run: indie init"
        fi
    fi
    
    echo ""
    echo "======================================"
    success "Installation complete!"
    echo "======================================"
    echo ""
    echo "Installed version: ${install_version}"
    echo ""
    echo "Next steps:"
    echo "  1. Initialize your server:"
    echo "     indie init"
    echo ""
    echo "  2. Add your first project:"
    echo "     indie add"
    echo ""
    echo "  3. List projects:"
    echo "     indie list"
    echo ""
    echo "Options:"
    echo "  --skip-deps    Skip automatic dependency installation"
    echo ""
    echo "To install a specific version:"
    echo "  curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | sudo bash -s v0.1.0-alpha"
    echo ""
    echo "To skip dependency installation:"
    echo "  curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | sudo bash -s latest --skip-deps"
    echo ""
    echo "Documentation: https://github.com/${REPO}"
    echo ""
}

main

