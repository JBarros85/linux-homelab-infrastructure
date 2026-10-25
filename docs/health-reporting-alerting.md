# Automated Health Reporting and Alerting

The homelab includes automated health reporting and proactive alerting for
storage, backups, system resources and container health.

The monitoring design has three layers:

1. immediate alerts for conditions that require attention;
2. one concise weekly health summary;
3. one broader monthly infrastructure summary.

Detailed technical reports remain stored locally for troubleshooting, while
email notifications contain only the information needed for a quick health
assessment.

---

## Monitoring Overview

| Layer | Schedule | Purpose |
| --- | --- | --- |
| Immediate alert | Every 10 minutes | Detect important failures quickly |
| Weekly summary | Sunday 09:05 | Concise operational health overview |
| Monthly summary | First day of the month at 08:00 | Broader infrastructure review |

The schedules are managed by cron.

Example:

```text
*/10 * * * * root /usr/local/sbin/immediate-alert.sh
5 9 * * 0 root /usr/local/sbin/weekly-health-summary.sh
0 8 1 * * root /usr/local/sbin/monthly-health-summary.sh
```

The real production script names and notification destination are intentionally
not included in the public repository.

---

## Weekly Health Summary

Only one scheduled weekly health email is sent.

The summary includes:

- RAID state
- degraded RAID member count
- SMART pending sectors
- SMART reallocated sectors
- system disk usage
- RAID data usage
- backup disk usage
- CPU load and temperature
- memory usage
- GPU temperature and utilization
- GPU memory usage
- latest Borg backup result
- latest Borg repository verification result
- running Docker container count
- unhealthy Docker container count
- failed systemd service count
- relevant warnings

Example storage section:

```text
Storage:
- System: 63% used | 560G of 936G | 337G free
- RAID data: 78% used | 2.7T of 3.6T | 797G free
- Backup: 48% used | 1.2T of 2.7T | 1.4T free
```

This format provides both percentage utilization and actual capacity, making
storage pressure easier to understand quickly.

---

## Detailed Weekly Report

The weekly process also generates a complete local technical report.

Example location:

```text
/var/log/health-reports/weekly-YYYY-MM-DD_HH-MM-SS.txt
```

The detailed report contains information such as:

- uptime
- memory statistics
- filesystem utilization
- `mdadm` RAID details
- `/proc/mdstat`
- SMART attributes
- GPU status
- hardware sensors
- Borg service status
- Borg repository check status
- Docker container status
- failed systemd services

The email contains the path to this report so detailed information is available
when deeper troubleshooting is required.

---

## Immediate Alerts

A lightweight health script runs every 10 minutes.

It sends an email only when at least one monitored condition crosses an alert
threshold.

Current checks include:

### RAID

Alert when:

- the RAID reports one or more degraded members;
- the RAID becomes inactive or unavailable.

### SMART

Alert when:

- any monitored disk reports one or more current pending sectors.

Pending sectors are treated more urgently than historical reallocated sectors.

Reallocated sectors are tracked in the weekly and monthly summaries so their
evolution can be reviewed over time.

### CPU and GPU Temperature

Alert threshold:

```text
85 °C
```

for either CPU or GPU.

### Available Memory

Alert when available RAM falls to:

```text
1 GiB or less
```

### Filesystem Capacity

Alert when any monitored filesystem reaches:

```text
90% utilization
```

The monitored storage areas include:

- system filesystem;
- primary RAID data storage;
- dedicated backup storage.

### Borg Backup

Alert when the most recent Borg backup service does not report a successful
result.

Repository integrity checks are also shown in the scheduled health reports.

### Docker

Alert when one or more running containers report an `unhealthy` health status.

---

## Alert Cooldown

Immediate alerts use a two-hour cooldown.

This prevents a persistent condition from generating a new email every
10 minutes while still ensuring that the administrator is notified when the
problem is first detected.

Conceptually:

