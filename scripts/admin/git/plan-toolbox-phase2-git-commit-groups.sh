#!/usr/bin/env bash
set -u

# Plan Git classification and commit groups for Toolbox Phase 2.
#
# This script does not modify Git state.
# It does not run git add, git commit, git rm, or delete files.
#
# It classifies accumulated docs/scripts from the Phase 2 Toolbox work:
#   - Phase 2 operational docs
#   - scripts/lib minimal implementation
#   - admin diagnostic/planning/validation/apply scripts
#   - editor backups / temporary files
#   - shell files outside the Git repo
#
# It uses scripts/lib helpers.

bootstrap_fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

TOOLBOX_APP="/srv/toolbox/app"
LIB_DIR="${TOOLBOX_APP}/scripts/lib"

LOGGING_LIB="${LIB_DIR}/logging.sh"
TIMESTAMPS_LIB="${LIB_DIR}/timestamps.sh"
TSV_LIB="${LIB_DIR}/tsv.sh"
REPORTS_LIB="${LIB_DIR}/reports.sh"

[ -f "$LOGGING_LIB" ] || bootstrap_fail "Missing lib file: $LOGGING_LIB"
[ -f "$TIMESTAMPS_LIB" ] || bootstrap_fail "Missing lib file: $TIMESTAMPS_LIB"
[ -f "$TSV_LIB" ] || bootstrap_fail "Missing lib file: $TSV_LIB"
[ -f "$REPORTS_LIB" ] || bootstrap_fail "Missing lib file: $REPORTS_LIB"

source "$LOGGING_LIB"
source "$TIMESTAMPS_LIB"
source "$TSV_LIB"
source "$REPORTS_LIB"

STAMP="$(toolbox_timestamp)"

REPORT_FILE="$(toolbox_report_path "toolbox_phase2_git_commit_groups" "plan" "$STAMP")"
TSV_FILE="$(toolbox_tsv_path "toolbox_phase2_git_commit_groups" "plan" "$STAMP")"

mkdir -p "$(dirname "$REPORT_FILE")"
mkdir -p "$(dirname "$TSV_FILE")"

section() {
  local title="$1"

  {
    printf '\n'
    printf '%s\n' '================================================================'
    printf '%s\n' "$title"
    printf '%s\n' '================================================================'
  } >> "$REPORT_FILE"
}

record() {
  local category="$1"
  local item="$2"
  local check="$3"
  local status="$4"
  local details="$5"

  printf '[%s] %s — %s — %s\n' "$status" "$category" "$item" "$check" >> "$REPORT_FILE"
  if [ -n "$details" ]; then
    printf '    %s\n' "$details" >> "$REPORT_FILE"
  fi

  tsv_row "$category" "$item" "$check" "$status" "$details" >> "$TSV_FILE"
}

write_headers() {
  {
    printf 'Toolbox Phase 2 Git commit group planning report\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope:\n'
    printf '  classify accumulated Git changes after Toolbox Phase 2 documentation, scripts/lib, and tbman work;\n'
    printf '  propose commit groups;\n'
    printf '  identify files that should not be committed;\n'
    printf '  identify follow-up cleanup needs;\n'
    printf '  no git add;\n'
    printf '  no git commit;\n'
    printf '  no git rm;\n'
    printf '  no file deletion;\n'
    printf '  no shell configuration changes;\n'
    printf '  no Docker changes.\n'
    printf '\n'
    printf 'Output destinations remain provisional and inherited from recent scripts.\n'
  } > "$REPORT_FILE"

  tsv_row "category" "item" "check" "status" "details" > "$TSV_FILE"
}

