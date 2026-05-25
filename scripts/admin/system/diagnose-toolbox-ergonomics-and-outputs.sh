#!/usr/bin/env bash
set -u

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
  log "ERROR: $*" >&2
  exit 1
}

STAMP="$(date +%Y%m%d-%H%M%S)"

TOOLBOX_APP="/srv/toolbox/app"

REPORT_DIR="/srv/toolbox/shared/reports/media"
RAW_DIR="/srv/toolbox/shared/library-db/raw"
SNAPSHOT_DIR="/srv/toolbox/shared/library-db/snapshots"

REPORT_FILE="${REPORT_DIR}/toolbox_ergonomics_outputs_report_${STAMP}.txt"
TSV_FILE="${RAW_DIR}/toolbox_ergonomics_outputs_diagnosis_${STAMP}.tsv"

require_dir_writable() {
  dir="$1"
  label="$2"

  if [ ! -d "$dir" ]; then
    fail "${label} does not exist: ${dir}"
  fi

  if [ ! -w "$dir" ]; then
    fail "${label} is not writable: ${dir}"
  fi
}

tsv_escape() {
  local raw
  raw="$1"

  raw="${raw//$'\t'/ }"
  raw="${raw//$'\n'/ }"
  raw="${raw//$'\r'/ }"

  printf '%s' "$raw"
}

tsv_row() {
  local category
  local item
  local status
  local row_value

  category="$1"
  item="$2"
  status="$3"
  row_value="$4"

  {
    tsv_escape "$category"
    printf '\t'
    tsv_escape "$item"
    printf '\t'
    tsv_escape "$status"
    printf '\t'
    tsv_escape "$row_value"
    printf '\n'
  } >> "$TSV_FILE"
}

section() {
  local title
  title="$1"

  {
    printf '\n'
    printf '%s\n' '================================================================'
    printf '%s\n' "$title"
    printf '%s\n' '================================================================'
  } >> "$REPORT_FILE"
}

subsection() {
  local title
  title="$1"

  {
    printf '\n'
    printf '%s\n' '----------------------------------------------------------------'
    printf '%s\n' "$title"
    printf '%s\n' '----------------------------------------------------------------'
  } >> "$REPORT_FILE"
}

append_cmd() {
  local title
  local rc

  title="$1"
  shift

  subsection "$title"
  {
    printf '%s' '$'
    printf ' %q' "$@"
    printf '\n\n'
  } >> "$REPORT_FILE"

  "$@" >> "$REPORT_FILE" 2>&1
  rc="$?"

  if [ "$rc" -ne 0 ]; then
    printf '\n[exit_code=%s]\n' "$rc" >> "$REPORT_FILE"
  fi

  return 0
}

append_shell() {
  local title
  local cmd
  local rc

  title="$1"
  cmd="$2"

  subsection "$title"
  {
    printf '%s\n\n' "$ $cmd"
  } >> "$REPORT_FILE"

  bash -lc "$cmd" >> "$REPORT_FILE" 2>&1
  rc="$?"

  if [ "$rc" -ne 0 ]; then
    printf '\n[exit_code=%s]\n' "$rc" >> "$REPORT_FILE"
  fi

  return 0
}

file_state_tsv() {
  path="$1"
  label="$2"

  if [ -e "$path" ]; then
    perms="$(stat -c '%A %U:%G %s bytes %y' "$path" 2>/dev/null || true)"
    tsv_row "file" "$label" "exists" "${path} | ${perms}"
  else
    tsv_row "file" "$label" "missing" "$path"
  fi
}

dir_state_tsv() {
  path="$1"
  label="$2"

  if [ -d "$path" ]; then
    perms="$(stat -c '%A %U:%G %s bytes %y' "$path" 2>/dev/null || true)"
    count="$(find "$path" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"
    tsv_row "directory" "$label" "exists" "${path} | entries=${count} | ${perms}"
  else
    tsv_row "directory" "$label" "missing" "$path"
  fi
}

