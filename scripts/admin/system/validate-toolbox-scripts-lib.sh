#!/usr/bin/env bash
set -u

# Validate Toolbox scripts/lib minimal implementation.
#
# This script intentionally uses scripts/lib helpers while validating scripts/lib.
# It should validate both:
#   1. that the library files exist and pass bashcheck;
#   2. that the library functions work well enough to generate this validation report.
#
# This script must not modify anything except its own validation report and TSV.

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

# Source the library under validation.
# These source operations must not print output or modify state.
source "$LOGGING_LIB"
source "$TIMESTAMPS_LIB"
source "$TSV_LIB"
source "$PATHS_LIB"
source "$REPORTS_LIB"

STAMP="$(toolbox_timestamp)"
REPORT_FILE="$(toolbox_report_path "toolbox_scripts_lib" "validation" "$STAMP")"
TSV_FILE="$(toolbox_tsv_path "toolbox_scripts_lib" "validation" "$STAMP")"

mkdir -p "$(dirname "$REPORT_FILE")"
mkdir -p "$(dirname "$TSV_FILE")"

write_headers() {
  {
    printf 'Toolbox scripts/lib validation report\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Lib dir: %s\n' "$LIB_DIR"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope:\n'
    printf '  validate minimal scripts/lib implementation;\n'
    printf '  use scripts/lib functions while validating scripts/lib;\n'
    printf '  no script migration;\n'
    printf '  no Docker changes;\n'
    printf '  no MANPATH changes;\n'
    printf '  no Git commit.\n'
    printf '\n'
    printf 'Output destinations remain provisional and inherited from recent scripts.\n'
  } > "$REPORT_FILE"

  tsv_row "category" "item" "check" "status" "details" > "$TSV_FILE"
}

section() {
  local title="$1"

  {
    printf '\n'
    printf '%s\n' '================================================================'
    printf '%s\n' "$title"
    printf '%s\n' '================================================================'
  } >> "$REPORT_FILE"
}

record_ok() {
  local category="$1"
  local item="$2"
  local check="$3"
  local details="$4"

  printf 'OK: [%s] %s — %s\n' "$category" "$item" "$check" >> "$REPORT_FILE"
  if [ -n "$details" ]; then
    printf '    %s\n' "$details" >> "$REPORT_FILE"
  fi

  tsv_row "$category" "$item" "$check" "ok" "$details" >> "$TSV_FILE"
}

record_missing() {
  local category="$1"
  local item="$2"
  local check="$3"
  local details="$4"

  printf 'MISSING: [%s] %s — %s\n' "$category" "$item" "$check" >> "$REPORT_FILE"
  if [ -n "$details" ]; then
    printf '    %s\n' "$details" >> "$REPORT_FILE"
  fi

  tsv_row "$category" "$item" "$check" "missing" "$details" >> "$TSV_FILE"
}

record_fail() {
  local category="$1"
  local item="$2"
  local check="$3"
  local details="$4"

  printf 'FAIL: [%s] %s — %s\n' "$category" "$item" "$check" >> "$REPORT_FILE"
  if [ -n "$details" ]; then
    printf '    %s\n' "$details" >> "$REPORT_FILE"
  fi

  tsv_row "$category" "$item" "$check" "fail" "$details" >> "$TSV_FILE"
}

validate_file_exists() {
  local file="$1"
  local label="$2"

  if [ -f "$file" ]; then
    local size
    local lines
    local sha

    size="$(stat -c '%s' "$file" 2>/dev/null || printf 'UNKNOWN')"
    lines="$(wc -l < "$file" 2>/dev/null | tr -d ' ' || printf 'UNKNOWN')"
    sha="$(sha256sum "$file" 2>/dev/null | awk '{print $1}' || printf 'UNKNOWN')"

    record_ok "file" "$label" "exists" "path=${file} size=${size} lines=${lines} sha256=${sha}"
  else
    record_missing "file" "$label" "exists" "$file"
  fi
}

