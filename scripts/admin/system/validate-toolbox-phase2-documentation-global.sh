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

REPORT_FILE="${REPORT_DIR}/toolbox_phase2_documentation_global_validation_report_${STAMP}.txt"
TSV_FILE="${RAW_DIR}/toolbox_phase2_documentation_global_validation_${STAMP}.tsv"

DOC_ARCH="${DOCS_OPS}/toolbox_architecture_reconciliation.md"
DOC_LIB="${DOCS_OPS}/toolbox_scripts_lib_policy.md"
DOC_RUNTIME="${DOCS_OPS}/toolbox_runtime_profiles.md"
DOC_MAN="${DOCS_OPS}/toolbox_manpages_policy.md"
DOC_GIT="${DOCS_OPS}/toolbox_git_routine.md"
DOC_SCRIPT="${DOCS_OPS}/toolbox_script_conventions.md"
DOC_REPORTS="${DOCS_OPS}/toolbox_reports_policy.md"
DOC_LOGGING="${DOCS_OPS}/toolbox_logging_policy.md"

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
    printf 'Toolbox Phase 2 global documentation validation report\n'
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Docs operations: %s\n' "$DOCS_OPS"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope:\n'
    printf '  validate all Phase 2 documentation files;\n'
    printf '  no edits;\n'
    printf '  no Docker changes;\n'
    printf '  no scripts/lib creation;\n'
    printf '  no MANPATH changes;\n'
    printf '  no Git commit.\n'
    printf '\n'
    printf 'Validated documents:\n'
    printf '  - %s\n' "$DOC_ARCH"
    printf '  - %s\n' "$DOC_LIB"
    printf '  - %s\n' "$DOC_RUNTIME"
    printf '  - %s\n' "$DOC_MAN"
    printf '  - %s\n' "$DOC_GIT"
    printf '  - %s\n' "$DOC_SCRIPT"
    printf '  - %s\n' "$DOC_REPORTS"
    printf '  - %s\n' "$DOC_LOGGING"
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
      grep -Fn "$term" "$file" 2>/dev/null | sed -n '1,12p'
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

validate_cross_reference() {
  local source_file="$1"
  local source_label="$2"
  local referenced_name="$3"

  validate_term "$source_file" "$source_label" "$referenced_name"
}

write_header_preview() {
  local file="$1"
  local label="$2"

  section "Header preview: ${label}"

  if [ -f "$file" ]; then
    sed -n '1,35p' "$file" >> "$REPORT_FILE" 2>&1
    tsv_row "preview" "$label" "sed 1-35" "ok" "header preview written to report"
  else
    printf 'SKIPPED: file missing: %s\n' "$file" >> "$REPORT_FILE"
    tsv_row "preview" "$label" "sed 1-35" "skipped" "file missing"
  fi
}

validate_architecture_reconciliation() {
  local label="toolbox_architecture_reconciliation.md"

  validate_file "$DOC_ARCH" "$label"

  section "Term validation: ${label}"

  validate_term "$DOC_ARCH" "$label" "plataforma operacional híbrida"
  validate_term "$DOC_ARCH" "$label" "host-mode"
  validate_term "$DOC_ARCH" "$label" "container-mode"
  validate_term "$DOC_ARCH" "$label" "toolbox-media"
  validate_term "$DOC_ARCH" "$label" "scripts/lib"
  validate_term "$DOC_ARCH" "$label" "manpages"
  validate_term "$DOC_ARCH" "$label" "run-job"
  validate_term "$DOC_ARCH" "$label" "diagnose → plan → apply → validate"
  validate_term "$DOC_ARCH" "$label" "Navidrome"

  write_header_preview "$DOC_ARCH" "$label"
}

validate_scripts_lib_policy() {
  local label="toolbox_scripts_lib_policy.md"

  validate_file "$DOC_LIB" "$label"

  section "Term validation: ${label}"

  validate_term "$DOC_LIB" "$label" "scripts/lib"
  validate_term "$DOC_LIB" "$label" "logging.sh"
  validate_term "$DOC_LIB" "$label" "log()"
  validate_term "$DOC_LIB" "$label" "fail()"
  validate_term "$DOC_LIB" "$label" "timestamps.sh"
  validate_term "$DOC_LIB" "$label" "paths.sh"
  validate_term "$DOC_LIB" "$label" "tsv.sh"
  validate_term "$DOC_LIB" "$label" "reports.sh"
  validate_term "$DOC_LIB" "$label" "adoção gradual"

  write_header_preview "$DOC_LIB" "$label"
}

