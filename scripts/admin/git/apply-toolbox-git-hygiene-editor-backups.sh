#!/usr/bin/env bash
set -u

# Apply Toolbox Git hygiene for editor backup/temp files.
#
# This script removes only reviewed editor backup/temp files and updates
# .gitignore with editor-backup ignore rules if they are missing.
#
# Preferred mode:
#   run script, review plan, type APPLY interactively.
#
# Fallback mode:
#   apply-toolbox-git-hygiene-editor-backups.sh APPLY
#
# This script does not touch docs/media, scripts/media, Stockhausen, Soulseek,
# library scripts, generated reports, TSVs or snapshots.

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

REPORT_FILE="$(toolbox_report_path "toolbox_git_hygiene_editor_backups" "apply" "$STAMP")"
TSV_FILE="$(toolbox_tsv_path "toolbox_git_hygiene_editor_backups" "apply" "$STAMP")"
SNAPSHOT_FILE="$(toolbox_snapshot_path "toolbox_git_hygiene_editor_backups" "pre_apply" "$STAMP")"

GITIGNORE_FILE="${TOOLBOX_APP}/.gitignore"

FILES_TO_REMOVE="
docs/operations/toolbox_logging_policy.md.save
scripts/admin/system/apply-toolbox-tbman-host-access.sh.save
scripts/admin/system/diagnose-toolbox-ergonomics-and-outputs.sh.save
scripts/admin/system/diagnose-toolbox-ergonomics-and-outputs.sh.save.1
"

IGNORE_RULES="
*.save
*.save.*
*.bak
*~
"

mkdir -p "$(dirname "$REPORT_FILE")"
mkdir -p "$(dirname "$TSV_FILE")"
mkdir -p "$(dirname "$SNAPSHOT_FILE")"

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
    printf 'Toolbox Git hygiene editor backup apply report\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Gitignore file: %s\n' "$GITIGNORE_FILE"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf 'Snapshot file: %s\n' "$SNAPSHOT_FILE"
    printf '\n'
    printf 'Scope:\n'
    printf '  remove only reviewed editor backup/temp files;\n'
    printf '  update .gitignore with editor backup rules if missing;\n'
    printf '  no git add;\n'
    printf '  no git commit;\n'
    printf '  no git rm;\n'
    printf '  no media/Stockhausen staging;\n'
    printf '  no generated outputs cleanup;\n'
    printf '  no Docker changes;\n'
    printf '  no shell configuration changes.\n'
    printf '\n'
    printf 'This script modifies files only after explicit APPLY confirmation.\n'
    printf 'Output destinations remain provisional and inherited from recent scripts.\n'
  } > "$REPORT_FILE"

  tsv_row "category" "item" "action" "status" "details" > "$TSV_FILE"
  tsv_row "path" "exists_before" "size_bytes_before" "sha256_before" "git_status_before" > "$SNAPSHOT_FILE"
}

git_required() {
  section "Git repository diagnosis"

  if git -C "$TOOLBOX_APP" rev-parse --show-toplevel >/tmp/toolbox-git-hygiene-apply-root.$$ 2>/tmp/toolbox-git-hygiene-apply-err.$$; then
    local root
    local branch

    root="$(cat /tmp/toolbox-git-hygiene-apply-root.$$)"
    branch="$(git -C "$TOOLBOX_APP" branch --show-current 2>/dev/null || printf 'UNKNOWN')"

    record "git" "repository" "root" "ok" "$root"
    record "git" "repository" "branch" "ok" "$branch"
  else
    local err
    err="$(cat /tmp/toolbox-git-hygiene-apply-err.$$ 2>/dev/null || printf 'unknown error')"
    record "git" "$TOOLBOX_APP" "repository" "fail" "$err"
    rm -f /tmp/toolbox-git-hygiene-apply-root.$$ /tmp/toolbox-git-hygiene-apply-err.$$
    fail "Not a Git repository: $TOOLBOX_APP"
  fi

  rm -f /tmp/toolbox-git-hygiene-apply-root.$$ /tmp/toolbox-git-hygiene-apply-err.$$
}

