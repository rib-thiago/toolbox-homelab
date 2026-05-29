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

ALBUM_DIR="${1:-}"
EXPECTED_MBID="${2:-}"
EXPECTED_ARTIST="${3:-}"
EXPECTED_ALBUM="${4:-}"
EXPECTED_MATCH_MIN="${5:-80}"
EXPECTED_DISTANCE_MAX="${6:-}"

ALBUM_NAME="$(basename "$ALBUM_DIR")"
SAFE_ALBUM_NAME="$(printf '%s' "$ALBUM_NAME" | tr ' /[]()' '_______' | tr -cd '[:alnum:]_.-')"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"

REPORT="$REPORT_DIR/music_staging_beets_mbid_dry_run_validation_${SAFE_ALBUM_NAME}_report_$STAMP.txt"
TSV="$RAW_DIR/music_staging_beets_mbid_dry_run_validation_${SAFE_ALBUM_NAME}_$STAMP.tsv"

ERROR_PATTERNS='error loading plugin|PluginImportError|ModuleNotFoundError|Could not import plugin|No module named|Traceback'

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

check_contains_fixed() {
  local check_id="$1"
  local category="$2"
  local file="$3"
  local expected="$4"
  local message="$5"

  if grep -F "$expected" "$file" >/dev/null 2>&1; then
    write_check "$check_id" "$category" "$file" "OK" "$message" "$expected"
  else
    write_check "$check_id" "$category" "$file" "FAIL" "$message not found" "$expected"
  fi
}

check_contains_regex() {
  local check_id="$1"
  local category="$2"
  local file="$3"
  local pattern="$4"
  local message="$5"

  if grep -Ei "$pattern" "$file" >/dev/null 2>&1; then
    write_check "$check_id" "$category" "$file" "OK" "$message" "$pattern"
  else
    write_check "$check_id" "$category" "$file" "FAIL" "$message not found" "$pattern"
  fi
}

check_not_contains_regex() {
  local check_id="$1"
  local category="$2"
  local file="$3"
  local pattern="$4"
  local message="$5"
  local found

  found="$(grep -Ei "$pattern" "$file" 2>/dev/null || true)"

  if [ -z "$found" ]; then
    write_check "$check_id" "$category" "$file" "OK" "$message" ""
  else
    write_check "$check_id" "$category" "$file" "FAIL" "$message failed" "$found"
  fi
}

append_file_excerpt() {
  local title="$1"
  local file="$2"

  {
    printf '\n'
    printf '## %s\n' "$title"
    printf '\n'
    printf '%s\n' '```text'
    if [ -n "$file" ] && [ -f "$file" ]; then
      cat "$file"
    else
      printf 'missing: %s\n' "$file"
    fi
    printf '%s\n' '```'
  } >> "$REPORT"
}

usage() {
  cat <<'EOF'
Usage:
  validate-music-staging-beets-mbid-dry-run.sh <album_dir> <mbid> <expected_artist> <expected_album> [expected_match_min] [expected_distance_max]

Safety:
  Validation only. Does not run Beets, write tags, copy files, move files or modify staging/library.
EOF
}

validate_args() {
  if [ -z "$ALBUM_DIR" ] || [ -z "$EXPECTED_MBID" ] || [ -z "$EXPECTED_ARTIST" ] || [ -z "$EXPECTED_ALBUM" ]; then
    usage >&2
    fail "Missing required arguments."
  fi
}

extract_match_percent() {
  local file="$1"

  grep -Eo 'Match \([^)]*%[^)]*\)' "$file" 2>/dev/null \
    | tail -n 1 \
    | sed -E 's/.*\(([0-9]+([.][0-9]+)?)%.*/\1/' \
    || true
}

validate_match_threshold() {
  local file="$1"
  local match_percent

  match_percent="$(extract_match_percent "$file")"

  if [ -z "$match_percent" ]; then
    write_check "MATCH-THRESHOLD" "match" "$file" "WARN" "match percentage not detected" ""
    return 0
  fi

  if awk -v got="$match_percent" -v min="$EXPECTED_MATCH_MIN" 'BEGIN { exit (got >= min) ? 0 : 1 }'; then
    write_check "MATCH-THRESHOLD" "match" "$file" "OK" "match percentage meets threshold" "got=$match_percent min=$EXPECTED_MATCH_MIN"
  else
    write_check "MATCH-THRESHOLD" "match" "$file" "FAIL" "match percentage below threshold" "got=$match_percent min=$EXPECTED_MATCH_MIN"
  fi
}

