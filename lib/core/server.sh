#!/usr/bin/env bash

# Server preparation functions for Indie Ventures

# Check if we should offer server preparation (Linux = yes, macOS = no)
is_production_server() {
    local os_info
    os_info=$(detect_os)
    local os
    IFS=':' read -r os _ <<< "${os_info}"

    # macOS (Homebrew) is never production
    if [ "${os}" = "macos" ]; then
        return 1
    fi

    # Linux servers should offer setup
    if [ "${os}" = "linux" ]; then
        return 0
    fi

    # Unknown OS - don't offer setup
    return 1
}

# Check if we have sudo/root access
has_privileges() {
    if is_root; then
        return 0
    fi

    # Check if sudo is available (may require password prompt)
    if command_exists sudo; then
        return 0
    fi

    return 1
}

# Get command prefix for privileged operations
get_sudo_prefix() {
    if is_root; then
        echo ""
    elif command_exists sudo; then
        echo "sudo "
    else
        echo ""
    fi
}

# Update system packages
prepare_server_system() {
    if ! has_privileges; then
        error "Root or sudo access required to update system packages"
        return 1
    fi

    local sudo_prefix
    sudo_prefix=$(get_sudo_prefix)

    info "Updating system packages…"
    if ${sudo_prefix}apt-get update -qq && ${sudo_prefix}apt-get upgrade -y -qq; then
        success "System packages updated"
        return 0
    else
        error "Failed to update system packages"
        return 1
    fi
}

# Configure firewall (install UFW if needed, allow ports 22, 80, 443)
prepare_server_firewall() {
    if ! has_privileges; then
        error "Root or sudo access required to configure firewall"
        return 1
    fi

    local sudo_prefix
    sudo_prefix=$(get_sudo_prefix)

    # Check if UFW is installed
    if ! command_exists ufw; then
        info "UFW is not installed. Installing…"
        if ! ${sudo_prefix}apt-get install -y -qq ufw; then
            error "Failed to install UFW"
            return 1
        fi
        success "UFW installed"
    fi

    info "Configuring firewall…"

    # Allow SSH (critical - don't block current connection)
    ${sudo_prefix}ufw allow 22/tcp >/dev/null 2>&1
    success "Allowed port 22 (SSH)"

    # Allow HTTP and HTTPS
    ${sudo_prefix}ufw allow 80/tcp >/dev/null 2>&1
    success "Allowed port 80 (HTTP)"
    ${sudo_prefix}ufw allow 443/tcp >/dev/null 2>&1
    success "Allowed port 443 (HTTPS)"

    # Enable UFW if not already enabled
    if ! ${sudo_prefix}ufw status | grep -q "Status: active"; then
        warning "Enabling UFW firewall. Make sure port 22 is allowed!"
        if echo "y" | ${sudo_prefix}ufw enable >/dev/null 2>&1; then
            success "UFW firewall enabled"
        else
            error "Failed to enable UFW firewall"
            return 1
        fi
    else
        info "UFW firewall is already enabled"
    fi

    return 0
}

# Create non-root user with sudo privileges
prepare_server_user() {
    if ! has_privileges; then
        error "Root or sudo access required to create user"
        return 1
    fi

    local sudo_prefix
    sudo_prefix=$(get_sudo_prefix)

    echo ""
    info "Create a non-root user for better security"
    local username
    username=$(prompt_input "Username" "indie")

    if [ -z "${username}" ]; then
        warning "Username cannot be empty. Skipping user creation."
        return 1
    fi

    # Check if user already exists
    if id "${username}" >/dev/null 2>&1; then
        warning "User '${username}' already exists"
        if confirm "Add to sudo group anyway?" "n"; then
            if ${sudo_prefix}usermod -aG sudo "${username}"; then
                success "Added '${username}' to sudo group"
                return 0
            else
                error "Failed to add '${username}' to sudo group"
                return 1
            fi
        else
            info "Skipping user creation"
            return 0
        fi
    fi

    # Create user
    info "Creating user '${username}'…"
    if ${sudo_prefix}adduser "${username}" --disabled-password --gecos "" --quiet 2>/dev/null; then
        success "Created user '${username}'"
    else
        error "Failed to create user '${username}'"
        return 1
    fi

    # Add to sudo group
    info "Adding '${username}' to sudo group…"
    if ${sudo_prefix}usermod -aG sudo "${username}"; then
        success "Added '${username}' to sudo group"
    else
        error "Failed to add '${username}' to sudo group"
        return 1
    fi

    echo ""
    info "User '${username}' created successfully"
    info "You can now switch to this user with: su - ${username}"

    return 0
}

# Main server preparation function
prepare_server() {
    if ! is_production_server; then
        return 0
    fi

    show_header "Server Preparation"

    echo ""
    info "This will help you set up basic server security and configuration:"
    echo "  • Update system packages"
    echo "  • Configure firewall (UFW) - allow SSH, HTTP, HTTPS"
    echo "  • Create a non-root user with sudo privileges"
    echo ""

    if ! confirm "Would you like to run a basic setup (update system, firewall, non-root user)?" "y"; then
        info "Skipping server preparation"
        return 0
    fi

    if ! has_privileges; then
        warning "Root or sudo access required for server preparation"
        echo ""
        echo "Please run with sudo or as root:"
        echo "  sudo indie init"
        echo ""
        return 1
    fi

    echo ""

    # System update
    if confirm "Update system packages?" "y"; then
        if ! prepare_server_system; then
            warning "System update failed, continuing…"
        fi
        echo ""
    fi

    # Firewall configuration
    if confirm "Configure firewall (allow SSH, HTTP, HTTPS)?" "y"; then
        if ! prepare_server_firewall; then
            warning "Firewall configuration failed, continuing…"
        fi
        echo ""
    fi

    # User creation
    if confirm "Create a non-root user?" "y"; then
        if ! prepare_server_user; then
            warning "User creation failed, continuing…"
        fi
        echo ""
    fi

    success "Server preparation complete!"
    return 0
}

