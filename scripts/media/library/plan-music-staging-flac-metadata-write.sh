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
PLAN_DIR="$SHARED_DIR/library-db/plans/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"
SNAPSHOT_BASE="$SHARED_DIR/library-db/snapshots/media/staging"

ALBUM_DIR="${1:-}"
MBID="${2:-}"
EXPECTED_ARTIST="${3:-}"
EXPECTED_ALBUM="${4:-}"

ALBUM_NAME=""
SAFE_ALBUM_NAME=""

REPORT=""
TSV=""
FILE_MANIFEST=""
TAG_SNAPSHOT_PLAN=""
BACKUP_DIR=""

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
  plan-music-staging-flac-metadata-write.sh <album_dir> <mbid> <expected_artist> <expected_album>

Example:
  plan-music-staging-flac-metadata-write.sh \
    "/srv/media/music-staging/reviewing/[1971] Thembi" \
    "34497839-9158-4c6f-8945-7f543276ea3e" \
    "Pharoah Sanders" \
    "Thembi"

Safety:
  Plan only. Does not run Beets in write mode, write tags, copy files, move files, delete files, or modify /srv/media/music.
EOF
}

validate_args() {
  if [ -z "$ALBUM_DIR" ] || [ -z "$MBID" ] || [ -z "$EXPECTED_ARTIST" ] || [ -z "$EXPECTED_ALBUM" ]; then
    usage >&2
    fail "Missing required arguments."
  fi

  if [ ! -d "$ALBUM_DIR" ]; then
    fail "Album directory not found: $ALBUM_DIR"
  fi

  if ! command -v metaflac >/dev/null 2>&1; then
    fail "metaflac command not found."
  fi

  if ! command -v sha256sum >/dev/null 2>&1; then
    fail "sha256sum command not found."
  fi

  if ! command -v ffprobe >/dev/null 2>&1; then
    fail "ffprobe command not found."
  fi
}

