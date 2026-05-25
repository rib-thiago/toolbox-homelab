#!/usr/bin/env bash
set -u

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
  log "ERROR: $*" >&2
  exit 1
}

STAMP="$(date +%Y%m%d-%H%M%S)"

TOOLBOX_APP="/srv/toolbox/app"
TOOLBOX_SHARED="/srv/toolbox/shared"

REPORTS_ROOT="/srv/toolbox/shared/reports"
PROVISIONAL_REPORT_DIR="/srv/toolbox/shared/reports/media"

LIBRARY_DB_ROOT="/srv/toolbox/shared/library-db"
PROVISIONAL_RAW_DIR="/srv/toolbox/shared/library-db/raw"
SNAPSHOT_DIR="/srv/toolbox/shared/library-db/snapshots"

SCRIPT_LIB_DIR="/srv/toolbox/app/scripts/lib"
DOCS_OPERATIONS_DIR="/srv/toolbox/app/docs/operations"

select_output_dir() {
  local preferred_dir
  local fallback_dir
  local label

  preferred_dir="$1"
  fallback_dir="$2"
  label="$3"

  if [ -d "$preferred_dir" ] && [ -w "$preferred_dir" ]; then
    printf '%s\n' "$preferred_dir"
    return 0
  fi

  if [ -d "$fallback_dir" ] && [ -w "$fallback_dir" ]; then
    printf '%s\n' "$fallback_dir"
    return 0
  fi

  fail "No writable output directory available for ${label}: preferred=${preferred_dir}, fallback=${fallback_dir}"
}

REPORT_DIR="$(select_output_dir "$PROVISIONAL_REPORT_DIR" "/tmp" "human report")"
RAW_DIR="$(select_output_dir "$PROVISIONAL_RAW_DIR" "/tmp" "structured TSV")"

REPORT_FILE="${REPORT_DIR}/toolbox_output_policy_lib_diagnosis_report_${STAMP}.txt"
TSV_FILE="${RAW_DIR}/toolbox_output_policy_lib_diagnosis_${STAMP}.tsv"

tsv_escape() {
  local raw
  raw="$1"

  raw="${raw//$'\t'/ }"
  raw="${raw//$'\n'/ }"
  raw="${raw//$'\r'/ }"

  printf '%s' "$raw"
}

tsv_row() {
  local category
  local item
  local status
  local row_value

  category="$1"
  item="$2"
  status="$3"
  row_value="$4"

  {
    tsv_escape "$category"
    printf '\t'
    tsv_escape "$item"
    printf '\t'
    tsv_escape "$status"
    printf '\t'
    tsv_escape "$row_value"
    printf '\n'
  } >> "$TSV_FILE"
}

section() {
  local title
  title="$1"

  {
    printf '\n'
    printf '%s\n' '================================================================'
    printf '%s\n' "$title"
    printf '%s\n' '================================================================'
  } >> "$REPORT_FILE"
}

subsection() {
  local title
  title="$1"

  {
    printf '\n'
    printf '%s\n' '----------------------------------------------------------------'
    printf '%s\n' "$title"
    printf '%s\n' '----------------------------------------------------------------'
  } >> "$REPORT_FILE"
}

append_shell() {
  local title
  local cmd
  local rc

  title="$1"
  cmd="$2"

  subsection "$title"
  {
    printf '%s\n\n' "$ $cmd"
  } >> "$REPORT_FILE"

  bash -lc "$cmd" >> "$REPORT_FILE" 2>&1
  rc="$?"

  if [ "$rc" -ne 0 ]; then
    printf '\n[exit_code=%s]\n' "$rc" >> "$REPORT_FILE"
  fi

  return 0
}

dir_state_tsv() {
  local path
  local label
  local details
  local count

  path="$1"
  label="$2"

  if [ -d "$path" ]; then
    details="$(stat -c '%A %U:%G %s bytes %y' "$path" 2>/dev/null || true)"
    count="$(find "$path" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"
    tsv_row "directory" "$label" "exists" "${path} | entries=${count} | ${details}"
  else
    tsv_row "directory" "$label" "missing" "$path"
  fi
}

