#!/usr/bin/env bash
set -u

# Diagnose Toolbox manpages host access.
#
# This script does not modify anything.
# It inspects the current manpage structure, host tools, MANPATH state,
# and whether Toolbox manpages can be rendered from the host.
#
# It intentionally uses scripts/lib as the first real diagnostic use case
# after the minimal library was created.

bootstrap_fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

TOOLBOX_APP="/srv/toolbox/app"
LIB_DIR="${TOOLBOX_APP}/scripts/lib"

LOGGING_LIB="${LIB_DIR}/logging.sh"
TIMESTAMPS_LIB="${LIB_DIR}/timestamps.sh"
TSV_LIB="${LIB_DIR}/tsv.sh"
PATHS_LIB="${LIB_DIR}/paths.sh"
REPORTS_LIB="${LIB_DIR}/reports.sh"

[ -f "$LOGGING_LIB" ] || bootstrap_fail "Missing lib file: $LOGGING_LIB"
[ -f "$TIMESTAMPS_LIB" ] || bootstrap_fail "Missing lib file: $TIMESTAMPS_LIB"
[ -f "$TSV_LIB" ] || bootstrap_fail "Missing lib file: $TSV_LIB"
[ -f "$PATHS_LIB" ] || bootstrap_fail "Missing lib file: $PATHS_LIB"
[ -f "$REPORTS_LIB" ] || bootstrap_fail "Missing lib file: $REPORTS_LIB"

source "$LOGGING_LIB"
source "$TIMESTAMPS_LIB"
source "$TSV_LIB"
source "$PATHS_LIB"
source "$REPORTS_LIB"

STAMP="$(toolbox_timestamp)"

REPORT_FILE="$(toolbox_report_path "toolbox_manpages_host_access" "diagnosis" "$STAMP")"
TSV_FILE="$(toolbox_tsv_path "toolbox_manpages_host_access" "diagnosis" "$STAMP")"

DOCS_DIR="${TOOLBOX_APP}/docs"
MAN1_DIR="${DOCS_DIR}/man1"
MAN7_DIR="${DOCS_DIR}/man7"
LEGACY_MAN_DIR="${DOCS_DIR}/man"

mkdir -p "$(dirname "$REPORT_FILE")"
mkdir -p "$(dirname "$TSV_FILE")"

