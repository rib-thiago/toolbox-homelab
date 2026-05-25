#!/usr/bin/env bash
set -u

# Diagnose Toolbox tbman post-apply state.
#
# This script does not modify anything.
# It validates that tbman remains available after the apply step and that
# normal system man behavior was not broken.
#
# It uses scripts/lib helpers.

bootstrap_fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

TOOLBOX_APP="/srv/toolbox/app"
LIB_DIR="${TOOLBOX_APP}/scripts/lib"

LOGGING_LIB="${LIB_DIR}/logging.sh"
TIMESTAMPS_LIB="${LIB_DIR}/timestamps.sh"
TSV_LIB="${LIB_DIR}/tsv.sh"
REPORTS_LIB="${LIB_DIR}/reports.sh"

[ -f "$LOGGING_LIB" ] || bootstrap_fail "Missing lib file: $LOGGING_LIB"
[ -f "$TIMESTAMPS_LIB" ] || bootstrap_fail "Missing lib file: $TIMESTAMPS_LIB"
[ -f "$TSV_LIB" ] || bootstrap_fail "Missing lib file: $TSV_LIB"
[ -f "$REPORTS_LIB" ] || bootstrap_fail "Missing lib file: $REPORTS_LIB"

source "$LOGGING_LIB"
source "$TIMESTAMPS_LIB"
source "$TSV_LIB"
source "$REPORTS_LIB"

STAMP="$(toolbox_timestamp)"

REPORT_FILE="$(toolbox_report_path "toolbox_tbman_post_apply" "diagnosis" "$STAMP")"
TSV_FILE="$(toolbox_tsv_path "toolbox_tbman_post_apply" "diagnosis" "$STAMP")"

HOME_DIR="${HOME}"
BASH_ALIASES="${HOME_DIR}/.bash_aliases"
BASH_ALIASES_D="${HOME_DIR}/.bash_aliases.d"
TBMAN_FILE="${BASH_ALIASES_D}/toolbox-man.sh"
TOOLBOX_DOCS_DIR="${TOOLBOX_APP}/docs"

mkdir -p "$(dirname "$REPORT_FILE")"
mkdir -p "$(dirname "$TSV_FILE")"

section() {
  local title="$1"

  {
    printf '\n'
    printf '%s\n' '================================================================'
    printf '%s\n' "$title"
    printf '%s\n' '================================================================'
  } >> "$REPORT_FILE"
}

record() {
  local category="$1"
  local item="$2"
  local check="$3"
  local status="$4"
  local details="$5"

  printf '[%s] %s — %s — %s\n' "$status" "$category" "$item" "$check" >> "$REPORT_FILE"
  if [ -n "$details" ]; then
    printf '    %s\n' "$details" >> "$REPORT_FILE"
  fi

  tsv_row "$category" "$item" "$check" "$status" "$details" >> "$TSV_FILE"
}

write_headers() {
  {
    printf 'Toolbox tbman post-apply diagnosis report\n'
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Toolbox docs dir: %s\n' "$TOOLBOX_DOCS_DIR"
    printf 'Bash aliases file: %s\n' "$BASH_ALIASES"
    printf 'Bash aliases dir: %s\n' "$BASH_ALIASES_D"
    printf 'tbman file: %s\n' "$TBMAN_FILE"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope:\n'
    printf '  diagnose tbman after apply;\n'
    printf '  validate tbman availability;\n'
    printf '  validate Toolbox manpage rendering;\n'
    printf '  validate regular system man still works;\n'
    printf '  inspect MANPATH without changing it;\n'
    printf '  no edits;\n'
    printf '  no shell configuration changes;\n'
    printf '  no MANPATH changes;\n'
    printf '  no Docker changes;\n'
    printf '  no Git commit.\n'
    printf '\n'
    printf 'Output destinations remain provisional and inherited from recent scripts.\n'
  } > "$REPORT_FILE"

  tsv_row "category" "item" "check" "status" "details" > "$TSV_FILE"
}

validate_file() {
  local file="$1"
  local label="$2"

  if [ -f "$file" ]; then
    local size
    local sha
    size="$(stat -c '%s' "$file" 2>/dev/null || printf 'UNKNOWN')"
    sha="$(sha256sum "$file" 2>/dev/null | awk '{print $1}' || printf 'UNKNOWN')"
    record "file" "$label" "exists" "ok" "path=${file} size=${size} sha256=${sha}"
  else
    record "file" "$label" "exists" "missing" "$file"
  fi
}