git_required() {
  section "Git repository diagnosis"

  if git -C "$TOOLBOX_APP" rev-parse --show-toplevel >/tmp/toolbox-git-root.$$ 2>/tmp/toolbox-git-root-err.$$; then
    local root
    local branch

    root="$(cat /tmp/toolbox-git-root.$$)"
    branch="$(git -C "$TOOLBOX_APP" branch --show-current 2>/dev/null || printf 'UNKNOWN')"

    record "git" "repository" "root" "ok" "$root"
    record "git" "repository" "branch" "ok" "$branch"
  else
    local err
    err="$(cat /tmp/toolbox-git-root-err.$$ 2>/dev/null || printf 'unknown error')"
    record "git" "$TOOLBOX_APP" "repository" "fail" "$err"
    rm -f /tmp/toolbox-git-root.$$ /tmp/toolbox-git-root-err.$$
    fail "Not a Git repository: $TOOLBOX_APP"
  fi

  rm -f /tmp/toolbox-git-root.$$ /tmp/toolbox-git-root-err.$$
}

write_recent_commits() {
  section "Recent commits"

  {
    cd "$TOOLBOX_APP" || exit 0
    git log --oneline -8 2>&1 || true
  } >> "$REPORT_FILE"

  record "git" "recent commits" "git log --oneline -8" "recorded" "see report"
}

write_full_status() {
  section "Full Git status --short"

  {
    cd "$TOOLBOX_APP" || exit 0
    git status --short 2>&1 || true
  } >> "$REPORT_FILE"

  record "git" "working tree" "git status --short" "recorded" "see report"
}

status_for_path() {
  local path="$1"
  local status

  status="$(git -C "$TOOLBOX_APP" status --short -- "$path" 2>/dev/null | sed -n '1p')"

  if [ -n "$status" ]; then
    printf '%s' "$status"
  else
    printf 'CLEAN %s' "$path"
  fi
}

classify_expected_file() {
  local group="$1"
  local path="$2"
  local recommendation="$3"
  local notes="$4"
  local full_path
  local status

  full_path="${TOOLBOX_APP}/${path}"
  status="$(status_for_path "$path")"

  if [ -e "$full_path" ]; then
    record "file" "$path" "$group" "present" "git_status=${status}; recommendation=${recommendation}; notes=${notes}"
  else
    record "file" "$path" "$group" "missing" "recommendation=${recommendation}; notes=${notes}"
  fi
}

classify_phase2_docs() {
  section "Classification: Phase 2 operational documents"

  classify_expected_file "phase2-docs" "docs/operations/toolbox_architecture_reconciliation.md" "commit" "new central architecture reconciliation document"
  classify_expected_file "phase2-docs" "docs/operations/toolbox_scripts_lib_policy.md" "commit" "new scripts/lib policy"
  classify_expected_file "phase2-docs" "docs/operations/toolbox_runtime_profiles.md" "commit" "new host/container runtime profiles policy"
  classify_expected_file "phase2-docs" "docs/operations/toolbox_manpages_policy.md" "commit" "new manpages policy"
  classify_expected_file "phase2-docs" "docs/operations/toolbox_git_routine.md" "commit" "new Git routine"
  classify_expected_file "phase2-docs" "docs/operations/toolbox_script_conventions.md" "commit" "updated script conventions"
  classify_expected_file "phase2-docs" "docs/operations/toolbox_reports_policy.md" "commit" "updated reports/output policy"
  classify_expected_file "phase2-docs" "docs/operations/toolbox_logging_policy.md" "commit" "updated logging policy"
}

classify_scripts_lib() {
  section "Classification: scripts/lib minimal implementation"

  classify_expected_file "scripts-lib" "scripts/lib/logging.sh" "commit" "minimal shared log/fail helpers; previously tracked or placeholder-modified"
  classify_expected_file "scripts-lib" "scripts/lib/timestamps.sh" "commit" "new timestamp helpers"
  classify_expected_file "scripts-lib" "scripts/lib/tsv.sh" "commit" "new TSV helpers"
  classify_expected_file "scripts-lib" "scripts/lib/paths.sh" "commit" "new provisional path helpers"
  classify_expected_file "scripts-lib" "scripts/lib/reports.sh" "commit" "new report/TSV/log/snapshot path helpers"
}

