#!/usr/bin/env bash
set -u

APP_DIR="/srv/toolbox/app"
LIB_DIR="$APP_DIR/scripts/lib"

source "$LIB_DIR/logging.sh"
source "$LIB_DIR/timestamps.sh"
source "$LIB_DIR/tsv.sh"
source "$LIB_DIR/paths.sh"

STAMP="$(toolbox_timestamp)"
SHARED_DIR="$(toolbox_shared_dir)"

REPORT_DIR="$SHARED_DIR/reports/system/storage"
RAW_DIR="$SHARED_DIR/library-db/raw/system/storage"

REPORT="$REPORT_DIR/storage_pressure_ata_health_diagnosis_report_$STAMP.txt"
TSV="$RAW_DIR/storage_pressure_ata_health_diagnosis_$STAMP.tsv"

ROOT_DEVICE="${1:-/dev/sda}"

require_function() {
  local fn="$1"

  if ! declare -F "$fn" >/dev/null 2>&1; then
    printf '%s\n' "[ERRO] Required function not found: $fn" >&2
    exit 1
  fi
}

require_lib_contract() {
  require_function log
  require_function fail
  require_function toolbox_timestamp
  require_function toolbox_now
  require_function toolbox_shared_dir
  require_function tsv_row
}

write_check() {
  local check_id="$1"
  local category="$2"
  local target="$3"
  local status="$4"
  local message="$5"
  local details="$6"

  tsv_row "$check_id" "$category" "$target" "$status" "$message" "$details" >> "$TSV"
}

append_command() {
  local title="$1"
  shift

  {
    printf '\n'
    printf '## %s\n' "$title"
    printf '\n'
    printf '%s\n' '```text'
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
  } >> "$REPORT"

  if "$@" >> "$REPORT" 2>&1; then
    printf '\n%s\n' '[OK]' >> "$REPORT"
    printf '%s\n' '```' >> "$REPORT"
    return 0
  fi

  printf '\n%s\n' '[WARN/FAIL]' >> "$REPORT"
  printf '%s\n' '```' >> "$REPORT"
  return 1
}

append_shell_block() {
  local title="$1"
  local command_text="$2"

  {
    printf '\n'
    printf '## %s\n' "$title"
    printf '\n'
    printf '%s\n' '```text'
    printf '$ %s\n\n' "$command_text"
  } >> "$REPORT"

  set +e
  bash -c "$command_text" >> "$REPORT" 2>&1
  local status="$?"
  set -e

  {
    printf '\n'
    if [ "$status" -eq 0 ]; then
      printf '%s\n' '[OK]'
    else
      printf '[WARN/FAIL exit=%s]\n' "$status"
    fi
    printf '%s\n' '```'
  } >> "$REPORT"

  return 0
}

record_root_usage() {
  local usage_percent
  local avail

  usage_percent="$(df -P / | awk 'NR == 2 { gsub("%","",$5); print $5 }')"
  avail="$(df -hP / | awk 'NR == 2 { print $4 }')"

  if [ -z "$usage_percent" ]; then
    write_check "ROOT-USE" "capacity" "/" "WARN" "could not determine root usage" ""
    return 0
  fi

  if [ "$usage_percent" -ge 95 ]; then
    write_check "ROOT-USE" "capacity" "/" "WARN" "root filesystem usage is critical" "usage=${usage_percent}% avail=$avail"
  elif [ "$usage_percent" -ge 90 ]; then
    write_check "ROOT-USE" "capacity" "/" "WARN" "root filesystem usage is high" "usage=${usage_percent}% avail=$avail"
  else
    write_check "ROOT-USE" "capacity" "/" "OK" "root filesystem usage acceptable" "usage=${usage_percent}% avail=$avail"
  fi
}

record_dmesg_ata_status() {
  local recent_errors

  recent_errors="$(sudo dmesg -T 2>/dev/null | grep -Ei 'ata1|sda|i/o|error|reset|ext4' | tail -n 300 | grep -Ei 'WRITE FPDMA|ATA bus error|I/O error|Buffer I/O|EXT4-fs error|hard resetting link' || true)"

  if [ -n "$recent_errors" ]; then
    write_check "DMESG-ATA" "kernel" "dmesg" "WARN" "storage-related error/reset patterns found" "$(printf '%s' "$recent_errors" | head -n 5 | tr '\n' ' ')"
  else
    write_check "DMESG-ATA" "kernel" "dmesg" "OK" "no critical ATA/I/O/EXT4 error pattern found in filtered dmesg tail" ""
  fi
}

