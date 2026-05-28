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

STAGING_DIR="/srv/media/music-staging/reviewing"
BEETS_SANDBOX_ROOT="$SHARED_DIR/beets/media-staging"
BEETS_CONFIG="$BEETS_SANDBOX_ROOT/config.yaml"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
PLAN_DIR="$SHARED_DIR/library-db/plans/media/staging"

REPORT="$REPORT_DIR/music_staging_beets_dry_run_plan_report_$STAMP.txt"
TSV="$PLAN_DIR/music_staging_beets_dry_run_plan_$STAMP.tsv"

DEFAULT_ALBUM="$STAGING_DIR/[1971] Thembi"
ALBUM_DIR="${1:-$DEFAULT_ALBUM}"

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

shell_quote_arg() {
  local value="$1"

  printf '%q' "$value"
}

count_files() {
  local dir="$1"
  shift

  find "$dir" -type f "$@" 2>/dev/null | wc -l | tr -d ' '
}

write_step() {
  local step_id="$1"
  local category="$2"
  local target="$3"
  local status="$4"
  local action="$5"
  local notes="$6"

  tsv_row "$step_id" "$category" "$target" "$status" "$action" "$notes" >> "$TSV"
}

main() {
  local album_name
  local flac_count
  local mp3_count
  local mp4_count
  local image_count
  local total_bytes
  local command_text
  local live_log_path

  require_lib_contract

  mkdir -p "$REPORT_DIR" "$PLAN_DIR"

  log "Generating Beets dry-run plan."

  tsv_row \
    "step_id" \
    "category" \
    "target" \
    "status" \
    "action" \
    "notes" > "$TSV"

  if [ ! -d "$ALBUM_DIR" ]; then
    fail "Album directory not found: $ALBUM_DIR"
  fi

  if [ ! -d "$BEETS_SANDBOX_ROOT" ]; then
    fail "Beets sandbox root not found: $BEETS_SANDBOX_ROOT"
  fi

  if [ ! -f "$BEETS_CONFIG" ]; then
    fail "Beets sandbox config not found: $BEETS_CONFIG"
  fi

  album_name="$(basename "$ALBUM_DIR")"
  flac_count="$(count_files "$ALBUM_DIR" -iname '*.flac')"
  mp3_count="$(count_files "$ALBUM_DIR" -iname '*.mp3')"
  mp4_count="$(count_files "$ALBUM_DIR" -iname '*.mp4')"
  image_count="$(find "$ALBUM_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | wc -l | tr -d ' ')"
  total_bytes="$(du -sb "$ALBUM_DIR" 2>/dev/null | awk '{print $1}')"

  command_text="BEETSDIR=$(shell_quote_arg "$BEETS_SANDBOX_ROOT") beet import -C -W $(shell_quote_arg "$ALBUM_DIR")"
  live_log_path="$REPORT_DIR/beets_dry_run_${album_name// /_}_live_$STAMP.log"

  {
    printf '%s\n' '# Music Staging Beets Dry-run Plan'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Album directory: %s\n' "$ALBUM_DIR"
    printf 'Album name: %s\n' "$album_name"
    printf 'Beets sandbox root: %s\n' "$BEETS_SANDBOX_ROOT"
    printf 'Beets config: %s\n' "$BEETS_CONFIG"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: plan only. This script does not run beet import, write tags, copy files, move files or modify staging/library.'
    printf '%s\n' 'Dry-run policy: use BEETSDIR sandbox plus beet import -C -W.'
    printf '\n'
    printf '%s\n' '## Album summary'
    printf '\n'
    printf 'FLAC files: %s\n' "$flac_count"
    printf 'MP3 files: %s\n' "$mp3_count"
    printf 'MP4 files: %s\n' "$mp4_count"
    printf 'Image files: %s\n' "$image_count"
    printf 'Total bytes: %s\n' "$total_bytes"
    printf '\n'
    printf '%s\n' '## Planned command'
    printf '\n'
    printf '%s\n' '```bash'
    printf '%s\n' "$command_text"
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Suggested live-log command'
    printf '\n'
    printf '%s\n' '```bash'
    printf 'nflog %s env BEETSDIR=%s beet import -C -W %s\n' \
      "$(shell_quote_arg "$live_log_path")" \
      "$(shell_quote_arg "$BEETS_SANDBOX_ROOT")" \
      "$(shell_quote_arg "$ALBUM_DIR")"
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Manual note'
    printf '\n'
    printf '%s\n' 'beet import may ask interactive questions. For the first test, foreground execution may be easier than nohup/live-log.'
    printf '%s\n' 'If it asks whether to import, choose a safe non-writing path and do not approve any operation you do not understand.'
    printf '\n'
  } > "$REPORT"

  write_step "PLAN-001" "album" "$ALBUM_DIR" "OK" "selected album for dry-run" "$album_name"
  write_step "PLAN-002" "sandbox" "$BEETS_SANDBOX_ROOT" "OK" "sandbox root exists" ""
  write_step "PLAN-003" "config" "$BEETS_CONFIG" "OK" "sandbox config exists" ""
  write_step "PLAN-004" "command" "$ALBUM_DIR" "PLANNED" "beet import -C -W" "$command_text"
  write_step "PLAN-005" "live-log" "$live_log_path" "PLANNED" "optional nflog command" "beets can be interactive; foreground may be preferable"

  {
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  log "Beets dry-run plan generated."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
