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

REPORT_DIR="$SHARED_DIR/reports/system/shell"
RAW_DIR="$SHARED_DIR/library-db/raw/system/shell"

REPORT="$REPORT_DIR/shell_artifact_helpers_validation_report_$STAMP.txt"
TSV="$RAW_DIR/shell_artifact_helpers_validation_$STAMP.tsv"

ALIAS_DIR="$HOME/.bash_aliases.d"
ARTIFACTS_FILE="$ALIAS_DIR/85-toolbox-artifacts.sh"
JOBS_FILE="$ALIAS_DIR/95-jobs.sh"
DEV_FILE="$ALIAS_DIR/50-dev.sh"
BASH_ALIASES="$HOME/.bash_aliases"

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

append_section() {
  local title="$1"

  {
    printf '\n'
    printf '## %s\n' "$title"
    printf '\n'
  } >> "$REPORT"
}

block_text() {
  local file="$1"
  local marker="$2"

  awk -v marker="$marker" '
    $0 == "# >>> " marker {flag=1}
    flag {print}
    $0 == "# <<< " marker {flag=0}
  ' "$file"
}

validate_file_exists() {
  local check_id="$1"
  local file="$2"

  if [ -f "$file" ]; then
    write_check "$check_id" "file" "$file" "OK" "file exists" ""
  else
    write_check "$check_id" "file" "$file" "FAIL" "file missing" ""
  fi
}

validate_bash_syntax() {
  local check_id="$1"
  local file="$2"

  if [ ! -f "$file" ]; then
    write_check "$check_id" "syntax" "$file" "FAIL" "file missing" ""
    return 1
  fi

  if bash -n "$file" >/dev/null 2>&1; then
    write_check "$check_id" "syntax" "$file" "OK" "bash -n passed" ""
  else
    write_check "$check_id" "syntax" "$file" "FAIL" "bash -n failed" ""
  fi
}

validate_marker_once() {
  local check_id="$1"
  local file="$2"
  local marker="$3"
  local count

  if [ ! -f "$file" ]; then
    write_check "$check_id" "marker" "$file" "FAIL" "file missing" "$marker"
    return 1
  fi

  count="$(grep -c "^# >>> $marker$" "$file" || true)"

  if [ "$count" -eq 1 ]; then
    write_check "$check_id" "marker" "$file" "OK" "marker appears exactly once" "$marker"
  elif [ "$count" -eq 0 ]; then
    write_check "$check_id" "marker" "$file" "FAIL" "marker missing" "$marker"
  else
    write_check "$check_id" "marker" "$file" "FAIL" "marker duplicated" "$marker count=$count"
  fi
}

validate_block_contains() {
  local check_id="$1"
  local file="$2"
  local marker="$3"
  local pattern="$4"
  local message="$5"

  if block_text "$file" "$marker" | grep -q "$pattern"; then
    write_check "$check_id" "block" "$file" "OK" "$message" "$pattern"
  else
    write_check "$check_id" "block" "$file" "FAIL" "$message not found" "$pattern"
  fi
}

validate_block_absent() {
  local check_id="$1"
  local file="$2"
  local marker="$3"
  local pattern="$4"
  local message="$5"

  if block_text "$file" "$marker" | grep -q "$pattern"; then
    write_check "$check_id" "block-policy" "$file" "FAIL" "$message present" "$pattern"
  else
    write_check "$check_id" "block-policy" "$file" "OK" "$message absent" "$pattern"
  fi
}

validate_no_optional_aliases() {
  local check_id="$1"
  local file="$2"
  local marker="$3"
  local found

  found="$(
    block_text "$file" "$marker" \
      | grep -E "^[[:space:]]*alias[[:space:]]+(msr|mst|pyr|pyt|shr|sht)=" || true
  )"

  if [ -z "$found" ]; then
    write_check "$check_id" "policy" "$file" "OK" "no temporary/domain-specific aliases in helper block" ""
  else
    write_check "$check_id" "policy" "$file" "FAIL" "temporary/domain-specific aliases found" "$found"
  fi
}

