# Indie Ventures

> Self-hosted Supabase manager for running multiple isolated projects on a single server.

[![License: OSL-3.0](https://img.shields.io/badge/License-OSL%203.0-blue.svg)](https://opensource.org/licenses/OSL-3.0)

**Indie Ventures** is a beautiful CLI tool that makes it easy to manage multiple Supabase projects on a single server. Perfect for indie hackers, agencies, and developers who want to self-host Supabase without the complexity.

## Features

- **Server Agnostic** - Works on any Ubuntu/Debian server (Hetzner, DigitalOcean, AWS, bare metal, etc.)
- **Hybrid Architecture** - Choose shared or isolated services per project
- **Multi-Domain Support** - Each project can have multiple custom domains
- **Automatic SSL/TLS** - Free Let's Encrypt certificates with auto-renewal
- **Beautiful CLI** - Powered by [Gum](https://github.com/charmbracelet/gum) for gorgeous interactive prompts
- **One-Command Setup** - Install via Homebrew, initialize in seconds
- **Easy Migration** - Export projects when they outgrow shared hosting
- **Secure by Default** - Auto-generated JWT secrets, isolated databases, HTTPS ready

## Quick Start

### Installation

Choose the installation method based on your use case:

#### For Production Servers

Use the direct installation script (recommended for security):

```bash
# SSH into your server
ssh root@your-server-ip

# Install indie-ventures
curl -fsSL https://raw.githubusercontent.com/atropical/indie-ventures/main/install.sh | sudo bash

# Initialize
indie init
```

The CLI will guide you through:
- Dependency installation (Docker, etc.)
- Base credential setup
- Service initialization

#### For Local Development

Use Homebrew on your Mac or Linux development machine:

```bash
# Install via Homebrew
brew tap atropical/indie-ventures
brew install indie-ventures

# Initialize
indie init
```

**Security Note:** The direct installation script is recommended for production servers to avoid installing Homebrew as root, which is a security risk. Homebrew is perfect for local development environments.

### Add Your First Project

```bash
indie add
```

Interactive prompts will ask for:
- Project name
- Architecture (shared or isolated)
- Domains

That's it! Your Supabase project is ready.

## System Requirements

**Minimum:**
- Ubuntu 20.04+ or Debian 11+
- 2 CPU cores
- 4GB RAM
- 20GB storage

**Recommended:**
- 4 CPU cores
- 8GB RAM
- 50GB+ SSD

**Works on:**
- Hetzner Cloud
- DigitalOcean
- Linode
- AWS EC2
- Google Cloud
- Azure VMs
- Bare metal servers
- Local development (macOS/Linux)

## Architecture

### Shared Mode (Default)
- **One Supabase service stack** for multiple projects
- Each project gets its own database and JWT secrets
- Lower resource usage
- Perfect for small-medium projects

### Isolated Mode
- **Dedicated services** per project
- Complete isolation between projects
- Higher resource usage
- Recommended for production/important projects

You can mix both on the same server!

## Commands

```bash
indie init              # Initialize server (first time only)
indie add               # Add new project
indie list              # List all projects
indie domains <name>    # Manage project domains
indie ssl enable <name> # Enable SSL/HTTPS (free Let's Encrypt)
indie ssl renew         # Renew all certificates
indie backup <name>     # Export project for migration
indie remove <name>     # Remove project (with backup)
indie status            # Check service health
```

## Documentation

- [Installation Guide](docs/INSTALL.md)
- [Server Setup](docs/SETUP.md)
- [SSL/TLS with Let's Encrypt](docs/SSL.md)
- [Architecture Comparison](docs/ARCHITECTURE.md)
- [Domain Configuration](docs/DOMAINS.md)
- [Migration Guide](docs/MIGRATE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

### Provider-Specific Guides

- [Hetzner](docs/providers/HETZNER.md)
- [DigitalOcean](docs/providers/DIGITALOCEAN.md)
- [Linode](docs/providers/LINODE.md)
- [AWS EC2](docs/providers/AWS.md)
- [Bare Metal](docs/providers/BARE_METAL.md)

## Example Workflow

### Add a blog project (shared mode)
```bash
indie add
> Project name: my-blog
> Architecture: shared
> Domains: blog.mydomain.com api.blog.mydomain.com

✓ Created database 'myblog'
✓ Generated JWT secrets
✓ Configured Nginx
✓ Project ready!

Your API URL: https://blog.mydomain.com
anon key: eyJhbGciOiJ...
```

### Add a production SaaS (isolated mode)
```bash
indie add
> Project name: my-saas
> Architecture: isolated
> Domains: api.mysaas.com

✓ Starting dedicated services...
✓ Project ready at https://api.mysaas.com
```

### List all projects
```bash
indie list

┏━━━━━━━━━━━┳━━━━━━━━━━━━┳━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ Project   ┃ Arch       ┃ Status ┃ Domains                 ┃
┡━━━━━━━━━━━╇━━━━━━━━━━━━╇━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━┩
│ my-blog   │ shared     │ up     │ blog.mydomain.com       │
│ my-saas   │ isolated   │ up     │ api.mysaas.com          │
└───────────┴────────────┴────────┴─────────────────────────┘
```

### Export project for migration
```bash
indie backup my-saas

✓ Dumping database...
✓ Exporting storage files...
✓ Packaging configuration...
✓ Created: backups/my-saas-2025-10-28.tar.gz

This archive contains everything needed to migrate
your project to a dedicated server.
```

## Contributing

Contributions are welcome! Please read our [Contributing Guide](docs/CONTRIBUTING.md) first.

## License

This project is licensed under the [Open Software License 3.0](LICENSE).

## Support

- [GitHub Issues](https://github.com/atropical/indie-ventures/issues)
- [Documentation](docs/)

## Credits

Built with:
- [Supabase](https://supabase.com/) - Open source Firebase alternative
- [Gum](https://github.com/charmbracelet/gum) - Beautiful shell scripts
- [Docker](https://www.docker.com/) - Containerization
- [Nginx](https://nginx.org/) - Reverse proxy

---

Made with ❤️ for indie hackers everywhere.
This project has started as a vibe coding experiment. Use at your own risk and try to not be too judgemental.
