#!/usr/bin/env bash

# Homelab Health Check
# Read-only diagnostic utility for Linux homelab environments.
#
# Exit status:
#   0 = healthy
#   1 = warnings detected
#   2 = failures detected
#
# Optional environment variables:
#   DISK_WARN_PCT=85
#   DISK_CRIT_PCT=95
#   MEM_WARN_PCT=85
#   MEM_CRIT_PCT=95
#   BORG_REPO=/path/to/repository
#   BORG_TIMEOUT_SECONDS=20
#   NO_COLOR=1

set -uo pipefail

readonly SCRIPT_NAME="homelab-health-check"
readonly VERSION="1.0.0"

DISK_WARN_PCT="${DISK_WARN_PCT:-85}"
DISK_CRIT_PCT="${DISK_CRIT_PCT:-95}"
MEM_WARN_PCT="${MEM_WARN_PCT:-85}"
MEM_CRIT_PCT="${MEM_CRIT_PCT:-95}"
BORG_REPO="${BORG_REPO:-}"
BORG_TIMEOUT_SECONDS="${BORG_TIMEOUT_SECONDS:-20}"

WARNINGS=0
FAILURES=0
SKIPS=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
    C_RESET=$'\033[0m'
else
    C_GREEN=""
    C_YELLOW=""
    C_RED=""
    C_BLUE=""
    C_CYAN=""
    C_RESET=""
fi

status_line() {
    local color="$1"
    local label="$2"
    shift 2

    printf '%b%-5s%b %s\n' \
        "$color" \
        "$label" \
        "$C_RESET" \
        "$*"
}

pass() {
    status_line "$C_GREEN" "PASS" "$*"
}

warn() {
    WARNINGS=$((WARNINGS + 1))
    status_line "$C_YELLOW" "WARN" "$*"
}

fail() {
    FAILURES=$((FAILURES + 1))
    status_line "$C_RED" "FAIL" "$*"
}

skip() {
    SKIPS=$((SKIPS + 1))
    status_line "$C_BLUE" "SKIP" "$*"
}

info() {
    status_line "$C_CYAN" "INFO" "$*"
}

section() {
    printf '\n%b== %s ==%b\n' "$C_CYAN" "$*" "$C_RESET"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_integer() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

run_privileged() {
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
        return $?
    fi

    if command_exists sudo && sudo -n true >/dev/null 2>&1; then
        sudo -n "$@"
        return $?
    fi

    return 77
}

usage() {
    cat <<USAGE
${SCRIPT_NAME} ${VERSION}

Usage:
  ./scripts/homelab-health-check.sh
  ./scripts/homelab-health-check.sh --help
  ./scripts/homelab-health-check.sh --version

Purpose:
  Performs read-only checks of common homelab infrastructure components.

Checks:
  - Host uptime
  - Docker daemon and containers
  - Failed systemd units
  - Filesystem capacity
  - Memory utilisation
  - Linux software RAID
  - WireGuard
  - UFW firewall
  - Borg backup repository

Configuration examples:

  DISK_WARN_PCT=80 ./scripts/homelab-health-check.sh

  BORG_REPO=/path/to/repository \
  ./scripts/homelab-health-check.sh

Exit status:
  0  No warnings or failures
  1  One or more warnings
  2  One or more failures

The script does not restart services, modify firewall rules,
change system configuration or write to the monitored services.
USAGE
}

validate_configuration() {
    local variable
    local value

    for variable in \
        DISK_WARN_PCT \
        DISK_CRIT_PCT \
        MEM_WARN_PCT \
        MEM_CRIT_PCT \
        BORG_TIMEOUT_SECONDS
    do
        value="${!variable}"

        if ! is_integer "$value"; then
            fail "Invalid configuration: ${variable} must be an integer."
            return 1
        fi
    done

    if (( DISK_WARN_PCT >= DISK_CRIT_PCT )); then
        fail "DISK_WARN_PCT must be lower than DISK_CRIT_PCT."
        return 1
    fi

    if (( MEM_WARN_PCT >= MEM_CRIT_PCT )); then
        fail "MEM_WARN_PCT must be lower than MEM_CRIT_PCT."
        return 1
    fi

    return 0
}

check_uptime() {
    section "Host"

    local host
    local uptime_text

    host="$(hostname -f 2>/dev/null || hostname)"
    uptime_text="$(uptime -p 2>/dev/null || true)"

    info "Host: ${host}"

    if [[ -n "$uptime_text" ]]; then
        pass "Uptime: ${uptime_text}"
    else
        warn "Unable to determine host uptime."
    fi
}

check_docker() {
    section "Docker"

    if ! command_exists docker; then
        skip "Docker CLI is not installed."
        return
    fi

    if ! docker info >/dev/null 2>&1; then
        warn "Docker daemon is unavailable or current user lacks permission."
        return
    fi

    local total
    local running
    local problematic
    local exited

    total="$(docker ps -a -q 2>/dev/null | wc -l | tr -d ' ')"
    running="$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')"

    pass "Docker daemon reachable — ${running}/${total} containers running."

    problematic="$(
        docker ps \
            --format '{{.Names}}\t{{.Status}}' 2>/dev/null |
        grep -Ei 'unhealthy|restarting|dead' || true
    )"

    if [[ -n "$problematic" ]]; then
        warn "Containers require attention:"
        printf '%s\n' "$problematic" | sed 's/^/      /'
    else
        pass "No running containers report unhealthy/restarting/dead state."
    fi

    exited="$(
        docker ps -a \
            --filter status=exited \
            --format '{{.Names}}' 2>/dev/null |
        wc -l |
        tr -d ' '
    )"

    if (( exited > 0 )); then
        info "${exited} container(s) are currently stopped."
    fi
}