```text
problem detected
      |
      v
alert already sent recently?
      |
   +--+--+
   |     |
  yes    no
   |     |
 suppress send alert
```

---

## Monthly Health Summary

The monthly report provides a broader infrastructure snapshot.

It includes:

- server uptime
- load averages
- RAM usage
- swap usage
- RAID state
- degraded RAID count
- SMART pending sectors
- SMART reallocated sectors
- filesystem capacity
- latest Borg backup state
- latest Borg repository check state
- running Docker containers
- unhealthy containers
- failed systemd services
- pending operating-system updates
- number of weekly reports generated recently

A detailed monthly report is also stored locally under:

```text
/var/log/health-reports/
```

This keeps the email readable while preserving technical evidence for later
review.

---

## Avoiding Duplicate Notifications

The original configuration generated multiple overlapping weekly emails:

- a concise health summary;
- a separate complete RAID/SMART email.

The configuration was simplified so the administrator now receives only one
scheduled weekly summary.

Detailed RAID and SMART information remains available in the local technical
report instead of being duplicated in another email.

A redundant monthly email whose only purpose was testing SMART email delivery
was also removed.

---

## Email Delivery

Health notifications are delivered using:

```text
mail -> sendmail compatibility -> msmtp -> SMTP provider
```

The SMTP credentials are not stored in this repository.

The host configuration file is restricted to the root account:

```text
owner: root
mode: 0600
```

---

## Troubleshooting Email Delivery

An email delivery failure was diagnosed after scheduled reports continued to
generate local log data but stopped arriving in the administrator mailbox.

Testing `msmtp` directly revealed that the SMTP password helper could no longer
execute successfully.

Kernel audit logs identified the actual cause:

```text
apparmor="DENIED"
profile="msmtp//helpers"
```

The installed system used a newer coreutils implementation where commands such
as `cat` and `head` resolved through a different executable path.

The existing AppArmor profile allowed the traditional command paths but did not
allow the resolved helper executable used on this host.

As a result:

```text
msmtp
  -> passwordeval
      -> helper command
          -> blocked by AppArmor
```

---

## Resolution

Instead of disabling AppArmor or placing the complete `msmtp` profile into a
permissive mode, the configuration was simplified.

The SMTP credential is read directly by `msmtp` from its root-only
configuration file rather than through an external `passwordeval` helper.

The SMTP log path was also aligned with the path already permitted by the
installed AppArmor profile.

After the change, direct SMTP delivery returned:

```text
smtpstatus=250
exitcode=EX_OK
```

Both direct `msmtp` delivery and the `mail` command used by the reporting
scripts were successfully validated.

---

## Security Considerations

The public repository must never contain:

- SMTP passwords
- application passwords
- email credentials
- API keys
- private IP addressing
- production notification addresses
- authentication tokens

Secrets remain only on the server with restrictive filesystem permissions.

The monitoring scripts should also avoid including credentials or sensitive
configuration content inside generated reports.

---

## Operational Verification

Useful checks include:

```bash
# Inspect scheduled monitoring jobs
grep -R "health" /etc/cron.d/

# Check recent reports
find /var/log/health-reports -maxdepth 1 -type f | sort

# Verify Borg result
systemctl show borg-backup-full.service -p Result

# Check unhealthy containers
docker ps --filter health=unhealthy

# Inspect failed systemd services
systemctl --failed

# Verify RAID
cat /proc/mdstat

# Check storage utilization
df -h
```

A successful monitoring system should provide concise routine reporting while
reserving immediate notifications for conditions that genuinely require
attention.

---

## Final Monitoring Model

The resulting design is intentionally simple:

```text
                         Server
                           |
          +----------------+----------------+
          |                |                |
    every 10 min      every Sunday      every month
          |                |                |
          v                v                v
   Immediate Alert    Weekly Summary    Monthly Review
          |                |                |
          +----------------+----------------+
                           |
                           v
                    Administrator
```

This provides continuous lightweight monitoring without creating unnecessary
notification noise.