record_smart_status() {
  local smart_output
  local health
  local realloc
  local uncorrect
  local timeout
  local crc
  local selftest

  smart_output="$(sudo smartctl -a "$ROOT_DEVICE" 2>/dev/null || true)"

  if [ -z "$smart_output" ]; then
    write_check "SMART-000" "smart" "$ROOT_DEVICE" "WARN" "smartctl returned no output" ""
    return 0
  fi

  health="$(printf '%s\n' "$smart_output" | awk -F: '/SMART overall-health self-assessment test result/ { gsub(/^ +/,"",$2); print $2; exit }')"
  realloc="$(printf '%s\n' "$smart_output" | awk '$1 == "5" { print $10; exit }')"
  uncorrect="$(printf '%s\n' "$smart_output" | awk '$1 == "187" { print $10; exit }')"
  timeout="$(printf '%s\n' "$smart_output" | awk '$1 == "188" { print $10; exit }')"
  crc="$(printf '%s\n' "$smart_output" | awk '$1 == "199" { print $10; exit }')"
  selftest="$(printf '%s\n' "$smart_output" | awk '/Short offline/ { print; exit }')"

  if printf '%s' "$health" | grep -q "PASSED"; then
    write_check "SMART-001" "smart" "$ROOT_DEVICE" "OK" "SMART overall health passed" "$health"
  else
    write_check "SMART-001" "smart" "$ROOT_DEVICE" "WARN" "SMART overall health not clearly passed" "$health"
  fi

  if [ "${realloc:-0}" = "0" ]; then
    write_check "SMART-005" "smart" "$ROOT_DEVICE" "OK" "no reallocated sectors" "Reallocated_Sector_Ct=${realloc:-unknown}"
  else
    write_check "SMART-005" "smart" "$ROOT_DEVICE" "WARN" "reallocated sectors present" "Reallocated_Sector_Ct=${realloc:-unknown}"
  fi

  if [ "${uncorrect:-0}" = "0" ]; then
    write_check "SMART-187" "smart" "$ROOT_DEVICE" "OK" "no reported uncorrectable errors" "Reported_Uncorrect=${uncorrect:-unknown}"
  else
    write_check "SMART-187" "smart" "$ROOT_DEVICE" "WARN" "reported uncorrectable errors present" "Reported_Uncorrect=${uncorrect:-unknown}"
  fi

  if [ "${timeout:-0}" = "0" ]; then
    write_check "SMART-188" "smart" "$ROOT_DEVICE" "OK" "no command timeouts" "Command_Timeout=${timeout:-unknown}"
  else
    write_check "SMART-188" "smart" "$ROOT_DEVICE" "WARN" "command timeouts present" "Command_Timeout=${timeout:-unknown}"
  fi

  if [ "${crc:-0}" = "0" ]; then
    write_check "SMART-199" "smart" "$ROOT_DEVICE" "OK" "no SATA CRC errors reported by SMART" "SATA_CRC_Error=${crc:-unknown}"
  else
    write_check "SMART-199" "smart" "$ROOT_DEVICE" "WARN" "SATA CRC errors present" "SATA_CRC_Error=${crc:-unknown}"
  fi

  if printf '%s' "$selftest" | grep -q "Completed without error"; then
    write_check "SMART-SELFTEST" "smart" "$ROOT_DEVICE" "OK" "latest short self-test completed without error" "$selftest"
  else
    write_check "SMART-SELFTEST" "smart" "$ROOT_DEVICE" "WARN" "latest short self-test not clearly successful" "$selftest"
  fi
}

main() {
  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting storage pressure and ATA health diagnosis."

  tsv_row \
    "check_id" \
    "category" \
    "target" \
    "status" \
    "message" \
    "details" > "$TSV"

  {
    printf '%s\n' '# Storage Pressure and ATA Health Diagnosis'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Root/primary device checked: %s\n' "$ROOT_DEVICE"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: diagnosis only. This script does not prune Docker, vacuum journals, run fstrim, write tags, move files or modify storage state intentionally.'
    printf '\n'
  } > "$REPORT"

  record_root_usage
  record_dmesg_ata_status
  record_smart_status

  append_command "lsblk inventory" lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINTS,FSTYPE
  append_command "df filesystem usage" df -hT
  append_command "root mount options" findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS /
  append_command "smartctl scan-open" sudo smartctl --scan-open
  append_command "SMART primary device" sudo smartctl -a "$ROOT_DEVICE"

  append_shell_block "Filtered dmesg storage tail" "sudo dmesg -T | grep -Ei 'ata1|sda|i/o|error|reset|ext4' | tail -n 300"

  append_shell_block "Top-level /srv usage" "sudo du -xhd1 /srv 2>/dev/null | sort -h"
  append_shell_block "/srv/media usage" "sudo du -xhd1 /srv/media 2>/dev/null | sort -h"
  append_shell_block "/srv/media/music-staging usage" "sudo du -xhd1 /srv/media/music-staging 2>/dev/null | sort -h"
  append_shell_block "/srv/media/music usage" "sudo du -xhd1 /srv/media/music 2>/dev/null | sort -h"

  append_shell_block "/var usage" "sudo du -xhd1 /var 2>/dev/null | sort -h"
  append_shell_block "/var/lib usage" "sudo du -xhd1 /var/lib 2>/dev/null | sort -h"
  append_shell_block "/var/log usage" "sudo du -xhd1 /var/log 2>/dev/null | sort -h"
  append_shell_block "/home usage" "sudo du -xhd1 /home 2>/dev/null | sort -h"

  append_command "docker system df" docker system df
  append_command "docker system df verbose" docker system df -v
  append_command "journal disk usage" journalctl --disk-usage

  append_shell_block "Large log files over 100M" "sudo find /var/log -type f -size +100M -printf '%s\t%p\n' 2>/dev/null | sort -n"

  {
    printf '\n'
    printf '%s\n' '## TSV summary'
    printf '\n'
    printf '%s\n' '```text'
    column -t -s $'\t' "$TSV" 2>/dev/null || cat "$TSV"
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Interpretation guide'
    printf '\n'
    printf '%s\n' '- WARN on root usage means free space should be recovered before heavy writes.'
    printf '%s\n' '- WARN on dmesg ATA/I/O/EXT4 means do not proceed with media writes until investigated.'
    printf '%s\n' '- SMART PASSED with no reallocated/uncorrectable/timeout/CRC errors lowers suspicion of immediate SSD failure, but does not erase a real ATA incident.'
    printf '%s\n' '- This report is diagnostic evidence for deciding whether to clean space, inspect hardware, or pause media workflows.'
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  log "Storage pressure and ATA health diagnosis completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
