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
PLAN_DIR="$SHARED_DIR/library-db/plans/media/staging"
SNAPSHOT_BASE="$SHARED_DIR/library-db/snapshots/media/staging"

APPLY_MODE="${1:-}"
ALBUM_DIR="${2:-}"
MBID="${3:-}"
EXPECTED_ARTIST="${4:-}"
EXPECTED_ALBUM="${5:-}"

ALBUM_NAME=""
SAFE_ALBUM_NAME=""

BEETS_SANDBOX_ROOT="$SHARED_DIR/beets/media-staging"

REPORT=""
TSV=""
LIVE_LOG=""
BACKUP_DIR=""
BEFORE_MANIFEST=""
AFTER_MANIFEST=""
BEFORE_TAGS=""
AFTER_TAGS=""

ERROR_PATTERNS='error loading plugin|PluginImportError|ModuleNotFoundError|Could not import plugin|No module named|Traceback|Input/output error|I/O error|Read-only file system'
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

usage() {
  cat <<'EOF'
Usage:
  apply-music-staging-flac-metadata-write.sh --apply <album_dir> <mbid> <expected_artist> <expected_album>

Example:
  apply-music-staging-flac-metadata-write.sh \
    --apply \
    "/srv/media/music-staging/reviewing/[1971] Thembi" \
    "34497839-9158-4c6f-8945-7f543276ea3e" \
    "Pharoah Sanders" \
    "Thembi"

Safety:
  Copies FLAC files to a rollback backup before writing.
  Writes metadata only to FLAC files in the supplied staging album directory.
  Runs Beets with -C -w: no copy, explicit tag write.
  Does not move files to /srv/media/music.
  Does not delete source files or backups.
EOF
}

validate_args() {
  if [ "$APPLY_MODE" != "--apply" ] || [ -z "$ALBUM_DIR" ] || [ -z "$MBID" ] || [ -z "$EXPECTED_ARTIST" ] || [ -z "$EXPECTED_ALBUM" ]; then
    usage >&2
    fail "Missing required arguments."
  fi

  if [ ! -d "$ALBUM_DIR" ]; then
    fail "Album directory not found: $ALBUM_DIR"
  fi

  if [ ! -d "$BEETS_SANDBOX_ROOT" ]; then
    fail "Beets sandbox root not found: $BEETS_SANDBOX_ROOT"
  fi

  if ! command -v beet >/dev/null 2>&1; then
    fail "beet command not found."
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

  REPORT="$REPORT_DIR/music_staging_flac_metadata_write_apply_${SAFE_ALBUM_NAME}_report_$STAMP.txt"
  TSV="$RAW_DIR/music_staging_flac_metadata_write_apply_${SAFE_ALBUM_NAME}_$STAMP.tsv"
  LIVE_LOG="$REPORT_DIR/flac_metadata_write_${SAFE_ALBUM_NAME}_live_$STAMP.log"

  BACKUP_DIR="$SNAPSHOT_BASE/flac-metadata-write-${SAFE_ALBUM_NAME}-$STAMP/files"

  BEFORE_MANIFEST="$RAW_DIR/music_staging_flac_metadata_write_apply_${SAFE_ALBUM_NAME}_before_files_$STAMP.tsv"
  AFTER_MANIFEST="$RAW_DIR/music_staging_flac_metadata_write_apply_${SAFE_ALBUM_NAME}_after_files_$STAMP.tsv"
  BEFORE_TAGS="$RAW_DIR/music_staging_flac_metadata_write_apply_${SAFE_ALBUM_NAME}_before_tags_$STAMP.tsv"
  AFTER_TAGS="$RAW_DIR/music_staging_flac_metadata_write_apply_${SAFE_ALBUM_NAME}_after_tags_$STAMP.tsv"
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

write_file_manifest() {
  local output="$1"
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
    "sha256" > "$output"

  while IFS= read -r -d '' file; do
    rel="${file#$ALBUM_DIR/}"
    size="$(stat -c '%s' "$file" 2>/dev/null || printf '')"
    duration="$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$file" 2>/dev/null || printf '')"
    checksum="$(sha256sum "$file" | awk '{print $1}')"

    tsv_row "$rel" "$file" "$size" "$duration" "$checksum" >> "$output"
  done < <(find "$ALBUM_DIR" -type f -iname '*.flac' -print0 | sort -z)
}

