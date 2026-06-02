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

REPORT="$REPORT_DIR/toolbox_knowledge_services_consistency_$STAMP.txt"
TSV="$RAW_DIR/toolbox_knowledge_services_consistency_$STAMP.tsv"

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
INFO_COUNT=0

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

ensure_output_dirs() {
  mkdir -p "$REPORT_DIR" "$RAW_DIR"
}

write_tsv_header() {
  printf 'timestamp\tstatus\tcheck_id\tpath\tdetail\n' > "$TSV"
}

emit_check() {
  local status="$1"
  local check_id="$2"
  local path="$3"
  local detail="$4"
  local now

  now="$(toolbox_now)"

  printf '[%s] %-5s %-56s %s\n' "$check_id" "$status" "$path" "$detail" >> "$REPORT"
  printf '%s\t%s\t%s\t%s\t%s\n' "$now" "$status" "$check_id" "$path" "$detail" >> "$TSV"

  case "$status" in
    OK) OK_COUNT=$((OK_COUNT + 1)) ;;
    WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    INFO) INFO_COUNT=$((INFO_COUNT + 1)) ;;
    *) WARN_COUNT=$((WARN_COUNT + 1)) ;;
  esac
}

write_header() {
  {
    printf '# Toolbox knowledge services consistency validation\n\n'
    printf 'Generated at: %s\n' "$(toolbox_now)"
    printf 'App dir: %s\n' "$APP_DIR"
    printf 'Shared dir: %s\n' "$SHARED_DIR"
    printf 'Report: %s\n' "$REPORT"
    printf 'TSV: %s\n\n' "$TSV"

    printf '## Scope\n\n'
    printf 'This validation reviews the current first service-map layer under `knowledge/services`.\n\n'
    printf 'It is read-only and does not inspect live service state, containers, mounts, firewall rules, media files, or backup repositories.\n\n'

    printf 'Expected service files for lote 1:\n\n'
    printf -- '- `knowledge/services/README.md`\n'
    printf -- '- `knowledge/services/toolbox.md`\n'
    printf -- '- `knowledge/services/docker.md`\n'
    printf -- '- `knowledge/services/networking.md`\n'
    printf -- '- `knowledge/services/nginx-proxy-manager.md`\n'
    printf -- '- `knowledge/services/samba.md`\n'
    printf -- '- `knowledge/services/backup.md`\n'
    printf -- '- `knowledge/services/filebrowser.md`\n'
    printf -- '- `knowledge/services/music-staging.md`\n'
    printf -- '- `knowledge/services/navidrome.md`\n\n'

    printf '## Checks\n\n'
  } > "$REPORT"
}

