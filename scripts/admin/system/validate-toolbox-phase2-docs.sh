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

REPORT_FILE="${REPORT_DIR}/toolbox_phase2_docs_validation_report_${STAMP}.txt"
TSV_FILE="${RAW_DIR}/toolbox_phase2_docs_validation_${STAMP}.tsv"

DOC_ARCH="${DOCS_OPS}/toolbox_architecture_reconciliation.md"
DOC_LIB="${DOCS_OPS}/toolbox_scripts_lib_policy.md"
DOC_RUNTIME="${DOCS_OPS}/toolbox_runtime_profiles.md"
DOC_MAN="${DOCS_OPS}/toolbox_manpages_policy.md"
DOC_GIT="${DOCS_OPS}/toolbox_git_routine.md"

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
  local item="$2"
  local check="$3"
  local status="$4"
  local details="$5"

  {
    tsv_escape "$category"
    printf '\t'
    tsv_escape "$item"
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
    printf 'Toolbox Phase 2 documentation validation report\n'
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Docs operations: %s\n' "$DOCS_OPS"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope:\n'
    printf '  validate Phase 2 documentation only;\n'
    printf '  no edits;\n'
    printf '  no Docker changes;\n'
    printf '  no scripts/lib creation;\n'
    printf '  no MANPATH changes;\n'
    printf '  no Git commit.\n'
    printf '\n'
    printf 'Output destinations remain provisional and inherited from recent scripts.\n'
  } > "$REPORT_FILE"

  {
    printf 'category\titem\tcheck\tstatus\tdetails\n'
  } > "$TSV_FILE"
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

    printf 'OK: %s exists | size=%s | lines=%s | sha256=%s\n' "$label" "$size" "$lines" "$sha" >> "$REPORT_FILE"
    tsv_row "file" "$label" "exists" "ok" "path=${file} size=${size} lines=${lines} sha256=${sha}"
  else
    printf 'MISSING: %s | %s\n' "$label" "$file" >> "$REPORT_FILE"
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
    printf 'OK: %s contains "%s" (%s hit(s))\n' "$label" "$term" "$hits" >> "$REPORT_FILE"
    tsv_row "term" "$label" "$term" "ok" "hits=${hits}"
  else
    printf 'MISSING: %s does not contain "%s"\n' "$label" "$term" >> "$REPORT_FILE"
    tsv_row "term" "$label" "$term" "missing" "term not found"
  fi
}

validate_architecture_reconciliation() {
  section "1. toolbox_architecture_reconciliation.md"

  validate_file_exists "$DOC_ARCH" "toolbox_architecture_reconciliation.md"

  validate_term "$DOC_ARCH" "toolbox_architecture_reconciliation.md" "plataforma operacional híbrida"
  validate_term "$DOC_ARCH" "toolbox_architecture_reconciliation.md" "host-mode"
  validate_term "$DOC_ARCH" "toolbox_architecture_reconciliation.md" "container-mode"
  validate_term "$DOC_ARCH" "toolbox_architecture_reconciliation.md" "toolbox-media"
  validate_term "$DOC_ARCH" "toolbox_architecture_reconciliation.md" "scripts/lib"
  validate_term "$DOC_ARCH" "toolbox_architecture_reconciliation.md" "diagnose → plan → apply → validate"
  validate_term "$DOC_ARCH" "toolbox_architecture_reconciliation.md" "Navidrome"
}

validate_scripts_lib_policy() {
  section "2. toolbox_scripts_lib_policy.md"

  validate_file_exists "$DOC_LIB" "toolbox_scripts_lib_policy.md"

  validate_term "$DOC_LIB" "toolbox_scripts_lib_policy.md" "scripts/lib"
  validate_term "$DOC_LIB" "toolbox_scripts_lib_policy.md" "logging.sh"
  validate_term "$DOC_LIB" "toolbox_scripts_lib_policy.md" "log()"
  validate_term "$DOC_LIB" "toolbox_scripts_lib_policy.md" "fail()"
  validate_term "$DOC_LIB" "toolbox_scripts_lib_policy.md" "tsv_escape()"
  validate_term "$DOC_LIB" "toolbox_scripts_lib_policy.md" "adoção gradual"
}

