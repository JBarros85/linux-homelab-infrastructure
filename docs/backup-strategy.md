# Backup Strategy

## Overview

This document describes the backup strategy used in the homelab.

The backup system is designed to complement the RAID1 storage layer.

RAID and backup solve different problems:

- RAID provides availability after a disk failure
- Backup provides recovery from data loss, corruption or mistakes

The homelab uses Borg Backup with a separate physical backup disk.

## Backup Architecture

The simplified backup flow is:

```text
Application Data
      |
      v
RAID1 Storage
      |
      v
Borg Backup
      |
      v
Separate Backup Disk
```

The backup disk is physically separate from the main RAID1 data array.

This reduces the risk of losing both the primary data and its backup because of a single disk failure.

## Why RAID Is Not a Backup

RAID1 stores the same data on two disks.

If a file is deleted from the RAID1 filesystem, the deletion is replicated.

If an application corrupts a file, the corrupted version is also stored on both disks.

RAID1 does not protect against:

- Accidental deletion
- File corruption
- Application errors
- Configuration mistakes
- Malware
- User mistakes
- Incorrect synchronization
- Loss of the entire server

For this reason, independent backups are required.

## Borg Backup

Borg Backup is used to create backup archives.

Borg is suitable for the homelab because it supports:

- Deduplication
- Compression
- Incremental storage
- Archive history
- Integrity verification
- Retention policies
- Efficient repeated backups

## Deduplication

Borg uses deduplication.

This means identical blocks of data do not need to be stored multiple times.

Example:

```text
Backup 1
100 GB stored

Backup 2
Only changed data is added

Backup 3
Only new or modified blocks are added
```

This makes repeated backups more storage-efficient.

## Backup Scope

The backup strategy separates system data and important application data.

Typical backup targets include:

- Application data
- Important configuration files
- Server configuration
- Docker persistent data where appropriate
- User files
- Critical service data

Temporary or easily replaceable data does not necessarily need the same backup priority.

## System Backup

Important system configuration can be included in a separate backup archive.

Examples include:

- `/etc`
- Service configuration
- System scripts
- Important administration files

The goal is not necessarily to clone the entire operating system byte-for-byte.

Instead, the backup should contain enough information to rebuild the environment and restore the important configuration.

## Data Backup

Application data has higher priority because it may not be easily recreated.

Examples include:

- Nextcloud files
- Important documents
- Photos
- Application data
- Personal files
- Configuration that would be difficult to recreate manually

## Backup Scheduling

Backup jobs can be automated using systemd timers.

A simplified workflow is:

```text
systemd timer
      |
      v
Backup script
      |
      v
Borg create
      |
      v
Backup repository
```

Automated execution reduces the risk of forgetting to perform backups manually.

## Backup Verification

Creating a backup is not enough.

The backup repository must also be checked periodically.

Borg provides repository and archive verification mechanisms.

A good backup process includes:

1. Create backups regularly
2. Verify repository integrity
3. Monitor backup job results
4. Check available disk space
5. Test restoration procedures

## Restore Testing

A backup should be considered reliable only if data can actually be restored from it.

Restore tests should be performed periodically.

A safe restore test can use a temporary directory:

```text
Backup Repository
       |
       v
Temporary Restore Directory
       |
       v
Verify Files
```

The original production data should not be overwritten during a test restore.

## Retention

Keeping every backup forever is usually unnecessary.

A retention strategy can preserve different historical points.

Example:

```text
Recent backups
    |
    +---- Daily
    +---- Weekly
    +---- Monthly
```

The exact retention policy depends on:

- Available backup storage
- Importance of the data
- Frequency of changes
- Recovery requirements

## Monitoring

Backup jobs should provide a clear success or failure result.

Important checks include:

- Last successful backup
- Backup duration
- Repository integrity
- Available storage
- Backup disk health
- Failed scheduled jobs

## Backup Disk Monitoring

The physical backup disk is also monitored using SMART.

A backup stored on a failing disk cannot be considered reliable.

Important SMART indicators include:

- Reallocated sectors
- Pending sectors
- Read errors
- Self-test results
- Disk temperature

## Separation of Responsibilities

The homelab uses multiple protection layers:

```text
Layer 1
RAID1
Disk redundancy

Layer 2
Borg Backup
Historical recovery

Layer 3
SMART Monitoring
Disk health

Layer 4
Backup Verification
Repository integrity
```

Each layer protects against a different type of problem.

## Security

Backup repositories may contain sensitive information.

For this reason, the public Git repository never includes:

- Real backup archives
- Backup passwords
- Encryption keys
- Personal files
- Database dumps containing private data
- Backup repository paths that reveal sensitive information

Only documentation and sanitized examples are published.

## Disaster Recovery

A basic disaster recovery process would follow this order:

```text
1. Repair or replace failed infrastructure
2. Reinstall the operating system if necessary
3. Restore core configuration
4. Recreate Docker services
5. Restore application data
6. Validate application health
7. Verify user access
```

Documenting the environment makes recovery easier because the infrastructure can be recreated more systematically.

## Current Design

The current homelab backup architecture uses:

```text
RAID1 Primary Data
        +
Separate Physical Backup Disk
        +
Borg Backup
        +
Automated Backup Jobs
        +
Repository Checks
        +
SMART Monitoring
```

## Future Improvements

Possible future improvements include:

- Encrypted off-site backups
- Remote backup replication
- Automated backup notifications
- More frequent restore testing
- Disaster recovery documentation
- Backup reports
- Additional retention policies
- Secondary off-site storage

## Summary

The backup strategy follows one key principle:

> RAID provides redundancy. Backup provides recovery.

Both are necessary for a reliable storage environment.
