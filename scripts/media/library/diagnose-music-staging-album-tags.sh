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
ALBUM_DIR="${1:-$DEFAULT_ALBUM}"
ALBUM_NAME="$(basename "$ALBUM_DIR")"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"

SAFE_ALBUM_NAME="$(printf '%s' "$ALBUM_NAME" | tr ' /[]()' '_______' | tr -cd '[:alnum:]_.-')"

REPORT="$REPORT_DIR/music_staging_album_tags_diagnosis_${SAFE_ALBUM_NAME}_report_$STAMP.txt"
TSV="$RAW_DIR/music_staging_album_tags_diagnosis_${SAFE_ALBUM_NAME}_$STAMP.tsv"

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

command_status() {
  local cmd="$1"

  if command -v "$cmd" >/dev/null 2>&1; then
    printf '%s' "OK"
  else
    printf '%s' "MISSING"
  fi
}

command_path() {
  local cmd="$1"

  command -v "$cmd" 2>/dev/null || true
}

audio_ext() {
  local file="$1"

  case "$file" in
    *.flac|*.FLAC) printf '%s' "flac" ;;
    *.mp3|*.MP3) printf '%s' "mp3" ;;
    *.m4a|*.M4A) printf '%s' "m4a" ;;
    *.wav|*.WAV) printf '%s' "wav" ;;
    *.ogg|*.OGG) printf '%s' "ogg" ;;
    *.opus|*.OPUS) printf '%s' "opus" ;;
    *) printf '%s' "unknown" ;;
  esac
}

file_size_bytes() {
  local file="$1"

  stat -c '%s' "$file" 2>/dev/null || printf '%s' ""
}

ffprobe_duration() {
  local file="$1"

  if ! command -v ffprobe >/dev/null 2>&1; then
    printf '%s' ""
    return 0
  fi

  ffprobe \
    -v error \
    -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 \
    "$file" 2>/dev/null \
    | awk '{ printf "%.3f", $1 }'
}

metaflac_tag() {
  local file="$1"
  local tag="$2"

  if ! command -v metaflac >/dev/null 2>&1; then
    printf '%s' ""
    return 0
  fi

  metaflac --show-tag="$tag" "$file" 2>/dev/null \
    | sed "s/^$tag=//" \
    | paste -sd ';' -
}

fpcalc_fingerprint() {
  local file="$1"

  if ! command -v fpcalc >/dev/null 2>&1; then
    printf '%s' ""
    return 0
  fi

  fpcalc "$file" 2>/dev/null \
    | awk -F= '$1 == "FINGERPRINT" { print $2 }'
}

fpcalc_duration() {
  local file="$1"

  if ! command -v fpcalc >/dev/null 2>&1; then
    printf '%s' ""
    return 0
  fi

  fpcalc "$file" 2>/dev/null \
    | awk -F= '$1 == "DURATION" { print $2 }'
}

mp3_tag_with_mid3v2() {
  local file="$1"
  local field="$2"

  if ! command -v mid3v2 >/dev/null 2>&1; then
    printf '%s' ""
    return 0
  fi

  case "$field" in
    title)
      mid3v2 -l "$file" 2>/dev/null | awk -F= '/^TIT2=/ { print $2 }' | paste -sd ';' -
      ;;
    artist)
      mid3v2 -l "$file" 2>/dev/null | awk -F= '/^TPE1=/ { print $2 }' | paste -sd ';' -
      ;;
    albumartist)
      mid3v2 -l "$file" 2>/dev/null | awk -F= '/^TPE2=/ { print $2 }' | paste -sd ';' -
      ;;
    album)
      mid3v2 -l "$file" 2>/dev/null | awk -F= '/^TALB=/ { print $2 }' | paste -sd ';' -
      ;;
    tracknumber)
      mid3v2 -l "$file" 2>/dev/null | awk -F= '/^TRCK=/ { print $2 }' | paste -sd ';' -
      ;;
    date)
      mid3v2 -l "$file" 2>/dev/null | awk -F= '/^(TDRC|TYER)=/ { print $2 }' | paste -sd ';' -
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

