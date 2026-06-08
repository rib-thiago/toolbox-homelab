#!/usr/bin/env bash
set -u

ROOT="/srv/toolbox/app"

REPORT_DIR="/srv/toolbox/shared/reports/system"
RAW_DIR="/srv/toolbox/shared/library-db/raw/system"
INV_DIR="/srv/toolbox/shared/inventory/toolbox"

TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$REPORT_DIR/toolbox_script_semantics_inventory_latest_validation_report_${TS}.txt"
TSV="$RAW_DIR/toolbox_script_semantics_inventory_latest_validation_${TS}.tsv"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

usage() {
  cat <<USAGE
Usage:
  validate-toolbox-script-semantics-inventory-latest.sh

Validates the latest semantic inventory raw and normalized TSVs for:

  block1_core_platform
  block2_admin_system_git
  block3_infrastructure_admin
  block4_media_library_soulseek

Checks:
  - latest raw TSV exists
  - latest normalized TSV exists
  - column counts are stable
  - bad_rows=0
  - report exists
  - report summary fields can be read

Writes:
  $REPORT_DIR/toolbox_script_semantics_inventory_latest_validation_report_*.txt
  $RAW_DIR/toolbox_script_semantics_inventory_latest_validation_*.tsv

This script writes generated validation evidence only under /srv/toolbox/shared.
USAGE
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

[ -d "$ROOT" ] || fail "Repo root not found: $ROOT"

mkdir -p "$REPORT_DIR" "$RAW_DIR" || fail "Could not create output directories"

cd "$ROOT" || fail "Could not cd to $ROOT"

git_branch="$(git branch --show-current 2>/dev/null || printf 'unknown')"
git_commit="$(git rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
if [ -n "$(git status --short 2>/dev/null)" ]; then
  git_status="dirty"
else
  git_status="clean"
fi

{
  printf '# Toolbox script semantics inventory latest validation report\n\n'
  printf 'Generated at: %s\n' "$TS"
  printf 'Repo root: %s\n' "$ROOT"
  printf 'Git branch: %s\n' "$git_branch"
  printf 'Git commit: %s\n' "$git_commit"
  printf 'Git status: %s\n' "$git_status"
  printf 'TSV: %s\n\n' "$TSV"

  printf '## Validation summary\n\n'
} > "$REPORT" || fail "Could not write report: $REPORT"

printf 'timestamp\tscope_slug\tfile_kind\tpath\texpected_columns\tbad_rows\tstatus\n' > "$TSV" \
  || fail "Could not write TSV: $TSV"

validate_tsv_file() {
  scope_slug="$1"
  file_kind="$2"
  path="$3"

  if [ -z "$path" ] || [ ! -f "$path" ]; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$TS" "$scope_slug" "$file_kind" "${path:-missing}" "missing" "missing" "fail" >> "$TSV"
    {
      printf -- '- %s %s: missing\n' "$scope_slug" "$file_kind"
    } >> "$REPORT"
    return 1
  fi

  result="$(awk -F '\t' '
    NR==1 { expected=NF; next }
    NF!=expected { bad++ }
    END { printf "%s\t%s", expected+0, bad+0 }
  ' "$path")"

  expected_columns="${result%%	*}"
  bad_rows="${result##*	}"

  if [ "$bad_rows" = "0" ]; then
    status="ok"
  else
    status="fail"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$TS" "$scope_slug" "$file_kind" "$path" "$expected_columns" "$bad_rows" "$status" >> "$TSV"

  {
    printf -- '- %s %s: expected_columns=%s bad_rows=%s status=%s\n' \
      "$scope_slug" "$file_kind" "$expected_columns" "$bad_rows" "$status"
  } >> "$REPORT"

  [ "$status" = "ok" ]
}

scopes=(
  "block1_core_platform"
  "block2_admin_system_git"
  "block3_infrastructure_admin"
  "block4_media_library_soulseek"
)

failures=0

for slug in "${scopes[@]}"; do
  raw_latest="$(ls -1t "$RAW_DIR/toolbox_script_semantics_inventory_${slug}_"*.tsv 2>/dev/null | head -1 || true)"
  norm_latest="$(ls -1t "$INV_DIR/toolbox_script_semantics_inventory_${slug}_"*.tsv 2>/dev/null | head -1 || true)"
  report_latest="$(ls -1t "$REPORT_DIR/toolbox_script_semantics_inventory_report_${slug}_"*.txt 2>/dev/null | head -1 || true)"

  {
    printf '\n## %s\n\n' "$slug"
    printf 'Raw TSV: %s\n' "${raw_latest:-missing}"
    printf 'Normalized TSV: %s\n' "${norm_latest:-missing}"
    printf 'Report: %s\n\n' "${report_latest:-missing}"
  } >> "$REPORT"

  validate_tsv_file "$slug" "raw" "$raw_latest" || failures=$((failures + 1))
  validate_tsv_file "$slug" "normalized" "$norm_latest" || failures=$((failures + 1))

  if [ -n "$report_latest" ] && [ -f "$report_latest" ]; then
    total_rows="$(grep -m1 '^Total scoped rows:' "$report_latest" | awk -F ': ' '{print $2}' || true)"
    placeholder_rows="$(grep -m1 '^Placeholder rows:' "$report_latest" | awk -F ': ' '{print $2}' || true)"
    warning_rows="$(grep -m1 '^Rows with warnings:' "$report_latest" | awk -F ': ' '{print $2}' || true)"

    {
      printf 'Report totals:\n\n'
      printf -- '- Total scoped rows: %s\n' "${total_rows:-unknown}"
      printf -- '- Placeholder rows: %s\n' "${placeholder_rows:-unknown}"
      printf -- '- Rows with warnings: %s\n' "${warning_rows:-unknown}"
    } >> "$REPORT"
  else
    {
      printf 'Report totals: missing report\n'
    } >> "$REPORT"
    failures=$((failures + 1))
  fi
done

{
  printf '\n## Git status\n\n'
  printf '```text\n'
  git status --short
  printf '```\n\n'

  printf '## Result\n\n'
  printf 'Failures: %s\n' "$failures"
} >> "$REPORT"

log "Validation completed."
log "Report: $REPORT"
log "TSV: $TSV"
log "Failures: $failures"

printf 'Report: %s\n' "$REPORT"
printf 'TSV: %s\n' "$TSV"
printf 'Failures: %s\n' "$failures"

if [ "$failures" -ne 0 ]; then
  exit 1
fi
