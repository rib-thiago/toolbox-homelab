#!/usr/bin/env bash
set -u

APP_DIR="/srv/toolbox/app"
LIB_DIR="$APP_DIR/scripts/lib"

source "$LIB_DIR/logging.sh"
source "$LIB_DIR/timestamps.sh"
source "$LIB_DIR/tsv.sh"
source "$LIB_DIR/paths.sh"

STAMP="$(toolbox_timestamp)"
SHARED_DIR="$(toolbox_shared_dir)"

REPORT_DIR="$SHARED_DIR/reports/git"
RAW_DIR="$SHARED_DIR/library-db/raw/git"

REPORT="$REPORT_DIR/toolbox_git_stage_check_commit_report_$STAMP.txt"
TSV="$RAW_DIR/toolbox_git_stage_check_commit_$STAMP.tsv"

COMMIT_MESSAGE=""
FILES=()

usage() {
  cat <<'EOF'
Usage:
  apply-toolbox-git-stage-check-commit.sh -m "commit message" -- file1 file2 ...
  apply-toolbox-git-stage-check-commit.sh

Interactive mode:
  If no files/message are provided, the script asks for them.

Safety:
  - stages only the files provided;
  - runs bash -n on staged .sh files;
  - runs git diff --cached --stat;
  - runs git diff --cached --check;
  - asks for COMMIT before git commit;
  - does not push.
EOF
}

require_function() {
  local fn="$1"

  if ! declare -F "$fn" >/dev/null 2>&1; then
    printf '%s\n' "[ERRO] Required function not found: $fn" >&2
    exit 1
  fi
}

require_lib_contract() {
  require_function log
  require_function fail
  require_function toolbox_timestamp
  require_function toolbox_now
  require_function toolbox_shared_dir
  require_function tsv_row
}

write_step() {
  local step_id="$1"
  local phase="$2"
  local target="$3"
  local status="$4"
  local action="$5"
  local notes="$6"

  tsv_row "$step_id" "$phase" "$target" "$status" "$action" "$notes" >> "$TSV"
}

append_command() {
  local title="$1"
  shift

  {
    printf '\n'
    printf '## %s\n' "$title"
    printf '\n'
    printf '%s\n' '```text'
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
  } >> "$REPORT"

  if "$@" >> "$REPORT" 2>&1; then
    printf '\n%s\n' '[OK]' >> "$REPORT"
    printf '%s\n' '```' >> "$REPORT"
    return 0
  fi

  printf '\n%s\n' '[FAIL]' >> "$REPORT"
  printf '%s\n' '```' >> "$REPORT"
  return 1
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -m|--message)
        shift
        if [ "$#" -eq 0 ]; then
          fail "Missing value for -m/--message."
        fi
        COMMIT_MESSAGE="$1"
        ;;
      --)
        shift
        while [ "$#" -gt 0 ]; do
          FILES+=("$1")
          shift
        done
        break
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        FILES+=("$1")
        ;;
    esac
    shift || true
  done
}

interactive_inputs() {
  local line

  if [ -z "$COMMIT_MESSAGE" ]; then
    printf '%s' "Commit message: "
    read -r COMMIT_MESSAGE
  fi

  if [ "${#FILES[@]}" -eq 0 ]; then
    printf '%s\n' "Enter files to stage, one per line. Blank line finishes."
    while true; do
      printf '%s' "file> "
      read -r line
      if [ -z "$line" ]; then
        break
      fi
      FILES+=("$line")
    done
  fi

  if [ -z "$COMMIT_MESSAGE" ]; then
    fail "Commit message cannot be empty."
  fi

  if [ "${#FILES[@]}" -eq 0 ]; then
    fail "No files provided."
  fi
}

validate_files_exist() {
  local file
  local failures=0

  for file in "${FILES[@]}"; do
    if [ -e "$file" ]; then
      write_step "PRE-FILE" "preflight" "$file" "OK" "file exists" ""
    else
      write_step "PRE-FILE" "preflight" "$file" "FAIL" "file missing" ""
      failures=$((failures + 1))
    fi
  done

  if [ "$failures" -gt 0 ]; then
    fail "One or more files are missing."
  fi
}

