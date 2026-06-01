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
PLAN_DIR="$SHARED_DIR/library-db/plans/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"

TARGET_STATE=""
ALBUM_DIR=""
EXPECTED_ARTIST=""
EXPECTED_ALBUM=""
MBID=""

ALBUM_NAME=""
SAFE_ALBUM_NAME=""
SOURCE_STATE=""
DEST_DIR=""
ALBUM_STATE_DIR=""

REPORT=""
TSV=""
TRANSITION_MANIFEST=""
STATE_PLAN=""
EVENT_PLAN=""

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
  plan-music-staging-transition.sh --to <tagging|ready> <album_dir> <expected_artist> <expected_album> <mbid>

Examples:
  plan-music-staging-transition.sh \
    --to tagging \
    "/srv/media/music-staging/reviewing/[1971] Thembi" \
    "Pharoah Sanders" \
    "Thembi" \
    "34497839-9158-4c6f-8945-7f543276ea3e"

  plan-music-staging-transition.sh \
    --to ready \
    "/srv/media/music-staging/tagging/[1971] Thembi" \
    "Pharoah Sanders" \
    "Thembi" \
    "34497839-9158-4c6f-8945-7f543276ea3e"

Safety:
  Plan only. Does not move, copy, delete, write tags, run Beets, or modify /srv/media/music.
EOF
}