run_python_validation() {
  python3 - "$APP_DIR" "$REPORT" "$TSV" <<'PY'
from __future__ import annotations

from collections import Counter, defaultdict
from pathlib import Path
import re
import sys

app = Path(sys.argv[1])
report_path = Path(sys.argv[2])
tsv_path = Path(sys.argv[3])

expected_files = [
    "knowledge/services/README.md",
    "knowledge/services/toolbox.md",
    "knowledge/services/docker.md",
    "knowledge/services/networking.md",
    "knowledge/services/nginx-proxy-manager.md",
    "knowledge/services/samba.md",
    "knowledge/services/backup.md",
    "knowledge/services/filebrowser.md",
    "knowledge/services/music-staging.md",
    "knowledge/services/navidrome.md",
]

service_files = [
    "knowledge/services/toolbox.md",
    "knowledge/services/docker.md",
    "knowledge/services/networking.md",
    "knowledge/services/nginx-proxy-manager.md",
    "knowledge/services/samba.md",
    "knowledge/services/backup.md",
    "knowledge/services/filebrowser.md",
    "knowledge/services/music-staging.md",
    "knowledge/services/navidrome.md",
]

required_context_refs = [
    "knowledge/context/agent-entrypoint.md",
    "knowledge/context/homelab-context.md",
    "knowledge/context/toolbox-context.md",
]

required_policy_refs = [
    "knowledge/policies/agent-safety-policy.md",
    "knowledge/policies/change-management-policy.md",
    "knowledge/policies/reporting-policy.md",
    "knowledge/policies/filesystem-safety-policy.md",
    "knowledge/policies/media-curation-policy.md",
]

required_common_refs = [
    "knowledge/services/README.md",
    "knowledge/services/toolbox.md",
    "knowledge/services/docker.md",
    "docs/operations/toolbox_output_destinations_policy.md",
    "docs/operations/toolbox_script_conventions.md",
    "docs/operations/toolbox_storage_policy.md",
]

required_headings = [
    "Purpose",
    "Service type",
    "Current role in the homelab",
    "Important paths",
    "Related services",
    "Related scripts and workflows",
    "Related reports, TSVs, inventories, and logs",
    "Related policies and docs",
    "Sensitive operations",
    "Read-only inspection allowed",
    "Read-only collection plan",
    "Actions requiring approval",
    "Known historical lessons",
    "Open questions",
    "Source of truth",
]

allowed_service_types = {
    "technical_service",
    "operational_subsystem",
    "infrastructure_layer",
}

important_terms = [
    "diagnose",
    "plan",
    "apply",
    "validate",
    "approval",
    "read-only",
    "script inventory",
    "/srv/toolbox/app",
    "/srv/toolbox/shared",
    "knowledge/architecture/historical-operational-lessons.md",
    "knowledge/architecture/open-questions.md",
]

accepted_repeated_lines = {
    "Agents must not treat memory, old reports, or chat history as proof of current host state.",
    "A general instruction to continue is not approval for unrelated changes.",
    "Service-specific lessons should be summarized here only when they directly affect operation.",
}

ok = warn = fail = info = 0

def tsv_escape(value: object) -> str:
    return str(value).replace("\t", " ").replace("\r", " ").replace("\n", " ")

def emit(status: str, check_id: str, path: str, detail: str) -> None:
    global ok, warn, fail, info

    with report_path.open("a", encoding="utf-8") as report:
        report.write(f"[{check_id}] {status:<5} {path:<56} {detail}\n")

    from datetime import datetime
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    with tsv_path.open("a", encoding="utf-8") as tsv:
        tsv.write(
            "\t".join(
                [
                    tsv_escape(timestamp),
                    tsv_escape(status),
                    tsv_escape(check_id),
                    tsv_escape(path),
                    tsv_escape(detail),
                ]
            )
            + "\n"
        )

    if status == "OK":
        ok += 1
    elif status == "WARN":
        warn += 1
    elif status == "FAIL":
        fail += 1
    elif status == "INFO":
        info += 1
    else:
        warn += 1

def read_rel(rel: str) -> str:
    return (app / rel).read_text(encoding="utf-8", errors="replace")

def exists(rel: str) -> bool:
    return (app / rel).exists()

def has_heading(text: str, heading: str) -> bool:
    return re.search(rf"^##+\s+{re.escape(heading)}\s*$", text, re.MULTILINE) is not None

def extract_service_type(text: str) -> str:
    match = re.search(r"^`([^`]+)`\s*$", text, re.MULTILINE)
    if match:
        return match.group(1)
    return ""

def markdown_fence_count(text: str) -> int:
    return text.count("```")

def extract_backtick_paths(text: str) -> set[str]:
    values = set(re.findall(r"`([^`]+)`", text))
    paths = set()
    for value in values:
        if value.startswith(("knowledge/", "docs/", "scripts/", "bin/")):
            paths.add(value)
    return paths

def is_expected_future_path(path: str) -> bool:
    future_paths = {
        "knowledge/architecture/historical-operational-lessons.md",
        "knowledge/architecture/open-questions.md",
        "knowledge/services/calibre-web.md",
        "knowledge/services/homepage.md",
        "knowledge/services/immich.md",
        "knowledge/services/jellyfin.md",
        "knowledge/services/kavita.md",
        "knowledge/services/monitoring.md",
        "knowledge/services/portainer.md",
        "knowledge/services/slskd.md",
    }
    return path in future_paths

for rel in expected_files:
    if exists(rel):
        emit("OK", "service_exists", rel, "service file exists")
    else:
        emit("FAIL", "service_exists", rel, "service file missing")

for rel in expected_files:
    if not exists(rel):
        continue

    text = read_rel(rel)
    count = markdown_fence_count(text)
    if count % 2 == 0:
        emit("OK", "markdown_fence", rel, f"balanced markdown code fences: {count}")
    else:
        emit("FAIL", "markdown_fence", rel, f"unbalanced markdown code fences: {count}")

for rel in service_files:
    if not exists(rel):
        continue

    text = read_rel(rel)

    for heading in required_headings:
        if has_heading(text, heading):
            emit("OK", "heading", rel, f"heading found: {heading}")
        else:
            emit("FAIL", "heading", rel, f"heading missing: {heading}")

    service_type = extract_service_type(text)
    if service_type in allowed_service_types:
        emit("OK", "service_type", rel, f"recognized service type: {service_type}")
    elif service_type:
        emit("WARN", "service_type", rel, f"unrecognized service type: {service_type}")
    else:
        emit("FAIL", "service_type", rel, "service type not found")

    for ref in required_context_refs:
        if ref in text:
            emit("OK", "context_reference", rel, f"reference found: {ref}")
        else:
            emit("FAIL", "context_reference", rel, f"reference missing: {ref}")

    for ref in required_policy_refs:
        if ref in text:
            emit("OK", "policy_reference", rel, f"reference found: {ref}")
        else:
            emit("FAIL", "policy_reference", rel, f"reference missing: {ref}")

    for ref in required_common_refs:
        if ref == rel:
            continue
        if ref in text:
            emit("OK", "common_reference", rel, f"reference found: {ref}")
        else:
            emit("WARN", "common_reference", rel, f"reference missing: {ref}")

    for term in important_terms:
        if term in text:
            emit("OK", "term", rel, f"term found: {term}")
        else:
            emit("WARN", "term", rel, f"term missing: {term}")

    if "latest Toolbox script inventory report and TSV" in text:
        emit("OK", "script_inventory", rel, "read-only collection references latest script inventory")
    else:
        emit("WARN", "script_inventory", rel, "read-only collection does not explicitly reference latest script inventory")

    if "A general instruction to continue is not approval" in text:
        emit("OK", "approval_boundary", rel, "general continuation is not treated as approval")
    else:
        emit("WARN", "approval_boundary", rel, "approval boundary phrase missing")

all_text = "\n".join(read_rel(rel) for rel in expected_files if exists(rel))

for term in [
    "Toolbox",
    "Docker",
    "Networking",
    "Nginx Proxy Manager",
    "Samba",
    "Backup",
    "FileBrowser",
    "Music Staging",
    "Navidrome",
    "Tailscale",
    "UFW",
    "DOCKER-USER",
    "Restic",
    "Backrest",
    "Beets",
    "MusicBrainz",
    "Feishin",
    "Amperfy",
]:
    count = all_text.count(term)
    if count > 0:
        emit("OK", "corpus_term", "knowledge/services", f"term found across service corpus: {term} ({count} matches)")
    else:
        emit("WARN", "corpus_term", "knowledge/services", f"term missing across service corpus: {term}")

path_refs = set()
for rel in expected_files:
    if not exists(rel):
        continue
    path_refs.update(extract_backtick_paths(read_rel(rel)))

for ref in sorted(path_refs):
    if exists(ref):
        emit("OK", "path_reference", ref, "referenced path exists")
    elif is_expected_future_path(ref):
        emit("INFO", "path_reference", ref, "referenced future path does not exist yet")
    else:
        emit("WARN", "path_reference", ref, "referenced path not found")

line_occurrences: dict[str, set[str]] = defaultdict(set)

for rel in service_files:
    if not exists(rel):
        continue

    for line in read_rel(rel).splitlines():
        stripped = " ".join(line.strip().split())
        if len(stripped) < 100:
            continue
        if stripped.startswith(("*", "-", "#")):
            continue
        if stripped in accepted_repeated_lines:
            continue
        line_occurrences[stripped].add(rel)

repeated = [
    (line, sorted(paths))
    for line, paths in line_occurrences.items()
    if len(paths) >= 4
]

if repeated:
    for line, paths in sorted(repeated)[:20]:
        emit("WARN", "repeated_line", "knowledge/services", f"line repeated in {len(paths)} service files: {line[:180]}")
else:
    emit("OK", "repeated_line", "knowledge/services", "no strong repeated long lines detected across four or more service files")

with report_path.open("a", encoding="utf-8") as report:
    report.write("\n## Service files\n\n")
    for rel in expected_files:
        if exists(rel):
            report.write(f"{rel}\n")
    report.write("\n")

    report.write("## Summary\n\n")
    report.write(f"OK: {ok}\n")
    report.write(f"WARN: {warn}\n")
    report.write(f"FAIL: {fail}\n")
    report.write(f"INFO: {info}\n")
PY
}

