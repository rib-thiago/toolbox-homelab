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

STAMP="$(toolbox_timestamp)"
SHARED_DIR="$(toolbox_shared_dir)"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"

REPORT="$REPORT_DIR/musicbrainz_cli_tools_diagnosis_report_$STAMP.txt"
TSV="$RAW_DIR/musicbrainz_cli_tools_diagnosis_$STAMP.tsv"

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
  require_function tsv_row
  require_function toolbox_shared_dir
}

command_path() {
  local cmd="$1"

  command -v "$cmd" 2>/dev/null || true
}

command_version() {
  local cmd="$1"

  case "$cmd" in
    beet)
      "$cmd" version 2>/dev/null | head -n 1 || true
      ;;
    fpcalc)
      "$cmd" -version 2>&1 | head -n 1 || true
      ;;
    metaflac)
      "$cmd" --version 2>&1 | head -n 1 || true
      ;;
    ffprobe)
      "$cmd" -version 2>&1 | head -n 1 || true
      ;;
    mid3v2)
      "$cmd" --version 2>&1 | head -n 1 || true
      ;;
    id3v2)
      "$cmd" --version 2>&1 | head -n 1 || true
      ;;
    eyeD3)
      "$cmd" --version 2>&1 | head -n 1 || true
      ;;
    python3)
      "$cmd" --version 2>&1 | head -n 1 || true
      ;;
    pipx)
      "$cmd" --version 2>&1 | head -n 1 || true
      ;;
    pip3)
      "$cmd" --version 2>&1 | head -n 1 || true
      ;;
    *)
      "$cmd" --version 2>&1 | head -n 1 || true
      ;;
  esac
}

python_module_status() {
  local module="$1"

  python3 - "$module" <<'PY' 2>/dev/null
import importlib.util
import sys

module = sys.argv[1]
spec = importlib.util.find_spec(module)
if spec is None:
    print("missing")
else:
    print("available")
PY
}

python_module_version() {
  local module="$1"

  python3 - "$module" <<'PY' 2>/dev/null
import importlib
import sys

module = sys.argv[1]
try:
    mod = importlib.import_module(module)
except Exception:
    print("")
    raise SystemExit(0)

print(getattr(mod, "__version__", "version_unknown"))
PY
}

write_tool_check() {
  local tool="$1"
  local role="$2"
  local required_level="$3"
  local install_hint="$4"

  local path
  local version
  local status
  local notes

  path="$(command_path "$tool")"

  if [ -n "$path" ]; then
    status="OK"
    version="$(command_version "$tool")"
    notes="$version"
  else
    status="MISSING"
    version=""
    notes="$install_hint"
  fi

  tsv_row \
    "command" \
    "$tool" \
    "$role" \
    "$required_level" \
    "$status" \
    "$path" \
    "$version" \
    "$notes" >> "$TSV"

  printf '%s | %s | %s | %s | %s\n' "$tool" "$role" "$required_level" "$status" "${path:-not found}" >> "$REPORT"
}

write_python_module_check() {
  local module="$1"
  local role="$2"
  local required_level="$3"
  local install_hint="$4"

  local status
  local version
  local notes

  if ! command -v python3 >/dev/null 2>&1; then
    status="SKIP"
    version=""
    notes="python3 not available"
  else
    module_status="$(python_module_status "$module")"

    if [ "$module_status" = "available" ]; then
      status="OK"
      version="$(python_module_version "$module")"
      notes="$version"
    else
      status="MISSING"
      version=""
      notes="$install_hint"
    fi
  fi

  tsv_row \
    "python-module" \
    "$module" \
    "$role" \
    "$required_level" \
    "$status" \
    "" \
    "$version" \
    "$notes" >> "$TSV"

  printf '%s | %s | %s | %s\n' "$module" "$role" "$required_level" "$status" >> "$REPORT"
}

