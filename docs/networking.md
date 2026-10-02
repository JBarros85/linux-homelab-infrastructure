# Networking

## Overview

This document describes the networking architecture used in the homelab.

The real environment uses private addressing, internal routes and infrastructure details that are intentionally not published.

All IP addresses and network ranges shown in this repository are sanitized examples.

## Network Layers

The homelab uses several network layers:

- Physical local network
- WireGuard VPN
- Docker bridge networks
- Localhost-only services
- Reverse proxy access

Each layer has a specific purpose and different access requirements.

## Local Network

The server is connected to a private local network.

Example network:

```text
192.168.10.0/24
```

The LAN is used by trusted devices such as:

- Workstations
- Laptops
- Mobile devices
- Smart home devices
- Network printers
- The homelab server

Administrative interfaces are preferably accessible only from trusted networks.

## WireGuard VPN

WireGuard is used for secure remote access.

Example VPN network:

```text
10.10.0.0/24
```

Remote clients establish an encrypted VPN tunnel before accessing private services.

Simplified communication flow:

```text
Remote Device
     |
     v
Internet
     |
     v
WireGuard VPN
     |
     v
Private LAN
     |
     +---- SSH
     +---- Nextcloud
     +---- Immich
     +---- Home Assistant
     +---- Jellyfin
     +---- Administration
```

This reduces the number of services that need to be exposed directly to the Internet.

## SSH Access

SSH is restricted to trusted networks.

Allowed access includes:

- Local LAN
- WireGuard VPN

Direct SSH access from the public Internet is blocked by the firewall.

## Reverse Proxy

Nginx Proxy Manager acts as the main HTTP and HTTPS reverse proxy.

Simplified flow:

```text
Internet
   |
   v
Router
   |
   v
Nginx Proxy Manager
   |
   v
Selected Internal Service
```

The reverse proxy provides a controlled entry point for services that require external access.

Its administrative interface remains restricted to the private network.

## Public Services

Only intentionally published services are reachable from the Internet.

The primary public entry points are:

- HTTP
- HTTPS
- WireGuard VPN

Internal administrative services are not intentionally published.

## Docker Networking

Docker applications communicate using private Docker bridge networks.

Example:

```text
Application Container
        |
        v
Docker Bridge Network
        |
        +---- Database
        +---- Redis
        +---- Supporting Service
```

Services such as databases generally do not publish ports to the host.

They communicate internally using Docker DNS and container network names.

Example:

```text
Nextcloud
    |
    +---- MariaDB
    |
    +---- Redis
```

Instead of connecting to a public IP address, the application can communicate with services by Docker service name.

## Port Binding Strategy

Docker ports are published according to the required access level.

### Public

Services intended to receive Internet traffic may bind to public interfaces.

Examples:

```text
80/tcp
443/tcp
```

### Local Network

Services intended only for trusted devices are bound to the server's LAN interface.

Examples include:

- Nextcloud
- Immich
- Jellyfin direct access
- ONLYOFFICE
- Nginx Proxy Manager administration
- Frigate interfaces

### Localhost

Services that only need to communicate with applications on the host are bound to:

```text
127.0.0.1
```

This prevents other devices on the network from connecting directly.

### Docker Internal Networks

Databases, caches and supporting services remain inside Docker networks whenever possible.

Examples:

- MariaDB
- PostgreSQL
- Redis

## Firewall Architecture

UFW provides host-level firewall protection.

The general policy is:

```text
Incoming: DENY
Outgoing: ALLOW
Routed: DENY unless explicitly allowed
```

Specific rules are added only when required.

## Access Model

| Service | Intended Access |
|---|---|
| HTTP / HTTPS reverse proxy | Internet |
| WireGuard | Internet |
| SSH | LAN / VPN |
| Nextcloud | LAN / VPN |
| Immich | LAN / VPN |
| Jellyfin direct access | LAN / VPN |
| Home Assistant | LAN / VPN |
| Frigate | LAN / VPN |
| Nginx Proxy Manager admin | LAN |
| MariaDB | Docker network |
| PostgreSQL | Docker network |
| Redis | Docker network / localhost |
| Internal application APIs | Docker network / localhost |

## Routing

VPN clients can access selected resources on the private network through the WireGuard tunnel.

Simplified model:

```text
VPN Client
   |
   v
WireGuard Tunnel
   |
   v
VPN Interface
   |
   v
Server
   |
   v
Private LAN
```

Routing is explicitly controlled instead of allowing unrestricted traffic.

## Name Resolution

Different forms of name resolution are used depending on the network layer.

### Docker

Docker provides internal DNS resolution between containers.

Containers can communicate using service names such as:

```text
mariadb
redis
nextcloud
jellyfin
```

### Local Network

Local devices use the LAN DNS configuration provided by the network infrastructure.

### Public Services

Public services use DNS names that point to the reverse proxy.

Real production domain names are intentionally excluded from this repository.

## Service Isolation

The goal is to avoid unnecessary communication between unrelated services.

Isolation is provided by:

- Docker networks
- Host firewall rules
- Interface-specific port bindings
- VPN access controls
- Localhost bindings

## Network Security Principles

The network design follows these principles:

- Expose only what is necessary
- Prefer VPN access for administration
- Keep databases private
- Restrict SSH to trusted networks
- Use HTTPS for externally accessible applications
- Separate public and administrative interfaces
- Use Docker internal networking where possible
- Avoid publishing unnecessary container ports
- Review firewall rules regularly
- Remove obsolete access rules

## Sanitization

Real infrastructure values are not published.

The following information is intentionally replaced or omitted:

- Real private IP addresses
- Public IP addresses
- Real VPN addressing
- Real domain names
- Router configuration
- Port forwarding details that could expose the environment
- WireGuard keys
- Authentication credentials
- Internal device identities

The examples in this repository are intended to demonstrate architecture and networking concepts without exposing the real environment.
