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

APPLY_MODE="${1:-}"
ALBUM_DIR="${2:-}"
MBID="${3:-}"
EXPECTED_ARTIST="${4:-}"
EXPECTED_ALBUM="${5:-}"

ALBUM_NAME="$(basename "$ALBUM_DIR")"
SAFE_ALBUM_NAME="$(printf '%s' "$ALBUM_NAME" | tr ' /[]()' '_______' | tr -cd '[:alnum:]_.-')"

BEETS_SANDBOX_ROOT="$SHARED_DIR/beets/media-staging"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"

REPORT="$REPORT_DIR/music_staging_beets_mbid_dry_run_apply_${SAFE_ALBUM_NAME}_report_$STAMP.txt"
TSV="$RAW_DIR/music_staging_beets_mbid_dry_run_apply_${SAFE_ALBUM_NAME}_$STAMP.tsv"
LIVE_LOG="$REPORT_DIR/beets_mbid_dry_run_${SAFE_ALBUM_NAME}_live_$STAMP.log"

ERROR_PATTERNS='error loading plugin|PluginImportError|ModuleNotFoundError|Could not import plugin|No module named|Traceback'
NO_MATCH_PATTERNS='No matching release found|No matching release'

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

write_step() {
  local step_id="$1"
  local phase="$2"
  local target="$3"
  local status="$4"
  local action="$5"
  local notes="$6"

  tsv_row "$step_id" "$phase" "$target" "$status" "$action" "$notes" >> "$TSV"
}

usage() {
  cat <<'EOF'
Usage:
  apply-music-staging-beets-mbid-dry-run.sh --apply <album_dir> <mbid> <expected_artist> <expected_album>

Safety:
  Runs Beets with -C -W inside isolated BEETSDIR sandbox.
  Does not intentionally write tags, copy files, move files or modify /srv/media/music.
EOF
}

validate_args() {
  if [ "$APPLY_MODE" != "--apply" ] || [ -z "$ALBUM_DIR" ] || [ -z "$MBID" ] || [ -z "$EXPECTED_ARTIST" ] || [ -z "$EXPECTED_ALBUM" ]; then
    usage >&2
    fail "Missing required arguments."
  fi
}

confirm_apply() {
  local confirmation

  validate_args

  printf '%s\n' "This script will run an interactive Beets MBID dry-run:"
  printf '%s\n' "- Album: $ALBUM_DIR"
  printf '%s\n' "- MBID: $MBID"
  printf '%s\n' "- Expected artist: $EXPECTED_ARTIST"
  printf '%s\n' "- Expected album: $EXPECTED_ALBUM"
  printf '%s\n' "- BEETSDIR: $BEETS_SANDBOX_ROOT"
  printf '%s\n' "- Command: beet -v import -C -W"
  printf '%s\n' "- Live log: $LIVE_LOG"
  printf '%s\n' "At the Beets prompt, choose: enter Id"
  printf '%s\n' "Then paste: $MBID"
  printf '%s\n' "Do not use Use as-is. Do not remove -C or -W."
  printf '%s\n' "It should not write tags, copy files, move files, or modify /srv/media/music."
  printf '%s\n' "It may update the isolated Beets sandbox database."
  printf '%s' "Type APPLY to continue: "
  read -r confirmation

  if [ "$confirmation" != "APPLY" ]; then
    fail "Apply aborted by user."
  fi
}

