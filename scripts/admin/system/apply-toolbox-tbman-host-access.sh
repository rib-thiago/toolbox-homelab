#!/usr/bin/env bash
set -u

# Apply Toolbox host access to manpages through tbman.
#
# This script modifies shell configuration files and therefore requires
# explicit APPLY confirmation.
#
# It creates/updates:
#   ~/.bash_aliases.d/toolbox-man.sh
#
# It also updates:
#   ~/.bash_aliases
#
# The goal is to ensure ~/.bash_aliases loads ~/.bash_aliases.d/*.sh
# without editing ~/.bashrc directly.

bootstrap_fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

TOOLBOX_APP="/srv/toolbox/app"
LIB_DIR="${TOOLBOX_APP}/scripts/lib"

LOGGING_LIB="${LIB_DIR}/logging.sh"
TIMESTAMPS_LIB="${LIB_DIR}/timestamps.sh"
TSV_LIB="${LIB_DIR}/tsv.sh"
PATHS_LIB="${LIB_DIR}/paths.sh"
REPORTS_LIB="${LIB_DIR}/reports.sh"

[ -f "$LOGGING_LIB" ] || bootstrap_fail "Missing lib file: $LOGGING_LIB"
[ -f "$TIMESTAMPS_LIB" ] || bootstrap_fail "Missing lib file: $TIMESTAMPS_LIB"
[ -f "$TSV_LIB" ] || bootstrap_fail "Missing lib file: $TSV_LIB"
[ -f "$PATHS_LIB" ] || bootstrap_fail "Missing lib file: $PATHS_LIB"
[ -f "$REPORTS_LIB" ] || bootstrap_fail "Missing lib file: $REPORTS_LIB"

source "$LOGGING_LIB"
source "$TIMESTAMPS_LIB"
source "$TSV_LIB"
source "$PATHS_LIB"
source "$REPORTS_LIB"

STAMP="$(toolbox_timestamp)"

REPORT_FILE="$(toolbox_report_path "toolbox_tbman_host_access" "apply" "$STAMP")"
TSV_FILE="$(toolbox_tsv_path "toolbox_tbman_host_access" "apply" "$STAMP")"
SNAPSHOT_FILE="$(toolbox_snapshot_path "toolbox_tbman_host_access" "pre_apply" "$STAMP")"

HOME_DIR="${HOME}"
BASH_ALIASES="${HOME_DIR}/.bash_aliases"
BASH_ALIASES_D="${HOME_DIR}/.bash_aliases.d"
TBMAN_FILE="${BASH_ALIASES_D}/toolbox-man.sh"

TOOLBOX_DOCS_DIR="${TOOLBOX_APP}/docs"

mkdir -p "$(dirname "$REPORT_FILE")"
mkdir -p "$(dirname "$TSV_FILE")"
mkdir -p "$(dirname "$SNAPSHOT_FILE")"

section() {
  local title="$1"

  {
    printf '\n'
    printf '%s\n' '================================================================'
    printf '%s\n' "$title"
    printf '%s\n' '================================================================'
  } >> "$REPORT_FILE"
}

write_headers() {
  {
    printf 'Toolbox tbman host access apply report\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Toolbox docs dir: %s\n' "$TOOLBOX_DOCS_DIR"
    printf 'Bash aliases file: %s\n' "$BASH_ALIASES"
    printf 'Bash aliases dir: %s\n' "$BASH_ALIASES_D"
    printf 'tbman file: %s\n' "$TBMAN_FILE"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf 'Snapshot file: %s\n' "$SNAPSHOT_FILE"
    printf '\n'
    printf 'Scope:\n'
    printf '  create or update tbman shell helper;\n'
    printf '  update ~/.bash_aliases to load ~/.bash_aliases.d/*.sh if needed;\n'
    printf '  do not edit ~/.bashrc directly;\n'
    printf '  do not alter global MANPATH;\n'
    printf '  do not move manpages;\n'
    printf '  do not convert Markdown to manpages;\n'
    printf '  do not change Docker;\n'
    printf '  do not commit Git changes.\n'
    printf '\n'
    printf 'This is an APPLY script and requires explicit confirmation.\n'
    printf 'Output destinations remain provisional and inherited from recent scripts.\n'
  } > "$REPORT_FILE"

  tsv_row "category" "item" "action" "status" "details" > "$TSV_FILE"
  tsv_row "path" "exists_before" "size_bytes_before" "sha256_before" "notes" > "$SNAPSHOT_FILE"
}

