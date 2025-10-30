# Installation Guide

## Requirements

### System Requirements
- **Servers:** Ubuntu 20.04+ or Debian 11+ (production)
- **Development:** macOS 11+ or Linux (local testing)
- 2+ CPU cores
- 4GB+ RAM
- 20GB+ storage

### Software Requirements
The following dependencies are automatically installed:
- Docker
- Docker Compose
- Gum (for beautiful CLI prompts)
- jq (for JSON processing)

## Installation Methods

Choose the appropriate method for your use case:

---

## Production Server Installation (Recommended)

### Direct Installation Script

This is the **recommended and secure** method for production servers. It avoids installing Homebrew as root.

### 1. Install Indie Ventures

SSH into your server and run:

```bash
# Using sudo (recommended)
curl -fsSL https://raw.githubusercontent.com/atropical/indie-ventures/main/install.sh | sudo bash
```

Or with a specific version:

```bash
curl -fsSL https://raw.githubusercontent.com/atropical/indie-ventures/main/install.sh | sudo bash -s v1.0.0
```

The script will:
- Download the latest release from GitHub
- Install to `/opt/indie-ventures`
- Create symlink at `/usr/local/bin/indie`
- Check for dependencies (installs on `indie init`)

### 2. Verify installation

```bash
indie version
```

You should see:
```
Indie Ventures v1.0.0
Self-hosted Supabase Manager
https://github.com/atropical/indie-ventures
```

### 3. Initialize your server

```bash
indie init
```

The CLI will guide you through:
- Choosing data directory (default: `/opt/indie-ventures`)
- Dependency installation (Docker, etc.)
- Docker setup
- Base configuration (PostgreSQL, Dashboard passwords)
- Service initialization

### Updating

To update Indie Ventures to the latest version:

```bash
sudo indie update
```

This will:
- Check for the latest version on GitHub
- Download and install the update
- Preserve all your projects and data
- Maintain your configuration

**Note:** The update command is only for direct installations. If you used `--skip-deps` during installation, dependencies won't be updated.

### Uninstallation

To remove Indie Ventures from your production server:

```bash
curl -fsSL https://raw.githubusercontent.com/atropical/indie-ventures/main/uninstall.sh | sudo bash
```

**What gets removed:**
- Indie Ventures installation from `/opt/indie-ventures`
- CLI symlink from `/usr/local/bin/indie`
- Configuration files (`/etc/indie-ventures.conf` or `~/.indie-ventures.conf`)
- Optionally: project data (you'll be prompted)

**What gets preserved:**
- Docker and Docker Compose
- System dependencies (jq, gum)
- Running containers (unless you choose to remove data)

The uninstall script will prompt you before removing any project data, giving you a chance to back up first.

**To remove everything including Docker:**
```bash
# After running uninstall.sh, remove Docker
sudo apt-get remove docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo docker system prune -a --volumes  # Remove all containers and volumes
```

---

## Local Development Installation

### Installation via Homebrew

For local development and testing on macOS or Linux, use Homebrew.

⚠️ **Note:** Do NOT use this method on production servers as root.

### 1. Install Homebrew (if not already installed)

**On macOS:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**On Linux:**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH (add to ~/.bashrc or ~/.zshrc)
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
source ~/.bashrc
```

### 2. Tap the Indie Ventures repository

```bash
brew tap atropical/indie-ventures
```

### 3. Install Indie Ventures

```bash
brew install indie-ventures
```

This will automatically install all dependencies.

### 4. Verify installation

```bash
indie version
```

### 5. Initialize

For local testing:

```bash
indie init
```

**Note:** On macOS, you'll need Docker Desktop installed and running.

### Updating

```bash
brew upgrade indie-ventures
```

### Uninstallation

```bash
brew uninstall indie-ventures
brew untap atropical/indie-ventures
```

---

## Troubleshooting

### Server Installation Issues

#### Installation script fails

If the direct installation script fails:

1. Check you're running as root/sudo:
   ```bash
   whoami  # Should show 'root' or use sudo
   ```

2. Verify internet connectivity:
   ```bash
   curl -I https://github.com
   ```

3. Check system requirements:
   ```bash
   cat /etc/os-release  # Should be Ubuntu/Debian
   ```

#### Docker not found

The installation checks for Docker but doesn't install it automatically. Run:

```bash
indie init
```

This will detect and install Docker. Or install manually:

**Ubuntu/Debian:**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

#### Permission denied errors

After Docker installation, add your user to the docker group:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

#### Command not found after installation

Ensure `/usr/local/bin` is in your PATH:

```bash
echo $PATH | grep /usr/local/bin
```

If not, add to `~/.bashrc` or `~/.zshrc`:
```bash
export PATH="/usr/local/bin:$PATH"
source ~/.bashrc
```

### Homebrew Installation Issues

#### Gum not available

Gum is optional but recommended. If installation fails, the CLI will work with fallback prompts.

To install manually:
```bash
brew install gum
```

#### Docker Desktop not running (macOS)

Download and install [Docker Desktop](https://www.docker.com/products/docker-desktop), then ensure it's running before using `indie init`.

#### Homebrew permissions

If you encounter permission errors with Homebrew:
```bash
sudo chown -R $(whoami) /usr/local/Homebrew
```

---

## Comparison: Server vs Homebrew

| Feature | Server Installation | Homebrew Installation |
|---------|-------------------|---------------------|
| **Use Case** | Production servers | Local development |
| **Installation** | Direct script | Homebrew |
| **Location** | `/opt/indie-ventures` | `/usr/local/Cellar` |
| **Requires Root** | Yes | No |
| **Security** | ✓ Recommended | ⚠️ Not for servers |
| **Update Method** | `sudo indie update` | `brew upgrade` |
| **Uninstall** | Run uninstall script | `brew uninstall` |

## Next Steps

After installation:
1. [Server Setup](SETUP.md) - Configure your server
2. [Add Your First Project](../README.md#quick-start) - Create a Supabase project
3. [Domain Configuration](DOMAINS.md) - Set up custom domains

## Getting Help

- [Documentation](https://github.com/atropical/indie-ventures/tree/main/docs)
- [GitHub Issues](https://github.com/atropical/indie-ventures/issues)
- [Supabase Docs](https://supabase.com/docs)