snapshot_file_state() {
  local path="$1"
  local full_path
  local size
  local sha
  local git_status

  full_path="${TOOLBOX_APP}/${path}"
  git_status="$(git -C "$TOOLBOX_APP" status --short -- "$path" 2>/dev/null | sed -n '1p')"

  if [ -e "$full_path" ]; then
    size="$(stat -c '%s' "$full_path" 2>/dev/null || printf 'UNKNOWN')"

    if [ -f "$full_path" ]; then
      sha="$(sha256sum "$full_path" 2>/dev/null | awk '{print $1}' || printf 'UNKNOWN')"
    else
      sha="-"
    fi

    tsv_row "$path" "yes" "$size" "$sha" "$git_status" >> "$SNAPSHOT_FILE"
  else
    tsv_row "$path" "no" "-" "-" "$git_status" >> "$SNAPSHOT_FILE"
  fi
}

write_pre_apply_snapshot() {
  section "Pre-apply snapshot"

  local path

  for path in $FILES_TO_REMOVE; do
    snapshot_file_state "$path"
    record "snapshot" "$path" "pre-apply snapshot" "recorded" "see snapshot TSV"
  done

  if [ -f "$GITIGNORE_FILE" ]; then
    local size
    local sha
    size="$(stat -c '%s' "$GITIGNORE_FILE" 2>/dev/null || printf 'UNKNOWN')"
    sha="$(sha256sum "$GITIGNORE_FILE" 2>/dev/null | awk '{print $1}' || printf 'UNKNOWN')"
    record "snapshot" ".gitignore" "pre-apply snapshot" "recorded" "size=${size}; sha256=${sha}"
  else
    record "snapshot" ".gitignore" "pre-apply snapshot" "missing" "will create .gitignore if APPLY confirmed"
  fi
}

show_plan() {
  section "Apply plan"

  printf '\n'
  printf 'This script will remove ONLY these reviewed editor backup/temp files if they exist:\n'
  printf '\n'

  {
    printf 'Files planned for removal:\n'
    printf '\n'
  } >> "$REPORT_FILE"

  local path
  for path in $FILES_TO_REMOVE; do
    printf '  %s\n' "$path"
    printf '  %s\n' "$path" >> "$REPORT_FILE"
    record "plan" "$path" "remove editor backup/temp file" "planned" "remove only after APPLY"
  done

  printf '\n'
  printf 'This script will also ensure these .gitignore rules exist:\n'
  printf '\n'

  {
    printf '\n.gitignore rules planned:\n'
    printf '\n'
  } >> "$REPORT_FILE"

  local rule
  for rule in $IGNORE_RULES; do
    printf '  %s\n' "$rule"
    printf '  %s\n' "$rule" >> "$REPORT_FILE"
    record "plan" "$rule" "ensure .gitignore rule" "planned" "append if missing"
  done

  printf '\n'
  printf 'It will NOT stage or commit anything.\n'
  printf 'It will NOT touch docs/media, scripts/media, Stockhausen, Soulseek or library scripts.\n'
  printf '\n'
}

