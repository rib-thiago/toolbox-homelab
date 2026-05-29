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
SNAPSHOT_DIR="$SHARED_DIR/library-db/snapshots/media/staging/beets-mbid-remove-album-defaults-$STAMP"

REPORT="$REPORT_DIR/beets_mbid_workflow_remove_album_defaults_apply_report_$STAMP.txt"
TSV="$RAW_DIR/beets_mbid_workflow_remove_album_defaults_apply_$STAMP.tsv"

APPLY_MODE="${1:-}"

PLAN_SCRIPT="scripts/media/library/plan-music-staging-beets-mbid-dry-run.sh"
APPLY_SCRIPT="scripts/media/library/apply-music-staging-beets-mbid-dry-run.sh"
VALIDATE_SCRIPT="scripts/media/library/validate-music-staging-beets-mbid-dry-run.sh"

FORBIDDEN_PATTERNS=(
  "Pharoah Sanders"
  "Thembi"
  "34497839-9158-4c6f-8945-7f543276ea3e"
  "1971__Thembi"
  "beets_mbid_debug__1971__Thembi"
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

confirm_apply() {
  local confirmation

  if [ "$APPLY_MODE" != "--apply" ]; then
    fail "This script removes album-specific defaults from MBID workflow scripts. Re-run with: apply-beets-mbid-workflow-remove-album-defaults.sh --apply"
  fi

  printf '%s\n' "This script will remove album-specific defaults from:"
  printf '%s\n' "- $PLAN_SCRIPT"
  printf '%s\n' "- $APPLY_SCRIPT"
  printf '%s\n' "- $VALIDATE_SCRIPT"
  printf '%s\n' "Backups will be written to:"
  printf '%s\n' "- $SNAPSHOT_DIR"
  printf '%s\n' "After this, album_dir, MBID, expected_artist and expected_album become mandatory."
  printf '%s\n' "It will not run Beets, write tags, copy files, move files, or modify /srv/media/music."
  printf '%s' "Type APPLY to continue: "
  read -r confirmation

  if [ "$confirmation" != "APPLY" ]; then
    fail "Apply aborted by user."
  fi
}

backup_file() {
  local file="$1"
  local dest

  mkdir -p "$SNAPSHOT_DIR"
  dest="$SNAPSHOT_DIR/$(basename "$file").bak"

  if [ -f "$file" ]; then
    cp -a "$file" "$dest"
    write_step "BACKUP" "backup" "$file" "OK" "created backup" "$dest"
  else
    write_step "BACKUP" "backup" "$file" "FAIL" "source file missing" ""
    return 1
  fi
}

apply_python_patch() {
  python3 - <<'PY'
from pathlib import Path

def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"replacement target not found: {label}")
    return text.replace(old, new, 1)

plan = Path("scripts/media/library/plan-music-staging-beets-mbid-dry-run.sh")
apply = Path("scripts/media/library/apply-music-staging-beets-mbid-dry-run.sh")
validate = Path("scripts/media/library/validate-music-staging-beets-mbid-dry-run.sh")

# PLAN SCRIPT
text = plan.read_text()

text = replace_once(
    text,
    '''STAGING_DIR="/srv/media/music-staging/reviewing"
DEFAULT_ALBUM="$STAGING_DIR/[1971] Thembi"
DEFAULT_MBID="34497839-9158-4c6f-8945-7f543276ea3e"
DEFAULT_EXPECTED_ARTIST="Pharoah Sanders"
DEFAULT_EXPECTED_ALBUM="Thembi"

ALBUM_DIR="${1:-$DEFAULT_ALBUM}"
MBID="${2:-$DEFAULT_MBID}"
EXPECTED_ARTIST="${3:-$DEFAULT_EXPECTED_ARTIST}"
EXPECTED_ALBUM="${4:-$DEFAULT_EXPECTED_ALBUM}"
''',
    '''ALBUM_DIR="${1:-}"
MBID="${2:-}"
EXPECTED_ARTIST="${3:-}"
EXPECTED_ALBUM="${4:-}"
''',
    "plan defaults block",
)

text = replace_once(
    text,
    '''main() {
  local beets_command

  require_lib_contract

  mkdir -p "$REPORT_DIR" "$PLAN_DIR"

  if [ ! -d "$ALBUM_DIR" ]; then
    fail "Album directory not found: $ALBUM_DIR"
  fi
''',
    '''usage() {
  cat <<'EOF'
Usage:
  plan-music-staging-beets-mbid-dry-run.sh <album_dir> <mbid> <expected_artist> <expected_album>

Safety:
  Plan only. Does not run Beets, write tags, copy files, move files or modify staging/library.
EOF
}

validate_args() {
  if [ -z "$ALBUM_DIR" ] || [ -z "$MBID" ] || [ -z "$EXPECTED_ARTIST" ] || [ -z "$EXPECTED_ALBUM" ]; then
    usage >&2
    fail "Missing required arguments."
  fi
}

main() {
  local beets_command

  require_lib_contract
  validate_args

  mkdir -p "$REPORT_DIR" "$PLAN_DIR"

  if [ ! -d "$ALBUM_DIR" ]; then
    fail "Album directory not found: $ALBUM_DIR"
  fi
''',
    "plan main args",
)

plan.write_text(text)

# APPLY SCRIPT
text = apply.read_text()

text = replace_once(
    text,
    '''STAGING_DIR="/srv/media/music-staging/reviewing"
DEFAULT_ALBUM="$STAGING_DIR/[1971] Thembi"
DEFAULT_MBID="34497839-9158-4c6f-8945-7f543276ea3e"
DEFAULT_EXPECTED_ARTIST="Pharoah Sanders"
DEFAULT_EXPECTED_ALBUM="Thembi"

APPLY_MODE="${1:-}"
ALBUM_DIR="${2:-$DEFAULT_ALBUM}"
MBID="${3:-$DEFAULT_MBID}"
EXPECTED_ARTIST="${4:-$DEFAULT_EXPECTED_ARTIST}"
EXPECTED_ALBUM="${5:-$DEFAULT_EXPECTED_ALBUM}"
''',
    '''APPLY_MODE="${1:-}"
ALBUM_DIR="${2:-}"
MBID="${3:-}"
EXPECTED_ARTIST="${4:-}"
EXPECTED_ALBUM="${5:-}"
''',
    "apply defaults block",
)

text = replace_once(
    text,
    '''write_step() {
  local step_id="$1"
  local phase="$2"
  local target="$3"
  local status="$4"
  local action="$5"
  local notes="$6"

  tsv_row "$step_id" "$phase" "$target" "$status" "$action" "$notes" >> "$TSV"
}

confirm_apply() {
''',
    '''write_step() {
  local step_id="$1"
  local phase="$2"
  local target="$3"
  local status="$4"
  local action="$5"
  local notes="$6"

  tsv_row "$step_id" "$phase" "$target" "$status" "$action" "$notes" >> "$TSV"
}

usage() {
  cat <<'EOF'
Usage:
  apply-music-staging-beets-mbid-dry-run.sh --apply <album_dir> <mbid> <expected_artist> <expected_album>

Safety:
  Runs Beets with -C -W inside isolated BEETSDIR sandbox.
  Does not intentionally write tags, copy files, move files or modify /srv/media/music.
EOF
}

validate_args() {
  if [ "$APPLY_MODE" != "--apply" ] || [ -z "$ALBUM_DIR" ] || [ -z "$MBID" ] || [ -z "$EXPECTED_ARTIST" ] || [ -z "$EXPECTED_ALBUM" ]; then
    usage >&2
    fail "Missing required arguments."
  fi
}

confirm_apply() {
''',
    "apply usage insertion",
)

text = replace_once(
    text,
    '''  if [ "$APPLY_MODE" != "--apply" ]; then
    fail "This script runs an interactive Beets MBID dry-run. Re-run with: apply-music-staging-beets-mbid-dry-run.sh --apply [album_dir] [mbid] [expected_artist] [expected_album]"
  fi

  printf '%s\\n' "This script will run an interactive Beets MBID dry-run:"
''',
    '''  validate_args

  printf '%s\\n' "This script will run an interactive Beets MBID dry-run:"
''',
    "apply confirm args",
)

apply.write_text(text)

# VALIDATE SCRIPT
text = validate.read_text()

text = replace_once(
    text,
    '''STAGING_DIR="/srv/media/music-staging/reviewing"
DEFAULT_ALBUM="$STAGING_DIR/[1971] Thembi"
DEFAULT_MBID="34497839-9158-4c6f-8945-7f543276ea3e"
DEFAULT_EXPECTED_ARTIST="Pharoah Sanders"
DEFAULT_EXPECTED_ALBUM="Thembi"
DEFAULT_MATCH_MIN="80"
DEFAULT_DISTANCE_MAX=""

ALBUM_DIR="${1:-$DEFAULT_ALBUM}"
EXPECTED_MBID="${2:-$DEFAULT_MBID}"
EXPECTED_ARTIST="${3:-$DEFAULT_EXPECTED_ARTIST}"
EXPECTED_ALBUM="${4:-$DEFAULT_EXPECTED_ALBUM}"
EXPECTED_MATCH_MIN="${5:-$DEFAULT_MATCH_MIN}"
EXPECTED_DISTANCE_MAX="${6:-$DEFAULT_DISTANCE_MAX}"
''',
    '''ALBUM_DIR="${1:-}"
EXPECTED_MBID="${2:-}"
EXPECTED_ARTIST="${3:-}"
EXPECTED_ALBUM="${4:-}"
EXPECTED_MATCH_MIN="${5:-80}"
EXPECTED_DISTANCE_MAX="${6:-}"
''',
    "validate defaults block",
)

text = replace_once(
    text,
    '''append_file_excerpt() {
  local title="$1"
  local file="$2"

  {
    printf '\\n'
    printf '## %s\\n' "$title"
    printf '\\n'
    printf '%s\\n' '```text'
    if [ -n "$file" ] && [ -f "$file" ]; then
      cat "$file"
    else
      printf 'missing: %s\\n' "$file"
    fi
    printf '%s\\n' '```'
  } >> "$REPORT"
}

extract_match_percent() {
''',
    '''append_file_excerpt() {
  local title="$1"
  local file="$2"

  {
    printf '\\n'
    printf '## %s\\n' "$title"
    printf '\\n'
    printf '%s\\n' '```text'
    if [ -n "$file" ] && [ -f "$file" ]; then
      cat "$file"
    else
      printf 'missing: %s\\n' "$file"
    fi
    printf '%s\\n' '```'
  } >> "$REPORT"
}

usage() {
  cat <<'EOF'
Usage:
  validate-music-staging-beets-mbid-dry-run.sh <album_dir> <mbid> <expected_artist> <expected_album> [expected_match_min] [expected_distance_max]

Safety:
  Validation only. Does not run Beets, write tags, copy files, move files or modify staging/library.
EOF
}

validate_args() {
  if [ -z "$ALBUM_DIR" ] || [ -z "$EXPECTED_MBID" ] || [ -z "$EXPECTED_ARTIST" ] || [ -z "$EXPECTED_ALBUM" ]; then
    usage >&2
    fail "Missing required arguments."
  fi
}

extract_match_percent() {
''',
    "validate usage insertion",
)

text = replace_once(
    text,
    '''  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting Beets MBID dry-run validation."
''',
    '''  require_lib_contract
  validate_args

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting Beets MBID dry-run validation."
''',
    "validate main args",
)

validate.write_text(text)
PY
}