validate_bash_syntax() {
  local file="$1"
  local label="$2"

  if [ ! -f "$file" ]; then
    record "syntax" "$label" "bash -n" "skipped" "file missing"
    return 0
  fi

  if bash -n "$file" >/tmp/toolbox-tbman-post-bashcheck-stdout.$$ 2>/tmp/toolbox-tbman-post-bashcheck-stderr.$$; then
    record "syntax" "$label" "bash -n" "ok" "syntax ok"
  else
    local err
    err="$(cat /tmp/toolbox-tbman-post-bashcheck-stderr.$$ 2>/dev/null || printf 'unknown error')"
    record "syntax" "$label" "bash -n" "fail" "$err"
  fi

  rm -f /tmp/toolbox-tbman-post-bashcheck-stdout.$$ /tmp/toolbox-tbman-post-bashcheck-stderr.$$
}

diagnose_shell_files() {
  section "Shell files"

  validate_file "$BASH_ALIASES" "~/.bash_aliases"
  validate_file "$BASH_ALIASES_D" "~/.bash_aliases.d"
  validate_file "$TBMAN_FILE" "~/.bash_aliases.d/toolbox-man.sh"

  validate_bash_syntax "$BASH_ALIASES" "~/.bash_aliases"
  validate_bash_syntax "$TBMAN_FILE" "~/.bash_aliases.d/toolbox-man.sh"

  if [ -f "$BASH_ALIASES" ] && grep -Fq ".bash_aliases.d" "$BASH_ALIASES"; then
    record "loader" "~/.bash_aliases" "loads ~/.bash_aliases.d" "ok" "loader reference found"
  else
    record "loader" "~/.bash_aliases" "loads ~/.bash_aliases.d" "fail" "loader reference not found"
  fi
}

diagnose_shell_state() {
  section "Shell state"

  {
    printf 'Current MANPATH:\n'
    printf '%s\n' "${MANPATH-}"
    printf '\n'
    printf 'type man:\n'
    type man 2>&1 || true
    printf '\n'
    printf 'type tbman in current shell:\n'
    type tbman 2>&1 || true
  } >> "$REPORT_FILE"

  if [ -n "${MANPATH-}" ]; then
    record "shell" "MANPATH" "current value" "recorded" "$MANPATH"
  else
    record "shell" "MANPATH" "current value" "ok" "empty or unset; expected because global MANPATH was not changed"
  fi

  if type tbman >/dev/null 2>&1; then
    record "shell" "tbman" "current shell function" "ok" "$(type tbman 2>&1 | head -n 1)"
  else
    record "shell" "tbman" "current shell function" "warning" "tbman not loaded in current shell; source ~/.bash_aliases may be needed"
  fi
}

validate_tbman_loads_from_bash_aliases() {
  section "Validate tbman loading"

  if bash -c "set -u; source '$BASH_ALIASES'; type tbman >/dev/null 2>&1"; then
    record "tbman" "source ~/.bash_aliases" "type tbman" "ok" "tbman available after source"
  else
    record "tbman" "source ~/.bash_aliases" "type tbman" "fail" "tbman not available after source"
  fi

  local usage_output
  local usage_exit

  usage_output="$(bash -c "set -u; source '$BASH_ALIASES'; tbman" 2>&1 >/tmp/toolbox-tbman-post-usage-stdout.$$)"
  usage_exit="$?"

  if [ "$usage_exit" -eq 2 ] && printf '%s\n' "$usage_output" | grep -Fq "Usage: tbman"; then
    record "tbman" "tbman without args" "usage" "ok" "exit=${usage_exit} output=${usage_output}"
  else
    record "tbman" "tbman without args" "usage" "fail" "exit=${usage_exit} output=${usage_output}"
  fi

  rm -f /tmp/toolbox-tbman-post-usage-stdout.$$
}

