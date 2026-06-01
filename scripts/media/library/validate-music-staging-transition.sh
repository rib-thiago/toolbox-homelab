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

TARGET_STATE=""
ALBUM_NAME_OR_DIR=""
EXPECTED_ARTIST=""
EXPECTED_ALBUM=""
MBID=""

ALBUM_NAME=""
SAFE_ALBUM_NAME=""
DEST_DIR=""
ALBUM_STATE_DIR=""
ALBUM_TOOLBOX_DIR=""

REPORT=""
TSV=""
CURRENT_MANIFEST=""

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
  validate-music-staging-transition.sh --state <tagging|ready> <album_name_or_dir> <expected_artist> <expected_album> <mbid>

Examples:
  validate-music-staging-transition.sh \
    --state tagging \
    "[1971] Thembi" \
    "Pharoah Sanders" \
    "Thembi" \
    "34497839-9158-4c6f-8945-7f543276ea3e"

  validate-music-staging-transition.sh \
    --state tagging \
    "/srv/media/music-staging/tagging/1973 Spectrum" \
    "Billy Cobham" \
    "Spectrum" \
    "1c9b277c-2b46-3e9d-94c9-f3ffaa684126"

Safety:
  Validation only. Does not move, copy, delete, run Beets, write tags, or modify /srv/media/music.
EOF
}

