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

STAGING_ROOT="/srv/media/music-staging"
ALBUM_STATE_ROOT="$SHARED_DIR/library-db/albums/media-staging"
REPORT_DIR="$SHARED_DIR/reports/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"
PLAN_DIR="$SHARED_DIR/library-db/plans/media/staging"

APPLY_MODE=""
TARGET_STATE=""
ALBUM_DIR=""
EXPECTED_ARTIST=""
EXPECTED_ALBUM=""
MBID=""
NOTE=""

ALBUM_NAME=""
SAFE_ALBUM_NAME=""
SOURCE_STATE=""
DEST_DIR=""
ALBUM_STATE_DIR=""

REPORT=""
TSV=""
TRANSITION_MANIFEST=""
STATE_FILE=""
EVENTS_FILE=""
ALBUM_TOOLBOX_DIR=""

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

usage() {
  cat <<'EOF'
Usage:
  apply-music-staging-transition.sh --apply --to <tagging|ready> <album_dir> <expected_artist> <expected_album> <mbid> [note]

Examples:
  apply-music-staging-transition.sh \
    --apply \
    --to tagging \
    "/srv/media/music-staging/reviewing/[1971] Thembi" \
    "Pharoah Sanders" \
    "Thembi" \
    "34497839-9158-4c6f-8945-7f543276ea3e" \
    "Controlled FLAC metadata write validated; moving to tagging for plugin/enrichment decisions."

Safety:
  Moves album directory inside /srv/media/music-staging only.
  Does not run Beets, write tags, delete files, or modify /srv/media/music.
  Fails if destination already exists.
EOF
}

parse_args() {
  if [ "${1:-}" != "--apply" ]; then
    usage >&2
    fail "First argument must be --apply."
  fi

  if [ "${2:-}" != "--to" ]; then
    usage >&2
    fail "Second argument must be --to."
  fi

  APPLY_MODE="${1:-}"
  TARGET_STATE="${3:-}"
  ALBUM_DIR="${4:-}"
  EXPECTED_ARTIST="${5:-}"
  EXPECTED_ALBUM="${6:-}"
  MBID="${7:-}"
  NOTE="${8:-}"

  if [ -z "$TARGET_STATE" ] || [ -z "$ALBUM_DIR" ] || [ -z "$EXPECTED_ARTIST" ] || [ -z "$EXPECTED_ALBUM" ] || [ -z "$MBID" ]; then
    usage >&2
    fail "Missing required arguments."
  fi

  case "$TARGET_STATE" in
    tagging|ready)
      ;;
    *)
      fail "Unsupported target state: $TARGET_STATE"
      ;;
  esac
}