parse_args() {
  if [ "${1:-}" != "--to" ]; then
    usage >&2
    fail "First argument must be --to."
  fi

  TARGET_STATE="${2:-}"
  ALBUM_DIR="${3:-}"
  EXPECTED_ARTIST="${4:-}"
  EXPECTED_ALBUM="${5:-}"
  MBID="${6:-}"

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

count_flac_files() {
  find "$ALBUM_DIR" -type f -iname '*.flac' | wc -l | tr -d ' '
}

count_audio_files() {
  find "$ALBUM_DIR" -type f \( \
    -iname '*.flac' -o \
    -iname '*.mp3' -o \
    -iname '*.m4a' -o \
    -iname '*.ogg' -o \
    -iname '*.opus' -o \
    -iname '*.wav' -o \
    -iname '*.aiff' \
  \) | wc -l | tr -d ' '
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

  REPORT="$REPORT_DIR/music_staging_transition_plan_${SOURCE_STATE}_to_${TARGET_STATE}_${SAFE_ALBUM_NAME}_report_$STAMP.txt"
  TSV="$PLAN_DIR/music_staging_transition_plan_${SOURCE_STATE}_to_${TARGET_STATE}_${SAFE_ALBUM_NAME}_$STAMP.tsv"
  TRANSITION_MANIFEST="$PLAN_DIR/music_staging_transition_plan_${SOURCE_STATE}_to_${TARGET_STATE}_${SAFE_ALBUM_NAME}_manifest_$STAMP.tsv"
  STATE_PLAN="$ALBUM_STATE_DIR/state_plan_${SOURCE_STATE}_to_${TARGET_STATE}_$STAMP.tsv"
  EVENT_PLAN="$ALBUM_STATE_DIR/events_plan_${SOURCE_STATE}_to_${TARGET_STATE}_$STAMP.tsv"
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

write_manifest() {
  local latest_mbid_validation_report="$1"
  local latest_flac_write_validation_report="$2"
  local flac_count="$3"
  local audio_count="$4"

  tsv_row \
    "key" \
    "value" > "$TRANSITION_MANIFEST"

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
  tsv_row "flac_count" "$flac_count" >> "$TRANSITION_MANIFEST"
  tsv_row "audio_count" "$audio_count" >> "$TRANSITION_MANIFEST"
  tsv_row "latest_mbid_validation_report" "${latest_mbid_validation_report:-missing}" >> "$TRANSITION_MANIFEST"
  tsv_row "latest_flac_write_validation_report" "${latest_flac_write_validation_report:-missing}" >> "$TRANSITION_MANIFEST"
  tsv_row "album_state_dir" "$ALBUM_STATE_DIR" >> "$TRANSITION_MANIFEST"
  tsv_row "planned_state_file" "$STATE_PLAN" >> "$TRANSITION_MANIFEST"
  tsv_row "planned_events_file" "$EVENT_PLAN" >> "$TRANSITION_MANIFEST"
}

write_state_plan() {
  mkdir -p "$ALBUM_STATE_DIR"

  tsv_row \
    "key" \
    "value" > "$STATE_PLAN"

  tsv_row "album_name" "$ALBUM_NAME" >> "$STATE_PLAN"
  tsv_row "safe_album_name" "$SAFE_ALBUM_NAME" >> "$STATE_PLAN"
  tsv_row "state" "$TARGET_STATE" >> "$STATE_PLAN"
  tsv_row "source_state" "$SOURCE_STATE" >> "$STATE_PLAN"
  tsv_row "source_dir" "$ALBUM_DIR" >> "$STATE_PLAN"
  tsv_row "current_dir_after_apply" "$DEST_DIR" >> "$STATE_PLAN"
  tsv_row "expected_artist" "$EXPECTED_ARTIST" >> "$STATE_PLAN"
  tsv_row "expected_album" "$EXPECTED_ALBUM" >> "$STATE_PLAN"
  tsv_row "mbid" "$MBID" >> "$STATE_PLAN"
  tsv_row "updated_at" "$(toolbox_now)" >> "$STATE_PLAN"
  tsv_row "last_transition_plan" "$TRANSITION_MANIFEST" >> "$STATE_PLAN"
}

write_event_plan() {
  mkdir -p "$ALBUM_STATE_DIR"

  if [ ! -f "$EVENT_PLAN" ]; then
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
      "notes" > "$EVENT_PLAN"
  fi

  tsv_row \
    "$(toolbox_now)" \
    "transition_planned" \
    "$SOURCE_STATE" \
    "$TARGET_STATE" \
    "$ALBUM_DIR" \
    "$DEST_DIR" \
    "$EXPECTED_ARTIST" \
    "$EXPECTED_ALBUM" \
    "$MBID" \
    "plan only; no filesystem changes" >> "$EVENT_PLAN"
}

main() {
  local flac_count
  local audio_count
  local latest_mbid_validation_report
  local latest_mbid_validation_tsv
  local latest_flac_write_validation_report
  local latest_flac_write_validation_tsv
  local fail_count

  require_lib_contract
  parse_args "$@"
  validate_inputs
  init_paths

  mkdir -p "$REPORT_DIR" "$PLAN_DIR" "$RAW_DIR" "$ALBUM_STATE_DIR"

  log "Generating music staging transition plan."

  tsv_row \
    "step_id" \
    "phase" \
    "target" \
    "status" \
    "action" \
    "notes" > "$TSV"

  flac_count="$(count_flac_files)"
  audio_count="$(count_audio_files)"

  latest_mbid_validation_report="$(latest_file "$REPORT_DIR" "music_staging_beets_mbid_dry_run_validation_${SAFE_ALBUM_NAME}_report_*.txt")"
  latest_mbid_validation_tsv="$(latest_file "$RAW_DIR" "music_staging_beets_mbid_dry_run_validation_${SAFE_ALBUM_NAME}_*.tsv")"
  latest_flac_write_validation_report="$(latest_file "$REPORT_DIR" "music_staging_flac_metadata_write_validation_${SAFE_ALBUM_NAME}_report_*.txt")"
  latest_flac_write_validation_tsv="$(latest_file "$RAW_DIR" "music_staging_flac_metadata_write_validation_${SAFE_ALBUM_NAME}_*.tsv")"

  write_step "PRE-001" "preflight" "$ALBUM_DIR" "OK" "album directory exists" ""
  write_step "PRE-002" "preflight" "$SOURCE_STATE" "OK" "source state detected" ""
  write_step "PRE-003" "preflight" "$TARGET_STATE" "OK" "target state accepted" ""
  write_step "PRE-004" "preflight" "$EXPECTED_ARTIST" "OK" "expected artist supplied" ""
  write_step "PRE-005" "preflight" "$EXPECTED_ALBUM" "OK" "expected album supplied" ""
  write_step "PRE-006" "preflight" "$MBID" "OK" "MBID supplied" ""

  case "$SOURCE_STATE" in
    reviewing|tagging)
      write_step "PATH-001" "path" "$SOURCE_STATE" "OK" "source state is normal for transition" ""
      ;;
    incoming|downloading|archive|rejected|imports|ready)
      write_step "PATH-001" "path" "$SOURCE_STATE" "WARN" "source state requires extra confirmation in apply" "not reviewing/tagging"
      ;;
    *)
      write_step "PATH-001" "path" "$SOURCE_STATE" "WARN" "unusual source state requires extra confirmation in apply" ""
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

  if [ "$audio_count" -gt 0 ]; then
    write_step "MEDIA-001" "media" "$ALBUM_DIR" "OK" "audio files found" "audio_count=$audio_count flac_count=$flac_count"
  else
    write_step "MEDIA-001" "media" "$ALBUM_DIR" "WARN" "no audio files detected" ""
  fi

  if [ "$TARGET_STATE" = "tagging" ]; then
    if [ -n "$latest_mbid_validation_report" ]; then
      write_step "EVID-001" "evidence" "$latest_mbid_validation_report" "OK" "latest MBID dry-run validation found" ""
    else
      write_step "EVID-001" "evidence" "missing" "WARN" "MBID dry-run validation not found" "tagging can still be planned, but review recommended"
    fi

    if [ -n "$latest_flac_write_validation_report" ]; then
      write_step "EVID-002" "evidence" "$latest_flac_write_validation_report" "OK" "latest FLAC metadata write validation found" "album already has controlled tag write evidence"
    else
      write_step "EVID-002" "evidence" "missing" "OK" "FLAC metadata write validation not required for tagging" ""
    fi
  fi

  if [ "$TARGET_STATE" = "ready" ]; then
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
  fi

  write_step "PLAN-001" "plan" "$DEST_DIR" "PLANNED" "move album directory with mv in apply phase" "preserve current directory name"
  write_step "PLAN-002" "plan" "$ALBUM_STATE_DIR" "PLANNED" "write consolidated album state under library-db/albums" ""
  write_step "PLAN-003" "plan" "$DEST_DIR/.toolbox" "PLANNED" "write .toolbox state inside album after move" ""
  write_step "PLAN-004" "plan" "$TRANSITION_MANIFEST" "PLANNED" "write transition manifest" ""

  write_manifest "$latest_mbid_validation_report" "$latest_flac_write_validation_report" "$flac_count" "$audio_count"
  write_state_plan
  write_event_plan

  {
    printf '%s\n' '# Music Staging Transition Plan'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Album directory: %s\n' "$ALBUM_DIR"
    printf 'Album name: %s\n' "$ALBUM_NAME"
    printf 'Safe album name: %s\n' "$SAFE_ALBUM_NAME"
    printf 'Source state: %s\n' "$SOURCE_STATE"
    printf 'Target state: %s\n' "$TARGET_STATE"
    printf 'Destination: %s\n' "$DEST_DIR"
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf 'MBID: %s\n' "$MBID"
    printf 'FLAC count: %s\n' "$flac_count"
    printf 'Audio count: %s\n' "$audio_count"
    printf 'Album state dir: %s\n' "$ALBUM_STATE_DIR"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf 'Transition manifest: %s\n' "$TRANSITION_MANIFEST"
    printf 'State plan: %s\n' "$STATE_PLAN"
    printf 'Event plan: %s\n' "$EVENT_PLAN"
    printf '\n'
    printf '%s\n' 'Safety: plan only. This script does not move, copy, delete, run Beets, write tags, or modify /srv/media/music.'
    printf '\n'

    printf '%s\n' '## Evidence'
    printf '\n'
    printf 'Latest MBID dry-run validation report: %s\n' "${latest_mbid_validation_report:-missing}"
    printf 'Latest MBID dry-run validation TSV: %s\n' "${latest_mbid_validation_tsv:-missing}"
    printf 'Latest FLAC metadata write validation report: %s\n' "${latest_flac_write_validation_report:-missing}"
    printf 'Latest FLAC metadata write validation TSV: %s\n' "${latest_flac_write_validation_tsv:-missing}"
    printf '\n'

    printf '%s\n' '## Transition semantics'
    printf '\n'
    printf '%s\n' '- reviewing: album is being evaluated; identity/release/risk are under review.'
    printf '%s\n' '- tagging: album is under curatorial metadata treatment; not ready for final import.'
    printf '%s\n' '- ready: album is finalized within staging and ready for future import.'
    printf '\n'

    printf '%s\n' '## Planned apply behavior'
    printf '\n'
    printf '%s\n' '```text'
    printf 'mv %s %s\n' "$ALBUM_DIR" "$DEST_DIR"
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' '## Plan TSV'
    printf '\n'
    printf '%s\n' '```text'
    column -t -s $'\t' "$TSV" 2>/dev/null || cat "$TSV"
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
    printf '%s\n' "- Transition manifest: $TRANSITION_MANIFEST"
    printf '%s\n' "- State plan: $STATE_PLAN"
    printf '%s\n' "- Event plan: $EVENT_PLAN"
  } > "$REPORT"

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$TSV")"

  if [ "$fail_count" -gt 0 ]; then
    log "Music staging transition plan generated with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  log "Music staging transition plan generated."
  log "Report: $REPORT"
  log "TSV: $TSV"
  log "Transition manifest: $TRANSITION_MANIFEST"
}

main "$@"