parse_args() {
  if [ "${1:-}" != "--state" ]; then
    usage >&2
    fail "First argument must be --state."
  fi

  TARGET_STATE="${2:-}"
  ALBUM_NAME_OR_DIR="${3:-}"
  EXPECTED_ARTIST="${4:-}"
  EXPECTED_ALBUM="${5:-}"
  MBID="${6:-}"

  if [ -z "$TARGET_STATE" ] || [ -z "$ALBUM_NAME_OR_DIR" ] || [ -z "$EXPECTED_ARTIST" ] || [ -z "$EXPECTED_ALBUM" ] || [ -z "$MBID" ]; then
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

init_paths() {
  case "$ALBUM_NAME_OR_DIR" in
    "$STAGING_ROOT"/*)
      DEST_DIR="$ALBUM_NAME_OR_DIR"
      ALBUM_NAME="$(basename "$DEST_DIR")"
      ;;
    *)
      ALBUM_NAME="$ALBUM_NAME_OR_DIR"
      DEST_DIR="$STAGING_ROOT/$TARGET_STATE/$ALBUM_NAME"
      ;;
  esac

  SAFE_ALBUM_NAME="$(safe_name "$ALBUM_NAME")"
  ALBUM_STATE_DIR="$ALBUM_STATE_ROOT/$SAFE_ALBUM_NAME"
  ALBUM_TOOLBOX_DIR="$DEST_DIR/.toolbox"

  REPORT="$REPORT_DIR/music_staging_transition_validation_${TARGET_STATE}_${SAFE_ALBUM_NAME}_report_$STAMP.txt"
  TSV="$RAW_DIR/music_staging_transition_validation_${TARGET_STATE}_${SAFE_ALBUM_NAME}_$STAMP.tsv"
  CURRENT_MANIFEST="$RAW_DIR/music_staging_transition_validation_${TARGET_STATE}_${SAFE_ALBUM_NAME}_current_manifest_$STAMP.tsv"
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

count_total_files_at() {
  local dir="$1"

  find "$dir" -type f | wc -l | tr -d ' '
}

read_state_value() {
  local file="$1"
  local key="$2"

  awk -F '\t' -v key="$key" '
    NR > 1 && $1 == key {
      print $2
      exit
    }
  ' "$file"
}

write_current_manifest() {
  local audio_count
  local flac_count
  local total_files
  local latest_apply_report
  local latest_apply_tsv
  local state_file
  local events_file
  local local_state_file
  local local_events_file
  local local_manifest_file

  audio_count="$(count_audio_files_at "$DEST_DIR")"
  flac_count="$(count_flac_files_at "$DEST_DIR")"
  total_files="$(count_total_files_at "$DEST_DIR")"
  latest_apply_report="$(latest_file "$REPORT_DIR" "music_staging_transition_apply_*_to_${TARGET_STATE}_${SAFE_ALBUM_NAME}_report_*.txt")"
  latest_apply_tsv="$(latest_file "$RAW_DIR" "music_staging_transition_apply_*_to_${TARGET_STATE}_${SAFE_ALBUM_NAME}_*.tsv")"

  state_file="$ALBUM_STATE_DIR/state.tsv"
  events_file="$ALBUM_STATE_DIR/events.tsv"
  local_state_file="$ALBUM_TOOLBOX_DIR/state.tsv"
  local_events_file="$ALBUM_TOOLBOX_DIR/events.tsv"
  local_manifest_file="$ALBUM_TOOLBOX_DIR/transition_manifest.tsv"

  tsv_row "key" "value" > "$CURRENT_MANIFEST"
  tsv_row "timestamp" "$STAMP" >> "$CURRENT_MANIFEST"
  tsv_row "album_name" "$ALBUM_NAME" >> "$CURRENT_MANIFEST"
  tsv_row "safe_album_name" "$SAFE_ALBUM_NAME" >> "$CURRENT_MANIFEST"
  tsv_row "expected_state" "$TARGET_STATE" >> "$CURRENT_MANIFEST"
  tsv_row "dest_dir" "$DEST_DIR" >> "$CURRENT_MANIFEST"
  tsv_row "expected_artist" "$EXPECTED_ARTIST" >> "$CURRENT_MANIFEST"
  tsv_row "expected_album" "$EXPECTED_ALBUM" >> "$CURRENT_MANIFEST"
  tsv_row "mbid" "$MBID" >> "$CURRENT_MANIFEST"
  tsv_row "audio_count" "$audio_count" >> "$CURRENT_MANIFEST"
  tsv_row "flac_count" "$flac_count" >> "$CURRENT_MANIFEST"
  tsv_row "total_files" "$total_files" >> "$CURRENT_MANIFEST"
  tsv_row "album_state_dir" "$ALBUM_STATE_DIR" >> "$CURRENT_MANIFEST"
  tsv_row "state_file" "$state_file" >> "$CURRENT_MANIFEST"
  tsv_row "events_file" "$events_file" >> "$CURRENT_MANIFEST"
  tsv_row "album_toolbox_dir" "$ALBUM_TOOLBOX_DIR" >> "$CURRENT_MANIFEST"
  tsv_row "local_state_file" "$local_state_file" >> "$CURRENT_MANIFEST"
  tsv_row "local_events_file" "$local_events_file" >> "$CURRENT_MANIFEST"
  tsv_row "local_transition_manifest" "$local_manifest_file" >> "$CURRENT_MANIFEST"
  tsv_row "latest_apply_report" "${latest_apply_report:-missing}" >> "$CURRENT_MANIFEST"
  tsv_row "latest_apply_tsv" "${latest_apply_tsv:-missing}" >> "$CURRENT_MANIFEST"
}

validate_tags_basic() {
  local current_tags_file
  local album_count
  local artist_count
  local albumartist_count
  local mbid_count
  local title_count
  local tracknumber_count
  local flac_count

  current_tags_file="$RAW_DIR/music_staging_transition_validation_${TARGET_STATE}_${SAFE_ALBUM_NAME}_current_tags_$STAMP.tsv"
  flac_count="$(count_flac_files_at "$DEST_DIR")"

  if [ "$flac_count" -eq 0 ]; then
    write_check "TAG-SKIP" "tags" "$DEST_DIR" "WARN" "no FLAC files; skipping FLAC tag validation" ""
    return 0
  fi

  tsv_row "relative_path" "field" "value" > "$current_tags_file"

  while IFS= read -r -d '' file; do
    rel="${file#$DEST_DIR/}"

    while IFS='=' read -r field value; do
      if [ -n "$field" ]; then
        tsv_row "$rel" "$field" "${value:-}" >> "$current_tags_file"
      fi
    done < <(metaflac --export-tags-to=- "$file" 2>/dev/null || true)
  done < <(find "$DEST_DIR" -type f -iname '*.flac' -print0 | sort -z)

  album_count="$(
    awk -F '\t' -v expected="$EXPECTED_ALBUM" '
      NR > 1 && toupper($2) == "ALBUM" && $3 == expected { files[$1]=1 }
      END { for (f in files) c++; print c+0 }
    ' "$current_tags_file"
  )"

  artist_count="$(
    awk -F '\t' -v expected="$EXPECTED_ARTIST" '
      NR > 1 && toupper($2) == "ARTIST" && $3 == expected { files[$1]=1 }
      END { for (f in files) c++; print c+0 }
    ' "$current_tags_file"
  )"

  albumartist_count="$(
    awk -F '\t' -v expected="$EXPECTED_ARTIST" '
      NR > 1 && toupper($2) == "ALBUMARTIST" && $3 == expected { files[$1]=1 }
      END { for (f in files) c++; print c+0 }
    ' "$current_tags_file"
  )"

  mbid_count="$(
    awk -F '\t' -v expected="$MBID" '
      NR > 1 && $3 == expected { files[$1]=1 }
      END { for (f in files) c++; print c+0 }
    ' "$current_tags_file"
  )"

  title_count="$(
    awk -F '\t' '
      NR > 1 && toupper($2) == "TITLE" && $3 != "" { files[$1]=1 }
      END { for (f in files) c++; print c+0 }
    ' "$current_tags_file"
  )"

  tracknumber_count="$(
    awk -F '\t' '
      NR > 1 && toupper($2) == "TRACKNUMBER" && $3 != "" { files[$1]=1 }
      END { for (f in files) c++; print c+0 }
    ' "$current_tags_file"
  )"

  if [ "$album_count" -eq "$flac_count" ]; then
    write_check "TAG-ALBUM" "tags" "$current_tags_file" "OK" "ALBUM matches expected album for all FLACs" "count=$album_count flac=$flac_count"
  else
    write_check "TAG-ALBUM" "tags" "$current_tags_file" "FAIL" "ALBUM mismatch" "count=$album_count flac=$flac_count"
  fi

  if [ "$artist_count" -eq "$flac_count" ]; then
    write_check "TAG-ARTIST" "tags" "$current_tags_file" "OK" "ARTIST matches expected artist for all FLACs" "count=$artist_count flac=$flac_count"
  else
    write_check "TAG-ARTIST" "tags" "$current_tags_file" "FAIL" "ARTIST mismatch" "count=$artist_count flac=$flac_count"
  fi

  if [ "$albumartist_count" -eq "$flac_count" ]; then
    write_check "TAG-ALBUMARTIST" "tags" "$current_tags_file" "OK" "ALBUMARTIST matches expected artist for all FLACs" "count=$albumartist_count flac=$flac_count"
  else
    write_check "TAG-ALBUMARTIST" "tags" "$current_tags_file" "WARN" "ALBUMARTIST missing or differs on some FLACs" "count=$albumartist_count flac=$flac_count"
  fi

  if [ "$mbid_count" -eq "$flac_count" ]; then
    write_check "TAG-MBID" "tags" "$current_tags_file" "OK" "expected MBID found for all FLACs" "count=$mbid_count flac=$flac_count"
  else
    write_check "TAG-MBID" "tags" "$current_tags_file" "WARN" "expected MBID not found on all FLACs" "count=$mbid_count flac=$flac_count"
  fi

  if [ "$title_count" -eq "$flac_count" ]; then
    write_check "TAG-TITLE" "tags" "$current_tags_file" "OK" "TITLE present for all FLACs" "count=$title_count flac=$flac_count"
  else
    write_check "TAG-TITLE" "tags" "$current_tags_file" "FAIL" "TITLE missing on some FLACs" "count=$title_count flac=$flac_count"
  fi

  if [ "$tracknumber_count" -eq "$flac_count" ]; then
    write_check "TAG-TRACKNUMBER" "tags" "$current_tags_file" "OK" "TRACKNUMBER present for all FLACs" "count=$tracknumber_count flac=$flac_count"
  else
    write_check "TAG-TRACKNUMBER" "tags" "$current_tags_file" "FAIL" "TRACKNUMBER missing on some FLACs" "count=$tracknumber_count flac=$flac_count"
  fi

  write_check "TAG-FILE" "tags" "$current_tags_file" "OK" "current tag snapshot written" ""
}

main() {
  local state_file
  local events_file
  local local_state_file
  local local_events_file
  local local_manifest_file
  local state_value
  local current_dir_value
  local artist_value
  local album_value
  local mbid_value
  local audio_count
  local flac_count
  local latest_apply_tsv
  local latest_apply_report
  local apply_fail_count
  local fail_count
  local warn_count

  require_lib_contract
  parse_args "$@"
  init_paths

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting music staging transition validation."

  tsv_row \
    "check_id" \
    "category" \
    "target" \
    "status" \
    "message" \
    "details" > "$TSV"

  state_file="$ALBUM_STATE_DIR/state.tsv"
  events_file="$ALBUM_STATE_DIR/events.tsv"
  local_state_file="$ALBUM_TOOLBOX_DIR/state.tsv"
  local_events_file="$ALBUM_TOOLBOX_DIR/events.tsv"
  local_manifest_file="$ALBUM_TOOLBOX_DIR/transition_manifest.tsv"

  {
    printf '%s\n' '# Music Staging Transition Validation'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Expected state: %s\n' "$TARGET_STATE"
    printf 'Album name: %s\n' "$ALBUM_NAME"
    printf 'Safe album name: %s\n' "$SAFE_ALBUM_NAME"
    printf 'Destination: %s\n' "$DEST_DIR"
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf 'MBID: %s\n' "$MBID"
    printf 'Album state dir: %s\n' "$ALBUM_STATE_DIR"
    printf 'Album .toolbox dir: %s\n' "$ALBUM_TOOLBOX_DIR"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf 'Current manifest: %s\n' "$CURRENT_MANIFEST"
    printf '\n'
    printf '%s\n' 'Safety: validation only. This script does not move, copy, delete, run Beets, write tags, or modify /srv/media/music.'
    printf '\n'
  } > "$REPORT"

  if [ -d "$DEST_DIR" ]; then
    write_check "DEST-001" "destination" "$DEST_DIR" "OK" "destination directory exists" ""
  else
    write_check "DEST-001" "destination" "$DEST_DIR" "FAIL" "destination directory missing" ""
  fi

  if [ -d "$ALBUM_STATE_DIR" ]; then
    write_check "STATE-DIR" "state" "$ALBUM_STATE_DIR" "OK" "album state directory exists" ""
  else
    write_check "STATE-DIR" "state" "$ALBUM_STATE_DIR" "FAIL" "album state directory missing" ""
  fi

  if [ -d "$ALBUM_TOOLBOX_DIR" ]; then
    write_check "LOCAL-TOOLBOX" "state" "$ALBUM_TOOLBOX_DIR" "OK" "album-local .toolbox directory exists" ""
  else
    write_check "LOCAL-TOOLBOX" "state" "$ALBUM_TOOLBOX_DIR" "FAIL" "album-local .toolbox directory missing" ""
  fi

  for f in "$state_file" "$events_file" "$local_state_file" "$local_events_file" "$local_manifest_file"; do
    if [ -f "$f" ]; then
      write_check "FILE" "file" "$f" "OK" "expected state artifact exists" ""
    else
      write_check "FILE" "file" "$f" "FAIL" "expected state artifact missing" ""
    fi
  done

  if [ -f "$state_file" ]; then
    state_value="$(read_state_value "$state_file" "state")"
    current_dir_value="$(read_state_value "$state_file" "current_dir")"
    artist_value="$(read_state_value "$state_file" "expected_artist")"
    album_value="$(read_state_value "$state_file" "expected_album")"
    mbid_value="$(read_state_value "$state_file" "mbid")"

    if [ "$state_value" = "$TARGET_STATE" ]; then
      write_check "STATE-001" "state" "$state_file" "OK" "state matches expected state" "$state_value"
    else
      write_check "STATE-001" "state" "$state_file" "FAIL" "state mismatch" "found=$state_value expected=$TARGET_STATE"
    fi

    if [ "$current_dir_value" = "$DEST_DIR" ]; then
      write_check "STATE-002" "state" "$state_file" "OK" "current_dir matches destination" "$current_dir_value"
    else
      write_check "STATE-002" "state" "$state_file" "FAIL" "current_dir mismatch" "found=$current_dir_value expected=$DEST_DIR"
    fi

    if [ "$artist_value" = "$EXPECTED_ARTIST" ] && [ "$album_value" = "$EXPECTED_ALBUM" ] && [ "$mbid_value" = "$MBID" ]; then
      write_check "STATE-003" "state" "$state_file" "OK" "artist/album/MBID state values match expected" ""
    else
      write_check "STATE-003" "state" "$state_file" "FAIL" "artist/album/MBID state values mismatch" "artist=$artist_value album=$album_value mbid=$mbid_value"
    fi
  fi

  if [ -d "$DEST_DIR" ]; then
    audio_count="$(count_audio_files_at "$DEST_DIR")"
    flac_count="$(count_flac_files_at "$DEST_DIR")"

    if [ "$audio_count" -gt 0 ]; then
      write_check "MEDIA-001" "media" "$DEST_DIR" "OK" "audio files found in destination" "audio=$audio_count flac=$flac_count"
    else
      write_check "MEDIA-001" "media" "$DEST_DIR" "FAIL" "no audio files found in destination" ""
    fi

    write_current_manifest
    write_check "MANIFEST-001" "manifest" "$CURRENT_MANIFEST" "OK" "current transition validation manifest written" ""

    if command -v metaflac >/dev/null 2>&1; then
      validate_tags_basic
    else
      write_check "TAG-SKIP" "tags" "$DEST_DIR" "WARN" "metaflac not available; skipping tag validation" ""
    fi
  fi

  latest_apply_tsv="$(latest_file "$RAW_DIR" "music_staging_transition_apply_*_to_${TARGET_STATE}_${SAFE_ALBUM_NAME}_*.tsv")"
  latest_apply_report="$(latest_file "$REPORT_DIR" "music_staging_transition_apply_*_to_${TARGET_STATE}_${SAFE_ALBUM_NAME}_report_*.txt")"

  if [ -n "$latest_apply_tsv" ] && [ -f "$latest_apply_tsv" ]; then
    apply_fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$latest_apply_tsv")"

    if [ "$apply_fail_count" -eq 0 ]; then
      write_check "APPLY-001" "apply" "$latest_apply_tsv" "OK" "latest transition apply TSV has no failures" ""
    else
      write_check "APPLY-001" "apply" "$latest_apply_tsv" "FAIL" "latest transition apply TSV has failures" "failures=$apply_fail_count"
    fi
  else
    write_check "APPLY-001" "apply" "missing" "FAIL" "latest transition apply TSV missing" ""
  fi

  if [ -n "$latest_apply_report" ] && [ -f "$latest_apply_report" ]; then
    if grep -F "Interpretation: music staging transition applied successfully" "$latest_apply_report" >/dev/null 2>&1; then
      write_check "APPLY-002" "apply" "$latest_apply_report" "OK" "latest transition apply report passed" ""
    else
      write_check "APPLY-002" "apply" "$latest_apply_report" "FAIL" "latest transition apply report did not pass" ""
    fi
  else
    write_check "APPLY-002" "apply" "missing" "FAIL" "latest transition apply report missing" ""
  fi

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$TSV")"
  warn_count="$(awk -F '\t' 'NR > 1 && $4 == "WARN" { c++ } END { print c+0 }' "$TSV")"

  {
    printf '%s\n' '## Validation TSV'
    printf '\n'
    printf '%s\n' '```text'
    column -t -s $'\t' "$TSV" 2>/dev/null || cat "$TSV"
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' '## Summary'
    printf '\n'
    printf 'Failures: %s\n' "$fail_count"
    printf 'Warnings: %s\n' "$warn_count"
    if [ "$fail_count" -eq 0 ]; then
      printf '%s\n' 'Interpretation: music staging transition validation passed.'
    else
      printf '%s\n' 'Interpretation: music staging transition validation failed.'
    fi
    printf '\n'

    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
    printf '%s\n' "- Current manifest: $CURRENT_MANIFEST"
  } >> "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    log "Music staging transition validation completed with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  log "Music staging transition validation completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