tag_value() {
  local file="$1"
  local ext="$2"
  local tag="$3"

  case "$ext" in
    flac)
      metaflac_tag "$file" "$tag"
      ;;
    mp3)
      case "$tag" in
        TITLE) mp3_tag_with_mid3v2 "$file" "title" ;;
        ARTIST) mp3_tag_with_mid3v2 "$file" "artist" ;;
        ALBUMARTIST) mp3_tag_with_mid3v2 "$file" "albumartist" ;;
        ALBUM) mp3_tag_with_mid3v2 "$file" "album" ;;
        TRACKNUMBER) mp3_tag_with_mid3v2 "$file" "tracknumber" ;;
        DATE) mp3_tag_with_mid3v2 "$file" "date" ;;
        *) printf '%s' "" ;;
      esac
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

write_audio_row() {
  local file="$1"
  local rel_path
  local base_name
  local ext
  local size
  local ff_duration
  local fp_duration
  local fingerprint
  local title
  local artist
  local albumartist
  local album
  local tracknumber
  local discnumber
  local date
  local genre
  local composer

  rel_path="${file#"$ALBUM_DIR"/}"
  base_name="$(basename "$file")"
  ext="$(audio_ext "$file")"
  size="$(file_size_bytes "$file")"
  ff_duration="$(ffprobe_duration "$file")"
  fp_duration="$(fpcalc_duration "$file")"
  fingerprint="$(fpcalc_fingerprint "$file")"

  title="$(tag_value "$file" "$ext" "TITLE")"
  artist="$(tag_value "$file" "$ext" "ARTIST")"
  albumartist="$(tag_value "$file" "$ext" "ALBUMARTIST")"
  album="$(tag_value "$file" "$ext" "ALBUM")"
  tracknumber="$(tag_value "$file" "$ext" "TRACKNUMBER")"
  discnumber="$(tag_value "$file" "$ext" "DISCNUMBER")"
  date="$(tag_value "$file" "$ext" "DATE")"
  genre="$(tag_value "$file" "$ext" "GENRE")"
  composer="$(tag_value "$file" "$ext" "COMPOSER")"

  tsv_row \
    "$file" \
    "$rel_path" \
    "$base_name" \
    "$ext" \
    "$size" \
    "$ff_duration" \
    "$fp_duration" \
    "$tracknumber" \
    "$discnumber" \
    "$title" \
    "$artist" \
    "$albumartist" \
    "$album" \
    "$date" \
    "$genre" \
    "$composer" \
    "$fingerprint" >> "$TSV"
}

append_command_output() {
  local title="$1"
  shift

  {
    printf '\n'
    printf '## %s\n' "$title"
    printf '\n'
    printf '%s\n' '```text'
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
  } >> "$REPORT"

  if "$@" >> "$REPORT" 2>&1; then
    printf '\n%s\n' '[OK]' >> "$REPORT"
  else
    printf '\n%s\n' '[WARN] command returned non-zero status' >> "$REPORT"
  fi

  printf '%s\n' '```' >> "$REPORT"
}

