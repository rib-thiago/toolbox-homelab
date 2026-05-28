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
SNAPSHOT_DIR="$SHARED_DIR/library-db/snapshots/system/shell"

REPORT="$REPORT_DIR/shell_artifact_helpers_apply_report_$STAMP.txt"
TSV="$RAW_DIR/shell_artifact_helpers_apply_$STAMP.tsv"

APPLY_MODE="${1:-}"

ALIAS_DIR="$HOME/.bash_aliases.d"
DEV_FILE="$ALIAS_DIR/50-dev.sh"
ARTIFACTS_FILE="$ALIAS_DIR/85-toolbox-artifacts.sh"
JOBS_FILE="$ALIAS_DIR/95-jobs.sh"

ARTIFACTS_MARKER="toolbox-artifact-helpers"
JOBS_MARKER="toolbox-live-log-helpers"
DEV_MARKER="toolbox-mkxcheck-helper"

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
  local target="$3"
  local status="$4"
  local action="$5"
  local notes="$6"

  tsv_row \
    "$step_id" \
    "$phase" \
    "$target" \
    "$status" \
    "$action" \
    "$notes" >> "$TSV"
}

append_section() {
  local title="$1"

  {
    printf '\n'
    printf '## %s\n' "$title"
    printf '\n'
  } >> "$REPORT"
}

confirm_apply() {
  local confirmation

  if [ "$APPLY_MODE" != "--apply" ]; then
    fail "This script modifies shell files. Re-run with: apply-shell-artifact-helpers.sh --apply"
  fi

  printf '%s\n' "This script will modify files under: $ALIAS_DIR"
  printf '%s\n' "Backups will be written under: $SNAPSHOT_DIR"
  printf '%s' "Type APPLY to continue: "
  read -r confirmation

  if [ "$confirmation" != "APPLY" ]; then
    fail "Apply aborted by user."
  fi
}

safe_name_for_path() {
  local path="$1"

  printf '%s' "$path" | sed 's#^/##; s#[/ ]#_#g'
}

backup_file() {
  local file="$1"
  local safe_name
  local backup_path

  mkdir -p "$SNAPSHOT_DIR"

  if [ ! -e "$file" ]; then
    write_step "BACKUP" "backup" "$file" "SKIP" "backup missing file" "target does not exist yet"
    return 0
  fi

  safe_name="$(safe_name_for_path "$file")"
  backup_path="$SNAPSHOT_DIR/${safe_name}_backup_$STAMP"

  cp -a "$file" "$backup_path"

  write_step "BACKUP" "backup" "$file" "OK" "created backup" "$backup_path"
}

ensure_alias_dir() {
  if [ -d "$ALIAS_DIR" ]; then
    write_step "PRE-001" "preflight" "$ALIAS_DIR" "OK" "alias dir exists" ""
    return 0
  fi

  mkdir -p "$ALIAS_DIR"
  write_step "PRE-001" "preflight" "$ALIAS_DIR" "OK" "created alias dir" ""
}

ensure_file_exists() {
  local file="$1"

  if [ -e "$file" ]; then
    if [ -f "$file" ]; then
      write_step "PRE-FILE" "preflight" "$file" "OK" "file exists" ""
      return 0
    fi

    write_step "PRE-FILE" "preflight" "$file" "FAIL" "target exists but is not a regular file" ""
    return 1
  fi

  {
    printf '# %s\n' "$file"
    printf '# Created by apply-shell-artifact-helpers.sh at %s\n' "$(toolbox_now)"
    printf '\n'
  } > "$file"

  write_step "PRE-FILE" "preflight" "$file" "OK" "created file" ""
}

marker_exists() {
  local file="$1"
  local marker="$2"

  [ -f "$file" ] && grep -q "^# >>> $marker$" "$file"
}

append_block_file() {
  local step_id="$1"
  local file="$2"
  local marker="$3"
  local block_file="$4"

  append_section "$step_id - $file"

  if marker_exists "$file" "$marker"; then
    write_step "$step_id" "apply" "$file" "SKIP" "marker already exists" "$marker"

    {
      printf '%s\n' "Marker already exists, not appending duplicate block: $marker"
      printf '\n'
    } >> "$REPORT"

    return 0
  fi

  backup_file "$file"

  {
    printf '\n'
    cat "$block_file"
    printf '\n'
  } >> "$file"

  write_step "$step_id" "apply" "$file" "OK" "appended helper block" "$marker"

  {
    printf '%s\n' "Appended block: $marker"
    printf '\n'
    printf '%s\n' '```bash'
    cat "$block_file"
    printf '%s\n' '```'
  } >> "$REPORT"
}

