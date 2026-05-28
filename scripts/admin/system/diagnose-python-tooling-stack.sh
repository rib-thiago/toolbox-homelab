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

REPORT_DIR="$SHARED_DIR/reports/system/python"
RAW_DIR="$SHARED_DIR/library-db/raw/system/python"

REPORT="$REPORT_DIR/python_tooling_stack_diagnosis_report_$STAMP.txt"
TSV="$RAW_DIR/python_tooling_stack_diagnosis_$STAMP.tsv"

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

cmd_path() {
  command -v "$1" 2>/dev/null || true
}

cmd_version() {
  local cmd="$1"

  case "$cmd" in
    python3) "$cmd" --version 2>&1 | head -n 1 || true ;;
    pip3) "$cmd" --version 2>&1 | head -n 1 || true ;;
    pipx) "$cmd" --version 2>&1 | head -n 1 || true ;;
    poetry) "$cmd" --version 2>&1 | head -n 1 || true ;;
    pyenv) "$cmd" --version 2>&1 | head -n 1 || true ;;
    beet) "$cmd" version 2>/dev/null | head -n 1 || true ;;
    fpcalc) "$cmd" -version 2>&1 | head -n 1 || true ;;
    metaflac) "$cmd" --version 2>&1 | head -n 1 || true ;;
    ffprobe) "$cmd" -version 2>&1 | head -n 1 || true ;;
    *) "$cmd" --version 2>&1 | head -n 1 || true ;;
  esac
}

write_cmd_check() {
  local name="$1"
  local role="$2"
  local priority="$3"
  local path
  local version
  local status

  path="$(cmd_path "$name")"

  if [ -n "$path" ]; then
    status="OK"
    version="$(cmd_version "$name")"
  else
    status="MISSING"
    version=""
  fi

  tsv_row "command" "$name" "$role" "$priority" "$status" "$path" "$version" >> "$TSV"
  printf '%s | %s | %s | %s | %s\n' "$name" "$role" "$priority" "$status" "${path:-not found}" >> "$REPORT"
}

write_python_module_check() {
  local module="$1"
  local role="$2"
  local priority="$3"
  local status
  local version

  if ! command -v python3 >/dev/null 2>&1; then
    status="SKIP"
    version=""
  else
    status="$(
      python3 - "$module" <<'PY' 2>/dev/null
import importlib.util
import sys

module = sys.argv[1]
print("OK" if importlib.util.find_spec(module) else "MISSING")
PY
    )"

    if [ "$status" = "OK" ]; then
      version="$(
        python3 - "$module" <<'PY' 2>/dev/null
import importlib
import sys

module = sys.argv[1]
mod = importlib.import_module(module)
print(getattr(mod, "__version__", "version_unknown"))
PY
      )"
    else
      version=""
    fi
  fi

  tsv_row "python-module" "$module" "$role" "$priority" "$status" "" "$version" >> "$TSV"
  printf '%s | %s | %s | %s\n' "$module" "$role" "$priority" "$status" >> "$REPORT"
}

write_apt_policy() {
  local package="$1"

  {
    printf '\n'
    printf '### apt-cache policy %s\n' "$package"
    printf '\n'
    printf '%s\n' '```text'
    apt-cache policy "$package" 2>&1 || true
    printf '%s\n' '```'
  } >> "$REPORT"
}

main() {
  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting Python tooling stack diagnosis."

  tsv_row "check_type" "name" "role" "priority" "status" "path" "version" > "$TSV"

  {
    printf '%s\n' '# Python Tooling Stack Diagnosis'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: diagnosis only. This script does not install packages, modify shell files, create virtualenvs or change Python configuration.'
    printf '%s\n' 'Output policy: this script writes to reports/system/python and library-db/raw/system/python.'
    printf '\n'
    printf '%s\n' '## Command checks'
    printf '\n'
    printf '%s\n' '```text'
  } > "$REPORT"

  write_cmd_check "python3" "system Python runtime" "required"
  write_cmd_check "pip3" "system pip, diagnostic only; avoid global pollution" "optional"
  write_cmd_check "pipx" "isolated Python CLI installer" "recommended"
  write_cmd_check "poetry" "project dependency manager, future/CraftText" "future"
  write_cmd_check "pyenv" "Python version manager, future stack hygiene" "future"
  write_cmd_check "beet" "beets MusicBrainz CLI" "required-soon"
  write_cmd_check "fpcalc" "Chromaprint acoustic fingerprinting" "recommended"
  write_cmd_check "metaflac" "FLAC tag inspection/writing" "required"
  write_cmd_check "ffprobe" "media metadata inspection" "required"

  {
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Python module checks'
    printf '\n'
    printf '%s\n' '```text'
  } >> "$REPORT"

  write_python_module_check "mutagen" "audio metadata library" "recommended"
  write_python_module_check "beets" "Python package behind beet CLI" "required-soon"
  write_python_module_check "musicbrainzngs" "future controlled MusicBrainz API queries" "future"

  {
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## PATH and shell context'
    printf '\n'
    printf '%s\n' '```text'
    printf 'PATH=%s\n' "$PATH"
    printf '\n'
    printf '~/.local/bin in PATH: '
    case ":$PATH:" in
      *":$HOME/.local/bin:"*) printf '%s\n' 'yes' ;;
      *) printf '%s\n' 'no' ;;
    esac
    printf '\n'
    printf '~/.bashrc.d exists: '
    [ -d "$HOME/.bashrc.d" ] && printf '%s\n' 'yes' || printf '%s\n' 'no'
    printf '~/.bash_aliases.d exists: '
    [ -d "$HOME/.bash_aliases.d" ] && printf '%s\n' 'yes' || printf '%s\n' 'no'
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Apt package policy'
  } >> "$REPORT"

  write_apt_policy "pipx"
  write_apt_policy "python3-pip"
  write_apt_policy "beets"
  write_apt_policy "libchromaprint-tools"

  {
    printf '\n'
    printf '%s\n' '## Interpretation'
    printf '\n'
    printf '%s\n' 'Recommended direction: keep system Python clean, use pipx for Python CLI tools such as beets, use apt for native tools such as fpcalc/chromaprint, and defer pyenv/Poetry to a separate Python stack hygiene front unless immediately needed.'
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
