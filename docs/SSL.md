# SSL/TLS with Let's Encrypt

Indie Ventures includes automatic SSL/TLS certificate management using Let's Encrypt. Certificates are obtained, installed, and automatically renewed at no cost.

## Quick Start

Enable SSL for a project in two steps:

```bash
# 1. Ensure DNS is configured
# Point your domain A record to your server's IP

# 2. Enable SSL
indie ssl enable my-project
```

That's it! Your project is now secured with HTTPS.

## Features

- **Automatic Certificate Obtainment** - One command to get SSL certificates
- **Auto-Renewal** - Certificates automatically renew before expiration
- **Multi-Domain Support** - Single project can have multiple SSL-enabled domains
- **Production-Ready** - Modern SSL/TLS configuration with secure ciphers
- **Zero Cost** - Free certificates from Let's Encrypt

## Prerequisites

Before obtaining SSL certificates:

### 1. DNS Configuration

Your domain must point to your server:

```bash
# Add A record in your DNS provider:
Type: A
Name: @ (or blog, api, etc.)
Value: YOUR_SERVER_IP
TTL: 3600
```

Verify DNS is configured:
```bash
ping your-domain.com
# Should show your server's IP
```

### 2. Port 80 Must Be Open

Let's Encrypt verifies domain ownership via HTTP (port 80). Ensure your firewall allows it:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

## Commands

### Enable SSL for Project

```bash
indie ssl enable <project-name>
```

This will:
1. Check DNS configuration
2. Prompt for email (for expiry notifications)
3. Obtain certificates for all project domains
4. Update Nginx configuration
5. Reload Nginx to enable HTTPS

**Example:**
```bash
indie ssl enable my-blog

# Output:
✓ blog.mydomain.com - DNS configured
✓ api.blog.mydomain.com - DNS configured

Email for Let's Encrypt notifications: admin@mydomain.com

⠿ Obtaining certificate for blog.mydomain.com…
✓ Certificate obtained

⠿ Obtaining certificate for api.blog.mydomain.com…
✓ Certificate obtained

✓ SSL enabled for my-blog

Your project is now accessible via HTTPS!
```

### List All Certificates

```bash
indie ssl list
```

Shows all obtained certificates with expiry dates.

### Check Certificate Status

```bash
indie ssl status <project-name>
```

Shows certificate details for a specific project:
- Expiry date
- Days remaining
- All secured domains

### Renew Certificates

```bash
indie ssl renew
```

Manually trigger certificate renewal. This is typically not needed as certificates auto-renew, but useful for testing.

### Remove SSL

```bash
indie ssl remove <project-name>
```

Removes SSL certificates and reverts to HTTP-only.

### Setup Auto-Renewal

```bash
indie ssl setup-auto-renewal
```

Configures automatic renewal (already set up by `indie init`). Certificates are checked twice daily and renewed when < 30 days remain.

### Test SSL Configuration

```bash
indie ssl test <domain>
```

Tests SSL connection and displays certificate information.

## Automatic Renewal

Indie Ventures automatically renews certificates using two methods:

### 1. Certbot Container (Primary)

The Certbot Docker container runs continuously and checks for renewal twice daily:

- **Schedule**: Every 12 hours
- **Threshold**: Renews when < 30 days remaining
- **Process**: Automatic, no intervention needed

### 2. Cron Job (Backup)

A cron job provides redundancy:

```bash
# Runs twice daily (midnight and noon)
0 0,12 * * * /opt/indie-ventures/scripts/renew-certs.sh
```

### Renewal Logs

View renewal logs:

```bash
# Certbot logs
cat /opt/indie-ventures/volumes/logs/certbot-renewal.log

# Docker logs
docker logs indie-certbot
```

## SSL Configuration

Indie Ventures uses modern, secure SSL configuration:

```nginx
# TLS Protocols
ssl_protocols TLSv1.2 TLSv1.3;

# Cipher Suites
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;

# HSTS
Strict-Transport-Security "max-age=31536000; includeSubDomains"
```

This configuration scores **A+** on SSL Labs.

## During Project Creation

When creating a project with `indie add`, you'll be prompted to enable SSL:

```bash
indie add

# After project creation:
Would you like to enable SSL/HTTPS now?
This will obtain free Let's Encrypt certificates for your domains.

Enable SSL now? [y/N] y

Make sure your DNS A records point to this server before continuing!

DNS configured and ready to obtain certificates? [y/N] y

Email for Let's Encrypt notifications: admin@mydomain.com

✓ SSL enabled!
Your project is now secured with HTTPS!
```