validate_runtime_profiles() {
  local label="toolbox_runtime_profiles.md"

  validate_file "$DOC_RUNTIME" "$label"

  section "Term validation: ${label}"

  validate_term "$DOC_RUNTIME" "$label" "host-mode"
  validate_term "$DOC_RUNTIME" "$label" "container-mode"
  validate_term "$DOC_RUNTIME" "$label" "toolbox-base"
  validate_term "$DOC_RUNTIME" "$label" "toolbox-docs"
  validate_term "$DOC_RUNTIME" "$label" "toolbox-media"
  validate_term "$DOC_RUNTIME" "$label" "toolbox-nlp"
  validate_term "$DOC_RUNTIME" "$label" "run-job"
  validate_term "$DOC_RUNTIME" "$label" "diagnose → plan → apply → validate"
  validate_term "$DOC_RUNTIME" "$label" "Navidrome"
  validate_term "$DOC_RUNTIME" "$label" "FileBrowser não é runtime"

  write_header_preview "$DOC_RUNTIME" "$label"
}

validate_manpages_policy() {
  local label="toolbox_manpages_policy.md"

  validate_file "$DOC_MAN" "$label"

  section "Term validation: ${label}"

  validate_term "$DOC_MAN" "$label" "Manpages e groff"
  validate_term "$DOC_MAN" "$label" "/srv/toolbox/app/docs"
  validate_term "$DOC_MAN" "$label" "/toolbox/app/docs"
  validate_term "$DOC_MAN" "$label" "docs/man1"
  validate_term "$DOC_MAN" "$label" "docs/man7"
  validate_term "$DOC_MAN" "$label" "host-mode"
  validate_term "$DOC_MAN" "$label" "container-mode"
  validate_term "$DOC_MAN" "$label" "tbman"
  validate_term "$DOC_MAN" "$label" "MANPATH"
  validate_term "$DOC_MAN" "$label" "diagnose → plan → apply → validate"

  write_header_preview "$DOC_MAN" "$label"
}

validate_git_routine() {
  local label="toolbox_git_routine.md"

  validate_file "$DOC_GIT" "$label"

  section "Term validation: ${label}"

  validate_term "$DOC_GIT" "$label" "git status --short"
  validate_term "$DOC_GIT" "$label" "git add ."
  validate_term "$DOC_GIT" "$label" "bashcheck"
  validate_term "$DOC_GIT" "$label" "APPLY"
  validate_term "$DOC_GIT" "$label" "scripts/lib"
  validate_term "$DOC_GIT" "$label" "toolbox-media"
  validate_term "$DOC_GIT" "$label" ".save"
  validate_term "$DOC_GIT" "$label" "diagnose → plan → apply → validate"

  write_header_preview "$DOC_GIT" "$label"
}

validate_script_conventions() {
  local label="toolbox_script_conventions.md"

  validate_file "$DOC_SCRIPT" "$label"

  section "Term validation: ${label}"

  validate_term "$DOC_SCRIPT" "$label" "host-mode"
  validate_term "$DOC_SCRIPT" "$label" "container-mode"
  validate_term "$DOC_SCRIPT" "$label" "scripts/lib"
  validate_term "$DOC_SCRIPT" "$label" "diagnose → plan → apply → validate"
  validate_term "$DOC_SCRIPT" "$label" "run-job"
  validate_term "$DOC_SCRIPT" "$label" "APPLY"
  validate_term "$DOC_SCRIPT" "$label" "reports/media"
  validate_term "$DOC_SCRIPT" "$label" "library-db/raw"
  validate_term "$DOC_SCRIPT" "$label" "toolbox-media"

  write_header_preview "$DOC_SCRIPT" "$label"
}

validate_reports_policy() {
  local label="toolbox_reports_policy.md"

  validate_file "$DOC_REPORTS" "$label"

  section "Term validation: ${label}"

  validate_term "$DOC_REPORTS" "$label" "reports/media"
  validate_term "$DOC_REPORTS" "$label" "library-db/raw"
  validate_term "$DOC_REPORTS" "$label" "não é destino universal"
  validate_term "$DOC_REPORTS" "$label" "diagnose → plan → apply → validate"
  validate_term "$DOC_REPORTS" "$label" "logs live"
  validate_term "$DOC_REPORTS" "$label" "snapshots"
  validate_term "$DOC_REPORTS" "$label" "Outputs legados"
  validate_term "$DOC_REPORTS" "$label" "scripts/lib"

  write_header_preview "$DOC_REPORTS" "$label"
}

