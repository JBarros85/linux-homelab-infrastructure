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
readonly VERSION="1.1.0"

DISK_WARN_PCT="${DISK_WARN_PCT:-85}"
DISK_CRIT_PCT="${DISK_CRIT_PCT:-95}"
MEM_WARN_PCT="${MEM_WARN_PCT:-85}"
MEM_CRIT_PCT="${MEM_CRIT_PCT:-95}"
BORG_REPO="${BORG_REPO:-}"
BORG_TIMEOUT_SECONDS="${BORG_TIMEOUT_SECONDS:-20}"

OUTPUT_MODE="text"

WARNINGS=0
FAILURES=0
SKIPS=0

declare -a RESULTS=()

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

json_escape() {
    local value="$1"

    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}

    printf '%s' "$value"
}

record_result() {
    local status="$1"
    local name="$2"
    local message="$3"
    local color=""

    case "$status" in
        PASS)
            color="$C_GREEN"
            ;;
        WARN)
            WARNINGS=$((WARNINGS + 1))
            color="$C_YELLOW"
            ;;
        FAIL)
            FAILURES=$((FAILURES + 1))
            color="$C_RED"
            ;;
        SKIP)
            SKIPS=$((SKIPS + 1))
            color="$C_BLUE"
            ;;
        INFO)
            color="$C_CYAN"
            ;;
    esac

    if [[ "$OUTPUT_MODE" == "json" ]]; then
        RESULTS+=(
            "{\"name\":\"$(json_escape "$name")\",\"status\":\"$(json_escape "$status")\",\"message\":\"$(json_escape "$message")\"}"
        )
    else
        printf '%b%-5s%b %-18s %s\n' \
            "$color" \
            "$status" \
            "$C_RESET" \
            "$name" \
            "$message"
    fi
}

section() {
    if [[ "$OUTPUT_MODE" == "text" ]]; then
        printf '\n%b== %s ==%b\n' "$C_CYAN" "$1" "$C_RESET"
    fi
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
  ./scripts/homelab-health-check.sh --json
  ./scripts/homelab-health-check.sh --help
  ./scripts/homelab-health-check.sh --version

Options:
  --json       Return machine-readable JSON output
  --help       Show this help message
  --version    Show script version

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

Exit status:
  0  Healthy
  1  Warning detected
  2  Failure detected

This utility is read-only and does not restart services,
modify firewall rules or change system configuration.
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
            record_result \
                "FAIL" \
                "Configuration" \
                "${variable} must be an integer."
            return 1
        fi
    done

    if (( DISK_WARN_PCT >= DISK_CRIT_PCT )); then
        record_result \
            "FAIL" \
            "Configuration" \
            "DISK_WARN_PCT must be lower than DISK_CRIT_PCT."
        return 1
    fi

    if (( MEM_WARN_PCT >= MEM_CRIT_PCT )); then
        record_result \
            "FAIL" \
            "Configuration" \
            "MEM_WARN_PCT must be lower than MEM_CRIT_PCT."
        return 1
    fi

    return 0
}

check_uptime() {
    section "Host"

    local uptime_text

    uptime_text="$(uptime -p 2>/dev/null || true)"

    if [[ -n "$uptime_text" ]]; then
        record_result "PASS" "Host uptime" "$uptime_text"
    else
        record_result "WARN" "Host uptime" "Unable to determine uptime."
    fi
}

check_docker() {
    section "Docker"

    if ! command_exists docker; then
        record_result "SKIP" "Docker" "Docker CLI is not installed."
        return
    fi

    if ! docker info >/dev/null 2>&1; then
        record_result \
            "WARN" \
            "Docker" \
            "Docker daemon unavailable or current user lacks permission."
        return
    fi

    local total
    local running
    local problematic
    local stopped

    total="$(docker ps -a -q 2>/dev/null | wc -l | tr -d ' ')"
    running="$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')"

    record_result \
        "PASS" \
        "Docker" \
        "${running}/${total} containers running."

    problematic="$(
        docker ps \
            --format '{{.Names}} {{.Status}}' 2>/dev/null |
        grep -Ei 'unhealthy|restarting|dead' || true
    )"

    if [[ -n "$problematic" ]]; then
        record_result \
            "WARN" \
            "Docker health" \
            "$problematic"
    else
        record_result \
            "PASS" \
            "Docker health" \
            "No unhealthy, restarting or dead containers."
    fi

    stopped="$(
        docker ps -a \
            --filter status=exited \
            --format '{{.Names}}' 2>/dev/null |
        wc -l |
        tr -d ' '
    )"

    record_result \
        "INFO" \
        "Docker stopped" \
        "${stopped} container(s) currently stopped."
}