derive_state_from_path() {
  local path="$1"
  local rel

  case "$path" in
    "$STAGING_ROOT"/*)
      rel="${path#$STAGING_ROOT/}"
      printf '%s' "${rel%%/*}"
      ;;
    *)
      printf '%s' "outside-staging"
      ;;
  esac
}

safe_name() {
  local name="$1"

  printf '%s' "$name" | tr ' /[]()' '_______' | tr -cd '[:alnum:]_.-'
}

latest_file() {
  local dir="$1"
  local pattern="$2"

  find "$dir" -maxdepth 1 -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | head -n 1 \
    | cut -d' ' -f2-
}

count_audio_files_at() {
  local dir="$1"

  find "$dir" -type f \( \
    -iname '*.flac' -o \
    -iname '*.mp3' -o \
    -iname '*.m4a' -o \
    -iname '*.ogg' -o \
    -iname '*.opus' -o \
    -iname '*.wav' -o \
    -iname '*.aiff' \
  \) | wc -l | tr -d ' '
}

count_flac_files_at() {
  local dir="$1"

  find "$dir" -type f -iname '*.flac' | wc -l | tr -d ' '
}

validate_inputs() {
  if [ ! -d "$ALBUM_DIR" ]; then
    fail "Album directory not found: $ALBUM_DIR"
  fi

  case "$ALBUM_DIR" in
    "$STAGING_ROOT"/*)
      ;;
    *)
      fail "Album directory is outside staging root: $ALBUM_DIR"
      ;;
  esac
}

init_paths() {
  ALBUM_NAME="$(basename "$ALBUM_DIR")"
  SAFE_ALBUM_NAME="$(safe_name "$ALBUM_NAME")"
  SOURCE_STATE="$(derive_state_from_path "$ALBUM_DIR")"
  DEST_DIR="$STAGING_ROOT/$TARGET_STATE/$ALBUM_NAME"
  ALBUM_STATE_DIR="$ALBUM_STATE_ROOT/$SAFE_ALBUM_NAME"
  ALBUM_TOOLBOX_DIR="$DEST_DIR/.toolbox"

  REPORT="$REPORT_DIR/music_staging_transition_apply_${SOURCE_STATE}_to_${TARGET_STATE}_${SAFE_ALBUM_NAME}_report_$STAMP.txt"
  TSV="$RAW_DIR/music_staging_transition_apply_${SOURCE_STATE}_to_${TARGET_STATE}_${SAFE_ALBUM_NAME}_$STAMP.tsv"
  TRANSITION_MANIFEST="$RAW_DIR/music_staging_transition_apply_${SOURCE_STATE}_to_${TARGET_STATE}_${SAFE_ALBUM_NAME}_manifest_$STAMP.tsv"
  STATE_FILE="$ALBUM_STATE_DIR/state.tsv"
  EVENTS_FILE="$ALBUM_STATE_DIR/events.tsv"
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

confirm_apply() {
  local confirmation
  local extra_confirmation

  printf '%s\n' "This script will move a music staging album:"
  printf '%s\n' "- Source: $ALBUM_DIR"
  printf '%s\n' "- Source state: $SOURCE_STATE"
  printf '%s\n' "- Target state: $TARGET_STATE"
  printf '%s\n' "- Destination: $DEST_DIR"
  printf '%s\n' "- Expected artist: $EXPECTED_ARTIST"
  printf '%s\n' "- Expected album: $EXPECTED_ALBUM"
  printf '%s\n' "- MBID: $MBID"
  printf '%s\n' ""
  printf '%s\n' "It will create/update:"
  printf '%s\n' "- $ALBUM_STATE_DIR"
  printf '%s\n' "- $DEST_DIR/.toolbox"
  printf '%s\n' ""
  printf '%s\n' "It will NOT run Beets, write tags, delete files, or modify /srv/media/music."
  printf '%s\n' ""

  case "$SOURCE_STATE" in
    reviewing|tagging)
      ;;
    *)
      printf '%s\n' "WARNING: source state is not reviewing/tagging: $SOURCE_STATE"
      printf '%s' "Type ALLOW-STAGING-PATH to continue: "
      read -r extra_confirmation
      if [ "$extra_confirmation" != "ALLOW-STAGING-PATH" ]; then
        fail "Apply aborted: extra confirmation not provided."
      fi
      ;;
  esac

  printf '%s' "Type APPLY to continue: "
  read -r confirmation

  if [ "$confirmation" != "APPLY" ]; then
    fail "Apply aborted by user."
  fi
}

check_ready_gate() {
  local latest_flac_write_validation_report
  local latest_flac_write_validation_tsv

  latest_flac_write_validation_report="$(latest_file "$REPORT_DIR" "music_staging_flac_metadata_write_validation_${SAFE_ALBUM_NAME}_report_*.txt")"
  latest_flac_write_validation_tsv="$(latest_file "$RAW_DIR" "music_staging_flac_metadata_write_validation_${SAFE_ALBUM_NAME}_*.tsv")"

  if [ "$TARGET_STATE" != "ready" ]; then
    write_step "READY-GATE" "gate" "$TARGET_STATE" "OK" "ready gate not required for this target state" ""
    return 0
  fi

  if [ -n "$latest_flac_write_validation_report" ] && grep -F "Interpretation: controlled FLAC metadata write validation passed" "$latest_flac_write_validation_report" >/dev/null 2>&1; then
    write_step "READY-001" "ready-gate" "$latest_flac_write_validation_report" "OK" "FLAC metadata write validation passed" ""
  else
    write_step "READY-001" "ready-gate" "${latest_flac_write_validation_report:-missing}" "FAIL" "FLAC metadata write validation missing or not passed" ""
  fi

  if [ -n "$latest_flac_write_validation_tsv" ]; then
    if awk -F '\t' 'NR > 1 && $4 == "WARN" { found=1 } END { exit found ? 0 : 1 }' "$latest_flac_write_validation_tsv"; then
      write_step "READY-002" "ready-gate" "$latest_flac_write_validation_tsv" "FAIL" "warnings present; ready blocks warnings by policy" ""
    else
      write_step "READY-002" "ready-gate" "$latest_flac_write_validation_tsv" "OK" "no warnings in latest validation TSV" ""
    fi
  else
    write_step "READY-002" "ready-gate" "missing" "FAIL" "latest validation TSV missing" ""
  fi
}

write_transition_manifest() {
  local before_audio="$1"
  local before_flac="$2"
  local after_audio="$3"
  local after_flac="$4"

  tsv_row "key" "value" > "$TRANSITION_MANIFEST"
  tsv_row "timestamp" "$STAMP" >> "$TRANSITION_MANIFEST"
  tsv_row "album_name" "$ALBUM_NAME" >> "$TRANSITION_MANIFEST"
  tsv_row "safe_album_name" "$SAFE_ALBUM_NAME" >> "$TRANSITION_MANIFEST"
  tsv_row "source_dir" "$ALBUM_DIR" >> "$TRANSITION_MANIFEST"
  tsv_row "source_state" "$SOURCE_STATE" >> "$TRANSITION_MANIFEST"
  tsv_row "target_state" "$TARGET_STATE" >> "$TRANSITION_MANIFEST"
  tsv_row "dest_dir" "$DEST_DIR" >> "$TRANSITION_MANIFEST"
  tsv_row "expected_artist" "$EXPECTED_ARTIST" >> "$TRANSITION_MANIFEST"
  tsv_row "expected_album" "$EXPECTED_ALBUM" >> "$TRANSITION_MANIFEST"
  tsv_row "mbid" "$MBID" >> "$TRANSITION_MANIFEST"
  tsv_row "before_audio_count" "$before_audio" >> "$TRANSITION_MANIFEST"
  tsv_row "before_flac_count" "$before_flac" >> "$TRANSITION_MANIFEST"
  tsv_row "after_audio_count" "$after_audio" >> "$TRANSITION_MANIFEST"
  tsv_row "after_flac_count" "$after_flac" >> "$TRANSITION_MANIFEST"
  tsv_row "album_state_dir" "$ALBUM_STATE_DIR" >> "$TRANSITION_MANIFEST"
  tsv_row "state_file" "$STATE_FILE" >> "$TRANSITION_MANIFEST"
  tsv_row "events_file" "$EVENTS_FILE" >> "$TRANSITION_MANIFEST"
  tsv_row "note" "$NOTE" >> "$TRANSITION_MANIFEST"
}

write_state_file() {
  mkdir -p "$ALBUM_STATE_DIR"

  tsv_row "key" "value" > "$STATE_FILE"
  tsv_row "album_name" "$ALBUM_NAME" >> "$STATE_FILE"
  tsv_row "safe_album_name" "$SAFE_ALBUM_NAME" >> "$STATE_FILE"
  tsv_row "state" "$TARGET_STATE" >> "$STATE_FILE"
  tsv_row "previous_state" "$SOURCE_STATE" >> "$STATE_FILE"
  tsv_row "current_dir" "$DEST_DIR" >> "$STATE_FILE"
  tsv_row "expected_artist" "$EXPECTED_ARTIST" >> "$STATE_FILE"
  tsv_row "expected_album" "$EXPECTED_ALBUM" >> "$STATE_FILE"
  tsv_row "mbid" "$MBID" >> "$STATE_FILE"
  tsv_row "updated_at" "$(toolbox_now)" >> "$STATE_FILE"
  tsv_row "last_transition_manifest" "$TRANSITION_MANIFEST" >> "$STATE_FILE"
  tsv_row "last_transition_report" "$REPORT" >> "$STATE_FILE"
  tsv_row "note" "$NOTE" >> "$STATE_FILE"
}

append_event() {
  mkdir -p "$ALBUM_STATE_DIR"

  if [ ! -f "$EVENTS_FILE" ]; then
    tsv_row \
      "timestamp" \
      "event" \
      "source_state" \
      "target_state" \
      "source_dir" \
      "dest_dir" \
      "artist" \
      "album" \
      "mbid" \
      "report" \
      "notes" > "$EVENTS_FILE"
  fi

  tsv_row \
    "$(toolbox_now)" \
    "transition_applied" \
    "$SOURCE_STATE" \
    "$TARGET_STATE" \
    "$ALBUM_DIR" \
    "$DEST_DIR" \
    "$EXPECTED_ARTIST" \
    "$EXPECTED_ALBUM" \
    "$MBID" \
    "$REPORT" \
    "$NOTE" >> "$EVENTS_FILE"
}

write_album_toolbox_files() {
  mkdir -p "$ALBUM_TOOLBOX_DIR"

  cp -a "$STATE_FILE" "$ALBUM_TOOLBOX_DIR/state.tsv"
  cp -a "$TRANSITION_MANIFEST" "$ALBUM_TOOLBOX_DIR/transition_manifest.tsv"
  cp -a "$EVENTS_FILE" "$ALBUM_TOOLBOX_DIR/events.tsv"
}

main() {
  local before_audio
  local before_flac
  local after_audio
  local after_flac
  local fail_count

  require_lib_contract
  parse_args "$@"
  validate_inputs
  init_paths
  confirm_apply

  mkdir -p "$REPORT_DIR" "$RAW_DIR" "$ALBUM_STATE_DIR"

  log "Starting music staging transition apply."

  tsv_row \
    "step_id" \
    "phase" \
    "target" \
    "status" \
    "action" \
    "notes" > "$TSV"

  before_audio="$(count_audio_files_at "$ALBUM_DIR")"
  before_flac="$(count_flac_files_at "$ALBUM_DIR")"

  write_step "PRE-001" "preflight" "$ALBUM_DIR" "OK" "source album directory exists" ""
  write_step "PRE-002" "preflight" "$SOURCE_STATE" "OK" "source state detected" ""
  write_step "PRE-003" "preflight" "$TARGET_STATE" "OK" "target state accepted" ""
  write_step "PRE-004" "preflight" "$DEST_DIR" "OK" "destination computed" ""
  write_step "MEDIA-001" "media" "$ALBUM_DIR" "OK" "source media counted" "audio=$before_audio flac=$before_flac"

  case "$SOURCE_STATE" in
    reviewing|tagging)
      write_step "PATH-001" "path" "$SOURCE_STATE" "OK" "source state accepted without extra gate" ""
      ;;
    *)
      write_step "PATH-001" "path" "$SOURCE_STATE" "WARN" "source state accepted with extra confirmation" ""
      ;;
  esac

  if [ "$SOURCE_STATE" = "$TARGET_STATE" ]; then
    write_step "PATH-002" "path" "$TARGET_STATE" "FAIL" "source and target state are the same" ""
  else
    write_step "PATH-002" "path" "$TARGET_STATE" "OK" "source and target states differ" ""
  fi

  if [ -e "$DEST_DIR" ]; then
    write_step "DEST-001" "destination" "$DEST_DIR" "FAIL" "destination already exists" "will not overwrite"
  else
    write_step "DEST-001" "destination" "$DEST_DIR" "OK" "destination does not exist" ""
  fi

  check_ready_gate

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$TSV")"
  if [ "$fail_count" -gt 0 ]; then
    log "Transition apply preflight failed."
    log "TSV: $TSV"
    exit 1
  fi

  mkdir -p "$(dirname "$DEST_DIR")"

  mv "$ALBUM_DIR" "$DEST_DIR"
  write_step "MOVE-001" "move" "$DEST_DIR" "OK" "album directory moved with mv" "$ALBUM_DIR -> $DEST_DIR"

  after_audio="$(count_audio_files_at "$DEST_DIR")"
  after_flac="$(count_flac_files_at "$DEST_DIR")"

  if [ "$after_audio" -eq "$before_audio" ] && [ "$after_flac" -eq "$before_flac" ]; then
    write_step "VAL-001" "validate" "$DEST_DIR" "OK" "media counts preserved after move" "before_audio=$before_audio after_audio=$after_audio before_flac=$before_flac after_flac=$after_flac"
  else
    write_step "VAL-001" "validate" "$DEST_DIR" "FAIL" "media count mismatch after move" "before_audio=$before_audio after_audio=$after_audio before_flac=$before_flac after_flac=$after_flac"
  fi

  if [ ! -e "$ALBUM_DIR" ] && [ -d "$DEST_DIR" ]; then
    write_step "VAL-002" "validate" "$DEST_DIR" "OK" "source removed and destination exists" ""
  else
    write_step "VAL-002" "validate" "$DEST_DIR" "FAIL" "source/destination state unexpected after move" "source_exists=$(test -e "$ALBUM_DIR" && printf yes || printf no)"
  fi

  write_transition_manifest "$before_audio" "$before_flac" "$after_audio" "$after_flac"
  write_state_file
  append_event
  write_album_toolbox_files

  write_step "STATE-001" "state" "$STATE_FILE" "OK" "album state file written" ""
  write_step "STATE-002" "state" "$EVENTS_FILE" "OK" "album events file updated" ""
  write_step "STATE-003" "state" "$ALBUM_TOOLBOX_DIR" "OK" "album-local .toolbox state written" ""
  write_step "STATE-004" "state" "$TRANSITION_MANIFEST" "OK" "transition manifest written" ""

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$TSV")"

  {
    printf '%s\n' '# Music Staging Transition Apply'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Album name: %s\n' "$ALBUM_NAME"
    printf 'Safe album name: %s\n' "$SAFE_ALBUM_NAME"
    printf 'Source state: %s\n' "$SOURCE_STATE"
    printf 'Target state: %s\n' "$TARGET_STATE"
    printf 'Source dir: %s\n' "$ALBUM_DIR"
    printf 'Destination: %s\n' "$DEST_DIR"
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf 'MBID: %s\n' "$MBID"
    printf 'Note: %s\n' "$NOTE"
    printf 'Album state dir: %s\n' "$ALBUM_STATE_DIR"
    printf 'Album .toolbox dir: %s\n' "$ALBUM_TOOLBOX_DIR"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf 'Transition manifest: %s\n' "$TRANSITION_MANIFEST"
    printf 'State file: %s\n' "$STATE_FILE"
    printf 'Events file: %s\n' "$EVENTS_FILE"
    printf '\n'
    printf '%s\n' 'Safety: moved only within /srv/media/music-staging. Did not run Beets, write tags, delete files, or modify /srv/media/music.'
    printf '\n'

    printf '%s\n' '## Transition TSV'
    printf '\n'
    printf '%s\n' '```text'
    column -t -s $'\t' "$TSV" 2>/dev/null || cat "$TSV"
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' '## Summary'
    printf '\n'
    printf 'Failures: %s\n' "$fail_count"
    if [ "$fail_count" -eq 0 ]; then
      printf '%s\n' 'Interpretation: music staging transition applied successfully.'
    else
      printf '%s\n' 'Interpretation: music staging transition completed with failures; inspect state before proceeding.'
    fi
    printf '\n'

    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
    printf '%s\n' "- Transition manifest: $TRANSITION_MANIFEST"
    printf '%s\n' "- State file: $STATE_FILE"
    printf '%s\n' "- Events file: $EVENTS_FILE"
    printf '%s\n' "- Album-local toolbox dir: $ALBUM_TOOLBOX_DIR"
  } > "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    log "Music staging transition apply completed with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  log "Music staging transition apply completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
  log "Destination: $DEST_DIR"
}

main "$@"
