#!/usr/bin/env bash

set -euo pipefail

# Indie Ventures - Uninstall Script
# https://github.com/atropical/indie-ventures

INSTALL_DIR="/opt/indie-ventures"
BIN_LINK="/usr/local/bin/indie"
DATA_DIR="/opt/indie-ventures/data"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check if installed
check_installed() {
    if [ ! -d "$INSTALL_DIR" ] && [ ! -L "$BIN_LINK" ]; then
        warn "Indie Ventures does not appear to be installed"
        exit 0
    fi
}

# Remove installation
remove_installation() {
    info "Removing Indie Ventures installation..."
    
    # Remove symlink
    if [ -L "$BIN_LINK" ]; then
        rm -f "$BIN_LINK"
        success "Removed symlink: ${BIN_LINK}"
    fi
    
    # Remove installation directory
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        success "Removed directory: ${INSTALL_DIR}"
    fi
}

# Ask about data removal
ask_remove_data() {
    if [ -d "$DATA_DIR" ]; then
        echo ""
        warn "Project data still exists at: ${DATA_DIR}"
        echo ""
        read -p "Remove ALL project data? This cannot be undone! (y/N) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Removing project data..."
            rm -rf "$DATA_DIR"
            success "Project data removed"
        else
            info "Project data preserved at: ${DATA_DIR}"
        fi
    fi
}

# Show what remains
show_remaining() {
    echo ""
    echo "======================================"
    info "The following were NOT removed:"
    echo "======================================"
    echo ""
    echo "Dependencies (if installed):"
    echo "  - Docker"
    echo "  - Docker Compose"
    echo "  - Nginx"
    echo "  - PostgreSQL containers"
    echo "  - jq"
    echo "  - gum"
    echo ""
    
    if [ -d "$DATA_DIR" ]; then
        echo "Project data:"
        echo "  - ${DATA_DIR}"
        echo ""
    fi
    
    echo "To remove Docker and related containers:"
    echo "  docker system prune -a --volumes"
    echo ""
    echo "To remove Docker completely:"
    echo "  apt-get remove docker-ce docker-ce-cli containerd.io docker-compose-plugin"
    echo ""
}

# Main uninstall
main() {
    echo "========================================="
    echo "  Indie Ventures - Uninstall Script"
    echo "========================================="
    echo ""
    
    check_root
    check_installed
    
    warn "This will remove Indie Ventures from your system"
    echo ""
    read -p "Continue? (y/N) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Uninstall cancelled"
        exit 0
    fi
    
    echo ""
    remove_installation
    ask_remove_data
    show_remaining
    
    echo ""
    success "Indie Ventures has been uninstalled"
    echo ""
}

main

