#!/usr/bin/env bash

# Update Indie Ventures CLI

REPO="atropical/indie-ventures"
INSTALL_DIR="/opt/indie-ventures"

# Detect if this is a Homebrew installation
is_homebrew_install() {
    # Check if INDIE_LIB_DIR env var is set (Homebrew sets this)
    if [ -n "${INDIE_LIB_DIR:-}" ]; then
        return 0
    fi
    
    # Check if the binary path contains Cellar or homebrew
    local binary_path
    if [ -L "$0" ]; then
        binary_path="$(readlink "$0" 2>/dev/null || echo "$0")"
    else
        binary_path="$0"
    fi
    
    # Use realpath if available, otherwise use readlink -f
    if command_exists realpath; then
        binary_path="$(realpath "$binary_path" 2>/dev/null || echo "$binary_path")"
    elif command_exists readlink; then
        binary_path="$(readlink -f "$binary_path" 2>/dev/null || echo "$binary_path")"
    fi
    
    if [[ "$binary_path" =~ (Cellar|homebrew|Homebrew) ]]; then
        return 0
    fi
    
    return 1
}

# Get latest version from GitHub
get_latest_version() {
    local latest
    # Try to get the latest non-prerelease first
    latest=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    # If that fails (404 or no stable releases), get the most recent release including prereleases
    if [ -z "$latest" ]; then
        latest=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases" 2>/dev/null | grep '"tag_name"' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
    fi
    
    if [ -z "$latest" ]; then
        return 1
    fi
    
    echo "$latest"
}

# Compare versions (returns 0 if v1 < v2, 1 if v1 >= v2)
version_lt() {
    local v1="$1"
    local v2="$2"
    
    # Remove 'v' prefix if present
    v1="${v1#v}"
    v2="${v2#v}"
    
    # Simple lexicographic comparison
    if [ "$v1" = "$v2" ]; then
        return 1
    fi
    
    # Use sort -V for version comparison
    local older
    older=$(printf '%s\n%s\n' "$v1" "$v2" | sort -V | head -n1)
    
    [ "$older" = "$v1" ]
}

# Update the installation
perform_update() {
    local version="$1"
    local download_url="https://github.com/${REPO}/archive/${version}.tar.gz"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    info "Downloading Indie Ventures ${version}…"
    
    if ! curl -fsSL "$download_url" -o "${temp_dir}/indie-ventures.tar.gz"; then
        error "Failed to download from ${download_url}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    info "Extracting update…"
    
    # Extract to temp directory
    tar -xzf "${temp_dir}/indie-ventures.tar.gz" -C "$temp_dir"
    
    # Find the extracted directory
    local extracted_dir
    extracted_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "indie-ventures-*" | head -n 1)
    
    if [ -z "$extracted_dir" ]; then
        error "Failed to find extracted directory"
        rm -rf "$temp_dir"
        return 1
    fi
    
    info "Installing update to ${INSTALL_DIR}…"
    
    # Backup current installation (just in case)
    if [ -d "${INSTALL_DIR}.backup" ]; then
        rm -rf "${INSTALL_DIR}.backup"
    fi
    
    # Copy contents to install directory
    cp -r "${extracted_dir}"/* "$INSTALL_DIR/"
    
    # Set executable permissions
    chmod +x "${INSTALL_DIR}/bin/indie"
    find "${INSTALL_DIR}/lib" -type f -name "*.sh" -exec chmod +x {} \;
    
    # Clean up
    rm -rf "$temp_dir"
    
    success "Update installed successfully"
    return 0
}

cmd_update() {
    show_header "Indie Ventures Update"
    
    # Check if this is a Homebrew installation
    if is_homebrew_install; then
        echo ""
        warning "This appears to be a Homebrew installation"
        echo ""
        echo "To update via Homebrew, use:"
        echo "  ${GREEN}brew upgrade indie-ventures${NC}"
        echo ""
        echo "Do not use 'indie update' for Homebrew installations."
        exit 0
    fi
    
    # Check for root/sudo permissions
    if ! is_root; then
        error "Update requires root privileges"
        echo ""
        echo "Please run with sudo:"
        echo "  sudo indie update"
        exit 1
    fi
    
    # Check if installation directory exists
    if [ ! -d "$INSTALL_DIR" ]; then
        error "Installation directory not found: ${INSTALL_DIR}"
        echo ""
        echo "This command only works for direct installations."
        echo "If you used a different installation method, please update accordingly."
        exit 1
    fi
    
    # Get current version
    local current_version="${VERSION}"
    info "Current version: ${current_version}"
    
    # Fetch latest version
    info "Checking for updates…"
    local latest_version
    latest_version=$(get_latest_version)
    
    if [ -z "$latest_version" ]; then
        error "Failed to fetch latest version from GitHub"
        echo ""
        echo "Please check your internet connection and try again."
        exit 1
    fi
    
    info "Latest version: ${latest_version}"
    echo ""
    
    # Compare versions
    if ! version_lt "$current_version" "$latest_version"; then
        success "You are already running the latest version (${current_version})"
        exit 0
    fi
    
    # Ask for confirmation
    echo "Update available: ${current_version} → ${latest_version}"
    echo ""
    if ! confirm "Update to ${latest_version}?"; then
        info "Update cancelled"
        exit 0
    fi
    
    echo ""
    
    # Perform update
    if perform_update "$latest_version"; then
        echo ""
        show_success_box "Update Complete!" "Indie Ventures has been updated to ${latest_version}

Your projects and data are preserved.
No further action is needed.

To verify: indie version"
        success "Update complete!"
    else
        error "Update failed"
        exit 1
    fi
}

