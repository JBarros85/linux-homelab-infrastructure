# Disaster Recovery Runbook

## Overview

This runbook documents a high-level recovery strategy for the homelab after major infrastructure failures.

The objective is to restore critical services methodically while protecting existing data and avoiding unnecessary changes during diagnosis.

The environment uses multiple recovery layers:

- Linux host
- Docker and Docker Compose
- RAID1 primary storage
- Separate Borg backup storage
- Persistent application data
- Infrastructure documentation stored in Git

## Recovery Principles

The recovery process follows these principles:

1. Preserve data before making changes
2. Identify the failed layer
3. Restore infrastructure before applications
4. Restore dependencies before dependent services
5. Validate each layer before continuing
6. Use backups only when necessary
7. Document the incident and recovery

## Failure Classification

### Service Failure

Examples:

- Container stopped
- Application unhealthy
- Database unavailable
- Reverse proxy error

Start with application and container diagnostics.

### Host Failure

Examples:

- Operating system corruption
- Boot failure
- Docker unavailable
- Critical system configuration damage

The host may need to be repaired or rebuilt.

### Storage Failure

Examples:

- RAID member failure
- Filesystem problems
- Disk hardware failure

Protect remaining storage before attempting application recovery.

### Data Loss

Examples:

- Accidental deletion
- Application corruption
- Incorrect configuration
- Damaged persistent data

Historical backup recovery may be required.

## Recovery Priority

A recommended recovery order is:

```text
1. Physical hardware
2. Operating system
3. Network connectivity
4. Storage
5. Docker
6. Databases and caches
7. Core applications
8. Reverse proxy
9. External access
10. Monitoring and backups
```

Dependencies should be restored before the services that require them.

## Initial Assessment

Before changing anything, collect basic information.

```bash
uptime
lsblk
df -h
cat /proc/mdstat
systemctl --failed
docker ps -a
ip addr
ip route
```

If available, also review:

```bash
journalctl -p err --since today --no-pager
```

The first phase should be diagnostic rather than corrective.

## RAID1 Failure

If the RAID array reports a degraded state:

```bash
cat /proc/mdstat
```

Detailed information:

```bash
sudo mdadm --detail /dev/md0
```

Do not immediately remove or recreate RAID members.

First determine:

- Which member failed
- Whether the remaining member is healthy
- Whether the filesystem is accessible
- Whether recent backups are available

RAID1 provides redundancy but does not replace backups.

## Disk Health

Check SMART information before deciding whether a disk should remain in service.

```bash
sudo smartctl -H /dev/sdX
sudo smartctl -a /dev/sdX
```

Important indicators include:

- Reallocated sectors
- Pending sectors
- Offline uncorrectable sectors
- SMART test failures
- Read errors

## Operating System Recovery

If the operating system cannot be repaired safely, the host can be rebuilt while preserving application data stored separately.

Simplified process:

```text
Install Ubuntu
      |
      v
Configure network
      |
      v
Restore system configuration
      |
      v
Install Docker
      |
      v
Mount persistent storage
      |
      v
Recreate services
```

The exact production configuration is intentionally not stored in this public repository.

## Docker Recovery

Containers should be considered replaceable.

Important data should exist outside the container filesystem using:

- Bind mounts
- Docker volumes
- Persistent storage
- Database storage

After Docker is restored:

```bash
docker ps
docker network ls
docker volume ls
```

Then recreate services using the appropriate Compose project.

```bash
docker compose up -d
```

Production Compose files may contain environment-specific information and are not published directly.

## Dependency Recovery

Services should be restored according to their dependencies.

Example:

```text
Database
   |
   +---- Redis
   |
   v
Application
   |
   v
Reverse Proxy
```

For example, an application should not be considered recovered until its database and supporting services are available.

## Borg Backup Recovery

Borg provides historical recovery when primary data is missing or corrupted.

Before restoration, inspect available archives.

```bash
borg list /path/to/repository
```

Repository information:

```bash
borg info /path/to/repository
```

A safe recovery should first restore data to a temporary location whenever possible.

Example workflow:

```text
Borg Repository
      |
      v
Temporary Restore Location
      |
      v
Validate Data
      |
      v
Move to Production
```

This reduces the risk of overwriting valid production data.

Real repository locations, credentials and encryption information are excluded from this repository.

## Database Recovery

Database recovery should be handled separately from ordinary application files.

Before restoring a database:

- Stop dependent applications when appropriate
- Verify backup integrity
- Preserve the current database state
- Confirm database version compatibility
- Restore into a controlled environment when possible

After restoration:

- Verify database connectivity
- Review logs
- Confirm application access
- Check data consistency

## Network Recovery

After rebuilding a host, verify network configuration before troubleshooting applications.

Check:

```bash
ip addr
ip route
```

Test local connectivity:

```bash
ping -c 4 <gateway>
```

Test DNS:

```bash
getent hosts example.com
```

Then validate:

- LAN connectivity
- DNS
- WireGuard
- Firewall
- Reverse proxy

## WireGuard Recovery

Verify the VPN interface:

```bash
sudo wg show
```

Confirm:

- Interface is active
- Expected peers exist
- Handshakes occur
- Routing is correct

Private keys and real VPN configuration must never be stored in the public repository.

## Firewall Recovery

Review firewall state:

```bash
sudo ufw status verbose
```

Firewall rules should be restored deliberately.

The intended architecture follows a default-deny approach with only required services allowed.

Administrative services should remain restricted to trusted networks.

## Application Validation

After restoring each service, validate it independently.

Recommended order:

```text
Container status
      |
      v
Application logs
      |
      v
Local connection
      |
      v
LAN connection
      |
      v
Reverse proxy
      |
      v
Remote access
```

This helps identify the exact layer where recovery is incomplete.

## Post-Recovery Validation

After restoring the environment, verify:

- RAID status
- Disk health
- Filesystem capacity
- Docker container health
- Database connectivity
- Application availability
- WireGuard connectivity
- Firewall state
- Reverse proxy operation
- Backup jobs
- Monitoring

The automated health-check script in this repository can assist with validation:

```bash
./scripts/homelab-health-check.sh
```

Machine-readable output:

```bash
./scripts/homelab-health-check.sh --json
```

## Recovery Documentation

After a major incident, record:

- Date and time
- Failure symptoms
- Root cause
- Affected services
- Diagnostic steps
- Recovery actions
- Data restored
- Validation performed
- Preventive improvements

This creates a repeatable recovery process instead of relying on memory.

## Future Improvements

Future disaster recovery improvements may include:

- Off-site encrypted backups
- Automated configuration backup
- Automated recovery validation
- Formal restore testing schedule
- Infrastructure automation
- Ansible-based host provisioning
- Recovery time measurements
- Documented recovery objectives

## Security Notice

This runbook intentionally excludes:

- Real IP addresses
- Public domains
- VPN keys
- Passwords
- API tokens
- Database credentials
- Personal data
- Private backup repository details

All examples are sanitized for portfolio use.
