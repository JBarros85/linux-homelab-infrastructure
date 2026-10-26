# SSH Protection with Fail2ban

This homelab uses multiple security controls together to reduce the risk of
unauthorized SSH access.

The protection model combines:

- source network restrictions;
- disabled root login;
- limited SSH authentication attempts;
- public-key authentication support;
- Fail2ban monitoring;
- temporary bans after repeated authentication failures.

No single mechanism is treated as sufficient by itself.

---

## Audited State

At the time of the audit:

| Control | State |
| --- | --- |
| Fail2ban service | Active and enabled |
| Fail2ban jails | `sshd`, `sshd-ddos` |
| SSH root login | Disabled |
| SSH public-key authentication | Enabled |
| SSH password authentication | Enabled |
| SSH maximum authentication attempts | 3 |
| SSH source access | Restricted to approved LAN/VPN networks |

The real internal network ranges are intentionally omitted from this public
repository.

---

## Fail2ban Service

Fail2ban runs as a native systemd service:

```bash
systemctl status fail2ban
```

The service can also be checked with:

```bash
systemctl is-active fail2ban
systemctl is-enabled fail2ban
```

The audited system reported the service as both active and enabled.

---

## Active Jails

The server currently uses two SSH-related jails:

```text
sshd
sshd-ddos
```

They can be listed with:

```bash
sudo fail2ban-client status
```

---

## Standard SSH Jail

The primary `sshd` jail uses the following effective policy:

```text
Maximum retries: 3
Detection window: 600 seconds
Ban duration: 3600 seconds
```

This means three matching authentication failures within ten minutes can cause
the source address to be blocked for one hour.

The jail monitors SSH events through the systemd journal.

Example verification:

```bash
sudo fail2ban-client status sshd
```

---

## Extended SSH Abuse Jail

A second jail provides a longer response to repeated SSH abuse:

```text
Maximum retries: 5
Detection window: 600 seconds
Ban duration: 86400 seconds
```

Five matching events within ten minutes can therefore result in a 24-hour ban.

During the audit, this jail was monitoring SSH authentication data from the
system authentication log.

Example:

```bash
sudo fail2ban-client status sshd-ddos
```

---

## SSH Configuration

The effective SSH configuration includes:

```text
Port 22
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication yes
MaxAuthTries 3
```

Root login over SSH is therefore disabled.

The SSH daemon also restricts the permitted user to specific trusted source
networks.

A sanitized representation is:

```text
AllowUsers <user>@192.168.10.0/24
AllowUsers <user>@10.10.0.0/24
AllowUsers <user>@127.0.0.1
```

The real production addresses are not published.

---

## Defense in Depth

The resulting access path can be represented as:

```text
Connection attempt
       |
       v
Approved source network?
       |
   +---+---+
   |       |
  no      yes
   |       |
 blocked   v
        SSH authentication
              |
              v
        Root login allowed?
              |
             no
              |
              v
        User authentication
              |
              v
         Fail2ban observes
        repeated failures
              |
              v
        Temporary IP ban
```

Fail2ban is therefore an additional control rather than the primary perimeter.

---

## Why Source Restrictions Matter

Fail2ban reacts after suspicious authentication activity is observed.

Restricting SSH access to approved LAN or VPN networks reduces exposure before
authentication is even attempted.

This provides two different controls:

1. network access policy limits where SSH connections may originate;
2. Fail2ban reacts to repeated authentication failures from sources that can
   reach the SSH service.

---

## Current Ban Counters

During the audited snapshot, both SSH jails reported:

```text
Currently failed: 0
Currently banned: 0
Total banned: 0
```

This does not indicate a configuration problem.

The SSH service is already restricted to approved source networks, significantly
reducing the traffic that can reach the authentication layer.

Runtime counters should also be interpreted as an operational snapshot rather
than long-term security history.

---

## Checking Jail Parameters

Effective jail values can be inspected directly:

```bash
sudo fail2ban-client get sshd maxretry
sudo fail2ban-client get sshd findtime
sudo fail2ban-client get sshd bantime

sudo fail2ban-client get sshd-ddos maxretry
sudo fail2ban-client get sshd-ddos findtime
sudo fail2ban-client get sshd-ddos bantime
```

This is preferable to assuming that configuration-file defaults represent the
currently loaded policy.

---

## Inspecting SSH Policy

The effective SSH configuration can be queried without relying only on the
contents of `sshd_config`:

```bash
sudo sshd -T | grep -Ei \
'^(port|permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries|allowusers)'
```

Using `sshd -T` is useful because it shows the configuration interpreted by the
SSH daemon.

---

## Safe Fail2ban Inspection

A normal status check can include banned IP addresses:

```bash
sudo fail2ban-client status sshd
```

When collecting output for public documentation, IP addresses should be
redacted.

Example:

```bash
sudo fail2ban-client status sshd |
sed -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/<IP>/g'
```

Real attacker addresses and internal infrastructure addresses should not be
published unnecessarily.

---

## Password Authentication

Password authentication is currently enabled.

This is partially mitigated by:

- source network restrictions;
- disabled root login;
- `MaxAuthTries 3`;
- Fail2ban monitoring.

A possible future hardening step is to move administrative SSH access to
key-only authentication after confirming that all required clients have
reliable key-based access.

This should be performed deliberately to avoid accidental administrative
lockout.

---

## Operational Checks

Useful commands include:

```bash
systemctl status fail2ban --no-pager
sudo fail2ban-client status

sudo fail2ban-client status sshd
sudo fail2ban-client status sshd-ddos

sudo sshd -T

journalctl -u fail2ban --since today --no-pager
```

---

## Security Notes

Public documentation should never expose:

- real private network ranges;
- VPN addressing;
- currently banned IP addresses;
- usernames when unnecessary;
- SSH private keys;
- passwords or authentication tokens.

Configuration examples in this repository therefore use sanitized values.

---

## Result

The SSH security design uses several independent controls:

```text
Network restriction
        +
Root login disabled
        +
Authentication attempt limits
        +
Fail2ban
        =
Layered SSH protection
```

This approach provides stronger protection than relying on a changed SSH port or
a single security mechanism.
