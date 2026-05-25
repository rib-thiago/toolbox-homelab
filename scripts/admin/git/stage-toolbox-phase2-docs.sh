#!/usr/bin/env bash
set -u

# Stage Toolbox Phase 2 operational documentation.
#
# This script stages only the approved Phase 2 documentation files.
# It does not commit.
# It does not stage scripts, outputs, reports, TSVs, snapshots or editor backups.
#
# Preferred mode:
#   run script, review plan, type APPLY interactively.
#
# Fallback mode:
#   stage-toolbox-phase2-docs.sh APPLY

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

REPORT_FILE="$(toolbox_report_path "toolbox_phase2_docs" "stage" "$STAMP")"
TSV_FILE="$(toolbox_tsv_path "toolbox_phase2_docs" "stage" "$STAMP")"

mkdir -p "$(dirname "$REPORT_FILE")"
mkdir -p "$(dirname "$TSV_FILE")"

DOCS_TO_STAGE="
docs/operations/toolbox_architecture_reconciliation.md
docs/operations/toolbox_scripts_lib_policy.md
docs/operations/toolbox_runtime_profiles.md
docs/operations/toolbox_manpages_policy.md
docs/operations/toolbox_git_routine.md
docs/operations/toolbox_script_conventions.md
docs/operations/toolbox_reports_policy.md
docs/operations/toolbox_logging_policy.md
"

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
  local action="$3"
  local status="$4"
  local details="$5"

  printf '[%s] %s — %s — %s\n' "$status" "$category" "$item" "$action" >> "$REPORT_FILE"
  if [ -n "$details" ]; then
    printf '    %s\n' "$details" >> "$REPORT_FILE"
  fi

  tsv_row "$category" "$item" "$action" "$status" "$details" >> "$TSV_FILE"
}

write_headers() {
  {
    printf 'Toolbox Phase 2 documentation staging report\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope:\n'
    printf '  stage only Phase 2 operational documentation files;\n'
    printf '  no commit;\n'
    printf '  no git add .;\n'
    printf '  no scripts staged;\n'
    printf '  no generated outputs staged;\n'
    printf '  no editor backups staged;\n'
    printf '  no file deletion;\n'
    printf '  no Docker changes;\n'
    printf '  no shell configuration changes.\n'
    printf '\n'
    printf 'This script modifies Git index only after explicit APPLY confirmation.\n'
    printf 'Output destinations remain provisional and inherited from recent scripts.\n'
  } > "$REPORT_FILE"

  tsv_row "category" "item" "action" "status" "details" > "$TSV_FILE"
}

git_required() {
  section "Git repository diagnosis"

  if git -C "$TOOLBOX_APP" rev-parse --show-toplevel >/tmp/toolbox-stage-docs-git-root.$$ 2>/tmp/toolbox-stage-docs-git-err.$$; then
    local root
    local branch

    root="$(cat /tmp/toolbox-stage-docs-git-root.$$)"
    branch="$(git -C "$TOOLBOX_APP" branch --show-current 2>/dev/null || printf 'UNKNOWN')"

    record "git" "repository" "root" "ok" "$root"
    record "git" "repository" "branch" "ok" "$branch"
  else
    local err
    err="$(cat /tmp/toolbox-stage-docs-git-err.$$ 2>/dev/null || printf 'unknown error')"
    record "git" "$TOOLBOX_APP" "repository" "fail" "$err"
    rm -f /tmp/toolbox-stage-docs-git-root.$$ /tmp/toolbox-stage-docs-git-err.$$
    fail "Not a Git repository: $TOOLBOX_APP"
  fi

  rm -f /tmp/toolbox-stage-docs-git-root.$$ /tmp/toolbox-stage-docs-git-err.$$
}

show_plan() {
  section "Staging plan"

  {
    printf 'The following files will be staged:\n'
    printf '\n'
  } >> "$REPORT_FILE"

  printf '\n'
  printf 'This script will stage ONLY these files:\n'
  printf '\n'

  local path
  for path in $DOCS_TO_STAGE; do
    printf '  %s\n' "$path"
    printf '  %s\n' "$path" >> "$REPORT_FILE"
    record "plan" "$path" "stage candidate" "planned" "Phase 2 documentation"
  done

  printf '\n'
  printf 'It will NOT commit.\n'
  printf 'It will NOT stage scripts, reports, TSVs, snapshots, .save files, media scripts, or Stockhausen files.\n'
  printf '\n'
}

