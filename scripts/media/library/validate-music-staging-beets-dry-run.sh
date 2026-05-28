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

REPORT_DIR="$SHARED_DIR/reports/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"

REPORT="$REPORT_DIR/music_staging_beets_dry_run_validation_report_$STAMP.txt"
TSV="$RAW_DIR/music_staging_beets_dry_run_validation_$STAMP.tsv"

ERROR_PATTERNS='error loading plugin|PluginImportError|ModuleNotFoundError|Could not import plugin|No module named|Traceback'
NO_MATCH_PATTERNS='No matching release found|No matching release'
SKIP_PATTERNS='Skip|skip|\[S\]kip'

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

latest_file() {
  local dir="$1"
  local pattern="$2"

  find "$dir" -maxdepth 1 -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | head -n 1 \
    | cut -d' ' -f2-
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

validate_file_exists() {
  local check_id="$1"
  local file="$2"
  local label="$3"

  if [ -n "$file" ] && [ -f "$file" ]; then
    write_check "$check_id" "file" "$label" "OK" "file exists" "$file"
  else
    write_check "$check_id" "file" "$label" "FAIL" "file missing" "$file"
  fi
}

validate_no_runtime_errors() {
  local check_id="$1"
  local file="$2"
  local found

  found="$(grep -Ei "$ERROR_PATTERNS" "$file" 2>/dev/null || true)"

  if [ -z "$found" ]; then
    write_check "$check_id" "runtime" "$file" "OK" "no plugin/runtime errors detected" ""
  else
    write_check "$check_id" "runtime" "$file" "FAIL" "plugin/runtime errors detected" "$found"
  fi
}

validate_no_match_detected() {
  local check_id="$1"
  local file="$2"
  local found

  found="$(grep -Ei "$NO_MATCH_PATTERNS" "$file" 2>/dev/null || true)"

  if [ -n "$found" ]; then
    write_check "$check_id" "musicbrainz-result" "$file" "WARN" "no matching release found" "$found"
  else
    write_check "$check_id" "musicbrainz-result" "$file" "OK" "no no-match message detected" ""
  fi
}

validate_skip_detected() {
  local check_id="$1"
  local file="$2"
  local found

  found="$(grep -Ei "$SKIP_PATTERNS" "$file" 2>/dev/null || true)"

  if [ -n "$found" ]; then
    write_check "$check_id" "operator-choice" "$file" "OK" "skip option appears in log" "$found"
  else
    write_check "$check_id" "operator-choice" "$file" "WARN" "skip option not detected in log" ""
  fi
}

append_file_excerpt() {
  local title="$1"
  local file="$2"

  append_section "$title"

  {
    printf '%s\n' '```text'
    if [ -n "$file" ] && [ -f "$file" ]; then
      cat "$file"
    else
      printf 'missing: %s\n' "$file"
    fi
    printf '%s\n' '```'
  } >> "$REPORT"
}

main() {
  local latest_apply_tsv
  local latest_apply_report
  local latest_live_log
  local fail_count
  local warn_count

  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting Beets dry-run validation."

  latest_apply_tsv="$(latest_file "$RAW_DIR" 'music_staging_beets_dry_run_apply_*.tsv')"
  latest_apply_report="$(latest_file "$REPORT_DIR" 'music_staging_beets_dry_run_apply_report_*.txt')"
  latest_live_log="$(latest_file "$REPORT_DIR" 'beets_dry_run_*_live_*.log')"

  tsv_row \
    "check_id" \
    "category" \
    "target" \
    "status" \
    "message" \
    "details" > "$TSV"

  {
    printf '%s\n' '# Music Staging Beets Dry-run Validation'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Latest apply TSV: %s\n' "$latest_apply_tsv"
    printf 'Latest apply report: %s\n' "$latest_apply_report"
    printf 'Latest live log: %s\n' "$latest_live_log"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: validation only. This script does not run beet import, write tags, copy files, move files or modify staging/library.'
    printf '\n'
  } > "$REPORT"

  validate_file_exists "FILE-001" "$latest_apply_tsv" "latest dry-run apply TSV"
  validate_file_exists "FILE-002" "$latest_apply_report" "latest dry-run apply report"
  validate_file_exists "FILE-003" "$latest_live_log" "latest dry-run live log"

  if [ -n "$latest_live_log" ] && [ -f "$latest_live_log" ]; then
    validate_no_runtime_errors "RUN-001" "$latest_live_log"
    validate_no_match_detected "MB-001" "$latest_live_log"
    validate_skip_detected "OP-001" "$latest_live_log"
  fi

  if [ -n "$latest_apply_tsv" ] && [ -f "$latest_apply_tsv" ]; then
    if awk -F '\t' 'NR > 1 && $4 == "FAIL" { found=1 } END { exit found ? 0 : 1 }' "$latest_apply_tsv"; then
      write_check "APP-001" "apply-result" "$latest_apply_tsv" "FAIL" "apply TSV contains FAIL" ""
    else
      write_check "APP-001" "apply-result" "$latest_apply_tsv" "OK" "apply TSV has no FAIL rows" ""
    fi
  fi

  append_file_excerpt "Latest live log" "$latest_live_log"
  append_file_excerpt "Latest apply TSV" "$latest_apply_tsv"

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
      printf '%s\n' 'Interpretation: dry-run validation failed. Review report before continuing.'
    elif [ "$warn_count" -gt 0 ]; then
      printf '%s\n' 'Interpretation: dry-run tooling completed, but MusicBrainz matching needs follow-up diagnosis.'
    else
      printf '%s\n' 'Interpretation: dry-run validation passed without warnings.'
    fi
    printf '\n'
    printf '%s\n' 'Recommended next action: diagnose local album tags/durations for Thembi before trying another import strategy.'
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    log "Beets dry-run validation completed with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  log "Beets dry-run validation completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
