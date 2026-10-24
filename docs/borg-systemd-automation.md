# Automated Borg Backup with systemd

## Overview

The homelab uses Borg Backup together with native `systemd` services and timers to automate two separate tasks:

```text
Daily backup
      +
Weekly repository integrity check
```

The objective is to keep backup creation and repository verification independent while allowing both jobs to be monitored through standard Linux tools such as:

```bash
systemctl
journalctl
systemctl list-timers
```

The examples in this document are sanitized versions of the configuration used in the homelab.

## Architecture

```text
systemd timer
     |
     v
backup service
     |
     v
Borg backup script
     |
     +---- application data
     +---- container data
     +---- system data
     |
     v
Borg repository
```

A separate weekly workflow verifies the repository:

```text
systemd timer
     |
     v
repository check service
     |
     v
borg check --repository-only
```

## Daily Backup Timer

The backup timer runs once per day.

Sanitized example:

```ini
[Unit]
Description=Daily Borg backup schedule

[Timer]
OnCalendar=*-*-* 03:15:00
RandomizedDelaySec=10min
Persistent=false
Unit=borg-backup-full.service

[Install]
WantedBy=timers.target
```

The timer is enabled and waits for its next scheduled execution.

Check it with:

```bash
systemctl status borg-backup-full.timer
```

or:

```bash
systemctl list-timers --all | grep borg
```

## Why `RandomizedDelaySec` Is Used

The timer includes:

```ini
RandomizedDelaySec=10min
```

This allows systemd to delay the start slightly rather than always executing at exactly the same second.

For a homelab with several scheduled maintenance tasks, this helps avoid unnecessary contention when multiple jobs would otherwise start simultaneously.

## Backup Service

The daily backup is implemented as a `oneshot` service.

Sanitized example:

```ini
[Unit]
Description=Complete Borg backup
Requires=docker.service
After=docker.service local-fs.target
RequiresMountsFor=/mnt/data /mnt/backup

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/borg-backup-full.sh
ExecStopPost=/usr/local/sbin/borg-backup-safety-cleanup.sh
TimeoutStartSec=infinity
TimeoutStopSec=20min
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=6
OOMScoreAdjust=-500
StandardOutput=journal
StandardError=journal
SyslogIdentifier=borg-backup-full
```

## Docker Dependency

The service declares:

```ini
Requires=docker.service
After=docker.service
```

This ensures the Docker service is available before the backup workflow starts.

This is important because the backup process interacts with containerized workloads.

## Required Mount Points

The backup service also declares required storage:

```ini
RequiresMountsFor=/mnt/data /mnt/backup
```

This prevents the backup workflow from starting without the required filesystems being available.

In public documentation, the actual mount points are replaced with sanitized examples.

## Resource Priority

The backup service runs with reduced CPU and I/O scheduling priority:

```ini
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=6
```

This helps keep the backup workload from competing unnecessarily with interactive or application workloads.

The service also contains:

```ini
OOMScoreAdjust=-500
```

which influences how the Linux Out-Of-Memory subsystem treats the backup process.

## Safety Cleanup

A dedicated cleanup script is configured through:

```ini
ExecStopPost=/usr/local/sbin/borg-backup-safety-cleanup.sh
```

The cleanup runs after the main backup command finishes.

Observed cleanup operations include:

```text
Ensure database/cache containers are running
Ensure application containers are running
Wait for application management commands to become available
Disable application maintenance mode
```

This adds an additional recovery step if the main backup workflow exits after temporarily changing application state.

## Successful Backup Verification

A successful execution should not be verified only by checking whether the timer exists.

Inspect the service:

```bash
systemctl status borg-backup-full.service
```

Important indicators include:

```text
code=exited
status=0/SUCCESS
```

The journal can also be checked:

```bash
journalctl -u borg-backup-full.service -n 50 --no-pager
```

A successful execution should finish with messages similar to:

```text
Backup completed
Safety cleanup completed
Deactivated successfully
Finished borg-backup-full.service
```

Because the service uses:

```ini
Type=oneshot
```

an `inactive (dead)` state after successful completion is expected.

The important result is the exit status.

## Backup Archives

The backup workflow produces separate archive groups for different categories of data.

Conceptually:

```text
data-YYYY-MM-DD_HH-MM-SS
system-YYYY-MM-DD_HH-MM-SS
```

This keeps application/data backups logically separated from system backups.

The public documentation intentionally avoids publishing real repository locations or sensitive paths.

## Retention

The backup workflow also applies a retention policy after archive creation.

The logs show the following general sequence:

```text
Create backup
Apply retention
Evaluate compaction policy
List current archives
Run safety cleanup
Finish
```

Retention should be treated separately from backup creation.

