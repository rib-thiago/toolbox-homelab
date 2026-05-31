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

ALBUM_DIR="${1:-}"
MBID="${2:-}"
EXPECTED_ARTIST="${3:-}"
EXPECTED_ALBUM="${4:-}"
EXPECTED_CHANGED_MIN="${5:-1}"

ALBUM_NAME=""
SAFE_ALBUM_NAME=""

REPORT=""
TSV=""

ERROR_PATTERNS='error loading plugin|PluginImportError|ModuleNotFoundError|Could not import plugin|No module named|Traceback|Input/output error|I/O error|Read-only file system|No matching release found|No matching release'

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
  validate-music-staging-flac-metadata-write.sh <album_dir> <mbid> <expected_artist> <expected_album> [expected_changed_min]

Example:
  validate-music-staging-flac-metadata-write.sh \
    "/srv/media/music-staging/reviewing/[1971] Thembi" \
    "34497839-9158-4c6f-8945-7f543276ea3e" \
    "Pharoah Sanders" \
    "Thembi" \
    "1"

Safety:
  Validation only. Does not run Beets, write tags, copy files, move files, delete files or modify /srv/media/music.
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

  REPORT="$REPORT_DIR/music_staging_flac_metadata_write_validation_${SAFE_ALBUM_NAME}_report_$STAMP.txt"
  TSV="$RAW_DIR/music_staging_flac_metadata_write_validation_${SAFE_ALBUM_NAME}_$STAMP.tsv"
}

latest_file() {
  local dir="$1"
  local pattern="$2"

  find "$dir" -maxdepth 1 -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | head -n 1 \
    | cut -d' ' -f2-
}

