#!/usr/bin/env bash
set -u

# Plan Toolbox Git hygiene for editor backup/temp files.
#
# This script does not delete files.
# It does not modify .gitignore.
# It does not run git add, git rm, or git commit.
#
# It identifies editor backup/temp files such as:
#   *.save
#   *.save.*
#   *.bak
#   *~
#   .#*
#
# Preferred next step after this diagnosis:
#   review report, then create an APPLY script if removal/.gitignore update is approved.

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

REPORT_FILE="$(toolbox_report_path "toolbox_git_hygiene_editor_backups" "plan" "$STAMP")"
TSV_FILE="$(toolbox_tsv_path "toolbox_git_hygiene_editor_backups" "plan" "$STAMP")"

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
    printf 'Toolbox Git hygiene editor backup planning report\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope:\n'
    printf '  diagnose editor backup/temp files inside Toolbox repo;\n'
    printf '  classify files that should not be committed;\n'
    printf '  inspect .gitignore state;\n'
    printf '  propose cleanup plan;\n'
    printf '  no deletion;\n'
    printf '  no git add;\n'
    printf '  no git rm;\n'
    printf '  no git commit;\n'
    printf '  no .gitignore modification;\n'
    printf '  no media/Stockhausen staging.\n'
    printf '\n'
    printf 'Output destinations remain provisional and inherited from recent scripts.\n'
  } > "$REPORT_FILE"

  tsv_row "category" "item" "action" "status" "details" > "$TSV_FILE"
}

git_required() {
  section "Git repository diagnosis"

  if git -C "$TOOLBOX_APP" rev-parse --show-toplevel >/tmp/toolbox-git-hygiene-root.$$ 2>/tmp/toolbox-git-hygiene-err.$$; then
    local root
    local branch

    root="$(cat /tmp/toolbox-git-hygiene-root.$$)"
    branch="$(git -C "$TOOLBOX_APP" branch --show-current 2>/dev/null || printf 'UNKNOWN')"

    record "git" "repository" "root" "ok" "$root"
    record "git" "repository" "branch" "ok" "$branch"
  else
    local err
    err="$(cat /tmp/toolbox-git-hygiene-err.$$ 2>/dev/null || printf 'unknown error')"
    record "git" "$TOOLBOX_APP" "repository" "fail" "$err"
    rm -f /tmp/toolbox-git-hygiene-root.$$ /tmp/toolbox-git-hygiene-err.$$
    fail "Not a Git repository: $TOOLBOX_APP"
  fi

  rm -f /tmp/toolbox-git-hygiene-root.$$ /tmp/toolbox-git-hygiene-err.$$
}

write_status() {
  section "Current Git status"

  {
    cd "$TOOLBOX_APP" || exit 0
    git status --short
  } >> "$REPORT_FILE" 2>&1

  record "git" "working tree" "git status --short" "recorded" "see report"
}

inspect_gitignore() {
  section ".gitignore diagnosis"

  local gitignore
  gitignore="${TOOLBOX_APP}/.gitignore"

  if [ -f "$gitignore" ]; then
    local size
    local lines
    size="$(stat -c '%s' "$gitignore" 2>/dev/null || printf 'UNKNOWN')"
    lines="$(wc -l < "$gitignore" 2>/dev/null | tr -d ' ' || printf 'UNKNOWN')"

    record "gitignore" ".gitignore" "exists" "ok" "size=${size} lines=${lines}"

    {
      printf '\nCurrent .gitignore relevant lines:\n'
      grep -nE '(\.save|\.bak|\*~|#\*)' "$gitignore" 2>/dev/null || true
    } >> "$REPORT_FILE"

    if grep -Eq '(^|/|\*)\.save($|\.|\*)' "$gitignore" 2>/dev/null; then
      record "gitignore" ".gitignore" "covers .save" "ok" "existing .save-like rule found"
    else
      record "gitignore" ".gitignore" "covers .save" "missing" "no .save rule found"
    fi

    if grep -Eq '(^|/|\*)\.bak($|\.|\*)' "$gitignore" 2>/dev/null; then
      record "gitignore" ".gitignore" "covers .bak" "ok" "existing .bak-like rule found"
    else
      record "gitignore" ".gitignore" "covers .bak" "missing" "no .bak rule found"
    fi

    if grep -Fq '*~' "$gitignore" 2>/dev/null; then
      record "gitignore" ".gitignore" "covers editor tilde backups" "ok" "existing *~ rule found"
    else
      record "gitignore" ".gitignore" "covers editor tilde backups" "missing" "no *~ rule found"
    fi
  else
    record "gitignore" ".gitignore" "exists" "missing" "no .gitignore found at repo root"
  fi
}

