#!/usr/bin/env bash
set -u

APP_DIR="${APP_DIR:-/srv/toolbox/app}"
LIB_DIR="$APP_DIR/scripts/lib"

source "$LIB_DIR/logging.sh"
source "$LIB_DIR/timestamps.sh"
source "$LIB_DIR/paths.sh"

STAMP="$(toolbox_timestamp)"
SHARED_DIR="$(toolbox_shared_dir)"

REPORT_DIR="$SHARED_DIR/reports/system"
RAW_DIR="$SHARED_DIR/library-db/raw/system"

REPORT="$REPORT_DIR/codex_cli_readiness_report_$STAMP.txt"
TSV="$RAW_DIR/codex_cli_readiness_$STAMP.tsv"

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
INFO_COUNT=0

OFFICIAL_INSTALL_URL="https://chatgpt.com/codex/install.sh"
CODEX_RUNBOOK="knowledge/runbooks/codex-read-only-first-run.md"

ensure_output_dirs() {
  mkdir -p "$REPORT_DIR" "$RAW_DIR"
}

tsv_escape() {
  local value="${1:-}"
  printf '%s' "$value" | tr '\t\r\n' '   '
}

write_tsv_header() {
  printf 'timestamp\tstatus\tcheck_id\tpath\tdetail\n' > "$TSV"
}

record() {
  local status="$1"
  local check_id="$2"
  local path="$3"
  local detail="$4"
  local now

  now="$(toolbox_now)"

  case "$status" in
    OK)
      OK_COUNT=$((OK_COUNT + 1))
      ;;
    WARN)
      WARN_COUNT=$((WARN_COUNT + 1))
      ;;
    FAIL)
      FAIL_COUNT=$((FAIL_COUNT + 1))
      ;;
    INFO)
      INFO_COUNT=$((INFO_COUNT + 1))
      ;;
    *)
      status="FAIL"
      FAIL_COUNT=$((FAIL_COUNT + 1))
      detail="Invalid validation status"
      ;;
  esac

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$(tsv_escape "$now")" \
    "$(tsv_escape "$status")" \
    "$(tsv_escape "$check_id")" \
    "$(tsv_escape "$path")" \
    "$(tsv_escape "$detail")" >> "$TSV"

  printf '[%s] %-5s %-58s %s\n' "$check_id" "$status" "$path" "$detail" >> "$REPORT"
}

write_report_header() {
  {
    printf '# Codex CLI readiness diagnosis\n\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'App dir: %s\n' "$APP_DIR"
    printf 'Shared dir: %s\n' "$SHARED_DIR"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n\n' "$TSV"

    printf '## Purpose\n\n'
    printf 'This read-only diagnostic checks whether the homelab host and Toolbox repo are ready for Codex CLI installation and first-run planning.\n\n'
    printf 'It does not install Codex, does not execute the installer, does not authenticate, does not edit files, does not inspect secrets, and does not modify Git state.\n\n'

    printf '## Official installer reference\n\n'
    printf 'Expected official standalone installer URL for later human-approved installation:\n\n'
    printf -- '- %s\n\n' "$OFFICIAL_INSTALL_URL"
  } > "$REPORT"
}

write_report_summary() {
  {
    printf '\n## Summary\n\n'
    printf 'OK: %s\n' "$OK_COUNT"
    printf 'WARN: %s\n' "$WARN_COUNT"
    printf 'FAIL: %s\n' "$FAIL_COUNT"
    printf 'INFO: %s\n' "$INFO_COUNT"
    printf '\n'
  } >> "$REPORT"
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
}

check_app_dir() {
  if [ -d "$APP_DIR" ]; then
    record "OK" "app_dir" "$APP_DIR" "Toolbox app directory exists"
  else
    record "FAIL" "app_dir" "$APP_DIR" "Toolbox app directory is missing"
  fi
}