record() {
  local category="$1"
  local item="$2"
  local action="$3"
  local status="$4"
  local details="$5"

  printf '[%s] %s — %s — %s\n' "$status" "$category" "$item" "$action" >> "$REPORT_FILE"
  if [ -n "$details" ]; then
    printf '    %s\n' "$details" >> "$REPORT_FILE"
  fi

  tsv_row "$category" "$item" "$action" "$status" "$details" >> "$TSV_FILE"
}

snapshot_path() {
  local path="$1"
  local notes="$2"

  if [ -e "$path" ]; then
    local size
    local sha

    if [ -f "$path" ]; then
      size="$(stat -c '%s' "$path" 2>/dev/null || printf 'UNKNOWN')"
      sha="$(sha256sum "$path" 2>/dev/null | awk '{print $1}' || printf 'UNKNOWN')"
    else
      size="-"
      sha="-"
    fi

    tsv_row "$path" "yes" "$size" "$sha" "$notes" >> "$SNAPSHOT_FILE"
  else
    tsv_row "$path" "no" "-" "-" "$notes" >> "$SNAPSHOT_FILE"
  fi
}

backup_file_if_exists() {
  local file="$1"

  if [ -f "$file" ]; then
    local backup
    backup="${file}.backup-${STAMP}"
    cp -a "$file" "$backup"
    record "backup" "$file" "backup existing file" "ok" "$backup"
  else
    record "backup" "$file" "backup existing file" "skipped" "file does not exist"
  fi
}

require_apply_confirmation() {
  local confirmation="${1-}"

  if [ "$confirmation" != "APPLY" ]; then
    {
      printf '\n'
      printf 'Refusing to apply changes.\n'
      printf 'This script modifies shell configuration.\n'
      printf 'Run with:\n'
      printf '  %s APPLY\n' "$0"
    } >> "$REPORT_FILE"

    printf 'Refusing to apply changes. Run with: %s APPLY\n' "$0" >&2
    exit 2
  fi
}

check_prerequisites() {
  section "Prerequisites"

  if [ -d "$TOOLBOX_DOCS_DIR" ]; then
    record "prerequisite" "$TOOLBOX_DOCS_DIR" "docs dir exists" "ok" "Toolbox docs directory found"
  else
    record "prerequisite" "$TOOLBOX_DOCS_DIR" "docs dir exists" "fail" "Toolbox docs directory missing"
    fail "Toolbox docs directory missing: $TOOLBOX_DOCS_DIR"
  fi

  if [ -d "${TOOLBOX_DOCS_DIR}/man1" ]; then
    record "prerequisite" "${TOOLBOX_DOCS_DIR}/man1" "man1 dir exists" "ok" "man1 directory found"
  else
    record "prerequisite" "${TOOLBOX_DOCS_DIR}/man1" "man1 dir exists" "fail" "man1 directory missing"
    fail "Toolbox man1 directory missing: ${TOOLBOX_DOCS_DIR}/man1"
  fi

  if [ -d "${TOOLBOX_DOCS_DIR}/man7" ]; then
    record "prerequisite" "${TOOLBOX_DOCS_DIR}/man7" "man7 dir exists" "ok" "man7 directory found"
  else
    record "prerequisite" "${TOOLBOX_DOCS_DIR}/man7" "man7 dir exists" "fail" "man7 directory missing"
    fail "Toolbox man7 directory missing: ${TOOLBOX_DOCS_DIR}/man7"
  fi

  if command -v man >/dev/null 2>&1; then
    record "prerequisite" "man" "command available" "ok" "$(command -v man)"
  else
    record "prerequisite" "man" "command available" "fail" "man command missing"
    fail "man command missing"
  fi
}

write_tbman_file() {
  section "Write tbman helper"

  mkdir -p "$BASH_ALIASES_D"
  record "apply" "$BASH_ALIASES_D" "ensure directory" "ok" "mkdir -p"

  backup_file_if_exists "$TBMAN_FILE"

  cat > "$TBMAN_FILE" <<'EOF_TBMAN'
# Toolbox manpage helper.
#
# Provides tbman for consulting Toolbox manpages from the host without
# changing the global MANPATH.
#
# Usage:
#   tbman 1 run-job
#   tbman 7 toolbox
#   tbman run-job

tbman() {
  local toolbox_manpath
  toolbox_manpath="/srv/toolbox/app/docs"

  if [ "$#" -eq 0 ]; then
    printf 'Usage: tbman [section] <page>\n' >&2
    printf 'Examples:\n' >&2
    printf '  tbman 1 run-job\n' >&2
    printf '  tbman 7 toolbox\n' >&2
    printf '  tbman run-job\n' >&2
    return 2
  fi

  MANPAGER="${MANPAGER:-less}" man -M "$toolbox_manpath" "$@"
}
EOF_TBMAN

  chmod 664 "$TBMAN_FILE"

  record "apply" "$TBMAN_FILE" "write tbman helper" "ok" "tbman function written"
}

