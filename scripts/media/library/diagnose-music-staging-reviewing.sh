#!/usr/bin/env bash
set -u

APP_DIR="/srv/toolbox/app"
LIB_DIR="$APP_DIR/scripts/lib"

# shellcheck source=/srv/toolbox/app/scripts/lib/logging.sh
source "$LIB_DIR/logging.sh"

# shellcheck source=/srv/toolbox/app/scripts/lib/timestamps.sh
source "$LIB_DIR/timestamps.sh"

# shellcheck source=/srv/toolbox/app/scripts/lib/tsv.sh
source "$LIB_DIR/tsv.sh"

# shellcheck source=/srv/toolbox/app/scripts/lib/paths.sh
source "$LIB_DIR/paths.sh"

STAGING_DIR="/srv/media/music-staging/reviewing"
MUSIC_ROOT="/srv/media/music"

STAMP="$(toolbox_timestamp)"
SHARED_DIR="$(toolbox_shared_dir)"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"

REPORT="$REPORT_DIR/music_staging_reviewing_diagnosis_report_$STAMP.txt"
TSV="$RAW_DIR/music_staging_reviewing_diagnosis_$STAMP.tsv"

require_function() {
  local fn="$1"

  if ! declare -F "$fn" >/dev/null 2>&1; then
    printf '%s\n' "[ERRO] Required function not found: $fn" >&2
    exit 1
  fi
}

require_toolbox_lib_contract() {
  require_function log
  require_function fail
  require_function toolbox_timestamp
  require_function toolbox_now
  require_function tsv_escape
  require_function tsv_row
  require_function toolbox_shared_dir
}

count_files() {
  local dir="$1"
  shift

  find "$dir" -type f "$@" 2>/dev/null | wc -l | tr -d ' '
}

first_audio_file() {
  local dir="$1"

  find "$dir" -type f \( -iname '*.flac' -o -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.ogg' -o -iname '*.opus' -o -iname '*.wav' -o -iname '*.mp4' \) 2>/dev/null \
    | sort \
    | head -n 1
}

artist_probe_from_album_name() {
  local name="$1"

  if printf '%s' "$name" | grep -qi 'Stockhausen'; then
    printf '%s\n' 'Karlheinz Stockhausen'
  elif printf '%s' "$name" | grep -qi 'Braxton\|Trillium'; then
    printf '%s\n' 'Anthony Braxton'
  elif printf '%s' "$name" | grep -qi 'Naná\|Nana\|Vasconcelos'; then
    printf '%s\n' 'Nana Vasconcelos'
  elif printf '%s' "$name" | grep -qi 'Revolutionary Ensemble'; then
    printf '%s\n' 'Revolutionary Ensemble'
  elif printf '%s' "$name" | grep -qi 'Thembi\|Pharoah'; then
    printf '%s\n' 'Pharoah Sanders'
  elif printf '%s' "$name" | grep -qi 'Spectrum'; then
    printf '%s\n' 'Billy Cobham'
  else
    printf '%s\n' ''
  fi
}

library_candidates_for_probe() {
  local probe="$1"

  if [ -z "$probe" ]; then
    return 0
  fi

  find "$MUSIC_ROOT" -type d -iname "*$probe*" -print 2>/dev/null | sort
}

classify_album() {
  local album_name="$1"
  local flac_count="$2"
  local mp3_count="$3"
  local mp4_count="$4"
  local library_candidate_count="$5"

  if printf '%s' "$album_name" | grep -qi 'Stockhausen'; then
    printf '%s\n' 'stockhausen-special'
  elif printf '%s' "$album_name" | grep -qi 'Trillium J'; then
    printf '%s\n' 'braxton-video-opera'
  elif printf '%s' "$album_name" | grep -qi 'Trillium'; then
    if [ "$library_candidate_count" -gt 0 ]; then
      printf '%s\n' 'braxton-known-collection'
    else
      printf '%s\n' 'braxton-review'
    fi
  elif [ "$mp4_count" -gt 0 ] && [ "$flac_count" -eq 0 ] && [ "$mp3_count" -eq 0 ]; then
    printf '%s\n' 'video'
  elif [ "$flac_count" -gt 0 ] && [ "$mp3_count" -eq 0 ]; then
    printf '%s\n' 'flac-album'
  elif [ "$mp3_count" -gt 0 ] && [ "$flac_count" -eq 0 ]; then
    printf '%s\n' 'mp3-album'
  elif [ "$flac_count" -gt 0 ] && [ "$mp3_count" -gt 0 ]; then
    printf '%s\n' 'mixed-audio'
  else
    printf '%s\n' 'unknown'
  fi
}

suggest_next_action() {
  local suggested_class="$1"

  case "$suggested_class" in
    stockhausen-special)
      printf '%s\n' 'plan with Stockhausen structural policy; use MusicBrainz as optional enrichment'
      ;;
    braxton-known-collection)
      printf '%s\n' 'compare with existing Braxton library; likely good candidate for beets/MusicBrainz-assisted import'
      ;;
    braxton-review)
      printf '%s\n' 'diagnose Braxton metadata and MusicBrainz candidates before import'
      ;;
    braxton-video-opera)
      printf '%s\n' 'separate video/archive decision; likely not direct Navidrome music import'
      ;;
    video)
      printf '%s\n' 'exclude from music import; consider Jellyfin/video archive workflow'
      ;;
    flac-album)
      printf '%s\n' 'candidate for beets MusicBrainz sandbox'
      ;;
    mp3-album)
      printf '%s\n' 'candidate for beets MusicBrainz sandbox; inspect MP3 tag tooling'
      ;;
    mixed-audio)
      printf '%s\n' 'manual diagnosis before apply; mixed audio formats'
      ;;
    *)
      printf '%s\n' 'diagnose better'
      ;;
  esac
}