check_git_repo() {
  if [ ! -d "$APP_DIR/.git" ]; then
    record "FAIL" "git_repo" "$APP_DIR" "not a Git repository"
    return 0
  fi

  record "OK" "git_repo" "$APP_DIR" "Git repository exists"

  local status
  status="$(cd "$APP_DIR" && git status --short)"

  if [ -z "$status" ]; then
    record "OK" "git_status" "$APP_DIR" "working tree clean"
  else
    record "WARN" "git_status" "$APP_DIR" "working tree has pending changes"
    {
      printf '\n## Git status --short\n\n'
      printf '%s\n' "$status"
    } >> "$REPORT"
  fi
}

check_system_identity() {
  {
    printf '\n## System identity\n\n'
    printf 'uname -a:\n'
    uname -a
    printf '\n'
    printf 'os-release:\n'
    if [ -f /etc/os-release ]; then
      cat /etc/os-release
    else
      printf 'missing /etc/os-release\n'
    fi
    printf '\n'
    printf 'architecture: %s\n' "$(uname -m)"
    printf 'user: %s\n' "$(id -un 2>/dev/null || true)"
    printf 'uid/gid: %s\n' "$(id 2>/dev/null || true)"
    printf 'shell: %s\n' "${SHELL:-unknown}"
  } >> "$REPORT"

  record "INFO" "system" "$(hostname 2>/dev/null || printf unknown)" "system identity recorded in report"
}

check_architecture() {
  local arch
  arch="$(uname -m)"

  case "$arch" in
    x86_64|aarch64|arm64)
      record "OK" "architecture" "$arch" "architecture appears compatible with typical Codex CLI Linux support"
      ;;
    *)
      record "WARN" "architecture" "$arch" "architecture may need manual compatibility review"
      ;;
  esac
}

check_command_exists() {
  local cmd="$1"
  local required="$2"
  local path

  if path="$(command -v "$cmd" 2>/dev/null)"; then
    record "OK" "command" "$cmd" "found at $path"
  else
    if [ "$required" = "required" ]; then
      record "FAIL" "command" "$cmd" "required command not found"
    else
      record "WARN" "command" "$cmd" "optional command not found"
    fi
  fi
}

check_basic_commands() {
  check_command_exists sh required
  check_command_exists bash required
  check_command_exists curl required
  check_command_exists git required
  check_command_exists sed required
  check_command_exists grep required
  check_command_exists awk required
  check_command_exists find required
  check_command_exists head required
  check_command_exists tail required
  check_command_exists sort required
}

check_optional_install_tools() {
  check_command_exists node optional
  check_command_exists npm optional
  check_command_exists brew optional
}

check_versions() {
  {
    printf '\n## Command versions\n\n'

    printf 'bash:\n'
    bash --version 2>/dev/null | head -2 || true
    printf '\n'

    printf 'curl:\n'
    curl --version 2>/dev/null | head -3 || true
    printf '\n'

    printf 'git:\n'
    git --version 2>/dev/null || true
    printf '\n'

    printf 'node:\n'
    node --version 2>/dev/null || true
    printf '\n'

    printf 'npm:\n'
    npm --version 2>/dev/null || true
    printf '\n'
  } >> "$REPORT"

  record "INFO" "versions" "commands" "command versions recorded in report"
}

check_existing_codex() {
  local path
  if path="$(command -v codex 2>/dev/null)"; then
    record "WARN" "existing_codex" "$path" "codex command already exists; inspect before installing or reinstalling"

    {
      printf '\n## Existing Codex command\n\n'
      printf 'Path: %s\n\n' "$path"
      printf 'codex --version:\n'
      codex --version 2>/dev/null || true
      printf '\n'
      printf 'file information:\n'
      file "$path" 2>/dev/null || true
      printf '\n'
      printf 'symlink resolution:\n'
      readlink -f "$path" 2>/dev/null || true
      printf '\n'
    } >> "$REPORT"
  else
    record "OK" "existing_codex" "codex" "codex command not currently installed in PATH"
  fi
}

check_path() {
  {
    printf '\n## PATH\n\n'
    printf '%s\n' "$PATH" | tr ':' '\n'
  } >> "$REPORT"

  record "INFO" "path" "PATH" "PATH recorded in report"
}