classify_admin_scripts() {
  section "Classification: admin scripts created during Phase 2"

  classify_expected_file "admin-script-backup" "scripts/admin/system/backup-toolbox-phase2-docs.sh" "commit" "backup/snapshot script for Phase 2 docs"

  classify_expected_file "admin-script-diagnosis" "scripts/admin/system/diagnose-toolbox-ergonomics-and-outputs.sh" "commit" "initial ergonomics/outputs diagnostic; verify no obsolete version"
  classify_expected_file "admin-script-diagnosis" "scripts/admin/system/diagnose-toolbox-output-policy-and-lib.sh" "commit" "output policy and scripts/lib diagnostic"
  classify_expected_file "admin-script-diagnosis" "scripts/admin/system/diagnose-toolbox-operations-docs-policy.sh" "commit" "operations docs policy diagnostic"
  classify_expected_file "admin-script-diagnosis" "scripts/admin/system/diagnose-toolbox-architecture-vs-practice.sh" "commit" "architecture vs practice diagnostic"
  classify_expected_file "admin-script-diagnosis" "scripts/admin/system/diagnose-toolbox-host-container-tools.sh" "commit" "host/container tools diagnostic"
  classify_expected_file "admin-script-diagnosis" "scripts/admin/system/diagnose-toolbox-manpages-host-access.sh" "commit" "manpages host access diagnostic"
  classify_expected_file "admin-script-diagnosis" "scripts/admin/system/diagnose-toolbox-tbman-post-apply.sh" "commit" "tbman post-apply diagnostic"

  classify_expected_file "admin-script-validation" "scripts/admin/system/validate-toolbox-phase2-docs.sh" "commit" "Phase 2 docs validation script"
  classify_expected_file "admin-script-validation" "scripts/admin/system/validate-toolbox-phase2-policy-docs.sh" "commit" "policy docs validation script"
  classify_expected_file "admin-script-validation" "scripts/admin/system/validate-toolbox-phase2-documentation-global.sh" "commit" "global Phase 2 documentation validation script"
  classify_expected_file "admin-script-validation" "scripts/admin/system/validate-toolbox-scripts-lib.sh" "commit" "scripts/lib validation script"

  classify_expected_file "admin-script-apply" "scripts/admin/system/apply-toolbox-tbman-host-access.sh" "commit" "apply script that installed tbman with APPLY confirmation"
}

classify_possible_unrelated_scripts() {
  section "Classification: possible unrelated or pre-existing admin scripts"

  classify_expected_file "admin-script-review" "scripts/admin/system/collect-homelab-operational-context.sh" "review-before-commit" "appears in status; verify whether it belongs to this Phase 2 commit set"
}

detect_editor_backups() {
  section "Editor backups / temporary files"

  local found
  found="no"

  {
    cd "$TOOLBOX_APP" || exit 0
    find . \
      \( -name '*.save' -o -name '*.save.*' -o -name '*.bak' -o -name '*~' -o -name '.#*' \) \
      -print 2>/dev/null | sort
  } >/tmp/toolbox-editor-backups.$$

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    found="yes"

    path="${path#./}"
    record "do-not-commit" "$path" "editor backup/temp" "exclude" "do not commit; plan cleanup or .gitignore decision later"
  done < /tmp/toolbox-editor-backups.$$

  rm -f /tmp/toolbox-editor-backups.$$

  if [ "$found" = "no" ]; then
    record "do-not-commit" "editor backups" "scan" "ok" "no .save/.bak/*~/.#* files found under repo"
  fi
}