bash_check_staged_shell_files() {
  local file
  local failures=0

  while IFS= read -r file; do
    case "$file" in
      *.sh)
        if [ -f "$file" ]; then
          if bash -n "$file"; then
            write_step "BASH-N" "check" "$file" "OK" "bash -n passed" ""
          else
            write_step "BASH-N" "check" "$file" "FAIL" "bash -n failed" ""
            failures=$((failures + 1))
          fi
        else
          write_step "BASH-N" "check" "$file" "WARN" "staged shell file not present in working tree" ""
        fi
        ;;
    esac
  done < <(git diff --cached --name-only --diff-filter=ACMR)

  if [ "$failures" -gt 0 ]; then
    return 1
  fi

  return 0
}

main() {
  local confirmation
  local staged_count
  local diff_check_output
  local commit_status

  require_lib_contract
  parse_args "$@"
  interactive_inputs

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  tsv_row \
    "step_id" \
    "phase" \
    "target" \
    "status" \
    "action" \
    "notes" > "$TSV"

  {
    printf '%s\n' '# Toolbox Git Stage / Check / Commit'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Repository: %s\n' "$(pwd)"
    printf 'Commit message: %s\n' "$COMMIT_MESSAGE"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: stages provided files only, checks staged content, asks for COMMIT, does not push.'
    printf '\n'
  } > "$REPORT"

  log "Starting Git stage/check/commit routine."

  validate_files_exist

  append_command "Git status before staging" git status --short || true

  git add -- "${FILES[@]}"
  write_step "GIT-ADD" "stage" "provided files" "OK" "git add completed" "${FILES[*]}"

  staged_count="$(git diff --cached --name-only | wc -l | tr -d ' ')"

  if [ "$staged_count" -eq 0 ]; then
    write_step "STAGED" "check" "index" "FAIL" "no staged changes" ""
    fail "No staged changes after git add."
  fi

  write_step "STAGED" "check" "index" "OK" "staged changes detected" "$staged_count files"

  if bash_check_staged_shell_files; then
    write_step "BASH-N-SUMMARY" "check" "staged shell files" "OK" "shell syntax checks passed" ""
  else
    write_step "BASH-N-SUMMARY" "check" "staged shell files" "FAIL" "shell syntax checks failed" ""
    fail "bash -n failed for at least one staged shell script."
  fi

  append_command "Git diff cached stat" git diff --cached --stat || true

  diff_check_output="$(git diff --cached --check 2>&1 || true)"
  {
    printf '\n'
    printf '%s\n' '## Git diff cached check'
    printf '\n'
    printf '%s\n' '```text'
    printf '%s\n' "$diff_check_output"
    printf '%s\n' '```'
  } >> "$REPORT"

  if [ -n "$diff_check_output" ]; then
    write_step "DIFF-CHECK" "check" "git diff --cached --check" "FAIL" "whitespace/conflict check failed" "$diff_check_output"
    fail "git diff --cached --check reported problems."
  fi

  write_step "DIFF-CHECK" "check" "git diff --cached --check" "OK" "no whitespace/conflict issues" ""

  printf '%s\n' "Review before commit:"
  git diff --cached --stat
  printf '\n'
  git diff --cached --check
  printf '\n'
  printf '%s\n' "Commit message: $COMMIT_MESSAGE"
  printf '%s' "Type COMMIT to create the commit: "
  read -r confirmation

  if [ "$confirmation" != "COMMIT" ]; then
    write_step "COMMIT" "commit" "user confirmation" "ABORTED" "user did not confirm COMMIT" ""
    log "Commit aborted by user."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 2
  fi

  set +e
  git commit -m "$COMMIT_MESSAGE" >> "$REPORT" 2>&1
  commit_status="$?"
  set -e

  if [ "$commit_status" -eq 0 ]; then
    write_step "COMMIT" "commit" "$COMMIT_MESSAGE" "OK" "git commit completed" ""
  else
    write_step "COMMIT" "commit" "$COMMIT_MESSAGE" "FAIL" "git commit failed" "exit=$commit_status"
    fail "git commit failed. See report: $REPORT"
  fi

  append_command "Git status after commit" git status --short || true
  append_command "Recent log" git --no-pager log --oneline -5 || true

  log "Git stage/check/commit routine completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