check_shell_profile_hints() {
  local home_dir
  home_dir="${HOME:-}"

  if [ -z "$home_dir" ] || [ ! -d "$home_dir" ]; then
    record "WARN" "home" "HOME" "HOME is unset or not a directory"
    return 0
  fi

  {
    printf '\n## Shell profile hints\n\n'
    for f in \
      "$home_dir/.bashrc" \
      "$home_dir/.profile" \
      "$home_dir/.bash_profile" \
      "$home_dir/.bash_aliases" \
      "$home_dir/.bashrc.d" \
      "$home_dir/.bash_aliases.d"
    do
      if [ -e "$f" ]; then
        printf 'exists: %s\n' "$f"
      else
        printf 'missing: %s\n' "$f"
      fi
    done
  } >> "$REPORT"

  record "INFO" "shell_profiles" "$home_dir" "shell profile hints recorded without reading secrets"
}

check_codex_config_locations() {
  local home_dir
  home_dir="${HOME:-}"

  if [ -z "$home_dir" ] || [ ! -d "$home_dir" ]; then
    return 0
  fi

  {
    printf '\n## Existing Codex-related config path hints\n\n'
    for d in \
      "$home_dir/.codex" \
      "$home_dir/.config/codex" \
      "$home_dir/.cache/codex" \
      "$home_dir/.local/bin"
    do
      if [ -e "$d" ]; then
        printf 'exists: %s\n' "$d"
      else
        printf 'missing: %s\n' "$d"
      fi
    done
  } >> "$REPORT"

  record "INFO" "codex_config_hints" "HOME" "Codex-related config path existence recorded without reading contents"
}

check_installer_reachability() {
  if ! command -v curl >/dev/null 2>&1; then
    record "WARN" "installer_reachability" "$OFFICIAL_INSTALL_URL" "curl missing; cannot test installer reachability"
    return 0
  fi

  local status
  status="$(curl -fsSIL --max-time 10 "$OFFICIAL_INSTALL_URL" >/dev/null 2>&1; printf '%s' "$?")"

  if [ "$status" = "0" ]; then
    record "OK" "installer_reachability" "$OFFICIAL_INSTALL_URL" "official installer URL reachable with HEAD request"
  else
    record "WARN" "installer_reachability" "$OFFICIAL_INSTALL_URL" "could not confirm installer URL reachability; network or TLS may need review"
  fi
}

check_runbook_exists() {
  if [ -f "$APP_DIR/$CODEX_RUNBOOK" ]; then
    record "OK" "codex_runbook" "$CODEX_RUNBOOK" "Codex read-only first-run runbook exists"
  else
    record "FAIL" "codex_runbook" "$CODEX_RUNBOOK" "Codex read-only first-run runbook is missing"
  fi
}

check_required_knowledge_files() {
  local files=(
    "knowledge/context/agent-entrypoint.md"
    "knowledge/context/homelab-context.md"
    "knowledge/context/toolbox-context.md"
    "knowledge/policies/agent-safety-policy.md"
    "knowledge/policies/change-management-policy.md"
    "knowledge/policies/reporting-policy.md"
    "knowledge/policies/filesystem-safety-policy.md"
    "knowledge/policies/media-curation-policy.md"
    "knowledge/policies/architecture-knowledge-policy.md"
    "knowledge/services/README.md"
    "knowledge/architecture/historical-operational-lessons.md"
    "knowledge/architecture/open-questions.md"
  )

  local f
  for f in "${files[@]}"; do
    if [ -f "$APP_DIR/$f" ]; then
      record "OK" "knowledge_file" "$f" "required knowledge file exists"
    else
      record "FAIL" "knowledge_file" "$f" "required knowledge file missing"
    fi
  done
}