validate_scripts() {
  local script
  local failures=0

  for script in "$PLAN_SCRIPT" "$APPLY_SCRIPT" "$VALIDATE_SCRIPT"; do
    if bash -n "$script"; then
      write_step "VALIDATE" "bash-n" "$script" "OK" "bash -n passed" ""
    else
      write_step "VALIDATE" "bash-n" "$script" "FAIL" "bash -n failed" ""
      failures=$((failures + 1))
    fi
  done

  if [ "$failures" -gt 0 ]; then
    return 1
  fi

  return 0
}

check_forbidden_patterns() {
  local script
  local pattern
  local matches
  local failures=0

  for script in "$PLAN_SCRIPT" "$APPLY_SCRIPT" "$VALIDATE_SCRIPT"; do
    for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
      matches="$(grep -nF "$pattern" "$script" 2>/dev/null || true)"

      if [ -n "$matches" ]; then
        write_step "FORBIDDEN" "validate" "$script" "FAIL" "forbidden album-specific reference found" "$pattern at $(printf '%s' "$matches" | cut -d: -f1 | paste -sd ',' -)"
        failures=$((failures + 1))
      else
        write_step "FORBIDDEN" "validate" "$script" "OK" "forbidden pattern absent" "$pattern"
      fi
    done
  done

  if [ "$failures" -gt 0 ]; then
    return 1
  fi

  return 0
}