classify_backup_file() {
  local path="$1"
  local full_path
  local size
  local sha
  local git_status
  local recommendation

  full_path="${TOOLBOX_APP}/${path}"
  size="$(stat -c '%s' "$full_path" 2>/dev/null || printf 'UNKNOWN')"
  sha="$(sha256sum "$full_path" 2>/dev/null | awk '{print $1}' || printf 'UNKNOWN')"
  git_status="$(git -C "$TOOLBOX_APP" status --short -- "$path" 2>/dev/null | sed -n '1p')"

  recommendation="remove-after-review"

  case "$path" in
    *.save|*.save.*|*.bak|*~|*.swp|*.tmp)
      recommendation="remove-after-review"
      ;;
    .#*)
      recommendation="remove-after-review"
      ;;
  esac

  record "backup-file" "$path" "classify" "exclude" "git_status=${git_status}; size=${size}; sha256=${sha}; recommendation=${recommendation}"
}

scan_editor_backups() {
  section "Editor backup/temp file scan"

  local found
  found="no"

  {
    cd "$TOOLBOX_APP" || exit 0
    find . \
      \( -name '*.save' -o -name '*.save.*' -o -name '*.bak' -o -name '*~' -o -name '.#*' -o -name '*.swp' -o -name '*.tmp' \) \
      -print 2>/dev/null | sort
  } >/tmp/toolbox-git-hygiene-backups.$$

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    found="yes"
    path="${path#./}"
    classify_backup_file "$path"
  done < /tmp/toolbox-git-hygiene-backups.$$

  rm -f /tmp/toolbox-git-hygiene-backups.$$

  if [ "$found" = "no" ]; then
    record "backup-file" "editor backups" "scan" "ok" "no editor backup/temp files found"
  fi
}

scan_staged_backups() {
  section "Check staged backup/temp files"

  local found
  found="no"

  {
    cd "$TOOLBOX_APP" || exit 0
    git diff --cached --name-only 2>/dev/null
  } >/tmp/toolbox-git-hygiene-staged.$$

  while IFS= read -r path; do
    [ -n "$path" ] || continue

    case "$path" in
      *.save|*.save.*|*.bak|*~|.#*|*.swp|*.tmp)
        found="yes"
        record "staged-backup" "$path" "staged check" "fail" "backup/temp file is staged"
        ;;
    esac
  done < /tmp/toolbox-git-hygiene-staged.$$

  rm -f /tmp/toolbox-git-hygiene-staged.$$

  if [ "$found" = "no" ]; then
    record "staged-backup" "staged backup/temp files" "staged check" "ok" "no backup/temp files staged"
  fi
}

write_cleanup_plan() {
  section "Proposed cleanup plan"

  {
    printf 'Recommended next steps:\n'
    printf '\n'
    printf '1. Review this report.\n'
    printf '2. If all listed backup/temp files are editor artifacts, create an APPLY cleanup script.\n'
    printf '3. The cleanup apply script should:\n'
    printf '   - show files to remove;\n'
    printf '   - create a pre-delete snapshot TSV;\n'
    printf '   - require interactive APPLY;\n'
    printf '   - remove only listed backup/temp files;\n'
    printf '   - optionally update .gitignore with:\n'
    printf '       *.save\n'
    printf '       *.save.*\n'
    printf '       *.bak\n'
    printf '       *~\n'
    printf '   - validate git status afterward.\n'
    printf '\n'
    printf 'Do not touch docs/media, scripts/media, Stockhausen, Soulseek, or library scripts in this hygiene step.\n'
  } >> "$REPORT_FILE"

  record "plan" "cleanup" "next step" "proposed" "create APPLY script after review"
  record "plan" ".gitignore" "possible update" "proposed" "add .save/.save.*/*.bak/*~ rules if absent"
}

write_summary() {
  local backup_count
  local fail_count
  local missing_count

  section "Summary"

  backup_count="$(awk -F '\t' 'NR > 1 && $1 == "backup-file" && $4 == "exclude" {count++} END {print count+0}' "$TSV_FILE")"
  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "fail" {count++} END {print count+0}' "$TSV_FILE")"
  missing_count="$(awk -F '\t' 'NR > 1 && $4 == "missing" {count++} END {print count+0}' "$TSV_FILE")"

  {
    printf 'Backup/temp files found: %s\n' "$backup_count"
    printf 'Failed checks: %s\n' "$fail_count"
    printf 'Missing checks: %s\n' "$missing_count"
    printf '\n'
    printf 'Generated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  TSV: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'No files were modified except this planning report and TSV.\n'
    printf '\n'
    printf 'Next recommended step:\n'
    printf '  review this plan, then create an APPLY cleanup script for editor backups and optional .gitignore update.\n'
  } >> "$REPORT_FILE"

  record "summary" "git-hygiene-editor-backups" "planning completed" "recorded" "backup_count=${backup_count}; fail_count=${fail_count}; missing_count=${missing_count}"
}

main() {
  write_headers

  log "Planning Toolbox Git hygiene for editor backup/temp files."
  log "Report: $REPORT_FILE"
  log "TSV: $TSV_FILE"

  git_required
  write_status
  inspect_gitignore
  scan_editor_backups
  scan_staged_backups
  write_cleanup_plan
  write_summary

  log "Git hygiene planning completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report: %s\n' "$REPORT_FILE"
  printf '  TSV:          %s\n' "$TSV_FILE"
}

main "$@"
