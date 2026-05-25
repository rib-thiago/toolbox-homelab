#!/usr/bin/env bash
set -u

# Collect a safe operational context snapshot for the homelab/Toolbox.
#
# This script is intentionally conservative:
#   - it does not dump full shell configuration files;
#   - it does not print secrets;
#   - it avoids mandatory sudo;
#   - it writes a human report and a TSV summary;
#   - it uses Toolbox shared shell libraries.
#
# It does not modify system state.
# It does not modify Docker, firewall, Tailscale, media files, metadata or Git.

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

REPORT_FILE="$(toolbox_report_path "homelab_operational_context" "safe_snapshot" "$STAMP")"
TSV_FILE="$(toolbox_tsv_path "homelab_operational_context" "safe_snapshot" "$STAMP")"

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

run_cmd() {
  local title="$1"
  shift

  section "$title"

  {
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
  } >> "$REPORT_FILE"

  if "$@" >> "$REPORT_FILE" 2>&1; then
    record "command" "$title" "run" "ok" "$*"
  else
    record "command" "$title" "run" "warning" "command failed or returned non-zero: $*"
  fi
}

run_shell_cmd() {
  local title="$1"
  local command="$2"

  section "$title"

  {
    printf '$ %s\n\n' "$command"
  } >> "$REPORT_FILE"

  if sh -c "$command" >> "$REPORT_FILE" 2>&1; then
    record "command" "$title" "run" "ok" "$command"
  else
    record "command" "$title" "run" "warning" "command failed or returned non-zero: $command"
  fi
}

write_headers() {
  {
    printf 'Safe homelab operational context snapshot\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname 2>/dev/null || printf 'UNKNOWN')"
    printf 'User: %s\n' "$(id -un 2>/dev/null || printf 'UNKNOWN')"
    printf 'Toolbox app: %s\n' "$TOOLBOX_APP"
    printf 'Report file: %s\n' "$REPORT_FILE"
    printf 'TSV file: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'Scope:\n'
    printf '  collect safe operational context;\n'
    printf '  do not dump full shell dotfiles;\n'
    printf '  do not print secrets intentionally;\n'
    printf '  avoid mandatory sudo;\n'
    printf '  no system modification;\n'
    printf '  no Docker modification;\n'
    printf '  no firewall modification;\n'
    printf '  no Tailscale modification;\n'
    printf '  no media or metadata modification;\n'
    printf '  no Git modification.\n'
    printf '\n'
    printf 'Note:\n'
    printf '  This is a diagnostic snapshot for human review. Treat output as internal operational data.\n'
  } > "$REPORT_FILE"

  tsv_row "category" "item" "check" "status" "details" > "$TSV_FILE"
}

file_metadata() {
  local path="$1"
  local label="$2"

  section "File metadata: ${label}"

  if [ -f "$path" ]; then
    local size
    local lines
    local sha

    size="$(stat -c '%s' "$path" 2>/dev/null || printf 'UNKNOWN')"
    lines="$(wc -l < "$path" 2>/dev/null | tr -d ' ' || printf 'UNKNOWN')"
    sha="$(sha256sum "$path" 2>/dev/null | awk '{print $1}' || printf 'UNKNOWN')"

    {
      printf 'Path: %s\n' "$path"
      printf 'Size bytes: %s\n' "$size"
      printf 'Lines: %s\n' "$lines"
      printf 'SHA256: %s\n' "$sha"
    } >> "$REPORT_FILE"

    record "file" "$label" "metadata" "ok" "path=${path}; size=${size}; lines=${lines}; sha256=${sha}"
  else
    record "file" "$label" "metadata" "missing" "path not found: $path"
  fi
}

directory_summary() {
  local path="$1"
  local label="$2"
  local max_depth="${3:-2}"

  section "Directory summary: ${label}"

  if [ -d "$path" ]; then
    local files
    local dirs
    local total
    local size

    files="$(find "$path" -type f 2>/dev/null | wc -l | tr -d ' ')"
    dirs="$(find "$path" -type d 2>/dev/null | wc -l | tr -d ' ')"
    total="$(find "$path" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"
    size="$(du -sh "$path" 2>/dev/null | awk '{print $1}' || printf 'UNKNOWN')"

    {
      printf 'Path: %s\n' "$path"
      printf 'Size: %s\n' "$size"
      printf 'Directories: %s\n' "$dirs"
      printf 'Files: %s\n' "$files"
      printf 'Total entries: %s\n' "$total"
      printf '\nListing up to depth %s:\n' "$max_depth"
      find "$path" -maxdepth "$max_depth" -print 2>/dev/null | sort | sed -n '1,300p'
    } >> "$REPORT_FILE"

    record "directory" "$label" "summary" "ok" "path=${path}; size=${size}; dirs=${dirs}; files=${files}; total=${total}"
  else
    record "directory" "$label" "summary" "missing" "path not found: $path"
  fi
}

