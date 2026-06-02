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
TAGGING_DIR="$STAGING_ROOT/tagging"
ALBUM_STATE_ROOT="$SHARED_DIR/library-db/albums/media-staging"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"

REPORT="$REPORT_DIR/music_staging_tagging_audit_report_$STAMP.txt"
TSV="$RAW_DIR/music_staging_tagging_audit_$STAMP.tsv"

ALBUM_FILTER="${1:-}"

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

safe_name() {
  local name="$1"

  printf '%s' "$name" | tr ' /[]()' '_______' | tr -cd '[:alnum:]_.-'
}

state_value() {
  local file="$1"
  local key="$2"

  if [ ! -f "$file" ]; then
    printf ''
    return 0
  fi

  awk -F '\t' -v key="$key" '
    NR > 1 && $1 == key {
      print $2
      exit
    }
  ' "$file"
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
  \) 2>/dev/null | wc -l | tr -d ' '
}

count_ext_at() {
  local dir="$1"
  local pattern="$2"

  find "$dir" -type f -iname "$pattern" 2>/dev/null | wc -l | tr -d ' '
}

sum_bytes_at() {
  local dir="$1"

  find "$dir" -type f -printf '%s\n' 2>/dev/null | awk '{ s += $1 } END { print s+0 }'
}

has_cover_sidecar() {
  local dir="$1"

  find "$dir" -maxdepth 2 -type f \( \
    -iname 'cover.jpg' -o \
    -iname 'cover.jpeg' -o \
    -iname 'folder.jpg' -o \
    -iname 'front.jpg' -o \
    -iname 'cover.png' \
  \) 2>/dev/null | head -n 1
}

flac_test_summary() {
  local dir="$1"
  local total
  local ok
  local bad
  local file

  total=0
  ok=0
  bad=0

  if ! command -v flac >/dev/null 2>&1; then
    printf 'not_available'
    return 0
  fi

  while IFS= read -r -d '' file; do
    total=$((total + 1))
    if flac -t -s "$file" >/dev/null 2>&1; then
      ok=$((ok + 1))
    else
      bad=$((bad + 1))
    fi
  done < <(find "$dir" -type f -iname '*.flac' -print0 2>/dev/null | sort -z)

  printf 'total=%s ok=%s bad=%s' "$total" "$ok" "$bad"
}

ffprobe_audio_summary() {
  local dir="$1"
  local total
  local ok
  local bad
  local file

  total=0
  ok=0
  bad=0

  if ! command -v ffprobe >/dev/null 2>&1; then
    printf 'not_available'
    return 0
  fi

  while IFS= read -r -d '' file; do
    total=$((total + 1))
    if ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$file" >/dev/null 2>&1; then
      ok=$((ok + 1))
    else
      bad=$((bad + 1))
    fi
  done < <(find "$dir" -type f \( \
    -iname '*.flac' -o \
    -iname '*.mp3' -o \
    -iname '*.m4a' -o \
    -iname '*.ogg' -o \
    -iname '*.opus' -o \
    -iname '*.wav' -o \
    -iname '*.aiff' \
  \) -print0 2>/dev/null | sort -z)

  printf 'total=%s ok=%s bad=%s' "$total" "$ok" "$bad"
}

tag_count_for_field_value() {
  local tags_file="$1"
  local field="$2"
  local expected="$3"

  awk -F '\t' -v field="$field" -v expected="$expected" '
    NR > 1 && toupper($2) == field && $3 == expected {
      files[$1]=1
    }
    END {
      for (f in files) c++
      print c+0
    }
  ' "$tags_file"
}

tag_count_for_field_present() {
  local tags_file="$1"
  local field="$2"

  awk -F '\t' -v field="$field" '
    NR > 1 && toupper($2) == field && $3 != "" {
      files[$1]=1
    }
    END {
      for (f in files) c++
      print c+0
    }
  ' "$tags_file"
}

tag_count_value_contains() {
  local tags_file="$1"
  local expected="$2"

  awk -F '\t' -v expected="$expected" '
    NR > 1 && $3 == expected {
      files[$1]=1
    }
    END {
      for (f in files) c++
      print c+0
    }
  ' "$tags_file"
}