detect_generated_outputs_in_repo() {
  section "Generated outputs inside repo"

  local found
  found="no"

  {
    cd "$TOOLBOX_APP" || exit 0
    find . \
      \( -name '*.log' -o -name '*_report_*.txt' -o -name '*_diagnosis_*.tsv' -o -name '*_validation_*.tsv' -o -name '*_snapshot_*.tsv' \) \
      -print 2>/dev/null | sort
  } >/tmp/toolbox-generated-outputs.$$

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    found="yes"

    path="${path#./}"
    record "do-not-commit" "$path" "generated output inside repo" "review" "likely should not be committed"
  done < /tmp/toolbox-generated-outputs.$$

  rm -f /tmp/toolbox-generated-outputs.$$

  if [ "$found" = "no" ]; then
    record "do-not-commit" "generated outputs inside repo" "scan" "ok" "no obvious generated outputs found inside repo"
  fi
}

detect_shell_files_outside_repo() {
  section "Shell files modified outside Git repo"

  local bash_aliases
  local tbman_file

  bash_aliases="${HOME}/.bash_aliases"
  tbman_file="${HOME}/.bash_aliases.d/toolbox-man.sh"

  if [ -f "$bash_aliases" ]; then
    record "outside-git" "$bash_aliases" "shell config" "modified-outside-repo" "not part of /srv/toolbox/app Git repo; backup exists from apply step"
  else
    record "outside-git" "$bash_aliases" "shell config" "missing" "unexpected if tbman was applied"
  fi

  if [ -f "$tbman_file" ]; then
    record "outside-git" "$tbman_file" "tbman helper" "created-outside-repo" "not part of /srv/toolbox/app Git repo"
  else
    record "outside-git" "$tbman_file" "tbman helper" "missing" "unexpected if tbman was applied"
  fi
}

write_commit_plan() {
  section "Proposed commit plan"

  {
    printf 'Recommended commit groups, subject to user review:\n'
    printf '\n'
    printf 'Commit 1 — Phase 2 operational documentation\n'
    printf '  Message suggestion:\n'
    printf '    docs: consolidate toolbox phase 2 operational policies\n'
    printf '  Include:\n'
    printf '    docs/operations/toolbox_architecture_reconciliation.md\n'
    printf '    docs/operations/toolbox_scripts_lib_policy.md\n'
    printf '    docs/operations/toolbox_runtime_profiles.md\n'
    printf '    docs/operations/toolbox_manpages_policy.md\n'
    printf '    docs/operations/toolbox_git_routine.md\n'
    printf '    docs/operations/toolbox_script_conventions.md\n'
    printf '    docs/operations/toolbox_reports_policy.md\n'
    printf '    docs/operations/toolbox_logging_policy.md\n'
    printf '\n'
    printf 'Commit 2 — Minimal scripts/lib implementation\n'
    printf '  Message suggestion:\n'
    printf '    scripts: add minimal toolbox shell library\n'
    printf '  Include:\n'
    printf '    scripts/lib/logging.sh\n'
    printf '    scripts/lib/timestamps.sh\n'
    printf '    scripts/lib/tsv.sh\n'
    printf '    scripts/lib/paths.sh\n'
    printf '    scripts/lib/reports.sh\n'
    printf '\n'
    printf 'Commit 3 — Phase 2 diagnostic and validation scripts\n'
    printf '  Message suggestion:\n'
    printf '    scripts/admin: add toolbox phase 2 diagnostics and validators\n'
    printf '  Include diagnostic/validation scripts only.\n'
    printf '  Exclude .save/.bak/*~ files.\n'
    printf '\n'
    printf 'Commit 4 — tbman host manpage access apply/diagnostic scripts\n'
    printf '  Message suggestion:\n'
    printf '    scripts/admin: add tbman host manpage access workflow\n'
    printf '  Include:\n'
    printf '    diagnose-toolbox-manpages-host-access.sh\n'
    printf '    apply-toolbox-tbman-host-access.sh\n'
    printf '    diagnose-toolbox-tbman-post-apply.sh\n'
    printf '\n'
    printf 'Optional Commit 5 — Git hygiene\n'
    printf '  Message suggestion:\n'
    printf '    chore: ignore editor backup files\n'
    printf '  Only if we decide to update .gitignore for .save/.bak/*~.\n'
    printf '\n'
    printf 'Do not commit:\n'
    printf '  reports generated under /srv/toolbox/shared/reports\n'
    printf '  TSVs generated under /srv/toolbox/shared/library-db/raw\n'
    printf '  snapshots under /srv/toolbox/shared/library-db/snapshots\n'
    printf '  shell backups under $HOME\n'
    printf '  .save/.bak/*~ editor backups\n'
  } >> "$REPORT_FILE"

  record "commit-plan" "commit-1" "docs" "proposed" "docs: consolidate toolbox phase 2 operational policies"
  record "commit-plan" "commit-2" "scripts-lib" "proposed" "scripts: add minimal toolbox shell library"
  record "commit-plan" "commit-3" "diagnostics-validators" "proposed" "scripts/admin: add toolbox phase 2 diagnostics and validators"
  record "commit-plan" "commit-4" "tbman-workflow" "proposed" "scripts/admin: add tbman host manpage access workflow"
  record "commit-plan" "commit-5" "git-hygiene" "optional" "chore: ignore editor backup files"
}