init_paths() {
  ALBUM_NAME="$(basename "$ALBUM_DIR")"
  SAFE_ALBUM_NAME="$(printf '%s' "$ALBUM_NAME" | tr ' /[]()' '_______' | tr -cd '[:alnum:]_.-')"

  REPORT="$REPORT_DIR/music_staging_flac_metadata_write_plan_${SAFE_ALBUM_NAME}_report_$STAMP.txt"
  TSV="$PLAN_DIR/music_staging_flac_metadata_write_plan_${SAFE_ALBUM_NAME}_$STAMP.tsv"
  FILE_MANIFEST="$PLAN_DIR/music_staging_flac_metadata_write_plan_${SAFE_ALBUM_NAME}_files_$STAMP.tsv"
  TAG_SNAPSHOT_PLAN="$PLAN_DIR/music_staging_flac_metadata_write_plan_${SAFE_ALBUM_NAME}_current_tags_$STAMP.tsv"
  BACKUP_DIR="$SNAPSHOT_BASE/flac-metadata-write-${SAFE_ALBUM_NAME}-$STAMP/files"
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

count_non_flac_audio_files() {
  find "$ALBUM_DIR" -type f \( -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.ogg' -o -iname '*.opus' -o -iname '*.wav' -o -iname '*.aiff' \) | wc -l | tr -d ' '
}

write_file_manifest() {
  local file
  local rel
  local size
  local duration
  local checksum

  tsv_row \
    "relative_path" \
    "absolute_path" \
    "size_bytes" \
    "duration_seconds" \
    "sha256" > "$FILE_MANIFEST"

  while IFS= read -r -d '' file; do
    rel="${file#$ALBUM_DIR/}"
    size="$(stat -c '%s' "$file" 2>/dev/null || printf '')"
    duration="$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$file" 2>/dev/null || printf '')"
    checksum="$(sha256sum "$file" | awk '{print $1}')"

    tsv_row "$rel" "$file" "$size" "$duration" "$checksum" >> "$FILE_MANIFEST"
  done < <(find "$ALBUM_DIR" -type f -iname '*.flac' -print0 | sort -z)
}

write_tag_snapshot_plan() {
  local file
  local rel
  local field
  local value

  tsv_row \
    "relative_path" \
    "field" \
    "value" > "$TAG_SNAPSHOT_PLAN"

  while IFS= read -r -d '' file; do
    rel="${file#$ALBUM_DIR/}"

    while IFS='=' read -r field value; do
      if [ -n "$field" ]; then
        tsv_row "$rel" "$field" "${value:-}" >> "$TAG_SNAPSHOT_PLAN"
      fi
    done < <(metaflac --export-tags-to=- "$file" 2>/dev/null || true)
  done < <(find "$ALBUM_DIR" -type f -iname '*.flac' -print0 | sort -z)
}

main() {
  local flac_count
  local non_flac_audio_count
  local latest_mbid_apply_report
  local latest_mbid_validation_report
  local latest_mbid_validation_tsv

  require_lib_contract
  validate_args
  init_paths

  mkdir -p "$REPORT_DIR" "$PLAN_DIR" "$RAW_DIR" "$(dirname "$BACKUP_DIR")"

  log "Generating FLAC metadata write plan."

  tsv_row \
    "step_id" \
    "phase" \
    "target" \
    "status" \
    "action" \
    "notes" > "$TSV"

  flac_count="$(count_flac_files)"
  non_flac_audio_count="$(count_non_flac_audio_files)"

  latest_mbid_apply_report="$(latest_file "$REPORT_DIR" "music_staging_beets_mbid_dry_run_apply_${SAFE_ALBUM_NAME}_report_*.txt")"
  latest_mbid_validation_report="$(latest_file "$REPORT_DIR" "music_staging_beets_mbid_dry_run_validation_${SAFE_ALBUM_NAME}_report_*.txt")"
  latest_mbid_validation_tsv="$(latest_file "$RAW_DIR" "music_staging_beets_mbid_dry_run_validation_${SAFE_ALBUM_NAME}_*.tsv")"

  write_step "PRE-001" "preflight" "$ALBUM_DIR" "OK" "album directory exists" "$ALBUM_NAME"
  write_step "PRE-002" "preflight" "$MBID" "OK" "MusicBrainz release MBID supplied" ""
  write_step "PRE-003" "preflight" "$EXPECTED_ARTIST" "OK" "expected artist supplied" ""
  write_step "PRE-004" "preflight" "$EXPECTED_ALBUM" "OK" "expected album supplied" ""

  if [ "$flac_count" -gt 0 ]; then
    write_step "PRE-005" "preflight" "$ALBUM_DIR" "OK" "FLAC files found" "$flac_count"
  else
    write_step "PRE-005" "preflight" "$ALBUM_DIR" "FAIL" "no FLAC files found" ""
  fi

  if [ "$non_flac_audio_count" -eq 0 ]; then
    write_step "PRE-006" "preflight" "$ALBUM_DIR" "OK" "no non-FLAC audio files detected" ""
  else
    write_step "PRE-006" "preflight" "$ALBUM_DIR" "WARN" "non-FLAC audio files detected; this plan is FLAC-only" "$non_flac_audio_count"
  fi

  if [ -n "$latest_mbid_validation_report" ]; then
    write_step "EVID-001" "evidence" "$latest_mbid_validation_report" "OK" "latest MBID dry-run validation report found" ""
  else
    write_step "EVID-001" "evidence" "$latest_mbid_validation_report" "WARN" "no MBID dry-run validation report found" "run validate-music-staging-beets-mbid-dry-run.sh first if needed"
  fi

  if [ -n "$latest_mbid_apply_report" ]; then
    write_step "EVID-002" "evidence" "$latest_mbid_apply_report" "OK" "latest MBID dry-run apply report found" ""
  else
    write_step "EVID-002" "evidence" "$latest_mbid_apply_report" "WARN" "no MBID dry-run apply report found" ""
  fi

  write_step "PLAN-001" "snapshot" "$FILE_MANIFEST" "PLANNED" "record pre-write FLAC manifest" "relative path, size, duration, sha256"
  write_step "PLAN-002" "snapshot" "$TAG_SNAPSHOT_PLAN" "PLANNED" "record pre-write FLAC tags" "metaflac export before writing"
  write_step "PLAN-003" "backup" "$BACKUP_DIR" "PLANNED" "copy target FLACs before metadata write" "rollback source"
  write_step "PLAN-004" "write" "$ALBUM_DIR" "PLANNED" "run controlled Beets metadata write" "must remove -W only in apply phase; must keep no move/copy policy"
  write_step "PLAN-005" "validate" "$ALBUM_DIR" "PLANNED" "validate post-write tags and checksums" "confirm expected artist/album/MBID and changed files"
  write_step "PLAN-006" "rollback" "$BACKUP_DIR" "PLANNED" "rollback possible from copied FLACs" "apply script must not delete backup"

  write_file_manifest
  write_tag_snapshot_plan

  {
    printf '%s\n' '# Music Staging FLAC Metadata Write Plan'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Album directory: %s\n' "$ALBUM_DIR"
    printf 'Album name: %s\n' "$ALBUM_NAME"
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf 'MusicBrainz release MBID: %s\n' "$MBID"
    printf 'FLAC files: %s\n' "$flac_count"
    printf 'Non-FLAC audio files: %s\n' "$non_flac_audio_count"
    printf 'Backup dir planned: %s\n' "$BACKUP_DIR"
    printf 'Report: %s\n' "$REPORT"
    printf 'Plan TSV: %s\n' "$TSV"
    printf 'File manifest: %s\n' "$FILE_MANIFEST"
    printf 'Current tag snapshot plan: %s\n' "$TAG_SNAPSHOT_PLAN"
    printf '\n'
    printf '%s\n' 'Safety: plan only. This script does not run Beets in write mode, write tags, copy files, move files, delete files or modify /srv/media/music.'
    printf '\n'

    printf '%s\n' '## Evidence'
    printf '\n'
    printf 'Latest MBID dry-run apply report: %s\n' "${latest_mbid_apply_report:-missing}"
    printf 'Latest MBID dry-run validation report: %s\n' "${latest_mbid_validation_report:-missing}"
    printf 'Latest MBID dry-run validation TSV: %s\n' "${latest_mbid_validation_tsv:-missing}"
    printf '\n'

    printf '%s\n' '## Planned controlled write policy'
    printf '\n'
    printf '%s\n' '- Only FLAC files in the supplied album directory are in scope.'
    printf '%s\n' '- A pre-write manifest with sha256 hashes is generated.'
    printf '%s\n' '- A pre-write tag snapshot is generated with metaflac.'
    printf '%s\n' '- The apply phase must copy all target FLAC files to the planned backup directory before writing.'
    printf '%s\n' '- The apply phase may write metadata only after explicit APPLY confirmation.'
    printf '%s\n' '- The apply phase must not move files to /srv/media/music.'
    printf '%s\n' '- The apply phase must not delete source files or backups.'
    printf '%s\n' '- The validate phase must compare before/after state and confirm expected metadata.'
    printf '\n'

    printf '%s\n' '## Planned Beets write command shape'
    printf '\n'
    printf '%s\n' '```bash'
    printf 'BEETSDIR=%q beet -v import -C %q\n' "$SHARED_DIR/beets/media-staging" "$ALBUM_DIR"
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' 'Note: -W is intentionally absent only in the future apply script. This plan does not execute that command.'
    printf '\n'

    printf '%s\n' '## Rollback concept'
    printf '\n'
    printf '%s\n' 'If validation fails, rollback should restore the backed-up FLAC files over the album directory files, then re-run validation.'
    printf '\n'

    printf '%s\n' '## Plan TSV preview'
    printf '\n'
    printf '%s\n' '```text'
    column -t -s $'\t' "$TSV" 2>/dev/null || cat "$TSV"
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- Plan TSV: $TSV"
    printf '%s\n' "- File manifest: $FILE_MANIFEST"
    printf '%s\n' "- Current tag snapshot plan: $TAG_SNAPSHOT_PLAN"
  } > "$REPORT"

  if awk -F '\t' 'NR > 1 && $4 == "FAIL" { found=1 } END { exit found ? 0 : 1 }' "$TSV"; then
    log "FLAC metadata write plan generated with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  log "FLAC metadata write plan generated."
  log "Report: $REPORT"
  log "TSV: $TSV"
  log "File manifest: $FILE_MANIFEST"
  log "Current tag snapshot plan: $TAG_SNAPSHOT_PLAN"
}

main "$@"