main() {
  require_lib_contract
  confirm_apply

  mkdir -p "$REPORT_DIR" "$RAW_DIR" "$SNAPSHOT_DIR"

  tsv_row \
    "step_id" \
    "phase" \
    "target" \
    "status" \
    "action" \
    "notes" > "$TSV"

  {
    printf '%s\n' '# Beets MBID Workflow Remove Album Defaults Apply'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Snapshot dir: %s\n' "$SNAPSHOT_DIR"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: edits scripts only. Does not run Beets, write tags, copy files or move files.'
    printf '\n'
  } > "$REPORT"

  log "Starting Beets MBID workflow remove album defaults apply."

  backup_file "$PLAN_SCRIPT"
  backup_file "$APPLY_SCRIPT"
  backup_file "$VALIDATE_SCRIPT"

  apply_python_patch
  write_step "APPLY-001" "apply" "$PLAN_SCRIPT" "OK" "removed album-specific defaults and made args mandatory" ""
  write_step "APPLY-002" "apply" "$APPLY_SCRIPT" "OK" "removed album-specific defaults and made args mandatory" ""
  write_step "APPLY-003" "apply" "$VALIDATE_SCRIPT" "OK" "removed album-specific defaults and made args mandatory" ""

  if validate_scripts; then
    write_step "VALIDATE-SUMMARY" "validate" "target scripts" "OK" "all target scripts passed bash -n" ""
  else
    write_step "VALIDATE-SUMMARY" "validate" "target scripts" "FAIL" "one or more scripts failed bash -n" ""
    fail "bash -n validation failed. Backups are in: $SNAPSHOT_DIR"
  fi

  if check_forbidden_patterns; then
    write_step "FORBIDDEN-SUMMARY" "validate" "target scripts" "OK" "no forbidden album-specific references found" ""
  else
    write_step "FORBIDDEN-SUMMARY" "validate" "target scripts" "FAIL" "forbidden album-specific references remain" ""
    fail "Forbidden album-specific references remain. Backups are in: $SNAPSHOT_DIR"
  fi

  {
    printf '%s\n' '## Applied changes'
    printf '\n'
    printf '%s\n' '- Removed album-specific defaults from MBID dry-run workflow scripts.'
    printf '%s\n' '- album_dir, MBID, expected_artist and expected_album are now mandatory.'
    printf '%s\n' '- Preserved -C -W and sandbox safety policy.'
    printf '%s\n' '- Verified target scripts with bash -n.'
    printf '%s\n' '- Verified forbidden album-specific references are absent.'
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
    printf '%s\n' "- Snapshot dir: $SNAPSHOT_DIR"
  } >> "$REPORT"

  log "Beets MBID workflow remove album defaults apply completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
  log "Snapshot dir: $SNAPSHOT_DIR"
}

main "$@"
