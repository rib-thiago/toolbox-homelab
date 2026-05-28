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

REPORT="$REPORT_DIR/python_tooling_bootstrap_apply_report_$STAMP.txt"
TSV="$RAW_DIR/python_tooling_bootstrap_apply_$STAMP.tsv"

APPLY_MODE="${1:-}"

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

write_step() {
  local step_id="$1"
  local phase="$2"
  local status="$3"
  local command="$4"
  local notes="$5"

  tsv_row "$step_id" "$phase" "$status" "$command" "$notes" >> "$TSV"
}

append_section() {
  local title="$1"

  {
    printf '\n'
    printf '## %s\n' "$title"
    printf '\n'
  } >> "$REPORT"
}

run_step() {
  local step_id="$1"
  local phase="$2"
  local command_text="$3"
  shift 3

  append_section "$step_id - $phase"

  {
    printf '%s\n' '```text'
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
  } >> "$REPORT"

  if "$@" >> "$REPORT" 2>&1; then
    printf '\n%s\n' '[OK]' >> "$REPORT"
    printf '%s\n' '```' >> "$REPORT"
    write_step "$step_id" "$phase" "OK" "$command_text" "completed"
    return 0
  fi

  printf '\n%s\n' '[FAIL]' >> "$REPORT"
  printf '%s\n' '```' >> "$REPORT"
  write_step "$step_id" "$phase" "FAIL" "$command_text" "command failed"
  return 1
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

main() {
  require_lib_contract

  if [ "$APPLY_MODE" != "--apply" ]; then
    fail "This script modifies the host. Re-run with: apply-python-tooling-bootstrap.sh --apply"
  fi

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting Python tooling bootstrap apply."

  tsv_row "step_id" "phase" "status" "command" "notes" > "$TSV"

  {
    printf '%s\n' '# Python Tooling Bootstrap Apply'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: APPLY script. This script installs packages and may update user PATH through pipx ensurepath.'
    printf '%s\n' 'Scope: install/validate pipx, libchromaprint-tools/fpcalc and beets via pipx.'
    printf '%s\n' 'Deferred: pyenv, Poetry and musicbrainzngs remain out of scope for this apply.'
    printf '\n'
  } > "$REPORT"

  run_step "01" "apt-update" "sudo apt update" sudo apt update

  if has_cmd pipx; then
    write_step "02" "install-pipx" "SKIP" "sudo apt install -y pipx" "pipx already available"
    {
      printf '\n'
      printf '%s\n' '## 02 - install-pipx'
      printf '\n'
      printf '%s\n' 'SKIP: pipx already available.'
    } >> "$REPORT"
  else
    run_step "02" "install-pipx" "sudo apt install -y pipx" sudo apt install -y pipx
  fi

  if has_cmd fpcalc; then
    write_step "03" "install-chromaprint" "SKIP" "sudo apt install -y libchromaprint-tools" "fpcalc already available"
    {
      printf '\n'
      printf '%s\n' '## 03 - install-chromaprint'
      printf '\n'
      printf '%s\n' 'SKIP: fpcalc already available.'
    } >> "$REPORT"
  else
    run_step "03" "install-chromaprint" "sudo apt install -y libchromaprint-tools" sudo apt install -y libchromaprint-tools
  fi

  if has_cmd pipx; then
    run_step "04" "pipx-ensurepath" "pipx ensurepath" pipx ensurepath
  else
    write_step "04" "pipx-ensurepath" "FAIL" "pipx ensurepath" "pipx command unavailable after install step"
  fi

  export PATH="$HOME/.local/bin:$PATH"

  if has_cmd beet; then
    write_step "05" "install-beets" "SKIP" "pipx install beets" "beet already available"
    {
      printf '\n'
      printf '%s\n' '## 05 - install-beets'
      printf '\n'
      printf '%s\n' 'SKIP: beet already available.'
    } >> "$REPORT"
  else
    if has_cmd pipx; then
      run_step "05" "install-beets" "pipx install beets" pipx install beets
    else
      write_step "05" "install-beets" "FAIL" "pipx install beets" "pipx unavailable"
    fi
  fi

  export PATH="$HOME/.local/bin:$PATH"

  if has_cmd beet; then
    run_step "06" "validate-beet" "beet version" beet version
  else
    write_step "06" "validate-beet" "FAIL" "beet version" "beet command not found"
  fi

  if has_cmd fpcalc; then
    run_step "07" "validate-fpcalc" "fpcalc -version" fpcalc -version
  else
    write_step "07" "validate-fpcalc" "FAIL" "fpcalc -version" "fpcalc command not found"
  fi

  if has_cmd diagnose-musicbrainz-cli-tools.sh; then
    run_step "08" "rerun-musicbrainz-diagnosis" "diagnose-musicbrainz-cli-tools.sh" diagnose-musicbrainz-cli-tools.sh
  else
    write_step "08" "rerun-musicbrainz-diagnosis" "WARN" "diagnose-musicbrainz-cli-tools.sh" "command not found in PATH"
  fi

  fail_count="$(awk -F '\t' 'NR > 1 && $3 == "FAIL" { c++ } END { print c+0 }' "$TSV")"
  warn_count="$(awk -F '\t' 'NR > 1 && $3 == "WARN" { c++ } END { print c+0 }' "$TSV")"

  {
    printf '\n'
    printf '%s\n' '## Summary'
    printf '\n'
    printf 'Failures: %s\n' "$fail_count"
    printf 'Warnings: %s\n' "$warn_count"
    printf '\n'
    printf '%s\n' 'Post-apply note: if beet is not available in a new shell, reload Bash or open a new SSH session because pipx ensurepath may update shell startup files.'
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    log "Python tooling bootstrap completed with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  log "Python tooling bootstrap completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
