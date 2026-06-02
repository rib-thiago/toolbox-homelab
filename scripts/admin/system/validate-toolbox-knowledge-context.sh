#!/usr/bin/env bash
set -u

APP_DIR="${APP_DIR:-/srv/toolbox/app}"
LIB_DIR="$APP_DIR/scripts/lib"

source "$LIB_DIR/logging.sh"
source "$LIB_DIR/timestamps.sh"
source "$LIB_DIR/paths.sh"

STAMP="$(toolbox_timestamp)"
SHARED_DIR="$(toolbox_shared_dir)"

REPORT_DIR="$SHARED_DIR/reports/system"
RAW_DIR="$SHARED_DIR/library-db/raw/system"

REPORT="$REPORT_DIR/toolbox_knowledge_context_validation_$STAMP.txt"
TSV="$RAW_DIR/toolbox_knowledge_context_validation_$STAMP.tsv"

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

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
}

ensure_output_dirs() {
  mkdir -p "$REPORT_DIR" "$RAW_DIR"
}

tsv_escape() {
  local value="${1:-}"
  printf '%s' "$value" | tr '\t\r\n' '   '
}

write_tsv_header() {
  printf 'timestamp\tstatus\tcheck_id\tpath\tdetail\n' > "$TSV"
}

record() {
  local status="$1"
  local check_id="$2"
  local path="$3"
  local detail="$4"
  local now
  local safe_now
  local safe_status
  local safe_check_id
  local safe_path
  local safe_detail

  now="$(toolbox_now)"

  case "$status" in
    OK)
      OK_COUNT=$((OK_COUNT + 1))
      ;;
    WARN)
      WARN_COUNT=$((WARN_COUNT + 1))
      ;;
    FAIL)
      FAIL_COUNT=$((FAIL_COUNT + 1))
      ;;
    *)
      status="FAIL"
      FAIL_COUNT=$((FAIL_COUNT + 1))
      detail="Invalid validation status"
      ;;
  esac

  safe_now="$(tsv_escape "$now")"
  safe_status="$(tsv_escape "$status")"
  safe_check_id="$(tsv_escape "$check_id")"
  safe_path="$(tsv_escape "$path")"
  safe_detail="$(tsv_escape "$detail")"

  printf '%s\t%s\t%s\t%s\t%s\n' "$safe_now" "$safe_status" "$safe_check_id" "$safe_path" "$safe_detail" >> "$TSV"
  printf '[%s] %-5s %-48s %s\n' "$check_id" "$status" "$path" "$detail" >> "$REPORT"
}

write_report_header() {
  {
    printf '# Toolbox knowledge context validation\n\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'App dir: %s\n' "$APP_DIR"
    printf 'Shared dir: %s\n' "$SHARED_DIR"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n\n' "$TSV"
    printf '## Checks\n\n'
  } > "$REPORT"
}

write_report_summary() {
  {
    printf '\n## Summary\n\n'
    printf 'OK: %s\n' "$OK_COUNT"
    printf 'WARN: %s\n' "$WARN_COUNT"
    printf 'FAIL: %s\n' "$FAIL_COUNT"
    printf '\n'
  } >> "$REPORT"
}

check_dir_exists() {
  local check_id="$1"
  local path="$2"

  if [ -d "$APP_DIR/$path" ]; then
    record "OK" "$check_id" "$path" "directory exists"
  else
    record "FAIL" "$check_id" "$path" "required directory is missing"
  fi
}

check_file_exists() {
  local check_id="$1"
  local path="$2"

  if [ -f "$APP_DIR/$path" ]; then
    record "OK" "$check_id" "$path" "file exists"
  else
    record "FAIL" "$check_id" "$path" "required file is missing"
  fi
}

check_markdown_fences() {
  local path="$1"
  local full_path="$APP_DIR/$path"
  local count

  if [ ! -f "$full_path" ]; then
    record "FAIL" "markdown_fence" "$path" "cannot check missing file"
    return 0
  fi

  count="$(python3 - "$full_path" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text()
print(text.count("```"))
PY
)"

  if [ $((count % 2)) -eq 0 ]; then
    record "OK" "markdown_fence" "$path" "balanced markdown code fences: $count"
  else
    record "FAIL" "markdown_fence" "$path" "unbalanced markdown code fences: $count"
  fi
}

check_reference() {
  local pattern="$1"
  local path="$2"
  local full_path="$APP_DIR/$path"

  if [ ! -f "$full_path" ]; then
    record "FAIL" "reference" "$path" "cannot check reference in missing file"
    return 0
  fi

  if grep -F "$pattern" "$full_path" >/dev/null 2>&1; then
    record "OK" "reference" "$path" "reference found: $pattern"
  else
    record "WARN" "reference" "$path" "reference not found: $pattern"
  fi
}

check_git_diff_check() {
  local output
  local status

  output="$(cd "$APP_DIR" && git diff --check 2>&1)"
  status=$?

  if [ "$status" -eq 0 ]; then
    record "OK" "git_diff_check" "$APP_DIR" "git diff --check passed"
  else
    record "FAIL" "git_diff_check" "$APP_DIR" "git diff --check failed"
    {
      printf '\n## git diff --check output\n\n'
      printf '%s\n' "$output"
    } >> "$REPORT"
  fi
}

check_git_status() {
  local status

  status="$(cd "$APP_DIR" && git status --short)"

  if [ -z "$status" ]; then
    record "OK" "git_status" "$APP_DIR" "working tree clean"
  else
    record "WARN" "git_status" "$APP_DIR" "working tree has pending changes"
    {
      printf '\n## Git status --short\n\n'
      printf '%s\n' "$status"
    } >> "$REPORT"
  fi
}