safe_shell_environment_summary() {
  section "Safe shell environment summary"

  file_metadata "$HOME/.bashrc" "bashrc"
  file_metadata "$HOME/.bash_aliases" "bash_aliases"
  file_metadata "$HOME/.nanorc" "nanorc"
  file_metadata "$HOME/.config/starship.toml" "starship_config"

  if [ -d "$HOME/.config/starship/themes" ]; then
    directory_summary "$HOME/.config/starship/themes" "starship_themes" 1
  else
    record "directory" "starship_themes" "exists" "missing" "$HOME/.config/starship/themes"
  fi

  section "PATH entries"

  printf '%s\n' "$PATH" | tr ':' '\n' | while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    printf '%s\n' "$entry" >> "$REPORT_FILE"
    tsv_row "path" "$entry" "PATH entry" "recorded" "-" >> "$TSV_FILE"
  done

  section "Known Toolbox shell helpers in PATH"

  for cmd in tb tbox mkx bashcheck tbman aliasconfig bashconfig j tf nf; do
    if command -v "$cmd" >/dev/null 2>&1; then
      local resolved
      resolved="$(command -v "$cmd" 2>/dev/null || printf 'UNKNOWN')"
      record "shell-helper" "$cmd" "available" "ok" "$resolved"
    else
      record "shell-helper" "$cmd" "available" "missing" "not found in PATH"
    fi
  done
}

git_summary() {
  section "Git summary"

  if git -C "$TOOLBOX_APP" rev-parse --show-toplevel >/tmp/toolbox-context-git-root.$$ 2>/tmp/toolbox-context-git-err.$$; then
    local root
    local branch
    local head

    root="$(cat /tmp/toolbox-context-git-root.$$)"
    branch="$(git -C "$TOOLBOX_APP" branch --show-current 2>/dev/null || printf 'UNKNOWN')"
    head="$(git -C "$TOOLBOX_APP" log --oneline -1 2>/dev/null || printf 'UNKNOWN')"

    record "git" "repository" "root" "ok" "$root"
    record "git" "repository" "branch" "ok" "$branch"
    record "git" "repository" "HEAD" "ok" "$head"

    {
      printf 'Root: %s\n' "$root"
      printf 'Branch: %s\n' "$branch"
      printf 'HEAD: %s\n' "$head"
      printf '\nStatus:\n'
      git -C "$TOOLBOX_APP" status --short
      printf '\nRecent commits:\n'
      git -C "$TOOLBOX_APP" --no-pager log --oneline -15
    } >> "$REPORT_FILE"
  else
    local err
    err="$(cat /tmp/toolbox-context-git-err.$$ 2>/dev/null || printf 'unknown error')"
    record "git" "repository" "summary" "warning" "$err"
  fi

  rm -f /tmp/toolbox-context-git-root.$$ /tmp/toolbox-context-git-err.$$
}

toolbox_summary() {
  section "Toolbox summary"

  directory_summary "/srv/toolbox/app" "toolbox_app" 3
  directory_summary "/srv/toolbox/shared" "toolbox_shared" 3
  directory_summary "/srv/toolbox/shared/reports" "toolbox_reports" 3
  directory_summary "/srv/toolbox/shared/library-db" "toolbox_library_db" 3

  run_shell_cmd "Recent Toolbox media reports" "find /srv/toolbox/shared/reports/media -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort -r | head -80"
  run_shell_cmd "Recent Toolbox raw files" "find /srv/toolbox/shared/library-db/raw -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort -r | head -80"
  run_shell_cmd "Recent Toolbox snapshots" "find /srv/toolbox/shared/library-db/snapshots -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort -r | head -40"
}

media_summary() {
  section "Media summary"

  directory_summary "/srv/media" "srv_media" 2
  directory_summary "/srv/media/music" "music_library" 2
  directory_summary "/srv/media/music-staging" "music_staging" 3
  directory_summary "/srv/media/pdfs" "pdf_library" 2
  directory_summary "/srv/media/photos" "photo_library" 2

  run_shell_cmd "Stockhausen canonical directories" "find /srv/media/music/Karlheinz\\ Stockhausen -maxdepth 3 -type d 2>/dev/null | sort | sed -n '1,200p'"
  run_shell_cmd "Music staging summary" "find /srv/media/music-staging -maxdepth 3 -type d 2>/dev/null | sort | sed -n '1,200p'"
  run_shell_cmd "Artwork cold archive summary" "find /srv/toolbox/shared/artwork-cold-archive -maxdepth 4 -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort -r | head -120"
}

