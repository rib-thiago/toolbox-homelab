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

REPORT_DIR="$SHARED_DIR/reports/system/shell"
RAW_DIR="$SHARED_DIR/library-db/raw/system/shell"

REPORT="$REPORT_DIR/shell_artifact_helpers_plan_report_$STAMP.txt"
TSV="$RAW_DIR/shell_artifact_helpers_plan_$STAMP.tsv"

ALIAS_DIR="$HOME/.bash_aliases.d"

DEV_FILE="$ALIAS_DIR/50-dev.sh"
ARTIFACTS_FILE="$ALIAS_DIR/85-toolbox-artifacts.sh"
JOBS_FILE="$ALIAS_DIR/95-jobs.sh"

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
  local target_file="$2"
  local helper_name="$3"
  local helper_type="$4"
  local action="$5"
  local status="$6"
  local notes="$7"

  tsv_row \
    "$step_id" \
    "$target_file" \
    "$helper_name" \
    "$helper_type" \
    "$action" \
    "$status" \
    "$notes" >> "$TSV"
}

helper_exists_in_alias_dir() {
  local helper="$1"

  if [ ! -d "$ALIAS_DIR" ]; then
    return 1
  fi

  grep -R "^[[:space:]]*$helper[[:space:]]*()" "$ALIAS_DIR" >/dev/null 2>&1
}

alias_exists_in_alias_dir() {
  local helper="$1"

  if [ ! -d "$ALIAS_DIR" ]; then
    return 1
  fi

  grep -R "^[[:space:]]*alias[[:space:]]\\+$helper=" "$ALIAS_DIR" >/dev/null 2>&1
}

planned_or_skip_function() {
  local step_id="$1"
  local target_file="$2"
  local helper="$3"
  local notes="$4"

  if helper_exists_in_alias_dir "$helper"; then
    write_step "$step_id" "$target_file" "$helper" "function" "preserve existing" "SKIP" "$notes"
  else
    write_step "$step_id" "$target_file" "$helper" "function" "add" "PLANNED" "$notes"
  fi
}

planned_or_skip_alias() {
  local step_id="$1"
  local target_file="$2"
  local helper="$3"
  local notes="$4"

  if alias_exists_in_alias_dir "$helper"; then
    write_step "$step_id" "$target_file" "$helper" "alias" "preserve existing" "SKIP" "$notes"
  else
    write_step "$step_id" "$target_file" "$helper" "alias" "add optional" "PLANNED" "$notes"
  fi
}

append_section() {
  local title="$1"

  {
    printf '\n'
    printf '## %s\n' "$title"
    printf '\n'
  } >> "$REPORT"
}

append_code_block() {
  local title="$1"

  append_section "$title"
  printf '%s\n' '```bash' >> "$REPORT"
  cat >> "$REPORT"
  printf '%s\n' '```' >> "$REPORT"
}

