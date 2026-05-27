#!/usr/bin/env bash
set -u

APP_DIR="/srv/toolbox/app"
REPORT_DIR="/srv/toolbox/shared/reports/git"
STAMP="$(date +%Y%m%d-%H%M%S)"

REPORT="$REPORT_DIR/toolbox_git_remote_config_report_$STAMP.txt"
TSV="$REPORT_DIR/toolbox_git_remote_config_checks_$STAMP.tsv"

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

append_cmd() {
  local title="$1"
  shift

  {
    printf '\n## %s\n\n' "$title"
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

  {
    printf '# Toolbox Git Remote Config Quick Diagnosis\n\n'
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Repository: %s\n' "$APP_DIR"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf 'Scope: quick diagnosis of Git repository, branch, remotes, upstream and remote reachability.\n'
    printf 'Safety: this script does not commit, tag, push, pull, fetch, rebase, merge or modify repository state.\n'
    printf '\n'
    printf 'Output note: /srv/toolbox/shared/reports/git is used here as a domain-specific operational output path. This does not define a universal output policy for the Toolbox.\n'
  } > "$REPORT"

  printf 'check_id\tcategory\tstatus\tmessage\tdetails\n' > "$TSV"

  log "Starting quick Git remote/config diagnosis."

  if [ ! -d "$APP_DIR" ]; then
    write_check "REPO-001" "repository" "FAIL" "Toolbox app directory not found" "$APP_DIR"
    fail "Toolbox app directory not found: $APP_DIR"
  fi

  cd "$APP_DIR" || fail "Cannot enter $APP_DIR"

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    write_check "REPO-001" "repository" "OK" "Inside a Git work tree" "$repo_root"
  else
    write_check "REPO-001" "repository" "FAIL" "Not inside a Git work tree" "$APP_DIR"
    fail "Not inside a Git work tree: $APP_DIR"
  fi

  branch="$(git branch --show-current 2>/dev/null || true)"

  if [ -n "$branch" ]; then
    write_check "BRANCH-001" "branch" "OK" "Current branch detected" "$branch"
  else
    write_check "BRANCH-001" "branch" "WARN" "Current branch not detected" "Detached HEAD or unusual repository state"
  fi

  append_cmd "Repository root" git rev-parse --show-toplevel
  append_cmd "Current branch" git branch --show-current
  append_cmd "Short status" git status --short
  append_cmd "Git remotes" git remote -v
  append_cmd "Local branches with upstream info" git branch -vv
  append_cmd "Recent commits" git --no-pager log --oneline -5

  remote_count="$(git remote | wc -l | tr -d ' ')"

  if [ "$remote_count" -gt 0 ]; then
    write_check "REMOTE-001" "remote" "OK" "Git remotes configured" "$remote_count remote(s)"
  else
    write_check "REMOTE-001" "remote" "WARN" "No Git remotes configured" "Remote push will require adding a remote"
  fi

  if git remote get-url origin >/dev/null 2>&1; then
    origin_fetch="$(git remote get-url origin 2>/dev/null || true)"
    origin_push="$(git remote get-url --push origin 2>/dev/null || true)"

    write_check "REMOTE-002" "remote" "OK" "origin fetch URL detected" "$origin_fetch"
    write_check "REMOTE-003" "remote" "OK" "origin push URL detected" "$origin_push"
  else
    write_check "REMOTE-002" "remote" "WARN" "origin remote not configured" "No origin fetch URL"
    write_check "REMOTE-003" "remote" "WARN" "origin push URL not configured" "No origin push URL"
  fi

  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

  if [ -n "$upstream" ]; then
    write_check "UPSTREAM-001" "upstream" "OK" "Current branch has upstream" "$upstream"
  else
    write_check "UPSTREAM-001" "upstream" "WARN" "Current branch has no upstream" "Push may require git push -u origin ${branch:-<branch>}"
  fi

  {
    printf '\n## Remote reachability\n\n'
  } >> "$REPORT"

  if git remote get-url origin >/dev/null 2>&1; then
    printf '$ git ls-remote --heads origin\n\n' >> "$REPORT"

    if git ls-remote --heads origin >> "$REPORT" 2>&1; then
      write_check "REMOTE-004" "remote" "OK" "origin is reachable" "git ls-remote --heads origin succeeded"
      printf '\n[OK]\n' >> "$REPORT"
    else
      write_check "REMOTE-004" "remote" "WARN" "origin was not reachable or authentication failed" "Check network, SSH key/token, GitHub access or remote URL"
      printf '\n[WARN] origin was not reachable or authentication failed.\n' >> "$REPORT"
    fi
  else
    write_check "REMOTE-004" "remote" "SKIP" "Remote reachability skipped" "origin is not configured"
    printf 'Skipped: origin is not configured.\n' >> "$REPORT"
  fi

  {
    printf '\n## Suggested next commands, if diagnosis is acceptable\n\n'

    if [ -n "$branch" ]; then
      if [ -n "$upstream" ]; then
        printf 'Branch push, if needed:\n'
        printf 'git push\n\n'
      else
        printf 'First branch push with upstream, if needed:\n'
        printf 'git push -u origin "%s"\n\n' "$branch"
      fi
    else
      printf 'Current branch was not detected. Do not push until branch state is understood.\n\n'
    fi

    printf 'Checkpoint tag example, to be reviewed later:\n'
    printf 'git tag -a "toolbox-phase2-baseline-%s" -m "Toolbox Phase 2 baseline checkpoint"\n' "$STAMP"
    printf 'git push origin "toolbox-phase2-baseline-%s"\n' "$STAMP"
  } >> "$REPORT"

  warn_count="$(awk -F '\t' 'NR > 1 && $3 == "WARN" { c++ } END { print c+0 }' "$TSV")"
  fail_count="$(awk -F '\t' 'NR > 1 && $3 == "FAIL" { c++ } END { print c+0 }' "$TSV")"

  {
    printf '\n## Summary\n\n'
    printf 'Warnings: %s\n' "$warn_count"
    printf 'Failures: %s\n' "$fail_count"
    printf '\nGenerated artifacts:\n'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  if [ "$fail_count" -gt 0 ]; then
    write_check "SUMMARY" "summary" "FAIL" "Quick Git remote/config diagnosis found failure(s)" "$fail_count failure(s), $warn_count warning(s)"
  elif [ "$warn_count" -gt 0 ]; then
    write_check "SUMMARY" "summary" "WARN" "Quick Git remote/config diagnosis found warning(s)" "$warn_count warning(s)"
  else
    write_check "SUMMARY" "summary" "OK" "Quick Git remote/config diagnosis found no warnings or failures" "Remote configuration appears ready"
  fi

  log "Quick Git remote/config diagnosis completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