docker_summary() {
  section "Docker summary"

  if command -v docker >/dev/null 2>&1; then
    run_cmd "Docker containers" docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
    run_cmd "Docker system df" docker system df
    run_shell_cmd "Docker compose directories" "find /srv/compose -maxdepth 2 -type f \\( -name 'compose.yml' -o -name 'docker-compose.yml' -o -name '.env' \\) -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | sort"
  else
    record "docker" "docker" "available" "missing" "docker command not found"
  fi
}

network_summary() {
  section "Network summary"

  run_cmd "Network interfaces" ip -br a
  run_shell_cmd "Listening ports without sudo" "ss -tuln 2>/dev/null || true"

  if command -v tailscale >/dev/null 2>&1; then
    run_shell_cmd "Tailscale status compact" "tailscale status 2>/dev/null | sed -n '1,80p'"
    run_shell_cmd "Tailscale IPv4 presence" "tailscale ip -4 2>/dev/null || true"
  else
    record "network" "tailscale" "available" "missing" "tailscale command not found"
  fi

  if command -v ufw >/dev/null 2>&1; then
    if sudo -n true >/dev/null 2>&1; then
      run_cmd "UFW status verbose" sudo ufw status verbose
    else
      record "network" "ufw" "status" "skipped" "sudo non-interactive not available"
    fi
  else
    record "network" "ufw" "available" "missing" "ufw command not found"
  fi
}

system_summary() {
  section "System summary"

  run_cmd "Disk usage df -h" df -h
  run_cmd "Memory" free -h
  run_cmd "Uptime" uptime
  run_shell_cmd "Top-level /srv usage" "du -h --max-depth=1 /srv 2>/dev/null | sort -h"
  run_shell_cmd "Top-level /srv/toolbox usage" "du -h --max-depth=1 /srv/toolbox 2>/dev/null | sort -h"
  run_shell_cmd "Top-level /srv/media usage" "du -h --max-depth=1 /srv/media 2>/dev/null | sort -h"
}

process_summary() {
  section "Relevant process summary"

  run_shell_cmd "Relevant long-running/media/toolbox processes" "ps aux | grep -E 'stockhausen|toolbox|cwebp|ffmpeg|flac|metaflac|shnsplit|cuebreakpoints|7z|navidrome|slskd' | grep -v grep || true"
}

write_summary() {
  local fail_count
  local warning_count
  local missing_count
  local skipped_count

  section "Summary"

  fail_count="$(awk -F '\t' 'NR > 1 && $4 == "fail" {count++} END {print count+0}' "$TSV_FILE")"
  warning_count="$(awk -F '\t' 'NR > 1 && $4 == "warning" {count++} END {print count+0}' "$TSV_FILE")"
  missing_count="$(awk -F '\t' 'NR > 1 && $4 == "missing" {count++} END {print count+0}' "$TSV_FILE")"
  skipped_count="$(awk -F '\t' 'NR > 1 && $4 == "skipped" {count++} END {print count+0}' "$TSV_FILE")"

  {
    printf 'Failed checks: %s\n' "$fail_count"
    printf 'Warning checks: %s\n' "$warning_count"
    printf 'Missing checks: %s\n' "$missing_count"
    printf 'Skipped checks: %s\n' "$skipped_count"
    printf '\n'
    printf 'Generated artifacts:\n'
    printf '  Human report: %s\n' "$REPORT_FILE"
    printf '  TSV: %s\n' "$TSV_FILE"
    printf '\n'
    printf 'No system state was intentionally modified.\n'
  } >> "$REPORT_FILE"

  record "summary" "safe-operational-context" "completed" "recorded" "fail=${fail_count}; warning=${warning_count}; missing=${missing_count}; skipped=${skipped_count}"
}

main() {
  write_headers

  log "Collecting safe homelab operational context."
  log "Report: $REPORT_FILE"
  log "TSV: $TSV_FILE"

  safe_shell_environment_summary
  git_summary
  toolbox_summary
  media_summary
  docker_summary
  network_summary
  system_summary
  process_summary
  write_summary

  log "Safe operational context collection completed."
  log "Human report: $REPORT_FILE"
  log "Structured TSV: $TSV_FILE"

  printf '\n'
  printf 'Generated artifacts:\n'
  printf '  Human report: %s\n' "$REPORT_FILE"
  printf '  TSV:          %s\n' "$TSV_FILE"
}

main "$@"