bash_aliases_has_loader() {
  if [ ! -f "$BASH_ALIASES" ]; then
    return 1
  fi

  grep -Fq ".bash_aliases.d" "$BASH_ALIASES"
}

write_or_update_bash_aliases_loader() {
  section "Update ~/.bash_aliases loader"

  if [ ! -f "$BASH_ALIASES" ]; then
    printf '# ~/.bash_aliases\n' > "$BASH_ALIASES"
    record "apply" "$BASH_ALIASES" "create file" "ok" "created ~/.bash_aliases"
  fi

  backup_file_if_exists "$BASH_ALIASES"

  if bash_aliases_has_loader; then
    record "apply" "$BASH_ALIASES" "ensure ~/.bash_aliases.d loader" "skipped" "loader already appears to exist"
    return 0
  fi

  {
    printf '\n'
    printf '# Load modular bash aliases/functions.\n'
    printf '# Added by Toolbox tbman host access apply script on %s.\n' "$(toolbox_now)"
    printf 'if [ -d "$HOME/.bash_aliases.d" ]; then\n'
    printf '  for file in "$HOME"/.bash_aliases.d/*.sh; do\n'
    printf '    [ -r "$file" ] && . "$file"\n'
    printf '  done\n'
    printf '  unset file\n'
    printf 'fi\n'
  } >> "$BASH_ALIASES"

  record "apply" "$BASH_ALIASES" "append ~/.bash_aliases.d loader" "ok" "loader appended"
}

validate_written_files() {
  section "Validate written files"

  if bash -n "$TBMAN_FILE" >/tmp/toolbox-tbman-bashcheck-stdout.$$ 2>/tmp/toolbox-tbman-bashcheck-stderr.$$; then
    record "validate" "$TBMAN_FILE" "bash -n" "ok" "syntax ok"
  else
    local err
    err="$(cat /tmp/toolbox-tbman-bashcheck-stderr.$$ 2>/dev/null || printf 'unknown error')"
    record "validate" "$TBMAN_FILE" "bash -n" "fail" "$err"
  fi

  rm -f /tmp/toolbox-tbman-bashcheck-stdout.$$ /tmp/toolbox-tbman-bashcheck-stderr.$$

  if bash -n "$BASH_ALIASES" >/tmp/toolbox-bash-aliases-stdout.$$ 2>/tmp/toolbox-bash-aliases-stderr.$$; then
    record "validate" "$BASH_ALIASES" "bash -n" "ok" "syntax ok"
  else
    local err
    err="$(cat /tmp/toolbox-bash-aliases-stderr.$$ 2>/dev/null || printf 'unknown error')"
    record "validate" "$BASH_ALIASES" "bash -n" "fail" "$err"
  fi

  rm -f /tmp/toolbox-bash-aliases-stdout.$$ /tmp/toolbox-bash-aliases-stderr.$$

  if bash -c "set -u; source '$BASH_ALIASES'; type tbman >/dev/null 2>&1"; then
    record "validate" "tbman" "source ~/.bash_aliases and type tbman" "ok" "tbman becomes available after sourcing ~/.bash_aliases"
  else
    record "validate" "tbman" "source ~/.bash_aliases and type tbman" "fail" "tbman was not available after sourcing ~/.bash_aliases"
  fi
}