command_state_tsv() {
  name="$1"

  if command -v "$name" >/dev/null 2>&1; then
    resolved="$(command -v "$name" 2>/dev/null || true)"
    tsv_row "command" "$name" "available" "$resolved"
  else
    tsv_row "command" "$name" "missing" ""
  fi
}

alias_state_tsv() {
  name="$1"
  value="$(alias "$name" 2>/dev/null || true)"

  if [ -n "$value" ]; then
    tsv_row "alias" "$name" "defined" "$value"
  else
    tsv_row "alias" "$name" "missing" ""
  fi
}

function_or_command_state_tsv() {
  name="$1"
  value="$(type "$name" 2>/dev/null | head -5 | tr '\n' ' ' || true)"

  if [ -n "$value" ]; then
    tsv_row "shell_symbol" "$name" "available" "$value"
  else
    tsv_row "shell_symbol" "$name" "missing" ""
  fi
}

shopt_state_tsv() {
  name="$1"
  value="$(shopt -p "$name" 2>/dev/null || true)"

  if [ -n "$value" ]; then
    tsv_row "shopt" "$name" "found" "$value"
  else
    tsv_row "shopt" "$name" "missing_or_invalid" ""
  fi
}

git_summary_tsv() {
  if [ ! -d "$TOOLBOX_APP" ]; then
    tsv_row "git" "toolbox_app" "missing" "$TOOLBOX_APP"
    return 0
  fi

  if git -C "$TOOLBOX_APP" rev-parse --show-toplevel >/dev/null 2>&1; then
    root="$(git -C "$TOOLBOX_APP" rev-parse --show-toplevel 2>/dev/null || true)"
    branch="$(git -C "$TOOLBOX_APP" branch --show-current 2>/dev/null || true)"
    status_count="$(git -C "$TOOLBOX_APP" status --short 2>/dev/null | wc -l | tr -d ' ')"
    modified_scripts="$(git -C "$TOOLBOX_APP" status --short -- '*.sh' 2>/dev/null | wc -l | tr -d ' ')"
    untracked_scripts="$(git -C "$TOOLBOX_APP" status --short -- '*.sh' 2>/dev/null | grep -c '^??' 2>/dev/null || true)"

    tsv_row "git" "repo" "yes" "$root"
    tsv_row "git" "branch" "found" "$branch"
    tsv_row "git" "status_entries" "count" "$status_count"
    tsv_row "git" "changed_shell_scripts" "count" "$modified_scripts"
    tsv_row "git" "untracked_shell_scripts" "count" "$untracked_scripts"
  else
    tsv_row "git" "repo" "no" "$TOOLBOX_APP"
  fi
}

write_header() {
  {
    printf 'Toolbox ergonomics and outputs diagnosis\n'
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope: diagnose only. No configuration changes, no mkdir, no chmod, no git writes.\n'
  } > "$REPORT_FILE"

  {
    printf 'category\titem\tstatus\tvalue\n'
  } > "$TSV_FILE"
}

diagnose_git() {
  section "1. GIT STATE OF TOOLBOX"

  if [ ! -d "$TOOLBOX_APP" ]; then
    printf 'Toolbox app directory missing: %s\n' "$TOOLBOX_APP" >> "$REPORT_FILE"
    return 0
  fi

  append_shell "Toolbox app directory" "cd '$TOOLBOX_APP' && pwd"

  append_shell "Git repository root" "cd '$TOOLBOX_APP' && git rev-parse --show-toplevel 2>/dev/null || echo NOT_A_GIT_REPO"
  append_shell "Current Git branch" "cd '$TOOLBOX_APP' && git branch --show-current 2>/dev/null || true"
  append_shell "Git status short" "cd '$TOOLBOX_APP' && git status --short 2>/dev/null || true"
  append_shell "Last commits" "cd '$TOOLBOX_APP' && git log --oneline -10 2>/dev/null || true"
  append_shell "Modified files" "cd '$TOOLBOX_APP' && git diff --name-only 2>/dev/null || true"
  append_shell "Staged files" "cd '$TOOLBOX_APP' && git diff --cached --name-only 2>/dev/null || true"
  append_shell "Untracked relevant scripts" "cd '$TOOLBOX_APP' && git status --short -- '*.sh' 'scripts/**' 'docs/**' 2>/dev/null | sed -n '1,200p' || true"
  append_shell "Shell scripts not ignored by Git status" "cd '$TOOLBOX_APP' && git status --short -- '*.sh' 2>/dev/null || true"
}

