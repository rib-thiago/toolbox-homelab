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

BEETS_SANDBOX_ROOT="${BEETS_SANDBOX_ROOT:-$SHARED_DIR/beets/media-staging}"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"

REPORT="$REPORT_DIR/music_staging_beets_plugin_readiness_report_$STAMP.txt"
TSV="$RAW_DIR/music_staging_beets_plugin_readiness_$STAMP.tsv"
COMMANDS_TSV="$RAW_DIR/music_staging_beets_command_readiness_$STAMP.tsv"
DEPS_TSV="$RAW_DIR/music_staging_dependency_readiness_$STAMP.tsv"

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

enabled_plugins() {
  if ! command -v beet >/dev/null 2>&1; then
    return 0
  fi

  BEETSDIR="$BEETS_SANDBOX_ROOT" beet version 2>/dev/null \
    | awk -F: '/^plugins:/ { gsub(/^ +/, "", $2); print $2; exit }'
}

is_enabled_plugin() {
  local plugin="$1"
  local enabled="$2"

  printf '%s\n' "$enabled" | tr ' ' '\n' | grep -Fx "$plugin" >/dev/null 2>&1
}

test_plugin_loadable() {
  local plugin="$1"
  local tmpdir
  local output
  local status

  if ! command -v beet >/dev/null 2>&1; then
    printf '%s' "beet_missing"
    return 0
  fi

  tmpdir="$(mktemp -d)"
  output="$tmpdir/output.txt"

  cat > "$tmpdir/config.yaml" <<EOF
directory: $tmpdir/library
library: $tmpdir/library.blb
plugins: $plugin
import:
  copy: no
  write: no
  move: no
EOF

  mkdir -p "$tmpdir/library"

  set +e
  BEETSDIR="$tmpdir" beet version > "$output" 2>&1
  status="$?"
  set -u

  if [ "$status" -eq 0 ] && ! grep -Ei 'error loading plugin|PluginImportError|ModuleNotFoundError|Could not import plugin|No module named|Traceback' "$output" >/dev/null 2>&1; then
    rm -rf "$tmpdir"
    printf '%s' "yes"
    return 0
  fi

  if grep -Ei 'error loading plugin|PluginImportError|ModuleNotFoundError|Could not import plugin|No module named' "$output" >/dev/null 2>&1; then
    printf '%s' "no"
  else
    printf '%s' "unknown"
  fi

  rm -rf "$tmpdir"
}

check_beet_command() {
  local command_name="$1"
  local status
  local notes

  if ! command -v beet >/dev/null 2>&1; then
    tsv_row "$command_name" "missing" "beet command not found" >> "$COMMANDS_TSV"
    return 0
  fi

  if BEETSDIR="$BEETS_SANDBOX_ROOT" beet help "$command_name" >/dev/null 2>&1; then
    status="available"
    notes="beet help $command_name succeeded"
  else
    status="missing_or_not_enabled"
    notes="beet help $command_name failed; plugin may be disabled or unavailable"
  fi

  tsv_row "$command_name" "$status" "$notes" >> "$COMMANDS_TSV"
}

check_dependency() {
  local name="$1"
  local command_name="$2"
  local purpose="$3"
  local status
  local path
  local version

  if command -v "$command_name" >/dev/null 2>&1; then
    status="available"
    path="$(command -v "$command_name")"
    case "$command_name" in
      flac)
        version="$("$command_name" --version 2>&1 | head -n 1)"
        ;;
      ffprobe)
        version="$("$command_name" -version 2>&1 | head -n 1)"
        ;;
      metaflac)
        version="$("$command_name" --version 2>&1 | head -n 1)"
        ;;
      fpcalc)
        version="$("$command_name" -version 2>&1 | head -n 1)"
        ;;
      magick|identify)
        version="$("$command_name" -version 2>&1 | head -n 1)"
        ;;
      mp3val|mp3check|rsgain|ffmpeg|curl|python3)
        version="$("$command_name" --version 2>&1 | head -n 1 || true)"
        ;;
      *)
        version="version_check_not_defined"
        ;;
    esac
  else
    status="missing"
    path=""
    version=""
  fi

  tsv_row "$name" "$command_name" "$status" "$path" "$version" "$purpose" >> "$DEPS_TSV"
}

