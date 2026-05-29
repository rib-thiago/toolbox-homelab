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
SNAPSHOT_DIR="$SHARED_DIR/library-db/snapshots/media/staging/beets-mbid-generalization-$STAMP"

REPORT="$REPORT_DIR/beets_mbid_workflow_generalization_apply_report_$STAMP.txt"
TSV="$RAW_DIR/beets_mbid_workflow_generalization_apply_$STAMP.tsv"

APPLY_MODE="${1:-}"

PLAN_SCRIPT="scripts/media/library/plan-music-staging-beets-mbid-dry-run.sh"
APPLY_SCRIPT="scripts/media/library/apply-music-staging-beets-mbid-dry-run.sh"
VALIDATE_SCRIPT="scripts/media/library/validate-music-staging-beets-mbid-dry-run.sh"

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
    fail "This script edits MBID workflow scripts. Re-run with: apply-beets-mbid-workflow-generalization.sh --apply"
  fi

  printf '%s\n' "This script will generalize the Beets MBID dry-run workflow:"
  printf '%s\n' "- $PLAN_SCRIPT"
  printf '%s\n' "- $APPLY_SCRIPT"
  printf '%s\n' "- $VALIDATE_SCRIPT"
  printf '%s\n' "Backups will be written to:"
  printf '%s\n' "- $SNAPSHOT_DIR"
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