check_systemd() {
    section "systemd"

    if ! command_exists systemctl; then
        record_result "SKIP" "systemd" "systemctl is not available."
        return
    fi

    local failed_units

    failed_units="$(
        systemctl --failed --no-legend --plain 2>/dev/null |
        awk '{print $1}' |
        paste -sd ',' - || true
    )"

    if [[ -z "$failed_units" ]]; then
        record_result "PASS" "systemd" "No failed units."
    else
        record_result \
            "FAIL" \
            "systemd" \
            "Failed units: ${failed_units}"
    fi
}

check_filesystems() {
    section "Filesystems"

    local filesystem
    local percentage
    local mountpoint
    local value
    local checked=0
    local issues=0

    while read -r filesystem percentage mountpoint; do
        [[ -z "${filesystem:-}" ]] && continue

        value="${percentage%\%}"

        if ! is_integer "$value"; then
            continue
        fi

        checked=$((checked + 1))

        if (( value >= DISK_CRIT_PCT )); then
            record_result \
                "FAIL" \
                "Filesystem" \
                "${mountpoint}: ${value}% used (${filesystem})"
            issues=$((issues + 1))
        elif (( value >= DISK_WARN_PCT )); then
            record_result \
                "WARN" \
                "Filesystem" \
                "${mountpoint}: ${value}% used (${filesystem})"
            issues=$((issues + 1))
        fi
    done < <(
        df -P \
            -x tmpfs \
            -x devtmpfs \
            -x squashfs \
            -x overlay 2>/dev/null |
        awk 'NR > 1 {print $1, $5, $6}'
    )

    if (( checked == 0 )); then
        record_result \
            "WARN" \
            "Filesystem" \
            "No filesystems could be evaluated."
    elif (( issues == 0 )); then
        record_result \
            "PASS" \
            "Filesystem" \
            "All filesystems below ${DISK_WARN_PCT}% usage."
    fi
}

check_memory() {
    section "Memory"

    if [[ ! -r /proc/meminfo ]]; then
        record_result \
            "SKIP" \
            "Memory" \
            "/proc/meminfo is unavailable."
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

        record_result \
            "WARN" \
            "Memory" \
            "Unable to calculate utilisation."
        return
    fi

    used_pct=$(( (total_kb - available_kb) * 100 / total_kb ))

    if (( used_pct >= MEM_CRIT_PCT )); then
        record_result \
            "FAIL" \
            "Memory" \
            "${used_pct}% utilised."
    elif (( used_pct >= MEM_WARN_PCT )); then
        record_result \
            "WARN" \
            "Memory" \
            "${used_pct}% utilised."
    else
        record_result \
            "PASS" \
            "Memory" \
            "${used_pct}% utilised."
    fi
}

check_raid() {
    section "Linux Software RAID"

    if [[ ! -r /proc/mdstat ]]; then
        record_result \
            "SKIP" \
            "RAID" \
            "/proc/mdstat is unavailable."
        return
    fi

    local arrays
    local states

    arrays="$(
        grep -E '^md[[:alnum:]_-]+[[:space:]]*:' /proc/mdstat || true
    )"

    if [[ -z "$arrays" ]]; then
        record_result \
            "SKIP" \
            "RAID" \
            "No active Linux MD arrays detected."
        return
    fi

    states="$(
        grep -Eo '\[[U_]+\]' /proc/mdstat || true
    )"

    if grep -q '_' <<< "$states"; then
        record_result \
            "FAIL" \
            "RAID" \
            "Degraded RAID member detected."
    else
        record_result \
            "PASS" \
            "RAID" \
            "All expected RAID members online."
    fi
}

check_wireguard() {
    section "WireGuard"

    if ! command_exists wg; then
        record_result \
            "SKIP" \
            "WireGuard" \
            "WireGuard tools are not installed."
        return
    fi

    local output
    local result
    local interfaces
    local peer_count

    output="$(run_privileged wg show 2>/dev/null)"
    result=$?

    if (( result == 77 )); then
        record_result \
            "SKIP" \
            "WireGuard" \
            "Privileged access unavailable."
        return
    fi

    if (( result != 0 )); then
        record_result \
            "WARN" \
            "WireGuard" \
            "Unable to query state."
        return
    fi

    if [[ -z "$output" ]]; then
        record_result \
            "SKIP" \
            "WireGuard" \
            "No active interfaces detected."
        return
    fi

    interfaces="$(
        awk '/^interface:/ {print $2}' <<< "$output" |
        paste -sd ',' -
    )"

    peer_count="$(
        grep -c '^peer:' <<< "$output" || true
    )"

    record_result \
        "PASS" \
        "WireGuard" \
        "Interfaces: ${interfaces}; peers: ${peer_count}."
}