plugin_row() {
  local plugin="$1"
  local role="$2"
  local desired_state="$3"
  local toolbox_form="$4"
  local required_before_ready="$5"
  local timing="$6"
  local priority="$7"
  local enabled="$8"
  local loadable
  local enabled_status
  local readiness
  local notes

  loadable="$(test_plugin_loadable "$plugin")"

  if is_enabled_plugin "$plugin" "$enabled"; then
    enabled_status="yes"
  else
    enabled_status="no"
  fi

  readiness="unknown"
  notes=""

  case "$loadable:$enabled_status" in
    yes:yes)
      readiness="enabled"
      notes="plugin loadable and enabled in current BEETSDIR"
      ;;
    yes:no)
      readiness="available_not_enabled"
      notes="plugin appears loadable but is not enabled in current BEETSDIR"
      ;;
    no:yes)
      readiness="enabled_but_not_loadable"
      notes="plugin enabled but standalone load test failed; inspect config/dependencies"
      ;;
    no:no)
      readiness="missing_or_dependency_missing"
      notes="plugin did not load in isolated test"
      ;;
    beet_missing:*)
      readiness="beet_missing"
      notes="beet command not found"
      ;;
    *)
      readiness="unknown"
      notes="plugin loadability unclear"
      ;;
  esac

  tsv_row \
    "$plugin" \
    "$role" \
    "$desired_state" \
    "$toolbox_form" \
    "$required_before_ready" \
    "$timing" \
    "$priority" \
    "$enabled_status" \
    "$loadable" \
    "$readiness" \
    "$notes" >> "$TSV"
}