validate_expected_files() {
  section "Validate expected files"

  local path
  local full_path

  for path in $DOCS_TO_STAGE; do
    full_path="${TOOLBOX_APP}/${path}"

    if [ -f "$full_path" ]; then
      local size
      local lines
      local sha

      size="$(stat -c '%s' "$full_path" 2>/dev/null || printf 'UNKNOWN')"
      lines="$(wc -l < "$full_path" 2>/dev/null | tr -d ' ' || printf 'UNKNOWN')"
      sha="$(sha256sum "$full_path" 2>/dev/null | awk '{print $1}' || printf 'UNKNOWN')"

      record "file" "$path" "exists" "ok" "size=${size} lines=${lines} sha256=${sha}"
    else
      record "file" "$path" "exists" "fail" "missing expected file"
    fi
  done
}

validate_no_save_files_in_scope() {
  section "Validate no editor backups in staging scope"

  local found
  found="no"

  {
    cd "$TOOLBOX_APP" || exit 0
    find docs/operations \
      \( -name '*.save' -o -name '*.save.*' -o -name '*.bak' -o -name '*~' -o -name '.#*' \) \
      -print 2>/dev/null | sort
  } >/tmp/toolbox-stage-docs-save-files.$$

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    found="yes"
    record "exclude" "$path" "editor backup detected" "warning" "will not be staged by this script"
  done < /tmp/toolbox-stage-docs-save-files.$$

  rm -f /tmp/toolbox-stage-docs-save-files.$$

  if [ "$found" = "no" ]; then
    record "exclude" "docs/operations editor backups" "scan" "ok" "no editor backup files found in docs/operations"
  fi
}

write_pre_status() {
  section "Pre-stage Git status for selected docs"

  {
    cd "$TOOLBOX_APP" || exit 0
    for path in $DOCS_TO_STAGE; do
      git status --short -- "$path"
    done
  } >> "$REPORT_FILE" 2>&1

  record "git" "selected docs" "pre-stage status" "recorded" "see report"
}

run_validation_before_stage() {
  section "Pre-stage documentation validation"

  if command -v validate-toolbox-phase2-documentation-global.sh >/dev/null 2>&1; then
    if validate-toolbox-phase2-documentation-global.sh >/tmp/toolbox-stage-docs-validation.$$ 2>&1; then
      record "validation" "validate-toolbox-phase2-documentation-global.sh" "pre-stage" "ok" "global documentation validation passed"
    else
      local output
      output="$(cat /tmp/toolbox-stage-docs-validation.$$ 2>/dev/null || printf 'unknown validation error')"
      record "validation" "validate-toolbox-phase2-documentation-global.sh" "pre-stage" "fail" "$output"
      rm -f /tmp/toolbox-stage-docs-validation.$$
      fail "Global documentation validation failed."
    fi

    {
      printf '\nValidation command output:\n'
      cat /tmp/toolbox-stage-docs-validation.$$ 2>/dev/null || true
    } >> "$REPORT_FILE"

    rm -f /tmp/toolbox-stage-docs-validation.$$
  else
    record "validation" "validate-toolbox-phase2-documentation-global.sh" "pre-stage" "warning" "command not found in PATH; skipped"
  fi
}

require_apply_confirmation() {
  local arg_confirmation="${1-}"
  local typed_confirmation

  if [ "$arg_confirmation" = "APPLY" ]; then
    record "confirmation" "APPLY" "argument confirmation" "ok" "fallback command-line confirmation used"
    return 0
  fi

  printf 'About to stage Phase 2 documentation files listed above.\n'
  printf 'This modifies the Git index but does NOT commit.\n'
  printf 'Type APPLY to continue: '

  IFS= read -r typed_confirmation

  if [ "$typed_confirmation" = "APPLY" ]; then
    record "confirmation" "APPLY" "interactive confirmation" "ok" "user typed APPLY"
    return 0
  fi

  record "confirmation" "APPLY" "confirmation" "refused" "user did not type APPLY"
  printf 'Refusing to stage files. Confirmation was not APPLY.\n' >&2
  exit 2
}

stage_docs() {
  section "Stage selected documentation files"

  local path

  {
    cd "$TOOLBOX_APP" || exit 1

    for path in $DOCS_TO_STAGE; do
      git add -- "$path"
      printf 'staged %s\n' "$path"
    done
  } >> "$REPORT_FILE" 2>&1

  for path in $DOCS_TO_STAGE; do
    record "stage" "$path" "git add explicit path" "ok" "staged"
  done
}