diagnose_output_dirs() {
  section "2. OFFICIAL TOOLBOX OUTPUT DIRECTORIES"

  append_shell "Directory permissions" "ls -ld '$REPORT_DIR' '$RAW_DIR' '$SNAPSHOT_DIR' 2>/dev/null || true"

  append_shell "Reports/media recent entries" "find '$REPORT_DIR' -maxdepth 1 -type f 2>/dev/null | sort | tail -30 || true"
  append_shell "Raw recent entries" "find '$RAW_DIR' -maxdepth 1 -type f 2>/dev/null | sort | tail -30 || true"
  append_shell "Snapshots recent entries" "find '$SNAPSHOT_DIR' -maxdepth 1 -type f 2>/dev/null | sort | tail -30 || true"

  append_shell "Reports/media disk usage summary" "du -sh '$REPORT_DIR' 2>/dev/null || true"
  append_shell "Raw disk usage summary" "du -sh '$RAW_DIR' 2>/dev/null || true"
  append_shell "Snapshots disk usage summary" "du -sh '$SNAPSHOT_DIR' 2>/dev/null || true"
}

diagnose_recent_outputs() {
  section "3. RECENT OUTPUT NAMING PATTERNS"

  append_shell "Recent human reports (*.txt)" "find '$REPORT_DIR' -maxdepth 1 -type f -name '*.txt' 2>/dev/null | sed 's#^.*/##' | sort | tail -40 || true"
  append_shell "Recent live logs (*_live_*.log and *.log)" "find '$REPORT_DIR' -maxdepth 1 -type f \\( -name '*_live_*.log' -o -name '*.log' \\) 2>/dev/null | sed 's#^.*/##' | sort | tail -40 || true"
  append_shell "Recent TSVs in raw" "find '$RAW_DIR' -maxdepth 1 -type f -name '*.tsv' 2>/dev/null | sed 's#^.*/##' | sort | tail -60 || true"
  append_shell "Recent plans" "find '$RAW_DIR' -maxdepth 1 -type f -name '*_plan_*.tsv' 2>/dev/null | sed 's#^.*/##' | sort | tail -40 || true"
  append_shell "Recent validations" "find '$RAW_DIR' -maxdepth 1 -type f -name '*_validation_*.tsv' 2>/dev/null | sed 's#^.*/##' | sort | tail -40 || true"
  append_shell "Recent diagnostics" "find '$RAW_DIR' -maxdepth 1 -type f \\( -name '*_diagnosis_*.tsv' -o -name '*_diagnostic_*.tsv' \\) 2>/dev/null | sed 's#^.*/##' | sort | tail -40 || true"
  append_shell "Recent snapshots/freezes" "find '$SNAPSHOT_DIR' -maxdepth 1 -type f 2>/dev/null | sed 's#^.*/##' | sort | tail -60 || true"
}

diagnose_bash_ergonomics() {
  section "4. CURRENT BASH ERGONOMICS"

  append_shell "Aliases of interest" "alias | grep -E 'alias (j|tf|t100|nf|psg|reload|latestreport|latestmedia|latestraw|scratch|aliasdir|bashdir|aliasconfig|bashconfig)=' || true"
  append_shell "Functions/commands of interest" "type mkx bashcheck reload latestreport latestmedia latestraw scratch aliasdir bashdir aliasconfig bashconfig 2>/dev/null || true"
  append_shell "PATH" "printf '%s\n' \"\$PATH\" | tr ':' '\n'"
  append_shell "Local bin state" "ls -ld ~/.local ~/.local/bin 2>/dev/null || true; find ~/.local/bin -maxdepth 1 \\( -type f -o -type l \\) 2>/dev/null | sort | sed -n '1,120p' || true"
  append_shell "Scratch directory state" "ls -ld ~/scratch 2>/dev/null || true; find ~/scratch -maxdepth 1 2>/dev/null | sort | sed -n '1,80p' || true"
}