main() {
  local enabled
  local beet_version
  local beet_config_output
  local config_plugins_line

  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting Beets plugin readiness diagnosis."

  tsv_row \
    "plugin" \
    "role" \
    "desired_state" \
    "toolbox_form" \
    "required_before_ready" \
    "timing" \
    "priority" \
    "enabled_in_current_beetsdir" \
    "loadable_in_isolated_profile" \
    "readiness" \
    "notes" > "$TSV"

  tsv_row \
    "command" \
    "status" \
    "notes" > "$COMMANDS_TSV"

  tsv_row \
    "dependency" \
    "command" \
    "status" \
    "path" \
    "version" \
    "purpose" > "$DEPS_TSV"

  if command -v beet >/dev/null 2>&1; then
    beet_version="$(BEETSDIR="$BEETS_SANDBOX_ROOT" beet version 2>&1 || true)"
    beet_config_output="$(BEETSDIR="$BEETS_SANDBOX_ROOT" beet config 2>&1 || true)"
    config_plugins_line="$(printf '%s\n' "$beet_config_output" | awk '/^plugins:/ { print; exit }')"
  else
    beet_version="beet command missing"
    beet_config_output="beet command missing"
    config_plugins_line=""
  fi

  enabled="$(enabled_plugins)"

  plugin_row "chroma" "fingerprint/acoustic identification" "core_validated" "existing-identification-workflow" "yes" "reviewing" "high" "$enabled"
  plugin_row "musicbrainz" "release metadata and MBID source" "core_validated" "existing-identification-workflow" "yes" "reviewing" "high" "$enabled"
  plugin_row "fromfilename" "derive tags from filenames for problematic/tagless albums" "available_when_needed" "diagnostic-substep" "no" "reviewing" "low-medium" "$enabled"

  plugin_row "badfiles" "technical file integrity via Beets" "backend_in_integrity_stack" "internal-backend-no-wrapper-initially" "yes" "end-of-tagging" "high" "$enabled"
  plugin_row "missing" "release completeness against selected release" "diagnostic_backend" "workflow-diagnose" "yes" "tagging-before-ready" "medium-high" "$enabled"
  plugin_row "duplicates" "duplicate detection against Beets/library/staging context" "diagnostic_backend" "workflow-diagnose" "yes" "tagging-before-ready" "medium-high" "$enabled"

  plugin_row "fetchart" "cover sidecar discovery/download" "install_test_controlled" "workflow-plan-apply-validate" "probably" "tagging-artwork" "high" "$enabled"
  plugin_row "embedart" "embed artwork into audio files" "install_test_controlled" "workflow-plan-apply-validate-with-backup" "policy-yes-if-embed-adopted" "after-sidecar-artwork" "high" "$enabled"
  plugin_row "replaygain" "perceived loudness metadata" "install_test_controlled" "workflow-or-run-job" "probably-or-explicitly-deferred" "end-of-tagging" "medium-high" "$enabled"

  plugin_row "lyrics" "lyrics enrichment" "opt_in" "future-workflow-opt-in" "no" "tagging-optional" "low" "$enabled"
  plugin_row "lastgenre" "genre candidates from external tags" "diagnostic_candidates" "diagnose-then-human-apply" "no" "tagging" "medium" "$enabled"
  plugin_row "rewrite" "artist/path canonicalization for import" "implement_this_phase" "import-canonicalization-front" "not-for-ready-but-before-import" "ready-to-import" "high" "$enabled"
  plugin_row "convert" "derived export/transcode" "implement_this_phase" "run-job-pipeline-export" "no" "export" "medium" "$enabled"

  plugin_row "discogs" "alternative metadata source" "out_for_now" "future-reviewing-source" "no" "future" "deferred" "$enabled"
  plugin_row "scrub" "destructive tag cleanup/rewrite from Beets DB" "out_for_now" "future-controlled-front" "no" "future" "deferred" "$enabled"

  check_beet_command "import"
  check_beet_command "bad"
  check_beet_command "missing"
  check_beet_command "duplicates"
  check_beet_command "fetchart"
  check_beet_command "embedart"
  check_beet_command "replaygain"
  check_beet_command "lyrics"
  check_beet_command "lastgenre"
  check_beet_command "convert"

  check_dependency "beets" "beet" "Beets CLI"
  check_dependency "python" "python3" "Script helpers and MusicBrainz JSON parsing"
  check_dependency "curl" "curl" "MusicBrainz/API access"
  check_dependency "flac" "flac" "FLAC technical integrity validation"
  check_dependency "ffprobe" "ffprobe" "Audio probing/duration/format validation"
  check_dependency "ffmpeg" "ffmpeg" "Transcoding/export backend and media tooling"
  check_dependency "metaflac" "metaflac" "FLAC tag and embedded art inspection"
  check_dependency "fpcalc" "fpcalc" "Acoustic fingerprint support"
  check_dependency "imagemagick-magick" "magick" "Artwork inspection/conversion"
  check_dependency "imagemagick-identify" "identify" "Artwork inspection"
  check_dependency "mp3val" "mp3val" "MP3 technical integrity validation"
  check_dependency "mp3check" "mp3check" "MP3 technical integrity validation"
  check_dependency "rsgain" "rsgain" "ReplayGain backend candidate"

  {
    printf '%s\n' '# Music Staging Beets Plugin Readiness Diagnosis'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'BEETSDIR: %s\n' "$BEETS_SANDBOX_ROOT"
    printf 'Report: %s\n' "$REPORT"
    printf 'Plugin TSV: %s\n' "$TSV"
    printf 'Command TSV: %s\n' "$COMMANDS_TSV"
    printf 'Dependency TSV: %s\n' "$DEPS_TSV"
    printf '\n'
    printf '%s\n' 'Safety: diagnosis only. This script does not run Beets import, apply plugins to albums, write tags, move files, delete files, or modify /srv/media/music.'
    printf '\n'

    printf '%s\n' '## Beets version'
    printf '\n'
    printf '%s\n' '```text'
    printf '%s\n' "$beet_version"
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' '## Current config plugin line'
    printf '\n'
    printf '%s\n' '```text'
    printf '%s\n' "${config_plugins_line:-missing}"
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' '## Plugin readiness'
    printf '\n'
    printf '%s\n' '```text'
    column -t -s $'\t' "$TSV" 2>/dev/null || cat "$TSV"
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' '## Beets command readiness'
    printf '\n'
    printf '%s\n' '```text'
    column -t -s $'\t' "$COMMANDS_TSV" 2>/dev/null || cat "$COMMANDS_TSV"
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' '## External dependency readiness'
    printf '\n'
    printf '%s\n' '```text'
    column -t -s $'\t' "$DEPS_TSV" 2>/dev/null || cat "$DEPS_TSV"
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' '## Interpretation'
    printf '\n'
    printf '%s\n' '- enabled: plugin is loadable and enabled in the current Beets sandbox.'
    printf '%s\n' '- available_not_enabled: plugin appears loadable but is not enabled in the current sandbox.'
    printf '%s\n' '- missing_or_dependency_missing: plugin failed isolated load; may need dependency, install or config.'
    printf '%s\n' '- Command readiness depends on plugin being enabled in the active BEETSDIR.'
    printf '%s\n' '- Wrapper creation should be reserved for plugins where Toolbox policy adds value beyond beet <command>.'
    printf '\n'
  } > "$REPORT"

  log "Beets plugin readiness diagnosis completed."
  log "Report: $REPORT"
  log "Plugin TSV: $TSV"
  log "Command TSV: $COMMANDS_TSV"
  log "Dependency TSV: $DEPS_TSV"
}

main "$@"