write_tag_snapshot() {
  local output="$1"
  local file
  local rel
  local field
  local value

  tsv_row \
    "relative_path" \
    "field" \
    "value" > "$output"

  while IFS= read -r -d '' file; do
    rel="${file#$ALBUM_DIR/}"

    while IFS='=' read -r field value; do
      if [ -n "$field" ]; then
        tsv_row "$rel" "$field" "${value:-}" >> "$output"
      fi
    done < <(metaflac --export-tags-to=- "$file" 2>/dev/null || true)
  done < <(find "$ALBUM_DIR" -type f -iname '*.flac' -print0 | sort -z)
}

copy_flac_backup() {
  local file
  local rel
  local dest

  mkdir -p "$BACKUP_DIR"

  while IFS= read -r -d '' file; do
    rel="${file#$ALBUM_DIR/}"
    dest="$BACKUP_DIR/$rel"
    mkdir -p "$(dirname "$dest")"
    cp -a "$file" "$dest"
  done < <(find "$ALBUM_DIR" -type f -iname '*.flac' -print0 | sort -z)
}

confirm_apply() {
  local flac_count
  local confirmation

  flac_count="$(count_flac_files)"

  printf '%s\n' "This script will WRITE FLAC metadata in staging:"
  printf '%s\n' "- Album: $ALBUM_DIR"
  printf '%s\n' "- FLAC files: $flac_count"
  printf '%s\n' "- MBID: $MBID"
  printf '%s\n' "- Expected artist: $EXPECTED_ARTIST"
  printf '%s\n' "- Expected album: $EXPECTED_ALBUM"
  printf '%s\n' "- Backup dir: $BACKUP_DIR"
  printf '%s\n' "- Command: BEETSDIR=$BEETS_SANDBOX_ROOT beet -v import -C -w <album_dir>"
  printf '%s\n' ""
  printf '%s\n' "This WILL modify FLAC tags in the staging album directory."
  printf '%s\n' "It will NOT move files to /srv/media/music."
  printf '%s\n' "It will NOT delete source files or backups."
  printf '%s\n' ""
  printf '%s\n' "At the Beets prompt, use enter Id if needed and paste:"
  printf '%s\n' "$MBID"
  printf '%s\n' "Accept only if Beets shows the expected artist/album/release."
  printf '%s\n' ""
  printf '%s' "Type APPLY to continue: "
  read -r confirmation

  if [ "$confirmation" != "APPLY" ]; then
    fail "Apply aborted by user."
  fi
}

check_latest_mbid_validation() {
  local latest_validation_report
  local latest_validation_tsv

  latest_validation_report="$(latest_file "$REPORT_DIR" "music_staging_beets_mbid_dry_run_validation_${SAFE_ALBUM_NAME}_report_*.txt")"
  latest_validation_tsv="$(latest_file "$RAW_DIR" "music_staging_beets_mbid_dry_run_validation_${SAFE_ALBUM_NAME}_*.tsv")"

  if [ -n "$latest_validation_report" ] && grep -F "Interpretation: MBID dry-run validation passed" "$latest_validation_report" >/dev/null 2>&1; then
    write_step "EVID-001" "evidence" "$latest_validation_report" "OK" "latest MBID dry-run validation passed" ""
  else
    write_step "EVID-001" "evidence" "${latest_validation_report:-missing}" "FAIL" "latest MBID dry-run validation missing or not passed" "run validate-music-staging-beets-mbid-dry-run.sh first"
  fi

  if [ -n "$latest_validation_tsv" ]; then
    write_step "EVID-002" "evidence" "$latest_validation_tsv" "OK" "latest MBID dry-run validation TSV found" ""
  else
    write_step "EVID-002" "evidence" "missing" "WARN" "latest MBID dry-run validation TSV missing" ""
  fi
}

compare_manifests() {
  local changed_count
  local total_count

  total_count="$(awk 'NR > 1 { c++ } END { print c+0 }' "$AFTER_MANIFEST")"

  changed_count="$(
    awk -F '\t' '
      NR == FNR && FNR > 1 { before[$1]=$5; next }
      FNR > 1 && before[$1] != "" && before[$1] != $5 { changed++ }
      END { print changed+0 }
    ' "$BEFORE_MANIFEST" "$AFTER_MANIFEST"
  )"

  if [ "$changed_count" -gt 0 ]; then
    write_step "VAL-005" "validate" "$AFTER_MANIFEST" "OK" "FLAC checksums changed after metadata write" "changed=$changed_count total=$total_count"
  else
    write_step "VAL-005" "validate" "$AFTER_MANIFEST" "WARN" "no FLAC checksum changes detected" "metadata may already have matched target state"
  fi
}