check_validators_exist() {
  local files=(
    "scripts/admin/system/validate-toolbox-knowledge-context.sh"
    "scripts/admin/system/validate-toolbox-knowledge-policies-consistency.sh"
    "scripts/admin/system/validate-toolbox-knowledge-services-consistency.sh"
    "scripts/admin/system/diagnose-knowledge-architecture-candidates.sh"
    "scripts/admin/system/diagnose-toolbox-script-inventory.sh"
  )

  local f
  for f in "${files[@]}"; do
    if [ -f "$APP_DIR/$f" ]; then
      record "OK" "validator_or_diagnostic" "$f" "required validator/diagnostic exists"
    else
      record "FAIL" "validator_or_diagnostic" "$f" "required validator/diagnostic missing"
    fi
  done
}

check_validator_syntax() {
  local files=(
    "scripts/admin/system/validate-toolbox-knowledge-context.sh"
    "scripts/admin/system/validate-toolbox-knowledge-policies-consistency.sh"
    "scripts/admin/system/validate-toolbox-knowledge-services-consistency.sh"
    "scripts/admin/system/diagnose-knowledge-architecture-candidates.sh"
    "scripts/admin/system/diagnose-toolbox-script-inventory.sh"
  )

  local f
  for f in "${files[@]}"; do
    if [ ! -f "$APP_DIR/$f" ]; then
      continue
    fi

    if bash -n "$APP_DIR/$f"; then
      record "OK" "bash_syntax" "$f" "bash syntax passed"
    else
      record "FAIL" "bash_syntax" "$f" "bash syntax failed"
    fi
  done
}

run_existing_knowledge_validators() {
  local commands=(
    "validate-toolbox-knowledge-context.sh"
    "scripts/admin/system/validate-toolbox-knowledge-policies-consistency.sh"
    "scripts/admin/system/validate-toolbox-knowledge-services-consistency.sh"
  )

  local cmd
  local output
  local status

  {
    printf '\n## Knowledge validator execution\n\n'
  } >> "$REPORT"

  for cmd in "${commands[@]}"; do
    set +e
    output="$(cd "$APP_DIR" && $cmd 2>&1)"
    status=$?
    set -u

    {
      printf '### %s\n\n' "$cmd"
      printf 'exit_status=%s\n\n' "$status"
      printf '%s\n\n' "$output"
    } >> "$REPORT"

    if [ "$status" -eq 0 ]; then
      record "OK" "validator_run" "$cmd" "validator completed successfully"
    else
      record "FAIL" "validator_run" "$cmd" "validator failed"
    fi
  done
}

write_next_step_guidance() {
  {
    printf '\n## Recommended next step\n\n'

    if [ "$FAIL_COUNT" -gt 0 ]; then
      printf 'Do not install Codex yet. Resolve FAIL items first.\n'
    else
      printf 'No readiness failure was detected.\n\n'
      printf 'Recommended next human-approved step is to install Codex CLI using the official standalone installer, then authenticate interactively, then run `knowledge/runbooks/codex-read-only-first-run.md`.\n\n'
      printf 'This diagnostic did not install Codex and did not authenticate.\n'
    fi

    printf '\n## Generated artifacts\n\n'
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
  } >> "$REPORT"
}

main() {
  require_lib_contract
  ensure_output_dirs
  write_tsv_header
  write_report_header

  log "Starting Codex CLI readiness diagnosis."

  check_app_dir
  check_git_repo
  check_system_identity
  check_architecture
  check_basic_commands
  check_optional_install_tools
  check_versions
  check_existing_codex
  check_path
  check_shell_profile_hints
  check_codex_config_locations
  check_installer_reachability
  check_runbook_exists
  check_required_knowledge_files
  check_validators_exist
  check_validator_syntax
  run_existing_knowledge_validators
  check_git_repo
  write_next_step_guidance
  write_report_summary

  log "Codex CLI readiness diagnosis completed."
  log "Report: $REPORT"
  log "TSV: $TSV"

  if [ "$FAIL_COUNT" -gt 0 ]; then
    fail "Codex CLI readiness diagnosis found $FAIL_COUNT failure(s)."
  fi

  return 0
}

main "$@"