extract_report_path() {
  local report="$1"
  local label="$2"

  awk -F': ' -v label="$label" '
    index($0, label ": ") == 1 {
      print $2
      exit
    }
  ' "$report"
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

count_flac_files() {
  find "$ALBUM_DIR" -type f -iname '*.flac' | wc -l | tr -d ' '
}

write_current_manifest() {
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

write_current_tags() {
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

count_manifest_rows() {
  local manifest="$1"

  awk 'NR > 1 { c++ } END { print c+0 }' "$manifest"
}

count_changed_checksums() {
  local before_manifest="$1"
  local after_manifest="$2"

  awk -F '\t' '
    NR == FNR && FNR > 1 {
      before[$1]=$5
      next
    }
    FNR > 1 && before[$1] != "" && before[$1] != $5 {
      changed++
    }
    END {
      print changed+0
    }
  ' "$before_manifest" "$after_manifest"
}

count_changed_sizes() {
  local before_manifest="$1"
  local after_manifest="$2"

  awk -F '\t' '
    NR == FNR && FNR > 1 {
      before[$1]=$3
      next
    }
    FNR > 1 && before[$1] != "" && before[$1] != $3 {
      changed++
    }
    END {
      print changed+0
    }
  ' "$before_manifest" "$after_manifest"
}

count_duration_mismatches() {
  local before_manifest="$1"
  local after_manifest="$2"

  awk -F '\t' '
    function rounded(x) {
      return int(x + 0.5)
    }
    NR == FNR && FNR > 1 {
      before[$1]=rounded($4)
      next
    }
    FNR > 1 && before[$1] != "" && before[$1] != rounded($4) {
      changed++
    }
    END {
      print changed+0
    }
  ' "$before_manifest" "$after_manifest"
}

count_tag_value_files() {
  local tags_file="$1"
  local field_regex="$2"
  local expected_value="$3"

  awk -F '\t' -v field_regex="$field_regex" -v expected="$expected_value" '
    NR > 1 {
      field=toupper($2)
      if (field ~ field_regex && $3 == expected) {
        files[$1]=1
      }
    }
    END {
      for (f in files) c++
      print c+0
    }
  ' "$tags_file"
}

count_mbid_files() {
  local tags_file="$1"
  local expected_mbid="$2"

  awk -F '\t' -v expected="$expected_mbid" '
    NR > 1 && $3 == expected {
      files[$1]=1
    }
    END {
      for (f in files) c++
      print c+0
    }
  ' "$tags_file"
}

count_field_files() {
  local tags_file="$1"
  local field_regex="$2"

  awk -F '\t' -v field_regex="$field_regex" '
    NR > 1 {
      field=toupper($2)
      if (field ~ field_regex && $3 != "") {
        files[$1]=1
      }
    }
    END {
      for (f in files) c++
      print c+0
    }
  ' "$tags_file"
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
      sed -n '1,220p' "$file"
    else
      printf 'missing: %s\n' "$file"
    fi
    printf '%s\n' '```'
  } >> "$REPORT"
}

main() {
  local flac_count
  local latest_apply_report
  local latest_apply_tsv
  local live_log
  local backup_dir
  local before_manifest
  local after_manifest
  local before_tags
  local after_tags
  local current_manifest
  local current_tags
  local apply_fail_count
  local apply_warn_count
  local report_fail_count
  local report_warn_count
  local before_count
  local after_count
  local current_count
  local changed_checksums
  local changed_sizes
  local duration_mismatches
  local album_count
  local artist_count
  local albumartist_count
  local mbid_count
  local title_count
  local tracknumber_count
  local backup_count
  local runtime_errors
  local fail_count
  local warn_count

  require_lib_contract
  validate_args
  init_paths

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting FLAC metadata write validation."

  latest_apply_report="$(latest_file "$REPORT_DIR" "music_staging_flac_metadata_write_apply_${SAFE_ALBUM_NAME}_report_*.txt")"
  latest_apply_tsv="$(latest_file "$RAW_DIR" "music_staging_flac_metadata_write_apply_${SAFE_ALBUM_NAME}_*.tsv")"

  if [ -n "$latest_apply_report" ] && [ -f "$latest_apply_report" ]; then
    live_log="$(extract_report_path "$latest_apply_report" "Live log")"
    backup_dir="$(extract_report_path "$latest_apply_report" "Backup dir")"
    before_manifest="$(extract_report_path "$latest_apply_report" "Before manifest")"
    after_manifest="$(extract_report_path "$latest_apply_report" "After manifest")"
    before_tags="$(extract_report_path "$latest_apply_report" "Before tags")"
    after_tags="$(extract_report_path "$latest_apply_report" "After tags")"
  else
    live_log=""
    backup_dir=""
    before_manifest=""
    after_manifest=""
    before_tags=""
    after_tags=""
  fi

  current_manifest="$RAW_DIR/music_staging_flac_metadata_write_validation_${SAFE_ALBUM_NAME}_current_files_$STAMP.tsv"
  current_tags="$RAW_DIR/music_staging_flac_metadata_write_validation_${SAFE_ALBUM_NAME}_current_tags_$STAMP.tsv"

  tsv_row \
    "check_id" \
    "category" \
    "target" \
    "status" \
    "message" \
    "details" > "$TSV"

  {
    printf '%s\n' '# Music Staging FLAC Metadata Write Validation'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Album directory: %s\n' "$ALBUM_DIR"
    printf 'Album name: %s\n' "$ALBUM_NAME"
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf 'Expected MBID: %s\n' "$MBID"
    printf 'Expected changed min: %s\n' "$EXPECTED_CHANGED_MIN"
    printf 'Latest apply report: %s\n' "$latest_apply_report"
    printf 'Latest apply TSV: %s\n' "$latest_apply_tsv"
    printf 'Live log: %s\n' "$live_log"
    printf 'Backup dir: %s\n' "$backup_dir"
    printf 'Before manifest: %s\n' "$before_manifest"
    printf 'After manifest: %s\n' "$after_manifest"
    printf 'Before tags: %s\n' "$before_tags"
    printf 'After tags: %s\n' "$after_tags"
    printf 'Current manifest: %s\n' "$current_manifest"
    printf 'Current tags: %s\n' "$current_tags"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: validation only. This script does not run Beets, write tags, copy files, move files or modify /srv/media/music.'
    printf '\n'
  } > "$REPORT"

  flac_count="$(count_flac_files)"

  if [ "$flac_count" -gt 0 ]; then
    write_check "PRE-001" "preflight" "$ALBUM_DIR" "OK" "FLAC files found" "$flac_count"
  else
    write_check "PRE-001" "preflight" "$ALBUM_DIR" "FAIL" "no FLAC files found" ""
  fi

  if [ -n "$latest_apply_report" ] && [ -f "$latest_apply_report" ]; then
    write_check "FILE-001" "file" "$latest_apply_report" "OK" "latest apply report found" ""
  else
    write_check "FILE-001" "file" "$latest_apply_report" "FAIL" "latest apply report missing" ""
  fi

  if [ -n "$latest_apply_tsv" ] && [ -f "$latest_apply_tsv" ]; then
    write_check "FILE-002" "file" "$latest_apply_tsv" "OK" "latest apply TSV found" ""
  else
    write_check "FILE-002" "file" "$latest_apply_tsv" "FAIL" "latest apply TSV missing" ""
  fi

  for f in "$live_log" "$before_manifest" "$after_manifest" "$before_tags" "$after_tags"; do
    if [ -n "$f" ] && [ -f "$f" ]; then
      write_check "FILE-ARTIFACT" "file" "$f" "OK" "apply artifact found" ""
    else
      write_check "FILE-ARTIFACT" "file" "${f:-missing}" "FAIL" "apply artifact missing" ""
    fi
  done

  if [ -n "$backup_dir" ] && [ -d "$backup_dir" ]; then
    backup_count="$(find "$backup_dir" -type f -iname '*.flac' | wc -l | tr -d ' ')"
    if [ "$backup_count" -eq "$flac_count" ]; then
      write_check "BACKUP-001" "backup" "$backup_dir" "OK" "rollback backup count matches FLAC count" "backup=$backup_count flac=$flac_count"
    else
      write_check "BACKUP-001" "backup" "$backup_dir" "FAIL" "rollback backup count mismatch" "backup=$backup_count flac=$flac_count"
    fi
  else
    write_check "BACKUP-001" "backup" "${backup_dir:-missing}" "FAIL" "rollback backup dir missing" ""
  fi

  if [ -n "$latest_apply_tsv" ] && [ -f "$latest_apply_tsv" ]; then
    apply_fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$latest_apply_tsv")"
    apply_warn_count="$(awk -F '\t' 'NR > 1 && $4 == "WARN" { c++ } END { print c+0 }' "$latest_apply_tsv")"

    if [ "$apply_fail_count" -eq 0 ]; then
      write_check "APPLY-FAILS" "apply" "$latest_apply_tsv" "OK" "apply TSV has no failures" "failures=$apply_fail_count"
    else
      write_check "APPLY-FAILS" "apply" "$latest_apply_tsv" "FAIL" "apply TSV has failures" "failures=$apply_fail_count"
    fi

    if [ "$apply_warn_count" -eq 0 ]; then
      write_check "APPLY-WARNS" "apply" "$latest_apply_tsv" "OK" "apply TSV has no warnings" "warnings=$apply_warn_count"
    else
      write_check "APPLY-WARNS" "apply" "$latest_apply_tsv" "WARN" "apply TSV has warnings" "warnings=$apply_warn_count"
    fi
  fi

  if [ -n "$latest_apply_report" ] && [ -f "$latest_apply_report" ]; then
    if grep -F "Interpretation: controlled FLAC metadata write completed without failures" "$latest_apply_report" >/dev/null 2>&1; then
      write_check "APPLY-REPORT" "apply" "$latest_apply_report" "OK" "apply report interpretation passed" ""
    else
      write_check "APPLY-REPORT" "apply" "$latest_apply_report" "FAIL" "apply report interpretation did not pass" ""
    fi
  fi

  if [ -n "$live_log" ] && [ -f "$live_log" ]; then
    runtime_errors="$(grep -Ei "$ERROR_PATTERNS" "$live_log" || true)"

    if [ -z "$runtime_errors" ]; then
      write_check "LOG-001" "log" "$live_log" "OK" "no runtime/plugin/I/O/no-match errors found" ""
    else
      write_check "LOG-001" "log" "$live_log" "FAIL" "runtime/plugin/I/O/no-match errors found" "$(printf '%s' "$runtime_errors" | tr '\n' ' ')"
    fi

    if grep -F "Sending event: write" "$live_log" >/dev/null 2>&1 && grep -F "Sending event: after_write" "$live_log" >/dev/null 2>&1; then
      write_check "LOG-002" "log" "$live_log" "OK" "write and after_write events detected" ""
    else
      write_check "LOG-002" "log" "$live_log" "FAIL" "write/after_write events missing" ""
    fi

    if grep -F "album_imported" "$live_log" >/dev/null 2>&1; then
      write_check "LOG-003" "log" "$live_log" "OK" "album_imported event detected" ""
    else
      write_check "LOG-003" "log" "$live_log" "WARN" "album_imported event missing" ""
    fi

    if grep -F "$MBID" "$live_log" >/dev/null 2>&1 && grep -F "$EXPECTED_ARTIST" "$live_log" >/dev/null 2>&1 && grep -F "$EXPECTED_ALBUM" "$live_log" >/dev/null 2>&1; then
      write_check "LOG-004" "log" "$live_log" "OK" "expected MBID/artist/album found in log" ""
    else
      write_check "LOG-004" "log" "$live_log" "FAIL" "expected MBID/artist/album missing from log" ""
    fi
  fi

  if [ -n "$before_manifest" ] && [ -f "$before_manifest" ] && [ -n "$after_manifest" ] && [ -f "$after_manifest" ]; then
    before_count="$(count_manifest_rows "$before_manifest")"
    after_count="$(count_manifest_rows "$after_manifest")"
    changed_checksums="$(count_changed_checksums "$before_manifest" "$after_manifest")"
    changed_sizes="$(count_changed_sizes "$before_manifest" "$after_manifest")"
    duration_mismatches="$(count_duration_mismatches "$before_manifest" "$after_manifest")"

    if [ "$before_count" -eq "$flac_count" ] && [ "$after_count" -eq "$flac_count" ]; then
      write_check "MANIFEST-001" "manifest" "$after_manifest" "OK" "before/after manifest row counts match FLAC count" "before=$before_count after=$after_count flac=$flac_count"
    else
      write_check "MANIFEST-001" "manifest" "$after_manifest" "FAIL" "manifest row count mismatch" "before=$before_count after=$after_count flac=$flac_count"
    fi

    if [ "$changed_checksums" -ge "$EXPECTED_CHANGED_MIN" ]; then
      write_check "MANIFEST-002" "manifest" "$after_manifest" "OK" "checksums changed after metadata write" "changed=$changed_checksums expected_min=$EXPECTED_CHANGED_MIN"
    else
      write_check "MANIFEST-002" "manifest" "$after_manifest" "WARN" "few or no checksum changes detected" "changed=$changed_checksums expected_min=$EXPECTED_CHANGED_MIN"
    fi

    if [ "$duration_mismatches" -eq 0 ]; then
      write_check "MANIFEST-003" "manifest" "$after_manifest" "OK" "rounded durations unchanged" ""
    else
      write_check "MANIFEST-003" "manifest" "$after_manifest" "FAIL" "audio durations changed unexpectedly" "duration_mismatches=$duration_mismatches"
    fi

    write_check "MANIFEST-004" "manifest" "$after_manifest" "OK" "size changes recorded for metadata rewrite context" "changed_sizes=$changed_sizes"
  fi

  write_current_manifest "$current_manifest"
  write_current_tags "$current_tags"

  current_count="$(count_manifest_rows "$current_manifest")"
  if [ "$current_count" -eq "$flac_count" ]; then
    write_check "CURRENT-001" "current" "$current_manifest" "OK" "current manifest row count matches FLAC count" "current=$current_count flac=$flac_count"
  else
    write_check "CURRENT-001" "current" "$current_manifest" "FAIL" "current manifest row count mismatch" "current=$current_count flac=$flac_count"
  fi

  if [ -n "$after_manifest" ] && [ -f "$after_manifest" ]; then
    if diff -u "$after_manifest" "$current_manifest" >/dev/null 2>&1; then
      write_check "CURRENT-002" "current" "$current_manifest" "OK" "current manifest matches apply after manifest" ""
    else
      write_check "CURRENT-002" "current" "$current_manifest" "WARN" "current manifest differs from apply after manifest" "album may have changed after apply"
    fi
  fi

  album_count="$(count_tag_value_files "$current_tags" '^ALBUM$' "$EXPECTED_ALBUM")"
  artist_count="$(count_tag_value_files "$current_tags" '^ARTIST$' "$EXPECTED_ARTIST")"
  albumartist_count="$(count_tag_value_files "$current_tags" '^ALBUMARTIST$' "$EXPECTED_ARTIST")"
  mbid_count="$(count_mbid_files "$current_tags" "$MBID")"
  title_count="$(count_field_files "$current_tags" '^TITLE$')"
  tracknumber_count="$(count_field_files "$current_tags" '^TRACKNUMBER$')"

  if [ "$album_count" -eq "$flac_count" ]; then
    write_check "TAG-ALBUM" "tags" "$current_tags" "OK" "ALBUM matches expected album for all FLACs" "count=$album_count"
  else
    write_check "TAG-ALBUM" "tags" "$current_tags" "FAIL" "ALBUM mismatch" "count=$album_count expected=$flac_count"
  fi

  if [ "$artist_count" -eq "$flac_count" ]; then
    write_check "TAG-ARTIST" "tags" "$current_tags" "OK" "ARTIST matches expected artist for all FLACs" "count=$artist_count"
  else
    write_check "TAG-ARTIST" "tags" "$current_tags" "FAIL" "ARTIST mismatch" "count=$artist_count expected=$flac_count"
  fi

  if [ "$albumartist_count" -eq "$flac_count" ]; then
    write_check "TAG-ALBUMARTIST" "tags" "$current_tags" "OK" "ALBUMARTIST matches expected artist for all FLACs" "count=$albumartist_count"
  else
    write_check "TAG-ALBUMARTIST" "tags" "$current_tags" "WARN" "ALBUMARTIST missing or differs on some FLACs" "count=$albumartist_count expected=$flac_count"
  fi

  if [ "$mbid_count" -eq "$flac_count" ]; then
    write_check "TAG-MBID" "tags" "$current_tags" "OK" "expected MusicBrainz release MBID found for all FLACs" "count=$mbid_count"
  else
    write_check "TAG-MBID" "tags" "$current_tags" "WARN" "expected MBID not found on all FLACs" "count=$mbid_count expected=$flac_count"
  fi

  if [ "$title_count" -eq "$flac_count" ]; then
    write_check "TAG-TITLE" "tags" "$current_tags" "OK" "TITLE present for all FLACs" "count=$title_count"
  else
    write_check "TAG-TITLE" "tags" "$current_tags" "FAIL" "TITLE missing on some FLACs" "count=$title_count expected=$flac_count"
  fi

  if [ "$tracknumber_count" -eq "$flac_count" ]; then
    write_check "TAG-TRACKNUMBER" "tags" "$current_tags" "OK" "TRACKNUMBER present for all FLACs" "count=$tracknumber_count"
  else
    write_check "TAG-TRACKNUMBER" "tags" "$current_tags" "FAIL" "TRACKNUMBER missing on some FLACs" "count=$tracknumber_count expected=$flac_count"
  fi

  append_file_excerpt "Validation TSV" "$TSV"
  append_file_excerpt "Latest apply report" "$latest_apply_report"
  append_file_excerpt "Latest live log" "$live_log"
  append_file_excerpt "Current tags" "$current_tags"

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
      printf '%s\n' 'Interpretation: controlled FLAC metadata write validation failed. Do not proceed to next album; inspect logs and rollback backup.'
    else
      printf '%s\n' 'Interpretation: controlled FLAC metadata write validation passed. Review warnings before proceeding.'
    fi
    printf '\n'
    printf '%s\n' 'Rollback source:'
    printf '%s\n' "${backup_dir:-missing}"
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
    printf '%s\n' "- Current manifest: $current_manifest"
    printf '%s\n' "- Current tags: $current_tags"
  } >> "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    log "FLAC metadata write validation completed with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  log "FLAC metadata write validation completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