append_git_checks() {
  {
    printf '\n## Git checks\n\n'
  } >> "$REPORT"

  if git -C "$APP_DIR" diff --check >> "$REPORT" 2>&1; then
    emit_check "OK" "git_diff_check" "$APP_DIR" "git diff --check passed"
  else
    emit_check "FAIL" "git_diff_check" "$APP_DIR" "git diff --check reported problems"
  fi

  local status
  status="$(git -C "$APP_DIR" status --short)"

  if [ -z "$status" ]; then
    emit_check "OK" "git_status" "$APP_DIR" "working tree clean"
  else
    emit_check "WARN" "git_status" "$APP_DIR" "working tree has pending changes"
    {
      printf '\n## Git status --short\n\n'
      printf '%s\n' "$status"
    } >> "$REPORT"
  fi
}

append_final_summary() {
  {
    printf '\n## Final validator summary\n\n'
    printf 'OK: %s\n' "$OK_COUNT"
    printf 'WARN: %s\n' "$WARN_COUNT"
    printf 'FAIL: %s\n' "$FAIL_COUNT"
    printf 'INFO: %s\n' "$INFO_COUNT"
    printf '\n'
  } >> "$REPORT"
}

main() {
  require_lib_contract
  ensure_output_dirs
  write_tsv_header
  write_header

  log "Starting Toolbox knowledge services consistency validation."

  run_python_validation

  if grep -Eq '^FAIL: [1-9][0-9]*$' "$REPORT"; then
    emit_check "FAIL" "python_validation" "knowledge/services" "Python service consistency checks reported failures"
  else
    emit_check "OK" "python_validation" "knowledge/services" "Python service consistency checks passed"
  fi

  append_git_checks
  append_final_summary

  log "Toolbox knowledge services consistency validation completed."
  log "Report: $REPORT"
  log "TSV: $TSV"

  if [ "$FAIL_COUNT" -gt 0 ]; then
    return 1
  fi

  return 0
}

main "$@"
