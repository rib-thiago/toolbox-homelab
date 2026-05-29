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

REPORT="$REPORT_DIR/toolbox_git_post_commit_report_$STAMP.txt"
TSV="$RAW_DIR/toolbox_git_post_commit_$STAMP.tsv"

DO_PUSH="no"
LOG_COUNT="6"

usage() {
  cat <<'EOF'
Usage:
  apply-toolbox-git-post-commit.sh
  apply-toolbox-git-post-commit.sh --push
  apply-toolbox-git-post-commit.sh --push --log-count 10

Behavior:
  - with --push, asks for PUSH before git push;
  - always runs post-commit checks:
      git status --short
      git branch -vv
      git --no-pager log --oneline -N
      git remote -v
  - writes report and TSV.
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
      --push)
        DO_PUSH="yes"
        ;;
      --log-count)
        shift
        if [ "$#" -eq 0 ]; then
          fail "Missing value for --log-count."
        fi
        LOG_COUNT="$1"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "Unknown argument: $1"
        ;;
    esac
    shift || true
  done
}

validate_log_count() {
  case "$LOG_COUNT" in
    ''|*[!0-9]*)
      fail "--log-count must be a positive integer."
      ;;
    *)
      if [ "$LOG_COUNT" -lt 1 ]; then
        fail "--log-count must be greater than zero."
      fi
      ;;
  esac
}

maybe_push() {
  local confirmation
  local push_status

  if [ "$DO_PUSH" != "yes" ]; then
    write_step "PUSH" "push" "origin/upstream" "SKIP" "push not requested" "use --push"
    return 0
  fi

  append_command "Remote configuration before push" git remote -v || true
  append_command "Branch tracking before push" git branch -vv || true

  printf '%s\n' "About to run: git push"
  printf '%s' "Type PUSH to continue: "
  read -r confirmation

  if [ "$confirmation" != "PUSH" ]; then
    write_step "PUSH" "push" "git push" "ABORTED" "user did not confirm PUSH" ""
    log "Push aborted by user."
    return 2
  fi

  set +e
  git push >> "$REPORT" 2>&1
  push_status="$?"
  set -e

  if [ "$push_status" -eq 0 ]; then
    write_step "PUSH" "push" "git push" "OK" "git push completed" ""
    return 0
  fi

  write_step "PUSH" "push" "git push" "FAIL" "git push failed" "exit=$push_status"
  return 1
}

post_checks() {
  local status_short
  local current_branch
  local upstream

  append_command "Git status short" git status --short || true
  append_command "Git branch verbose" git branch -vv || true
  append_command "Recent log" git --no-pager log --oneline "-$LOG_COUNT" || true
  append_command "Git remotes" git remote -v || true

  status_short="$(git status --short)"
  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"

  if [ -z "$status_short" ]; then
    write_step "STATUS" "validate" "working tree" "OK" "working tree clean" ""
  else
    write_step "STATUS" "validate" "working tree" "WARN" "working tree has changes" "$status_short"
  fi

  if [ -n "$upstream" ]; then
    write_step "UPSTREAM" "validate" "$current_branch" "OK" "upstream configured" "$upstream"
  else
    write_step "UPSTREAM" "validate" "$current_branch" "WARN" "upstream not configured" ""
  fi
}

main() {
  local push_result

  require_lib_contract
  parse_args "$@"
  validate_log_count

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  tsv_row \
    "step_id" \
    "phase" \
    "target" \
    "status" \
    "action" \
    "notes" > "$TSV"

  {
    printf '%s\n' '# Toolbox Git Post-Commit Routine'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Repository: %s\n' "$(pwd)"
    printf 'Push requested: %s\n' "$DO_PUSH"
    printf 'Log count: %s\n' "$LOG_COUNT"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
  } > "$REPORT"

  log "Starting Git post-commit routine."

  set +e
  maybe_push
  push_result="$?"
  set -e

  if [ "$push_result" -eq 1 ]; then
    post_checks
    log "Git post-commit routine completed with push failure."
    log "Report: $REPORT"
    log "TSV: $TSV"
    exit 1
  fi

  post_checks

  log "Git post-commit routine completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
