# Ubuntu Patch Management and Reboot Readiness

**Audit:** 2026-11-17. **Scope:** read-only review of the production Linux host.

## Verified State

| Check | Result |
| --- | --- |
| OS | Ubuntu 26.04.1 LTS |
| Kernel | 7.0.0-42-generic |
| unattended-upgrades | 2.12ubuntu9 installed; service enabled and active |
| apt-daily.timer | Enabled and active |
| apt-daily-upgrade.timer | Enabled and active |
| Reboot requested | Yes (`/run/reboot-required` present) |
| Upgradable packages | 12, from cached APT indexes |

On November 17, `apt-daily.timer` last ran at 03:17 WET, and `apt-daily-upgrade.timer` last ran at 06:58 WET. Their next scheduled runs were November 17 at 15:53 and November 18 at 06:03, respectively.

**Limitations:** The cached package count was not refreshed. We did not inspect the reboot-requesting packages, confirm which updates are security-related, or verify every unattended installation. Enabled services do not prove the host is fully patched.

## Read-Only Checks

```bash
uname -r
test -f /run/reboot-required && echo REBOOT_REQUIRED
systemctl list-timers --all --no-pager | grep -E "apt-daily|apt-daily-upgrade"
```

## Safe Maintenance Plan

1. Inspect `/run/reboot-required.pkgs` if present and review update history.
2. Confirm current backups, RAID state and critical Docker workloads.
3. Review pending changes and schedule an approved maintenance window.
4. Apply approved updates and reboot only when operationally safe.
5. After reboot, validate networking, disks, Docker services, Jellyfin and GPU access.
6. Document results and unresolved risks.

**No updates, restarts or configuration changes were performed for this audit.**
