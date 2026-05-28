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

REPORT_DIR="$SHARED_DIR/reports/system/shell"
RAW_DIR="$SHARED_DIR/library-db/raw/system/shell"

REPORT="$REPORT_DIR/shell_aliases_environment_diagnosis_report_$STAMP.txt"
TSV="$RAW_DIR/shell_aliases_environment_diagnosis_$STAMP.tsv"

HOME_DIR="$HOME"
BASHRC="$HOME_DIR/.bashrc"
BASH_ALIASES="$HOME_DIR/.bash_aliases"
BASHRC_D="$HOME_DIR/.bashrc.d"
BASH_ALIASES_D="$HOME_DIR/.bash_aliases.d"
NANORC="$HOME_DIR/.nanorc"
STARSHIP_CONFIG="$HOME_DIR/.config/starship.toml"

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

write_row() {
  local item_type="$1"
  local source_path="$2"
  local line_no="$3"
  local name="$4"
  local status="$5"
  local definition="$6"
  local notes="$7"

  tsv_row \
    "$item_type" \
    "$source_path" \
    "$line_no" \
    "$name" \
    "$status" \
    "$definition" \
    "$notes" >> "$TSV"
}

append_section() {
  local title="$1"

  {
    printf '\n'
    printf '## %s\n' "$title"
    printf '\n'
  } >> "$REPORT"
}

append_file_block() {
  local title="$1"
  local file="$2"

  append_section "$title"

  if [ ! -e "$file" ]; then
    {
      printf '%s\n' '```text'
      printf 'missing: %s\n' "$file"
      printf '%s\n' '```'
    } >> "$REPORT"
    return 0
  fi

  if [ -d "$file" ]; then
    {
      printf '%s\n' '```text'
      printf 'directory: %s\n' "$file"
      find "$file" -maxdepth 1 -mindepth 1 -printf '%M %u %g %p\n' 2>/dev/null | sort
      printf '%s\n' '```'
    } >> "$REPORT"
    return 0
  fi

  {
    printf '%s\n' '```text'
    nl -ba "$file" 2>/dev/null || cat "$file" 2>/dev/null || true
    printf '%s\n' '```'
  } >> "$REPORT"
}

append_command_output() {
  local title="$1"
  shift

  append_section "$title"

  {
    printf '%s\n' '```text'
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
  } >> "$REPORT"

  if "$@" >> "$REPORT" 2>&1; then
    printf '\n%s\n' '[OK]' >> "$REPORT"
  else
    printf '\n%s\n' '[WARN] Command returned non-zero status.' >> "$REPORT"
  fi

  printf '%s\n' '```' >> "$REPORT"
}

record_path_item() {
  local path="$1"
  local name="$2"

  if [ -e "$path" ]; then
    if [ -d "$path" ]; then
      write_row "path" "$path" "" "$name" "OK" "directory exists" ""
    elif [ -f "$path" ]; then
      write_row "path" "$path" "" "$name" "OK" "file exists" ""
    else
      write_row "path" "$path" "" "$name" "INFO" "exists but is not regular file/directory" ""
    fi
  else
    write_row "path" "$path" "" "$name" "MISSING" "not found" ""
  fi
}

parse_aliases_from_file() {
  local file="$1"

  if [ ! -f "$file" ]; then
    return 0
  fi

  awk '
    /^[[:space:]]*alias[[:space:]][A-Za-z0-9_][A-Za-z0-9_+-]*=/ {
      line=$0
      sub(/^[[:space:]]*alias[[:space:]]+/, "", line)
      name=line
      sub(/=.*/, "", name)
      print FILENAME "\t" FNR "\t" name "\t" line
    }
  ' "$file" |
    while IFS=$'\t' read -r source_path line_no name definition; do
      write_row "alias" "$source_path" "$line_no" "$name" "FOUND" "$definition" ""
    done
}

parse_functions_from_file() {
  local file="$1"

  if [ ! -f "$file" ]; then
    return 0
  fi

  awk '
    /^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*[[:space:]]*\(\)[[:space:]]*\{/ {
      line=$0
      name=line
      sub(/^[[:space:]]*/, "", name)
      sub(/[[:space:]]*\(\).*/, "", name)
      print FILENAME "\t" FNR "\t" name "\t" line
    }
    /^[[:space:]]*function[[:space:]]+[A-Za-z_][A-Za-z0-9_-]*/ {
      line=$0
      name=line
      sub(/^[[:space:]]*function[[:space:]]+/, "", name)
      sub(/[[:space:]\(\{].*/, "", name)
      print FILENAME "\t" FNR "\t" name "\t" line
    }
  ' "$file" |
    while IFS=$'\t' read -r source_path line_no name definition; do
      write_row "function" "$source_path" "$line_no" "$name" "FOUND" "$definition" ""
    done
}

validate_shell_file() {
  local file="$1"

  if [ ! -f "$file" ]; then
    return 0
  fi

  case "$file" in
    *.sh|*.bash|"$BASHRC"|"$BASH_ALIASES")
      if bash -n "$file" >/dev/null 2>&1; then
        write_row "syntax" "$file" "" "bash -n" "OK" "bash -n passed" ""
      else
        write_row "syntax" "$file" "" "bash -n" "FAIL" "bash -n failed" "review manually"
      fi
      ;;
    *)
      write_row "syntax" "$file" "" "bash -n" "SKIP" "not a shell file by extension" ""
      ;;
  esac
}

scan_shell_file() {
  local file="$1"

  if [ ! -f "$file" ]; then
    return 0
  fi

  validate_shell_file "$file"
  parse_aliases_from_file "$file"
  parse_functions_from_file "$file"
}

path_contains() {
  local needle="$1"

  case ":$PATH:" in
    *":$needle:"*) return 0 ;;
    *) return 1 ;;
  esac
}

