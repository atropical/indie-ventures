# Contributing to Indie Ventures

Thank you for your interest in contributing to Indie Ventures! This document provides guidelines for contributing to the project.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/indie-ventures.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test your changes
6. Commit with clear messages
7. Push to your fork
8. Open a Pull Request

## Development Setup

### Prerequisites
- Bash 4.0+
- Docker
- Gum (optional, for testing UI)
- jq

### Local Testing

```bash
# Make the CLI executable
chmod +x bin/indie

# Test commands locally
./bin/indie version
./bin/indie help
```

## Code Style

### Shell Scripts

- Use `#!/usr/bin/env bash` shebang
- Enable strict mode: `set -euo pipefail`
- Use 4 spaces for indentation
- Add comments for complex logic
- Use meaningful variable names
- Quote variables: `"${variable}"`

### Functions

- Use descriptive names: `create_project_database` not `create_db`
- Add comments explaining purpose
- Return 0 for success, 1 for failure
- Use local variables inside functions

### Example

```bash
#!/usr/bin/env bash

# Create a new project database
# Arguments:
#   $1 - project name
# Returns:
#   0 on success, 1 on failure
create_project_database() {
    local project_name="$1"
    local dbname
    dbname=$(slugify "${project_name}")

    info "Creating database: ${dbname}"

    if database_exists "${dbname}"; then
        warning "Database already exists"
        return 0
    fi

    if ! pg_exec "CREATE DATABASE ${dbname};"; then
        error "Failed to create database"
        return 1
    fi

    success "Database created"
    return 0
}
```

## Project Structure

```
indie-ventures/
├── bin/indie                 # Main CLI entry point
├── lib/
│   ├── commands/            # Command implementations
│   ├── core/                # Core functionality
│   └── ui/                  # UI components
├── templates/               # Docker Compose templates
├── docs/                    # Documentation
└── formula/                 # Homebrew formula
```

## Testing

### Manual Testing

Test commands in order:
1. `indie init` - Initialize on test server
2. `indie add` - Add test project
3. `indie list` - Verify project appears
4. `indie status` - Check services
5. `indie backup` - Test backup
6. `indie remove` - Clean up

### Testing on Multiple Platforms

Test on:
- Ubuntu 20.04
- Ubuntu 22.04
- Debian 11
- macOS (local development)

## Documentation

- Update relevant docs in `docs/` directory
- Update README.md if adding features
- Add examples for new commands
- Keep docs clear and concise

## Pull Request Guidelines

### Before Submitting

- Test your changes thoroughly
- Update documentation
- Follow code style guidelines
- Write clear commit messages

### PR Description

Include:
- What the PR does
- Why the change is needed
- How to test it
- Screenshots (for UI changes)

### Example PR

```markdown
## Description
Adds support for PostgreSQL 16

## Motivation
Support latest PostgreSQL version with improved performance

## Changes
- Updated postgres image to 16.1
- Updated database initialization scripts
- Added migration notes to docs

## Testing
- Tested on Ubuntu 22.04
- Verified backward compatibility
- Tested database creation and migrations

## Checklist
- [x] Code follows project style
- [x] Documentation updated
- [x] Tested locally
- [x] PR description is clear
```

## Feature Requests

Open an issue with:
- Clear description of the feature
- Use case / why it's needed
- Proposed implementation (optional)
- Examples

## Bug Reports

Open an issue with:
- Clear title
- Steps to reproduce
- Expected behavior
- Actual behavior
- Environment (OS, versions)
- Error messages / logs

## Community Guidelines

- Be respectful and constructive
- Help others learn
- Give credit where due
- Follow the code of conduct

## Questions?

- Open a GitHub Discussion
- Check existing issues
- Read the documentation

## License

By contributing, you agree that your contributions will be licensed under the OSL-3.0 License.

## Thank You!

Your contributions make Indie Ventures better for everyone. Thank you for taking the time to contribute!
