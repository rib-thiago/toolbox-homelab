#!/usr/bin/env bash
set -u

ROOT="/srv/toolbox/app"
GENERATOR="$ROOT/scripts/admin/system/generate-toolbox-script-semantics-inventory.sh"

REPORT_DIR="/srv/toolbox/shared/reports/system"
RAW_DIR="/srv/toolbox/shared/library-db/raw/system"
INV_DIR="/srv/toolbox/shared/inventory/toolbox"

TS="$(date +%Y%m%d-%H%M%S)"
REPORT="$REPORT_DIR/toolbox_script_semantics_inventory_all_scopes_rerun_report_${TS}.txt"
TSV="$RAW_DIR/toolbox_script_semantics_inventory_all_scopes_rerun_${TS}.tsv"

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
  run-toolbox-script-semantics-inventory-all-scopes.sh

Runs the semantic inventory generator for the bounded scopes:

  block1-core-platform
  block2-admin-system-git
  block3-infrastructure-admin
  block4-media-library-soulseek

Writes:
  $REPORT_DIR/toolbox_script_semantics_inventory_all_scopes_rerun_report_*.txt
  $RAW_DIR/toolbox_script_semantics_inventory_all_scopes_rerun_*.tsv

This script writes generated evidence only under /srv/toolbox/shared.
It does not modify repository files, services, media, configs, or Git state.
USAGE
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

[ -d "$ROOT" ] || fail "Repo root not found: $ROOT"
[ -x "$GENERATOR" ] || fail "Generator not executable: $GENERATOR"

mkdir -p "$REPORT_DIR" "$RAW_DIR" "$INV_DIR" || fail "Could not create output directories"

cd "$ROOT" || fail "Could not cd to $ROOT"

git_branch="$(git branch --show-current 2>/dev/null || printf 'unknown')"
git_commit="$(git rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
if [ -n "$(git status --short 2>/dev/null)" ]; then
  git_status="dirty"
else
  git_status="clean"
fi

{
  printf '# Toolbox script semantics inventory all-scopes rerun report\n\n'
  printf 'Generated at: %s\n' "$TS"
  printf 'Repo root: %s\n' "$ROOT"
  printf 'Git branch: %s\n' "$git_branch"
  printf 'Git commit: %s\n' "$git_commit"
  printf 'Git status before rerun: %s\n' "$git_status"
  printf 'Generator: %s\n' "$GENERATOR"
  printf 'TSV: %s\n\n' "$TSV"

  printf '## Safety notes\n\n'
  printf -- '- Runs only the semantic inventory generator.\n'
  printf -- '- Does not execute scoped scripts.\n'
  printf -- '- Does not inspect live media, services, configs, secrets, or runtime state.\n'
  printf -- '- Writes generated evidence only under /srv/toolbox/shared.\n\n'

  printf '## Scope runs\n\n'
} > "$REPORT" || fail "Could not write report: $REPORT"

printf 'timestamp\tscope\tscope_slug\tstatus\traw_tsv\tnormalized_tsv\treport\ttotal_rows\tplaceholder_rows\twarning_rows\n' > "$TSV" \
  || fail "Could not write TSV: $TSV"

scopes=(
  "block1-core-platform:block1_core_platform"
  "block2-admin-system-git:block2_admin_system_git"
  "block3-infrastructure-admin:block3_infrastructure_admin"
  "block4-media-library-soulseek:block4_media_library_soulseek"
)

for item in "${scopes[@]}"; do
  scope="${item%%:*}"
  slug="${item##*:}"

  log "Running semantic inventory scope: $scope"

  tmp_output="$(mktemp)"
  if "$GENERATOR" --scope "$scope" > "$tmp_output" 2>&1; then
    status="ok"
  else
    status="fail"
  fi

  raw_latest="$(ls -1t "$RAW_DIR/toolbox_script_semantics_inventory_${slug}_"*.tsv 2>/dev/null | head -1 || true)"
  norm_latest="$(ls -1t "$INV_DIR/toolbox_script_semantics_inventory_${slug}_"*.tsv 2>/dev/null | head -1 || true)"
  report_latest="$(ls -1t "$REPORT_DIR/toolbox_script_semantics_inventory_report_${slug}_"*.txt 2>/dev/null | head -1 || true)"

  total_rows="unknown"
  placeholder_rows="unknown"
  warning_rows="unknown"

  if [ -n "$report_latest" ] && [ -f "$report_latest" ]; then
    total_rows="$(grep -m1 '^Total scoped rows:' "$report_latest" | awk -F ': ' '{print $2}' || true)"
    placeholder_rows="$(grep -m1 '^Placeholder rows:' "$report_latest" | awk -F ': ' '{print $2}' || true)"
    warning_rows="$(grep -m1 '^Rows with warnings:' "$report_latest" | awk -F ': ' '{print $2}' || true)"
  fi

  [ -n "$total_rows" ] || total_rows="unknown"
  [ -n "$placeholder_rows" ] || placeholder_rows="unknown"
  [ -n "$warning_rows" ] || warning_rows="unknown"

  {
    printf '### %s\n\n' "$scope"
    printf 'Status: %s\n\n' "$status"
    printf 'Raw TSV: %s\n' "${raw_latest:-missing}"
    printf 'Normalized TSV: %s\n' "${norm_latest:-missing}"
    printf 'Report: %s\n' "${report_latest:-missing}"
    printf 'Total scoped rows: %s\n' "$total_rows"
    printf 'Placeholder rows: %s\n' "$placeholder_rows"
    printf 'Rows with warnings: %s\n\n' "$warning_rows"
    printf 'Generator output:\n\n'
    printf '```text\n'
    cat "$tmp_output"
    printf '```\n\n'
  } >> "$REPORT"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$TS" "$scope" "$slug" "$status" \
    "${raw_latest:-missing}" "${norm_latest:-missing}" "${report_latest:-missing}" \
    "$total_rows" "$placeholder_rows" "$warning_rows" >> "$TSV"

  rm -f "$tmp_output"

  if [ "$status" != "ok" ]; then
    fail "Generator failed for scope: $scope. See $REPORT"
  fi
done

if [ -n "$(git status --short 2>/dev/null)" ]; then
  git_status_after="dirty"
else
  git_status_after="clean"
fi

{
  printf '## Final Git status\n\n'
  printf 'Git status after rerun: %s\n\n' "$git_status_after"
  printf '```text\n'
  git status --short
  printf '```\n'
} >> "$REPORT"

log "All scopes rerun completed."
log "Report: $REPORT"
log "TSV: $TSV"

printf 'Report: %s\n' "$REPORT"
printf 'TSV: %s\n' "$TSV"