validate_bashcheck() {
  local file="$1"
  local label="$2"

  if [ ! -f "$file" ]; then
    record_missing "bashcheck" "$label" "bashcheck" "file missing: $file"
    return 0
  fi

  if bash -n "$file" >/tmp/toolbox-bashcheck-stdout.$$ 2>/tmp/toolbox-bashcheck-stderr.$$; then
    record_ok "bashcheck" "$label" "bash -n" "syntax ok"
  else
    local err
    err="$(cat /tmp/toolbox-bashcheck-stderr.$$ 2>/dev/null || printf 'unknown error')"
    record_fail "bashcheck" "$label" "bash -n" "$err"
  fi

  rm -f /tmp/toolbox-bashcheck-stdout.$$ /tmp/toolbox-bashcheck-stderr.$$
}

validate_source_silent() {
  local file="$1"
  local label="$2"
  local output
  local exit_code

  if [ ! -f "$file" ]; then
    record_missing "source" "$label" "silent source" "file missing: $file"
    return 0
  fi

  output="$(bash -c "set -u; source '$file'" 2>&1)"
  exit_code="$?"

  if [ "$exit_code" -eq 0 ] && [ -z "$output" ]; then
    record_ok "source" "$label" "silent source" "source produced no output and exit=0"
  else
    record_fail "source" "$label" "silent source" "exit=${exit_code} output=${output}"
  fi
}

validate_logging_functions() {
  local output
  local fail_output
  local fail_exit

  section "Validate logging.sh functions"

  output="$(bash -c "set -u; source '$LOGGING_LIB'; log 'Teste de log da Toolbox'" 2>&1)"

  if printf '%s\n' "$output" | grep -Eq '^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\] Teste de log da Toolbox$'; then
    record_ok "function" "log()" "format" "$output"
  else
    record_fail "function" "log()" "format" "$output"
  fi

  fail_output="$(bash -c "set -u; source '$LOGGING_LIB'; fail 'Teste controlado de fail'" 2>&1)"
  fail_exit="$?"

  if [ "$fail_exit" -ne 0 ] && printf '%s\n' "$fail_output" | grep -Fq '[ERRO] Teste controlado de fail'; then
    record_ok "function" "fail()" "controlled failure" "exit=${fail_exit} output=${fail_output}"
  else
    record_fail "function" "fail()" "controlled failure" "exit=${fail_exit} output=${fail_output}"
  fi
}

validate_timestamp_functions() {
  local ts
  local now

  section "Validate timestamps.sh functions"

  ts="$(toolbox_timestamp)"
  now="$(toolbox_now)"

  if printf '%s\n' "$ts" | grep -Eq '^[0-9]{8}-[0-9]{6}$'; then
    record_ok "function" "toolbox_timestamp()" "format" "$ts"
  else
    record_fail "function" "toolbox_timestamp()" "format" "$ts"
  fi

  if printf '%s\n' "$now" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'; then
    record_ok "function" "toolbox_now()" "format" "$now"
  else
    record_fail "function" "toolbox_now()" "format" "$now"
  fi
}

validate_tsv_functions() {
  local escaped
  local row
  local empty_row

  section "Validate tsv.sh functions"

  escaped="$(tsv_escape $'a\tb\nc\rd')"

  if [ "$escaped" = "a b c d" ]; then
    record_ok "function" "tsv_escape()" "sanitize tabs/newlines/cr" "$escaped"
  else
    record_fail "function" "tsv_escape()" "sanitize tabs/newlines/cr" "$escaped"
  fi

  row="$(tsv_row "col1" "col2" "col3")"

  if [ "$row" = $'col1\tcol2\tcol3' ]; then
    record_ok "function" "tsv_row()" "basic row" "$row"
  else
    record_fail "function" "tsv_row()" "basic row" "$row"
  fi

  row="$(tsv_row "a b" $'c\td' $'e\nf')"

  if [ "$row" = $'a b\tc d\te f' ]; then
    record_ok "function" "tsv_row()" "sanitized row" "$row"
  else
    record_fail "function" "tsv_row()" "sanitized row" "$row"
  fi

  empty_row="$(tsv_row)"

  if [ -z "$empty_row" ]; then
    record_ok "function" "tsv_row()" "empty row" "empty output without error"
  else
    record_fail "function" "tsv_row()" "empty row" "$empty_row"
  fi
}

