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
MBID="${2:-}"
EXPECTED_ARTIST="${3:-}"
EXPECTED_ALBUM="${4:-}"

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

usage() {
  cat <<'EOF'
Usage:
  plan-music-staging-beets-mbid-dry-run.sh <album_dir> <mbid> <expected_artist> <expected_album>

Safety:
  Plan only. Does not run Beets, write tags, copy files, move files or modify staging/library.
EOF
}

validate_args() {
  if [ -z "$ALBUM_DIR" ] || [ -z "$MBID" ] || [ -z "$EXPECTED_ARTIST" ] || [ -z "$EXPECTED_ALBUM" ]; then
    usage >&2
    fail "Missing required arguments."
  fi
}

main() {
  local beets_command

  require_lib_contract
  validate_args

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
  write_step "PLAN-002" "mbid" "$MBID" "OK" "selected MusicBrainz release candidate" "expected_artist=$EXPECTED_ARTIST expected_album=$EXPECTED_ALBUM"
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
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf 'Selected MBID: %s\n' "$MBID"
    printf 'Beets sandbox root: %s\n' "$BEETS_SANDBOX_ROOT"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: plan only. This script does not run Beets, write tags, copy files, move files or modify staging/library.'
    printf '\n'

    printf '%s\n' '## Evidence'
    printf '\n'
    printf '%s\n' '- Album tag diagnosis should be complete before this step.'
    printf '%s\n' '- MusicBrainz release candidate diagnosis should provide the selected MBID.'
    printf '%s\n' '- This plan prepares only a sandboxed Beets dry-run.'
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
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf '%s\n' 'Inspect proposed match before accepting.'
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' '## Decision rules'
    printf '\n'
    printf '%s\n' "- Accept only if Beets shows the expected artist/album and coherent track mapping."
    printf '%s\n' "- Expected artist: $EXPECTED_ARTIST"
    printf '%s\n' "- Expected album: $EXPECTED_ALBUM"
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