main() {
  local audio_count
  local flac_count
  local mp3_count
  local image_count
  local total_bytes
  local missing_title_count
  local missing_artist_count
  local missing_album_count
  local missing_track_count
  local unique_albums
  local unique_artists
  local unique_albumartists

  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  if [ ! -d "$ALBUM_DIR" ]; then
    fail "Album directory not found: $ALBUM_DIR"
  fi

  log "Starting music staging album tags diagnosis."

  tsv_row \
    "file_path" \
    "relative_path" \
    "file_name" \
    "ext" \
    "size_bytes" \
    "ffprobe_duration_seconds" \
    "fpcalc_duration_seconds" \
    "tracknumber" \
    "discnumber" \
    "title" \
    "artist" \
    "albumartist" \
    "album" \
    "date" \
    "genre" \
    "composer" \
    "acoustid_fingerprint" > "$TSV"

  audio_count="$(find "$ALBUM_DIR" -type f \( -iname '*.flac' -o -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.wav' -o -iname '*.ogg' -o -iname '*.opus' \) 2>/dev/null | wc -l | tr -d ' ')"
  flac_count="$(find "$ALBUM_DIR" -type f -iname '*.flac' 2>/dev/null | wc -l | tr -d ' ')"
  mp3_count="$(find "$ALBUM_DIR" -type f -iname '*.mp3' 2>/dev/null | wc -l | tr -d ' ')"
  image_count="$(find "$ALBUM_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | wc -l | tr -d ' ')"
  total_bytes="$(du -sb "$ALBUM_DIR" 2>/dev/null | awk '{print $1}')"

  {
    printf '%s\n' '# Music Staging Album Tags Diagnosis'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Album directory: %s\n' "$ALBUM_DIR"
    printf 'Album name: %s\n' "$ALBUM_NAME"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: diagnosis only. This script does not write tags, move files, rename files, copy files or modify staging/library.'
    printf '\n'
    printf '%s\n' '## Tool availability'
    printf '\n'
    printf '%s\n' '```text'
    printf 'metaflac: %s %s\n' "$(command_status metaflac)" "$(command_path metaflac)"
    printf 'ffprobe:  %s %s\n' "$(command_status ffprobe)" "$(command_path ffprobe)"
    printf 'fpcalc:   %s %s\n' "$(command_status fpcalc)" "$(command_path fpcalc)"
    printf 'mid3v2:   %s %s\n' "$(command_status mid3v2)" "$(command_path mid3v2)"
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Album summary'
    printf '\n'
    printf '%s\n' '```text'
    printf 'Audio files: %s\n' "$audio_count"
    printf 'FLAC files: %s\n' "$flac_count"
    printf 'MP3 files: %s\n' "$mp3_count"
    printf 'Image files: %s\n' "$image_count"
    printf 'Total bytes: %s\n' "$total_bytes"
    printf '%s\n' '```'
    printf '\n'
  } > "$REPORT"

  find "$ALBUM_DIR" -type f \( -iname '*.flac' -o -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.wav' -o -iname '*.ogg' -o -iname '*.opus' \) -print0 2>/dev/null \
    | sort -z \
    | while IFS= read -r -d '' file; do
        write_audio_row "$file"
      done

  missing_title_count="$(awk -F '\t' 'NR > 1 && $10 == "" { c++ } END { print c+0 }' "$TSV")"
  missing_artist_count="$(awk -F '\t' 'NR > 1 && $11 == "" { c++ } END { print c+0 }' "$TSV")"
  missing_album_count="$(awk -F '\t' 'NR > 1 && $13 == "" { c++ } END { print c+0 }' "$TSV")"
  missing_track_count="$(awk -F '\t' 'NR > 1 && $8 == "" { c++ } END { print c+0 }' "$TSV")"

  unique_albums="$(awk -F '\t' 'NR > 1 && $13 != "" { print $13 }' "$TSV" | sort -u | paste -sd ';' -)"
  unique_artists="$(awk -F '\t' 'NR > 1 && $11 != "" { print $11 }' "$TSV" | sort -u | paste -sd ';' -)"
  unique_albumartists="$(awk -F '\t' 'NR > 1 && $12 != "" { print $12 }' "$TSV" | sort -u | paste -sd ';' -)"

  {
    printf '%s\n' '## Metadata summary'
    printf '\n'
    printf '%s\n' '```text'
    printf 'Missing TITLE: %s\n' "$missing_title_count"
    printf 'Missing ARTIST: %s\n' "$missing_artist_count"
    printf 'Missing ALBUM: %s\n' "$missing_album_count"
    printf 'Missing TRACKNUMBER: %s\n' "$missing_track_count"
    printf 'Unique ALBUM values: %s\n' "$unique_albums"
    printf 'Unique ARTIST values: %s\n' "$unique_artists"
    printf 'Unique ALBUMARTIST values: %s\n' "$unique_albumartists"
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## TSV preview'
    printf '\n'
    printf '%s\n' '```text'
    column -t -s $'\t' "$TSV" 2>/dev/null | head -n 40
    printf '%s\n' '```'
  } >> "$REPORT"

  append_command_output "File tree" find "$ALBUM_DIR" -maxdepth 2 -type f -printf '%P\n'

  {
    printf '\n'
    printf '%s\n' '## Interpretation hints'
    printf '\n'
    printf '%s\n' '- If titles/artists/albums are missing or inconsistent, Beets matching may fail before MBID/manual strategy.'
    printf '%s\n' '- If durations differ from MusicBrainz releases, matching may require a specific release ID or local correction.'
    printf '%s\n' '- If fingerprints were produced, chroma/acoustid tooling is operational for this album.'
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  log "Music staging album tags diagnosis completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