capture_types() {
  local type_file="$1"

  bash -ic 'type latest-file tsvless tsvlatest rptless rptlatest tblatest nflog tblive mkxcheck' > "$type_file" 2>&1
}

validate_type_contains() {
  local check_id="$1"
  local type_file="$2"
  local helper="$3"

  if grep -Eq "^$helper (é uma função|is a function)" "$type_file"; then
    write_check "$check_id" "load" "$helper" "OK" "helper loaded as function" ""
  else
    write_check "$check_id" "load" "$helper" "FAIL" "helper not loaded as function" ""
  fi
}

validate_type_absent_in_helper() {
  local check_id="$1"
  local type_file="$2"
  local helper="$3"
  local pattern="$4"
  local message="$5"

  if awk -v helper="$helper" '
    $0 ~ "^" helper " " {flag=1}
    flag {print}
    flag && $0 == "}" {exit}
  ' "$type_file" | grep -q "$pattern"; then
    write_check "$check_id" "type-policy" "$helper" "FAIL" "$message present" "$pattern"
  else
    write_check "$check_id" "type-policy" "$helper" "OK" "$message absent" "$pattern"
  fi
}

run_latest_file_smoke() {
  local check_id="$1"
  local tmp_dir
  local old_file
  local new_file
  local result

  tmp_dir="$(mktemp -d)"
  old_file="$tmp_dir/old.txt"
  new_file="$tmp_dir/new.txt"

  printf '%s\n' "old" > "$old_file"
  sleep 1
  printf '%s\n' "new" > "$new_file"

  result="$(bash -ic "latest-file '$tmp_dir' '*.txt'" 2>/dev/null || true)"

  rm -rf "$tmp_dir"

  if [ "$result" = "$new_file" ]; then
    write_check "$check_id" "smoke" "latest-file" "OK" "returned newest file" "$result"
  else
    write_check "$check_id" "smoke" "latest-file" "FAIL" "did not return newest file" "result=$result expected=$new_file"
  fi
}

