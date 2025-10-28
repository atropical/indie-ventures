# Installation Guide

## Requirements

### System Requirements
- Ubuntu 20.04+ or Debian 11+ (for servers)
- macOS 11+ (for local development)
- 2+ CPU cores
- 4GB+ RAM
- 20GB+ storage

### Software Requirements
All dependencies are automatically installed via Homebrew:
- Docker
- Docker Compose
- Gum (for beautiful CLI)
- jq (for JSON processing)

## Installation via Homebrew

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

You should see:
```
Indie Ventures v1.0.0
Self-hosted Supabase Manager
https://github.com/atropical/indie-ventures
```

## Post-Installation

### On a Server

SSH into your server and initialize:

```bash
ssh root@your-server-ip
indie init
```

The CLI will guide you through:
- Dependency installation
- Docker setup
- Base configuration
- Service initialization

### Local Development

For local testing:

```bash
indie init
```

Note: On macOS, you'll need Docker Desktop installed and running.

## Troubleshooting

### Docker not found

If you see "Docker not found", install it manually:

**Ubuntu/Debian:**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

**macOS:**
Download and install [Docker Desktop](https://www.docker.com/products/docker-desktop)

### Permission denied

If you encounter permission errors:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Gum not available

Gum is optional but recommended. If installation fails, the CLI will work with fallback prompts.

To install manually:
```bash
brew install gum
```

## Next Steps

After installation:
1. [Server Setup](SETUP.md) - Configure your server
2. [Add Your First Project](../README.md#quick-start) - Create a Supabase project
3. [Domain Configuration](DOMAINS.md) - Set up custom domains

## Uninstallation

To remove Indie Ventures:

```bash
brew uninstall indie-ventures
brew untap atropical/indie-ventures
```

Note: This will not remove Docker or other dependencies, nor will it remove your project data in `/opt/indie-ventures/`.

To completely remove all data:
```bash
sudo rm -rf /opt/indie-ventures
```

## Getting Help

- [Documentation](https://github.com/atropical/indie-ventures/tree/main/docs)
- [GitHub Issues](https://github.com/atropical/indie-ventures/issues)
- [Supabase Docs](https://supabase.com/docs)
