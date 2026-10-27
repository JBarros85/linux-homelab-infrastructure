# Automated RAID and SMART Monitoring

The homelab uses native Linux monitoring tools to continuously inspect both the
software RAID array and the physical storage devices.

The monitoring design combines:

- `mdadm` monitoring for Linux MD RAID;
- a systemd timer for recurring RAID checks;
- `smartd` for continuous SMART monitoring;
- explicit temperature policies for primary storage disks;
- automatic discovery of additional SMART-capable devices;
- email notifications for relevant SMART events.

---

## Monitoring Architecture

```text
Linux MD RAID
    |
    v
mdmonitor-oneshot.timer
    |
    v
mdadm --monitor --oneshot --scan


Physical disks / NVMe
    |
    v
smartmontools.service
    |
    v
smartd
    |
    +--> SMART health
    +--> disk attributes
    +--> temperature thresholds
    +--> email notifications
```

---

## RAID Monitoring

The system uses the native `mdadm` monitoring service.

Relevant configuration:

```text
AUTOCHECK=true
AUTOSCAN=true
START_DAEMON=true
DAEMON_OPTIONS="--syslog"
VERBOSE=false
```

The recurring check is handled by:

```text
mdmonitor-oneshot.timer
```

The timer is enabled and configured with:

```ini
[Timer]
OnCalendar=daily
RandomizedDelaySec=24h
Persistent=true
```

This means RAID monitoring is performed daily, with a randomized execution time.

`Persistent=true` also allows a missed execution to be handled after the system
becomes available again.

The associated service runs:

```bash
mdadm --monitor --oneshot --scan
```

---

## RAID Verification

Useful commands:

```bash
systemctl status mdmonitor-oneshot.timer
systemctl status mdmonitor-oneshot.service

systemctl list-timers --all | grep mdmonitor

cat /proc/mdstat
sudo mdadm --detail /dev/md0
```

A successful oneshot execution should finish with:

```text
status=0/SUCCESS
```

---

## SMART Monitoring

Disk health monitoring is provided by:

```text
smartmontools.service
```

The service runs the `smartd` daemon continuously.

The audited system currently monitors:

```text
4 ATA/SATA devices
1 NVMe device
```

---

## Explicit Disk Policies

Primary storage disks use explicit monitoring rules.

Sanitized example:

```text
/dev/sda -a -n standby -W 4,50,55 -m <EMAIL>
/dev/sdc -a -n standby -W 4,50,55 -m <EMAIL>
/dev/sdb -a -n standby -W 4,50,55 -m <EMAIL>
```

The `-a` option enables the standard SMART checks.

`-n standby` avoids unnecessarily waking a disk that is sleeping.

The temperature policy:

```text
-W 4,50,55
```

defines:

```text
Temperature difference reporting: 4 °C
Informational threshold:          50 °C
Critical threshold:               55 °C
```

Email notifications are enabled for relevant SMART events.

The real notification address is intentionally not stored in this repository.

---

## Automatic Device Discovery

After the explicit disk rules, the configuration includes:

```text
DEVICESCAN -d removable -n standby -m <EMAIL>
```

This allows `smartd` to discover additional SMART-capable devices automatically.

In the audited system this also detected:

```text
one additional SATA device
one NVMe device
```

---

## Configuration Ordering

The order of entries in `smartd.conf` is important.

Explicit device rules must appear before `DEVICESCAN`.

Correct structure:

```text
/dev/sda ...
/dev/sdb ...
/dev/sdc ...
DEVICESCAN ...
```

During an audit, the explicit device rules were found below `DEVICESCAN`.

They were moved above it so that the intended per-device temperature policies
are applied before automatic device discovery occurs.

After the correction, `smartd` reported the explicitly configured devices first
and ignored their duplicate discovery during `DEVICESCAN`.

---

## Configuration Validation

Before restarting the service, the configuration can be safely tested with:

```bash
sudo smartd -q onecheck -c /etc/smartd.conf
```

A successful validation ends with:

```text
All devices successfully checked once.
smartd is exiting (exit status 0)
```

This provides a useful validation step before applying changes to the running
daemon.

---

## Applying Configuration Changes

After successful validation:

```bash
sudo systemctl restart smartmontools
```

Then verify:

```bash
systemctl status smartmontools --no-pager
```

The service should report:

```text
Active: active (running)
```

---

## Monitoring Logs

SMART activity can be inspected through the systemd journal:

```bash
sudo journalctl -u smartmontools --since today
```

RAID monitoring can be inspected with:

```bash
journalctl -u mdmonitor-oneshot.service
```

The SMART journal records events such as:

- device discovery;
- SMART capability detection;
- attribute changes;
- temperature changes;
- self-test results;
- daemon startup.

---

## SMART State Files

`smartd` maintains device state under:

```text
/var/lib/smartmontools/
```

These files allow the daemon to track changes in SMART attributes between
checks.

They should not normally be manually edited.

---

## Email Notifications

SMART monitoring is configured to notify the administrator when relevant
conditions are detected.

The notification chain is kept outside the public repository.

Sensitive information such as:

- email addresses;
- credentials;
- SMTP configuration;
- device serial numbers;
- WWNs;

must never be included in public documentation.

---

## Existing Health Reporting

SMART and RAID monitoring also feed the broader homelab health monitoring
strategy.

The server separately maintains:

- immediate health alerts;
- weekly health summaries;
- monthly infrastructure summaries.

This document focuses specifically on the native storage monitoring layer.

---

## Operational Checks

Useful commands:

```bash
# RAID
cat /proc/mdstat
sudo mdadm --detail /dev/md0

# RAID monitoring timer
systemctl status mdmonitor-oneshot.timer
journalctl -u mdmonitor-oneshot.service

# SMART daemon
systemctl status smartmontools

# Validate smartd configuration
sudo smartd -q onecheck -c /etc/smartd.conf

# SMART information for a device
sudo smartctl -a /dev/sdX
```

---

## Result

The storage monitoring model provides two complementary layers:

```text
RAID array monitoring
        +
Physical disk SMART monitoring
        +
Temperature thresholds
        +
Automated notifications
        =
Continuous storage health monitoring
```

RAID health alone is not enough to determine physical disk health, and SMART
monitoring alone does not describe the state of the RAID array.

Using both provides better visibility into storage reliability.
