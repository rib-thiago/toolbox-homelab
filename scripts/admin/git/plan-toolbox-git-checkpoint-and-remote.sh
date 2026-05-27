#!/usr/bin/env bash
set -u

APP_DIR="/srv/toolbox/app"
REPORT_DIR="/srv/toolbox/shared/reports/git"
STAMP="$(date +%Y%m%d-%H%M%S)"

REPORT="$REPORT_DIR/toolbox_git_checkpoint_remote_plan_report_$STAMP.txt"
TSV="$REPORT_DIR/toolbox_git_checkpoint_remote_plan_$STAMP.tsv"

REMOTE_URL="${1:-}"
TAG_NAME="toolbox-phase2-baseline-$STAMP"
COMMIT_MESSAGE="scripts/admin: add Git checkpoint diagnostics"

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

write_row() {
  # step_id phase action command required status notes
  local step_id="$1"
  local phase="$2"
  local action="$3"
  local command="$4"
  local required="$5"
  local status="$6"
  local notes="$7"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(tsv_escape "$step_id")" \
    "$(tsv_escape "$phase")" \
    "$(tsv_escape "$action")" \
    "$(tsv_escape "$command")" \
    "$(tsv_escape "$required")" \
    "$(tsv_escape "$status")" \
    "$(tsv_escape "$notes")" >> "$TSV"
}

append_section() {
  local title="$1"
  {
    printf '\n'
    printf '## %s\n' "$title"
    printf '\n'
  } >> "$REPORT"
}

append_cmd_block() {
  local command="$1"
  {
    printf '```bash\n'
    printf '%s\n' "$command"
    printf '```\n\n'
  } >> "$REPORT"
}

