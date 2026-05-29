#!/usr/bin/env bash
set -u

APP_DIR="/srv/toolbox/app"
LIB_DIR="$APP_DIR/scripts/lib"

source "$LIB_DIR/logging.sh"
source "$LIB_DIR/timestamps.sh"
source "$LIB_DIR/tsv.sh"
source "$LIB_DIR/paths.sh"

STAMP="$(toolbox_timestamp)"
SHARED_DIR="$(toolbox_shared_dir)"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"

REPORT="$REPORT_DIR/beets_mbid_workflow_generalization_diagnosis_report_$STAMP.txt"
TSV="$RAW_DIR/beets_mbid_workflow_generalization_diagnosis_$STAMP.tsv"

SCRIPTS=(
  "scripts/media/library/plan-music-staging-beets-mbid-dry-run.sh"
  "scripts/media/library/apply-music-staging-beets-mbid-dry-run.sh"
  "scripts/media/library/validate-music-staging-beets-mbid-dry-run.sh"
)

PATTERNS=(
  "Pharoah Sanders"
  "Thembi"
  "34497839-9158-4c6f-8945-7f543276ea3e"
  "93.7"
  "0.06"
  "beets_mbid_debug__1971__Thembi"
  "1971__Thembi"
)

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
  require_function tsv_row
}

write_row() {
  local script="$1"
  local pattern="$2"
  local status="$3"
  local line_numbers="$4"
  local notes="$5"

  tsv_row "$script" "$pattern" "$status" "$line_numbers" "$notes" >> "$TSV"
}

main() {
  local script
  local pattern
  local matches
  local line_numbers
  local total_findings=0

  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting Beets MBID workflow generalization diagnosis."

  tsv_row \
    "script" \
    "pattern" \
    "status" \
    "line_numbers" \
    "notes" > "$TSV"

  {
    printf '%s\n' '# Beets MBID Workflow Generalization Diagnosis'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: diagnosis only. This script does not modify files.'
    printf '\n'
    printf '%s\n' '## Scope'
    printf '\n'
    printf '%s\n' 'Scripts checked:'
    printf '\n'
    printf '%s\n' '```text'
    printf '%s\n' "${SCRIPTS[@]}"
    printf '%s\n' '```'
    printf '\n'
  } > "$REPORT"

  for script in "${SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
      write_row "$script" "" "FAIL" "" "script missing"
      total_findings=$((total_findings + 1))
      continue
    fi

    for pattern in "${PATTERNS[@]}"; do
      matches="$(grep -nF "$pattern" "$script" 2>/dev/null || true)"

      if [ -n "$matches" ]; then
        line_numbers="$(printf '%s\n' "$matches" | cut -d: -f1 | paste -sd ',' -)"
        write_row "$script" "$pattern" "FOUND" "$line_numbers" "candidate hardcode; review/generalize"
        total_findings=$((total_findings + 1))
      else
        write_row "$script" "$pattern" "OK" "" "pattern not found"
      fi
    done
  done

  {
    printf '%s\n' '## Findings'
    printf '\n'
    printf '%s\n' '```text'
    column -t -s $'\t' "$TSV" 2>/dev/null || cat "$TSV"
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Interpretation'
    printf '\n'
    if [ "$total_findings" -gt 0 ]; then
      printf 'Findings: %s\n' "$total_findings"
      printf '%s\n' 'The MBID dry-run workflow still contains album-specific assumptions. Create a plan/apply/validate correction before using it for more albums.'
    else
      printf '%s\n' 'No hardcoded Thembi/Sanders patterns found in checked scripts.'
    fi
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  log "Beets MBID workflow generalization diagnosis completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