validate_path_functions() {
  section "Validate paths.sh functions"

  if [ "$(toolbox_app_dir)" = "/srv/toolbox/app" ]; then
    record_ok "function" "toolbox_app_dir()" "path" "$(toolbox_app_dir)"
  else
    record_fail "function" "toolbox_app_dir()" "path" "$(toolbox_app_dir)"
  fi

  if [ "$(toolbox_shared_dir)" = "/srv/toolbox/shared" ]; then
    record_ok "function" "toolbox_shared_dir()" "path" "$(toolbox_shared_dir)"
  else
    record_fail "function" "toolbox_shared_dir()" "path" "$(toolbox_shared_dir)"
  fi

  if [ "$(toolbox_reports_dir)" = "/srv/toolbox/shared/reports/media" ]; then
    record_ok "function" "toolbox_reports_dir()" "provisional path" "$(toolbox_reports_dir)"
  else
    record_fail "function" "toolbox_reports_dir()" "provisional path" "$(toolbox_reports_dir)"
  fi

  if [ "$(toolbox_raw_dir)" = "/srv/toolbox/shared/library-db/raw" ]; then
    record_ok "function" "toolbox_raw_dir()" "provisional path" "$(toolbox_raw_dir)"
  else
    record_fail "function" "toolbox_raw_dir()" "provisional path" "$(toolbox_raw_dir)"
  fi

  if [ "$(toolbox_snapshots_dir)" = "/srv/toolbox/shared/library-db/snapshots" ]; then
    record_ok "function" "toolbox_snapshots_dir()" "provisional path" "$(toolbox_snapshots_dir)"
  else
    record_fail "function" "toolbox_snapshots_dir()" "provisional path" "$(toolbox_snapshots_dir)"
  fi
}

validate_report_path_functions() {
  local stamp
  local report_path
  local tsv_path
  local live_log_path
  local snapshot_path

  section "Validate reports.sh functions"

  stamp="20260524-230000"

  report_path="$(toolbox_report_path "toolbox" "test" "$stamp")"
  tsv_path="$(toolbox_tsv_path "toolbox" "test" "$stamp")"
  live_log_path="$(toolbox_live_log_path "toolbox" "test" "$stamp")"
  snapshot_path="$(toolbox_snapshot_path "toolbox" "test" "$stamp")"

  if [ "$report_path" = "/srv/toolbox/shared/reports/media/toolbox_test_report_20260524-230000.txt" ]; then
    record_ok "function" "toolbox_report_path()" "path" "$report_path"
  else
    record_fail "function" "toolbox_report_path()" "path" "$report_path"
  fi

  if [ "$tsv_path" = "/srv/toolbox/shared/library-db/raw/toolbox_test_20260524-230000.tsv" ]; then
    record_ok "function" "toolbox_tsv_path()" "path" "$tsv_path"
  else
    record_fail "function" "toolbox_tsv_path()" "path" "$tsv_path"
  fi

  if [ "$live_log_path" = "/srv/toolbox/shared/reports/media/toolbox_test_live_20260524-230000.log" ]; then
    record_ok "function" "toolbox_live_log_path()" "path" "$live_log_path"
  else
    record_fail "function" "toolbox_live_log_path()" "path" "$live_log_path"
  fi

  if [ "$snapshot_path" = "/srv/toolbox/shared/library-db/snapshots/toolbox_test_snapshot_20260524-230000.tsv" ]; then
    record_ok "function" "toolbox_snapshot_path()" "path" "$snapshot_path"
  else
    record_fail "function" "toolbox_snapshot_path()" "path" "$snapshot_path"
  fi
}