embedded_art_count_flac() {
  local dir="$1"
  local count
  local file

  count=0

  if ! command -v metaflac >/dev/null 2>&1; then
    printf 'unknown'
    return 0
  fi

  while IFS= read -r -d '' file; do
    if metaflac --list "$file" 2>/dev/null | grep -q '^METADATA block #[0-9].*type: 6 (PICTURE)'; then
      count=$((count + 1))
    fi
  done < <(find "$dir" -type f -iname '*.flac' -print0 2>/dev/null | sort -z)

  printf '%s' "$count"
}

write_tags_snapshot() {
  local dir="$1"
  local output="$2"
  local file
  local rel
  local field
  local value

  tsv_row "relative_path" "field" "value" > "$output"

  if ! command -v metaflac >/dev/null 2>&1; then
    return 0
  fi

  while IFS= read -r -d '' file; do
    rel="${file#$dir/}"

    while IFS='=' read -r field value; do
      if [ -n "$field" ]; then
        tsv_row "$rel" "$field" "${value:-}" >> "$output"
      fi
    done < <(metaflac --export-tags-to=- "$file" 2>/dev/null || true)
  done < <(find "$dir" -type f -iname '*.flac' -print0 2>/dev/null | sort -z)
}

audit_album() {
  local album_dir="$1"
  local album_name
  local safe_album
  local state_dir
  local state_file
  local events_file
  local local_toolbox_dir
  local local_state_file
  local expected_artist
  local expected_album
  local mbid
  local state
  local audio_count
  local flac_count
  local mp3_count
  local m4a_count
  local opus_count
  local image_count
  local total_bytes
  local cover_file
  local embedded_art_flac_count
  local tags_snapshot
  local album_tag_count
  local artist_tag_count
  local albumartist_tag_count
  local mbid_tag_count
  local title_count
  local tracknumber_count
  local date_count
  local label_count
  local catalog_count
  local genre_count
  local lyrics_count
  local replaygain_track_count
  local replaygain_album_count
  local flac_test
  local ffprobe_test
  local latest_transition_validation
  local latest_flac_write_validation
  local needs_artwork
  local needs_embedart
  local needs_replaygain
  local needs_genre_review
  local needs_lyrics_review
  local needs_integrity_fix
  local needs_completeness_check
  local needs_duplicates_check
  local candidate_for_ready
  local notes

  album_name="$(basename "$album_dir")"
  safe_album="$(safe_name "$album_name")"
  state_dir="$ALBUM_STATE_ROOT/$safe_album"
  state_file="$state_dir/state.tsv"
  events_file="$state_dir/events.tsv"
  local_toolbox_dir="$album_dir/.toolbox"
  local_state_file="$local_toolbox_dir/state.tsv"

  state="$(state_value "$state_file" "state")"
  expected_artist="$(state_value "$state_file" "expected_artist")"
  expected_album="$(state_value "$state_file" "expected_album")"
  mbid="$(state_value "$state_file" "mbid")"

  audio_count="$(count_audio_files_at "$album_dir")"
  flac_count="$(count_ext_at "$album_dir" "*.flac")"
  mp3_count="$(count_ext_at "$album_dir" "*.mp3")"
  m4a_count="$(count_ext_at "$album_dir" "*.m4a")"
  opus_count="$(count_ext_at "$album_dir" "*.opus")"
  image_count="$(find "$album_dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | wc -l | tr -d ' ')"
  total_bytes="$(sum_bytes_at "$album_dir")"
  cover_file="$(has_cover_sidecar "$album_dir")"
  embedded_art_flac_count="$(embedded_art_count_flac "$album_dir")"

  tags_snapshot="$RAW_DIR/music_staging_tagging_audit_${safe_album}_tags_$STAMP.tsv"
  write_tags_snapshot "$album_dir" "$tags_snapshot"

  album_tag_count=0
  artist_tag_count=0
  albumartist_tag_count=0
  mbid_tag_count=0
  title_count=0
  tracknumber_count=0
  date_count=0
  label_count=0
  catalog_count=0
  genre_count=0
  lyrics_count=0
  replaygain_track_count=0
  replaygain_album_count=0

  if [ -f "$tags_snapshot" ]; then
    album_tag_count="$(tag_count_for_field_value "$tags_snapshot" "ALBUM" "$expected_album")"
    artist_tag_count="$(tag_count_for_field_value "$tags_snapshot" "ARTIST" "$expected_artist")"
    albumartist_tag_count="$(tag_count_for_field_value "$tags_snapshot" "ALBUMARTIST" "$expected_artist")"
    mbid_tag_count="$(tag_count_value_contains "$tags_snapshot" "$mbid")"
    title_count="$(tag_count_for_field_present "$tags_snapshot" "TITLE")"
    tracknumber_count="$(tag_count_for_field_present "$tags_snapshot" "TRACKNUMBER")"
    date_count="$(tag_count_for_field_present "$tags_snapshot" "DATE")"
    label_count="$(tag_count_for_field_present "$tags_snapshot" "LABEL")"
    catalog_count="$(tag_count_for_field_present "$tags_snapshot" "CATALOGNUMBER")"
    genre_count="$(tag_count_for_field_present "$tags_snapshot" "GENRE")"
    lyrics_count="$(tag_count_for_field_present "$tags_snapshot" "LYRICS")"
    replaygain_track_count="$(tag_count_for_field_present "$tags_snapshot" "REPLAYGAIN_TRACK_GAIN")"
    replaygain_album_count="$(tag_count_for_field_present "$tags_snapshot" "REPLAYGAIN_ALBUM_GAIN")"
  fi

  flac_test="$(flac_test_summary "$album_dir")"
  ffprobe_test="$(ffprobe_audio_summary "$album_dir")"

  latest_transition_validation="$(find "$RAW_DIR" -maxdepth 1 -type f -name "music_staging_transition_validation_tagging_${safe_album}_*.tsv" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)"
  latest_flac_write_validation="$(find "$RAW_DIR" -maxdepth 1 -type f -name "music_staging_flac_metadata_write_validation_${safe_album}_*.tsv" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)"

  needs_artwork="no"
  needs_embedart="no"
  needs_replaygain="no"
  needs_genre_review="no"
  needs_lyrics_review="no"
  needs_integrity_fix="no"
  needs_completeness_check="yes"
  needs_duplicates_check="yes"
  candidate_for_ready="no"
  notes=""

  if [ -z "$cover_file" ]; then
    needs_artwork="yes"
  fi

  if [ "$flac_count" -gt 0 ] && [ "$embedded_art_flac_count" != "unknown" ] && [ "$embedded_art_flac_count" -lt "$flac_count" ]; then
    needs_embedart="yes"
  fi

  if [ "$flac_count" -gt 0 ] && { [ "$replaygain_track_count" -lt "$flac_count" ] || [ "$replaygain_album_count" -lt "$flac_count" ]; }; then
    needs_replaygain="yes"
  fi

  if [ "$genre_count" -lt "$audio_count" ]; then
    needs_genre_review="yes"
  fi

  if [ "$lyrics_count" -eq 0 ]; then
    needs_lyrics_review="optional"
  fi

  if printf '%s\n%s\n' "$flac_test" "$ffprobe_test" | grep -q 'bad=[1-9]'; then
    needs_integrity_fix="yes"
  fi

  if [ "$audio_count" -gt 0 ] \
    && [ "$album_tag_count" -eq "$flac_count" ] \
    && [ "$artist_tag_count" -eq "$flac_count" ] \
    && [ "$albumartist_tag_count" -eq "$flac_count" ] \
    && [ "$title_count" -eq "$flac_count" ] \
    && [ "$tracknumber_count" -eq "$flac_count" ] \
    && [ "$needs_integrity_fix" = "no" ]; then
    candidate_for_ready="maybe-after-policy-checks"
  fi

  if [ "$state" != "tagging" ]; then
    notes="${notes}state_not_tagging;"
  fi

  if [ ! -d "$local_toolbox_dir" ]; then
    notes="${notes}missing_album_toolbox_dir;"
  fi

  if [ -z "$latest_transition_validation" ]; then
    notes="${notes}missing_transition_validation;"
  fi

  if [ -z "$latest_flac_write_validation" ] && [ "$flac_count" -gt 0 ]; then
    notes="${notes}missing_flac_write_validation;"
  fi

  tsv_row \
    "$album_name" \
    "$safe_album" \
    "$album_dir" \
    "$state" \
    "$expected_artist" \
    "$expected_album" \
    "$mbid" \
    "$audio_count" \
    "$flac_count" \
    "$mp3_count" \
    "$m4a_count" \
    "$opus_count" \
    "$image_count" \
    "$total_bytes" \
    "${cover_file:-missing}" \
    "$embedded_art_flac_count" \
    "$album_tag_count" \
    "$artist_tag_count" \
    "$albumartist_tag_count" \
    "$mbid_tag_count" \
    "$title_count" \
    "$tracknumber_count" \
    "$date_count" \
    "$label_count" \
    "$catalog_count" \
    "$genre_count" \
    "$lyrics_count" \
    "$replaygain_track_count" \
    "$replaygain_album_count" \
    "$flac_test" \
    "$ffprobe_test" \
    "${latest_transition_validation:-missing}" \
    "${latest_flac_write_validation:-missing}" \
    "$needs_artwork" \
    "$needs_embedart" \
    "$needs_replaygain" \
    "$needs_genre_review" \
    "$needs_lyrics_review" \
    "$needs_integrity_fix" \
    "$needs_completeness_check" \
    "$needs_duplicates_check" \
    "$candidate_for_ready" \
    "${notes:-ok}" >> "$TSV"
}

