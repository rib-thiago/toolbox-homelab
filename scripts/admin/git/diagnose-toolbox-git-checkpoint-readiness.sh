#!/usr/bin/env bash
set -u

APP_DIR="/srv/toolbox/app"
REPORT_DIR="/srv/toolbox/shared/reports/git"
STAMP="$(date +%Y%m%d-%H%M%S)"

REPORT="$REPORT_DIR/toolbox_git_checkpoint_readiness_report_$STAMP.txt"
TSV="$REPORT_DIR/toolbox_git_checkpoint_readiness_checks_$STAMP.tsv"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

tsv_escape() {
  printf '%s' "$1" | tr '\n\t' '  '
}

write_check() {
  # usage: write_check CHECK_ID CATEGORY STATUS MESSAGE DETAILS
  local check_id="$1"
  local category="$2"
  local status="$3"
  local message="$4"
  local details="$5"

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$(tsv_escape "$check_id")" \
    "$(tsv_escape "$category")" \
    "$(tsv_escape "$status")" \
    "$(tsv_escape "$message")" \
    "$(tsv_escape "$details")" >> "$TSV"
}

append_report_section() {
  local title="$1"
  {
    printf '\n'
    printf '## %s\n' "$title"
    printf '\n'
  } >> "$REPORT"
}

run_and_capture() {
  local title="$1"
  shift

  append_report_section "$title"

  {
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
  } >> "$REPORT"

  if "$@" >> "$REPORT" 2>&1; then
    printf '\n[OK]\n' >> "$REPORT"
    return 0
  fi

  printf '\n[WARN] Command returned non-zero status.\n' >> "$REPORT"
  return 1
}

