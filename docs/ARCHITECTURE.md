# Architecture Guide

Indie Ventures supports two architecture modes for running Supabase projects. This guide explains the differences and helps you choose the right one.

## Overview

```
┌────────────────────────────────────────────────┐
│                                                │
│  Server (Hetzner, DigitalOcean, AWS, etc.)     │
│                                                │
│  ┌───────────────────────────────────────────┐ │
│  │  Indie Ventures Infrastructure            │ │
│  │                                           │ │
│  │  ┌─────────┐  ┌────────┐  ┌──────────────┐│ │
│  │  │ Nginx   │  │Postgres│  │  Shared or   ││ │
│  │  │ Reverse │  │        │  │  Isolated    ││ │
│  │  │ Proxy   │  │ (All   │  │  Supabase    ││ │
│  │  │         │  │  DBs)  │  │  Services    ││ │
│  │  └─────────┘  └────────┘  └──────────────┘│ │
│  └───────────────────────────────────────────┘ │
│                                                │
└────────────────────────────────────────────────┘
```

## Shared Architecture

### How It Works

- **One set of Supabase services** (Kong, PostgREST, GoTrue, Realtime, Storage, Studio)
- **Multiple databases** in a single PostgreSQL instance
- **JWT-based isolation** - Each project has unique secrets
- **Nginx routes** traffic to the shared services, JWT identifies the project

### When to Use

✅ Good for:
- Small projects
- Development and testing
- Projects with moderate traffic
- Cost efficiency (fewer containers)

⚠️ Not ideal for:
- High-traffic production apps
- Projects requiring guaranteed resources
- Maximum isolation needs

### Resource Usage

Typical resource usage for shared mode with 3 projects:
- Memory: ~2GB
- CPU: 1-2 cores
- Containers: ~10

### Example

```bash
indie add
> Project name: blog
> Architecture: shared
> Domains: blog.mydomain.com

indie add
> Project name: newsletter
> Architecture: shared
> Domains: news.mydomain.com
```

Both projects share the same Supabase services but have separate databases and API keys.

## Isolated Architecture

### How It Works

- **Dedicated Supabase services** for each project
- **Separate containers** (Kong, PostgREST, GoTrue, Storage, etc.)
- **One shared PostgreSQL** instance (still separate databases)
- **Independent scaling** - Each project can scale separately

### When to Use

✅ Good for:
- Production applications
- High-traffic projects
- Projects needing guaranteed resources
- Maximum isolation between projects

⚠️ Consider costs:
- More memory (3-4GB per project)
- More CPU usage
- More containers

### Resource Usage

Typical resource usage for isolated mode per project:
- Memory: ~3-4GB
- CPU: 1-2 cores
- Containers: ~8

### Example

```bash
indie add
> Project name: saas-app
> Architecture: isolated
> Domains: api.mysaas.com

indie add
> Project name: mobile-backend
> Architecture: isolated
> Domains: api.myapp.com
```

Each project has completely independent services.

## Comparison Table

| Feature | Shared | Isolated |
|---------|--------|----------|
| **Resource Usage** | Low | High |
| **Cost** | Lower | Higher |
| **Isolation** | Database-level | Service-level |
| **Scaling** | Limited | Independent |
| **Setup Complexity** | Simple | Simple |
| **Fault Tolerance** | If services crash, all projects affected | Only affected project down |
| **Best For** | Dev, small projects | Production, large projects |

## Mixing Architectures

You can run both architectures on the same server!

```bash
# Shared projects for dev/small apps
indie add --architecture shared blog
indie add --architecture shared newsletter

# Isolated for production
indie add --architecture isolated main-saas-app
```

## Migration Between Architectures

### From Shared to Isolated

```bash
# 1. Backup the project
indie backup my-project

# 2. Remove from shared
indie remove my-project

# 3. Re-add as isolated
indie add
> Name: my-project
> Architecture: isolated

# 4. Restore data
# (Use the backup file to restore database and storage)
```

### From Server to Dedicated Server

```bash
# Export for migration
indie backup my-big-project

# The backup contains:
# - Database dump
# - Storage files
# - JWT secrets
# - Migration guide
```

## Database Isolation

Both architectures use **separate PostgreSQL databases**:

```
PostgreSQL Instance:
├── postgres (system)
├── project1_db
├── project2_db
└── project3_db
```

Each project database is completely isolated with its own:
- Tables and schemas
- Users and permissions
- Extensions
- Data

## Security Considerations

### Shared Mode

- Services shared between projects
- JWT secrets provide API-level isolation
- Database-level isolation
- Good for trusted projects on same server

### Isolated Mode

- Complete service isolation
- Container-level isolation
- Database-level isolation
- Better for multi-tenant or untrusted scenarios

## Performance Characteristics

### Shared Mode

**Advantages:**
- Lower memory overhead
- Faster startup (services already running)
- Better resource utilization

**Considerations:**
- Shared connection pools
- Potential resource contention
- One service restart affects all

### Isolated Mode

**Advantages:**
- Dedicated resources
- No contention
- Independent restarts
- Easier debugging (isolated logs)

**Considerations:**
- Higher memory usage
- More complex management
- More containers to monitor

## Choosing an Architecture

### Start with Shared If:
- You're just starting out
- Running multiple small projects
- Want to minimize costs
- Have limited server resources (< 8GB RAM)

### Use Isolated If:
- Running production applications
- Need guaranteed performance
- Have critical applications
- Can allocate more resources (8GB+ RAM)

### Example Server Configurations

**Small Server (4GB RAM):**
- 3-5 shared projects
- OR 1 isolated project

**Medium Server (8GB RAM):**
- 5-10 shared projects
- OR 2-3 isolated projects
- OR Mix: 1-2 isolated + 3-5 shared

**Large Server (16GB RAM):**
- 10-20 shared projects
- OR 4-6 isolated projects
- OR Mix: 3-4 isolated + 5-10 shared

## Migration Strategy

### Growth Path

```
1. Start → Shared architecture
          ↓
2. Growing → Monitor performance
          ↓
3. If needed → Migrate to isolated
          ↓
4. Outgrown → Migrate to dedicated server
```

## Conclusion

- **Default to shared** for most use cases
- **Choose isolated** for production or critical apps
- **Mix both** for optimal resource usage
- **Easy migration** path when projects grow

Remember: The architecture choice isn't permanent. You can always backup and migrate as your needs evolve!

## Further Reading

- [Setup Guide](SETUP.md)
- [Migration Guide](MIGRATE.md)
- [Supabase Architecture](https://supabase.com/docs/guides/hosting/overview)