validate_logging_policy() {
  local label="toolbox_logging_policy.md"

  validate_file "$DOC_LOGGING" "$label"

  section "Term validation: ${label}"

  validate_term "$DOC_LOGGING" "$label" "nf"
  validate_term "$DOC_LOGGING" "$label" "nohup"
  validate_term "$DOC_LOGGING" "$label" "tail -f"
  validate_term "$DOC_LOGGING" "$label" "tee"
  validate_term "$DOC_LOGGING" "$label" "scripts/lib/logging.sh"
  validate_term "$DOC_LOGGING" "$label" "APPLY"
  validate_term "$DOC_LOGGING" "$label" "reports/media"
  validate_term "$DOC_LOGGING" "$label" "run-job"

  write_header_preview "$DOC_LOGGING" "$label"
}

validate_cross_references() {
  section "Cross-reference validation"

  validate_cross_reference "$DOC_SCRIPT" "toolbox_script_conventions.md" "toolbox_architecture_reconciliation.md"
  validate_cross_reference "$DOC_SCRIPT" "toolbox_script_conventions.md" "toolbox_scripts_lib_policy.md"
  validate_cross_reference "$DOC_SCRIPT" "toolbox_script_conventions.md" "toolbox_runtime_profiles.md"
  validate_cross_reference "$DOC_SCRIPT" "toolbox_script_conventions.md" "toolbox_manpages_policy.md"
  validate_cross_reference "$DOC_SCRIPT" "toolbox_script_conventions.md" "toolbox_git_routine.md"
  validate_cross_reference "$DOC_SCRIPT" "toolbox_script_conventions.md" "toolbox_reports_policy.md"
  validate_cross_reference "$DOC_SCRIPT" "toolbox_script_conventions.md" "toolbox_logging_policy.md"

  validate_cross_reference "$DOC_REPORTS" "toolbox_reports_policy.md" "toolbox_script_conventions.md"
  validate_cross_reference "$DOC_REPORTS" "toolbox_reports_policy.md" "toolbox_logging_policy.md"
  validate_cross_reference "$DOC_REPORTS" "toolbox_reports_policy.md" "toolbox_runtime_profiles.md"
  validate_cross_reference "$DOC_REPORTS" "toolbox_reports_policy.md" "toolbox_git_routine.md"
  validate_cross_reference "$DOC_REPORTS" "toolbox_reports_policy.md" "toolbox_scripts_lib_policy.md"

  validate_cross_reference "$DOC_LOGGING" "toolbox_logging_policy.md" "toolbox_script_conventions.md"
  validate_cross_reference "$DOC_LOGGING" "toolbox_logging_policy.md" "toolbox_reports_policy.md"
  validate_cross_reference "$DOC_LOGGING" "toolbox_logging_policy.md" "toolbox_runtime_profiles.md"
  validate_cross_reference "$DOC_LOGGING" "toolbox_logging_policy.md" "toolbox_scripts_lib_policy.md"
  validate_cross_reference "$DOC_LOGGING" "toolbox_logging_policy.md" "toolbox_git_routine.md"
}

write_git_status() {
  section "Git status for Phase 2 documentation"

  if git -C "$TOOLBOX_APP" rev-parse --show-toplevel >/dev/null 2>&1; then
    {
      cd "$TOOLBOX_APP" || exit 0
      git status --short docs/operations
      printf '\n'
      git status --short scripts/admin/system
    } >> "$REPORT_FILE" 2>&1

    tsv_row "git" "docs/operations" "git status --short" "recorded" "see report"
    tsv_row "git" "scripts/admin/system" "git status --short" "recorded" "see report"
  else
    printf 'Git repository not detected at %s\n' "$TOOLBOX_APP" >> "$REPORT_FILE"
    tsv_row "git" "$TOOLBOX_APP" "git status" "missing" "not a git repository"
  fi
}