write_headers() {
  {
    printf 'Toolbox manpages host access diagnosis report\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Docs dir: %s\n' "$DOCS_DIR"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope:\n'
    printf '  diagnose Toolbox manpage host access;\n'
    printf '  inspect docs/man1, docs/man7 and docs/man;\n'
    printf '  inspect host tools: man, groff, less, mandb, whatis, apropos;\n'
    printf '  inspect MANPATH and tbman state;\n'
    printf '  test groff rendering where possible;\n'
    printf '  test man -M access where possible;\n'
    printf '  no edits;\n'
    printf '  no shell configuration changes;\n'
    printf '  no MANPATH changes;\n'
    printf '  no Docker changes;\n'
    printf '  no Git commit.\n'
    printf '\n'
    printf 'Output destinations remain provisional and inherited from recent scripts.\n'
  } > "$REPORT_FILE"

  tsv_row "category" "item" "check" "status" "details" > "$TSV_FILE"
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

record_ok() {
  local category="$1"
  local item="$2"
  local check="$3"
  local details="$4"

  printf 'OK: [%s] %s — %s\n' "$category" "$item" "$check" >> "$REPORT_FILE"
  if [ -n "$details" ]; then
    printf '    %s\n' "$details" >> "$REPORT_FILE"
  fi

  tsv_row "$category" "$item" "$check" "ok" "$details" >> "$TSV_FILE"
}

record_missing() {
  local category="$1"
  local item="$2"
  local check="$3"
  local details="$4"

  printf 'MISSING: [%s] %s — %s\n' "$category" "$item" "$check" >> "$REPORT_FILE"
  if [ -n "$details" ]; then
    printf '    %s\n' "$details" >> "$REPORT_FILE"
  fi

  tsv_row "$category" "$item" "$check" "missing" "$details" >> "$TSV_FILE"
}

record_warning() {
  local category="$1"
  local item="$2"
  local check="$3"
  local details="$4"

  printf 'WARNING: [%s] %s — %s\n' "$category" "$item" "$check" >> "$REPORT_FILE"
  if [ -n "$details" ]; then
    printf '    %s\n' "$details" >> "$REPORT_FILE"
  fi

  tsv_row "$category" "$item" "$check" "warning" "$details" >> "$TSV_FILE"
}

record_fail() {
  local category="$1"
  local item="$2"
  local check="$3"
  local details="$4"

  printf 'FAIL: [%s] %s — %s\n' "$category" "$item" "$check" >> "$REPORT_FILE"
  if [ -n "$details" ]; then
    printf '    %s\n' "$details" >> "$REPORT_FILE"
  fi

  tsv_row "$category" "$item" "$check" "fail" "$details" >> "$TSV_FILE"
}

diagnose_directory() {
  local dir="$1"
  local label="$2"

  section "Directory diagnosis: ${label}"

  if [ -d "$dir" ]; then
    local count_all
    local count_regular
    local count_gz
    local count_section1
    local count_section7

    count_all="$(find "$dir" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"
    count_regular="$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
    count_gz="$(find "$dir" -maxdepth 1 -type f -name '*.gz' 2>/dev/null | wc -l | tr -d ' ')"
    count_section1="$(find "$dir" -maxdepth 1 -type f \( -name '*.1' -o -name '*.1.gz' \) 2>/dev/null | wc -l | tr -d ' ')"
    count_section7="$(find "$dir" -maxdepth 1 -type f \( -name '*.7' -o -name '*.7.gz' \) 2>/dev/null | wc -l | tr -d ' ')"

    record_ok "directory" "$label" "exists" "$dir"
    record_ok "directory" "$label" "item count" "all=${count_all} files=${count_regular} gz=${count_gz} section1=${count_section1} section7=${count_section7}"

    {
      printf '\nListing: %s\n' "$dir"
      ls -la "$dir" 2>&1 || true
    } >> "$REPORT_FILE"

    {
      printf '\nCandidate manpage files under %s:\n' "$dir"
      find "$dir" -maxdepth 1 -type f \
        \( -name '*.1' -o -name '*.1.gz' -o -name '*.7' -o -name '*.7.gz' \) \
        -printf '%f\n' 2>/dev/null | sort || true
    } >> "$REPORT_FILE"
  else
    record_missing "directory" "$label" "exists" "$dir"
  fi
}

diagnose_host_tool() {
  local tool="$1"

  if command -v "$tool" >/dev/null 2>&1; then
    local path
    path="$(command -v "$tool" 2>/dev/null || printf 'UNKNOWN')"
    record_ok "host-tool" "$tool" "available" "$path"
  else
    record_missing "host-tool" "$tool" "available" "not found in PATH"
  fi
}

diagnose_host_tools() {
  section "Host tool diagnosis"

  diagnose_host_tool "man"
  diagnose_host_tool "groff"
  diagnose_host_tool "less"
  diagnose_host_tool "mandb"
  diagnose_host_tool "whatis"
  diagnose_host_tool "apropos"
}

diagnose_shell_state() {
  section "Shell state diagnosis"

  {
    printf 'MANPATH raw value:\n'
    printf '%s\n' "${MANPATH-}"
    printf '\n'
    printf 'type man:\n'
    type man 2>&1 || true
    printf '\n'
    printf 'type tbman:\n'
    type tbman 2>&1 || true
  } >> "$REPORT_FILE"

  if [ -n "${MANPATH-}" ]; then
    record_ok "shell" "MANPATH" "present" "$MANPATH"
  else
    record_warning "shell" "MANPATH" "empty or unset" "This is not necessarily a problem; system man may use defaults."
  fi

  if type tbman >/dev/null 2>&1; then
    record_ok "shell" "tbman" "defined" "$(type tbman 2>&1 | head -n 1)"
  else
    record_missing "shell" "tbman" "defined" "tbman is not currently defined"
  fi
}

manpage_name_from_file() {
  local file="$1"
  local base

  base="$(basename "$file")"
  base="${base%.gz}"
  base="${base%.[0-9]}"

  printf '%s' "$base"
}

render_with_groff() {
  local file="$1"
  local label="$2"

  if ! command -v groff >/dev/null 2>&1; then
    record_missing "render" "$label" "groff" "groff not available"
    return 0
  fi

  if [ ! -f "$file" ]; then
    record_missing "render" "$label" "file exists" "$file"
    return 0
  fi

  local output
  local exit_code

  if printf '%s\n' "$file" | grep -Fq '.gz'; then
    output="$(gzip -dc "$file" 2>/tmp/toolbox-groff-stderr.$$ | groff -man -Tutf8 >/tmp/toolbox-groff-output.$$ 2>>/tmp/toolbox-groff-stderr.$$; printf 'exit=%s' "$?")"
    exit_code="${output#exit=}"
  else
    groff -man -Tutf8 "$file" >/tmp/toolbox-groff-output.$$ 2>/tmp/toolbox-groff-stderr.$$
    exit_code="$?"
  fi

  if [ "$exit_code" -eq 0 ]; then
    local preview
    preview="$(sed -n '1,5p' /tmp/toolbox-groff-output.$$ 2>/dev/null | tr '\n' ' ' || true)"
    record_ok "render" "$label" "groff -man -Tutf8" "preview=${preview}"
  else
    local err
    err="$(cat /tmp/toolbox-groff-stderr.$$ 2>/dev/null || printf 'unknown error')"
    record_fail "render" "$label" "groff -man -Tutf8" "$err"
  fi

  rm -f /tmp/toolbox-groff-output.$$ /tmp/toolbox-groff-stderr.$$
}

test_man_with_manpath() {
  local page="$1"
  local section="$2"
  local label="$3"

  if ! command -v man >/dev/null 2>&1; then
    record_missing "man-access" "$label" "man command" "man not available"
    return 0
  fi

  local output
  local exit_code

  output="$(MANPAGER=cat MANWIDTH=100 man -M "$DOCS_DIR" "$section" "$page" >/tmp/toolbox-man-output.$$ 2>/tmp/toolbox-man-stderr.$$; printf 'exit=%s' "$?")"
  exit_code="${output#exit=}"

  if [ "$exit_code" -eq 0 ]; then
    local preview
    preview="$(sed -n '1,5p' /tmp/toolbox-man-output.$$ 2>/dev/null | tr '\n' ' ' || true)"
    record_ok "man-access" "$label" "man -M ${DOCS_DIR} ${section} ${page}" "preview=${preview}"
  else
    local err
    err="$(cat /tmp/toolbox-man-stderr.$$ 2>/dev/null || printf 'unknown error')"
    record_warning "man-access" "$label" "man -M ${DOCS_DIR} ${section} ${page}" "$err"
  fi

  rm -f /tmp/toolbox-man-output.$$ /tmp/toolbox-man-stderr.$$
}

diagnose_manpage_files() {
  section "Manpage file diagnosis and render tests"

  local found_any
  found_any="no"

  for dir in "$MAN1_DIR" "$MAN7_DIR"; do
    if [ ! -d "$dir" ]; then
      continue
    fi

    while IFS= read -r file; do
      [ -n "$file" ] || continue
      found_any="yes"

      local page
      local section
      local rel_label

      page="$(manpage_name_from_file "$file")"

      case "$file" in
        *.1|*.1.gz)
          section="1"
          ;;
        *.7|*.7.gz)
          section="7"
          ;;
        *)
          section=""
          ;;
      esac

      rel_label="${file#$DOCS_DIR/}"

      record_ok "manpage" "$rel_label" "candidate" "page=${page} section=${section}"
      render_with_groff "$file" "$rel_label"

      if [ -n "$section" ]; then
        test_man_with_manpath "$page" "$section" "$rel_label"
      else
        record_warning "man-access" "$rel_label" "section detection" "could not infer section"
      fi
    done <<EOF_FIND
