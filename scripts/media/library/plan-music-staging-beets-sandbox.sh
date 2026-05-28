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
MUSIC_ROOT="/srv/media/music"
BEETS_SANDBOX_ROOT="$SHARED_DIR/beets/media-staging"
BEETS_CONFIG="$BEETS_SANDBOX_ROOT/config.yaml"
BEETS_LIBRARY="$BEETS_SANDBOX_ROOT/library.blb"
BEETS_STAGING_LIBRARY="$BEETS_SANDBOX_ROOT/library"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
PLAN_DIR="$SHARED_DIR/library-db/plans/media/staging"

REPORT="$REPORT_DIR/music_staging_beets_sandbox_plan_report_$STAMP.txt"
TSV="$PLAN_DIR/music_staging_beets_sandbox_plan_$STAMP.tsv"

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

count_files() {
  local dir="$1"
  shift

  find "$dir" -type f "$@" 2>/dev/null | wc -l | tr -d ' '
}

album_total_bytes() {
  local dir="$1"

  du -sb "$dir" 2>/dev/null | awk '{print $1}'
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

library_candidate_count_for_probe() {
  local probe="$1"

  if [ -z "$probe" ]; then
    printf '%s\n' "0"
    return 0
  fi

  find "$MUSIC_ROOT" -type d -iname "*$probe*" -print 2>/dev/null \
    | wc -l \
    | tr -d ' '
}

classify_for_beets_plan() {
  local album_name="$1"
  local flac_count="$2"
  local mp3_count="$3"
  local mp4_count="$4"

  if printf '%s' "$album_name" | grep -qi 'Trillium J'; then
    printf '%s\n' 'exclude-video'
  elif [ "$mp4_count" -gt 0 ] && [ "$flac_count" -eq 0 ] && [ "$mp3_count" -eq 0 ]; then
    printf '%s\n' 'exclude-video'
  elif printf '%s' "$album_name" | grep -qi 'Stockhausen'; then
    printf '%s\n' 'special-stockhausen'
  elif printf '%s' "$album_name" | grep -qi 'Trillium'; then
    printf '%s\n' 'candidate-braxton'
  elif [ "$flac_count" -gt 0 ] && [ "$mp3_count" -eq 0 ]; then
    printf '%s\n' 'candidate-flac'
  elif [ "$mp3_count" -gt 0 ] && [ "$flac_count" -eq 0 ]; then
    printf '%s\n' 'candidate-mp3'
  elif [ "$flac_count" -gt 0 ] && [ "$mp3_count" -gt 0 ]; then
    printf '%s\n' 'manual-mixed-audio'
  else
    printf '%s\n' 'manual-review'
  fi
}

recommended_action_for_class() {
  local class="$1"

  case "$class" in
    candidate-flac)
      printf '%s\n' 'run beets sandbox dry-run; likely good pilot candidate'
      ;;
    candidate-mp3)
      printf '%s\n' 'run beets sandbox dry-run; inspect ID3 behavior before apply'
      ;;
    candidate-braxton)
      printf '%s\n' 'run beets sandbox dry-run; compare with existing Braxton library before apply'
      ;;
    special-stockhausen)
      printf '%s\n' 'run beets sandbox as metadata candidate only; local Stockhausen structural policy remains authoritative'
      ;;
    exclude-video)
      printf '%s\n' 'exclude from music import; defer to video/Jellyfin/archive workflow'
      ;;
    manual-mixed-audio)
      printf '%s\n' 'manual diagnosis before beets; mixed audio formats'
      ;;
    *)
      printf '%s\n' 'diagnose better before beets'
      ;;
  esac
}

pilot_rank_for_album() {
  local album_name="$1"
  local class="$2"

  if printf '%s' "$album_name" | grep -qi 'Thembi'; then
    printf '%s\n' '01'
  elif printf '%s' "$album_name" | grep -qi 'Spectrum'; then
    printf '%s\n' '02'
  elif [ "$class" = "candidate-flac" ]; then
    printf '%s\n' '10'
  elif [ "$class" = "candidate-braxton" ]; then
    printf '%s\n' '20'
  elif [ "$class" = "candidate-mp3" ]; then
    printf '%s\n' '30'
  elif [ "$class" = "special-stockhausen" ]; then
    printf '%s\n' '40'
  elif [ "$class" = "exclude-video" ]; then
    printf '%s\n' '90'
  else
    printf '%s\n' '80'
  fi
}

shell_quote_arg() {
  local value="$1"

  printf '%q' "$value"
}

beets_dry_run_command_for_album() {
  local album_dir="$1"
  local quoted_album_dir

  quoted_album_dir="$(shell_quote_arg "$album_dir")"

  printf 'BEETSDIR=%s beet import -C -W %s\n' \
    "$(shell_quote_arg "$BEETS_SANDBOX_ROOT")" \
    "$quoted_album_dir"
}

write_plan_row() {
  local album_dir="$1"
  local album_name="$2"
  local flac_count="$3"
  local mp3_count="$4"
  local mp4_count="$5"
  local image_count="$6"
  local total_bytes="$7"
  local artist_probe="$8"
  local library_candidate_count="$9"
  local plan_class="${10}"
  local pilot_rank="${11}"
  local recommended_action="${12}"
  local beets_command="${13}"
  local notes="${14}"

  tsv_row \
    "$album_dir" \
    "$album_name" \
    "$flac_count" \
    "$mp3_count" \
    "$mp4_count" \
    "$image_count" \
    "$total_bytes" \
    "$artist_probe" \
    "$library_candidate_count" \
    "$plan_class" \
    "$pilot_rank" \
    "$recommended_action" \
    "$beets_command" \
    "$notes" >> "$TSV"
}