write_pending_tasks() {
  section "Pending tasks after Phase 2 documentation validation"

  {
    printf 'High priority pending tasks:\n'
    printf '  1. Review this global validation report.\n'
    printf '  2. If missing checks are zero, plan minimal scripts/lib creation.\n'
    printf '  3. Apply and validate minimal scripts/lib.\n'
    printf '  4. Plan host access to manpages, likely tbman first.\n'
    printf '  5. Plan toolbox-media profile.\n'
    printf '\n'
    printf 'Medium priority pending tasks:\n'
    printf '  1. Review toolbox_shell_environment.md.\n'
    printf '  2. Review toolbox_storage_policy.md.\n'
    printf '  3. Create generic validate-toolbox-doc-file.sh.\n'
    printf '  4. Update toolbox_pipeline_spec.md.\n'
    printf '  5. Update toolbox_directory_layout.md.\n'
    printf '  6. Update toolbox_environment_spec.md.\n'
    printf '\n'
    printf 'Low priority pending tasks:\n'
    printf '  1. Diagnose jobs.md.\n'
    printf '  2. Diagnose usage.md.\n'
    printf '  3. Diagnose docs/man/.\n'
    printf '  4. Preserve or mark toolbox_roadmap.md as historical.\n'
    printf '  5. Defer TUI/dashboard/search.\n'
  } >> "$REPORT_FILE"

  tsv_row "pending" "high-priority" "tasks" "recorded" "scripts/lib, manpages, toolbox-media"
  tsv_row "pending" "medium-priority" "tasks" "recorded" "shell/storage/generic-validator/historical-docs"
  tsv_row "pending" "low-priority" "tasks" "recorded" "jobs usage man roadmap TUI"
}

write_summary() {
  local missing_count
  local skipped_count
  local warning_count

  section "Summary"

  missing_count="$(awk -F '\t' 'NR > 1 && $4 == "missing" {count++} END {print count+0}' "$TSV_FILE")"
  skipped_count="$(awk -F '\t' 'NR > 1 && $4 == "skipped" {count++} END {print count+0}' "$TSV_FILE")"
  warning_count="$(awk -F '\t' 'NR > 1 && $4 == "warning" {count++} END {print count+0}' "$TSV_FILE")"

  {
    printf 'Validated Phase 2 documents:\n'
    printf '  - %s\n' "$DOC_ARCH"
    printf '  - %s\n' "$DOC_LIB"
    printf '  - %s\n' "$DOC_RUNTIME"
    printf '  - %s\n' "$DOC_MAN"
    printf '  - %s\n' "$DOC_GIT"
    printf '  - %s\n' "$DOC_SCRIPT"
    printf '  - %s\n' "$DOC_REPORTS"
    printf '  - %s\n' "$DOC_LOGGING"
    printf '\n'
    printf 'Missing checks: %s\n' "$missing_count"
    printf 'Skipped checks: %s\n' "$skipped_count"
    printf 'Warning checks: %s\n' "$warning_count"
    printf '\n'
    printf 'Generated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  TSV: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'No files were modified.\n'
  } >> "$REPORT_FILE"

  if [ "$missing_count" -eq 0 ]; then
    tsv_row "summary" "phase2-global-docs" "missing checks" "ok" "missing_count=0"
  else
    tsv_row "summary" "phase2-global-docs" "missing checks" "warning" "missing_count=${missing_count}"
  fi

  if [ "$skipped_count" -eq 0 ]; then
    tsv_row "summary" "phase2-global-docs" "skipped checks" "ok" "skipped_count=0"
  else
    tsv_row "summary" "phase2-global-docs" "skipped checks" "warning" "skipped_count=${skipped_count}"
  fi
}

main() {
  require_writable_dir "$REPORT_DIR" "report dir"
  require_writable_dir "$RAW_DIR" "raw dir"
  require_dir "$DOCS_OPS" "docs operations dir"

  write_headers

  log "Validating Phase 2 documentation globally."
  log "Report: $REPORT_FILE"
  log "TSV: $TSV_FILE"

  validate_architecture_reconciliation
  validate_scripts_lib_policy
  validate_runtime_profiles
  validate_manpages_policy
  validate_git_routine
  validate_script_conventions
  validate_reports_policy
  validate_logging_policy
  validate_cross_references
  write_git_status
  write_pending_tasks
  write_summary

  log "Global validation completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report: %s\n' "$REPORT_FILE"
  printf '  TSV:          %s\n' "$TSV_FILE"
}

main "$@"
