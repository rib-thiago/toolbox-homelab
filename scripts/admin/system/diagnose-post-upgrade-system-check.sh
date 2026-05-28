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

REPORT_DIR="$SHARED_DIR/reports/system/upgrade"
RAW_DIR="$SHARED_DIR/library-db/raw/system/upgrade"

REPORT="$REPORT_DIR/post_upgrade_system_check_report_$STAMP.txt"
TSV="$RAW_DIR/post_upgrade_system_check_$STAMP.tsv"

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

write_check() {
  local check_id="$1"
  local category="$2"
  local status="$3"
  local message="$4"
  local details="$5"

  tsv_row "$check_id" "$category" "$status" "$message" "$details" >> "$TSV"
}

append_section() {
  local title="$1"

  {
    printf '\n'
    printf '## %s\n' "$title"
    printf '\n'
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
    printf '%s\n' '```' >> "$REPORT"
    return 0
  fi

  printf '\n%s\n' '[WARN] Command returned non-zero status.' >> "$REPORT"
  printf '%s\n' '```' >> "$REPORT"
  return 1
}

service_check() {
  local service="$1"
  local check_id="$2"
  local category="$3"
  local status
  local details

  if systemctl list-unit-files "$service" >/dev/null 2>&1; then
    if systemctl is-active --quiet "$service"; then
      status="OK"
      details="active"
    else
      status="WARN"
      details="$(systemctl is-active "$service" 2>/dev/null || true)"
    fi
  else
    status="INFO"
    details="unit not found"
  fi

  write_check "$check_id" "$category" "$status" "$service" "$details"
}

command_check() {
  local cmd="$1"
  local check_id="$2"
  local category="$3"

  if command -v "$cmd" >/dev/null 2>&1; then
    write_check "$check_id" "$category" "OK" "$cmd available" "$(command -v "$cmd")"
  else
    write_check "$check_id" "$category" "WARN" "$cmd missing" "command not found"
  fi
}

main() {
  require_lib_contract

  mkdir -p "$REPORT_DIR" "$RAW_DIR"

  log "Starting post-upgrade system check."

  tsv_row "check_id" "category" "status" "message" "details" > "$TSV"

  {
    printf '%s\n' '# Post-upgrade System Check'
    printf '\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'Host: %s\n' "$(hostname)"
    printf 'User: %s\n' "$(id -un)"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n' "$TSV"
    printf '\n'
    printf '%s\n' 'Safety: diagnosis only. This script does not install packages, remove packages, run autoremove, reboot, restart services or modify configuration.'
    printf '%s\n' 'Purpose: validate host state after an accidental apt upgrade before continuing Python/beets tooling work.'
    printf '\n'
  } > "$REPORT"

  current_kernel="$(uname -r)"
  write_check "SYS-001" "kernel" "INFO" "Current running kernel" "$current_kernel"

  if [ -f /var/run/reboot-required ]; then
    reboot_pkgs="$(cat /var/run/reboot-required.pkgs 2>/dev/null | paste -sd ',' -)"
    write_check "SYS-002" "reboot" "WARN" "Reboot required" "$reboot_pkgs"
  else
    write_check "SYS-002" "reboot" "OK" "No reboot-required marker found" "/var/run/reboot-required absent"
  fi

  if dpkg --audit >/tmp/toolbox_dpkg_audit_"$STAMP".txt 2>&1; then
    if [ -s /tmp/toolbox_dpkg_audit_"$STAMP".txt ]; then
      write_check "APT-001" "apt" "WARN" "dpkg audit produced output" "review report"
    else
      write_check "APT-001" "apt" "OK" "dpkg audit clean" "no broken/incomplete packages reported"
    fi
  else
    write_check "APT-001" "apt" "WARN" "dpkg audit returned non-zero" "review report"
  fi

  upgradable_count="$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')"
  if [ "$upgradable_count" -eq 0 ]; then
    write_check "APT-002" "apt" "OK" "No upgradable packages listed" "apt list --upgradable"
  else
    write_check "APT-002" "apt" "INFO" "Packages still upgradable" "$upgradable_count"
  fi

  if apt-mark showhold 2>/dev/null | grep -q .; then
    held="$(apt-mark showhold 2>/dev/null | paste -sd ',' -)"
    write_check "APT-003" "apt" "INFO" "Held packages detected" "$held"
  else
    write_check "APT-003" "apt" "OK" "No held packages detected" "apt-mark showhold empty"
  fi

  service_check "docker.service" "SVC-001" "services"
  service_check "containerd.service" "SVC-002" "services"
  service_check "tailscaled.service" "SVC-003" "services"
  service_check "ufw.service" "SVC-004" "services"
  service_check "network-manager.service" "SVC-005" "services"
  service_check "NetworkManager.service" "SVC-006" "services"

  command_check "docker" "CMD-001" "commands"
  command_check "tailscale" "CMD-002" "commands"
  command_check "ufw" "CMD-003" "commands"
  command_check "systemctl" "CMD-004" "commands"

  if docker ps >/tmp/toolbox_docker_ps_"$STAMP".txt 2>&1; then
    running_containers="$(tail -n +2 /tmp/toolbox_docker_ps_"$STAMP".txt | wc -l | tr -d ' ')"
    write_check "DOCKER-001" "docker" "OK" "docker ps succeeded" "$running_containers running container(s)"
  else
    write_check "DOCKER-001" "docker" "WARN" "docker ps failed" "review report"
  fi

  if tailscale status >/tmp/toolbox_tailscale_status_"$STAMP".txt 2>&1; then
    write_check "TAILSCALE-001" "tailscale" "OK" "tailscale status succeeded" "review report for details"
  else
    write_check "TAILSCALE-001" "tailscale" "WARN" "tailscale status failed" "review report"
  fi

  if sudo -n ufw status verbose >/tmp/toolbox_ufw_status_"$STAMP".txt 2>&1; then
    write_check "UFW-001" "firewall" "OK" "ufw status readable without sudo prompt" "review report"
  else
    if ufw status verbose >/tmp/toolbox_ufw_status_"$STAMP".txt 2>&1; then
      write_check "UFW-001" "firewall" "OK" "ufw status readable" "review report"
    else
      write_check "UFW-001" "firewall" "INFO" "ufw status not readable non-interactively" "run sudo ufw status verbose manually if needed"
    fi
  fi

  append_command_output "Kernel and reboot markers" uname -a
  append_command_output "Current boot images" ls -lh /boot/vmlinuz /boot/initrd.img /boot/vmlinuz.old /boot/initrd.img.old
  append_command_output "Reboot required packages" sh -c 'cat /var/run/reboot-required.pkgs 2>/dev/null || true'
  append_command_output "dpkg audit" sh -c "cat /tmp/toolbox_dpkg_audit_$STAMP.txt 2>/dev/null || true"
  append_command_output "Upgradable packages" apt list --upgradable
  append_command_output "Held packages" apt-mark showhold
  append_command_output "Docker service status" systemctl status docker --no-pager
  append_command_output "containerd service status" systemctl status containerd --no-pager
  append_command_output "Tailscale service status" systemctl status tailscaled --no-pager
  append_command_output "Docker ps" sh -c "cat /tmp/toolbox_docker_ps_$STAMP.txt 2>/dev/null || docker ps"
  append_command_output "Tailscale status" sh -c "cat /tmp/toolbox_tailscale_status_$STAMP.txt 2>/dev/null || tailscale status"
  append_command_output "UFW status" sh -c "cat /tmp/toolbox_ufw_status_$STAMP.txt 2>/dev/null || true"
  append_command_output "Desktop/GNOME package check" sh -c "dpkg-query -W -f='\${db:Status-Abbrev}\t\${binary:Package}\t\${Version}\n' 'ubuntu-desktop*' 'gnome-shell' 'gdm3' 'network-manager' 2>/dev/null || true"
  append_command_output "Recent apt history tail" sh -c "tail -n 180 /var/log/apt/history.log 2>/dev/null || true"

  warn_count="$(awk -F '\t' 'NR > 1 && $3 == "WARN" { c++ } END { print c+0 }' "$TSV")"

  {
    printf '\n'
    printf '%s\n' '## Summary'
    printf '\n'
    printf 'Warnings: %s\n' "$warn_count"
    printf '\n'
    printf '%s\n' 'Generated artifacts:'
    printf '%s\n' "- Report: $REPORT"
    printf '%s\n' "- TSV: $TSV"
  } >> "$REPORT"

  rm -f /tmp/toolbox_dpkg_audit_"$STAMP".txt
  rm -f /tmp/toolbox_docker_ps_"$STAMP".txt
  rm -f /tmp/toolbox_tailscale_status_"$STAMP".txt
  rm -f /tmp/toolbox_ufw_status_"$STAMP".txt

  log "Post-upgrade system check completed."
  log "Report: $REPORT"
  log "TSV: $TSV"
}

main "$@"