main() {
  local flac_count
  local backup_count
  local beet_status
  local fail_count
  local warn_count
  local found_errors
  local found_no_match
  local found_markers

  require_lib_contract
  validate_args
  init_paths
  confirm_apply

  mkdir -p "$REPORT_DIR" "$RAW_DIR" "$(dirname "$BACKUP_DIR")"

  log "Starting FLAC metadata write apply."

  tsv_row \
    "step_id" \
    "phase" \
    "target" \
    "status" \
    "action" \
    "notes" > "$TSV"

  {
    printf '%s\n' '# Music Staging FLAC Metadata Write Apply'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Album directory: %s\n' "$ALBUM_DIR"
    printf 'Album name: %s\n' "$ALBUM_NAME"
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf 'MusicBrainz release MBID: %s\n' "$MBID"
    printf 'BEETSDIR: %s\n' "$BEETS_SANDBOX_ROOT"
    printf 'Backup dir: %s\n' "$BACKUP_DIR"
    printf 'Live log: %s\n' "$LIVE_LOG"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf 'Before manifest: %s\n' "$BEFORE_MANIFEST"
    printf 'After manifest: %s\n' "$AFTER_MANIFEST"
    printf 'Before tags: %s\n' "$BEFORE_TAGS"
    printf 'After tags: %s\n' "$AFTER_TAGS"
    printf '\n'
    printf '%s\n' 'Safety: writes FLAC metadata only after backup and explicit APPLY confirmation.'
    printf '%s\n' 'This script does not move files to /srv/media/music and does not delete source files or backups.'
    printf '\n'
  } > "$REPORT"

  flac_count="$(count_flac_files)"

  if [ "$flac_count" -gt 0 ]; then
    write_step "PRE-001" "preflight" "$ALBUM_DIR" "OK" "FLAC files found" "$flac_count"
  else
    write_step "PRE-001" "preflight" "$ALBUM_DIR" "FAIL" "no FLAC files found" ""
  fi

  check_latest_mbid_validation

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$TSV")"
  if [ "$fail_count" -gt 0 ]; then
    log "Preflight failed."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  write_file_manifest "$BEFORE_MANIFEST"
  write_tag_snapshot "$BEFORE_TAGS"
  write_step "SNAP-001" "snapshot" "$BEFORE_MANIFEST" "OK" "recorded pre-write FLAC manifest" ""
  write_step "SNAP-002" "snapshot" "$BEFORE_TAGS" "OK" "recorded pre-write FLAC tags" ""

  copy_flac_backup
  backup_count="$(find "$BACKUP_DIR" -type f -iname '*.flac' | wc -l | tr -d ' ')"

  if [ "$backup_count" -eq "$flac_count" ]; then
    write_step "BACKUP-001" "backup" "$BACKUP_DIR" "OK" "copied FLAC rollback backup" "files=$backup_count"
  else
    write_step "BACKUP-001" "backup" "$BACKUP_DIR" "FAIL" "backup FLAC count mismatch" "expected=$flac_count got=$backup_count"
  fi

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$TSV")"
  if [ "$fail_count" -gt 0 ]; then
    log "Backup validation failed."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  {
    printf '%s\n' '## Beets write command'
    printf '\n'
    printf '%s\n' '```bash'
    printf 'BEETSDIR=%q beet -v import -C -w %q\n' "$BEETS_SANDBOX_ROOT" "$ALBUM_DIR"
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Interactive instruction'
    printf '\n'
    printf '%s\n' '```text'
    printf '%s\n' 'If Beets does not directly show the expected match, choose enter Id and paste:'
    printf '%s\n' "$MBID"
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf '%s\n' 'Accept only if the proposed match is coherent.'
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Live output'
    printf '\n'
    printf '%s\n' '```text'
  } >> "$REPORT"

  printf '%s\n' "Running Beets controlled metadata write."
  printf '%s\n' "Expected: $EXPECTED_ARTIST - $EXPECTED_ALBUM"
  printf '%s\n' "MBID: $MBID"
  printf '%s\n' "Live log: $LIVE_LOG"

  set +e
  env "BEETSDIR=$BEETS_SANDBOX_ROOT" beet -v import -C -w "$ALBUM_DIR" 2>&1 | tee "$LIVE_LOG"
  beet_status="${PIPESTATUS[0]}"
  set -u

  cat "$LIVE_LOG" >> "$REPORT"

  {
    printf '%s\n' '```'
    printf '\n'
  } >> "$REPORT"

  if [ "$beet_status" -eq 0 ]; then
    write_step "RUN-001" "run" "$ALBUM_DIR" "OK" "beet -v import -C -w returned success" "$LIVE_LOG"
  else
    write_step "RUN-001" "run" "$ALBUM_DIR" "FAIL" "beet -v import -C -w returned non-zero" "exit=$beet_status log=$LIVE_LOG"
  fi

  found_errors="$(grep -Ei "$ERROR_PATTERNS" "$LIVE_LOG" || true)"
  if [ -z "$found_errors" ]; then
    write_step "VAL-001" "validate" "$LIVE_LOG" "OK" "no plugin/runtime/I/O errors detected" ""
  else
    write_step "VAL-001" "validate" "$LIVE_LOG" "FAIL" "plugin/runtime/I/O errors detected" "$found_errors"
  fi

  found_no_match="$(grep -Ei "$NO_MATCH_PATTERNS" "$LIVE_LOG" || true)"
  if [ -z "$found_no_match" ]; then
    write_step "VAL-002" "validate" "$LIVE_LOG" "OK" "no MusicBrainz no-match detected" ""
  else
    write_step "VAL-002" "validate" "$LIVE_LOG" "FAIL" "MusicBrainz no-match detected" "$found_no_match"
  fi

  found_markers="$(grep -Ei "$MBID|$EXPECTED_ARTIST|$EXPECTED_ALBUM|album_imported" "$LIVE_LOG" || true)"
  if [ -n "$found_markers" ]; then
    write_step "VAL-003" "validate" "$LIVE_LOG" "OK" "expected write markers detected" "$(printf '%s' "$found_markers" | tr '\n' ' ')"
  else
    write_step "VAL-003" "validate" "$LIVE_LOG" "WARN" "expected write markers not detected" "expected=$EXPECTED_ARTIST / $EXPECTED_ALBUM / $MBID / album_imported"
  fi

  if grep -F "album_imported" "$LIVE_LOG" >/dev/null 2>&1; then
    write_step "VAL-004" "validate" "$LIVE_LOG" "OK" "album_imported event detected" ""
  else
    write_step "VAL-004" "validate" "$LIVE_LOG" "WARN" "album_imported event not detected" ""
  fi

  write_file_manifest "$AFTER_MANIFEST"
  write_tag_snapshot "$AFTER_TAGS"
  write_step "SNAP-003" "snapshot" "$AFTER_MANIFEST" "OK" "recorded post-write FLAC manifest" ""
  write_step "SNAP-004" "snapshot" "$AFTER_TAGS" "OK" "recorded post-write FLAC tags" ""

  compare_manifests

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$TSV")"
  warn_count="$(awk -F '\t' 'NR > 1 && $4 == "WARN" { c++ } END { print c+0 }' "$TSV")"

  {
    printf '%s\n' '## Summary'
    printf '\n'
    printf 'Beet exit status: %s\n' "$beet_status"
    printf 'Failures: %s\n' "$fail_count"
    printf 'Warnings: %s\n' "$warn_count"
    printf '\n'
    if [ "$fail_count" -gt 0 ]; then
      printf '%s\n' 'Interpretation: controlled FLAC metadata write completed with failures. Do not proceed; inspect backup and logs.'
    else
      printf '%s\n' 'Interpretation: controlled FLAC metadata write completed without failures. Run validate-music-staging-flac-metadata-write.sh next.'
    fi
    printf '\n'
    printf '%s\n' 'Rollback source:'
    printf '%s\n' "$BACKUP_DIR"
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
    printf '%s\n' "- Live log: $LIVE_LOG"
    printf '%s\n' "- Backup dir: $BACKUP_DIR"
    printf '%s\n' "- Before manifest: $BEFORE_MANIFEST"
    printf '%s\n' "- After manifest: $AFTER_MANIFEST"
    printf '%s\n' "- Before tags: $BEFORE_TAGS"
    printf '%s\n' "- After tags: $AFTER_TAGS"
  } >> "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    log "FLAC metadata write apply completed with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    log "Backup dir: $BACKUP_DIR"
    exit 1
  fi

  log "FLAC metadata write apply completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
  log "Live log: $LIVE_LOG"
  log "Backup dir: $BACKUP_DIR"
}

main "$@"