diagnose_bash_config() {
  section "5. BASH CONFIGURATION"

  append_shell "Bash config files" "ls -la ~/.bashrc ~/.bash_aliases ~/.bashrc.d ~/.bash_aliases.d 2>/dev/null || true"
  append_shell "Bash modular files" "find ~/.bashrc.d ~/.bash_aliases.d -maxdepth 2 -type f 2>/dev/null | sort || true"
  append_shell "History and prompt settings in files" "grep -R \"PROMPT_COMMAND\\|HISTSIZE\\|HISTFILESIZE\\|HISTCONTROL\\|HISTTIMEFORMAT\\|LESS=\\|MANPAGER\\|autocd\\|cdspell\\|checkwinsize\" ~/.bashrc ~/.bash_aliases ~/.bashrc.d ~/.bash_aliases.d 2>/dev/null || true"
  append_shell "Current shell environment variables" "printf 'HISTSIZE=%s\n' \"\${HISTSIZE-}\"; printf 'HISTFILESIZE=%s\n' \"\${HISTFILESIZE-}\"; printf 'HISTCONTROL=%s\n' \"\${HISTCONTROL-}\"; printf 'HISTTIMEFORMAT=%s\n' \"\${HISTTIMEFORMAT-}\"; printf 'PROMPT_COMMAND=%s\n' \"\${PROMPT_COMMAND-}\"; printf 'LESS=%s\n' \"\${LESS-}\"; printf 'MANPAGER=%s\n' \"\${MANPAGER-}\""
  append_shell "Current shopt states" "shopt autocd cdspell checkwinsize 2>/dev/null || true"
  append_shell "Starship config indicators" "ls -la ~/.config/starship.toml 2>/dev/null || true; grep -n \"cmd_duration\\|status\\|jobs\" ~/.config/starship.toml 2>/dev/null || true"
  append_shell "Nano config indicators" "ls -la ~/.nanorc 2>/dev/null || true; sed -n '1,220p' ~/.nanorc 2>/dev/null || true"
}

diagnose_toolbox_structure() {
  section "6. RELEVANT TOOLBOX STRUCTURE"

  append_shell "Top-level Toolbox app tree" "find '$TOOLBOX_APP' -maxdepth 2 -type d 2>/dev/null | sort || true"

  append_shell "Scripts admin directories" "find '$TOOLBOX_APP/scripts/admin' -maxdepth 3 -type d 2>/dev/null | sort || true"
  append_shell "Scripts admin shell files" "find '$TOOLBOX_APP/scripts/admin' -maxdepth 4 -type f -name '*.sh' 2>/dev/null | sort || true"

  append_shell "Scripts media directories" "find '$TOOLBOX_APP/scripts/media' -maxdepth 3 -type d 2>/dev/null | sort || true"
  append_shell "Scripts media shell files" "find '$TOOLBOX_APP/scripts/media' -maxdepth 4 -type f -name '*.sh' 2>/dev/null | sort || true"

  append_shell "Scripts media/stockhausen shell files" "find '$TOOLBOX_APP/scripts/media/stockhausen' -maxdepth 2 -type f -name '*.sh' 2>/dev/null | sort || true"

  append_shell "Scripts lib state" "find '$TOOLBOX_APP/scripts/lib' -maxdepth 3 2>/dev/null | sort || true"

  append_shell "Docs operations state" "find '$TOOLBOX_APP/docs/operations' -maxdepth 3 -type f 2>/dev/null | sort || true"

  append_shell "Existing docs mentioning scripts or outputs" "find '$TOOLBOX_APP/docs' -type f 2>/dev/null | grep -Ei 'script|output|report|toolbox|operation|convention|policy|flow|fluxo' | sort || true"

  append_shell "Potential policy mentions" "grep -Rni \"diagnose\\|plan\\|apply\\|validate\\|set -u\\|log()\\|fail()\\|reports/media\\|library-db/raw\\|snapshots\\|nohup\\|tee\" '$TOOLBOX_APP/docs' '$TOOLBOX_APP/scripts' 2>/dev/null | sed -n '1,240p' || true"
}

