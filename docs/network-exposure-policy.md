# Network Exposure Policy

## Overview

This homelab follows a minimal-exposure network model.

The objective is to expose only the services that require Internet access while keeping administrative interfaces, databases and infrastructure services restricted to trusted networks.

All addresses in this document are sanitized examples.

## Network Zones

```text
Internet
   |
   | Public services only
   v
Firewall
   |
   +---- Reverse Proxy
   |
   +---- WireGuard VPN
   |
   v
LAN / VPN
   |
   +---- Administrative interfaces
   +---- SSH
   +---- Internal applications
   |
   v
Docker internal networks
   |
   +---- Databases
   +---- Redis
   +---- Application backends
```

Example trusted networks:

```text
LAN: 192.168.10.0/24
VPN: 10.10.0.0/24
```

## Firewall Strategy

The host firewall uses a default-deny approach for unsolicited incoming traffic.

Conceptually:

```text
Incoming: deny by default
Outgoing: allow by default
Forwarded/routed traffic: deny unless explicitly required
```

Public exposure is intentionally limited.

## Internet-Facing Ports

Only services that require direct Internet connectivity should be reachable from outside the trusted network.

Example policy:

| Port | Protocol | Purpose | Exposure |
|---|---|---|---|
| 80 | TCP | HTTP / reverse proxy | Internet |
| 443 | TCP | HTTPS / reverse proxy | Internet |
| 51820 | UDP | WireGuard VPN | Internet |

Application services are not normally exposed directly when they can be accessed through the reverse proxy.

## Reverse Proxy

Public web applications are published through a reverse proxy instead of exposing each container port directly.

Conceptually:

```text
Internet
   |
   | 80 / 443
   v
Reverse Proxy
   |
   +---- Application A
   +---- Application B
   +---- Application C
```

This provides a single controlled entry point for HTTP/HTTPS services.

Backend services remain on trusted or Docker-internal networks whenever possible.

## VPN Access

WireGuard provides remote access to services that should not be publicly exposed.

Typical examples include:

- SSH
- Administrative web interfaces
- Infrastructure dashboards
- Internal applications
- Maintenance services

Conceptually:

```text
Remote administrator
        |
        | WireGuard
        v
   Trusted VPN
        |
        +---- SSH
        +---- Admin interfaces
        +---- Internal services
```

## SSH Policy

SSH is not intended to be globally accessible from the Internet.

Access is restricted to trusted network ranges such as:

```text
LAN
VPN
```

This reduces unnecessary exposure of the SSH daemon.

## Administrative Interfaces

Management interfaces should remain accessible only from trusted networks.

Examples include:

- Reverse proxy administration
- Container administration
- Infrastructure dashboards
- Storage management
- Application administration interfaces

These services should not require direct Internet exposure.

## Databases and Redis

Databases and caching services should remain internal whenever external access is unnecessary.

Examples:

```text
MariaDB
PostgreSQL
Redis
```

Preferred model:

```text
Application container
       |
       v
Docker network
       |
       +---- Database
       +---- Redis
```

They should not be bound to public host interfaces unless there is a specific requirement.

## Container Port Publishing

Docker port publishing is reviewed before deployment.

A published port such as:

```yaml
ports:
  - "8080:80"
```

makes a service reachable through the host network depending on firewall and bind configuration.

For internal dependencies, Docker networks are preferred:

```yaml
services:
  application:
    networks:
      - backend

  database:
    networks:
      - backend

networks:
  backend:
```

No host port is required for communication between containers on the same Docker network.

## Verification

Firewall state:

```bash
sudo ufw status verbose
```

Listening sockets:

```bash
sudo ss -tulpn
```

Docker published ports:

```bash
docker ps \
  --format 'table {{.Names}}\t{{.Ports}}'
```

Active WireGuard interfaces:

```bash
sudo wg show
```

Docker networks:

```bash
docker network ls
```

These checks help compare the intended exposure policy with the actual running configuration.

## Exposure Review

A useful review workflow is:

```text
1. List listening host ports
2. List Docker published ports
3. Compare them with firewall rules
4. Identify the service behind each port
5. Decide whether Internet access is necessary
6. Restrict unnecessary exposure to LAN/VPN/internal networks
7. Verify connectivity after the change
```

Every open port should have a known purpose.

## Security Principles

The network policy follows several simple principles:

- Expose only what is necessary
- Prefer one controlled reverse-proxy entry point
- Use VPN access for private administration
- Restrict SSH to trusted networks
- Keep databases and caches internal
- Avoid unnecessary Docker host-port publishing
- Apply default-deny firewall rules
- Verify the real listening state instead of relying only on configuration files

## Sanitization

The real infrastructure contains private addressing and environment-specific configuration.

Public documentation uses example networks such as:

```text
192.168.10.0/24
10.10.0.0/24
```

The following are intentionally excluded:

- Real public addresses
- Real internal addressing
- Public domain names
- Credentials
- API tokens
- VPN keys
- Private keys
- Application secrets

## Conclusion

The homelab network is designed around controlled exposure rather than making every application directly reachable.

The general model is:

```text
Public service
    -> reverse proxy

Private service
    -> LAN or VPN

Backend dependency
    -> internal container network
```

This keeps the attack surface smaller while maintaining practical remote access and self-hosted services.