command_check() {
  local cmd="$1"
  local role="$2"

  if command -v "$cmd" >/dev/null 2>&1; then
    write_row "command" "$(command -v "$cmd")" "" "$cmd" "OK" "$role" ""
  else
    write_row "command" "" "" "$cmd" "MISSING" "$role" "command not found"
  fi
}

main() {
  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting shell aliases environment diagnosis."

  tsv_row \
    "item_type" \
    "source_path" \
    "line_no" \
    "name" \
    "status" \
    "definition" \
    "notes" > "$TSV"

  {
    printf '%s\n' '# Shell Aliases Environment Diagnosis'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Home: %s\n' "$HOME_DIR"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: diagnosis only. This script does not modify shell files, aliases, PATH, Git config, Nano config or Starship config.'
    printf '%s\n' 'Purpose: inspect current shell ergonomics before planning Toolbox shell artifact helpers.'
    printf '\n'
  } > "$REPORT"

  record_path_item "$BASHRC" ".bashrc"
  record_path_item "$BASH_ALIASES" ".bash_aliases"
  record_path_item "$BASHRC_D" ".bashrc.d"
  record_path_item "$BASH_ALIASES_D" ".bash_aliases.d"
  record_path_item "$NANORC" ".nanorc"
  record_path_item "$STARSHIP_CONFIG" "starship.toml"

  if path_contains "$HOME_DIR/.local/bin"; then
    write_row "path-env" "" "" "HOME/.local/bin" "OK" "$PATH" "present in PATH"
  else
    write_row "path-env" "" "" "HOME/.local/bin" "WARN" "$PATH" "not present in PATH"
  fi

  if path_contains "$APP_DIR/bin"; then
    write_row "path-env" "" "" "toolbox app bin" "OK" "$PATH" "present in PATH"
  else
    write_row "path-env" "" "" "toolbox app bin" "WARN" "$PATH" "not present in PATH"
  fi

  command_check "mkx" "make script executable helper"
  command_check "bashcheck" "shell syntax validation helper"
  command_check "nf" "nohup helper/alias"
  command_check "tf" "tail -f helper/alias"
  command_check "j" "jobs helper/alias"
  command_check "psg" "process grep helper/alias"
  command_check "bat" "preferred report reader"
  command_check "batcat" "Ubuntu bat command fallback"
  command_check "less" "universal pager"
  command_check "column" "TSV formatting"
  command_check "find" "latest artifact lookup"
  command_check "git" "Git workflow"
  command_check "starship" "prompt"
  command_check "nano" "editor"

  scan_shell_file "$BASHRC"
  scan_shell_file "$BASH_ALIASES"

  if [ -d "$BASHRC_D" ]; then
    while IFS= read -r -d '' file; do
      scan_shell_file "$file"
    done < <(find "$BASHRC_D" -maxdepth 1 -type f -print0 | sort -z)
  fi

  if [ -d "$BASH_ALIASES_D" ]; then
    while IFS= read -r -d '' file; do
      scan_shell_file "$file"
    done < <(find "$BASH_ALIASES_D" -maxdepth 1 -type f -print0 | sort -z)
  fi

  append_file_block ".bashrc" "$BASHRC"
  append_file_block ".bash_aliases" "$BASH_ALIASES"
  append_file_block ".bashrc.d listing" "$BASHRC_D"
  append_file_block ".bash_aliases.d listing" "$BASH_ALIASES_D"
  append_file_block ".nanorc" "$NANORC"
  append_file_block "Starship config" "$STARSHIP_CONFIG"

  append_command_output "PATH entries" sh -c 'printf "%s\n" "$PATH" | tr ":" "\n" | nl -ba'
  append_command_output "Bash aliases from non-interactive shell" bash -lc 'alias || true'
  append_command_output "Known shell functions from non-interactive shell" bash -lc 'declare -F || true'
  append_command_output "Git pager configuration" git config --global --get core.pager
  append_command_output "Git global aliases" git config --global --get-regexp '^alias\.' || true
  append_command_output "Toolbox app bin commands" sh -c 'find /srv/toolbox/app/bin -maxdepth 1 -type f -printf "%f\n" 2>/dev/null | sort || true'

  alias_count="$(awk -F '\t' 'NR > 1 && $1 == "alias" { c++ } END { print c+0 }' "$TSV")"
  function_count="$(awk -F '\t' 'NR > 1 && $1 == "function" { c++ } END { print c+0 }' "$TSV")"
  syntax_fail_count="$(awk -F '\t' 'NR > 1 && $1 == "syntax" && $5 == "FAIL" { c++ } END { print c+0 }' "$TSV")"
  warn_count="$(awk -F '\t' 'NR > 1 && $5 == "WARN" { c++ } END { print c+0 }' "$TSV")"

  {
    printf '\n'
    printf '%s\n' '## Summary'
    printf '\n'
    printf 'Aliases found: %s\n' "$alias_count"
    printf 'Functions found: %s\n' "$function_count"
    printf 'Syntax failures: %s\n' "$syntax_fail_count"
    printf 'Warnings: %s\n' "$warn_count"
    printf '\n'
    printf '%s\n' 'Potential next helper groups to plan:'
    printf '%s\n' '- artifact readers: latest-file, tsvless, tsvlatest, rptless, rptlatest, tblatest'
    printf '%s\n' '- live logs: nflog, tblive'
    printf '%s\n' '- dev helper: mkxcheck'
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  log "Shell aliases environment diagnosis completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