validate_tbman_function() {
  section "Validate tbman behavior"

  if bash -c "set -u; source '$BASH_ALIASES'; MANPAGER=cat MANWIDTH=100 tbman 1 run-job >/tmp/toolbox-tbman-run-job.$$ 2>/tmp/toolbox-tbman-run-job-err.$$"; then
    local preview
    preview="$(sed -n '1,3p' /tmp/toolbox-tbman-run-job.$$ 2>/dev/null | tr '\n' ' ' || true)"
    record "validate" "tbman 1 run-job" "render" "ok" "$preview"
  else
    local err
    err="$(cat /tmp/toolbox-tbman-run-job-err.$$ 2>/dev/null || printf 'unknown error')"
    record "validate" "tbman 1 run-job" "render" "fail" "$err"
  fi

  rm -f /tmp/toolbox-tbman-run-job.$$ /tmp/toolbox-tbman-run-job-err.$$

  if bash -c "set -u; source '$BASH_ALIASES'; MANPAGER=cat MANWIDTH=100 tbman 7 toolbox >/tmp/toolbox-tbman-toolbox.$$ 2>/tmp/toolbox-tbman-toolbox-err.$$"; then
    local preview
    preview="$(sed -n '1,3p' /tmp/toolbox-tbman-toolbox.$$ 2>/dev/null | tr '\n' ' ' || true)"
    record "validate" "tbman 7 toolbox" "render" "ok" "$preview"
  else
    local err
    err="$(cat /tmp/toolbox-tbman-toolbox-err.$$ 2>/dev/null || printf 'unknown error')"
    record "validate" "tbman 7 toolbox" "render" "fail" "$err"
  fi

  rm -f /tmp/toolbox-tbman-toolbox.$$ /tmp/toolbox-tbman-toolbox-err.$$
}

write_git_status() {
  section "Git status"

  if git -C "$TOOLBOX_APP" rev-parse --show-toplevel >/dev/null 2>&1; then
    {
      cd "$TOOLBOX_APP" || exit 0
      git status --short scripts/admin/system/apply-toolbox-tbman-host-access.sh
    } >> "$REPORT_FILE" 2>&1

    record "git" "apply-toolbox-tbman-host-access.sh" "git status --short" "recorded" "see report"
  else
    record "git" "$TOOLBOX_APP" "git status" "missing" "not a git repository"
  fi

  {
    printf '\nShell files modified outside Git repo:\n'
    printf '  %s\n' "$BASH_ALIASES"
    printf '  %s\n' "$TBMAN_FILE"
  } >> "$REPORT_FILE"
}

write_summary() {
  local fail_count
  local missing_count

  section "Summary"

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "fail" {count++} END {print count+0}' "$TSV_FILE")"
  missing_count="$(awk -F '\t' 'NR > 1 && $4 == "missing" {count++} END {print count+0}' "$TSV_FILE")"

  {
    printf 'Failed checks: %s\n' "$fail_count"
    printf 'Missing checks: %s\n' "$missing_count"
    printf '\n'
    printf 'Generated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  TSV: %s\n' "$TSV_FILE"
    printf '  Snapshot: %s\n' "$SNAPSHOT_FILE"
    printf '\n'
    printf 'Files intentionally modified:\n'
    printf '  %s\n' "$BASH_ALIASES"
    printf '  %s\n' "$TBMAN_FILE"
    printf '\n'
    printf 'Reload options:\n'
    printf '  source ~/.bash_aliases\n'
    printf '  or open a new shell\n'
    printf '\n'
    printf 'Manual validation commands:\n'
    printf '  type tbman\n'
    printf '  tbman 1 run-job\n'
    printf '  tbman 7 toolbox\n'
  } >> "$REPORT_FILE"

  if [ "$fail_count" -eq 0 ]; then
    record "summary" "tbman apply" "failed checks" "ok" "fail_count=0"
  else
    record "summary" "tbman apply" "failed checks" "fail" "fail_count=${fail_count}"
  fi
}

main() {
  write_headers

  log "Preparing tbman host access apply."
  log "Report: $REPORT_FILE"
  log "TSV: $TSV_FILE"
  log "Snapshot: $SNAPSHOT_FILE"

  snapshot_path "$BASH_ALIASES" "before apply"
  snapshot_path "$BASH_ALIASES_D" "before apply"
  snapshot_path "$TBMAN_FILE" "before apply"

  check_prerequisites
  require_apply_confirmation "${1-}"

  log "APPLY confirmed. Modifying shell configuration."

  write_tbman_file
  write_or_update_bash_aliases_loader
  validate_written_files
  validate_tbman_function
  write_git_status
  write_summary

  log "tbman host access apply completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"
  log "Snapshot: $SNAPSHOT_FILE"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report: %s\n' "$REPORT_FILE"
  printf '  TSV:          %s\n' "$TSV_FILE"
  printf '  Snapshot:     %s\n' "$SNAPSHOT_FILE"
  printf '\n'
  printf 'Reload with:\n'
  printf '  source ~/.bash_aliases\n'
}

main "$@"
