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
SNAPSHOT_DIR="/srv/toolbox/shared/library-db/snapshots"

REPORT_FILE="${REPORT_DIR}/toolbox_phase2_docs_backup_report_${STAMP}.txt"
TSV_FILE="${RAW_DIR}/toolbox_phase2_docs_backup_${STAMP}.tsv"
SNAPSHOT_FILE="${SNAPSHOT_DIR}/toolbox_phase2_docs_pre_manual_edit_snapshot_${STAMP}.tsv"
BACKUP_DIR="${SNAPSHOT_DIR}/toolbox_phase2_docs_backup_${STAMP}"

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
  local status="$3"
  local details="$4"

  {
    tsv_escape "$category"
    printf '\t'
    tsv_escape "$item"
    printf '\t'
    tsv_escape "$status"
    printf '\t'
    tsv_escape "$details"
    printf '\n'
  } >> "$TSV_FILE"
}

write_headers() {
  {
    printf 'Toolbox Phase 2 documentation backup report\n'
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Docs operations: %s\n' "$DOCS_OPS"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf 'Snapshot file: %s\n' "$SNAPSHOT_FILE"
    printf 'Backup dir: %s\n' "$BACKUP_DIR"
    printf '\n'
    printf 'Scope:\n'
    printf '  backup/snapshot only;\n'
    printf '  no document edits;\n'
    printf '  no Docker changes;\n'
    printf '  no scripts/lib changes;\n'
    printf '  no MANPATH changes;\n'
    printf '  no Git commit.\n'
    printf '\n'
    printf 'Output destinations remain provisional and inherited from recent scripts.\n'
  } > "$REPORT_FILE"

  {
    printf 'category\titem\tstatus\tdetails\n'
  } > "$TSV_FILE"

  {
    printf 'path\texists\tsize_bytes\tsha256\n'
  } > "$SNAPSHOT_FILE"
}

snapshot_file() {
  local file="$1"

  if [ -f "$file" ]; then
    printf '%s\t%s\t%s\t%s\n' \
      "$file" \
      "yes" \
      "$(stat -c '%s' "$file" 2>/dev/null || printf 'UNKNOWN')" \
      "$(sha256sum "$file" 2>/dev/null | awk '{print $1}' || printf 'UNKNOWN')" \
      >> "$SNAPSHOT_FILE"
  else
    printf '%s\t%s\t%s\t%s\n' "$file" "no" "-" "-" >> "$SNAPSHOT_FILE"
  fi
}

backup_file_if_exists() {
  local file="$1"
  local rel
  local dest

  if [ ! -f "$file" ]; then
    tsv_row "backup" "$file" "missing" "not copied"
    return 0
  fi

  rel="${file#$TOOLBOX_APP/}"
  dest="${BACKUP_DIR}/${rel}"

  mkdir -p "$(dirname "$dest")"
  cp -a "$file" "$dest"

  tsv_row "backup" "$file" "copied" "$dest"
}

main() {
  require_writable_dir "$REPORT_DIR" "report dir"
  require_writable_dir "$RAW_DIR" "raw dir"
  require_writable_dir "$SNAPSHOT_DIR" "snapshot dir"
  require_dir "$DOCS_OPS" "docs operations dir"

  mkdir -p "$BACKUP_DIR"

  write_headers

  log "Creating documentation backup."
  log "Report: $REPORT_FILE"
  log "TSV: $TSV_FILE"
  log "Snapshot: $SNAPSHOT_FILE"
  log "Backup dir: $BACKUP_DIR"

  for file in \
    "${DOCS_OPS}/toolbox_architecture_reconciliation.md" \
    "${DOCS_OPS}/toolbox_scripts_lib_policy.md" \
    "${DOCS_OPS}/toolbox_runtime_profiles.md" \
    "${DOCS_OPS}/toolbox_manpages_policy.md" \
    "${DOCS_OPS}/toolbox_git_routine.md" \
    "${DOCS_OPS}/toolbox_script_conventions.md" \
    "${DOCS_OPS}/toolbox_reports_policy.md" \
    "${DOCS_OPS}/toolbox_logging_policy.md"
  do
    snapshot_file "$file"
    backup_file_if_exists "$file"
  done

  {
    printf '\nGenerated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  TSV: %s\n' "$TSV_FILE"
    printf '  Snapshot: %s\n' "$SNAPSHOT_FILE"
    printf '  Backup dir: %s\n' "$BACKUP_DIR"
  } >> "$REPORT_FILE"

  log "Backup completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"
  log "Snapshot: $SNAPSHOT_FILE"
  log "Backup dir: $BACKUP_DIR"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report: %s\n' "$REPORT_FILE"
  printf '  TSV:          %s\n' "$TSV_FILE"
  printf '  Snapshot:     %s\n' "$SNAPSHOT_FILE"
  printf '  Backup dir:   %s\n' "$BACKUP_DIR"
}

main "$@"