main() {
  local latest_apply_tsv
  local latest_apply_report
  local latest_live_log
  local latest_debug_log
  local evidence_log
  local fail_count
  local warn_count

  require_lib_contract
  validate_args

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting Beets MBID dry-run validation."

  latest_apply_tsv="$(latest_file "$RAW_DIR" "music_staging_beets_mbid_dry_run_apply_${SAFE_ALBUM_NAME}_*.tsv")"
  latest_apply_report="$(latest_file "$REPORT_DIR" "music_staging_beets_mbid_dry_run_apply_${SAFE_ALBUM_NAME}_report_*.txt")"
  latest_live_log="$(latest_file "$REPORT_DIR" "beets_mbid_dry_run_${SAFE_ALBUM_NAME}_live_*.log")"
  latest_debug_log="$(latest_file "$REPORT_DIR" "beets_mbid_debug_${SAFE_ALBUM_NAME}_*.log")"

  if [ -n "$latest_debug_log" ] && [ -f "$latest_debug_log" ]; then
    evidence_log="$latest_debug_log"
  else
    evidence_log="$latest_live_log"
  fi

  tsv_row \
    "check_id" \
    "category" \
    "target" \
    "status" \
    "message" \
    "details" > "$TSV"

  {
    printf '%s\n' '# Music Staging Beets MBID Dry-run Validation'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Album directory: %s\n' "$ALBUM_DIR"
    printf 'Album name: %s\n' "$ALBUM_NAME"
    printf 'Expected MBID: %s\n' "$EXPECTED_MBID"
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf 'Expected match min: %s\n' "$EXPECTED_MATCH_MIN"
    printf 'Expected distance max: %s\n' "$EXPECTED_DISTANCE_MAX"
    printf 'Latest apply TSV: %s\n' "$latest_apply_tsv"
    printf 'Latest apply report: %s\n' "$latest_apply_report"
    printf 'Latest live log: %s\n' "$latest_live_log"
    printf 'Latest debug log: %s\n' "$latest_debug_log"
    printf 'Evidence log used: %s\n' "$evidence_log"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: validation only. This script does not run Beets, write tags, copy files, move files or modify staging/library.'
    printf '\n'
  } > "$REPORT"

  if [ -n "$latest_apply_tsv" ] && [ -f "$latest_apply_tsv" ]; then
    write_check "FILE-001" "file" "$latest_apply_tsv" "OK" "latest apply TSV exists" ""
  else
    write_check "FILE-001" "file" "$latest_apply_tsv" "WARN" "latest apply TSV missing" ""
  fi

  if [ -n "$latest_apply_report" ] && [ -f "$latest_apply_report" ]; then
    write_check "FILE-002" "file" "$latest_apply_report" "OK" "latest apply report exists" ""
  else
    write_check "FILE-002" "file" "$latest_apply_report" "WARN" "latest apply report missing" ""
  fi

  if [ -n "$evidence_log" ] && [ -f "$evidence_log" ]; then
    write_check "FILE-003" "file" "$evidence_log" "OK" "evidence log exists" ""
  else
    write_check "FILE-003" "file" "$evidence_log" "FAIL" "evidence log missing" ""
  fi

  if [ -n "$evidence_log" ] && [ -f "$evidence_log" ]; then
    check_not_contains_regex "RUN-001" "runtime" "$evidence_log" "$ERROR_PATTERNS" "no plugin/runtime errors detected"
    check_contains_fixed "PLG-001" "plugins" "$evidence_log" "Loading plugins: chroma, musicbrainz" "chroma and musicbrainz loaded"
    check_contains_fixed "MB-001" "musicbrainz" "$evidence_log" "$EXPECTED_MBID" "expected MBID detected"
    check_contains_fixed "MB-002" "musicbrainz" "$evidence_log" "$EXPECTED_ARTIST" "expected artist detected"
    check_contains_fixed "MB-003" "musicbrainz" "$evidence_log" "$EXPECTED_ALBUM" "expected album detected"
    check_contains_regex "MB-004" "musicbrainz" "$evidence_log" "Evaluating [0-9]+ candidates" "candidate evaluation happened"
    check_contains_regex "MATCH-001" "match" "$evidence_log" "Match .*%" "match percentage found"
    validate_match_threshold "$evidence_log"
  fi

  append_file_excerpt "Evidence log" "$evidence_log"
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
      printf '%s\n' 'Interpretation: MBID dry-run validation failed.'
    else
      printf '%s\n' 'Interpretation: MBID dry-run validation passed for the supplied album/artist/MBID parameters.'
    fi
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    log "Beets MBID dry-run validation completed with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  log "Beets MBID dry-run validation passed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
