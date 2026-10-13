# Backup Restore Testing Procedure

## Overview

A backup should not be considered reliable until its data can be successfully restored and validated.

This document describes a safe and repeatable restore-testing procedure for Borg Backup repositories used in the homelab.

The objective is to verify backup recoverability without modifying production data.

## Core Principle

> A successful backup job does not guarantee a successful restore.

Backup validation should therefore include:

- Repository accessibility
- Archive availability
- Restore execution
- File integrity
- Permission validation
- Application-level validation when appropriate
- Documentation of the test result

## Safety Rules

Restore testing must never overwrite production data.

Always restore into an isolated temporary location.

Example:

```text
Production Data
      |
      v
Borg Backup
      |
      v
Backup Repository
      |
      v
Temporary Restore Directory
      |
      v
Validation
```

The temporary restore directory should be separate from the active application data.

## Pre-Test Checks

Before performing a restore test, verify:

- Backup repository is accessible
- Backup disk is mounted
- Sufficient free space exists
- The selected archive is known
- Production services will not be modified
- Restore destination is empty or disposable

Check filesystem capacity:

```bash
df -h
```

Check mounted storage:

```bash
lsblk
```

## Repository Inspection

List available Borg archives:

```bash
borg list /path/to/repository
```

Inspect repository information:

```bash
borg info /path/to/repository
```

Real repository paths, credentials and encryption information are intentionally excluded from this repository.

## Select a Restore Point

Choose an archive appropriate for testing.

The selected archive should ideally represent a recent successful backup.

Document:

- Archive name
- Backup date
- Backup source
- Expected contents

## Create an Isolated Restore Directory

Example:

```bash
mkdir -p /tmp/borg-restore-test
```

Move into the temporary directory before extraction:

```bash
cd /tmp/borg-restore-test
```

This reduces the risk of accidentally writing restored files into production locations.

## Restore Test

For Borg 1.x style repositories, a restore operation may follow this pattern:

```bash
borg extract /path/to/repository::ARCHIVE_NAME
```

The exact command depends on the Borg version and repository configuration.

Always confirm the target directory before executing a restore.

## Validate Restored Data

After extraction, inspect the restored files:

```bash
find /tmp/borg-restore-test -type f | head
```

Check restored size:

```bash
du -sh /tmp/borg-restore-test
```

Check permissions:

```bash
find /tmp/borg-restore-test -maxdepth 2 -ls | head
```

Validation should confirm that:

- Expected directories exist
- Expected files exist
- File sizes are reasonable
- Ownership is appropriate
- Permissions are preserved
- Files are readable

## File Integrity Testing

For important files, compare checksums when an original copy is available.

Example:

```bash
sha256sum original-file
sha256sum restored-file
```

Matching hashes provide evidence that the restored file is identical to the source.

## Configuration File Validation

Restored configuration files can be checked without replacing active configuration.

Useful checks include:

- Syntax validation
- Expected values
- File permissions
- Application-specific validation

For example, a restored Bash script can be validated with:

```bash
bash -n restored-script.sh
```

## Database Restore Testing

Database backups require additional care.

A database restore test should preferably use:

- A temporary database
- A disposable container
- A separate test environment

Simplified workflow:

```text
Database Backup
      |
      v
Temporary Database
      |
      v
Restore
      |
      v
Integrity Validation
      |
      v
Application Test
```

Never restore a test database directly over a production database.

## Application-Level Validation

For critical services, file restoration alone may not be sufficient.

Where possible, test whether restored data can actually be used by the application.

Examples include:

- Application starts successfully
- Database opens correctly
- User files are accessible
- Media files are readable
- Configuration loads without errors

## Repository Integrity

Repository integrity should also be checked periodically.

Borg provides repository verification capabilities.

Example:

```bash
borg check /path/to/repository
```

Repository verification may take significant time depending on repository size.

It should therefore be scheduled appropriately.

## Cleanup

After validation, remove the temporary restore environment only after test results have been recorded.

Example:

```bash
rm -rf /tmp/borg-restore-test
```

Before removing anything, always verify the path carefully.

Never use cleanup commands against production storage.

## Test Record

Each restore test should record:

```text
Date:
Archive:
Restore destination:
Restore completed:
Files validated:
Integrity check:
Application validation:
Result:
Notes:
```

Example result:

```text
Result: PASS

Archive successfully restored to an isolated directory.
Expected files were present and readable.
Selected checksums matched.
Production data was not modified.
```

## Recommended Test Frequency

Restore testing can be performed periodically according to data importance.

Example strategy:

- Frequent verification of backup job success
- Monthly repository inspection
- Periodic sample-file restoration
- Quarterly broader recovery test
- Full disaster recovery exercise when major infrastructure changes occur

The exact schedule depends on the environment and recovery requirements.

## Failure Handling

If a restore test fails:

1. Do not delete the affected backup
2. Record the failure
3. Determine whether the problem is repository, storage or configuration related
4. Check other archives
5. Inspect backup job logs
6. Verify backup disk health
7. Correct the backup process
8. Repeat the restore test

A failed restore test should be treated as a backup reliability issue.

## Integration With Disaster Recovery

This procedure complements:

- [Backup Strategy](backup-strategy.md)
- [Disaster Recovery Runbook](disaster-recovery.md)
- [Storage Architecture](storage.md)
- [Troubleshooting Runbook](troubleshooting.md)

Together they document:

```text
Prevention
   |
   v
Backup
   |
   v
Verification
   |
   v
Restore Testing
   |
   v
Disaster Recovery
```

## Future Improvements

Possible improvements include:

- Automated restore testing
- Checksum verification scripts
- Scheduled repository checks
- Restore-test reports in JSON or Markdown
- Off-site backup testing
- Recovery time measurement
- Automated notifications
- Disposable Docker-based restore environments

## Security Notice

This document intentionally excludes:

- Real backup paths
- Encryption keys
- Backup passwords
- Personal data
- Production archive names
- Private infrastructure information

All examples are sanitized for portfolio use.
