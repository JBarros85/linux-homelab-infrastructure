# Storage Architecture

## Overview

The homelab uses multiple storage layers with different responsibilities.

The main goals are:

- Separate operating system storage from application data
- Provide redundancy for important data
- Maintain independent backups
- Monitor disk health
- Reduce the impact of individual disk failures

## Storage Layout

The environment uses three main storage roles:

```text
NVMe
  |
  +---- Operating System
  +---- Applications
  +---- Docker runtime

RAID1
  |
  +---- Application data
  +---- Media
  +---- Nextcloud data
  +---- Persistent service data

Separate Backup Disk
  |
  +---- Borg repositories
  +---- Historical backup snapshots
```

## Operating System Storage

The operating system runs on NVMe storage.

This provides fast access for:

- Ubuntu
- System packages
- Docker
- Application binaries
- Logs
- Temporary data

The operating system storage is separated from the main application data array.

## RAID1 Data Storage

The primary data storage uses Linux software RAID1.

Simplified layout:

```text
Disk A ──┐
         ├── RAID1 ── Main Data Filesystem
Disk B ──┘
```

RAID1 stores the same data on both disks.

If one disk fails, the array can continue operating using the remaining healthy disk.

## RAID Monitoring

The RAID array is monitored by Linux MD tools.

A healthy RAID1 array normally shows both devices active.

Example:

```text
[UU]
```

Each `U` represents an active member of the RAID array.

Monitoring is important because RAID redundancy only works while both disks remain healthy.

## What RAID Protects Against

RAID1 helps protect against:

- Failure of one physical disk
- Temporary loss of one RAID member
- Some hardware-related availability problems

## What RAID Does Not Protect Against

RAID is not a backup.

RAID1 does not protect against:

- Accidental file deletion
- Application corruption
- Malware
- Incorrect configuration
- User mistakes
- Files overwritten by applications
- Simultaneous failure of multiple disks
- Physical loss of the server

For this reason, a separate backup system is also used.

## Backup Storage

Backups are stored on a separate physical hard drive.

The backup disk is independent from the RAID1 array.

Simplified design:

```text
Primary Data
    |
    v
RAID1
    |
    v
Borg Backup
    |
    v
Separate Backup Disk
```

This provides an additional recovery layer.

## Borg Backup

Borg Backup is used for backup management.

Borg provides features such as:

- Deduplication
- Compression
- Snapshot-style archives
- Incremental storage efficiency
- Archive verification
- Retention management

Only changed data needs to consume additional storage after the initial backup.

## Data Separation

Application data is separated from system files whenever possible.

Examples of data stored separately include:

- Cloud files
- Photos
- Media
- Persistent Docker data
- Application storage
- Backup repositories

This simplifies maintenance and recovery.

## Docker Persistent Data

Containers themselves are considered replaceable.

Important data is stored using persistent volumes or bind mounts.

The basic principle is:

```text
Container
   |
   v
Persistent Storage
   |
   v
RAID1
```

If a container needs to be recreated, the application data remains available.

## Disk Health Monitoring

SMART monitoring is enabled for physical disks.

SMART information can help identify indicators such as:

- Reallocated sectors
- Pending sectors
- Read errors
- Temperature problems
- Self-test failures

Disk monitoring does not replace backups but helps identify failing hardware earlier.

## Filesystem Monitoring

Storage usage should be monitored regularly.

Useful checks include:

```text
Filesystem capacity
Free space
Mount status
RAID status
SMART status
Backup repository status
```

Running out of disk space can cause application and database failures even when the hardware itself is healthy.

## Recovery Strategy

The storage design uses multiple recovery layers.

### Disk Failure

RAID1 allows the system to continue operating after a single member failure.

### File Loss

Borg backups can be used to recover previous versions of files.

### Application Failure

Persistent data and backups allow services to be recreated without depending on the original container.

### Operating System Failure

Application data is separated from the main operating system storage, simplifying recovery and rebuilding.

## Storage Security

Storage configuration also follows security principles.

Sensitive data should not be published or committed to Git.

The repository does not contain:

- Real application data
- Personal files
- Backup archives
- Database files
- Encryption secrets
- Private storage paths that reveal sensitive information

Documentation uses simplified examples instead.

## Design Principles

The storage architecture follows these principles:

- RAID is redundancy, not backup
- Backups must be independent from primary storage
- Important application data must be persistent
- Containers should be replaceable
- Disk health should be monitored
- Backup integrity should be verified
- Storage capacity should be monitored
- Recovery procedures should be documented

## Future Improvements

Possible future improvements include:

- Additional off-site backup
- Encrypted remote backup
- Automated backup reports
- Storage capacity alerts
- Backup restoration tests
- Additional SMART alerting
- Documented disaster recovery procedures

## Summary

The homelab storage architecture combines:

```text
NVMe
  +
RAID1
  +
Separate Borg Backup Disk
  +
SMART Monitoring
```

These layers provide performance, redundancy, monitoring and recoverability while keeping each function independent.