main() {
  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Generating shell artifact helpers plan."

  tsv_row \
    "step_id" \
    "target_file" \
    "helper_name" \
    "helper_type" \
    "action" \
    "status" \
    "notes" > "$TSV"

  {
    printf '%s\n' '# Shell Artifact Helpers Plan'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Alias dir: %s\n' "$ALIAS_DIR"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: plan/dry-run only. This script does not modify shell files.'
    printf '%s\n' 'Goal: plan robust helpers for reading Toolbox artifacts, live logs, and mkx+bashcheck ergonomics.'
    printf '\n'
  } > "$REPORT"

  if [ -d "$ALIAS_DIR" ]; then
    write_step "00" "$ALIAS_DIR" "alias directory" "path" "verify" "OK" "alias directory exists"
  else
    write_step "00" "$ALIAS_DIR" "alias directory" "path" "create later" "PLANNED" "alias directory missing"
  fi

  planned_or_skip_function "01" "$ARTIFACTS_FILE" "latest-file" "Find latest file in a directory by mtime without relying on ls."
  planned_or_skip_function "02" "$ARTIFACTS_FILE" "tsvless" "Read one TSV using column and less -S."
  planned_or_skip_function "03" "$ARTIFACTS_FILE" "tsvlatest" "Read latest matching TSV using latest-file."
  planned_or_skip_function "04" "$ARTIFACTS_FILE" "rptless" "Read report with bat/batcat fallback to less."
  planned_or_skip_function "05" "$ARTIFACTS_FILE" "rptlatest" "Read latest matching report."
  planned_or_skip_function "06" "$ARTIFACTS_FILE" "tblatest" "Find latest artifact below /srv/toolbox/shared by domain path."

  planned_or_skip_function "07" "$JOBS_FILE" "nflog" "Run command with nohup to a given log path, creating log directory first, then tail -f."
  planned_or_skip_function "08" "$JOBS_FILE" "tblive" "Run Toolbox command with generated live log under /srv/toolbox/shared/reports/<context>."

  planned_or_skip_function "09" "$DEV_FILE" "mkxcheck" "Explicitly run mkx then bashcheck; does not merge chmod into bashcheck."

  planned_or_skip_alias "10" "$ARTIFACTS_FILE" "msr" "Optional shortcut for latest media/staging report."
  planned_or_skip_alias "11" "$ARTIFACTS_FILE" "mst" "Optional shortcut for latest media/staging TSV."
  planned_or_skip_alias "12" "$ARTIFACTS_FILE" "pyr" "Optional shortcut for latest system/python report."
  planned_or_skip_alias "13" "$ARTIFACTS_FILE" "pyt" "Optional shortcut for latest system/python TSV."

  append_section "Recommended target files"

  {
    printf '%s\n' '- ~/.bash_aliases.d/85-toolbox-artifacts.sh'
    printf '%s\n' '  - latest-file'
    printf '%s\n' '  - tsvless'
    printf '%s\n' '  - tsvlatest'
    printf '%s\n' '  - rptless'
    printf '%s\n' '  - rptlatest'
    printf '%s\n' '  - tblatest'
    printf '%s\n' '  - optional domain shortcuts'
    printf '\n'
    printf '%s\n' '- ~/.bash_aliases.d/95-jobs.sh'
    printf '%s\n' '  - nflog'
    printf '%s\n' '  - tblive'
    printf '\n'
    printf '%s\n' '- ~/.bash_aliases.d/50-dev.sh'
    printf '%s\n' '  - mkxcheck'
  } >> "$REPORT"

  append_code_block "Planned ~/.bash_aliases.d/85-toolbox-artifacts.sh" <<'EOF'
# ~/.bash_aliases.d/85-toolbox-artifacts.sh
# Toolbox artifact reading helpers.
#
# Purpose:
# - read TSVs safely with column + less;
# - read reports with bat/batcat fallback to less;
# - locate latest artifacts without relying on ls aliases.

latest-file() {
    local dir="${1:-}"
    local pattern="${2:-*}"

    if [ -z "$dir" ]; then
        echo "uso: latest-file <dir> [pattern]" >&2
        return 2
    fi

    if [ ! -d "$dir" ]; then
        echo "erro: diretório não encontrado: $dir" >&2
        return 1
    fi

    find "$dir" -maxdepth 1 -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null \
        | sort -nr \
        | head -n 1 \
        | cut -d' ' -f2-
}

tsvless() {
    local file="${1:-}"

    if [ -z "$file" ]; then
        echo "uso: tsvless <arquivo.tsv>" >&2
        return 2
    fi

    if [ ! -f "$file" ]; then
        echo "erro: TSV não encontrado ou não é arquivo: $file" >&2
        return 1
    fi

    column -t -s $'\t' "$file" | less -S
}

tsvlatest() {
    local dir="${1:-}"
    local pattern="${2:-*.tsv}"
    local file

    if [ -z "$dir" ]; then
        echo "uso: tsvlatest <dir> [pattern]" >&2
        return 2
    fi

    file="$(latest-file "$dir" "$pattern")"

    if [ -z "$file" ]; then
        echo "erro: nenhum TSV encontrado em $dir com padrão $pattern" >&2
        return 1
    fi

    tsvless "$file"
}

rptless() {
    local file="${1:-}"

    if [ -z "$file" ]; then
        echo "uso: rptless <arquivo.txt|md|log>" >&2
        return 2
    fi

    if [ ! -f "$file" ]; then
        echo "erro: report não encontrado ou não é arquivo: $file" >&2
        return 1
    fi

    if command -v bat >/dev/null 2>&1; then
        bat --paging=always "$file"
    elif command -v batcat >/dev/null 2>&1; then
        batcat --paging=always "$file"
    else
        less "$file"
    fi
}

rptlatest() {
    local dir="${1:-}"
    local pattern="${2:-*.txt}"
    local file

    if [ -z "$dir" ]; then
        echo "uso: rptlatest <dir> [pattern]" >&2
        return 2
    fi

    file="$(latest-file "$dir" "$pattern")"

    if [ -z "$file" ]; then
        echo "erro: nenhum report encontrado em $dir com padrão $pattern" >&2
        return 1
    fi

    rptless "$file"
}

tblatest() {
    local domain="${1:-}"
    local pattern="${2:-*}"

    if [ -z "$domain" ]; then
        echo "uso: tblatest <domínio-em-/srv/toolbox/shared> [pattern]" >&2
        echo "exemplo: tblatest reports/media/staging '*diagnosis_report_*.txt'" >&2
        echo "exemplo: tblatest library-db/raw/media/staging '*.tsv'" >&2
        return 2
    fi

    latest-file "/srv/toolbox/shared/$domain" "$pattern"
}

# Optional shortcuts for frequent current domains.
alias msr='rptlatest /srv/toolbox/shared/reports/media/staging'
alias mst='tsvlatest /srv/toolbox/shared/library-db/raw/media/staging'
alias pyr='rptlatest /srv/toolbox/shared/reports/system/python'
alias pyt='tsvlatest /srv/toolbox/shared/library-db/raw/system/python'
alias shr='rptlatest /srv/toolbox/shared/reports/system/shell'
alias sht='tsvlatest /srv/toolbox/shared/library-db/raw/system/shell'
EOF

  append_code_block "Planned additions to ~/.bash_aliases.d/95-jobs.sh" <<'EOF'
# Toolbox live-log helpers.
#
# These helpers complement existing nf/tf aliases by creating the log directory
# before redirection.

nflog() {
    local logfile="${1:-}"

    if [ -z "$logfile" ]; then
        echo "uso: nflog <logfile> <comando> [args...]" >&2
        return 2
    fi

    shift

    if [ "$#" -eq 0 ]; then
        echo "uso: nflog <logfile> <comando> [args...]" >&2
        return 2
    fi

    mkdir -p "$(dirname "$logfile")" || return 1

    nohup "$@" > "$logfile" 2>&1 &
    echo "PID: $!"
    echo "LOG: $logfile"
    tail -f "$logfile"
}

tblive() {
    local context="${1:-}"
    local command_name="${2:-}"

    if [ -z "$context" ] || [ -z "$command_name" ]; then
        echo "uso: tblive <contexto> <comando> [args...]" >&2
        echo "exemplo: tblive media/staging diagnose-music-staging-reviewing.sh" >&2
        echo "exemplo: tblive system/python diagnose-python-tooling-stack.sh" >&2
        return 2
    fi

    shift 2

    local stamp
    local logfile

    stamp="$(date +%Y%m%d-%H%M%S)"
    logfile="/srv/toolbox/shared/reports/$context/${command_name%.*}_live_${stamp}.log"

    mkdir -p "$(dirname "$logfile")" || return 1

    nohup "$command_name" "$@" > "$logfile" 2>&1 &
    echo "PID: $!"
    echo "LOG: $logfile"
    tail -f "$logfile"
}
EOF

  append_code_block "Planned addition to ~/.bash_aliases.d/50-dev.sh" <<'EOF'
# Explicit helper: run mkx, then bashcheck.
#
# This intentionally does not merge chmod behavior into bashcheck.
# It is only a convenience alternative to:
#   fc nano=mkx
#   fc mkx=bashcheck

mkxcheck() {
    local script="${1:-}"

    if [ -z "$script" ]; then
        echo "uso: mkxcheck <script.sh>" >&2
        return 2
    fi

    if [ ! -f "$script" ]; then
        echo "erro: arquivo não encontrado: $script" >&2
        return 1
    fi

    echo "+ mkx $script"
    mkx "$script" || return 1

    echo "+ bashcheck $script"
    bashcheck "$script"
}
EOF

  planned_count="$(awk -F '\t' 'NR > 1 && $6 == "PLANNED" { c++ } END { print c+0 }' "$TSV")"
  skip_count="$(awk -F '\t' 'NR > 1 && $6 == "SKIP" { c++ } END { print c+0 }' "$TSV")"

  {
    printf '\n'
    printf '%s\n' '## Summary'
    printf '\n'
    printf 'Planned items: %s\n' "$planned_count"
    printf 'Skipped existing items: %s\n' "$skip_count"
    printf '\n'
    printf '%s\n' 'Next step after review: create apply-shell-artifact-helpers.sh with --apply and textual APPLY confirmation.'
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  log "Shell artifact helpers plan generated."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