write_validation_commands_for_later() {
  section "Validation commands before any future commit"

  {
    printf 'Before staging anything, run or review:\n'
    printf '\n'
    printf '  cd /srv/toolbox/app || exit 1\n'
    printf '  git status --short\n'
    printf '  validate-toolbox-phase2-documentation-global.sh\n'
    printf '  validate-toolbox-scripts-lib.sh\n'
    printf '  diagnose-toolbox-tbman-post-apply.sh\n'
    printf '\n'
    printf 'Before committing shell scripts, run bashcheck on scripts to be staged.\n'
    printf '\n'
    printf 'Do not run git add .\n'
    printf 'Stage files by explicit path or reviewed groups only.\n'
  } >> "$REPORT_FILE"

  record "validation-plan" "before-commit" "commands" "recorded" "see report"
}

write_summary() {
  local exclude_count
  local review_count
  local missing_count
  local fail_count

  section "Summary"

  exclude_count="$(awk -F '\t' 'NR > 1 && $4 == "exclude" {count++} END {print count+0}' "$TSV_FILE")"
  review_count="$(awk -F '\t' 'NR > 1 && $4 == "review" {count++} END {print count+0}' "$TSV_FILE")"
  missing_count="$(awk -F '\t' 'NR > 1 && $4 == "missing" {count++} END {print count+0}' "$TSV_FILE")"
  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "fail" {count++} END {print count+0}' "$TSV_FILE")"

  {
    printf 'Exclude items: %s\n' "$exclude_count"
    printf 'Review items: %s\n' "$review_count"
    printf 'Missing items: %s\n' "$missing_count"
    printf 'Failed checks: %s\n' "$fail_count"
    printf '\n'
    printf 'Generated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  TSV: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'No files were modified except this planning report and TSV.\n'
    printf '\n'
    printf 'Next recommended step:\n'
    printf '  review this plan, then decide whether to create a Git apply/staging script or stage manually by explicit path.\n'
  } >> "$REPORT_FILE"

  record "summary" "phase2-git-plan" "planning completed" "recorded" "exclude=${exclude_count} review=${review_count} missing=${missing_count} fail=${fail_count}"
}

main() {
  write_headers

  log "Planning Toolbox Phase 2 Git commit groups."
  log "Report: $REPORT_FILE"
  log "TSV: $TSV_FILE"

  git_required
  write_recent_commits
  write_full_status
  classify_phase2_docs
  classify_scripts_lib
  classify_admin_scripts
  classify_possible_unrelated_scripts
  detect_editor_backups
  detect_generated_outputs_in_repo
  detect_shell_files_outside_repo
  write_commit_plan
  write_validation_commands_for_later
  write_summary

  log "Git commit group planning completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report: %s\n' "$REPORT_FILE"
  printf '  TSV:          %s\n' "$TSV_FILE"
}

main "$@"