check_systemd() {
    section "systemd"

    if ! command_exists systemctl; then
        skip "systemctl is not available."
        return
    fi

    local failed_units

    failed_units="$(
        systemctl --failed --no-legend --plain 2>/dev/null || true
    )"

    if [[ -z "$failed_units" ]]; then
        pass "No failed systemd units."
    else
        fail "Failed systemd units detected:"
        printf '%s\n' "$failed_units" | sed 's/^/      /'
    fi
}

check_filesystems() {
    section "Filesystems"

    local disk_issues=0
    local checked=0
    local filesystem
    local blocks
    local used
    local available
    local percentage
    local mountpoint
    local value

    while read -r \
        filesystem \
        blocks \
        used \
        available \
        percentage \
        mountpoint
    do
        [[ -z "${filesystem:-}" ]] && continue

        value="${percentage%\%}"

        if ! is_integer "$value"; then
            continue
        fi

        checked=$((checked + 1))

        if (( value >= DISK_CRIT_PCT )); then
            fail "${mountpoint}: ${value}% used (${filesystem})"
            disk_issues=$((disk_issues + 1))
        elif (( value >= DISK_WARN_PCT )); then
            warn "${mountpoint}: ${value}% used (${filesystem})"
            disk_issues=$((disk_issues + 1))
        fi

    done < <(
        df -P \
            -x tmpfs \
            -x devtmpfs \
            -x squashfs \
            -x overlay 2>/dev/null |
        awk 'NR > 1'
    )

    if (( checked == 0 )); then
        warn "No filesystems could be evaluated."
    elif (( disk_issues == 0 )); then
        pass "Filesystem utilisation below ${DISK_WARN_PCT}% warning threshold."
    fi
}

check_memory() {
    section "Memory"

    if [[ ! -r /proc/meminfo ]]; then
        skip "/proc/meminfo is unavailable."
        return
    fi

    local total_kb
    local available_kb
    local used_pct

    total_kb="$(
        awk '/^MemTotal:/ {print $2}' /proc/meminfo
    )"

    available_kb="$(
        awk '/^MemAvailable:/ {print $2}' /proc/meminfo
    )"

    if ! is_integer "${total_kb:-}" ||
       ! is_integer "${available_kb:-}" ||
       (( total_kb == 0 )); then
        warn "Unable to calculate memory utilisation."
        return
    fi

    used_pct=$(( (total_kb - available_kb) * 100 / total_kb ))

    if (( used_pct >= MEM_CRIT_PCT )); then
        fail "Memory utilisation is ${used_pct}%."
    elif (( used_pct >= MEM_WARN_PCT )); then
        warn "Memory utilisation is ${used_pct}%."
    else
        pass "Memory utilisation is ${used_pct}%."
    fi
}

check_raid() {
    section "Linux Software RAID"

    if [[ ! -r /proc/mdstat ]]; then
        skip "/proc/mdstat is unavailable."
        return
    fi

    local arrays
    local states

    arrays="$(
        grep -E '^md[[:alnum:]_-]+[[:space:]]*:' /proc/mdstat || true
    )"

    if [[ -z "$arrays" ]]; then
        skip "No active Linux MD RAID arrays detected."
        return
    fi

    states="$(
        grep -Eo '\[[U_]+\]' /proc/mdstat || true
    )"

    if grep -q '_' <<< "$states"; then
        fail "Degraded RAID member detected."

        printf '%s\n' "$arrays" |
            sed 's/^/      /'

        printf '%s\n' "$states" |
            sed 's/^/      State: /'
    else
        pass "Active RAID arrays report all expected members online."

        printf '%s\n' "$arrays" |
            sed 's/^/      /'
    fi
}