validate_tbman_page() {
  local section_number="$1"
  local page="$2"
  local label="$3"

  if bash -c "set -u; source '$BASH_ALIASES'; MANPAGER=cat MANWIDTH=100 tbman '$section_number' '$page' >/tmp/toolbox-tbman-post-page.$$ 2>/tmp/toolbox-tbman-post-page-err.$$"; then
    local preview
    preview="$(sed -n '1,3p' /tmp/toolbox-tbman-post-page.$$ 2>/dev/null | tr '\n' ' ' || true)"
    record "tbman" "$label" "render" "ok" "$preview"
  else
    local err
    err="$(cat /tmp/toolbox-tbman-post-page-err.$$ 2>/dev/null || printf 'unknown error')"
    record "tbman" "$label" "render" "fail" "$err"
  fi

  rm -f /tmp/toolbox-tbman-post-page.$$ /tmp/toolbox-tbman-post-page-err.$$
}

validate_tbman_pages() {
  section "Validate tbman pages"

  validate_tbman_page "1" "run-job" "tbman 1 run-job"
  validate_tbman_page "7" "toolbox" "tbman 7 toolbox"
}

validate_system_man() {
  section "Validate regular system man"

  if command -v man >/dev/null 2>&1; then
    record "system-man" "man" "available" "ok" "$(command -v man)"
  else
    record "system-man" "man" "available" "fail" "man not found"
    return 0
  fi

  if MANPAGER=cat MANWIDTH=80 man man >/tmp/toolbox-system-man.$$ 2>/tmp/toolbox-system-man-err.$$; then
    local preview
    preview="$(sed -n '1,3p' /tmp/toolbox-system-man.$$ 2>/dev/null | tr '\n' ' ' || true)"
    record "system-man" "man man" "render" "ok" "$preview"
  else
    local err
    err="$(cat /tmp/toolbox-system-man-err.$$ 2>/dev/null || printf 'unknown error')"
    record "system-man" "man man" "render" "fail" "$err"
  fi

  rm -f /tmp/toolbox-system-man.$$ /tmp/toolbox-system-man-err.$$
}

write_git_status() {
  section "Git status"

  if git -C "$TOOLBOX_APP" rev-parse --show-toplevel >/dev/null 2>&1; then
    {
      cd "$TOOLBOX_APP" || exit 0
      git status --short scripts/admin/system/diagnose-toolbox-tbman-post-apply.sh
    } >> "$REPORT_FILE" 2>&1

    record "git" "diagnose-toolbox-tbman-post-apply.sh" "git status --short" "recorded" "see report"
  else
    record "git" "$TOOLBOX_APP" "git status" "missing" "not a git repository"
  fi
}

write_summary() {
  local fail_count
  local missing_count
  local warning_count

  section "Summary"

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "fail" {count++} END {print count+0}' "$TSV_FILE")"
  missing_count="$(awk -F '\t' 'NR > 1 && $4 == "missing" {count++} END {print count+0}' "$TSV_FILE")"
  warning_count="$(awk -F '\t' 'NR > 1 && $4 == "warning" {count++} END {print count+0}' "$TSV_FILE")"

  {
    printf 'Failed checks: %s\n' "$fail_count"
    printf 'Missing checks: %s\n' "$missing_count"
    printf 'Warning checks: %s\n' "$warning_count"
    printf '\n'
    printf 'Generated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  TSV: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'No files were modified except this diagnosis report and TSV.\n'
    printf '\n'
    printf 'Next recommended step if fail_count=0:\n'
    printf '  plan Git classification/commit strategy for accumulated docs and scripts.\n'
  } >> "$REPORT_FILE"

  if [ "$fail_count" -eq 0 ]; then
    record "summary" "tbman post-apply" "failed checks" "ok" "fail_count=0"
  else
    record "summary" "tbman post-apply" "failed checks" "fail" "fail_count=${fail_count}"
  fi
}

main() {
  write_headers

  log "Diagnosing tbman post-apply state."
  log "Report: $REPORT_FILE"
  log "TSV: $TSV_FILE"

  diagnose_shell_files
  diagnose_shell_state
  validate_tbman_loads_from_bash_aliases
  validate_tbman_pages
  validate_system_man
  write_git_status
  write_summary

  log "tbman post-apply diagnosis completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report: %s\n' "$REPORT_FILE"
  printf '  TSV:          %s\n' "$TSV_FILE"
}

main "$@"