main() {
  local beet_status
  local fail_count
  local warn_count
  local found_errors
  local found_no_match
  local found_match_markers

  require_lib_contract
  confirm_apply

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting Beets MBID dry-run apply."

  tsv_row \
    "step_id" \
    "phase" \
    "target" \
    "status" \
    "action" \
    "notes" > "$TSV"

  {
    printf '%s\n' '# Music Staging Beets MBID Dry-run Apply'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Album directory: %s\n' "$ALBUM_DIR"
    printf 'Album name: %s\n' "$ALBUM_NAME"
    printf 'MBID: %s\n' "$MBID"
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf 'BEETSDIR: %s\n' "$BEETS_SANDBOX_ROOT"
    printf 'Live log: %s\n' "$LIVE_LOG"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: runs beet -v import with -C -W inside isolated BEETSDIR sandbox.'
    printf '%s\n' 'This script does not intentionally write tags, copy files, move files, or modify /srv/media/music.'
    printf '\n'
  } > "$REPORT"

  if [ -d "$ALBUM_DIR" ]; then
    write_step "PRE-001" "preflight" "$ALBUM_DIR" "OK" "album directory exists" ""
  else
    write_step "PRE-001" "preflight" "$ALBUM_DIR" "FAIL" "album directory missing" ""
  fi

  if [ -d "$BEETS_SANDBOX_ROOT" ]; then
    write_step "PRE-002" "preflight" "$BEETS_SANDBOX_ROOT" "OK" "Beets sandbox exists" ""
  else
    write_step "PRE-002" "preflight" "$BEETS_SANDBOX_ROOT" "FAIL" "Beets sandbox missing" ""
  fi

  if command -v beet >/dev/null 2>&1; then
    write_step "PRE-003" "preflight" "beet" "OK" "beet command found" "$(command -v beet)"
  else
    write_step "PRE-003" "preflight" "beet" "FAIL" "beet command missing" ""
  fi

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$TSV")"

  if [ "$fail_count" -gt 0 ]; then
    log "Preflight failed."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  {
    printf '%s\n' '## Beets command'
    printf '\n'
    printf '%s\n' '```bash'
    printf 'BEETSDIR=%q beet -v import -C -W %q\n' "$BEETS_SANDBOX_ROOT" "$ALBUM_DIR"
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Required interactive action'
    printf '\n'
    printf '%s\n' '```text'
    printf '%s\n' 'At prompt, choose: enter Id'
    printf 'Paste MBID: %s\n' "$MBID"
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf '%s\n' 'Inspect the proposed match before accepting.'
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Live output'
    printf '\n'
    printf '%s\n' '```text'
  } >> "$REPORT"

  printf '%s\n' "Running Beets MBID dry-run. Interact with beet normally."
  printf '%s\n' "At prompt: choose enter Id, paste $MBID"
  printf '%s\n' "Expected: $EXPECTED_ARTIST - $EXPECTED_ALBUM"
  printf '%s\n' "Log: $LIVE_LOG"

  set +e
  env "BEETSDIR=$BEETS_SANDBOX_ROOT" beet -v import -C -W "$ALBUM_DIR" 2>&1 | tee "$LIVE_LOG"
  beet_status="${PIPESTATUS[0]}"
  set -e

  cat "$LIVE_LOG" >> "$REPORT"

  {
    printf '%s\n' '```'
    printf '\n'
  } >> "$REPORT"

  if [ "$beet_status" -eq 0 ]; then
    write_step "RUN-001" "run" "$ALBUM_DIR" "OK" "beet -v import -C -W returned success" "$LIVE_LOG"
  else
    write_step "RUN-001" "run" "$ALBUM_DIR" "WARN" "beet -v import -C -W returned non-zero" "exit=$beet_status log=$LIVE_LOG"
  fi

  found_errors="$(grep -Ei "$ERROR_PATTERNS" "$LIVE_LOG" || true)"
  if [ -z "$found_errors" ]; then
    write_step "VAL-001" "validate" "$LIVE_LOG" "OK" "no plugin/runtime errors detected" ""
  else
    write_step "VAL-001" "validate" "$LIVE_LOG" "FAIL" "plugin/runtime errors detected" "$found_errors"
  fi

  found_no_match="$(grep -Ei "$NO_MATCH_PATTERNS" "$LIVE_LOG" || true)"
  if [ -z "$found_no_match" ]; then
    write_step "VAL-002" "validate" "$LIVE_LOG" "OK" "no MusicBrainz no-match detected" ""
  else
    write_step "VAL-002" "validate" "$LIVE_LOG" "WARN" "MusicBrainz no-match detected" "$found_no_match"
  fi

  found_match_markers="$(grep -Ei "$MBID|$EXPECTED_ARTIST|$EXPECTED_ALBUM" "$LIVE_LOG" || true)"
  if [ -n "$found_match_markers" ]; then
    write_step "VAL-003" "validate" "$LIVE_LOG" "OK" "expected match markers detected" "$found_match_markers"
  else
    write_step "VAL-003" "validate" "$LIVE_LOG" "WARN" "expected match markers not detected" "expected=$EXPECTED_ARTIST / $EXPECTED_ALBUM / $MBID"
  fi

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$TSV")"
  warn_count="$(awk -F '\t' 'NR > 1 && $4 == "WARN" { c++ } END { print c+0 }' "$TSV")"

  {
    printf '%s\n' '## Summary'
    printf '\n'
    printf 'Beet exit status: %s\n' "$beet_status"
    printf 'Failures: %s\n' "$fail_count"
    printf 'Warnings: %s\n' "$warn_count"
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
    printf '%s\n' "- Live log: $LIVE_LOG"
  } >> "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    log "Beets MBID dry-run apply completed with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    log "Live log: $LIVE_LOG"
    exit 1
  fi

  log "Beets MBID dry-run apply completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
  log "Live log: $LIVE_LOG"
}

main "$@"