validate_targets_are_safe() {
  section "Validate removal targets"

  local path
  local full_path

  for path in $FILES_TO_REMOVE; do
    full_path="${TOOLBOX_APP}/${path}"

    case "$path" in
      *.save|*.save.*|*.bak|*~|*.swp|*.tmp|.#*)
        record "safety" "$path" "filename pattern" "ok" "matches editor backup/temp pattern"
        ;;
      *)
        record "safety" "$path" "filename pattern" "fail" "does not match allowed backup/temp patterns"
        fail "Unsafe removal target: $path"
        ;;
    esac

    case "$path" in
      docs/media/*|scripts/media/*)
        record "safety" "$path" "media exclusion" "fail" "refusing to touch media path"
        fail "Refusing to touch media path in git hygiene: $path"
        ;;
      *)
        record "safety" "$path" "media exclusion" "ok" "not under docs/media or scripts/media"
        ;;
    esac

    if [ -e "$full_path" ]; then
      record "target" "$path" "exists" "ok" "will remove after APPLY"
    else
      record "target" "$path" "exists" "missing" "already absent; removal will be skipped"
    fi
  done
}

inspect_gitignore_before() {
  section ".gitignore before apply"

  if [ -f "$GITIGNORE_FILE" ]; then
    record "gitignore" ".gitignore" "exists" "ok" "$GITIGNORE_FILE"

    {
      printf '\nCurrent relevant .gitignore lines:\n'
      grep -nE '(\*\.save|\*\.save\.\*|\*\.bak|\*~)' "$GITIGNORE_FILE" 2>/dev/null || true
    } >> "$REPORT_FILE"
  else
    record "gitignore" ".gitignore" "exists" "missing" "will create if APPLY confirmed"
  fi
}

require_apply_confirmation() {
  local arg_confirmation="${1-}"
  local typed_confirmation

  if [ "$arg_confirmation" = "APPLY" ]; then
    record "confirmation" "APPLY" "argument confirmation" "ok" "fallback command-line confirmation used"
    return 0
  fi

  printf 'About to remove reviewed editor backup/temp files and update .gitignore.\n'
  printf 'This does NOT stage or commit anything.\n'
  printf 'Type APPLY to continue: '

  IFS= read -r typed_confirmation

  if [ "$typed_confirmation" = "APPLY" ]; then
    record "confirmation" "APPLY" "interactive confirmation" "ok" "user typed APPLY"
    return 0
  fi

  record "confirmation" "APPLY" "confirmation" "refused" "user did not type APPLY"
  printf 'Refusing to apply Git hygiene. Confirmation was not APPLY.\n' >&2
  exit 2
}

remove_backup_files() {
  section "Remove editor backup/temp files"

  local path
  local full_path

  for path in $FILES_TO_REMOVE; do
    full_path="${TOOLBOX_APP}/${path}"

    if [ -e "$full_path" ]; then
      rm -- "$full_path"
      record "remove" "$path" "rm" "ok" "removed"
    else
      record "remove" "$path" "rm" "skipped" "already absent"
    fi
  done
}

ensure_gitignore_rule() {
  local rule="$1"

  if [ ! -f "$GITIGNORE_FILE" ]; then
    printf '# Toolbox ignore rules\n' > "$GITIGNORE_FILE"
    record "gitignore" ".gitignore" "create" "ok" "created .gitignore"
  fi

  if grep -Fxq "$rule" "$GITIGNORE_FILE" 2>/dev/null; then
    record "gitignore" "$rule" "ensure rule" "skipped" "already present"
  else
    printf '%s\n' "$rule" >> "$GITIGNORE_FILE"
    record "gitignore" "$rule" "ensure rule" "ok" "appended"
  fi
}

update_gitignore() {
  section "Update .gitignore"

  local rule

  {
    printf '\n# Editor backup/temp files\n'
  } >> "$REPORT_FILE"

  for rule in $IGNORE_RULES; do
    ensure_gitignore_rule "$rule"
  done
}

validate_after_apply() {
  section "Post-apply validation"

  local path
  local full_path
  local absent_count
  local present_count

  absent_count=0
  present_count=0

  for path in $FILES_TO_REMOVE; do
    full_path="${TOOLBOX_APP}/${path}"

    if [ -e "$full_path" ]; then
      present_count=$((present_count + 1))
      record "validate" "$path" "removed" "fail" "file still exists"
    else
      absent_count=$((absent_count + 1))
      record "validate" "$path" "removed" "ok" "absent"
    fi
  done

  for rule in $IGNORE_RULES; do
    if grep -Fxq "$rule" "$GITIGNORE_FILE" 2>/dev/null; then
      record "validate" "$rule" ".gitignore rule present" "ok" "found"
    else
      record "validate" "$rule" ".gitignore rule present" "fail" "missing"
    fi
  done

  record "validate" "removed files" "count" "recorded" "absent=${absent_count}; present=${present_count}"
}

write_git_status_after() {
  section "Git status after apply"

  {
    cd "$TOOLBOX_APP" || exit 0
    git status --short
  } >> "$REPORT_FILE" 2>&1

  record "git" "working tree" "post-apply status" "recorded" "see report"
}

write_next_commands() {
  section "Next commands"

  {
    printf 'Review .gitignore change:\n'
    printf '\n'
    printf '  cd /srv/toolbox/app || exit 1\n'
    printf '  git diff -- .gitignore\n'
    printf '  git status --short\n'
    printf '\n'
    printf 'If correct, stage and commit hygiene scripts/.gitignore explicitly:\n'
    printf '\n'
    printf '  git add .gitignore \\\n'
    printf '    scripts/admin/git/plan-toolbox-git-hygiene-editor-backups.sh \\\n'
    printf '    scripts/admin/git/apply-toolbox-git-hygiene-editor-backups.sh\n'
    printf '  git diff --cached --stat\n'
    printf '  git commit -m "chore(git): ignore editor backup files"\n'
    printf '\n'
    printf 'Do not stage docs/media or scripts/media in this hygiene commit.\n'
  } >> "$REPORT_FILE"

  record "next-step" "git hygiene commit" "manual review" "recorded" "see report"
}

write_summary() {
  local fail_count
  local missing_count

  section "Summary"

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "fail" {count++} END {print count+0}' "$TSV_FILE")"
  missing_count="$(awk -F '\t' 'NR > 1 && $4 == "missing" {count++} END {print count+0}' "$TSV_FILE")"

  {
    printf 'Failed checks: %s\n' "$fail_count"
    printf 'Missing checks: %s\n' "$missing_count"
    printf '\n'
    printf 'Generated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  TSV: %s\n' "$TSV_FILE"
    printf '  Snapshot: %s\n' "$SNAPSHOT_FILE"
    printf '\n'
    printf 'Files intentionally removed if present:\n'
    local path
    for path in $FILES_TO_REMOVE; do
      printf '  %s\n' "$path"
    done
    printf '\n'
    printf '.gitignore was updated only after APPLY confirmation.\n'
    printf 'No Git staging or commit was performed.\n'
  } >> "$REPORT_FILE"

  if [ "$fail_count" -eq 0 ]; then
    record "summary" "git-hygiene-editor-backups" "failed checks" "ok" "fail_count=0"
  else
    record "summary" "git-hygiene-editor-backups" "failed checks" "fail" "fail_count=${fail_count}"
  fi
}

main() {
  write_headers

  log "Preparing Toolbox Git hygiene apply for editor backup/temp files."
  log "Report: $REPORT_FILE"
  log "TSV: $TSV_FILE"
  log "Snapshot: $SNAPSHOT_FILE"

  git_required
  write_pre_apply_snapshot
  show_plan
  validate_targets_are_safe
  inspect_gitignore_before
  require_apply_confirmation "${1-}"
  remove_backup_files
  update_gitignore
  validate_after_apply
  write_git_status_after
  write_next_commands
  write_summary

  log "Git hygiene apply completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"
  log "Snapshot: $SNAPSHOT_FILE"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report: %s\n' "$REPORT_FILE"
  printf '  TSV:          %s\n' "$TSV_FILE"
  printf '  Snapshot:     %s\n' "$SNAPSHOT_FILE"
  printf '\n'
  printf 'Review with:\n'
  printf '  cd /srv/toolbox/app || exit 1\n'
  printf '  git diff -- .gitignore\n'
  printf '  git status --short\n'
}

main "$@"