write_plan_script() {
  cat > "$PLAN_SCRIPT" <<'EOF'
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

STAGING_DIR="/srv/media/music-staging/reviewing"
DEFAULT_ALBUM="$STAGING_DIR/[1971] Thembi"
DEFAULT_MBID="34497839-9158-4c6f-8945-7f543276ea3e"
DEFAULT_EXPECTED_ARTIST="Pharoah Sanders"
DEFAULT_EXPECTED_ALBUM="Thembi"

ALBUM_DIR="${1:-$DEFAULT_ALBUM}"
MBID="${2:-$DEFAULT_MBID}"
EXPECTED_ARTIST="${3:-$DEFAULT_EXPECTED_ARTIST}"
EXPECTED_ALBUM="${4:-$DEFAULT_EXPECTED_ALBUM}"

ALBUM_NAME="$(basename "$ALBUM_DIR")"
SAFE_ALBUM_NAME="$(printf '%s' "$ALBUM_NAME" | tr ' /[]()' '_______' | tr -cd '[:alnum:]_.-')"

BEETS_SANDBOX_ROOT="$SHARED_DIR/beets/media-staging"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
PLAN_DIR="$SHARED_DIR/library-db/plans/media/staging"

REPORT="$REPORT_DIR/music_staging_beets_mbid_dry_run_plan_${SAFE_ALBUM_NAME}_report_$STAMP.txt"
TSV="$PLAN_DIR/music_staging_beets_mbid_dry_run_plan_${SAFE_ALBUM_NAME}_$STAMP.tsv"

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

shell_quote_arg() {
  local value="$1"

  printf '%q' "$value"
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
  local beets_command

  require_lib_contract

  mkdir -p "$REPORT_DIR" "$PLAN_DIR"

  if [ ! -d "$ALBUM_DIR" ]; then
    fail "Album directory not found: $ALBUM_DIR"
  fi

  if [ ! -d "$BEETS_SANDBOX_ROOT" ]; then
    fail "Beets sandbox root not found: $BEETS_SANDBOX_ROOT"
  fi

  log "Generating Beets MBID dry-run plan."

  beets_command="BEETSDIR=$(shell_quote_arg "$BEETS_SANDBOX_ROOT") beet import -C -W $(shell_quote_arg "$ALBUM_DIR")"

  tsv_row \
    "step_id" \
    "phase" \
    "target" \
    "status" \
    "action" \
    "notes" > "$TSV"

  write_step "PLAN-001" "album" "$ALBUM_DIR" "OK" "selected album" "$ALBUM_NAME"
  write_step "PLAN-002" "mbid" "$MBID" "OK" "selected MusicBrainz release candidate" "expected_artist=$EXPECTED_ARTIST expected_album=$EXPECTED_ALBUM"
  write_step "PLAN-003" "safety" "$BEETS_SANDBOX_ROOT" "OK" "sandbox dry-run only" "use -C -W; config has copy/write/move disabled"
  write_step "PLAN-004" "command" "$ALBUM_DIR" "PLANNED" "run beet import -C -W" "$beets_command"
  write_step "PLAN-005" "interactive" "beets prompt" "PLANNED" "choose enter Id and paste MBID" "$MBID"

  {
    printf '%s\n' '# Music Staging Beets MBID Dry-run Plan'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Album directory: %s\n' "$ALBUM_DIR"
    printf 'Album name: %s\n' "$ALBUM_NAME"
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf 'Selected MBID: %s\n' "$MBID"
    printf 'Beets sandbox root: %s\n' "$BEETS_SANDBOX_ROOT"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: plan only. This script does not run Beets, write tags, copy files, move files or modify staging/library.'
    printf '\n'

    printf '%s\n' '## Evidence'
    printf '\n'
    printf '%s\n' '- Album tag diagnosis should be complete before this step.'
    printf '%s\n' '- MusicBrainz release candidate diagnosis should provide the selected MBID.'
    printf '%s\n' '- This plan prepares only a sandboxed Beets dry-run.'
    printf '\n'

    printf '%s\n' '## Planned command'
    printf '\n'
    printf '%s\n' '```bash'
    printf '%s\n' "$beets_command"
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' '## Interactive Beets action'
    printf '\n'
    printf '%s\n' '```text'
    printf '%s\n' 'At prompt, choose: enter Id'
    printf 'Paste MBID: %s\n' "$MBID"
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf '%s\n' 'Inspect proposed match before accepting.'
    printf '%s\n' '```'
    printf '\n'

    printf '%s\n' '## Decision rules'
    printf '\n'
    printf '%s\n' "- Accept only if Beets shows the expected artist/album and coherent track mapping."
    printf '%s\n' "- Expected artist: $EXPECTED_ARTIST"
    printf '%s\n' "- Expected album: $EXPECTED_ALBUM"
    printf '%s\n' '- Do not use Use as-is.'
    printf '%s\n' '- Do not remove -C or -W.'
    printf '%s\n' '- This remains evidence gathering, not final import/tagging.'
    printf '\n'

    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } > "$REPORT"

  log "Beets MBID dry-run plan generated."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
EOF
}

write_apply_script() {
  cat > "$APPLY_SCRIPT" <<'EOF'
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

STAGING_DIR="/srv/media/music-staging/reviewing"
DEFAULT_ALBUM="$STAGING_DIR/[1971] Thembi"
DEFAULT_MBID="34497839-9158-4c6f-8945-7f543276ea3e"
DEFAULT_EXPECTED_ARTIST="Pharoah Sanders"
DEFAULT_EXPECTED_ALBUM="Thembi"

APPLY_MODE="${1:-}"
ALBUM_DIR="${2:-$DEFAULT_ALBUM}"
MBID="${3:-$DEFAULT_MBID}"
EXPECTED_ARTIST="${4:-$DEFAULT_EXPECTED_ARTIST}"
EXPECTED_ALBUM="${5:-$DEFAULT_EXPECTED_ALBUM}"

ALBUM_NAME="$(basename "$ALBUM_DIR")"
SAFE_ALBUM_NAME="$(printf '%s' "$ALBUM_NAME" | tr ' /[]()' '_______' | tr -cd '[:alnum:]_.-')"

BEETS_SANDBOX_ROOT="$SHARED_DIR/beets/media-staging"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"

REPORT="$REPORT_DIR/music_staging_beets_mbid_dry_run_apply_${SAFE_ALBUM_NAME}_report_$STAMP.txt"
TSV="$RAW_DIR/music_staging_beets_mbid_dry_run_apply_${SAFE_ALBUM_NAME}_$STAMP.tsv"
LIVE_LOG="$REPORT_DIR/beets_mbid_dry_run_${SAFE_ALBUM_NAME}_live_$STAMP.log"

ERROR_PATTERNS='error loading plugin|PluginImportError|ModuleNotFoundError|Could not import plugin|No module named|Traceback'
NO_MATCH_PATTERNS='No matching release found|No matching release'

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
    fail "This script runs an interactive Beets MBID dry-run. Re-run with: apply-music-staging-beets-mbid-dry-run.sh --apply [album_dir] [mbid] [expected_artist] [expected_album]"
  fi

  printf '%s\n' "This script will run an interactive Beets MBID dry-run:"
  printf '%s\n' "- Album: $ALBUM_DIR"
  printf '%s\n' "- MBID: $MBID"
  printf '%s\n' "- Expected artist: $EXPECTED_ARTIST"
  printf '%s\n' "- Expected album: $EXPECTED_ALBUM"
  printf '%s\n' "- BEETSDIR: $BEETS_SANDBOX_ROOT"
  printf '%s\n' "- Command: beet import -C -W"
  printf '%s\n' "- Live log: $LIVE_LOG"
  printf '%s\n' "At the Beets prompt, choose: enter Id"
  printf '%s\n' "Then paste: $MBID"
  printf '%s\n' "Do not use Use as-is. Do not remove -C or -W."
  printf '%s\n' "It should not write tags, copy files, move files, or modify /srv/media/music."
  printf '%s\n' "It may update the isolated Beets sandbox database."
  printf '%s' "Type APPLY to continue: "
  read -r confirmation

  if [ "$confirmation" != "APPLY" ]; then
    fail "Apply aborted by user."
  fi
}

main() {
  local beet_status
  local fail_count
  local warn_count
  local found_errors
  local found_no_match
  local found_match_markers

  require_lib_contract
  confirm_apply

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting Beets MBID dry-run apply."

  tsv_row \
    "step_id" \
    "phase" \
    "target" \
    "status" \
    "action" \
    "notes" > "$TSV"

  {
    printf '%s\n' '# Music Staging Beets MBID Dry-run Apply'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Album directory: %s\n' "$ALBUM_DIR"
    printf 'Album name: %s\n' "$ALBUM_NAME"
    printf 'MBID: %s\n' "$MBID"
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf 'BEETSDIR: %s\n' "$BEETS_SANDBOX_ROOT"
    printf 'Live log: %s\n' "$LIVE_LOG"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: runs beet import with -C -W inside isolated BEETSDIR sandbox.'
    printf '%s\n' 'This script does not intentionally write tags, copy files, move files, or modify /srv/media/music.'
    printf '\n'
  } > "$REPORT"

  if [ -d "$ALBUM_DIR" ]; then
    write_step "PRE-001" "preflight" "$ALBUM_DIR" "OK" "album directory exists" ""
  else
    write_step "PRE-001" "preflight" "$ALBUM_DIR" "FAIL" "album directory missing" ""
  fi

  if [ -d "$BEETS_SANDBOX_ROOT" ]; then
    write_step "PRE-002" "preflight" "$BEETS_SANDBOX_ROOT" "OK" "Beets sandbox exists" ""
  else
    write_step "PRE-002" "preflight" "$BEETS_SANDBOX_ROOT" "FAIL" "Beets sandbox missing" ""
  fi

  if command -v beet >/dev/null 2>&1; then
    write_step "PRE-003" "preflight" "beet" "OK" "beet command found" "$(command -v beet)"
  else
    write_step "PRE-003" "preflight" "beet" "FAIL" "beet command missing" ""
  fi

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$TSV")"

  if [ "$fail_count" -gt 0 ]; then
    log "Preflight failed."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  {
    printf '%s\n' '## Beets command'
    printf '\n'
    printf '%s\n' '```bash'
    printf 'BEETSDIR=%q beet import -C -W %q\n' "$BEETS_SANDBOX_ROOT" "$ALBUM_DIR"
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Required interactive action'
    printf '\n'
    printf '%s\n' '```text'
    printf '%s\n' 'At prompt, choose: enter Id'
    printf 'Paste MBID: %s\n' "$MBID"
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf '%s\n' 'Inspect the proposed match before accepting.'
    printf '%s\n' '```'
    printf '\n'
    printf '%s\n' '## Live output'
    printf '\n'
    printf '%s\n' '```text'
  } >> "$REPORT"

  printf '%s\n' "Running Beets MBID dry-run. Interact with beet normally."
  printf '%s\n' "At prompt: choose enter Id, paste $MBID"
  printf '%s\n' "Expected: $EXPECTED_ARTIST - $EXPECTED_ALBUM"
  printf '%s\n' "Log: $LIVE_LOG"

  set +e
  env "BEETSDIR=$BEETS_SANDBOX_ROOT" beet import -C -W "$ALBUM_DIR" 2>&1 | tee "$LIVE_LOG"
  beet_status="${PIPESTATUS[0]}"
  set -e

  cat "$LIVE_LOG" >> "$REPORT"

  {
    printf '%s\n' '```'
    printf '\n'
  } >> "$REPORT"

  if [ "$beet_status" -eq 0 ]; then
    write_step "RUN-001" "run" "$ALBUM_DIR" "OK" "beet import -C -W returned success" "$LIVE_LOG"
  else
    write_step "RUN-001" "run" "$ALBUM_DIR" "WARN" "beet import -C -W returned non-zero" "exit=$beet_status log=$LIVE_LOG"
  fi

  found_errors="$(grep -Ei "$ERROR_PATTERNS" "$LIVE_LOG" || true)"
  if [ -z "$found_errors" ]; then
    write_step "VAL-001" "validate" "$LIVE_LOG" "OK" "no plugin/runtime errors detected" ""
  else
    write_step "VAL-001" "validate" "$LIVE_LOG" "FAIL" "plugin/runtime errors detected" "$found_errors"
  fi

  found_no_match="$(grep -Ei "$NO_MATCH_PATTERNS" "$LIVE_LOG" || true)"
  if [ -z "$found_no_match" ]; then
    write_step "VAL-002" "validate" "$LIVE_LOG" "OK" "no MusicBrainz no-match detected" ""
  else
    write_step "VAL-002" "validate" "$LIVE_LOG" "WARN" "MusicBrainz no-match detected" "$found_no_match"
  fi

  found_match_markers="$(grep -Ei "$MBID|$EXPECTED_ARTIST|$EXPECTED_ALBUM" "$LIVE_LOG" || true)"
  if [ -n "$found_match_markers" ]; then
    write_step "VAL-003" "validate" "$LIVE_LOG" "OK" "expected match markers detected" "$found_match_markers"
  else
    write_step "VAL-003" "validate" "$LIVE_LOG" "WARN" "expected match markers not detected" "expected=$EXPECTED_ARTIST / $EXPECTED_ALBUM / $MBID"
  fi

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$TSV")"
  warn_count="$(awk -F '\t' 'NR > 1 && $4 == "WARN" { c++ } END { print c+0 }' "$TSV")"

  {
    printf '%s\n' '## Summary'
    printf '\n'
    printf 'Beet exit status: %s\n' "$beet_status"
    printf 'Failures: %s\n' "$fail_count"
    printf 'Warnings: %s\n' "$warn_count"
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
    printf '%s\n' "- Live log: $LIVE_LOG"
  } >> "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    log "Beets MBID dry-run apply completed with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    log "Live log: $LIVE_LOG"
    exit 1
  fi

  log "Beets MBID dry-run apply completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
  log "Live log: $LIVE_LOG"
}

main "$@"
EOF
}

