# Homelab Architecture Diagram

This diagram provides a simplified and sanitized overview of the homelab infrastructure.

```mermaid
flowchart TD

    Internet((Internet))

    Router["Router / Firewall"]

    Internet --> Router

    Router -->|UDP / VPN| WG["WireGuard VPN"]
    Router -->|HTTP / HTTPS| NPM["Nginx Proxy Manager"]

    WG --> LAN["Private LAN"]

    NPM --> Jellyfin["Jellyfin"]

    LAN --> SSH["SSH Administration"]
    LAN --> Nextcloud["Nextcloud"]
    LAN --> Immich["Immich"]
    LAN --> HA["Home Assistant"]
    LAN --> Frigate["Frigate"]
    LAN --> Jellyfin

    subgraph Docker["Docker Infrastructure"]
        Nextcloud
        Immich
        Jellyfin
        HA
        Frigate

        MariaDB["MariaDB"]
        PostgreSQL["PostgreSQL"]
        Redis["Redis"]
        Mosquitto["Mosquitto MQTT"]
        OnlyOffice["ONLYOFFICE"]
    end

    Nextcloud --> MariaDB
    Nextcloud --> Redis
    Nextcloud --> OnlyOffice

    Immich --> PostgreSQL
    Immich --> Redis

    Frigate --> Mosquitto

    subgraph Storage["Storage Layer"]
        NVMe["NVMe\nOperating System"]
        RAID["RAID1\nApplication Data"]
        Backup["Separate Backup Disk\nBorg Repository"]
    end

    Docker --> RAID
    RAID --> Backup

    subgraph Security["Security Layers"]
        UFW["UFW Firewall"]
        Fail2Ban["Fail2Ban"]
        VPN["VPN Access Control"]
        Secrets["Separated Secrets"]
    end

    Router --> UFW
    UFW --> Docker
    WG --> VPN
    SSH --> Fail2Ban
    Docker --> Secrets
```

## Access Model

```text
Internet
   |
   +---- WireGuard VPN
   |        |
   |        +---- Administration
   |        +---- Private Services
   |
   +---- Reverse Proxy
            |
            +---- Selected Public Service
```

## Storage Model

```text
NVMe
 |
 +---- Ubuntu Linux
 +---- Docker Runtime

RAID1
 |
 +---- Application Data
 +---- Media
 +---- Persistent Storage
 |
 +---- Borg Backup
          |
          +---- Separate Physical Disk
```

## Security Model

The environment follows a layered security approach:

- Default-deny host firewall
- Restricted SSH access
- WireGuard for remote administration
- Reverse proxy for selected public services
- Internal-only databases and caches
- Docker network isolation
- Fail2Ban protection
- Secrets stored outside version control
- RAID monitoring and SMART disk health checks
- Independent Borg backups

## Security Notice

The diagram intentionally does not expose:

- Real IP addresses
- Public IP addresses
- Real domain names
- VPN keys
- Passwords
- API tokens
- Database credentials
- Internal device identifiers

All architecture shown here is simplified and sanitized for portfolio purposes.
