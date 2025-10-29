# Server Setup Guide

This guide covers setting up Indie Ventures on any Ubuntu/Debian server.

## Quick Start

```bash
# 1. SSH into your server
ssh root@your-server-ip

# 2. Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
source ~/.bashrc

# 3. Install Indie Ventures
brew tap atropical/indie-ventures
brew install indie-ventures

# 4. Initialize
indie init
```

## Detailed Setup

### 1. Server Preparation

#### 1.1 Update System

```bash
sudo apt update
sudo apt upgrade -y
```

#### 1.2 Configure Firewall

Allow HTTP, HTTPS, and SSH:

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

#### 1.3 Create Non-Root User (Recommended)

```bash
adduser indie
usermod -aG sudo indie
su - indie
```

### 2. Install Indie Ventures

Follow the [Installation Guide](INSTALL.md) to install via Homebrew.

### 3. Initialize Indie Ventures

```bash
indie init
```

You'll be prompted for:

**Data Directory:**
- Where to store Indie Ventures data and projects
- Default: `/opt/indie-ventures` (recommended for production)
- You can specify a custom path (e.g., `/home/indie/data` or `./local-test`)
- This contains Docker volumes, project configurations, and backups

**PostgreSQL Password:**
- This is the master password for the PostgreSQL superuser
- Choose a strong password and save it securely
- All project databases will be created in this PostgreSQL instance

**Studio Dashboard Password:**
- Password for accessing the Supabase Studio web interface
- Used to manage your projects visually

### 4. Verify Services

Check that services are running:

```bash
indie status
```

You should see:
- postgres (running)
- nginx (running)

### 5. Access Studio Dashboard

**Locally (on the server):**
```
http://localhost:3000
```

**Remotely:**
```
http://your-server-ip:3000
```

Login with the dashboard password you set during init.

## Adding Your First Project

```bash
indie add
```

You'll be prompted for:
- **Project name**: e.g., `my-blog`
- **Architecture**: Choose `shared` (recommended for most projects)
- **Domains**: e.g., `blog.yourdomain.com`

## DNS Configuration

After creating a project, configure your domain DNS:

1. Go to your domain registrar's DNS settings
2. Add an A record:
   ```
   Type: A
   Name: blog (or @ for root domain)
   Value: your-server-ip
   TTL: 3600
   ```

Wait for DNS propagation (up to 24 hours, usually < 1 hour).

Test with:
```bash
ping blog.yourdomain.com
```

## SSL/TLS Configuration (Optional but Recommended)

### Using Certbot (Let's Encrypt)

```bash
# Install Certbot
sudo apt install certbot

# Get certificate
sudo certbot certonly --standalone -d blog.yourdomain.com

# Update Nginx config to use SSL
# Edit /opt/indie-ventures/nginx/sites/your-project.conf
# Uncomment the SSL server block and update paths
```

## Security Best Practices

### 1. Use Strong Passwords

Generate strong passwords for:
- PostgreSQL superuser
- Studio dashboard
- Each project's JWT secrets (auto-generated)

### 2. Firewall Configuration

Only expose necessary ports:
- 22 (SSH)
- 80 (HTTP)
- 443 (HTTPS)

Block direct access to:
- 5432 (PostgreSQL)
- 3000 (Studio Dashboard) - use SSH tunnel instead

### 3. SSH Key Authentication

Disable password authentication:

```bash
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no
sudo systemctl restart sshd
```

### 4. Regular Updates

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Update Indie Ventures
brew upgrade indie-ventures

# Update Docker images
cd /opt/indie-ventures
docker-compose pull
docker-compose up -d
```

### 5. Backups

Regular backups are crucial:

```bash
# Backup specific project
indie backup my-project

# Backup all projects
for project in $(indie list --names-only); do
    indie backup $project
done
```

## Monitoring

### Check Service Status

```bash
indie status
```

### View Docker Logs

```bash
cd /opt/indie-ventures
docker-compose logs -f postgres
docker-compose logs -f nginx
```

### Monitor Resources

```bash
# CPU and Memory
htop

# Disk space
df -h

# Docker stats
docker stats
```

## Troubleshooting

### Services won't start

```bash
# Check Docker
docker info

# Check logs
cd /opt/indie-ventures
docker-compose logs

# Restart services
indie init
```

### Can't access Studio Dashboard

```bash
# Check if port 3000 is open
sudo ufw status

# Use SSH tunnel instead
ssh -L 3000:localhost:3000 root@your-server-ip
# Then access http://localhost:3000
```

### Database connection errors

```bash
# Check PostgreSQL logs
docker logs indie-postgres

# Verify password in .env.base
cat /opt/indie-ventures/.env.base
```

## Provider-Specific Guides

- [Hetzner](providers/HETZNER.md)
- [DigitalOcean](providers/DIGITALOCEAN.md)
- [AWS EC2](providers/AWS.md)
- [Linode](providers/LINODE.md)
- [Bare Metal](providers/BARE_METAL.md)

## Next Steps

1. [Configure Domains](DOMAINS.md)
2. [Understanding Architectures](ARCHITECTURE.md)
3. [Migration Guide](MIGRATE.md)

## Getting Help

- [GitHub Issues](https://github.com/atropical/indie-ventures/issues)
- [Supabase Community](https://supabase.com/community)
