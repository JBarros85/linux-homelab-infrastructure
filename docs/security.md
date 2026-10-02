# Security Architecture

## Overview

Security is a central part of this homelab.

The environment follows a layered approach designed to reduce unnecessary exposure, restrict administrative access and isolate internal services.

The real infrastructure configuration is not published directly. All examples in this repository are sanitized.

## Security Principles

The main security principles used in this environment are:

- Default-deny firewall policy
- Minimum necessary network exposure
- VPN-based remote administration
- Restricted SSH access
- Container network isolation
- Internal databases
- Separation of secrets from configuration
- Service authentication
- Regular updates
- Monitoring and logging
- Removal of unused services

## Firewall

The host uses UFW.

The default firewall policy is based on:

```text
Incoming traffic: DENY
Outgoing traffic: ALLOW
Routed traffic: DENY unless explicitly permitted
```

Only required services receive explicit rules.

Administrative ports are not exposed directly to the public Internet.

## SSH

SSH access is restricted to trusted private networks.

Allowed sources include:

- Local network
- WireGuard VPN networks

Direct SSH access from the Internet is blocked.

This allows remote administration without publishing the SSH service publicly.

## WireGuard VPN

WireGuard is used as the primary remote access solution.

The VPN provides encrypted access to internal services.

Instead of exposing multiple administrative services to the Internet, remote users connect through WireGuard first.

Simplified access model:

```text
Remote Client
     |
     v
Encrypted WireGuard Tunnel
     |
     v
Private Network
     |
     +---- SSH
     +---- Internal Web Services
     +---- Remote Administration
```

## Reverse Proxy

Nginx Proxy Manager handles selected public HTTP and HTTPS traffic.

The reverse proxy provides a controlled entry point for services that require external access.

Its administrative interface is restricted to the private network.

Public access and administrative access are therefore separated.

## Docker Port Exposure

Docker services were reviewed to reduce unnecessary host port exposure.

Services are divided into different access levels.

### Public

Only services explicitly intended for public access are reachable through the reverse proxy.

### LAN / VPN

Applications intended for trusted users are bound to private interfaces.

Examples include:

- Nextcloud
- Immich
- Jellyfin direct access
- Nginx Proxy Manager administration

### Localhost

Some internal services are bound only to localhost when they do not require direct network access.

### Docker Internal Networks

Supporting services such as databases and cache systems communicate through Docker networks without publishing their ports publicly.

Examples include:

- MariaDB
- PostgreSQL
- Redis

## Secret Management

Passwords and other secrets are not stored directly inside published Docker Compose files.

Sensitive values are stored separately using environment files or other private configuration files.

Example:

```yaml
services:
  database:
    env_file:
      - ./secrets/database.env
```

The secret file itself is excluded from Git.

Example `.gitignore` rules:

```gitignore
.env
.env.*
secrets/
*.key
*.pem
```

Example files intended for publication must contain placeholder values only.

## Database Security

Database services are kept inside Docker networks whenever possible.

They are not directly exposed to the public network.

Administrative database accounts are restricted to the required scope.

Credentials used by applications are separate from administrative credentials.

## Nextcloud and ONLYOFFICE

JWT authentication is enabled between Nextcloud and ONLYOFFICE.

This ensures that document service requests are authenticated using a shared secret.

The JWT secret is stored outside the public configuration.

## Fail2Ban

Fail2Ban is enabled on the host.

It monitors supported services and can temporarily block sources that repeatedly fail authentication.

Fail2Ban complements the firewall but does not replace it.

## System Updates

The operating system uses automated security update mechanisms.

Regular package updates reduce exposure to known vulnerabilities.

Before major infrastructure changes, service health and compatibility are verified.

## Disk and Infrastructure Monitoring

The server uses monitoring mechanisms including:

- SMART disk monitoring
- Linux MD RAID monitoring
- Docker health checks
- System logs

Monitoring helps identify failures before they become larger availability or data-loss incidents.

## Removal of Unused Services

Unused services increase attack surface and resource consumption.

During the infrastructure review, unnecessary services were identified and disabled or removed.

Examples included:

- Legacy OpenVPN service
- Unused multipath services
- Redundant host Redis service
- Duplicate printing service installation
- Obsolete firewall rules

Services required for active workloads are kept enabled.

## Network Segmentation

The environment separates different traffic types using:

- Physical LAN
- WireGuard VPN
- Docker bridge networks
- Localhost bindings
- Firewall rules

This reduces unnecessary communication between unrelated services.

## Access Philosophy

The preferred access model is:

```text
Public Internet
      |
      +---- HTTPS Reverse Proxy
      |
      +---- WireGuard VPN
                 |
                 v
          Private Services
```

Administrative services remain behind the VPN or local network whenever possible.

## Git Repository Security

The Git repository contains documentation and sanitized examples only.

The following must never be committed:

- Passwords
- Private SSH keys
- WireGuard private keys
- API tokens
- Personal access tokens
- Database passwords
- JWT secrets
- Real `.env` files
- TLS private keys
- Backup encryption keys
- Personal application data

Before publishing configuration examples, files must be reviewed and sanitized.

## Security Review Workflow

Before publishing infrastructure changes:

1. Review exposed ports.
2. Review firewall rules.
3. Check Docker port bindings.
4. Check for hardcoded secrets.
5. Validate service authentication.
6. Remove obsolete configuration.
7. Test service health.
8. Sanitize documentation.
9. Review Git changes before committing.
10. Push only reviewed files.

## Security Disclaimer

This repository documents a personal lab environment created for learning and experimentation.

The configurations shown here are examples and should be reviewed before being applied to another environment.