main() {
  mkdir -p "$REPORT_DIR"

  if [ ! -d "$APP_DIR" ]; then
    fail "Toolbox app directory not found: $APP_DIR"
  fi

  cd "$APP_DIR" || fail "Cannot enter $APP_DIR"

  if [ ! -d ".git" ]; then
    fail "Not a Git repository: $APP_DIR"
  fi

  printf 'check_id\tcategory\tstatus\tmessage\tdetails\n' > "$TSV"

  {
    printf '# Toolbox Git Checkpoint Readiness Report\n\n'
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Repository: %s\n' "$APP_DIR"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf 'Output note: this report uses /srv/toolbox/shared/reports/git as a domain-specific operational output path. Output policy is still under consolidation; this path should not be interpreted as universal policy for all Toolbox outputs.\n'
  } > "$REPORT"

  log "Starting Toolbox Git checkpoint readiness diagnosis."

  # ---------------------------------------------------------------------------
  # Basic repository state
  # ---------------------------------------------------------------------------

  branch="$(git branch --show-current 2>/dev/null || true)"
  if [ -n "$branch" ]; then
    write_check "GIT-001" "repository" "OK" "Current branch detected" "$branch"
  else
    write_check "GIT-001" "repository" "WARN" "Could not detect current branch" "Detached HEAD or unusual repository state"
  fi

  run_and_capture "Git status short" git status --short
  run_and_capture "Current branch" git branch --show-current
  run_and_capture "Recent commits" git --no-pager log --oneline -10
  run_and_capture "Recent tags" git --no-pager tag --sort=-creatordate

  status_short="$(git status --short)"

  if [ -z "$status_short" ]; then
    write_check "GIT-002" "working-tree" "OK" "Working tree is clean" "git status --short returned no entries"
  else
    write_check "GIT-002" "working-tree" "WARN" "Working tree has pending changes" "Review report section: Git status short"
  fi

  modified_count="$(printf '%s\n' "$status_short" | grep -E '^( M|M |MM|A | D|D |R | R|C | C)' | wc -l | tr -d ' ')"
  untracked_count="$(printf '%s\n' "$status_short" | grep -E '^\?\?' | wc -l | tr -d ' ')"

  write_check "GIT-003" "working-tree" "INFO" "Modified/staged/deleted/renamed count" "$modified_count"
  write_check "GIT-004" "working-tree" "INFO" "Untracked count" "$untracked_count"

  # ---------------------------------------------------------------------------
  # Remote and upstream
  # ---------------------------------------------------------------------------

  run_and_capture "Git remotes" git remote -v

  remote_count="$(git remote | wc -l | tr -d ' ')"
  if [ "$remote_count" -gt 0 ]; then
    write_check "GIT-005" "remote" "OK" "At least one Git remote is configured" "$remote_count remote(s)"
  else
    write_check "GIT-005" "remote" "WARN" "No Git remote configured" "Push remoto will not be possible until a remote is added"
  fi

  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  if [ -n "$upstream" ]; then
    write_check "GIT-006" "remote" "OK" "Current branch has upstream" "$upstream"
  else
    write_check "GIT-006" "remote" "WARN" "Current branch has no upstream" "Push may require: git push -u origin <branch>"
  fi

  if [ "$remote_count" -gt 0 ]; then
    if git ls-remote --heads origin >/dev/null 2>&1; then
      write_check "GIT-007" "remote" "OK" "Remote origin is reachable" "git ls-remote --heads origin succeeded"
    else
      write_check "GIT-007" "remote" "WARN" "Could not verify remote origin reachability" "Check network/authentication/remote name"
    fi
  else
    write_check "GIT-007" "remote" "SKIP" "Remote reachability skipped" "No remote configured"
  fi

  # ---------------------------------------------------------------------------
  # Suspicious files: editor backups and generated outputs
  # ---------------------------------------------------------------------------

  append_report_section "Suspicious untracked/editor backup/generated files"

  {
    printf 'Editor backup candidates:\n'
    find . \
      -path './.git' -prune -o \
      -type f \( \
        -name '*.save' -o \
        -name '*.save.*' -o \
        -name '*.bak' -o \
        -name '*~' -o \
        -name '.#*' \
      \) -print | sort

    printf '\nGenerated output candidates inside repository:\n'
    find . \
      -path './.git' -prune -o \
      -type f \( \
        -name '*.log' -o \
        -name '*.tsv' -o \
        -name '*report*.txt' -o \
        -name '*snapshot*' -o \
        -name '*manifest*' \
      \) -print | sort
  } >> "$REPORT" 2>&1

  backup_count="$(
    find . \
      -path './.git' -prune -o \
      -type f \( \
        -name '*.save' -o \
        -name '*.save.*' -o \
        -name '*.bak' -o \
        -name '*~' -o \
        -name '.#*' \
      \) -print | wc -l | tr -d ' '
  )"

  if [ "$backup_count" -eq 0 ]; then
    write_check "GIT-008" "hygiene" "OK" "No editor backup candidates found in repository tree" "Checked *.save, *.save.*, *.bak, *~, .#*"
  else
    write_check "GIT-008" "hygiene" "WARN" "Editor backup candidates found" "$backup_count file(s); review before commit"
  fi

  generated_count="$(
    find . \
      -path './.git' -prune -o \
      -type f \( \
        -name '*.log' -o \
        -name '*.tsv' -o \
        -name '*report*.txt' -o \
        -name '*snapshot*' -o \
        -name '*manifest*' \
      \) -print | wc -l | tr -d ' '
  )"

  if [ "$generated_count" -eq 0 ]; then
    write_check "GIT-009" "hygiene" "OK" "No generated output candidates found inside repository tree" "Operational outputs should usually stay outside repo"
  else
    write_check "GIT-009" "hygiene" "WARN" "Generated output candidates found inside repository tree" "$generated_count file(s); review before commit"
  fi

  # ---------------------------------------------------------------------------
  # Shell script syntax validation
  # ---------------------------------------------------------------------------

  append_report_section "Shell script syntax validation"

  script_count="$(find scripts -type f -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')"

  if [ "$script_count" -eq 0 ]; then
    printf 'No shell scripts found under scripts/.\n' >> "$REPORT"
    write_check "SH-001" "scripts" "SKIP" "No shell scripts found" "scripts/**/*.sh"
  else
    printf 'Found %s shell script(s).\n\n' "$script_count" >> "$REPORT"

    failed_scripts_tmp="$(mktemp)"
    find scripts -type f -name '*.sh' -print0 2>/dev/null |
      while IFS= read -r -d '' script_path; do
        if bash -n "$script_path" >> "$REPORT" 2>&1; then
          printf '[OK] %s\n' "$script_path" >> "$REPORT"
        else
          printf '[FAIL] %s\n' "$script_path" >> "$REPORT"
          printf '%s\n' "$script_path" >> "$failed_scripts_tmp"
        fi
      done

    failed_script_count="$(wc -l < "$failed_scripts_tmp" | tr -d ' ')"

    if [ "$failed_script_count" -eq 0 ]; then
      write_check "SH-001" "scripts" "OK" "All shell scripts passed bash -n" "$script_count script(s)"
    else
      write_check "SH-001" "scripts" "FAIL" "Some shell scripts failed bash -n" "$failed_script_count failure(s)"
      {
        printf '\nFailed scripts:\n'
        cat "$failed_scripts_tmp"
      } >> "$REPORT"
    fi

    rm -f "$failed_scripts_tmp"
  fi

  # ---------------------------------------------------------------------------
  # Tag readiness
  # ---------------------------------------------------------------------------

  append_report_section "Tag checkpoint readiness"

  latest_tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"
  if [ -n "$latest_tag" ]; then
    printf 'Latest reachable tag: %s\n' "$latest_tag" >> "$REPORT"
    write_check "TAG-001" "tag" "INFO" "Latest reachable tag detected" "$latest_tag"
  else
    printf 'No reachable Git tag detected.\n' >> "$REPORT"
    write_check "TAG-001" "tag" "INFO" "No reachable Git tag detected" "This may be the first Toolbox checkpoint tag"
  fi

  suggested_tag="toolbox-phase2-baseline-$STAMP"
  {
    printf '\nSuggested local checkpoint tag name:\n'
    printf '%s\n' "$suggested_tag"
    printf '\nSuggested commands after manual review:\n'
    printf 'git tag -a "%s" -m "Toolbox Phase 2 baseline checkpoint"\n' "$suggested_tag"
    printf 'git push origin "%s"\n' "$suggested_tag"
    printf '\nIf branch has no upstream, branch push may require:\n'
    printf 'git push -u origin "%s"\n' "${branch:-main}"
  } >> "$REPORT"

  write_check "TAG-002" "tag" "INFO" "Suggested checkpoint tag name" "$suggested_tag"

  # ---------------------------------------------------------------------------
  # Summary
  # ---------------------------------------------------------------------------

  warn_count="$(awk -F '\t' 'NR > 1 && $3 == "WARN" { c++ } END { print c+0 }' "$TSV")"
  fail_count="$(awk -F '\t' 'NR > 1 && $3 == "FAIL" { c++ } END { print c+0 }' "$TSV")"

  {
    printf '\n## Summary\n\n'
    printf 'Warnings: %s\n' "$warn_count"
    printf 'Failures: %s\n' "$fail_count"
    printf '\nGenerated artifacts:\n'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
    printf '\nInterpretation:\n'
  } >> "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    printf 'FAIL: resolve failures before creating tag/checkpoint or pushing.\n' >> "$REPORT"
    write_check "SUMMARY" "summary" "FAIL" "Diagnosis found failure(s)" "$fail_count failure(s), $warn_count warning(s)"
  elif [ "$warn_count" -gt 0 ]; then
    printf 'WARN: review warnings before creating tag/checkpoint or pushing.\n' >> "$REPORT"
    write_check "SUMMARY" "summary" "WARN" "Diagnosis found warning(s)" "$warn_count warning(s)"
  else
    printf 'OK: repository appears ready for manual tag/checkpoint review.\n' >> "$REPORT"
    write_check "SUMMARY" "summary" "OK" "No failures or warnings detected" "Ready for manual review"
  fi

  log "Diagnosis completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
