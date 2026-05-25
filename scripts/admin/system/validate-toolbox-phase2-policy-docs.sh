#!/usr/bin/env bash
set -u

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

STAMP="$(date +%Y%m%d-%H%M%S)"

TOOLBOX_APP="/srv/toolbox/app"
DOCS_OPS="${TOOLBOX_APP}/docs/operations"

REPORT_DIR="/srv/toolbox/shared/reports/media"
RAW_DIR="/srv/toolbox/shared/library-db/raw"

REPORT_FILE="${REPORT_DIR}/toolbox_phase2_policy_docs_validation_report_${STAMP}.txt"
TSV_FILE="${RAW_DIR}/toolbox_phase2_policy_docs_validation_${STAMP}.tsv"

SCRIPT_CONVENTIONS="${DOCS_OPS}/toolbox_script_conventions.md"
REPORTS_POLICY="${DOCS_OPS}/toolbox_reports_policy.md"
LOGGING_POLICY="${DOCS_OPS}/toolbox_logging_policy.md"

require_dir() {
  local dir="$1"
  local label="$2"

  if [ ! -d "$dir" ]; then
    fail "${label} does not exist: ${dir}"
  fi
}

require_writable_dir() {
  local dir="$1"
  local label="$2"

  require_dir "$dir" "$label"

  if [ ! -w "$dir" ]; then
    fail "${label} is not writable: ${dir}"
  fi
}

tsv_escape() {
  local raw="$1"

  raw="${raw//$'\t'/ }"
  raw="${raw//$'\n'/ }"
  raw="${raw//$'\r'/ }"

  printf '%s' "$raw"
}