check_ufw() {
    section "UFW Firewall"

    if ! command_exists ufw; then
        record_result \
            "SKIP" \
            "UFW" \
            "UFW is not installed."
        return
    fi

    local output
    local result

    output="$(run_privileged ufw status 2>/dev/null)"
    result=$?

    if (( result == 77 )); then
        record_result \
            "SKIP" \
            "UFW" \
            "Privileged access unavailable."
        return
    fi

    if (( result != 0 )); then
        record_result \
            "WARN" \
            "UFW" \
            "Unable to query firewall status."
        return
    fi

    if grep -q '^Status: active' <<< "$output"; then
        record_result \
            "PASS" \
            "UFW" \
            "Firewall is active."
    else
        record_result \
            "WARN" \
            "UFW" \
            "Firewall is not active."
    fi
}

check_borg() {
    section "Borg Backup"

    if ! command_exists borg; then
        record_result \
            "SKIP" \
            "Borg" \
            "Borg Backup is not installed."
        return
    fi

    if [[ -z "$BORG_REPO" ]]; then
        record_result \
            "SKIP" \
            "Borg" \
            "BORG_REPO is not configured."
        return
    fi

    local output
    local result
    local -a borg_command

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
        record_result \
            "PASS" \
            "Borg" \
            "Latest archive: $(head -n 1 <<< "$output")"
    elif (( result == 124 )); then
        record_result \
            "WARN" \
            "Borg" \
            "Repository check timed out."
    else
        record_result \
            "WARN" \
            "Borg" \
            "Repository could not be validated."
    fi
}

overall_status() {
    if (( FAILURES > 0 )); then
        printf 'critical'
    elif (( WARNINGS > 0 )); then
        printf 'warning'
    else
        printf 'healthy'
    fi
}

print_text_summary() {
    section "Summary"

    printf 'Warnings : %d\n' "$WARNINGS"
    printf 'Failures : %d\n' "$FAILURES"
    printf 'Skipped  : %d\n' "$SKIPS"

    case "$(overall_status)" in
        critical)
            printf '%bFAIL%b  Health check completed with critical findings.\n' \
                "$C_RED" "$C_RESET"
            ;;
        warning)
            printf '%bWARN%b  Health check completed with warnings.\n' \
                "$C_YELLOW" "$C_RESET"
            ;;
        healthy)
            printf '%bPASS%b  Health check completed successfully.\n' \
                "$C_GREEN" "$C_RESET"
            ;;
    esac
}

print_json() {
    local timestamp
    local host
    local status
    local index

    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    host="$(hostname -f 2>/dev/null || hostname)"
    status="$(overall_status)"

    printf '{\n'
    printf '  "tool": "%s",\n' "$(json_escape "$SCRIPT_NAME")"
    printf '  "version": "%s",\n' "$(json_escape "$VERSION")"
    printf '  "timestamp": "%s",\n' "$(json_escape "$timestamp")"
    printf '  "host": "%s",\n' "$(json_escape "$host")"
    printf '  "status": "%s",\n' "$(json_escape "$status")"
    printf '  "summary": {\n'
    printf '    "warnings": %d,\n' "$WARNINGS"
    printf '    "failures": %d,\n' "$FAILURES"
    printf '    "skipped": %d\n' "$SKIPS"
    printf '  },\n'
    printf '  "checks": [\n'

    for index in "${!RESULTS[@]}"; do
        printf '    %s' "${RESULTS[$index]}"

        if (( index < ${#RESULTS[@]} - 1 )); then
            printf ','
        fi

        printf '\n'
    done

    printf '  ]\n'
    printf '}\n'
}

main() {
    case "${1:-}" in
        --json)
            OUTPUT_MODE="json"
            ;;
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

    if [[ "$OUTPUT_MODE" == "text" ]]; then
        printf '%b%s %s%b\n' \
            "$C_CYAN" \
            "$SCRIPT_NAME" \
            "$VERSION" \
            "$C_RESET"

        printf 'Read-only infrastructure health assessment\n'
    fi

    if ! validate_configuration; then
        if [[ "$OUTPUT_MODE" == "json" ]]; then
            print_json
        else
            print_text_summary
        fi
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

    if [[ "$OUTPUT_MODE" == "json" ]]; then
        print_json
    else
        print_text_summary
    fi

    if (( FAILURES > 0 )); then
        return 2
    fi

    if (( WARNINGS > 0 )); then
        return 1
    fi

    return 0
}

main "$@"