$(find "$dir" -maxdepth 1 -type f \( -name '*.1' -o -name '*.1.gz' -o -name '*.7' -o -name '*.7.gz' \) 2>/dev/null | sort)
EOF_FIND
  done

  if [ "$found_any" = "no" ]; then
    record_warning "manpage" "docs/man1 docs/man7" "candidate files" "no .1/.7/.gz manpage files found"
  fi
}

diagnose_legacy_man_dir() {
  section "Legacy docs/man diagnosis"

  if [ -d "$LEGACY_MAN_DIR" ]; then
    record_warning "directory" "docs/man" "exists" "legacy or duplicate directory should be inspected later"

    {
      printf '\nListing legacy docs/man:\n'
      ls -la "$LEGACY_MAN_DIR" 2>&1 || true
    } >> "$REPORT_FILE"
  else
    record_ok "directory" "docs/man" "absent" "no legacy docs/man directory found"
  fi
}

write_git_status() {
  section "Git status for manpage diagnosis"

  if git -C "$TOOLBOX_APP" rev-parse --show-toplevel >/dev/null 2>&1; then
    {
      cd "$TOOLBOX_APP" || exit 0
      git status --short docs/man1 docs/man7 docs/man docs/operations/toolbox_manpages_policy.md
      printf '\n'
      git status --short scripts/admin/system/diagnose-toolbox-manpages-host-access.sh
    } >> "$REPORT_FILE" 2>&1

    tsv_row "git" "manpages" "git status --short" "recorded" "see report" >> "$TSV_FILE"
  else
    printf 'Git repository not detected at %s\n' "$TOOLBOX_APP" >> "$REPORT_FILE"
    tsv_row "git" "$TOOLBOX_APP" "git status" "missing" "not a git repository" >> "$TSV_FILE"
  fi
}

