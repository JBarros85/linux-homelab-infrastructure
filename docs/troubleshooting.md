# Homelab Troubleshooting Runbook

## Overview

This runbook documents a structured troubleshooting workflow for diagnosing common problems in a Linux homelab.

The main principle is:

> Observe first, change later.

The initial diagnostic phase should avoid restarting services, modifying firewall rules or changing configuration before enough evidence has been collected.

## Troubleshooting Workflow

A typical investigation follows this order:

```text
1. Identify the affected service
2. Confirm the reported symptom
3. Check container or service status
4. Verify network connectivity
5. Check listening ports
6. Review logs
7. Verify dependencies
8. Check storage and system resources
9. Check firewall and VPN
10. Apply the smallest necessary change
11. Validate the result
12. Document the incident
```

## 1. Check Docker Containers

List running containers:

```bash
docker ps
```

Show all containers, including stopped ones:

```bash
docker ps -a
```

Useful information includes:

- Container status
- Health state
- Published ports
- Unexpected restarts
- Containers that exited

## 2. Check Container Logs

Review recent logs without modifying the container:

```bash
docker logs --since 10m <container_name>
```

Search for common error patterns:

```bash
docker logs --since 10m <container_name> 2>&1 | grep -Ei 'error|exception|failed|fatal|warning'
```

Logs should normally be reviewed before restarting a service.

## 3. Check Docker Compose Services

Inside the relevant Compose project:

```bash
docker compose ps
```

Review the resolved Compose configuration:

```bash
docker compose config
```

This can help identify:

- Incorrect environment variables
- Port mappings
- Missing volumes
- Network configuration
- Dependency configuration

## 4. Check Listening Ports

Show listening TCP and UDP sockets:

```bash
sudo ss -lntup
```

Check a specific port:

```bash
sudo ss -lntup | grep ':PORT'
```

This helps determine whether the expected application is actually listening on the host.

## 5. Test Local HTTP Services

Test a service from the server itself:

```bash
curl -I http://127.0.0.1:PORT
```

For a LAN-bound service:

```bash
curl -I http://192.168.10.10:PORT
```

Example addresses in this repository are sanitized and do not represent the real network.

Useful HTTP results include:

```text
200 OK
301 Moved Permanently
302 Found
401 Unauthorized
403 Forbidden
502 Bad Gateway
503 Service Unavailable
```

A successful TCP connection with an application-level error can help distinguish network problems from application problems.

## 6. Check Basic Network Configuration

Show interfaces and addresses:

```bash
ip addr
```

Show routes:

```bash
ip route
```

Test reachability:

```bash
ping -c 4 <destination>
```

Inspect the path to a destination when needed:

```bash
tracepath <destination>
```

## 7. Check DNS Resolution

Test name resolution:

```bash
getent hosts example.internal
```

If available:

```bash
dig example.internal
```

DNS problems can appear similar to application or connectivity failures.

## 8. Check WireGuard

Review WireGuard status:

```bash
sudo wg show
```

Useful information includes:

- Peer configuration
- Latest handshake
- Data transferred
- Endpoint information

A recent handshake normally indicates that the VPN tunnel is communicating.

## 9. Check Firewall Rules

Review UFW status:

```bash
sudo ufw status numbered
```

Review default policies:

```bash
sudo ufw status verbose
```

During diagnosis, firewall rules should be inspected before being changed.

## 10. Check Docker Networks

List Docker networks:

```bash
docker network ls
```

Inspect a specific network:

```bash
docker network inspect <network_name>
```

This helps verify:

- Connected containers
- Docker IP assignments
- Network isolation
- Whether dependent containers share the expected network

## 11. Test Communication Between Containers

Resolve another service from inside a container:

```bash
docker exec <container_name> getent hosts <service_name>
```

Test an HTTP dependency:

```bash
docker exec <container_name> curl -I http://<service_name>:PORT
```

This helps determine whether a problem exists:

```text
Client -> Host
```

or inside:

```text
Container -> Docker Network -> Dependency
```

## 12. Check System Resources

Memory:

```bash
free -h
```

CPU and processes:

```bash
top
```

Disk usage:

```bash
df -h
```

Block devices:

```bash
lsblk
```

