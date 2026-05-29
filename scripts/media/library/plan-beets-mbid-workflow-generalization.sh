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
PLAN_DIR="$SHARED_DIR/library-db/plans/media/staging"

REPORT="$REPORT_DIR/beets_mbid_workflow_generalization_plan_report_$STAMP.txt"
TSV="$PLAN_DIR/beets_mbid_workflow_generalization_plan_$STAMP.tsv"

TARGET_SCRIPTS=(
  "scripts/media/library/plan-music-staging-beets-mbid-dry-run.sh"
  "scripts/media/library/apply-music-staging-beets-mbid-dry-run.sh"
  "scripts/media/library/validate-music-staging-beets-mbid-dry-run.sh"
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

write_step() {
  local step_id="$1"
  local phase="$2"
  local target="$3"
  local status="$4"
  local action="$5"
  local notes="$6"

  tsv_row "$step_id" "$phase" "$target" "$status" "$action" "$notes" >> "$TSV"
}

main() {
  local script
  local missing=0

  require_lib_contract

  mkdir -p "$REPORT_DIR" "$PLAN_DIR"

  log "Generating Beets MBID workflow generalization plan."

  tsv_row \
    "step_id" \
    "phase" \
    "target" \
    "status" \
    "action" \
    "notes" > "$TSV"

  for script in "${TARGET_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
      write_step "PRE-001" "preflight" "$script" "OK" "target script exists" ""
    else
      write_step "PRE-001" "preflight" "$script" "FAIL" "target script missing" ""
      missing=$((missing + 1))
    fi
  done

  if [ "$missing" -gt 0 ]; then
    fail "One or more target scripts are missing."
  fi

  write_step "PLAN-001" "design" "plan-music-staging-beets-mbid-dry-run.sh" "PLANNED" "generalize report text" "replace Thembi/Sanders-specific evidence and decision rules with album/artist/MBID parameters"
  write_step "PLAN-002" "design" "apply-music-staging-beets-mbid-dry-run.sh" "PLANNED" "generalize expected match markers" "accept expected artist/album as optional parameters; avoid hardcoded Pharoah Sanders/Thembi markers"
  write_step "PLAN-003" "design" "validate-music-staging-beets-mbid-dry-run.sh" "PLANNED" "generalize validation inputs" "accept album_dir, mbid, expected_artist, expected_album, optional expected_match_min, optional expected_distance_max"
  write_step "PLAN-004" "design" "validate-music-staging-beets-mbid-dry-run.sh" "PLANNED" "generalize evidence log discovery" "derive SAFE_ALBUM_NAME from album_dir; use beets_mbid_debug_<SAFE_ALBUM_NAME>_*.log and beets_mbid_dry_run_<SAFE_ALBUM_NAME>_live_*.log"
  write_step "PLAN-005" "design" "all MBID dry-run scripts" "PLANNED" "preserve Thembi defaults" "default album and MBID may remain as fallback, but report language must be generic"
  write_step "PLAN-006" "safety" "all MBID dry-run scripts" "PLANNED" "preserve dry-run safety" "must keep -C -W, no write/copy/move policy, no tag mutation"
  write_step "PLAN-007" "validation" "diagnose-beets-mbid-workflow-generalization.sh" "PLANNED" "rerun hardcode diagnosis" "expected: no inappropriate Thembi/Sanders hardcodes except documented defaults"
  write_step "PLAN-008" "validation" "Spectrum" "PLANNED" "validate workflow with Spectrum parameters" "album=/srv/media/music-staging/reviewing/1973 Spectrum; mbid=1c9b277c-2b46-3e9d-94c9-f3ffaa684126; artist=Billy Cobham; album=Spectrum"
  write_step "PLAN-009" "validation" "Thembi" "PLANNED" "preserve known-good Thembi workflow" "album=/srv/media/music-staging/reviewing/[1971] Thembi; mbid=34497839-9158-4c6f-8945-7f543276ea3e; artist=Pharoah Sanders; album=Thembi"

  {
    printf '%s\n' '# Beets MBID Workflow Generalization Plan'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: plan only. This script does not edit files, run Beets, write tags, copy files or move files.'
    printf '\n'

    printf '%s\n' '## Problem'
    printf '\n'
    printf '%s\n' 'The Beets MBID dry-run workflow worked for Thembi, but Spectrum exposed album-specific hardcodes in reports and validation logic.'
    printf '%s\n' 'The workflow must be generalized before it is used as a reusable pipeline for future albums.'
    printf '\n'

    printf '%s\n' '## Target scripts'
    printf '\n'
    printf '%s\n' '```text'
    printf '%s\n' "${TARGET_SCRIPTS[@]}"
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' '## Required interface after correction'
    printf '\n'
    printf '%s\n' '```text'
    printf '%s\n' 'plan-music-staging-beets-mbid-dry-run.sh [album_dir] [mbid] [expected_artist] [expected_album]'
    printf '%s\n' 'apply-music-staging-beets-mbid-dry-run.sh --apply [album_dir] [mbid] [expected_artist] [expected_album]'
    printf '%s\n' 'validate-music-staging-beets-mbid-dry-run.sh [album_dir] [mbid] [expected_artist] [expected_album] [expected_match_min] [expected_distance_max]'
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' '## Defaults'
    printf '\n'
    printf '%s\n' 'Defaults may remain Thembi-based for convenience, but all user-visible evidence and validation checks must use resolved variables rather than hardcoded artist/album strings.'
    printf '\n'

    printf '%s\n' '## Validation criteria'
    printf '\n'
    printf '%s\n' '- Hardcode diagnosis should no longer find Thembi/Sanders text in generic report/validation logic.'
    printf '%s\n' '- Thembi must remain valid with defaults or explicit parameters.'
    printf '%s\n' '- Spectrum must work with explicit parameters.'
    printf '%s\n' '- Safety flags and sandbox behavior must remain unchanged.'
    printf '\n'

    printf '%s\n' '## Plan TSV preview'
    printf '\n'
    printf '%s\n' '```text'
    column -t -s $'\t' "$TSV" 2>/dev/null || cat "$TSV"
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } > "$REPORT"

  log "Beets MBID workflow generalization plan generated."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