file_state_tsv() {
  local path
  local label
  local details

  path="$1"
  label="$2"

  if [ -f "$path" ]; then
    details="$(stat -c '%A %U:%G %s bytes %y' "$path" 2>/dev/null || true)"
    tsv_row "file" "$label" "exists" "${path} | ${details}"
  else
    tsv_row "file" "$label" "missing" "$path"
  fi
}

classify_output_file() {
  local path
  local base
  local class

  path="$1"
  base="$(basename "$path")"
  class="other_file"

  case "$path" in
    "$SNAPSHOT_DIR"/*)
      case "$base" in
        *freeze*|*_freeze_*) class="snapshot_or_freeze" ;;
        *.tsv) class="snapshot_tsv" ;;
        *) class="snapshot_other" ;;
      esac
      ;;
    "$PROVISIONAL_RAW_DIR"/*)
      case "$base" in
        *_diagnosis_*.tsv|*_diagnostic_*.tsv) class="raw_diagnosis_tsv" ;;
        *_plan_*.tsv) class="raw_plan_tsv" ;;
        *_apply_*.tsv) class="raw_apply_tsv" ;;
        *_validation_*.tsv) class="raw_validation_tsv" ;;
        *_snapshot_*.tsv|*_freeze_*.tsv) class="raw_snapshot_or_freeze_candidate" ;;
        *.tsv) class="raw_other_tsv" ;;
        *.txt) class="possible_misplaced_text_report_in_raw" ;;
        *.log) class="possible_misplaced_log_in_raw" ;;
        *) class="raw_other_file" ;;
      esac
      ;;
    "$PROVISIONAL_REPORT_DIR"/*)
      case "$base" in
        *_live_*.log|*-live.log|*live*.log) class="media_live_log_or_legacy_live_log" ;;
        *.log) class="media_log" ;;
        *_report_*.txt|*_report.txt) class="media_human_report" ;;
        *.txt) class="media_text_report" ;;
        *.tsv) class="possible_misplaced_tsv_in_reports_media" ;;
        *) class="media_other_file" ;;
      esac
      ;;
    "$REPORTS_ROOT"/*)
      case "$base" in
        *_live_*.log|*-live.log|*live*.log) class="general_live_log_under_reports" ;;
        *.log) class="general_log_under_reports" ;;
        *_report_*.txt|*.txt) class="general_text_report_under_reports" ;;
        *.tsv) class="possible_misplaced_tsv_under_reports" ;;
        *) class="general_other_under_reports" ;;
      esac
      ;;
    "$LIBRARY_DB_ROOT"/*)
      case "$base" in
        *.tsv) class="library_db_tsv_outside_raw_or_snapshots" ;;
        *.sqlite|*.db) class="library_db_database" ;;
        *.txt) class="library_db_text_file" ;;
        *.log) class="library_db_log_file" ;;
        *) class="library_db_other_file" ;;
      esac
      ;;
    "$TOOLBOX_SHARED"/*)
      case "$base" in
        *.tsv) class="shared_tsv_outside_known_output_dirs" ;;
        *.txt) class="shared_text_outside_known_output_dirs" ;;
        *.log) class="shared_log_outside_known_output_dirs" ;;
        *) class="shared_other_file" ;;
      esac
      ;;
  esac

  printf '%s\n' "$class"
}

write_header() {
  {
    printf 'Toolbox output policy and scripts/lib diagnosis\n'
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Toolbox shared: %s\n' "$TOOLBOX_SHARED"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope: diagnose only. No mkdir, no chmod, no mv, no rm, no git writes.\n'
    printf '\n'
    printf 'Important note:\n'
    printf '  This script writes its own artifacts to the current inherited/provisional locations:\n'
    printf '    human report: %s\n' "$REPORT_DIR"
    printf '    structured TSV: %s\n' "$RAW_DIR"
    printf '  This is NOT a final output policy. These locations are being used only to record the diagnosis.\n'
  } > "$REPORT_FILE"

  {
    printf 'category\titem\tstatus\tvalue\n'
  } > "$TSV_FILE"
}

diagnose_git() {
  section "1. GIT STATE OF TOOLBOX"

  if [ ! -d "$TOOLBOX_APP" ]; then
    printf 'Toolbox app directory missing: %s\n' "$TOOLBOX_APP" >> "$REPORT_FILE"
    tsv_row "git" "toolbox_app" "missing" "$TOOLBOX_APP"
    return 0
  fi

  append_shell "Toolbox app directory" "cd '$TOOLBOX_APP' && pwd"
  append_shell "Git repository root" "cd '$TOOLBOX_APP' && git rev-parse --show-toplevel 2>/dev/null || echo NOT_A_GIT_REPO"
  append_shell "Current Git branch" "cd '$TOOLBOX_APP' && git branch --show-current 2>/dev/null || true"
  append_shell "Git status short" "cd '$TOOLBOX_APP' && git status --short 2>/dev/null || true"
  append_shell "Last commits" "cd '$TOOLBOX_APP' && git log --oneline -12 2>/dev/null || true"
  append_shell "Modified files" "cd '$TOOLBOX_APP' && git diff --name-only 2>/dev/null || true"
  append_shell "Staged files" "cd '$TOOLBOX_APP' && git diff --cached --name-only 2>/dev/null || true"
  append_shell "Untracked relevant files" "cd '$TOOLBOX_APP' && git status --short -- 'scripts/**' 'docs/**' '*.sh' 2>/dev/null | sed -n '1,260p' || true"
  append_shell "Nano/editor backup candidates inside repo" "cd '$TOOLBOX_APP' && find . -type f \\( -name '*.save' -o -name '*.save.*' -o -name '*~' -o -name '*.bak' \\) 2>/dev/null | sort || true"

  if git -C "$TOOLBOX_APP" rev-parse --show-toplevel >/dev/null 2>&1; then
    local root
    local branch
    local status_count
    local untracked_count
    local modified_count
    local staged_count

    root="$(git -C "$TOOLBOX_APP" rev-parse --show-toplevel 2>/dev/null || true)"
    branch="$(git -C "$TOOLBOX_APP" branch --show-current 2>/dev/null || true)"
    status_count="$(git -C "$TOOLBOX_APP" status --short 2>/dev/null | wc -l | tr -d ' ')"
    untracked_count="$(git -C "$TOOLBOX_APP" status --short 2>/dev/null | grep -c '^??' 2>/dev/null || true)"
    modified_count="$(git -C "$TOOLBOX_APP" diff --name-only 2>/dev/null | wc -l | tr -d ' ')"
    staged_count="$(git -C "$TOOLBOX_APP" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')"

    tsv_row "git" "repo_root" "exists" "$root"
    tsv_row "git" "branch" "found" "$branch"
    tsv_row "git" "status_entries" "count" "$status_count"
    tsv_row "git" "untracked_entries" "count" "$untracked_count"
    tsv_row "git" "modified_entries" "count" "$modified_count"
    tsv_row "git" "staged_entries" "count" "$staged_count"
  else
    tsv_row "git" "repo" "not_a_repo" "$TOOLBOX_APP"
  fi
}

diagnose_output_dirs() {
  section "2. CURRENT OUTPUT STRUCTURE"

  dir_state_tsv "$TOOLBOX_SHARED" "toolbox_shared"
  dir_state_tsv "$REPORTS_ROOT" "reports_root"
  dir_state_tsv "$PROVISIONAL_REPORT_DIR" "reports_media_current"
  dir_state_tsv "$LIBRARY_DB_ROOT" "library_db_root"
  dir_state_tsv "$PROVISIONAL_RAW_DIR" "library_db_raw_current"
  dir_state_tsv "$SNAPSHOT_DIR" "library_db_snapshots_current"

  append_shell "Top-level directories under /srv/toolbox/shared" "find '$TOOLBOX_SHARED' -maxdepth 3 -type d 2>/dev/null | sort || true"
  append_shell "Official/provisional output directory permissions" "ls -ld '$REPORTS_ROOT' '$PROVISIONAL_REPORT_DIR' '$LIBRARY_DB_ROOT' '$PROVISIONAL_RAW_DIR' '$SNAPSHOT_DIR' 2>/dev/null || true"
  append_shell "Disk usage of relevant shared directories" "du -sh '$TOOLBOX_SHARED' '$REPORTS_ROOT' '$PROVISIONAL_REPORT_DIR' '$LIBRARY_DB_ROOT' '$PROVISIONAL_RAW_DIR' '$SNAPSHOT_DIR' 2>/dev/null || true"
  append_shell "Recent files under /srv/toolbox/shared" "find '$TOOLBOX_SHARED' -maxdepth 5 -type f 2>/dev/null | sort | tail -120 || true"
}

diagnose_output_classification() {
  local path
  local rel
  local class
  local size
  local mtime
  local dir

  section "3. CLASSIFICATION OF EXISTING OUTPUT FILES"

  append_shell "Reports root file distribution" "find '$REPORTS_ROOT' -maxdepth 4 -type f 2>/dev/null | sed 's#^$REPORTS_ROOT/##' | sort || true"
  append_shell "Library-db file distribution" "find '$LIBRARY_DB_ROOT' -maxdepth 4 -type f 2>/dev/null | sed 's#^$LIBRARY_DB_ROOT/##' | sort || true"

  append_shell "Live logs candidates" "find '$TOOLBOX_SHARED' -maxdepth 6 -type f \\( -name '*_live_*.log' -o -name '*-live.log' -o -name '*live*.log' -o -name '*.log' \\) 2>/dev/null | sort || true"
  append_shell "Human report candidates" "find '$TOOLBOX_SHARED' -maxdepth 6 -type f \\( -name '*_report_*.txt' -o -name '*_report.txt' -o -name '*.txt' \\) 2>/dev/null | sort || true"
  append_shell "Plan TSV candidates" "find '$TOOLBOX_SHARED' -maxdepth 6 -type f -name '*_plan_*.tsv' 2>/dev/null | sort || true"
  append_shell "Apply TSV candidates" "find '$TOOLBOX_SHARED' -maxdepth 6 -type f -name '*_apply_*.tsv' 2>/dev/null | sort || true"
  append_shell "Validation TSV candidates" "find '$TOOLBOX_SHARED' -maxdepth 6 -type f -name '*_validation_*.tsv' 2>/dev/null | sort || true"
  append_shell "Diagnosis TSV candidates" "find '$TOOLBOX_SHARED' -maxdepth 6 -type f \\( -name '*_diagnosis_*.tsv' -o -name '*_diagnostic_*.tsv' \\) 2>/dev/null | sort || true"
  append_shell "Snapshot/freeze candidates" "find '$TOOLBOX_SHARED' -maxdepth 6 -type f \\( -name '*_snapshot_*.tsv' -o -name '*_freeze_*.tsv' -o -name '*freeze*.tsv' \\) 2>/dev/null | sort || true"

  append_shell "Possible TSVs under reports" "find '$REPORTS_ROOT' -maxdepth 5 -type f -name '*.tsv' 2>/dev/null | sort || true"
  append_shell "Possible reports/logs under raw" "find '$PROVISIONAL_RAW_DIR' -maxdepth 2 -type f \\( -name '*.txt' -o -name '*.log' \\) 2>/dev/null | sort || true"
  append_shell "Files outside reports and library-db under shared" "find '$TOOLBOX_SHARED' -maxdepth 5 -type f 2>/dev/null | grep -v '^$REPORTS_ROOT/' | grep -v '^$LIBRARY_DB_ROOT/' | sort || true"

  if [ -d "$TOOLBOX_SHARED" ]; then
    while IFS= read -r -d '' path; do
      rel="${path#$TOOLBOX_SHARED/}"
      class="$(classify_output_file "$path")"
      size="$(stat -c '%s' "$path" 2>/dev/null || printf 'UNKNOWN')"
      mtime="$(stat -c '%y' "$path" 2>/dev/null || printf 'UNKNOWN')"
      dir="$(dirname "$path")"

      tsv_row "output_file" "$rel" "$class" "dir=${dir} | size=${size} | mtime=${mtime}"
    done < <(find "$TOOLBOX_SHARED" -maxdepth 6 -type f -print0 2>/dev/null)
  fi
}

diagnose_scripts_lib() {
  local lib_file
  local base
  local size
  local lines
  local status
  local refs

  section "4. REAL STATE OF scripts/lib"

  dir_state_tsv "$SCRIPT_LIB_DIR" "scripts_lib"

  append_shell "scripts/lib file listing" "find '$SCRIPT_LIB_DIR' -maxdepth 3 -type f 2>/dev/null | sort | while read -r f; do ls -lh \"\$f\"; done || true"
  append_shell "scripts/lib content preview" "find '$SCRIPT_LIB_DIR' -maxdepth 2 -type f 2>/dev/null | sort | while read -r f; do echo; echo '====' \"\$f\"; sed -n '1,220p' \"\$f\"; done || true"
  append_shell "All source/dot references to scripts/lib" "grep -RniE '(^|[[:space:]])(source|\\.)[[:space:]].*(scripts/lib|/lib/|lib/)' '$TOOLBOX_APP/scripts' '$TOOLBOX_APP/bin' 2>/dev/null || true"
  append_shell "Any textual references to scripts/lib in docs/scripts" "grep -Rni 'scripts/lib\\|/lib/' '$TOOLBOX_APP/docs' '$TOOLBOX_APP/scripts' 2>/dev/null | sed -n '1,260p' || true"

  if [ -d "$SCRIPT_LIB_DIR" ]; then
    while IFS= read -r -d '' lib_file; do
      base="$(basename "$lib_file")"
      size="$(stat -c '%s' "$lib_file" 2>/dev/null || printf '0')"
      lines="$(wc -l < "$lib_file" 2>/dev/null | tr -d ' ' || printf '0')"

      if [ "$size" = "0" ]; then
        status="empty_placeholder"
      elif [ "$lines" = "0" ]; then
        status="empty_or_binary"
      elif grep -Eq '^[[:space:]]*(log|fail|run_|job_|require_|ensure_|die|timestamp|with_|safe_)' "$lib_file" 2>/dev/null; then
        status="non_empty_possible_real_lib"
      else
        status="non_empty_needs_review"
      fi

      refs="$(grep -R -F -e "scripts/lib/${base}" -e "/lib/${base}" -e "lib/${base}" "$TOOLBOX_APP/scripts" "$TOOLBOX_APP/bin" 2>/dev/null | wc -l | tr -d ' ')"

      tsv_row "scripts_lib" "$base" "$status" "path=${lib_file} | size=${size} | lines=${lines} | reference_count=${refs}"
    done < <(find "$SCRIPT_LIB_DIR" -maxdepth 1 -type f -print0 2>/dev/null)
  fi
}

diagnose_docs_policies() {
  section "5. EXISTING DOCUMENTATION AND POLICY FILES"

  dir_state_tsv "$DOCS_OPERATIONS_DIR" "docs_operations"

  append_shell "docs/operations files" "find '$DOCS_OPERATIONS_DIR' -maxdepth 3 -type f 2>/dev/null | sort || true"
  append_shell "Docs related to scripts, outputs, reports, logs, jobs, Git" "find '$TOOLBOX_APP/docs' -type f 2>/dev/null | grep -Ei 'script|output|report|toolbox|operation|convention|policy|flow|fluxo|git|job|log|storage|shell' | sort || true"
  append_shell "Policy keyword hits in docs" "grep -RniE 'diagnose|plan|apply|validate|set -u|log\\(\\)|fail\\(\\)|reports/media|library-db/raw|snapshots|nohup|tee|git status|bashcheck|outputs|relat[oó]rios|logs live' '$TOOLBOX_APP/docs' 2>/dev/null | sed -n '1,320p' || true"
  append_shell "Policy keyword hits in scripts" "grep -RniE 'REPORT_DIR|RAW_DIR|SNAPSHOT_DIR|reports/media|library-db/raw|snapshots|nohup|tee|set -u|log\\(\\)|fail\\(\\)' '$TOOLBOX_APP/scripts' 2>/dev/null | sed -n '1,320p' || true"

  if [ -d "$DOCS_OPERATIONS_DIR" ]; then
    while IFS= read -r -d '' doc_file; do
      local rel
      local size
      local lines

      rel="${doc_file#$TOOLBOX_APP/}"
      size="$(stat -c '%s' "$doc_file" 2>/dev/null || printf 'UNKNOWN')"
      lines="$(wc -l < "$doc_file" 2>/dev/null | tr -d ' ' || printf 'UNKNOWN')"

      tsv_row "doc_policy" "$rel" "exists" "size=${size} | lines=${lines}"
    done < <(find "$DOCS_OPERATIONS_DIR" -maxdepth 3 -type f -print0 2>/dev/null)
  fi
}

diagnose_scripts_output_usage() {
  section "6. OUTPUT PATH USAGE INSIDE SCRIPTS"

  append_shell "Scripts writing to reports/media" "grep -Rni 'reports/media' '$TOOLBOX_APP/scripts' 2>/dev/null | sed -n '1,260p' || true"
  append_shell "Scripts writing to library-db/raw" "grep -Rni 'library-db/raw' '$TOOLBOX_APP/scripts' 2>/dev/null | sed -n '1,260p' || true"
  append_shell "Scripts writing to library-db/snapshots" "grep -Rni 'library-db/snapshots' '$TOOLBOX_APP/scripts' 2>/dev/null | sed -n '1,260p' || true"
  append_shell "Scripts defining REPORT_DIR/RAW_DIR/SNAPSHOT_DIR/LOG paths" "grep -RniE 'REPORT_DIR=|RAW_DIR=|SNAPSHOT_DIR=|LOG=.*\\.log|_live_.*\\.log|live.*\\.log' '$TOOLBOX_APP/scripts' 2>/dev/null | sed -n '1,320p' || true"
  append_shell "Scripts using tee internally" "grep -RniE '[|][[:space:]]*tee|tee[[:space:]]+-a|tee[[:space:]]' '$TOOLBOX_APP/scripts' 2>/dev/null | sed -n '1,240p' || true"
}

write_summary() {
  section "7. DIAGNOSTIC SUMMARY"

  {
    printf 'This diagnosis intentionally does not propose a final output policy.\n'
    printf '\n'
    printf 'It maps the current state so that the next phase can plan a careful redesign of:\n'
    printf '  - general Toolbox outputs;\n'
    printf '  - media outputs;\n'
    printf '  - Stockhausen-specific outputs;\n'
    printf '  - live logs;\n'
    printf '  - reports;\n'
    printf '  - raw TSVs/plans/inventories;\n'
    printf '  - snapshots/freezes;\n'
    printf '  - scripts/lib maturity;\n'
    printf '  - Git/documentation routine.\n'
    printf '\n'
    printf 'Generated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  Structured TSV: %s\n' "$TSV_FILE"
  } >> "$REPORT_FILE"
}

main() {
  write_header

  log "Writing provisional human report: $REPORT_FILE"
  log "Writing provisional structured TSV: $TSV_FILE"
  log "Note: output destinations are provisional for this diagnosis, not final policy."

  diagnose_git
  diagnose_output_dirs
  diagnose_output_classification
  diagnose_scripts_lib
  diagnose_docs_policies
  diagnose_scripts_output_usage
  write_summary

  log "Diagnosis completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report:   %s\n' "$REPORT_FILE"
  printf '  Structured TSV: %s\n' "$TSV_FILE"
  printf '\n'
  printf 'Reminder: these output destinations are provisional and inherited from recent scripts, not a final policy.\n'
}

main "$@"