Deleting old archives does not prove that newly created backups are recoverable, which is why restore testing is documented separately.

See:

[Backup Restore Testing](backup-restore-testing.md)

## Borg Compaction

Repository compaction is evaluated independently during the backup workflow.

The script can decide whether compaction should run based on its configured policy.

This avoids performing potentially expensive repository maintenance on every daily backup.

## Weekly Repository Check

Repository integrity is checked through a separate timer.

Sanitized example:

```ini
[Unit]
Description=Weekly Borg repository check schedule

[Timer]
OnCalendar=Sun *-*-* 06:30:00
Persistent=false
RandomizedDelaySec=30min
Unit=borg-check-repository.service

[Install]
WantedBy=timers.target
```

This creates a weekly check with up to 30 minutes of randomized delay.

## Repository Check Service

The corresponding service is also a `oneshot` unit:

```ini
[Unit]
Description=Weekly Borg repository-only check
RequiresMountsFor=/mnt/backup

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/borg-check.sh --repository-only
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
StandardOutput=journal
StandardError=journal
SyslogIdentifier=borg-check
```

## Repository-Only Check

The service runs:

```text
borg check --repository-only
```

This verifies the Borg repository itself without combining the integrity check with the daily backup job.

Separating these operations provides clearer monitoring:

```text
Backup creation failure
        !=
Repository integrity failure
```

Each can be investigated independently.

## Repository Check Verification

Check the latest run with:

```bash
systemctl status borg-check-repository.service
```

and:

```bash
journalctl -u borg-check-repository.service -n 50 --no-pager
```

A successful run should show:

```text
Running borg check --repository-only
Borg check completed
Deactivated successfully
Finished borg-check-repository.service
```

and an exit status of:

```text
status=0/SUCCESS
```

## Long-Running Integrity Checks

Repository verification can take considerably longer than the daily backup.

This is not automatically an error.

Useful information includes:

```text
wall-clock duration
CPU time
memory usage
exit status
journal messages
```

The final exit status and Borg output are more important than the duration alone.

## Monitoring Commands

List Borg timers:

```bash
systemctl list-timers --all --no-pager | grep -i borg
```

Check the backup timer:

```bash
systemctl status borg-backup-full.timer
```

Check the last backup:

```bash
systemctl status borg-backup-full.service
```

Check backup logs:

```bash
journalctl -u borg-backup-full.service -n 50 --no-pager
```

Check repository verification:

```bash
systemctl status borg-check-repository.service
```

Check verification logs:

```bash
journalctl -u borg-check-repository.service -n 50 --no-pager
```

## Failure Investigation

If a scheduled backup fails, a practical sequence is:

```text
1. Check the timer
2. Check the service exit status
3. Read the service journal
4. Verify required filesystems are mounted
5. Verify Docker availability
6. Verify the Borg repository is accessible
7. Verify application cleanup completed
8. Investigate the specific Borg error
```

For a repository check failure:

```text
1. Do not assume the repository is corrupted
2. Preserve the Borg output
3. Check storage health
4. Check filesystem availability
5. Review recent backup failures
6. Investigate the repository before attempting repair
```

## Timer Persistence

Both timers currently use:

```ini
Persistent=false
```

This means a missed execution while the machine is powered off is not automatically replayed simply because the system starts later.

This behaviour should be considered when defining the desired backup policy for a server that is not continuously online.

## Security

Public documentation intentionally excludes:

- Real Borg repository paths
- Encryption passphrases
- Encryption keys
- Real application credentials
- Real internal paths where unnecessary
- Database passwords
- API tokens

Borg credentials and repository access information should remain outside public repositories.

## Backup Is Not Verified Until Restore Is Tested

A successful exit status confirms that Borg completed the configured operation.

It does not by itself prove that:

```text
the required files were included
the correct archive can be selected
the application can be restored
the restored data is usable
```

For this reason the homelab also maintains a separate restore-testing procedure.

See:

[Backup Restore Testing](backup-restore-testing.md)

## Related Documentation

- [Backup Strategy](backup-strategy.md)
- [Backup Restore Testing](backup-restore-testing.md)
- [Disaster Recovery](disaster-recovery.md)
- [Storage Health Monitoring](storage-health-monitoring.md)

## Conclusion

The backup automation separates four responsibilities:

```text
Scheduling
    |
    v
Backup creation
    |
    v
Retention / maintenance
    |
    v
Independent repository verification
```

Using native systemd timers and services provides:

```text
predictable scheduling
dependency management
mount verification
resource prioritization
centralized logging
exit-status monitoring
post-run cleanup
```

This makes the backup process observable and easier to troubleshoot than an unattended command running without service supervision.