main() {
  mkdir -p "$REPORT_DIR"

  if [ ! -d "$APP_DIR" ]; then
    fail "Toolbox app directory not found: $APP_DIR"
  fi

  cd "$APP_DIR" || fail "Cannot enter $APP_DIR"

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fail "Not inside a Git work tree: $APP_DIR"
  fi

  branch="$(git branch --show-current 2>/dev/null || true)"
  if [ -z "$branch" ]; then
    branch="<unknown>"
  fi

  status_short="$(git status --short)"
  remote_count="$(git remote | wc -l | tr -d ' ')"
  origin_url="$(git remote get-url origin 2>/dev/null || true)"
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  latest_commit="$(git --no-pager log --oneline -1 2>/dev/null || true)"

  checkpoint_script="scripts/admin/git/diagnose-toolbox-git-checkpoint-readiness.sh"
  remote_script="scripts/admin/git/diagnose-toolbox-git-remote-config.sh"

  checkpoint_script_status="$(git status --short "$checkpoint_script" 2>/dev/null || true)"
  remote_script_status="$(git status --short "$remote_script" 2>/dev/null || true)"

  printf 'step_id\tphase\taction\tcommand\trequired\tstatus\tnotes\n' > "$TSV"

  {
    printf '# Toolbox Git Checkpoint and Remote Plan\n\n'
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Repository: %s\n' "$APP_DIR"
    printf 'Branch: %s\n' "$branch"
    printf 'Latest commit: %s\n' "$latest_commit"
    printf 'Remote count: %s\n' "$remote_count"
    printf 'Origin URL: %s\n' "${origin_url:-<none>}"
    printf 'Upstream: %s\n' "${upstream:-<none>}"
    printf 'Proposed remote URL: %s\n' "${REMOTE_URL:-<not provided>}"
    printf 'Proposed tag: %s\n' "$TAG_NAME"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf 'Safety: this is a plan/dry-run script. It does not modify Git state.\n'
    printf 'Authentication note: GitHub HTTPS push requires a Personal Access Token instead of account password.\n'
    printf 'Output note: /srv/toolbox/shared/reports/git is used here as a domain-specific operational output path, not as universal Toolbox output policy.\n'
  } > "$REPORT"

  log "Generating Git checkpoint/remote dry-run plan."

  append_section "Current Git status"
  {
    printf '```text\n'
    git status --short
    printf '```\n'
  } >> "$REPORT"

  append_section "Planning assumptions"

  {
    printf ' The local branch is `%s`.\n' "$branch"
    printf ' No remote exists yet unless shown above.\n'
    printf ' The two new diagnostic scripts should be committed before the checkpoint tag.\n'
    printf ' The checkpoint tag should mark the repository after the diagnostic scripts are versioned.\n'
    printf ' The branch and tag should be pushed after remote configuration.\n'
    printf ' HTTPS is acceptable, but GitHub requires a Personal Access Token when prompted for password.\n'
  } >> "$REPORT"

  # Step 1: manual GitHub repo creation
  if [ -z "$REMOTE_URL" ]; then
    write_row "01" "manual" "Create empty remote repository" "<create repository on GitHub, copy HTTPS URL>" "yes" "WAITING" "No remote URL was provided to this script"
  else
    write_row "01" "manual" "Create empty remote repository" "<already provided: $REMOTE_URL>" "yes" "READY" "Use the provided HTTPS remote URL"
  fi

  # Step 2: inspect pending files
  write_row "02" "diagnose" "Review pending Git changes" "git status --short" "yes" "READY" "Current branch: $branch"

  # Step 3: validate scripts
  write_row "03" "validate" "Validate checkpoint readiness script" "bash -n $checkpoint_script" "yes" "READY" "$checkpoint_script_status"
  write_row "04" "validate" "Validate remote config script" "bash -n $remote_script" "yes" "READY" "$remote_script_status"
  write_row "05" "validate" "Validate all shell scripts" "find scripts -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n" "recommended" "READY" "Full validation before checkpoint"

  # Step 4: stage and commit new scripts
  write_row "06" "apply-later" "Stage Git diagnostic scripts" "git add $checkpoint_script $remote_script scripts/admin/git/plan-toolbox-git-checkpoint-and-remote.sh" "yes" "PLANNED" "Do only after reviewing this plan"
  write_row "07" "apply-later" "Review staged diff" "git diff --cached" "yes" "PLANNED" "Confirm only intended scripts are staged"
  write_row "08" "apply-later" "Commit Git diagnostic tooling" "git commit -m \"$COMMIT_MESSAGE\"" "yes" "PLANNED" "Commit scripts before creating checkpoint tag"

  # Step 5: add remote
  if [ -z "$origin_url" ]; then
    if [ -z "$REMOTE_URL" ]; then
      write_row "09" "apply-later" "Add origin remote" "git remote add origin <HTTPS_URL>" "yes" "BLOCKED" "REMOTE_URL not provided"
    else
      write_row "09" "apply-later" "Add origin remote" "git remote add origin $REMOTE_URL" "yes" "PLANNED" "Origin is currently absent"
    fi
  else
    write_row "09" "apply-later" "Origin already configured" "git remote -v" "no" "SKIP" "$origin_url"
  fi

  # Step 6: push branch
  if [ "$branch" = "<unknown>" ]; then
    write_row "10" "apply-later" "Push branch" "<branch unknown; do not push>" "yes" "BLOCKED" "Detached HEAD or branch detection failed"
  elif [ -z "$upstream" ]; then
    write_row "10" "apply-later" "Push branch and set upstream" "git push -u origin \"$branch\"" "yes" "PLANNED" "Will ask for GitHub username and token if HTTPS"
  else
    write_row "10" "apply-later" "Push branch" "git push" "yes" "PLANNED" "Upstream exists: $upstream"
  fi

  # Step 7: tag and push tag
  write_row "11" "apply-later" "Create annotated checkpoint tag" "git tag -a \"$TAG_NAME\" -m \"Toolbox Phase 2 baseline checkpoint\"" "yes" "PLANNED" "Create after commit and before tag push"
  write_row "12" "apply-later" "Push checkpoint tag" "git push origin \"$TAG_NAME\"" "yes" "PLANNED" "Push the specific tag, not all tags"

  append_section "Proposed command sequence"

  if [ -z "$REMOTE_URL" ]; then
    {
      printf 'Remote URL was not provided. Create an empty GitHub repository first, then rerun this script as:\n\n'
      printf '```bash\n'
      printf '%s "https://github.com/<usuario>/<repositorio>.git"\n' "$0"
      printf '```\n'
    } >> "$REPORT"
  else
    append_cmd_block "cd $APP_DIR || exit 1"
    append_cmd_block "git status --short"
    append_cmd_block "bash -n $checkpoint_script"
    append_cmd_block "bash -n $remote_script"
    append_cmd_block "bash -n scripts/admin/git/plan-toolbox-git-checkpoint-and-remote.sh"
    append_cmd_block "git add $checkpoint_script $remote_script scripts/admin/git/plan-toolbox-git-checkpoint-and-remote.sh"
    append_cmd_block "git diff --cached"
    append_cmd_block "git commit -m \"$COMMIT_MESSAGE\""

    if [ -z "$origin_url" ]; then
      append_cmd_block "git remote add origin $REMOTE_URL"
    else
      append_cmd_block "git remote -v"
    fi

    if [ "$branch" != "<unknown>" ]; then
      if [ -z "$upstream" ]; then
        append_cmd_block "git push -u origin \"$branch\""
      else
        append_cmd_block "git push"
      fi
    fi

    append_cmd_block "git tag -a \"$TAG_NAME\" -m \"Toolbox Phase 2 baseline checkpoint\""
    append_cmd_block "git push origin \"$TAG_NAME\""
  fi

  append_section "Manual review checklist"

  {
    printf ' Confirm repository name on GitHub.\n'
    printf ' Confirm remote URL is HTTPS if using Personal Access Token.\n'
    printf ' Confirm no generated outputs are staged.\n'
    printf ' Confirm scripts pass bashcheck/bash -n.\n'
    printf ' Confirm branch name should remain `%s` or be renamed later in a separate task.\n' "$branch"
    printf ' Confirm checkpoint tag name before applying.\n'
  } >> "$REPORT"

  log "Plan generated."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
