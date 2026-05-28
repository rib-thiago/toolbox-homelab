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

BEETS_SANDBOX_ROOT="$SHARED_DIR/beets/media-staging"
BEETS_CONFIG="$BEETS_SANDBOX_ROOT/config.yaml"
BEETS_LIBRARY="$BEETS_SANDBOX_ROOT/library.blb"
BEETS_STAGING_LIBRARY="$BEETS_SANDBOX_ROOT/library"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"

REPORT="$REPORT_DIR/music_staging_beets_sandbox_validation_report_$STAMP.txt"
TSV="$RAW_DIR/music_staging_beets_sandbox_validation_$STAMP.tsv"

ERROR_PATTERNS='error loading plugin|PluginImportError|ModuleNotFoundError|Could not import plugin|No module named'

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

validate_command_exists() {
  local check_id="$1"
  local command_name="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    write_check "$check_id" "command" "$command_name" "OK" "command found" "$(command -v "$command_name")"
  else
    write_check "$check_id" "command" "$command_name" "FAIL" "command missing" ""
  fi
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

validate_dir_exists() {
  local check_id="$1"
  local dir="$2"

  if [ -d "$dir" ]; then
    write_check "$check_id" "directory" "$dir" "OK" "directory exists" ""
  else
    write_check "$check_id" "directory" "$dir" "FAIL" "directory missing" ""
  fi
}

validate_config_contains() {
  local check_id="$1"
  local pattern="$2"
  local label="$3"

  if grep -q "$pattern" "$BEETS_CONFIG" 2>/dev/null; then
    write_check "$check_id" "config" "$BEETS_CONFIG" "OK" "$label found" "$pattern"
  else
    write_check "$check_id" "config" "$BEETS_CONFIG" "FAIL" "$label missing" "$pattern"
  fi
}

run_capture() {
  local title="$1"
  local output_file="$2"
  shift 2

  append_section "$title"

  {
    printf '%s\n' '```text'
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
  } >> "$REPORT"

  if "$@" > "$output_file" 2>&1; then
    cat "$output_file" >> "$REPORT"
    printf '\n%s\n' '[OK]' >> "$REPORT"
    printf '%s\n' '```' >> "$REPORT"
    return 0
  fi

  cat "$output_file" >> "$REPORT"
  printf '\n%s\n' '[FAIL]' >> "$REPORT"
  printf '%s\n' '```' >> "$REPORT"
  return 1
}

validate_output_has_no_plugin_errors() {
  local check_id="$1"
  local output_file="$2"
  local label="$3"
  local found

  found="$(grep -Ei "$ERROR_PATTERNS" "$output_file" || true)"

  if [ -z "$found" ]; then
    write_check "$check_id" "plugin" "$label" "OK" "no plugin import/load errors detected" ""
  else
    write_check "$check_id" "plugin" "$label" "FAIL" "plugin import/load errors detected" "$found"
  fi
}

validate_output_contains() {
  local check_id="$1"
  local output_file="$2"
  local pattern="$3"
  local label="$4"

  if grep -q "$pattern" "$output_file"; then
    write_check "$check_id" "output" "$label" "OK" "expected output found" "$pattern"
  else
    write_check "$check_id" "output" "$label" "FAIL" "expected output missing" "$pattern"
  fi
}

main() {
  local config_output
  local version_output
  local fail_count
  local warn_count

  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting music staging Beets sandbox validation."

  tsv_row \
    "check_id" \
    "category" \
    "target" \
    "status" \
    "message" \
    "details" > "$TSV"

  {
    printf '%s\n' '# Music Staging Beets Sandbox Validation'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Beets sandbox root: %s\n' "$BEETS_SANDBOX_ROOT"
    printf 'Beets config: %s\n' "$BEETS_CONFIG"
    printf 'Beets library DB: %s\n' "$BEETS_LIBRARY"
    printf 'Beets sandbox library dir: %s\n' "$BEETS_STAGING_LIBRARY"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: validation only. This script does not run import, write tags, move files or modify staging/library.'
    printf '\n'
  } > "$REPORT"

  validate_command_exists "CMD-001" "beet"
  validate_command_exists "CMD-002" "fpcalc"
  validate_file_exists "FILE-001" "$BEETS_CONFIG"
  validate_dir_exists "DIR-001" "$BEETS_SANDBOX_ROOT"
  validate_dir_exists "DIR-002" "$BEETS_STAGING_LIBRARY"

  validate_config_contains "CFG-001" "^directory: $BEETS_STAGING_LIBRARY$" "directory setting"
  validate_config_contains "CFG-002" "^library: $BEETS_LIBRARY$" "library setting"
  validate_config_contains "CFG-003" "^  copy: no$" "copy disabled"
  validate_config_contains "CFG-004" "^  write: no$" "write disabled"
  validate_config_contains "CFG-005" "^  move: no$" "move disabled"
  validate_config_contains "CFG-006" "^plugins: chroma$" "chroma plugin"

  config_output="$(mktemp)"
  version_output="$(mktemp)"

  if run_capture "BEETSDIR beet config" "$config_output" env "BEETSDIR=$BEETS_SANDBOX_ROOT" beet config; then
    write_check "RUN-001" "command-run" "BEETSDIR beet config" "OK" "command returned success" ""
  else
    write_check "RUN-001" "command-run" "BEETSDIR beet config" "FAIL" "command returned failure" ""
  fi

  validate_output_has_no_plugin_errors "PLG-001" "$config_output" "BEETSDIR beet config"
  validate_output_contains "OUT-001" "$config_output" "plugins: chroma" "beet config chroma plugin"
  validate_output_contains "OUT-002" "$config_output" "copy: no" "beet config copy disabled"
  validate_output_contains "OUT-003" "$config_output" "write: no" "beet config write disabled"
  validate_output_contains "OUT-004" "$config_output" "move: no" "beet config move disabled"

  if run_capture "BEETSDIR beet version" "$version_output" env "BEETSDIR=$BEETS_SANDBOX_ROOT" beet version; then
    write_check "RUN-002" "command-run" "BEETSDIR beet version" "OK" "command returned success" ""
  else
    write_check "RUN-002" "command-run" "BEETSDIR beet version" "FAIL" "command returned failure" ""
  fi

  validate_output_has_no_plugin_errors "PLG-002" "$version_output" "BEETSDIR beet version"
  validate_output_contains "OUT-005" "$version_output" "plugins: chroma" "beet version chroma plugin"

  rm -f "$config_output" "$version_output"

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
      printf '%s\n' 'Interpretation: validation failed. Do not run beet import until fixed.'
    else
      printf '%s\n' 'Interpretation: validation passed. Beets sandbox is ready for controlled dry-run matching.'
    fi
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    log "Music staging Beets sandbox validation completed with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  log "Music staging Beets sandbox validation passed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