## Multiple Domains

Projects can have multiple SSL-secured domains:

```bash
# During project creation
Domains: blog.mydomain.com api.blog.mydomain.com www.blog.mydomain.com

# SSL will be obtained for all domains
indie ssl enable my-project

✓ Certificate obtained for blog.mydomain.com
✓ Certificate obtained for api.blog.mydomain.com
✓ Certificate obtained for www.blog.mydomain.com
```

## Troubleshooting

### Certificate Obtainment Fails

**Problem:** `Failed to obtain certificate`

**Solutions:**

1. **Check DNS**
   ```bash
   nslookup your-domain.com
   # Should return your server's IP
   ```

2. **Check Port 80**
   ```bash
   sudo netstat -tlnp | grep :80
   # Should show nginx listening
   ```

3. **Check Nginx**
   ```bash
   indie status
   # Ensure nginx is running
   ```

4. **Check Certbot Logs**
   ```bash
   docker logs indie-certbot
   ```

5. **Verify Domain Accessibility**
   ```bash
   curl -I http://your-domain.com
   # Should return HTTP 200
   ```

### Rate Limits

Let's Encrypt has rate limits:
- **50 certificates per domain per week**
- **5 duplicate certificates per week**

If you hit rate limits, wait a week or use staging mode for testing.

### Mixed Content Warnings

After enabling SSL, ensure your application uses HTTPS for all resources:

```javascript
// ❌ Bad - Mixed content
const apiUrl = "http://api.mydomain.com";

// ✅ Good - All HTTPS
const apiUrl = "https://api.mydomain.com";
```

### Certificate Not Trusted

If browsers show "Not Trusted" warnings:

1. Wait a few minutes after setup
2. Clear browser cache
3. Check certificate chain:
   ```bash
   openssl s_client -connect your-domain.com:443 -showcerts
   ```

## Manual Certificate Management

While Indie Ventures handles everything automatically, you can also:

### View Certificate Files

```bash
# Certificate location
/opt/indie-ventures/volumes/certbot/conf/live/<domain>/

# Files:
fullchain.pem    # Full certificate chain
privkey.pem      # Private key
cert.pem         # Certificate
chain.pem        # Intermediate certificates
```

### Test Renewal

```bash
# Dry run (doesn't actually renew)
docker exec indie-certbot certbot renew --dry-run
```

### Force Renewal

```bash
# Force renewal even if not due
indie ssl renew
```

## Security Best Practices

### 1. Keep Email Updated

Let's Encrypt sends expiry notifications to your email. Keep it current:

```bash
# Use a monitored email address
indie ssl enable my-project
> Email: admin@mydomain.com  # ✅ Good - monitored
> Email: temp@example.com     # ❌ Bad - not monitored
```

### 2. Monitor Certificate Expiry

Check certificate status regularly:

```bash
indie ssl status my-project
```

### 3. Test After Setup

Always test SSL after enabling:

```bash
indie ssl test your-domain.com
```

### 4. Use HTTPS Everywhere

Update your application to use HTTPS URLs:
- API endpoints
- Asset URLs
- Webhook URLs

### 5. Enable HSTS

HSTS is automatically enabled in Nginx configuration, forcing HTTPS.

## Cost

**SSL certificates are completely free** with Let's Encrypt!

- No setup cost
- No renewal cost
- No hidden fees
- Unlimited certificates

## Let's Encrypt Limits

Be aware of Let's Encrypt rate limits:

| Limit | Value |
|-------|-------|
| Certificates per domain/week | 50 |
| Duplicate certificates/week | 5 |
| Subdomains per certificate | 100 |
| Renewals | Not rate limited |

For most indie projects, these limits are more than sufficient.

## Alternative: Custom Certificates

If you have custom SSL certificates, you can use them instead:

```bash
# Copy certificates
cp your-cert.pem /opt/indie-ventures/volumes/certbot/conf/live/your-domain.com/fullchain.pem
cp your-key.pem /opt/indie-ventures/volumes/certbot/conf/live/your-domain.com/privkey.pem

# Reload Nginx
docker exec indie-nginx nginx -s reload
```

## Next Steps

- [Domain Configuration](DOMAINS.md)
- [Architecture Guide](ARCHITECTURE.md)
- [Migration Guide](MIGRATE.md)

## Getting Help

- [GitHub Issues](https://github.com/atropical/indie-ventures/issues)
- [Let's Encrypt Community](https://community.letsencrypt.org/)