create_artifacts_block() {
  local block_file="$1"

  cat > "$block_file" <<'EOF'
# >>> toolbox-artifact-helpers
# Toolbox artifact reading helpers.
#
# Purpose:
# - read TSVs safely with column + less;
# - read reports with bat/batcat fallback to less;
# - locate latest artifacts without relying on ls aliases.
#
# No temporary/domain-specific aliases are defined here.

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
# <<< toolbox-artifact-helpers
EOF
}

create_jobs_block() {
  local block_file="$1"

  cat > "$block_file" <<'EOF'
# >>> toolbox-live-log-helpers
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
# <<< toolbox-live-log-helpers
EOF
}

create_dev_block() {
  local block_file="$1"

  cat > "$block_file" <<'EOF'
# >>> toolbox-mkxcheck-helper
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
# <<< toolbox-mkxcheck-helper
EOF
}

validate_shell_file() {
  local file="$1"

  if bash -n "$file" >/dev/null 2>&1; then
    write_step "VALIDATE" "validate" "$file" "OK" "bash -n passed" ""
    return 0
  fi

  write_step "VALIDATE" "validate" "$file" "FAIL" "bash -n failed" ""
  return 1
}

validate_loaded_helpers() {
  local result_file="$1"

  if bash -ic 'type latest-file tsvless tsvlatest rptless rptlatest tblatest nflog tblive mkxcheck' > "$result_file" 2>&1; then
    write_step "VALIDATE" "validate" "interactive shell" "OK" "helpers loaded in bash -ic" "$result_file"
    return 0
  fi

  write_step "VALIDATE" "validate" "interactive shell" "WARN" "helpers not all visible in bash -ic" "$result_file"
  return 0
}

main() {
  local artifacts_block
  local jobs_block
  local dev_block
  local type_result
  local fail_count

  require_lib_contract
  confirm_apply

  mkdir -p "$REPORT_DIR" "$RAW_DIR" "$SNAPSHOT_DIR"

  log "Starting shell artifact helpers apply."

  tsv_row \
    "step_id" \
    "phase" \
    "target" \
    "status" \
    "action" \
    "notes" > "$TSV"

  {
    printf '%s\n' '# Shell Artifact Helpers Apply'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Alias dir: %s\n' "$ALIAS_DIR"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf 'Snapshot dir: %s\n' "$SNAPSHOT_DIR"
    printf '\n'
    printf '%s\n' 'Safety: APPLY script. This script modifies shell alias files after --apply and textual APPLY confirmation.'
    printf '%s\n' 'Scope: add generic Toolbox artifact readers, live-log helpers, and mkxcheck. No temporary/domain-specific aliases are added.'
    printf '\n'
  } > "$REPORT"

  ensure_alias_dir

  ensure_file_exists "$DEV_FILE"
  ensure_file_exists "$ARTIFACTS_FILE"
  ensure_file_exists "$JOBS_FILE"

  artifacts_block="$(mktemp)"
  jobs_block="$(mktemp)"
  dev_block="$(mktemp)"
  type_result="$(mktemp)"

  create_artifacts_block "$artifacts_block"
  create_jobs_block "$jobs_block"
  create_dev_block "$dev_block"

  append_block_file "APPLY-001" "$ARTIFACTS_FILE" "$ARTIFACTS_MARKER" "$artifacts_block"
  append_block_file "APPLY-002" "$JOBS_FILE" "$JOBS_MARKER" "$jobs_block"
  append_block_file "APPLY-003" "$DEV_FILE" "$DEV_MARKER" "$dev_block"

  append_section "Validation"

  validate_shell_file "$DEV_FILE"
  validate_shell_file "$ARTIFACTS_FILE"
  validate_shell_file "$JOBS_FILE"
  validate_shell_file "$HOME/.bash_aliases"

  validate_loaded_helpers "$type_result"

  {
    printf '%s\n' '```text'
    cat "$type_result" 2>/dev/null || true
    printf '%s\n' '```'
  } >> "$REPORT"

  rm -f "$artifacts_block" "$jobs_block" "$dev_block" "$type_result"

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$TSV")"
  warn_count="$(awk -F '\t' 'NR > 1 && $4 == "WARN" { c++ } END { print c+0 }' "$TSV")"

  {
    printf '\n'
    printf '%s\n' '## Summary'
    printf '\n'
    printf 'Failures: %s\n' "$fail_count"
    printf 'Warnings: %s\n' "$warn_count"
    printf '\n'
    printf '%s\n' 'Next phase: run a dedicated validate-shell-artifact-helpers.sh script.'
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    log "Shell artifact helpers apply completed with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  log "Shell artifact helpers apply completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