write_git_status() {
  section "Git status for scripts/lib"

  if git -C "$TOOLBOX_APP" rev-parse --show-toplevel >/dev/null 2>&1; then
    {
      cd "$TOOLBOX_APP" || exit 0
      git status --short scripts/lib
      printf '\n'
      git status --short scripts/admin/system/validate-toolbox-scripts-lib.sh
    } >> "$REPORT_FILE" 2>&1

    tsv_row "git" "scripts/lib" "git status --short" "recorded" "see report" >> "$TSV_FILE"
  else
    printf 'Git repository not detected at %s\n' "$TOOLBOX_APP" >> "$REPORT_FILE"
    tsv_row "git" "$TOOLBOX_APP" "git status" "missing" "not a git repository" >> "$TSV_FILE"
  fi
}

write_summary() {
  local missing_count
  local fail_count

  section "Summary"

  missing_count="$(awk -F '\t' 'NR > 1 && $4 == "missing" {count++} END {print count+0}' "$TSV_FILE")"
  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "fail" {count++} END {print count+0}' "$TSV_FILE")"

  {
    printf 'Validated scripts/lib files:\n'
    printf '  - %s\n' "$LOGGING_LIB"
    printf '  - %s\n' "$TIMESTAMPS_LIB"
    printf '  - %s\n' "$TSV_LIB"
    printf '  - %s\n' "$PATHS_LIB"
    printf '  - %s\n' "$REPORTS_LIB"
    printf '\n'
    printf 'Missing checks: %s\n' "$missing_count"
    printf 'Failed checks: %s\n' "$fail_count"
    printf '\n'
    printf 'Generated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  TSV: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'No files were modified except this validation report and TSV.\n'
  } >> "$REPORT_FILE"

  if [ "$missing_count" -eq 0 ] && [ "$fail_count" -eq 0 ]; then
    tsv_row "summary" "scripts-lib" "validation" "ok" "missing_count=0 fail_count=0" >> "$TSV_FILE"
  else
    tsv_row "summary" "scripts-lib" "validation" "fail" "missing_count=${missing_count} fail_count=${fail_count}" >> "$TSV_FILE"
  fi
}

main() {
  write_headers

  log "Validating Toolbox scripts/lib minimal implementation."
  log "Report: $REPORT_FILE"
  log "TSV: $TSV_FILE"

  section "Validate library files"
  validate_file_exists "$LOGGING_LIB" "logging.sh"
  validate_file_exists "$TIMESTAMPS_LIB" "timestamps.sh"
  validate_file_exists "$TSV_LIB" "tsv.sh"
  validate_file_exists "$PATHS_LIB" "paths.sh"
  validate_file_exists "$REPORTS_LIB" "reports.sh"

  section "Validate bash syntax"
  validate_bashcheck "$LOGGING_LIB" "logging.sh"
  validate_bashcheck "$TIMESTAMPS_LIB" "timestamps.sh"
  validate_bashcheck "$TSV_LIB" "tsv.sh"
  validate_bashcheck "$PATHS_LIB" "paths.sh"
  validate_bashcheck "$REPORTS_LIB" "reports.sh"

  section "Validate silent source"
  validate_source_silent "$LOGGING_LIB" "logging.sh"
  validate_source_silent "$TIMESTAMPS_LIB" "timestamps.sh"
  validate_source_silent "$TSV_LIB" "tsv.sh"
  validate_source_silent "$PATHS_LIB" "paths.sh"
  validate_source_silent "$REPORTS_LIB" "reports.sh"

  validate_logging_functions
  validate_timestamp_functions
  validate_tsv_functions
  validate_path_functions
  validate_report_path_functions
  write_git_status
  write_summary

  log "scripts/lib validation completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report: %s\n' "$REPORT_FILE"
  printf '  TSV:          %s\n' "$TSV_FILE"
}

main "$@"