write_knowledge_file_listing() {
  {
    printf '\n## Knowledge files\n\n'
    cd "$APP_DIR" && find knowledge -maxdepth 3 -type f -print 2>/dev/null | sort
    printf '\n'
  } >> "$REPORT"
}

main() {
  require_lib_contract
  ensure_output_dirs
  write_tsv_header
  write_report_header

  log "Starting Toolbox knowledge context validation."

  check_dir_exists "dir" "knowledge"
  check_dir_exists "dir" "knowledge/context"
  check_dir_exists "dir" "knowledge/graph"
  check_dir_exists "dir" "knowledge/architecture"
  check_dir_exists "dir" "knowledge/services"
  check_dir_exists "dir" "knowledge/policies"
  check_dir_exists "dir" "knowledge/runbooks"

  check_file_exists "file" "knowledge/README.md"
  check_file_exists "context_file" "knowledge/context/agent-entrypoint.md"
  check_file_exists "context_file" "knowledge/context/homelab-context.md"
  check_file_exists "context_file" "knowledge/context/toolbox-context.md"
  check_file_exists "policy_file" "knowledge/policies/agent-safety-policy.md"
  check_file_exists "policy_file" "knowledge/policies/change-management-policy.md"
  check_file_exists "policy_file" "knowledge/policies/reporting-policy.md"

  check_markdown_fences "knowledge/README.md"
  check_markdown_fences "knowledge/context/agent-entrypoint.md"
  check_markdown_fences "knowledge/context/homelab-context.md"
  check_markdown_fences "knowledge/context/toolbox-context.md"
  check_markdown_fences "knowledge/policies/agent-safety-policy.md"
  check_markdown_fences "knowledge/policies/change-management-policy.md"
  check_markdown_fences "knowledge/policies/reporting-policy.md"

  check_reference "knowledge/context/agent-entrypoint.md" "knowledge/README.md"
  check_reference "knowledge/context/homelab-context.md" "knowledge/context/agent-entrypoint.md"
  check_reference "knowledge/context/toolbox-context.md" "knowledge/context/agent-entrypoint.md"
  check_reference "knowledge/context/agent-entrypoint.md" "knowledge/context/homelab-context.md"
  check_reference "knowledge/context/agent-entrypoint.md" "knowledge/context/toolbox-context.md"

  check_reference "knowledge/context/agent-entrypoint.md" "knowledge/policies/agent-safety-policy.md"
  check_reference "knowledge/context/homelab-context.md" "knowledge/policies/agent-safety-policy.md"
  check_reference "knowledge/context/toolbox-context.md" "knowledge/policies/agent-safety-policy.md"
  check_reference "docs/operations/toolbox_git_routine.md" "knowledge/policies/agent-safety-policy.md"
  check_reference "docs/operations/toolbox_script_conventions.md" "knowledge/policies/agent-safety-policy.md"
  check_reference "docs/operations/toolbox_logging_policy.md" "knowledge/policies/agent-safety-policy.md"
  check_reference "docs/operations/toolbox_reports_policy.md" "knowledge/policies/agent-safety-policy.md"
  check_reference "docs/operations/toolbox_storage_policy.md" "knowledge/policies/agent-safety-policy.md"
  check_reference "docs/media/stockhausen_metadata_policy.md" "knowledge/policies/agent-safety-policy.md"

  check_reference "knowledge/context/agent-entrypoint.md" "knowledge/policies/change-management-policy.md"
  check_reference "knowledge/context/homelab-context.md" "knowledge/policies/change-management-policy.md"
  check_reference "knowledge/context/toolbox-context.md" "knowledge/policies/change-management-policy.md"
  check_reference "knowledge/policies/agent-safety-policy.md" "knowledge/policies/change-management-policy.md"
  check_reference "docs/operations/toolbox_git_routine.md" "knowledge/policies/change-management-policy.md"
  check_reference "docs/operations/toolbox_script_conventions.md" "knowledge/policies/change-management-policy.md"
  check_reference "docs/operations/toolbox_reports_policy.md" "knowledge/policies/change-management-policy.md"
  check_reference "docs/operations/toolbox_storage_policy.md" "knowledge/policies/change-management-policy.md"

  check_reference "knowledge/context/agent-entrypoint.md" "knowledge/policies/reporting-policy.md"
  check_reference "knowledge/context/homelab-context.md" "knowledge/policies/reporting-policy.md"
  check_reference "knowledge/context/toolbox-context.md" "knowledge/policies/reporting-policy.md"
  check_reference "knowledge/policies/agent-safety-policy.md" "knowledge/policies/reporting-policy.md"
  check_reference "knowledge/policies/change-management-policy.md" "knowledge/policies/reporting-policy.md"
  check_reference "docs/operations/toolbox_reports_policy.md" "knowledge/policies/reporting-policy.md"
  check_reference "docs/operations/toolbox_logging_policy.md" "knowledge/policies/reporting-policy.md"
  check_reference "docs/operations/toolbox_output_destinations_policy.md" "knowledge/policies/reporting-policy.md"

  check_git_diff_check
  check_git_status
  write_knowledge_file_listing
  write_report_summary

  log "Toolbox knowledge context validation completed."
  log "Report: $REPORT"
  log "TSV: $TSV"

  if [ "$FAIL_COUNT" -gt 0 ]; then
    fail "Validation failed with $FAIL_COUNT failure(s)."
  fi

  return 0
}

main "$@"