main() {
  require_lib_contract

  mkdir -p "$REPORT_DIR" "$PLAN_DIR"

  if [ ! -d "$STAGING_DIR" ]; then
    fail "Staging directory not found: $STAGING_DIR"
  fi

  if [ ! -d "$MUSIC_ROOT" ]; then
    fail "Music root not found: $MUSIC_ROOT"
  fi

  log "Generating music staging beets sandbox plan."

  tsv_row \
    "album_dir" \
    "album_name" \
    "flac_count" \
    "mp3_count" \
    "mp4_count" \
    "image_count" \
    "total_bytes" \
    "artist_probe" \
    "library_candidate_count" \
    "plan_class" \
    "pilot_rank" \
    "recommended_action" \
    "beets_dry_run_command" \
    "notes" > "$TSV"

  {
    printf '%s\n' '# Music Staging Beets Sandbox Plan'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Staging directory: %s\n' "$STAGING_DIR"
    printf 'Music root: %s\n' "$MUSIC_ROOT"
    printf 'Beets sandbox root: %s\n' "$BEETS_SANDBOX_ROOT"
    printf 'Planned beets config: %s\n' "$BEETS_CONFIG"
    printf 'Planned beets library DB: %s\n' "$BEETS_LIBRARY"
    printf 'Planned beets sandbox library dir: %s\n' "$BEETS_STAGING_LIBRARY"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: plan only. This script does not create beets config, run beets, write tags, move files or modify staging/library.'
    printf '%s\n' 'Dry-run policy: use both BEETSDIR sandbox isolation and beet import -C -W for exploratory MusicBrainz matching.'
    printf '\n'
    printf '%s\n' '## Planned sandbox config'
    printf '\n'
    printf '%s\n' '```yaml'
    printf 'directory: %s\n' "$BEETS_STAGING_LIBRARY"
    printf 'library: %s\n' "$BEETS_LIBRARY"
    printf '%s\n' 'import:'
    printf '%s\n' '  copy: no'
    printf '%s\n' '  write: no'
    printf '%s\n' '  move: no'
    printf '%s\n' '  resume: ask'
    printf '%s\n' '  incremental: no'
    printf '%s\n' 'plugins: chroma'
    printf '%s\n' 'chroma:'
    printf '%s\n' '  auto: yes'
    printf '%s\n' 'ui:'
    printf '%s\n' '  color: yes'
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Album plan'
    printf '\n'
    printf '%s\n' '```text'
  } > "$REPORT"

  find "$STAGING_DIR" -mindepth 1 -maxdepth 1 -type d -print0 \
    | sort -z \
    | while IFS= read -r -d '' album_dir; do
        album_name="$(basename "$album_dir")"

        flac_count="$(count_files "$album_dir" -iname '*.flac')"
        mp3_count="$(count_files "$album_dir" -iname '*.mp3')"
        mp4_count="$(count_files "$album_dir" -iname '*.mp4')"
        image_count="$(find "$album_dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | wc -l | tr -d ' ')"
        total_bytes="$(album_total_bytes "$album_dir")"

        artist_probe="$(artist_probe_from_album_name "$album_name")"
        library_candidate_count="$(library_candidate_count_for_probe "$artist_probe")"
        plan_class="$(classify_for_beets_plan "$album_name" "$flac_count" "$mp3_count" "$mp4_count")"
        pilot_rank="$(pilot_rank_for_album "$album_name" "$plan_class")"
        recommended_action="$(recommended_action_for_class "$plan_class")"

        if [ "$plan_class" = "exclude-video" ]; then
          beets_command=""
          notes="excluded from beets/music import because current files are video-only"
        else
          beets_command="$(beets_dry_run_command_for_album "$album_dir")"
          notes=""
        fi

        printf '%s | class=%s | rank=%s | flac=%s mp3=%s mp4=%s | action=%s\n' \
          "$album_name" \
          "$plan_class" \
          "$pilot_rank" \
          "$flac_count" \
          "$mp3_count" \
          "$mp4_count" \
          "$recommended_action" >> "$REPORT"

        write_plan_row \
          "$album_dir" \
          "$album_name" \
          "$flac_count" \
          "$mp3_count" \
          "$mp4_count" \
          "$image_count" \
          "$total_bytes" \
          "$artist_probe" \
          "$library_candidate_count" \
          "$plan_class" \
          "$pilot_rank" \
          "$recommended_action" \
          "$beets_command" \
          "$notes"
      done

  {
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Recommended execution order'
    printf '\n'
    printf '%s\n' '1. Create/apply the Beets sandbox config in a separate apply phase.'
    printf '%s\n' '2. Validate BEETSDIR config and beets/chroma/fpcalc availability.'
    printf '%s\n' '3. Run first MusicBrainz dry-run on a low-risk album, likely Thembi or Spectrum.'
    printf '%s\n' '4. Capture beets output to a live log using tblive or nflog.'
    printf '%s\n' '5. Do not write tags or move files until a per-album import plan is generated and reviewed.'
    printf '\n'
    printf '%s\n' '## Example command pattern'
    printf '\n'
    printf '%s\n' '```bash'
    printf 'BEETSDIR=%s beet import -C -W %s\n' \
      "$(shell_quote_arg "$BEETS_SANDBOX_ROOT")" \
      "$(shell_quote_arg "$STAGING_DIR/<album>")"
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  log "Music staging beets sandbox plan generated."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