main() {
  require_toolbox_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting MusicBrainz CLI tools diagnosis."

  tsv_row \
    "check_type" \
    "name" \
    "role" \
    "required_level" \
    "status" \
    "path" \
    "version" \
    "notes" > "$TSV"

  {
    printf '%s\n' '# MusicBrainz CLI Tools Diagnosis'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: diagnosis only. This script does not install packages, write tags, move files or modify beets configuration.'
    printf '%s\n' 'Output policy: this script writes to reports/media/staging and library-db/raw/media/staging.'
    printf '%s\n' 'Purpose: prepare host workflow before future toolbox-media Docker image.'
    printf '\n'
    printf '%s\n' '## Tool checks'
    printf '\n'
    printf '%s\n' '```text'
  } > "$REPORT"

  write_tool_check "beet" "MusicBrainz autotagging and import workflow" "required-soon" "install beets before MusicBrainz CLI testing"
  write_tool_check "fpcalc" "Chromaprint acoustic fingerprinting for beets chroma plugin" "recommended" "install libchromaprint-tools for fpcalc for acoustic matching"
  write_tool_check "metaflac" "Reliable FLAC Vorbis comment inspection/writing" "required" "install flac tools"
  write_tool_check "ffprobe" "Audio/video technical metadata inspection" "required" "install ffmpeg"
  write_tool_check "mid3v2" "MP3/ID3 tag inspection and writing via mutagen" "recommended" "install python3-mutagen or equivalent"
  write_tool_check "id3v2" "Alternative MP3/ID3 tag inspection" "optional" "install id3v2 if desired"
  write_tool_check "eyeD3" "Alternative MP3/ID3 inspection" "optional" "install eyed3 if desired"
  write_tool_check "python3" "Python runtime for future MusicBrainz scripts" "required-soon" "install python3"
  write_tool_check "pipx" "Isolated Python CLI application installation" "recommended" "install pipx if using Python CLI apps outside apt"
  write_tool_check "pip3" "Python package installation/diagnostics" "optional" "install python3-pip if needed"

  {
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Python module checks'
    printf '\n'
    printf '%s\n' '```text'
  } >> "$REPORT"

  write_python_module_check "musicbrainzngs" "Future controlled MusicBrainz API queries from Python" "future" "install musicbrainzngs in a controlled environment"
  write_python_module_check "mutagen" "Audio metadata inspection/writing library used by many tools" "recommended" "install mutagen/python3-mutagen"
  write_python_module_check "beets" "Python package behind beet CLI; not required when beet is installed via pipx" "optional" "not needed if beet command is available through pipx"

  {
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Beets workflow recommendation'
    printf '\n'
    printf '%s\n' 'Use both an isolated beets sandbox and dry-run flags.'
    printf '\n'
    printf '%s\n' 'Recommended sandbox root:'
    printf '\n'
    printf '%s\n' '```text'
    printf '%s\n' '/srv/toolbox/shared/beets/media-staging'
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' 'Recommended exploratory pattern:'
    printf '\n'
    printf '%s\n' '```bash'
    printf '%s\n' 'BEETSDIR=/srv/toolbox/shared/beets/media-staging beet import -C -W /srv/media/music-staging/reviewing/<album>'
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' 'Rationale: -C and -W keep files untouched during import, while BEETSDIR keeps beets config/database isolated from any future real beets setup.'
    printf '\n'
    printf '%s\n' '## Future Docker image hints'
    printf '\n'
    printf '%s\n' 'Candidate packages/tools for toolbox-media:'
    printf '%s\n' 'beets'
    printf '%s\n' 'chromaprint/fpcalc'
    printf '%s\n' 'flac/metaflac'
    printf '%s\n' 'ffmpeg/ffprobe'
    printf '%s\n' 'python3'
    printf '%s\n' 'mutagen/mid3v2'
    printf '%s\n' 'musicbrainzngs'
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  missing_required="$(
    awk -F '\t' 'NR > 1 && ($4 == "required" || $4 == "required-soon") && $5 == "MISSING" { c++ } END { print c+0 }' "$TSV"
  )"

  {
    printf '\n'
    printf '%s\n' '## Summary'
    printf '\n'
    printf 'Missing required or required-soon tools/modules: %s\n' "$missing_required"
  } >> "$REPORT"

  if [ "$missing_required" -gt 0 ]; then
    log "Diagnosis completed with missing required/required-soon dependencies."
  else
    log "Diagnosis completed with required/required-soon dependencies available."
  fi

  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