check_wireguard() {
    section "WireGuard"

    if ! command_exists wg; then
        skip "WireGuard tools are not installed."
        return
    fi

    local output
    local result
    local interfaces
    local peer_count

    output="$(run_privileged wg show 2>/dev/null)"
    result=$?

    if (( result == 77 )); then
        skip "WireGuard requires privileged access; non-interactive sudo unavailable."
        return
    fi

    if (( result != 0 )); then
        warn "Unable to query WireGuard state."
        return
    fi

    if [[ -z "$output" ]]; then
        skip "No active WireGuard interfaces detected."
        return
    fi

    interfaces="$(
        awk '/^interface:/ {print $2}' <<< "$output" |
        paste -sd ',' -
    )"

    peer_count="$(
        grep -c '^peer:' <<< "$output" || true
    )"

    pass "Active interface(s): ${interfaces}; peer(s): ${peer_count}."
}

check_ufw() {
    section "UFW Firewall"

    if ! command_exists ufw; then
        skip "UFW is not installed."
        return
    fi

    local output
    local result

    output="$(run_privileged ufw status 2>/dev/null)"
    result=$?

    if (( result == 77 )); then
        skip "UFW requires privileged access; non-interactive sudo unavailable."
        return
    fi

    if (( result != 0 )); then
        warn "Unable to query UFW status."
        return
    fi

    if grep -q '^Status: active' <<< "$output"; then
        pass "UFW firewall is active."
    else
        warn "UFW firewall is not active."
    fi
}

check_borg() {
    section "Borg Backup"

    if ! command_exists borg; then
        skip "Borg Backup is not installed."
        return
    fi

    if [[ -z "$BORG_REPO" ]]; then
        skip "BORG_REPO is not configured."
        info "Set BORG_REPO to enable repository validation."
        return
    fi

    local output
    local result
    local borg_command

    borg_command=(
        borg
        list
        --last
        1
        --format
        '{archive}{NL}'
        "$BORG_REPO"
    )

    if command_exists timeout; then
        output="$(
            timeout \
                "${BORG_TIMEOUT_SECONDS}s" \
                "${borg_command[@]}" 2>/dev/null
        )"

        result=$?
    else
        output="$("${borg_command[@]}" 2>/dev/null)"
        result=$?
    fi

    if (( result == 0 )) && [[ -n "$output" ]]; then
        pass "Repository accessible. Latest archive: $(head -n 1 <<< "$output")"
    elif (( result == 124 )); then
        warn "Borg repository check timed out after ${BORG_TIMEOUT_SECONDS}s."
    else
        warn "Borg repository could not be validated non-interactively."
    fi
}

print_summary() {
    section "Summary"

    printf 'Warnings : %d\n' "$WARNINGS"
    printf 'Failures : %d\n' "$FAILURES"
    printf 'Skipped  : %d\n' "$SKIPS"

    if (( FAILURES > 0 )); then
        status_line "$C_RED" "FAIL" \
            "Health check completed with critical findings."
    elif (( WARNINGS > 0 )); then
        status_line "$C_YELLOW" "WARN" \
            "Health check completed with warnings."
    else
        status_line "$C_GREEN" "PASS" \
            "Health check completed successfully."
    fi
}

main() {
    case "${1:-}" in
        --help|-h)
            usage
            return 0
            ;;
        --version|-V)
            printf '%s %s\n' "$SCRIPT_NAME" "$VERSION"
            return 0
            ;;
        "")
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$1" >&2
            usage >&2
            return 2
            ;;
    esac

    printf '%b%s %s%b\n' \
        "$C_CYAN" \
        "$SCRIPT_NAME" \
        "$VERSION" \
        "$C_RESET"

    printf 'Read-only infrastructure health assessment\n'

    if ! validate_configuration; then
        print_summary
        return 2
    fi

    check_uptime
    check_docker
    check_systemd
    check_filesystems
    check_memory
    check_raid
    check_wireguard
    check_ufw
    check_borg

    print_summary

    if (( FAILURES > 0 )); then
        return 2
    fi

    if (( WARNINGS > 0 )); then
        return 1
    fi

    return 0
}

main "$@"
