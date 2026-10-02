# Linux Homelab Infrastructure

A self-hosted Linux infrastructure project built to develop practical experience in Linux administration, networking, cybersecurity, Docker, storage, backup, monitoring and self-hosted services.

## Overview

This homelab runs on **Ubuntu 26.04.1 LTS (Resolute Raccoon)** and hosts multiple services using Docker and Docker Compose.

The environment was designed with a focus on:

- Security
- Service isolation
- Secure remote access
- Data redundancy
- Backup and recovery
- Monitoring
- Self-hosting
- Continuous learning

## Operating System

- Ubuntu 26.04.1 LTS
- Codename: Resolute Raccoon
- Debian-based Linux distribution

## Core Technologies

- Linux
- Docker
- Docker Compose
- WireGuard
- UFW
- Fail2Ban
- Nginx Proxy Manager
- Linux Software RAID
- Borg Backup
- SMART Monitoring
- MariaDB
- PostgreSQL
- Redis

## Self-Hosted Services

### Cloud and Productivity

- Nextcloud
- ONLYOFFICE

### Media and Photos

- Jellyfin
- Immich

### Home Automation and Monitoring

- Home Assistant
- Frigate
- Matter Server
- Mosquitto MQTT

### Infrastructure

- Nginx Proxy Manager
- MariaDB
- PostgreSQL
- Redis

## Storage Architecture

The server uses different storage layers for the operating system, application data and backups.

### System Storage

The operating system runs on NVMe storage.

### Main Data Storage

Two hard drives are configured as a Linux software **RAID1** array.

RAID1 mirrors data between both disks, providing redundancy in case one drive fails.

### Backup Storage

A separate hard drive is dedicated to backups.

Backups are managed using **Borg Backup**, providing an additional layer of protection independent from the RAID array.

RAID protects against disk failure, while backups protect against situations such as:

- Accidental file deletion
- File corruption
- Configuration mistakes
- Application failures

RAID is not a replacement for backups.

## Network Architecture

The server is connected to a private local network.

Remote access is provided through **WireGuard VPN**.

Administrative services are restricted to trusted networks.

SSH access is allowed only from:

- Local network
- WireGuard VPN networks

Direct SSH access from the public Internet is blocked.

## Firewall

The server uses **UFW** as its host firewall.

The default policy follows a restrictive approach:

- Deny incoming traffic
- Allow outgoing traffic
- Deny routed traffic unless explicitly allowed

Only required services receive specific firewall rules.

## Public Access

Public exposure is intentionally limited.

**Nginx Proxy Manager** handles HTTP and HTTPS traffic.

The public-facing architecture is designed so that only explicitly required services are exposed through the reverse proxy.

Internal services remain restricted to:

- Local network
- VPN
- Docker internal networks
- Localhost

## Docker Architecture

Applications are separated into Docker containers and Docker networks.

Service ports are bound only to the interfaces that require them whenever possible.

Examples include:

- Nextcloud restricted to the local network
- ONLYOFFICE restricted to the local network
- Immich restricted to the local network
- Jellyfin direct access restricted to the local network
- Nginx Proxy Manager administration restricted to the local network
- Internal databases not exposed directly to the public network
- Internal Redis services not exposed publicly
- Internal application components bound to localhost when external access is unnecessary

## Security Hardening

The infrastructure was reviewed and hardened before being documented for this repository.

### Firewall Cleanup

Old and unused firewall rules were removed.

The remaining rules are limited to services that are actively required.

### Service Cleanup

Unused or redundant system services were disabled or removed.

Examples include:

- OpenVPN disabled after migration to WireGuard
- Multipath services disabled because they were not required
- Redundant host Redis service disabled
- Duplicate CUPS Snap installation removed

### Database Security

Sensitive database credentials were moved out of Docker Compose configuration files.

Secrets are stored separately from the infrastructure configuration.

Service credentials were also rotated during the hardening process.

MariaDB administrative access was restricted.

### Nextcloud and ONLYOFFICE

JWT authentication is enabled between Nextcloud and ONLYOFFICE.

This provides authenticated communication between both services.

### SSH Security

SSH is restricted to trusted private networks.

Public SSH access is blocked by firewall policy.

## Monitoring

Several mechanisms are used to monitor infrastructure health.

### Disk Monitoring

SMART monitoring is enabled for physical disks.

### RAID Monitoring

Linux MD monitoring is enabled for the RAID1 array.

### Security Monitoring

Fail2Ban is enabled to help protect services against repeated authentication attempts.

### Container Health Checks

Several Docker services use health checks to verify application availability.

## Remote Administration

WireGuard is the primary VPN solution for remote access.

Administrative access can be performed through:

- SSH
- WireGuard VPN
- Remote Desktop when required

This allows internal services to remain private instead of exposing unnecessary ports to the Internet.

## Backup Strategy

The infrastructure separates redundancy from backup.

### RAID1

RAID1 provides availability when one storage disk fails.

### Borg Backup

Borg Backup provides versioned backups on a separate storage device.

The backup strategy is designed to protect against:

- Accidental deletion
- Data corruption
- Configuration errors
- Application failures
- Storage problems

## Security Before Publication

The real production configuration is not published directly.

This repository contains only **sanitized examples**.

The following information is intentionally excluded:

- Passwords
- API keys
- Authentication tokens
- Private keys
- Database credentials
- Real domain names
- Sensitive internal network information
- Personal files
- Backups
- Application databases

Example configuration files use placeholder values instead.

## Repository Structure

```text
linux-homelab-infrastructure/
├── README.md
├── docs/
├── diagrams/
├── docker/
└── scripts/
```

### docs

Technical documentation about the infrastructure.

### diagrams

Architecture and network diagrams.

### docker

Sanitized Docker Compose configuration examples.

### scripts

Administration and utility scripts that are safe to publish.

## Skills Developed

This project provides practical experience with:

- Linux administration
- Networking
- TCP/IP
- VPN configuration
- Firewall management
- Docker
- Docker Compose
- Reverse proxies
- Linux storage
- RAID
- Backup strategies
- Database administration
- Service monitoring
- Security hardening
- Troubleshooting

## Project Status

**Active**

This homelab is continuously improved as part of my Computer Engineering studies and my practical development in Linux, networking and cybersecurity.