main() {
  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting music staging tagging audit."

  tsv_row \
    "album_name" \
    "safe_album_name" \
    "album_dir" \
    "state" \
    "expected_artist" \
    "expected_album" \
    "mbid" \
    "audio_count" \
    "flac_count" \
    "mp3_count" \
    "m4a_count" \
    "opus_count" \
    "image_count" \
    "total_bytes" \
    "cover_sidecar" \
    "embedded_art_flac_count" \
    "album_tag_count" \
    "artist_tag_count" \
    "albumartist_tag_count" \
    "mbid_tag_count" \
    "title_count" \
    "tracknumber_count" \
    "date_count" \
    "label_count" \
    "catalognumber_count" \
    "genre_count" \
    "lyrics_count" \
    "replaygain_track_count" \
    "replaygain_album_count" \
    "flac_test" \
    "ffprobe_test" \
    "latest_transition_validation" \
    "latest_flac_write_validation" \
    "needs_artwork" \
    "needs_embedart" \
    "needs_replaygain" \
    "needs_genre_review" \
    "needs_lyrics_review" \
    "needs_integrity_fix" \
    "needs_completeness_check" \
    "needs_duplicates_check" \
    "candidate_for_ready" \
    "notes" > "$TSV"

  if [ -n "$ALBUM_FILTER" ]; then
    if [ -d "$TAGGING_DIR/$ALBUM_FILTER" ]; then
      audit_album "$TAGGING_DIR/$ALBUM_FILTER"
    elif [ -d "$ALBUM_FILTER" ]; then
      audit_album "$ALBUM_FILTER"
    else
      fail "Album filter did not match a directory: $ALBUM_FILTER"
    fi
  else
    while IFS= read -r -d '' album_dir; do
      audit_album "$album_dir"
    done < <(find "$TAGGING_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
  fi

  {
    printf '%s\n' '# Music Staging Tagging Audit'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Tagging dir: %s\n' "$TAGGING_DIR"
    printf 'Album filter: %s\n' "${ALBUM_FILTER:-all}"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: diagnosis only. This script does not run Beets, apply plugins, write tags, move files, delete files, or modify /srv/media/music.'
    printf '\n'

    printf '%s\n' '## Interpretation'
    printf '\n'
    printf '%s\n' '- needs_artwork: no cover sidecar detected.'
    printf '%s\n' '- needs_embedart: not all FLACs have embedded art.'
    printf '%s\n' '- needs_replaygain: ReplayGain tags missing on some/all FLACs.'
    printf '%s\n' '- needs_genre_review: GENRE missing on some/all audio files.'
    printf '%s\n' '- needs_lyrics_review: optional; usually not blocking for instrumental material.'
    printf '%s\n' '- needs_integrity_fix: flac/ffprobe detected technical failures.'
    printf '%s\n' '- needs_completeness_check and needs_duplicates_check remain yes until dedicated checks exist.'
    printf '\n'

    printf '%s\n' '## Audit TSV'
    printf '\n'
    printf '%s\n' '```text'
    column -t -s $'\t' "$TSV" 2>/dev/null || cat "$TSV"
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } > "$REPORT"

  log "Music staging tagging audit completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