validate_runtime_profiles() {
  section "3. toolbox_runtime_profiles.md"

  validate_file_exists "$DOC_RUNTIME" "toolbox_runtime_profiles.md"

  validate_term "$DOC_RUNTIME" "toolbox_runtime_profiles.md" "host-mode"
  validate_term "$DOC_RUNTIME" "toolbox_runtime_profiles.md" "container-mode"
  validate_term "$DOC_RUNTIME" "toolbox_runtime_profiles.md" "toolbox-base"
  validate_term "$DOC_RUNTIME" "toolbox_runtime_profiles.md" "toolbox-docs"
  validate_term "$DOC_RUNTIME" "toolbox_runtime_profiles.md" "toolbox-media"
  validate_term "$DOC_RUNTIME" "toolbox_runtime_profiles.md" "toolbox-nlp"
  validate_term "$DOC_RUNTIME" "toolbox_runtime_profiles.md" "run-job"
  validate_term "$DOC_RUNTIME" "toolbox_runtime_profiles.md" "diagnose → plan → apply → validate"
  validate_term "$DOC_RUNTIME" "toolbox_runtime_profiles.md" "FileBrowser não é runtime"
}

validate_manpages_policy() {
  section "4. toolbox_manpages_policy.md"

  validate_file_exists "$DOC_MAN" "toolbox_manpages_policy.md"

  validate_term "$DOC_MAN" "toolbox_manpages_policy.md" "Manpages e groff"
  validate_term "$DOC_MAN" "toolbox_manpages_policy.md" "/srv/toolbox/app/docs"
  validate_term "$DOC_MAN" "toolbox_manpages_policy.md" "/toolbox/app/docs"
  validate_term "$DOC_MAN" "toolbox_manpages_policy.md" "docs/man1"
  validate_term "$DOC_MAN" "toolbox_manpages_policy.md" "docs/man7"
  validate_term "$DOC_MAN" "toolbox_manpages_policy.md" "tbman"
  validate_term "$DOC_MAN" "toolbox_manpages_policy.md" "MANPATH"
  validate_term "$DOC_MAN" "toolbox_manpages_policy.md" "diagnose → plan → apply → validate"
}

validate_git_routine() {
  section "5. toolbox_git_routine.md"

  validate_file_exists "$DOC_GIT" "toolbox_git_routine.md"

  validate_term "$DOC_GIT" "toolbox_git_routine.md" "git status --short"
  validate_term "$DOC_GIT" "toolbox_git_routine.md" "git add ."
  validate_term "$DOC_GIT" "toolbox_git_routine.md" "bashcheck"
  validate_term "$DOC_GIT" "toolbox_git_routine.md" "APPLY"
  validate_term "$DOC_GIT" "toolbox_git_routine.md" "scripts/lib"
  validate_term "$DOC_GIT" "toolbox_git_routine.md" "toolbox-media"
  validate_term "$DOC_GIT" "toolbox_git_routine.md" ".save"
  validate_term "$DOC_GIT" "toolbox_git_routine.md" "diagnose → plan → apply → validate"
}

write_git_status() {
  section "6. Git status for Phase 2 docs"

  if git -C "$TOOLBOX_APP" rev-parse --show-toplevel >/dev/null 2>&1; then
    {
      cd "$TOOLBOX_APP" || exit 0
      git status --short docs/operations
    } >> "$REPORT_FILE" 2>&1

    tsv_row "git" "docs/operations" "git status --short" "recorded" "see report"
  else
    printf 'Git repository not detected at %s\n' "$TOOLBOX_APP" >> "$REPORT_FILE"
    tsv_row "git" "$TOOLBOX_APP" "git status" "missing" "not a git repository"
  fi
}

write_summary() {
  section "7. Summary"

  {
    printf 'Validated Phase 2 documentation files:\n'
    printf '  - %s\n' "$DOC_ARCH"
    printf '  - %s\n' "$DOC_LIB"
    printf '  - %s\n' "$DOC_RUNTIME"
    printf '  - %s\n' "$DOC_MAN"
    printf '  - %s\n' "$DOC_GIT"
    printf '\n'
    printf 'Generated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  TSV: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'No files were modified.\n'
  } >> "$REPORT_FILE"
}

main() {
  require_writable_dir "$REPORT_DIR" "report dir"
  require_writable_dir "$RAW_DIR" "raw dir"
  require_dir "$DOCS_OPS" "docs operations dir"

  write_headers

  log "Validating Phase 2 documentation."
  log "Report: $REPORT_FILE"
  log "TSV: $TSV_FILE"

  validate_architecture_reconciliation
  validate_scripts_lib_policy
  validate_runtime_profiles
  validate_manpages_policy
  validate_git_routine
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
