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

REPORT="$REPORT_DIR/python_tooling_bootstrap_plan_report_$STAMP.txt"
TSV="$RAW_DIR/python_tooling_bootstrap_plan_$STAMP.tsv"

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

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

write_step() {
  local step_id="$1"
  local phase="$2"
  local action="$3"
  local command="$4"
  local required="$5"
  local status="$6"
  local notes="$7"

  tsv_row "$step_id" "$phase" "$action" "$command" "$required" "$status" "$notes" >> "$TSV"
}

append_cmd() {
  local command="$1"

  {
    printf '%s\n' '```bash'
    printf '%s\n' "$command"
    printf '%s\n' '```'
    printf '\n'
  } >> "$REPORT"
}

main() {
  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Generating Python tooling bootstrap plan."

  tsv_row "step_id" "phase" "action" "command" "required" "status" "notes" > "$TSV"

  {
    printf '%s\n' '# Python Tooling Bootstrap Plan'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: plan/dry-run only. This script does not install packages or modify shell configuration.'
    printf '%s\n' 'Goal: prepare minimal host tooling for beets/MusicBrainz while deferring pyenv/Poetry to a separate future front.'
    printf '\n'
  } > "$REPORT"

  if has_cmd pipx; then
    pipx_status="SKIP"
    pipx_notes="pipx already available"
  else
    pipx_status="PLANNED"
    pipx_notes="install pipx via apt"
  fi

  if has_cmd beet; then
    beets_status="SKIP"
    beets_notes="beet already available"
  else
    beets_status="PLANNED"
    beets_notes="install beets via pipx after pipx is available"
  fi

  if has_cmd fpcalc; then
    fpcalc_status="SKIP"
    fpcalc_notes="fpcalc already available"
  else
    fpcalc_status="PLANNED"
    fpcalc_notes="install chromaprint/fpcalc via apt"
  fi

  write_step "01" "diagnose" "Review Python tooling diagnosis" "less <latest python_tooling_stack_diagnosis_report>" "yes" "READY" "Use diagnosis output before applying"
  write_step "02" "install-later" "Update apt package index" "sudo apt update" "yes" "PLANNED" "Required before apt installs"
  write_step "03" "install-later" "Install pipx if missing" "sudo apt install pipx" "recommended" "$pipx_status" "$pipx_notes"
  write_step "04" "configure-later" "Ensure pipx path" "pipx ensurepath" "recommended" "$pipx_status" "May require shell reload; check ~/.local/bin in PATH"
  write_step "05" "install-later" "Install chromaprint/fpcalc" "sudo apt install libchromaprint-tools" "recommended" "$fpcalc_status" "$fpcalc_notes"
  write_step "06" "install-later" "Install beets via pipx" "pipx install beets" "required-soon" "$beets_status" "$beets_notes"
  write_step "07" "validate-later" "Validate beet command" "beet version" "yes" "PLANNED" "Confirms beets CLI"
  write_step "08" "validate-later" "Validate fpcalc command" "fpcalc -version" "recommended" "PLANNED" "Confirms chromaprint"
  write_step "09" "validate-later" "Rerun MusicBrainz tooling diagnosis" "diagnose-musicbrainz-cli-tools.sh" "yes" "PLANNED" "Return to media staging workflow"
  write_step "10" "git-later" "Review Git status for this parenthesis" "git status --short" "yes" "PLANNED" "Prepare dedicated Git cycle"

  {
    printf '%s\n' '## Proposed command sequence'
    printf '\n'
  } >> "$REPORT"

  append_cmd "cd /srv/toolbox/app || exit 1"
  append_cmd "sudo apt update"

  if [ "$pipx_status" = "PLANNED" ]; then
    append_cmd "sudo apt install pipx"
    append_cmd "pipx ensurepath"
  fi

  if [ "$fpcalc_status" = "PLANNED" ]; then
    append_cmd "sudo apt install libchromaprint-tools"
  fi

  if [ "$beets_status" = "PLANNED" ]; then
    append_cmd "pipx install beets"
  fi

  append_cmd "beet version"
  append_cmd "fpcalc -version"
  append_cmd "diagnose-musicbrainz-cli-tools.sh"

  {
    printf '%s\n' '## Deferred deliberately'
    printf '\n'
    printf '%s\n' '- pyenv: defer to a future Python stack hygiene front.'
    printf '%s\n' '- Poetry: install later via pipx when needed for CraftText or project development.'
    printf '%s\n' '- musicbrainzngs: defer to future Python script/venv/toolbox-media unless immediately needed.'
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  log "Plan generated."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