tsv_row() {
  local category="$1"
  local document="$2"
  local check="$3"
  local status="$4"
  local details="$5"

  {
    tsv_escape "$category"
    printf '\t'
    tsv_escape "$document"
    printf '\t'
    tsv_escape "$check"
    printf '\t'
    tsv_escape "$status"
    printf '\t'
    tsv_escape "$details"
    printf '\n'
  } >> "$TSV_FILE"
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

write_headers() {
  {
    printf 'Toolbox Phase 2 policy documents validation report\n'
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Docs operations: %s\n' "$DOCS_OPS"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope:\n'
    printf '  validate updated Phase 2 policy documents only;\n'
    printf '  no edits;\n'
    printf '  no Docker changes;\n'
    printf '  no scripts/lib creation;\n'
    printf '  no MANPATH changes;\n'
    printf '  no Git commit.\n'
    printf '\n'
    printf 'Documents validated:\n'
    printf '  - %s\n' "$SCRIPT_CONVENTIONS"
    printf '  - %s\n' "$REPORTS_POLICY"
    printf '  - %s\n' "$LOGGING_POLICY"
    printf '\n'
    printf 'Output destinations remain provisional and inherited from recent scripts.\n'
  } > "$REPORT_FILE"

  {
    printf 'category\tdocument\tcheck\tstatus\tdetails\n'
  } > "$TSV_FILE"
}

validate_file() {
  local file="$1"
  local label="$2"

  section "File validation: ${label}"

  if [ -f "$file" ]; then
    local size
    local lines
    local sha

    size="$(stat -c '%s' "$file" 2>/dev/null || printf 'UNKNOWN')"
    lines="$(wc -l < "$file" 2>/dev/null | tr -d ' ' || printf 'UNKNOWN')"
    sha="$(sha256sum "$file" 2>/dev/null | awk '{print $1}' || printf 'UNKNOWN')"

    {
      printf 'OK: file exists\n'
      printf 'Path: %s\n' "$file"
      printf 'Size bytes: %s\n' "$size"
      printf 'Lines: %s\n' "$lines"
      printf 'SHA256: %s\n' "$sha"
    } >> "$REPORT_FILE"

    tsv_row "file" "$label" "exists" "ok" "path=${file} size=${size} lines=${lines} sha256=${sha}"
  else
    printf 'MISSING: %s\n' "$file" >> "$REPORT_FILE"
    tsv_row "file" "$label" "exists" "missing" "$file"
  fi
}

validate_term() {
  local file="$1"
  local label="$2"
  local term="$3"

  if [ ! -f "$file" ]; then
    tsv_row "term" "$label" "$term" "skipped" "file missing"
    return 0
  fi

  if grep -Fq "$term" "$file" 2>/dev/null; then
    local hits
    hits="$(grep -Fn "$term" "$file" 2>/dev/null | wc -l | tr -d ' ')"

    {
      printf '\nOK: term found in %s\n' "$label"
      printf 'Term: %s\n' "$term"
      printf 'Hits: %s\n' "$hits"
      grep -Fn "$term" "$file" 2>/dev/null | sed -n '1,20p'
    } >> "$REPORT_FILE"

    tsv_row "term" "$label" "$term" "ok" "hits=${hits}"
  else
    {
      printf '\nMISSING: term not found in %s\n' "$label"
      printf 'Term: %s\n' "$term"
    } >> "$REPORT_FILE"

    tsv_row "term" "$label" "$term" "missing" "term not found"
  fi
}

write_header_preview() {
  local file="$1"
  local label="$2"

  section "Header preview: ${label}"

  if [ -f "$file" ]; then
    sed -n '1,45p' "$file" >> "$REPORT_FILE" 2>&1
    tsv_row "preview" "$label" "sed 1-45" "ok" "header preview written to report"
  else
    printf 'SKIPPED: file missing: %s\n' "$file" >> "$REPORT_FILE"
    tsv_row "preview" "$label" "sed 1-45" "skipped" "file missing"
  fi
}

validate_script_conventions() {
  local label="toolbox_script_conventions.md"

  validate_file "$SCRIPT_CONVENTIONS" "$label"

  section "Term validation: ${label}"

  validate_term "$SCRIPT_CONVENTIONS" "$label" "host-mode"
  validate_term "$SCRIPT_CONVENTIONS" "$label" "container-mode"
  validate_term "$SCRIPT_CONVENTIONS" "$label" "scripts/lib"
  validate_term "$SCRIPT_CONVENTIONS" "$label" "diagnose → plan → apply → validate"
  validate_term "$SCRIPT_CONVENTIONS" "$label" "run-job"
  validate_term "$SCRIPT_CONVENTIONS" "$label" "APPLY"
  validate_term "$SCRIPT_CONVENTIONS" "$label" "reports/media"
  validate_term "$SCRIPT_CONVENTIONS" "$label" "library-db/raw"

  write_header_preview "$SCRIPT_CONVENTIONS" "$label"
}

validate_reports_policy() {
  local label="toolbox_reports_policy.md"

  validate_file "$REPORTS_POLICY" "$label"

  section "Term validation: ${label}"

  validate_term "$REPORTS_POLICY" "$label" "reports/media"
  validate_term "$REPORTS_POLICY" "$label" "library-db/raw"
  validate_term "$REPORTS_POLICY" "$label" "não é destino universal"
  validate_term "$REPORTS_POLICY" "$label" "diagnose → plan → apply → validate"
  validate_term "$REPORTS_POLICY" "$label" "logs live"
  validate_term "$REPORTS_POLICY" "$label" "snapshots"
  validate_term "$REPORTS_POLICY" "$label" "Outputs legados"
  validate_term "$REPORTS_POLICY" "$label" "scripts/lib"

  write_header_preview "$REPORTS_POLICY" "$label"
}

validate_logging_policy() {
  local label="toolbox_logging_policy.md"

  validate_file "$LOGGING_POLICY" "$label"

  section "Term validation: ${label}"

  validate_term "$LOGGING_POLICY" "$label" "nf"
  validate_term "$LOGGING_POLICY" "$label" "nohup"
  validate_term "$LOGGING_POLICY" "$label" "tail -f"
  validate_term "$LOGGING_POLICY" "$label" "tee"
  validate_term "$LOGGING_POLICY" "$label" "scripts/lib/logging.sh"
  validate_term "$LOGGING_POLICY" "$label" "APPLY"
  validate_term "$LOGGING_POLICY" "$label" "reports/media"
  validate_term "$LOGGING_POLICY" "$label" "run-job"

  write_header_preview "$LOGGING_POLICY" "$label"
}

write_git_status() {
  section "Git status for validated policy documents"

  if git -C "$TOOLBOX_APP" rev-parse --show-toplevel >/dev/null 2>&1; then
    {
      cd "$TOOLBOX_APP" || exit 0
      git status --short \
        docs/operations/toolbox_script_conventions.md \
        docs/operations/toolbox_reports_policy.md \
        docs/operations/toolbox_logging_policy.md
    } >> "$REPORT_FILE" 2>&1

    tsv_row "git" "policy-docs" "git status --short" "recorded" "see report"
  else
    printf 'Git repository not detected at %s\n' "$TOOLBOX_APP" >> "$REPORT_FILE"
    tsv_row "git" "$TOOLBOX_APP" "git status" "missing" "not a git repository"
  fi
}

write_summary() {
  local missing_count

  section "Summary"

  missing_count="$(awk -F '\t' 'NR > 1 && $4 == "missing" {count++} END {print count+0}' "$TSV_FILE")"

  {
    printf 'Validated documents:\n'
    printf '  - %s\n' "$SCRIPT_CONVENTIONS"
    printf '  - %s\n' "$REPORTS_POLICY"
    printf '  - %s\n' "$LOGGING_POLICY"
    printf '\n'
    printf 'Missing checks: %s\n' "$missing_count"
    printf '\n'
    printf 'Generated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  TSV: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'No files were modified.\n'
  } >> "$REPORT_FILE"

  if [ "$missing_count" -eq 0 ]; then
    tsv_row "summary" "policy-docs" "missing checks" "ok" "missing_count=0"
  else
    tsv_row "summary" "policy-docs" "missing checks" "warning" "missing_count=${missing_count}"
  fi
}

main() {
  require_writable_dir "$REPORT_DIR" "report dir"
  require_writable_dir "$RAW_DIR" "raw dir"
  require_dir "$DOCS_OPS" "docs operations dir"

  write_headers

  log "Validating Phase 2 updated policy documents."
  log "Report: $REPORT_FILE"
  log "TSV: $TSV_FILE"

  validate_script_conventions
  validate_reports_policy
  validate_logging_policy
  write_git_status
  write_summary

  log "Validation completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report: %s\n' "$REPORT_FILE"
  printf '  TSV:          %s\n' "$TSV_FILE"
}

main "$@"