main() {
  require_toolbox_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  if [ ! -d "$STAGING_DIR" ]; then
    fail "Staging directory not found: $STAGING_DIR"
  fi

  if [ ! -d "$MUSIC_ROOT" ]; then
    fail "Music root not found: $MUSIC_ROOT"
  fi

  log "Starting music staging reviewing diagnosis."

  tsv_row \
    'album_dir' \
    'album_name' \
    'total_files' \
    'flac_count' \
    'mp3_count' \
    'mp4_count' \
    'image_count' \
    'other_count' \
    'total_bytes' \
    'first_audio' \
    'artist_probe' \
    'library_candidate_count' \
    'library_candidate_paths' \
    'suggested_class' \
    'suggested_next_action' \
    'notes' > "$TSV"

  {
    printf '%s\n' '# Music Staging Reviewing Diagnosis'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Staging directory: %s\n' "$STAGING_DIR"
    printf 'Music root: %s\n' "$MUSIC_ROOT"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: diagnosis only. This script does not write tags, move files, rename files or modify staging/library.'
    printf '%s\n' 'Output policy: this script writes to reports/media/staging and library-db/raw/media/staging to avoid flat legacy output directories.'
    printf '%s\n' 'Library policy: this script uses scripts/lib for logging, timestamps, paths and TSV rows.'
    printf '\n'
  } > "$REPORT"

  album_count="$(find "$STAGING_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"

  {
    printf '%s\n' '## Summary'
    printf '\n'
    printf 'Album directories: %s\n' "$album_count"
    printf '\n'
    printf '%s\n' '## Album diagnosis'
    printf '\n'
    printf '%s\n' '```text'
  } >> "$REPORT"

  find "$STAGING_DIR" -mindepth 1 -maxdepth 1 -type d -print0 \
    | sort -z \
    | while IFS= read -r -d '' album_dir; do
        album_name="$(basename "$album_dir")"

        total_files="$(find "$album_dir" -type f | wc -l | tr -d ' ')"
        flac_count="$(find "$album_dir" -type f -iname '*.flac' | wc -l | tr -d ' ')"
        mp3_count="$(find "$album_dir" -type f -iname '*.mp3' | wc -l | tr -d ' ')"
        mp4_count="$(find "$album_dir" -type f -iname '*.mp4' | wc -l | tr -d ' ')"
        image_count="$(find "$album_dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | wc -l | tr -d ' ')"
        audio_image_count="$((flac_count + mp3_count + mp4_count + image_count))"
        other_count="$((total_files - audio_image_count))"
        total_bytes="$(du -sb "$album_dir" 2>/dev/null | awk '{print $1}')"
        first_audio="$(first_audio_file "$album_dir")"

        artist_probe="$(artist_probe_from_album_name "$album_name")"

        library_candidate_paths="$(
          library_candidates_for_probe "$artist_probe" \
            | paste -sd '|' -
        )"

        if [ -n "$library_candidate_paths" ]; then
          library_candidate_count="$(
            printf '%s\n' "$library_candidate_paths" \
              | tr '|' '\n' \
              | sed '/^$/d' \
              | wc -l \
              | tr -d ' '
          )"
        else
          library_candidate_count="0"
        fi

        suggested_class="$(classify_album "$album_name" "$flac_count" "$mp3_count" "$mp4_count" "$library_candidate_count")"
        suggested_next_action="$(suggest_next_action "$suggested_class")"
        notes=""

        printf '%s | class=%s | flac=%s mp3=%s mp4=%s images=%s other=%s | probe=%s | library_candidates=%s\n' \
          "$album_name" \
          "$suggested_class" \
          "$flac_count" \
          "$mp3_count" \
          "$mp4_count" \
          "$image_count" \
          "$other_count" \
          "$artist_probe" \
          "$library_candidate_count" >> "$REPORT"

        tsv_row \
          "$album_dir" \
          "$album_name" \
          "$total_files" \
          "$flac_count" \
          "$mp3_count" \
          "$mp4_count" \
          "$image_count" \
          "$other_count" \
          "$total_bytes" \
          "$first_audio" \
          "$artist_probe" \
          "$library_candidate_count" \
          "$library_candidate_paths" \
          "$suggested_class" \
          "$suggested_next_action" \
          "$notes" >> "$TSV"
      done

  {
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Recommended next steps'
    printf '\n'
    printf '%s\n' '1. Run diagnose-musicbrainz-cli-tools.sh.'
    printf '%s\n' '2. Install missing CLI dependencies, especially beets and chromaprint/fpcalc, if absent.'
    printf '%s\n' '3. Create isolated beets sandbox before running MusicBrainz matching.'
    printf '%s\n' '4. Use beets dry-run protections such as -C and -W during exploratory imports.'
    printf '%s\n' '5. Keep Stockhausen and complex collection policies available as overrides, but do not assume Braxton is problematic without checking the local library.'
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  log "Diagnosis completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
