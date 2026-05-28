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

REPORT="$REPORT_DIR/shell_artifact_helpers_repair_apply_report_$STAMP.txt"
TSV="$RAW_DIR/shell_artifact_helpers_repair_apply_$STAMP.tsv"

APPLY_MODE="${1:-}"

ALIAS_DIR="$HOME/.bash_aliases.d"
DEV_FILE="$ALIAS_DIR/50-dev.sh"
JOBS_FILE="$ALIAS_DIR/95-jobs.sh"

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
    fail "This script modifies shell files. Re-run with: apply-shell-artifact-helpers-repair.sh --apply"
  fi

  printf '%s\n' "This script will repair helper blocks in:"
  printf '%s\n' "- $JOBS_FILE"
  printf '%s\n' "- $DEV_FILE"
  printf '%s\n' "Backups will be written under: $SNAPSHOT_DIR"
  printf '%s' "Type APPLY to continue: "
  read -r confirmation

  if [ "$confirmation" != "APPLY" ]; then
    fail "Repair apply aborted by user."
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

  if [ ! -f "$file" ]; then
    write_step "BACKUP" "backup" "$file" "FAIL" "file not found" ""
    return 1
  fi

  safe_name="$(safe_name_for_path "$file")"
  backup_path="$SNAPSHOT_DIR/${safe_name}_repair_backup_$STAMP"

  cp -a "$file" "$backup_path"

  write_step "BACKUP" "backup" "$file" "OK" "created backup" "$backup_path"
}

marker_count() {
  local file="$1"
  local marker="$2"

  grep -c "^# >>> $marker$" "$file" 2>/dev/null || true
}

ensure_marker_once() {
  local file="$1"
  local marker="$2"
  local count

  count="$(marker_count "$file" "$marker")"

  if [ "$count" -eq 1 ]; then
    return 0
  fi

  write_step "CHECK" "preflight" "$file" "FAIL" "marker count is not 1" "$marker count=$count"
  return 1
}

replace_marked_block() {
  local step_id="$1"
  local file="$2"
  local marker="$3"
  local block_file="$4"
  local tmp_file

  append_section "$step_id - $file"

  if ! ensure_marker_once "$file" "$marker"; then
    return 1
  fi

  backup_file "$file"

  tmp_file="$(mktemp)"

  awk -v marker="$marker" -v block_file="$block_file" '
    BEGIN {
      start = "# >>> " marker
      end = "# <<< " marker
      in_block = 0
    }

    $0 == start {
      while ((getline line < block_file) > 0) {
        print line
      }
      close(block_file)
      in_block = 1
      next
    }

    $0 == end {
      in_block = 0
      next
    }

    in_block == 0 {
      print
    }
  ' "$file" > "$tmp_file"

  cat "$tmp_file" > "$file"
  rm -f "$tmp_file"

  write_step "$step_id" "repair-apply" "$file" "OK" "replaced marked block" "$marker"

  {
    printf '%s\n' "Replaced block: $marker"
    printf '\n'
    printf '%s\n' '```bash'
    cat "$block_file"
    printf '%s\n' '```'
  } >> "$REPORT"
}

create_jobs_block() {
  local block_file="$1"

  cat > "$block_file" <<'EOF'
# >>> toolbox-live-log-helpers
# Toolbox live-log helpers.
#
# These helpers complement existing nf/tf aliases by creating the log directory
# before redirection.
#
# Use command mkdir/tail to avoid alias expansion inside function bodies.

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

    command mkdir -p "$(dirname "$logfile")" || return 1

    nohup "$@" > "$logfile" 2>&1 &
    echo "PID: $!"
    echo "LOG: $logfile"
    command tail -f "$logfile"
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

    command mkdir -p "$(dirname "$logfile")" || return 1

    nohup "$command_name" "$@" > "$logfile" 2>&1 &
    echo "PID: $!"
    echo "LOG: $logfile"
    command tail -f "$logfile"
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
#
# eval is used only to preserve alias/function semantics for mkx and bashcheck
# without letting aliases expand while this function is being sourced.

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
    if alias mkx >/dev/null 2>&1; then
        eval "mkx \"\$script\"" || return 1
    else
        local mkx_cmd="mkx"
        "$mkx_cmd" "$script" || return 1
    fi

    echo "+ bashcheck $script"
    if alias bashcheck >/dev/null 2>&1; then
        eval "bashcheck \"\$script\""
    else
        local bashcheck_cmd="bashcheck"
        "$bashcheck_cmd" "$script"
    fi
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

validate_no_bad_expansion_in_source() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  if grep -q "$pattern" "$file"; then
    write_step "VALIDATE" "validate" "$file" "FAIL" "$label still present" "$pattern"
    return 1
  fi

  write_step "VALIDATE" "validate" "$file" "OK" "$label absent" "$pattern"
}

main() {
  local jobs_block
  local dev_block
  local fail_count
  local warn_count

  require_lib_contract
  confirm_apply

  mkdir -p "$REPORT_DIR" "$RAW_DIR" "$SNAPSHOT_DIR"

  log "Starting shell artifact helpers repair apply."

  tsv_row \
    "step_id" \
    "phase" \
    "target" \
    "status" \
    "action" \
    "notes" > "$TSV"

  {
    printf '%s\n' '# Shell Artifact Helpers Repair Apply'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf 'Snapshot dir: %s\n' "$SNAPSHOT_DIR"
    printf '\n'
    printf '%s\n' 'Safety: REPAIR APPLY script. This modifies previously applied shell helper blocks after --apply and textual APPLY confirmation.'
    printf '%s\n' 'Scope: repair alias expansion artifacts in nflog/tblive and mkxcheck.'
    printf '\n'
  } > "$REPORT"

  jobs_block="$(mktemp)"
  dev_block="$(mktemp)"

  create_jobs_block "$jobs_block"
  create_dev_block "$dev_block"

  replace_marked_block "REPAIR-001" "$JOBS_FILE" "$JOBS_MARKER" "$jobs_block"
  replace_marked_block "REPAIR-002" "$DEV_FILE" "$DEV_MARKER" "$dev_block"

  validate_shell_file "$JOBS_FILE"
  validate_shell_file "$DEV_FILE"
  validate_shell_file "$HOME/.bash_aliases"

  validate_no_bad_expansion_in_source "$JOBS_FILE" "mkdir -pv -p" "mkdir alias expansion artifact"
  write_step "VALIDATE" "validate" "" "OK" "mkxcheck repaired; broad chmod check skipped" "existing mkx alias may legitimately contain chmod +x"

  rm -f "$jobs_block" "$dev_block"

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$TSV")"
  warn_count="$(awk -F '\t' 'NR > 1 && $4 == "WARN" { c++ } END { print c+0 }' "$TSV")"

  {
    printf '\n'
    printf '%s\n' '## Summary'
    printf '\n'
    printf 'Failures: %s\n' "$fail_count"
    printf 'Warnings: %s\n' "$warn_count"
    printf '\n'
    printf '%s\n' 'Next phase: run validate-shell-artifact-helpers.sh.'
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    log "Shell artifact helpers repair apply completed with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  log "Shell artifact helpers repair apply completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