A service failure may be caused by resource exhaustion rather than the application itself.

## 13. Check RAID1

Review Linux software RAID status:

```bash
cat /proc/mdstat
```

A healthy two-disk RAID1 commonly shows:

```text
[UU]
```

Detailed information:

```bash
sudo mdadm --detail /dev/md0
```

Unexpected degraded status should be investigated before performing unnecessary application changes.

## 14. Check Disk Health

Basic SMART health:

```bash
sudo smartctl -H /dev/sdX
```

Detailed SMART information:

```bash
sudo smartctl -a /dev/sdX
```

Important indicators include:

- Reallocated sectors
- Pending sectors
- Offline uncorrectable sectors
- SMART self-test failures
- Temperature

## 15. Check Borg Backups

List available archives:

```bash
borg list /path/to/repository
```

Show repository information:

```bash
borg info /path/to/repository
```

Backup failures should also be correlated with:

- Disk availability
- Mount status
- Free space
- Scheduled job logs

Real repository paths and credentials are intentionally excluded from this public documentation.

## 16. Check systemd Services

Check a service:

```bash
systemctl status <service> --no-pager
```

Review recent logs:

```bash
journalctl -u <service> --since "30 minutes ago" --no-pager
```

Review failed systemd units:

```bash
systemctl --failed
```

## 17. Check General System Logs

Recent high-priority events:

```bash
journalctl -p err --since today --no-pager
```

Kernel messages:

```bash
journalctl -k --since today --no-pager
```

Logs can help identify:

- Disk errors
- Network interface problems
- Filesystem issues
- Service crashes
- Permission problems

## 18. Reverse Proxy Troubleshooting

For a service behind a reverse proxy, isolate each layer.

```text
Internet
   |
   v
Router
   |
   v
Reverse Proxy
   |
   v
Application
```

Test progressively:

```text
1. Application locally
2. Application from LAN
3. Reverse proxy to application
4. HTTPS endpoint
5. External access
```

This makes it easier to identify which layer is failing.

## 19. Database Dependency Troubleshooting

If an application depends on a database:

```text
Application
    |
    v
Database
```

Verify:

- Database container is running
- Both containers share the expected Docker network
- DNS resolves the database service name
- Database port is reachable internally
- Authentication configuration is correct
- Database logs do not show connection errors

Database ports should remain private whenever public access is unnecessary.

## 20. Troubleshooting by Layer

### Application Layer

Check:

- Container status
- Application logs
- Configuration
- Dependencies

### Container Layer

Check:

- Docker networks
- Volumes
- Environment variables
- Health checks

### Host Layer

Check:

- Listening ports
- CPU
- Memory
- Disk space
- systemd services

### Network Layer

Check:

- IP configuration
- Routes
- DNS
- Firewall
- VPN

### Storage Layer

Check:

- Filesystem usage
- Mount points
- RAID status
- SMART health
- Backup availability

## Example Incident Flow

Example:

```text
User reports application unavailable
            |
            v
Check container status
            |
            v
Container is running
            |
            v
Check application logs
            |
            v
No application errors
            |
            v
Check listening port
            |
            v
Port is listening
            |
            v
Test locally with curl
            |
            v
Local access works
            |
            v
Check firewall / VPN / reverse proxy
            |
            v
Identify failing network layer
```

This avoids immediately restarting a healthy application when the real problem is elsewhere.

## Safe Diagnostic Principle

During the first phase of troubleshooting, prefer commands that only read system state.

Examples:

```bash
docker ps
docker logs
ss
ip addr
ip route
wg show
ufw status
df -h
free -h
cat /proc/mdstat
smartctl
journalctl
```

Configuration changes, container restarts and system reboots should only be considered after the problem has been identified.

## Documentation

After resolving an incident, record:

- Symptom
- Affected service
- Root cause
- Diagnostic steps
- Resolution
- Preventive action

Good troubleshooting documentation helps reduce recovery time when similar problems occur again.

## Security Notice

All network addresses, paths and infrastructure examples in this document are sanitized.

This repository does not publish:

- Real private network addresses
- Public IP addresses
- Real domains
- VPN keys
- Passwords
- API tokens
- Database credentials
- Personal data