write_validate_script() {
  cat > "$VALIDATE_SCRIPT" <<'EOF'
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

STAGING_DIR="/srv/media/music-staging/reviewing"
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

ALBUM_NAME="$(basename "$ALBUM_DIR")"
SAFE_ALBUM_NAME="$(printf '%s' "$ALBUM_NAME" | tr ' /[]()' '_______' | tr -cd '[:alnum:]_.-')"

REPORT_DIR="$SHARED_DIR/reports/media/staging"
RAW_DIR="$SHARED_DIR/library-db/raw/media/staging"

REPORT="$REPORT_DIR/music_staging_beets_mbid_dry_run_validation_${SAFE_ALBUM_NAME}_report_$STAMP.txt"
TSV="$RAW_DIR/music_staging_beets_mbid_dry_run_validation_${SAFE_ALBUM_NAME}_$STAMP.tsv"

ERROR_PATTERNS='error loading plugin|PluginImportError|ModuleNotFoundError|Could not import plugin|No module named|Traceback'

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

latest_file() {
  local dir="$1"
  local pattern="$2"

  find "$dir" -maxdepth 1 -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | head -n 1 \
    | cut -d' ' -f2-
}

write_check() {
  local check_id="$1"
  local category="$2"
  local target="$3"
  local status="$4"
  local message="$5"
  local details="$6"

  tsv_row "$check_id" "$category" "$target" "$status" "$message" "$details" >> "$TSV"
}

check_contains_fixed() {
  local check_id="$1"
  local category="$2"
  local file="$3"
  local expected="$4"
  local message="$5"

  if grep -F "$expected" "$file" >/dev/null 2>&1; then
    write_check "$check_id" "$category" "$file" "OK" "$message" "$expected"
  else
    write_check "$check_id" "$category" "$file" "FAIL" "$message not found" "$expected"
  fi
}

check_contains_regex() {
  local check_id="$1"
  local category="$2"
  local file="$3"
  local pattern="$4"
  local message="$5"

  if grep -Ei "$pattern" "$file" >/dev/null 2>&1; then
    write_check "$check_id" "$category" "$file" "OK" "$message" "$pattern"
  else
    write_check "$check_id" "$category" "$file" "FAIL" "$message not found" "$pattern"
  fi
}

check_not_contains_regex() {
  local check_id="$1"
  local category="$2"
  local file="$3"
  local pattern="$4"
  local message="$5"
  local found

  found="$(grep -Ei "$pattern" "$file" 2>/dev/null || true)"

  if [ -z "$found" ]; then
    write_check "$check_id" "$category" "$file" "OK" "$message" ""
  else
    write_check "$check_id" "$category" "$file" "FAIL" "$message failed" "$found"
  fi
}

append_file_excerpt() {
  local title="$1"
  local file="$2"

  {
    printf '\n'
    printf '## %s\n' "$title"
    printf '\n'
    printf '%s\n' '```text'
    if [ -n "$file" ] && [ -f "$file" ]; then
      cat "$file"
    else
      printf 'missing: %s\n' "$file"
    fi
    printf '%s\n' '```'
  } >> "$REPORT"
}

extract_match_percent() {
  local file="$1"

  grep -Eo 'Match \([^)]*%[^)]*\)' "$file" 2>/dev/null \
    | tail -n 1 \
    | sed -E 's/.*\(([0-9]+([.][0-9]+)?)%.*/\1/' \
    || true
}

validate_match_threshold() {
  local file="$1"
  local match_percent

  match_percent="$(extract_match_percent "$file")"

  if [ -z "$match_percent" ]; then
    write_check "MATCH-THRESHOLD" "match" "$file" "WARN" "match percentage not detected" ""
    return 0
  fi

  if awk -v got="$match_percent" -v min="$EXPECTED_MATCH_MIN" 'BEGIN { exit (got >= min) ? 0 : 1 }'; then
    write_check "MATCH-THRESHOLD" "match" "$file" "OK" "match percentage meets threshold" "got=$match_percent min=$EXPECTED_MATCH_MIN"
  else
    write_check "MATCH-THRESHOLD" "match" "$file" "FAIL" "match percentage below threshold" "got=$match_percent min=$EXPECTED_MATCH_MIN"
  fi
}

main() {
  local latest_apply_tsv
  local latest_apply_report
  local latest_live_log
  local latest_debug_log
  local evidence_log
  local fail_count
  local warn_count

  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting Beets MBID dry-run validation."

  latest_apply_tsv="$(latest_file "$RAW_DIR" "music_staging_beets_mbid_dry_run_apply_${SAFE_ALBUM_NAME}_*.tsv")"
  latest_apply_report="$(latest_file "$REPORT_DIR" "music_staging_beets_mbid_dry_run_apply_${SAFE_ALBUM_NAME}_report_*.txt")"
  latest_live_log="$(latest_file "$REPORT_DIR" "beets_mbid_dry_run_${SAFE_ALBUM_NAME}_live_*.log")"
  latest_debug_log="$(latest_file "$REPORT_DIR" "beets_mbid_debug_${SAFE_ALBUM_NAME}_*.log")"

  if [ -n "$latest_debug_log" ] && [ -f "$latest_debug_log" ]; then
    evidence_log="$latest_debug_log"
  else
    evidence_log="$latest_live_log"
  fi

  tsv_row \
    "check_id" \
    "category" \
    "target" \
    "status" \
    "message" \
    "details" > "$TSV"

  {
    printf '%s\n' '# Music Staging Beets MBID Dry-run Validation'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Album directory: %s\n' "$ALBUM_DIR"
    printf 'Album name: %s\n' "$ALBUM_NAME"
    printf 'Expected MBID: %s\n' "$EXPECTED_MBID"
    printf 'Expected artist: %s\n' "$EXPECTED_ARTIST"
    printf 'Expected album: %s\n' "$EXPECTED_ALBUM"
    printf 'Expected match min: %s\n' "$EXPECTED_MATCH_MIN"
    printf 'Expected distance max: %s\n' "$EXPECTED_DISTANCE_MAX"
    printf 'Latest apply TSV: %s\n' "$latest_apply_tsv"
    printf 'Latest apply report: %s\n' "$latest_apply_report"
    printf 'Latest live log: %s\n' "$latest_live_log"
    printf 'Latest debug log: %s\n' "$latest_debug_log"
    printf 'Evidence log used: %s\n' "$evidence_log"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: validation only. This script does not run Beets, write tags, copy files, move files or modify staging/library.'
    printf '\n'
  } > "$REPORT"

  if [ -n "$latest_apply_tsv" ] && [ -f "$latest_apply_tsv" ]; then
    write_check "FILE-001" "file" "$latest_apply_tsv" "OK" "latest apply TSV exists" ""
  else
    write_check "FILE-001" "file" "$latest_apply_tsv" "WARN" "latest apply TSV missing" ""
  fi

  if [ -n "$latest_apply_report" ] && [ -f "$latest_apply_report" ]; then
    write_check "FILE-002" "file" "$latest_apply_report" "OK" "latest apply report exists" ""
  else
    write_check "FILE-002" "file" "$latest_apply_report" "WARN" "latest apply report missing" ""
  fi

  if [ -n "$evidence_log" ] && [ -f "$evidence_log" ]; then
    write_check "FILE-003" "file" "$evidence_log" "OK" "evidence log exists" ""
  else
    write_check "FILE-003" "file" "$evidence_log" "FAIL" "evidence log missing" ""
  fi

  if [ -n "$evidence_log" ] && [ -f "$evidence_log" ]; then
    check_not_contains_regex "RUN-001" "runtime" "$evidence_log" "$ERROR_PATTERNS" "no plugin/runtime errors detected"
    check_contains_fixed "PLG-001" "plugins" "$evidence_log" "Loading plugins: chroma, musicbrainz" "chroma and musicbrainz loaded"
    check_contains_fixed "MB-001" "musicbrainz" "$evidence_log" "$EXPECTED_MBID" "expected MBID detected"
    check_contains_fixed "MB-002" "musicbrainz" "$evidence_log" "$EXPECTED_ARTIST" "expected artist detected"
    check_contains_fixed "MB-003" "musicbrainz" "$evidence_log" "$EXPECTED_ALBUM" "expected album detected"
    check_contains_regex "MB-004" "musicbrainz" "$evidence_log" "Evaluating [0-9]+ candidates" "candidate evaluation happened"
    check_contains_regex "MATCH-001" "match" "$evidence_log" "Match .*%" "match percentage found"
    validate_match_threshold "$evidence_log"
  fi

  append_file_excerpt "Evidence log" "$evidence_log"
  append_file_excerpt "Latest apply TSV" "$latest_apply_tsv"

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "FAIL" { c++ } END { print c+0 }' "$TSV")"
  warn_count="$(awk -F '\t' 'NR > 1 && $4 == "WARN" { c++ } END { print c+0 }' "$TSV")"

  {
    printf '\n'
    printf '%s\n' '## Summary'
    printf '\n'
    printf 'Failures: %s\n' "$fail_count"
    printf 'Warnings: %s\n' "$warn_count"
    printf '\n'
    if [ "$fail_count" -gt 0 ]; then
      printf '%s\n' 'Interpretation: MBID dry-run validation failed.'
    else
      printf '%s\n' 'Interpretation: MBID dry-run validation passed for the supplied album/artist/MBID parameters.'
    fi
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    log "Beets MBID dry-run validation completed with failures."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  log "Beets MBID dry-run validation passed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
EOF
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
    printf '%s\n' '# Beets MBID Workflow Generalization Apply'
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

  log "Starting Beets MBID workflow generalization apply."

  backup_file "$PLAN_SCRIPT"
  backup_file "$APPLY_SCRIPT"
  backup_file "$VALIDATE_SCRIPT"

  write_plan_script
  write_step "APPLY-001" "apply" "$PLAN_SCRIPT" "OK" "rewrote generalized plan script" ""

  write_apply_script
  write_step "APPLY-002" "apply" "$APPLY_SCRIPT" "OK" "rewrote generalized apply script" ""

  write_validate_script
  write_step "APPLY-003" "apply" "$VALIDATE_SCRIPT" "OK" "rewrote generalized validate script" ""

  if validate_scripts; then
    write_step "VALIDATE-SUMMARY" "validate" "target scripts" "OK" "all target scripts passed bash -n" ""
  else
    write_step "VALIDATE-SUMMARY" "validate" "target scripts" "FAIL" "one or more scripts failed bash -n" ""
    fail "Validation failed after apply. Backups are in: $SNAPSHOT_DIR"
  fi

  {
    printf '%s\n' '## Applied changes'
    printf '\n'
    printf '%s\n' '- Generalized plan/apply/validate MBID dry-run scripts.'
    printf '%s\n' '- Added expected_artist and expected_album parameters.'
    printf '%s\n' '- Generalized validation log discovery using SAFE_ALBUM_NAME.'
    printf '%s\n' '- Preserved Thembi defaults for convenience.'
    printf '%s\n' '- Preserved -C -W and sandbox safety policy.'
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
    printf '%s\n' "- Snapshot dir: $SNAPSHOT_DIR"
  } >> "$REPORT"

  log "Beets MBID workflow generalization apply completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
  log "Snapshot dir: $SNAPSHOT_DIR"
}

main "$@"
