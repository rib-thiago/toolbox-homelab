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
DEFAULT_ALBUM="$STAGING_DIR/[1971] Thembi"
DEFAULT_MBID="34497839-9158-4c6f-8945-7f543276ea3e"

ALBUM_DIR="${1:-$DEFAULT_ALBUM}"
MBID="${2:-$DEFAULT_MBID}"

ALBUM_NAME="$(basename "$ALBUM_DIR")"
SAFE_ALBUM_NAME="$(printf '%s' "$ALBUM_NAME" | tr ' /[]()' '_______' | tr -cd '[:alnum:]_.-')"

BEETS_SANDBOX_ROOT="$SHARED_DIR/beets/media-staging"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
PLAN_DIR="$SHARED_DIR/library-db/plans/media/staging"

REPORT="$REPORT_DIR/music_staging_beets_mbid_dry_run_plan_${SAFE_ALBUM_NAME}_report_$STAMP.txt"
TSV="$PLAN_DIR/music_staging_beets_mbid_dry_run_plan_${SAFE_ALBUM_NAME}_$STAMP.tsv"

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

write_step() {
  local step_id="$1"
  local phase="$2"
  local target="$3"
  local status="$4"
  local action="$5"
  local notes="$6"

  tsv_row "$step_id" "$phase" "$target" "$status" "$action" "$notes" >> "$TSV"
}

main() {
  local beets_command

  require_lib_contract

  mkdir -p "$REPORT_DIR" "$PLAN_DIR"

  if [ ! -d "$ALBUM_DIR" ]; then
    fail "Album directory not found: $ALBUM_DIR"
  fi

  if [ ! -d "$BEETS_SANDBOX_ROOT" ]; then
    fail "Beets sandbox root not found: $BEETS_SANDBOX_ROOT"
  fi

  log "Generating Beets MBID dry-run plan."

  beets_command="BEETSDIR=$(shell_quote_arg "$BEETS_SANDBOX_ROOT") beet import -C -W $(shell_quote_arg "$ALBUM_DIR")"

  tsv_row \
    "step_id" \
    "phase" \
    "target" \
    "status" \
    "action" \
    "notes" > "$TSV"

  write_step "PLAN-001" "album" "$ALBUM_DIR" "OK" "selected album" "$ALBUM_NAME"
  write_step "PLAN-002" "mbid" "$MBID" "OK" "selected MusicBrainz release candidate" "best candidate from release diagnosis"
  write_step "PLAN-003" "safety" "$BEETS_SANDBOX_ROOT" "OK" "sandbox dry-run only" "use -C -W; config has copy/write/move disabled"
  write_step "PLAN-004" "command" "$ALBUM_DIR" "PLANNED" "run beet import -C -W" "$beets_command"
  write_step "PLAN-005" "interactive" "beets prompt" "PLANNED" "choose enter Id and paste MBID" "$MBID"

  {
    printf '%s\n' '# Music Staging Beets MBID Dry-run Plan'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Album directory: %s\n' "$ALBUM_DIR"
    printf 'Album name: %s\n' "$ALBUM_NAME"
    printf 'Selected MBID: %s\n' "$MBID"
    printf 'Beets sandbox root: %s\n' "$BEETS_SANDBOX_ROOT"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: plan only. This script does not run Beets, write tags, copy files, move files or modify staging/library.'
    printf '\n'

    printf '%s\n' '## Evidence'
    printf '\n'
    printf '%s\n' '- Previous Beets dry-run worked technically but returned no automatic/manual text match.'
    printf '%s\n' '- Album tag diagnosis showed complete local tags and fingerprints.'
    printf '%s\n' '- MusicBrainz release candidate diagnosis ranked this MBID first.'
    printf '%s\n' '- Candidate: Pharoah Sanders — Thembi, date 1987, country US, 6 tracks, title_matches=6, duration_delta=3.8s.'
    printf '\n'

    printf '%s\n' '## Planned command'
    printf '\n'
    printf '%s\n' '```bash'
    printf '%s\n' "$beets_command"
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' '## Interactive Beets action'
    printf '\n'
    printf '%s\n' '```text'
    printf '%s\n' 'At prompt, choose: enter Id'
    printf 'Paste MBID: %s\n' "$MBID"
    printf '%s\n' 'Inspect proposed match before accepting.'
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' '## Decision rules'
    printf '\n'
    printf '%s\n' '- Accept only if Beets shows Pharoah Sanders — Thembi with coherent 6-track mapping.'
    printf '%s\n' '- Do not use Use as-is.'
    printf '%s\n' '- Do not remove -C or -W.'
    printf '%s\n' '- This remains evidence gathering, not final import/tagging.'
    printf '\n'

    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } > "$REPORT"

  log "Beets MBID dry-run plan generated."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