write_cached_diff_summary() {
  section "Cached diff summary"

  {
    cd "$TOOLBOX_APP" || exit 0

    printf 'git diff --cached --stat:\n'
    git diff --cached --stat 2>&1 || true

    printf '\n'
    printf 'git status --short for selected docs:\n'
    for path in $DOCS_TO_STAGE; do
      git status --short -- "$path"
    done

    printf '\n'
    printf 'First lines of git diff --cached --name-only:\n'
    git diff --cached --name-only | sed -n '1,80p'
  } >> "$REPORT_FILE"

  record "git" "cached diff" "summary" "recorded" "see report"
}

validate_only_expected_docs_staged() {
  section "Validate staged file set"

  local unexpected
  local staged
  local path
  local ok

  unexpected="no"

  {
    cd "$TOOLBOX_APP" || exit 0
    git diff --cached --name-only
  } >/tmp/toolbox-stage-docs-cached-files.$$

  while IFS= read -r staged; do
    [ -n "$staged" ] || continue

    ok="no"
    for path in $DOCS_TO_STAGE; do
      if [ "$staged" = "$path" ]; then
        ok="yes"
        break
      fi
    done

    if [ "$ok" = "yes" ]; then
      record "staged-set" "$staged" "expected staged file" "ok" "allowed"
    else
      unexpected="yes"
      record "staged-set" "$staged" "unexpected staged file" "fail" "not part of Phase 2 docs staging plan"
    fi
  done < /tmp/toolbox-stage-docs-cached-files.$$

  rm -f /tmp/toolbox-stage-docs-cached-files.$$

  if [ "$unexpected" = "yes" ]; then
    fail "Unexpected files are staged. Review git diff --cached."
  fi
}

write_next_commands() {
  section "Next commands"

  {
    printf 'Review staged changes manually:\n'
    printf '\n'
    printf '  cd /srv/toolbox/app || exit 1\n'
    printf '  git diff --cached --stat\n'
    printf '  git diff --cached -- docs/operations\n'
    printf '\n'
    printf 'If everything is correct, commit manually:\n'
    printf '\n'
    printf '  git commit -m "docs: consolidate toolbox phase 2 operational policies"\n'
    printf '\n'
    printf 'If something is wrong, unstage these docs:\n'
    printf '\n'
    printf '  git restore --staged docs/operations/toolbox_architecture_reconciliation.md \\\n'
    printf '    docs/operations/toolbox_scripts_lib_policy.md \\\n'
    printf '    docs/operations/toolbox_runtime_profiles.md \\\n'
    printf '    docs/operations/toolbox_manpages_policy.md \\\n'
    printf '    docs/operations/toolbox_git_routine.md \\\n'
    printf '    docs/operations/toolbox_script_conventions.md \\\n'
    printf '    docs/operations/toolbox_reports_policy.md \\\n'
    printf '    docs/operations/toolbox_logging_policy.md\n'
  } >> "$REPORT_FILE"

  record "next-step" "manual review" "git diff --cached" "recorded" "see report"
}

write_summary() {
  local fail_count
  local warning_count

  section "Summary"

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "fail" {count++} END {print count+0}' "$TSV_FILE")"
  warning_count="$(awk -F '\t' 'NR > 1 && $4 == "warning" {count++} END {print count+0}' "$TSV_FILE")"

  {
    printf 'Failed checks: %s\n' "$fail_count"
    printf 'Warning checks: %s\n' "$warning_count"
    printf '\n'
    printf 'Generated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  TSV: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Git index was modified only after APPLY confirmation.\n'
    printf 'No commit was created.\n'
  } >> "$REPORT_FILE"

  if [ "$fail_count" -eq 0 ]; then
    record "summary" "phase2-docs-stage" "failed checks" "ok" "fail_count=0"
  else
    record "summary" "phase2-docs-stage" "failed checks" "fail" "fail_count=${fail_count}"
  fi
}

main() {
  write_headers

  log "Preparing to stage Toolbox Phase 2 documentation."
  log "Report: $REPORT_FILE"
  log "TSV: $TSV_FILE"

  git_required
  show_plan
  validate_expected_files
  validate_no_save_files_in_scope
  write_pre_status
  run_validation_before_stage
  require_apply_confirmation "${1-}"
  stage_docs
  write_cached_diff_summary
  validate_only_expected_docs_staged
  write_next_commands
  write_summary

  log "Phase 2 documentation staging completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report: %s\n' "$REPORT_FILE"
  printf '  TSV:          %s\n' "$TSV_FILE"
  printf '\n'
  printf 'Review staged docs with:\n'
  printf '  cd /srv/toolbox/app || exit 1\n'
  printf '  git diff --cached --stat\n'
  printf '  git diff --cached -- docs/operations\n'
}

main "$@"