write_recommendations() {
  section "Recommendations"

  {
    printf 'Interpretation guidance:\n'
    printf '  - If man -M works for existing pages, prefer tbman as first apply step.\n'
    printf '  - Do not alter global MANPATH yet.\n'
    printf '  - Do not edit ~/.bashrc or ~/.bash_aliases directly.\n'
    printf '  - Prefer a small shell function under ~/.bash_aliases.d/ or equivalent modular shell path.\n'
    printf '  - If manpage structure is inconsistent, plan structure correction before tbman.\n'
    printf '  - If docs/man exists, inspect whether it is legacy or duplicate before moving/removing.\n'
    printf '  - Do not convert Markdown to manpages in this step.\n'
  } >> "$REPORT_FILE"

  tsv_row "recommendation" "tbman" "first apply candidate" "recorded" "prefer tbman if man -M works" >> "$TSV_FILE"
  tsv_row "recommendation" "MANPATH" "global change" "defer" "do not alter global MANPATH yet" >> "$TSV_FILE"
  tsv_row "recommendation" "docs/man" "legacy inspection" "recorded" "inspect before moving or removing" >> "$TSV_FILE"
}

write_summary() {
  local missing_count
  local fail_count
  local warning_count

  section "Summary"

  missing_count="$(awk -F '\t' 'NR > 1 && $4 == "missing" {count++} END {print count+0}' "$TSV_FILE")"
  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "fail" {count++} END {print count+0}' "$TSV_FILE")"
  warning_count="$(awk -F '\t' 'NR > 1 && $4 == "warning" {count++} END {print count+0}' "$TSV_FILE")"

  {
    printf 'Missing checks: %s\n' "$missing_count"
    printf 'Failed checks: %s\n' "$fail_count"
    printf 'Warning checks: %s\n' "$warning_count"
    printf '\n'
    printf 'Generated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  TSV: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'No files were modified except this diagnosis report and TSV.\n'
  } >> "$REPORT_FILE"

  if [ "$fail_count" -eq 0 ]; then
    tsv_row "summary" "manpages-host-access" "failed checks" "ok" "fail_count=0" >> "$TSV_FILE"
  else
    tsv_row "summary" "manpages-host-access" "failed checks" "fail" "fail_count=${fail_count}" >> "$TSV_FILE"
  fi

  if [ "$missing_count" -eq 0 ]; then
    tsv_row "summary" "manpages-host-access" "missing checks" "ok" "missing_count=0" >> "$TSV_FILE"
  else
    tsv_row "summary" "manpages-host-access" "missing checks" "warning" "missing_count=${missing_count}" >> "$TSV_FILE"
  fi

  tsv_row "summary" "manpages-host-access" "warning checks" "recorded" "warning_count=${warning_count}" >> "$TSV_FILE"
}

main() {
  write_headers

  log "Diagnosing Toolbox manpages host access."
  log "Report: $REPORT_FILE"
  log "TSV: $TSV_FILE"

  diagnose_directory "$DOCS_DIR" "docs"
  diagnose_directory "$MAN1_DIR" "docs/man1"
  diagnose_directory "$MAN7_DIR" "docs/man7"
  diagnose_legacy_man_dir
  diagnose_host_tools
  diagnose_shell_state
  diagnose_manpage_files
  write_git_status
  write_recommendations
  write_summary

  log "Manpages host access diagnosis completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report: %s\n' "$REPORT_FILE"
  printf '  TSV:          %s\n' "$TSV_FILE"
}

main "$@"
