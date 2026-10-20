# Storage Health Monitoring

## Overview

The homelab uses Linux software RAID and disk health monitoring to reduce the risk of unnoticed storage failures.

The monitoring strategy focuses on:

- Linux MD RAID state
- RAID member health
- Disk SMART information
- Filesystem utilization
- Kernel storage errors
- Periodic manual verification

The objective is early detection rather than automatic repair.

## RAID Monitoring

Linux MD RAID status can be checked with:

```bash
cat /proc/mdstat
```

A healthy RAID1 array typically contains a status similar to:

```text
[UU]
```

Each `U` represents an active RAID member.

For a two-disk RAID1:

```text
[UU] = both members active
[_U] = one member missing or failed
[U_] = one member missing or failed
```

A degraded array should be investigated immediately.

## Detailed RAID Information

More information about an array can be obtained with:

```bash
sudo mdadm --detail /dev/md0
```

Important fields include:

```text
Raid Level
Array Size
Raid Devices
Active Devices
Working Devices
Failed Devices
State
```

A healthy array should normally report:

```text
State : clean
Failed Devices : 0
```

The exact output depends on the current state of the system.

## RAID Synchronization

During rebuild, recovery or synchronization, `/proc/mdstat` can show progress:

```bash
watch -n 2 cat /proc/mdstat
```

Example:

```text
recovery = 42.3%
```

A rebuild can take a significant amount of time depending on:

- disk capacity
- disk speed
- system load
- RAID configuration

The system should not be assumed healthy until synchronization has completed and all expected members are active.

## SMART Monitoring

SMART data provides information about the health reported by individual disks.

List block devices first:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
```

Then inspect a physical disk:

```bash
sudo smartctl -a /dev/sdX
```

For NVMe devices:

```bash
sudo smartctl -a /dev/nvme0
```

The device name must be verified before running commands against a disk.

## Useful SMART Indicators

Depending on the device type, useful indicators can include:

```text
SMART overall-health
Reallocated sectors
Pending sectors
Uncorrectable sectors
Power-on hours
Temperature
Media errors
Percentage used
```

SMART information should be interpreted together with actual system behaviour and logs.

A single value should not be treated as the only indicator of disk health.

## SMART Self-Tests

A short self-test can be started with:

```bash
sudo smartctl -t short /dev/sdX
```

After the suggested waiting time, inspect the result:

```bash
sudo smartctl -l selftest /dev/sdX
```

A long test can be started with:

```bash
sudo smartctl -t long /dev/sdX
```

Long tests may take several hours.

Tests should be scheduled carefully on production-like systems.

## smartmontools Service

The SMART monitoring service can be inspected with:

```bash
systemctl status smartmontools --no-pager
```

Check whether it starts automatically:

```bash
systemctl is-enabled smartmontools
```

Check whether it is currently running:

```bash
systemctl is-active smartmontools
```

## Filesystem Utilization

Disk capacity should also be monitored independently of physical disk health.

Check mounted filesystems:

```bash
df -h
```

For script-friendly output:

```bash
df -P
```

A disk can be physically healthy while the filesystem is close to full, so capacity monitoring is a separate concern.

## Block Device Overview

A useful overview of the storage topology is:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
```

This helps identify:

- physical disks
- partitions
- RAID devices
- filesystem types
- mount points
- device models

## Kernel Storage Errors

Recent kernel messages can reveal storage-related problems.

Examples:

```bash
journalctl -k -b | grep -Ei 'error|fail|ata|nvme|md|raid|i/o'
```

or:

```bash
dmesg | grep -Ei 'error|fail|ata|nvme|md|raid|i/o'
```

These searches can produce unrelated matches, so results must be reviewed rather than treated automatically as confirmed disk failures.

## Monitoring Workflow

A practical storage review can follow this order:

```text
1. Check /proc/mdstat
2. Inspect RAID details
3. Review filesystem utilization
4. Identify physical disks
5. Inspect SMART data
6. Review SMART self-tests
7. Check kernel logs for storage errors
8. Compare findings with previous observations
```

## Example Read-Only Audit

```bash
echo "=== RAID ==="
cat /proc/mdstat

echo
echo "=== FILESYSTEMS ==="
df -h

echo
echo "=== BLOCK DEVICES ==="
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL

echo
echo "=== SMART SERVICE ==="
systemctl is-active smartmontools
systemctl is-enabled smartmontools
```

This audit does not modify the RAID array or disks.

## What Not to Do During Diagnosis

Potentially destructive RAID commands should not be used simply to diagnose a problem.

Examples of operations that require careful verification include:

```text
creating an array
forcing assembly
removing members
adding replacement disks
zeroing RAID metadata
formatting filesystems
```

Before any repair operation:

```text
identify the correct device
confirm backups
record the current RAID state
verify which member failed
understand the recovery procedure
```

## RAID Is Not a Backup

RAID1 protects against the failure of one disk in the mirror.

It does not protect against:

- accidental deletion
- filesystem corruption
- ransomware
- application errors
- incorrect administrative commands
- simultaneous disk failures
- loss of the entire host

For this reason, RAID is used together with a separate backup strategy.

See:

[Backup Strategy](backup-strategy.md)

[Backup Restore Testing](backup-restore-testing.md)

[Disaster Recovery](disaster-recovery.md)

## Integration with the Homelab Health Check

The repository's health-check script also inspects Linux MD RAID state:

```bash
./scripts/homelab-health-check.sh
```

Machine-readable output is available with:

```bash
./scripts/homelab-health-check.sh --json
```

The automated check is useful for regular monitoring, while the commands in this document provide deeper manual investigation.

## Security and Privacy

Public documentation does not include:

- disk serial numbers
- filesystem UUIDs
- backup credentials
- encryption keys
- personally identifiable device information

Device names shown in examples such as:

```text
/dev/sdX
```

are intentionally generic.

## Conclusion

Storage monitoring combines several independent signals:

```text
RAID state
+
SMART health
+
filesystem capacity
+
kernel logs
+
backup verification
```

No single command is sufficient to determine the complete health of a storage system.

Regular inspection and tested backups are both required for reliable recovery.