main() {
  local type_file
  local fail_count
  local warn_count

  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting shell artifact helpers validation."

  tsv_row \
    "check_id" \
    "category" \
    "target" \
    "status" \
    "message" \
    "details" > "$TSV"

  {
    printf '%s\n' '# Shell Artifact Helpers Validation'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: validation only. This script does not modify shell files.'
    printf '%s\n' 'Purpose: validate Toolbox shell artifact helpers after apply/repair.'
    printf '\n'
  } > "$REPORT"

  validate_file_exists "FILE-001" "$ARTIFACTS_FILE"
  validate_file_exists "FILE-002" "$JOBS_FILE"
  validate_file_exists "FILE-003" "$DEV_FILE"
  validate_file_exists "FILE-004" "$BASH_ALIASES"

  validate_bash_syntax "SYN-001" "$ARTIFACTS_FILE"
  validate_bash_syntax "SYN-002" "$JOBS_FILE"
  validate_bash_syntax "SYN-003" "$DEV_FILE"
  validate_bash_syntax "SYN-004" "$BASH_ALIASES"

  validate_marker_once "MRK-001" "$ARTIFACTS_FILE" "toolbox-artifact-helpers"
  validate_marker_once "MRK-002" "$JOBS_FILE" "toolbox-live-log-helpers"
  validate_marker_once "MRK-003" "$DEV_FILE" "toolbox-mkxcheck-helper"

  validate_no_optional_aliases "POL-001" "$ARTIFACTS_FILE" "toolbox-artifact-helpers"

  validate_block_contains "BLK-001" "$ARTIFACTS_FILE" "toolbox-artifact-helpers" "latest-file()" "latest-file definition"
  validate_block_contains "BLK-002" "$ARTIFACTS_FILE" "toolbox-artifact-helpers" "tsvless()" "tsvless definition"
  validate_block_contains "BLK-003" "$ARTIFACTS_FILE" "toolbox-artifact-helpers" "rptless()" "rptless definition"
  validate_block_contains "BLK-004" "$ARTIFACTS_FILE" "toolbox-artifact-helpers" "tblatest()" "tblatest definition"

  validate_block_contains "BLK-005" "$JOBS_FILE" "toolbox-live-log-helpers" "nflog()" "nflog definition"
  validate_block_contains "BLK-006" "$JOBS_FILE" "toolbox-live-log-helpers" "tblive()" "tblive definition"
  validate_block_contains "BLK-007" "$JOBS_FILE" "toolbox-live-log-helpers" "command mkdir -p" "command mkdir usage"
  validate_block_contains "BLK-008" "$JOBS_FILE" "toolbox-live-log-helpers" "command tail -f" "command tail usage"

  validate_block_contains "BLK-009" "$DEV_FILE" "toolbox-mkxcheck-helper" "mkxcheck()" "mkxcheck definition"
  validate_block_contains "BLK-010" "$DEV_FILE" "toolbox-mkxcheck-helper" "eval \"mkx" "semantic mkx alias preservation"
  validate_block_contains "BLK-011" "$DEV_FILE" "toolbox-mkxcheck-helper" "eval \"bashcheck" "semantic bashcheck alias preservation"

  validate_block_absent "ABS-001" "$JOBS_FILE" "toolbox-live-log-helpers" "mkdir -pv -p" "mkdir alias expansion artifact"
  validate_block_absent "ABS-002" "$DEV_FILE" "toolbox-mkxcheck-helper" "chmod +x" "mkx alias expansion artifact"

  type_file="$(mktemp)"
  capture_types "$type_file" || true

  append_section "Interactive type output"

  {
    printf '%s\n' '```text'
    cat "$type_file"
    printf '%s\n' '```'
  } >> "$REPORT"

  validate_type_contains "LOAD-001" "$type_file" "latest-file"
  validate_type_contains "LOAD-002" "$type_file" "tsvless"
  validate_type_contains "LOAD-003" "$type_file" "tsvlatest"
  validate_type_contains "LOAD-004" "$type_file" "rptless"
  validate_type_contains "LOAD-005" "$type_file" "rptlatest"
  validate_type_contains "LOAD-006" "$type_file" "tblatest"
  validate_type_contains "LOAD-007" "$type_file" "nflog"
  validate_type_contains "LOAD-008" "$type_file" "tblive"
  validate_type_contains "LOAD-009" "$type_file" "mkxcheck"

  validate_type_absent_in_helper "TYP-001" "$type_file" "nflog" "mkdir -pv -p" "mkdir alias expansion artifact"
  validate_type_absent_in_helper "TYP-002" "$type_file" "tblive" "mkdir -pv -p" "mkdir alias expansion artifact"
  validate_type_absent_in_helper "TYP-003" "$type_file" "mkxcheck" "chmod +x" "mkx alias expansion artifact"

  run_latest_file_smoke "SMK-001"

  rm -f "$type_file"

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$TSV")"
  warn_count="$(awk -F '\t' 'NR > 1 && $4 == "WARN" { c++ } END { print c+0 }' "$TSV")"

  {
    printf '\n'
    printf '%s\n' '## Summary'
    printf '\n'
    printf 'Failures: %s\n' "$fail_count"
    printf 'Warnings: %s\n' "$warn_count"
    printf '\n'
    if [ "$fail_count" -gt 0 ]; then
      printf '%s\n' 'Interpretation: validation failed. Review TSV/report before committing.'
    else
      printf '%s\n' 'Interpretation: validation passed. This shell helper mini-front can proceed to Git review.'
    fi
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    log "Shell artifact helpers validation completed with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  log "Shell artifact helpers validation passed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