write_tsv_summary() {
  git_summary_tsv

  dir_state_tsv "$TOOLBOX_APP" "toolbox_app"
  dir_state_tsv "$REPORT_DIR" "reports_media"
  dir_state_tsv "$RAW_DIR" "library_db_raw"
  dir_state_tsv "$SNAPSHOT_DIR" "library_db_snapshots"

  file_state_tsv "$HOME/.bashrc" "bashrc"
  file_state_tsv "$HOME/.bash_aliases" "bash_aliases"
  dir_state_tsv "$HOME/.bashrc.d" "bashrc_d"
  dir_state_tsv "$HOME/.bash_aliases.d" "bash_aliases_d"
  file_state_tsv "$HOME/.nanorc" "nanorc"
  file_state_tsv "$HOME/.config/starship.toml" "starship_toml"

  alias_state_tsv "j"
  alias_state_tsv "tf"
  alias_state_tsv "t100"
  alias_state_tsv "nf"
  alias_state_tsv "psg"
  alias_state_tsv "reload"
  alias_state_tsv "latestreport"
  alias_state_tsv "latestmedia"
  alias_state_tsv "latestraw"
  alias_state_tsv "scratch"
  alias_state_tsv "aliasdir"
  alias_state_tsv "bashdir"
  alias_state_tsv "aliasconfig"
  alias_state_tsv "bashconfig"

  function_or_command_state_tsv "mkx"
  function_or_command_state_tsv "bashcheck"
  function_or_command_state_tsv "reload"
  function_or_command_state_tsv "latestreport"
  function_or_command_state_tsv "latestmedia"
  function_or_command_state_tsv "latestraw"
  function_or_command_state_tsv "scratch"

  command_state_tsv "git"
  command_state_tsv "find"
  command_state_tsv "grep"
  command_state_tsv "sed"
  command_state_tsv "awk"
  command_state_tsv "stat"
  command_state_tsv "du"
  command_state_tsv "batcat"
  command_state_tsv "starship"
  command_state_tsv "nano"

  shopt_state_tsv "autocd"
  shopt_state_tsv "cdspell"
  shopt_state_tsv "checkwinsize"

  tsv_row "env" "HISTSIZE" "value" "${HISTSIZE-}"
  tsv_row "env" "HISTFILESIZE" "value" "${HISTFILESIZE-}"
  tsv_row "env" "HISTCONTROL" "value" "${HISTCONTROL-}"
  tsv_row "env" "HISTTIMEFORMAT" "value" "${HISTTIMEFORMAT-}"
  tsv_row "env" "PROMPT_COMMAND" "value" "${PROMPT_COMMAND-}"
  tsv_row "env" "LESS" "value" "${LESS-}"
  tsv_row "env" "MANPAGER" "value" "${MANPAGER-}"
}

main() {
  require_dir_writable "$REPORT_DIR" "REPORT_DIR"
  require_dir_writable "$RAW_DIR" "RAW_DIR"

  write_header

  log "Writing human report: $REPORT_FILE"
  log "Writing structured TSV: $TSV_FILE"

  write_tsv_summary

  diagnose_git
  diagnose_output_dirs
  diagnose_recent_outputs
  diagnose_bash_ergonomics
  diagnose_bash_config
  diagnose_toolbox_structure

  section "7. GENERATED ARTIFACTS"
  {
    printf 'Human report: %s\n' "$REPORT_FILE"
    printf 'Structured TSV: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Diagnosis completed. No configuration changes were performed.\n'
  } >> "$REPORT_FILE"

  log "Diagnosis completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report:   %s\n' "$REPORT_FILE"
  printf '  Structured TSV: %s\n' "$TSV_FILE"
}

main "$@"
