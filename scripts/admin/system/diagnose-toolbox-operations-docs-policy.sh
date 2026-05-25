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
DOCS_ROOT="${TOOLBOX_APP}/docs"
DOCS_OPERATIONS_DIR="${TOOLBOX_APP}/docs/operations"

PROVISIONAL_REPORT_DIR="/srv/toolbox/shared/reports/media"
PROVISIONAL_RAW_DIR="/srv/toolbox/shared/library-db/raw"

REPORT_FILE="${PROVISIONAL_REPORT_DIR}/toolbox_operations_docs_policy_review_report_${STAMP}.txt"
TSV_FILE="${PROVISIONAL_RAW_DIR}/toolbox_operations_docs_policy_review_${STAMP}.tsv"

MAX_PREVIEW_LINES=220

require_writable_dir() {
  local dir
  local label

  dir="$1"
  label="$2"

  if [ ! -d "$dir" ]; then
    fail "${label} does not exist: ${dir}"
  fi

  if [ ! -w "$dir" ]; then
    fail "${label} is not writable: ${dir}"
  fi
}

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

relpath() {
  local path
  path="$1"

  case "$path" in
    "$TOOLBOX_APP"/*)
      printf '%s\n' "${path#$TOOLBOX_APP/}"
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

doc_kind() {
  local path
  path="$1"

  case "$path" in
    "$DOCS_OPERATIONS_DIR"/*)
      printf '%s\n' "operations_doc"
      ;;
    "$DOCS_ROOT"/media/*)
      printf '%s\n' "media_doc"
      ;;
    "$DOCS_ROOT"/man1/*)
      printf '%s\n' "manpage_1"
      ;;
    "$DOCS_ROOT"/man7/*)
      printf '%s\n' "manpage_7"
      ;;
    "$DOCS_ROOT"/*)
      printf '%s\n' "general_doc"
      ;;
    *)
      printf '%s\n' "unknown_doc"
      ;;
  esac
}

safe_count_regex() {
  local file
  local pattern
  local count

  file="$1"
  pattern="$2"

  count="$(
    grep -Ei "$pattern" "$file" 2>/dev/null \
      | wc -l \
      | tr -d ' '
  )"

  if [ -z "$count" ]; then
    count="0"
  fi

  printf '%s\n' "$count"
}

safe_count_fixed() {
  local file
  local pattern
  local count

  file="$1"
  pattern="$2"

  count="$(
    grep -Fi "$pattern" "$file" 2>/dev/null \
      | wc -l \
      | tr -d ' '
  )"

  if [ -z "$count" ]; then
    count="0"
  fi

  printf '%s\n' "$count"
}


has_fixed() {
  local file
  local pattern

  file="$1"
  pattern="$2"

  grep -Fiq "$pattern" "$file" 2>/dev/null
}

has_regex() {
  local file
  local pattern

  file="$1"
  pattern="$2"

  grep -Eiq "$pattern" "$file" 2>/dev/null
}

write_header() {
  {
    printf 'Toolbox operations docs policy review\n'
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Docs root: %s\n' "$DOCS_ROOT"
    printf 'Operations docs: %s\n' "$DOCS_OPERATIONS_DIR"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope: diagnose only. No mkdir, no chmod, no mv, no rm, no git writes, no doc edits.\n'
    printf '\n'
    printf 'Important note:\n'
    printf '  This script writes its own artifacts to inherited/provisional locations:\n'
    printf '    human report: %s\n' "$PROVISIONAL_REPORT_DIR"
    printf '    structured TSV: %s\n' "$PROVISIONAL_RAW_DIR"
    printf '  This is NOT a final output policy. These locations are used only to record this diagnosis.\n'
  } > "$REPORT_FILE"

  {
    printf 'category\titem\tstatus\tvalue\n'
  } > "$TSV_FILE"
}

list_candidate_docs() {
  if [ ! -d "$DOCS_ROOT" ]; then
    return 0
  fi

  find "$DOCS_ROOT" -type f \
    \( -name '*.md' -o -name '*.txt' -o -name '*.1' -o -name '*.7' \) \
    2>/dev/null | sort
}

diagnose_docs_inventory() {
  local file
  local relative
  local kind
  local size
  local lines
  local headings

  section "1. DOCUMENT INVENTORY"

  if [ ! -d "$DOCS_ROOT" ]; then
    printf 'Docs root missing: %s\n' "$DOCS_ROOT" >> "$REPORT_FILE"
    tsv_row "directory" "docs_root" "missing" "$DOCS_ROOT"
    return 0
  fi

  append_shell "Docs directory tree" "find '$DOCS_ROOT' -maxdepth 3 -type d 2>/dev/null | sort || true"
  append_shell "Candidate document files" "find '$DOCS_ROOT' -type f \\( -name '*.md' -o -name '*.txt' -o -name '*.1' -o -name '*.7' \\) 2>/dev/null | sort || true"
  append_shell "Operations docs files" "find '$DOCS_OPERATIONS_DIR' -maxdepth 3 -type f 2>/dev/null | sort || true"

  while IFS= read -r file; do
    [ -n "$file" ] || continue

    relative="$(relpath "$file")"
    kind="$(doc_kind "$file")"
    size="$(stat -c '%s' "$file" 2>/dev/null || printf 'UNKNOWN')"
    lines="$(wc -l < "$file" 2>/dev/null | tr -d ' ' || printf 'UNKNOWN')"
    headings="$(grep -Ec '^[[:space:]]*#{1,6}[[:space:]]+' "$file" 2>/dev/null || printf '0')"

    tsv_row "doc_file" "$relative" "$kind" "size=${size} | lines=${lines} | markdown_headings=${headings}"
  done < <(list_candidate_docs)
}

diagnose_headings_sections() {
  local file
  local relative

  section "2. TITLES AND SECTIONS FOUND"

  while IFS= read -r file; do
    [ -n "$file" ] || continue

    relative="$(relpath "$file")"

    subsection "$relative"

    if grep -Eq '^[[:space:]]*#{1,6}[[:space:]]+' "$file" 2>/dev/null; then
      grep -En '^[[:space:]]*#{1,6}[[:space:]]+' "$file" 2>/dev/null >> "$REPORT_FILE" || true

      grep -En '^[[:space:]]*#{1,6}[[:space:]]+' "$file" 2>/dev/null |
        while IFS= read -r heading_line; do
          tsv_row "heading" "$relative" "found" "$heading_line"
        done
    else
      printf 'No markdown headings found.\n' >> "$REPORT_FILE"
      tsv_row "heading" "$relative" "none_found" ""
    fi
  done < <(list_candidate_docs)
}

diagnose_term_hits() {
  local file
  local relative
  local count

  section "3. TERM AND POLICY KEYWORD HITS"

  append_shell "Global policy keyword hits" "grep -RniE 'reports|raw|snapshots|logs|live logs|live.*log|tee|nohup|nf|bashcheck|git status|git|commit|diagnose|plan|apply|validate|scripts/lib|log\\(\\)|fail\\(\\)|set -u' '$DOCS_ROOT' 2>/dev/null | sed -n '1,420p' || true"

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    relative="$(relpath "$file")"

    count="$(safe_count_fixed "$file" "reports")"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "reports" "count=${count}"

    count="$(safe_count_fixed "$file" "raw")"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "raw" "count=${count}"

    count="$(safe_count_fixed "$file" "snapshots")"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "snapshots" "count=${count}"

    count="$(safe_count_regex "$file" '(^|[^[:alpha:]])logs?([^[:alpha:]]|$)')"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "logs" "count=${count}"

    count="$(safe_count_regex "$file" 'live[[:space:]_-]*logs?|_live_|-live|live.*\.log')"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "live_logs" "count=${count}"

    count="$(safe_count_fixed "$file" "tee")"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "tee" "count=${count}"

    count="$(safe_count_fixed "$file" "nohup")"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "nohup" "count=${count}"

    count="$(safe_count_regex "$file" '(^|[^[:alnum:]_])nf([^[:alnum:]_]|$)')"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "nf" "count=${count}"

    count="$(safe_count_fixed "$file" "bashcheck")"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "bashcheck" "count=${count}"

    count="$(safe_count_fixed "$file" "git status")"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "git_status" "count=${count}"

    count="$(safe_count_fixed "$file" "git")"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "git" "count=${count}"

    count="$(safe_count_fixed "$file" "commit")"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "commit" "count=${count}"

    count="$(safe_count_fixed "$file" "diagnose")"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "diagnose" "count=${count}"

    count="$(safe_count_regex "$file" '(^|[^[:alpha:]])plan([^[:alpha:]]|$)')"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "plan" "count=${count}"

    count="$(safe_count_regex "$file" '(^|[^[:alpha:]])apply([^[:alpha:]]|$)')"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "apply" "count=${count}"

    count="$(safe_count_fixed "$file" "validate")"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "validate" "count=${count}"

    count="$(safe_count_fixed "$file" "scripts/lib")"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "scripts_lib" "count=${count}"

    count="$(safe_count_fixed "$file" "log()")"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "log_function" "count=${count}"

    count="$(safe_count_fixed "$file" "fail()")"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "fail_function" "count=${count}"

    count="$(safe_count_fixed "$file" "set -u")"
    [ "$count" -gt 0 ] && tsv_row "term_hit" "$relative" "set_u" "count=${count}"
  done < <(list_candidate_docs)
}

diagnose_focus_docs_preview() {
  section "4. FOCUSED PREVIEW OF OPERATIONS DOCS"

  if [ ! -d "$DOCS_OPERATIONS_DIR" ]; then
    printf 'Operations docs directory missing: %s\n' "$DOCS_OPERATIONS_DIR" >> "$REPORT_FILE"
    return 0
  fi

  find "$DOCS_OPERATIONS_DIR" -maxdepth 3 -type f \
    \( -name '*.md' -o -name '*.txt' \) 2>/dev/null | sort |
    while IFS= read -r file; do
      local relative
      relative="$(relpath "$file")"

      subsection "$relative"
      {
        printf 'First %s lines:\n\n' "$MAX_PREVIEW_LINES"
        sed -n "1,${MAX_PREVIEW_LINES}p" "$file" 2>/dev/null || true
      } >> "$REPORT_FILE"
    done
}

diagnose_possible_contradictions() {
  local file
  local relative
  local hit_count

  section "5. POSSIBLE CONTRADICTIONS OR POLICY TENSIONS"

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    relative="$(relpath "$file")"
    hit_count=0

    if has_fixed "$file" "tee" && has_fixed "$file" "nohup"; then
      tsv_row "possible_tension" "$relative" "tee_and_nohup_both_mentioned" "Review whether doc distinguishes deliberate internal tee from external nohup/nf logging."
      hit_count=$((hit_count + 1))
    fi

    if has_fixed "$file" "tee" && has_regex "$file" 'logs?[[:space:]]+extern|external[[:space:]]+logs?|nohup|nf'; then
      tsv_row "possible_tension" "$relative" "tee_vs_external_logs" "Review whether doc conflicts with current preference for external nf/nohup logs and no internal tee unless deliberate."
      hit_count=$((hit_count + 1))
    fi

    if has_fixed "$file" "reports/media" && ! has_fixed "$file" "media"; then
      tsv_row "possible_tension" "$relative" "reports_media_without_domain_context" "Review whether reports/media is treated as universal rather than media-specific."
      hit_count=$((hit_count + 1))
    fi

    if has_fixed "$file" "library-db/raw" && ! has_regex "$file" 'media|music|library|acervo|Stockhausen|Stockhausen'; then
      tsv_row "possible_tension" "$relative" "library_db_raw_without_domain_context" "Review whether library-db/raw is treated as universal rather than library/media-specific."
      hit_count=$((hit_count + 1))
    fi

    if has_fixed "$file" "scripts/lib" && has_fixed "$file" "source"; then
      tsv_row "possible_tension" "$relative" "scripts_lib_may_be_described_as_active" "Review whether scripts/lib is described as active despite current placeholder state."
      hit_count=$((hit_count + 1))
    fi

    if has_fixed "$file" "set -euo pipefail"; then
      tsv_row "possible_tension" "$relative" "set_euo_pipefail_policy" "Review against current preference for set -u plus explicit fail handling."
      hit_count=$((hit_count + 1))
    fi

    if has_fixed "$file" "set -u" && has_fixed "$file" "set -euo pipefail"; then
      tsv_row "possible_tension" "$relative" "mixed_set_u_and_set_euo" "Review whether script safety policy is internally consistent."
      hit_count=$((hit_count + 1))
    fi

    if has_fixed "$file" "git" && ! has_fixed "$file" "git status"; then
      tsv_row "possible_gap" "$relative" "git_without_git_status" "Git is mentioned but git status routine may be missing."
      hit_count=$((hit_count + 1))
    fi

    if [ "$hit_count" -gt 0 ]; then
      printf '%s: %s possible issue(s) flagged.\n' "$relative" "$hit_count" >> "$REPORT_FILE"
    fi
  done < <(list_candidate_docs)
}

diagnose_patch_candidates() {
  local file
  local relative
  local score
  local reasons

  section "6. DOCUMENTS CANDIDATE FOR PATCH"

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    relative="$(relpath "$file")"
    score=0
    reasons=""

    case "$relative" in
      docs/operations/toolbox_reports_policy.md)
        score=$((score + 5))
        reasons="${reasons}primary_reports_policy;"
        ;;
      docs/operations/toolbox_logging_policy.md)
        score=$((score + 5))
        reasons="${reasons}primary_logging_policy;"
        ;;
      docs/operations/toolbox_script_conventions.md)
        score=$((score + 5))
        reasons="${reasons}primary_script_conventions;"
        ;;
      docs/operations/toolbox_shell_environment.md)
        score=$((score + 2))
        reasons="${reasons}shell_environment_related;"
        ;;
      docs/operations/toolbox_storage_policy.md)
        score=$((score + 1))
        reasons="${reasons}storage_outputs_related;"
        ;;
    esac

    if has_regex "$file" 'reports|raw|snapshots|logs|live logs|nohup|tee|nf'; then
      score=$((score + 2))
      reasons="${reasons}output_or_logging_terms;"
    fi

    if has_regex "$file" 'git status|commit|bashcheck|diagnose|plan|apply|validate'; then
      score=$((score + 2))
      reasons="${reasons}workflow_or_git_terms;"
    fi

    if has_regex "$file" 'scripts/lib|log\(\)|fail\(\)|set -u'; then
      score=$((score + 1))
      reasons="${reasons}script_convention_terms;"
    fi

    if [ "$score" -ge 5 ]; then
      tsv_row "patch_candidate" "$relative" "high" "score=${score} | reasons=${reasons}"
      printf 'HIGH: %s — score=%s — %s\n' "$relative" "$score" "$reasons" >> "$REPORT_FILE"
    elif [ "$score" -ge 3 ]; then
      tsv_row "patch_candidate" "$relative" "medium" "score=${score} | reasons=${reasons}"
      printf 'MEDIUM: %s — score=%s — %s\n' "$relative" "$score" "$reasons" >> "$REPORT_FILE"
    fi
  done < <(list_candidate_docs)
}

diagnose_probable_gaps() {
  section "7. PROBABLE DOCUMENTATION GAPS"

  append_shell "Docs mentioning git status" "grep -Rni 'git status' '$DOCS_ROOT' 2>/dev/null || true"
  append_shell "Docs mentioning bashcheck" "grep -Rni 'bashcheck' '$DOCS_ROOT' 2>/dev/null || true"
  append_shell "Docs mentioning nf/nohup" "grep -RniE '(^|[^[:alnum:]_])nf([^[:alnum:]_]|$)|nohup' '$DOCS_ROOT' 2>/dev/null || true"
  append_shell "Docs mentioning internal tee" "grep -RniE '[|][[:space:]]*tee|tee[[:space:]]+-a|tee[[:space:]]' '$DOCS_ROOT' 2>/dev/null || true"
  append_shell "Docs mentioning reports/media" "grep -Rni 'reports/media' '$DOCS_ROOT' 2>/dev/null || true"
  append_shell "Docs mentioning library-db/raw" "grep -Rni 'library-db/raw' '$DOCS_ROOT' 2>/dev/null || true"
  append_shell "Docs mentioning snapshots" "grep -Rni 'snapshots' '$DOCS_ROOT' 2>/dev/null || true"
  append_shell "Docs mentioning scripts/lib" "grep -Rni 'scripts/lib' '$DOCS_ROOT' 2>/dev/null || true"
  append_shell "Docs mentioning diagnose/plan/apply/validate" "grep -RniE 'diagnose|plan|apply|validate' '$DOCS_ROOT' 2>/dev/null | sed -n '1,220p' || true"

  if ! grep -Rqi 'git status' "$DOCS_ROOT" 2>/dev/null; then
    tsv_row "probable_gap" "git_routine" "missing_git_status" "No docs mention git status."
  fi

  if ! grep -Rqi 'bashcheck' "$DOCS_ROOT" 2>/dev/null; then
    tsv_row "probable_gap" "script_validation" "missing_bashcheck" "No docs mention bashcheck."
  fi

  if ! grep -RqiE '(^|[^[:alnum:]_])nf([^[:alnum:]_]|$)|nohup' "$DOCS_ROOT" 2>/dev/null; then
    tsv_row "probable_gap" "external_live_logs" "missing_nf_nohup" "No docs mention nf/nohup external logging."
  fi

  if ! grep -Rqi 'reports/media' "$DOCS_ROOT" 2>/dev/null; then
    tsv_row "probable_gap" "reports_media" "not_documented" "No docs mention reports/media."
  fi

  if ! grep -Rqi 'library-db/raw' "$DOCS_ROOT" 2>/dev/null; then
    tsv_row "probable_gap" "library_db_raw" "not_documented" "No docs mention library-db/raw."
  fi

  if ! grep -Rqi 'scripts/lib' "$DOCS_ROOT" 2>/dev/null; then
    tsv_row "probable_gap" "scripts_lib" "not_documented" "No docs mention scripts/lib."
  fi
}

write_summary() {
  section "8. SUMMARY"

  {
    printf 'This is a focused documentation diagnosis only.\n'
    printf '\n'
    printf 'It prepares the next phase: a documentary patch plan for outputs, logging, Git routine, and script conventions.\n'
    printf '\n'
    printf 'No policy was applied.\n'
    printf 'No output directory was redesigned.\n'
    printf 'No files were moved.\n'
    printf 'No scripts/lib abstraction was created.\n'
    printf 'No aliases, newbash, TUI, dashboard, or Git commits were touched.\n'
    printf '\n'
    printf 'Generated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  Structured TSV: %s\n' "$TSV_FILE"
  } >> "$REPORT_FILE"
}

main() {
  require_writable_dir "$PROVISIONAL_REPORT_DIR" "provisional report dir"
  require_writable_dir "$PROVISIONAL_RAW_DIR" "provisional raw dir"

  write_header

  log "Writing provisional human report: $REPORT_FILE"
  log "Writing provisional structured TSV: $TSV_FILE"
  log "Note: output destinations are provisional for this diagnosis, not final policy."

  diagnose_docs_inventory
  diagnose_headings_sections
  diagnose_term_hits
  diagnose_focus_docs_preview
  diagnose_possible_contradictions
  diagnose_patch_candidates
  diagnose_probable_gaps
  write_summary

  log "Documentation diagnosis completed."
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
