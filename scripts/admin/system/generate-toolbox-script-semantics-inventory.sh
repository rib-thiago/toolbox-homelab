#!/usr/bin/env bash
set -u

APP_DIR="${APP_DIR:-/srv/toolbox/app}"
LIB_DIR="$APP_DIR/scripts/lib"
GENERATOR_SCRIPT="scripts/admin/system/generate-toolbox-script-semantics-inventory.sh"

source "$LIB_DIR/logging.sh"
source "$LIB_DIR/timestamps.sh"
source "$LIB_DIR/paths.sh"

STAMP="$(toolbox_timestamp)"
GENERATED_AT="$(toolbox_now)"
SHARED_DIR="$(toolbox_shared_dir)"

RAW_DIR="$SHARED_DIR/library-db/raw/system"
REPORT_DIR="$SHARED_DIR/reports/system"
INVENTORY_DIR="$SHARED_DIR/inventory/toolbox"

RAW_OUT_TSV=""
NORMALIZED_OUT_TSV=""
OUT_REPORT=""

SOURCE_INVENTORY=""
RAW_SCRIPT_INVENTORY=""
SCOPE_NAME="block1-core-platform"

usage() {
  cat <<'EOF'
Usage:
  generate-toolbox-script-semantics-inventory.sh
  generate-toolbox-script-semantics-inventory.sh --scope block1-core-platform
  generate-toolbox-script-semantics-inventory.sh --scope block2-admin-system-git
  generate-toolbox-script-semantics-inventory.sh --scope block3-infrastructure-admin
  generate-toolbox-script-semantics-inventory.sh --source-inventory PATH
  generate-toolbox-script-semantics-inventory.sh --raw-script-inventory PATH
  generate-toolbox-script-semantics-inventory.sh --scope SCOPE --source-inventory PATH --raw-script-inventory PATH
  generate-toolbox-script-semantics-inventory.sh --help

Generate toolbox_script_semantics_inventory_v0 for a named bounded source scope.

This generator reads source bodies only. It does not execute scoped scripts, pipelines,
run-job, validators, diagnostics, apply workflows, services, media paths, configs,
secrets, credentials, or backup repositories.

Supported scopes:
  block1-core-platform       bin/*, scripts/helpers/*, scripts/lib/*, scripts/pipelines/*
  block2-admin-system-git    scripts/admin/system/*, scripts/admin/git/*
  block3-infrastructure-admin scripts/admin/backup/*, docker/*, firewall/*, network/*, storage/*

Default scope:
  block1-core-platform

Block scopes are deterministic and bounded. They do not expand to live services,
media, configs, secrets, credentials, backup repositories, or unrelated paths.

Block 1 scope:
  bin/*
  scripts/helpers/*
  scripts/lib/*
  scripts/pipelines/*

Block 2 scope:
  scripts/admin/system/*
  scripts/admin/git/*

Block 3 scope:
  scripts/admin/backup/*
  scripts/admin/docker/*
  scripts/admin/firewall/*
  scripts/admin/network/*
  scripts/admin/storage/*

Outputs:
  /srv/toolbox/shared/library-db/raw/system/toolbox_script_semantics_inventory_SCOPE_YYYYMMDD-HHMMSS.tsv
  /srv/toolbox/shared/inventory/toolbox/toolbox_script_semantics_inventory_SCOPE_YYYYMMDD-HHMMSS.tsv
  /srv/toolbox/shared/reports/system/toolbox_script_semantics_inventory_report_SCOPE_YYYYMMDD-HHMMSS.txt
EOF
}

build_block1_scope() {
  (
    cd "$APP_DIR" || exit 1
    find bin scripts/helpers scripts/lib scripts/pipelines -maxdepth 1 -type f -printf '%p\n' 2>/dev/null \
      | sort
  )
}

build_block2_scope() {
  (
    cd "$APP_DIR" || exit 1
    find scripts/admin/system scripts/admin/git -maxdepth 1 -type f -printf '%p\n' 2>/dev/null \
      | sort
  )
}

build_block3_scope() {
  (
    cd "$APP_DIR" || exit 1
    find scripts/admin/backup scripts/admin/docker scripts/admin/firewall scripts/admin/network scripts/admin/storage -maxdepth 1 -type f -printf '%p\n' 2>/dev/null \
      | sort
  )
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

latest_matching_file() {
  local dir="$1"
  local pattern="$2"

  find "$dir" -maxdepth 1 -type f -name "$pattern" -printf '%T@ %p\n' 2>/dev/null \
    | sort -n \
    | tail -n 1 \
    | cut -d' ' -f2-
}

infer_report_for_inventory() {
  local source_path="$1"
  local base
  local stamp
  local candidate

  base="$(basename "$source_path")"
  stamp="${base#toolbox_inventory_}"
  stamp="${stamp%.tsv}"
  candidate="$REPORT_DIR/toolbox_inventory_report_$stamp.txt"

  if [ -f "$candidate" ]; then
    printf '%s\n' "$candidate"
  else
    printf '%s\n' "unknown"
  fi
}

infer_report_for_raw_script_inventory() {
  local source_path="$1"
  local base
  local stamp
  local candidate

  base="$(basename "$source_path")"
  stamp="${base#toolbox_script_inventory_}"
  stamp="${stamp%.tsv}"
  candidate="$REPORT_DIR/toolbox_script_inventory_report_$stamp.txt"

  if [ -f "$candidate" ]; then
    printf '%s\n' "$candidate"
  else
    printf '%s\n' "unknown"
  fi
}

git_branch_value() {
  if git -C "$APP_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$APP_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || printf '%s\n' "unknown"
  else
    printf '%s\n' "unknown"
  fi
}

git_commit_value() {
  if git -C "$APP_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$APP_DIR" rev-parse HEAD 2>/dev/null || printf '%s\n' "unknown"
  else
    printf '%s\n' "unknown"
  fi
}

git_status_value() {
  local status_out

  if ! git -C "$APP_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '%s\n' "unknown"
    return 0
  fi

  status_out="$(git -C "$APP_DIR" status --short 2>/dev/null)"
  if [ $? -ne 0 ]; then
    printf '%s\n' "unknown"
  elif [ -n "$status_out" ]; then
    printf '%s\n' "dirty"
  else
    printf '%s\n' "clean"
  fi
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --source-inventory)
        shift
        if [ "$#" -eq 0 ]; then
          fail "Missing value for --source-inventory."
        fi
        SOURCE_INVENTORY="$1"
        ;;
      --raw-script-inventory)
        shift
        if [ "$#" -eq 0 ]; then
          fail "Missing value for --raw-script-inventory."
        fi
        RAW_SCRIPT_INVENTORY="$1"
        ;;
      --scope)
        shift
        if [ "$#" -eq 0 ]; then
          fail "Missing value for --scope."
        fi
        case "$1" in
          block1-core-platform|block2-admin-system-git|block3-infrastructure-admin)
            SCOPE_NAME="$1"
            ;;
          *)
            fail "Unsupported scope: $1"
            ;;
        esac
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

ensure_inputs() {
  if [ -z "$SOURCE_INVENTORY" ]; then
    SOURCE_INVENTORY="$(latest_matching_file "$INVENTORY_DIR" 'toolbox_inventory_*.tsv')"
  fi

  if [ -z "$RAW_SCRIPT_INVENTORY" ]; then
    RAW_SCRIPT_INVENTORY="$(latest_matching_file "$RAW_DIR" 'toolbox_script_inventory_*.tsv')"
  fi

  if [ -z "$SOURCE_INVENTORY" ]; then
    fail "No source inventory found under $INVENTORY_DIR"
  fi

  if [ -z "$RAW_SCRIPT_INVENTORY" ]; then
    fail "No raw script inventory found under $RAW_DIR"
  fi

  if [ ! -r "$SOURCE_INVENTORY" ]; then
    fail "Source inventory is not readable: $SOURCE_INVENTORY"
  fi

  if [ ! -r "$RAW_SCRIPT_INVENTORY" ]; then
    fail "Raw script inventory is not readable: $RAW_SCRIPT_INVENTORY"
  fi
}

ensure_output_dirs() {
  mkdir -p "$RAW_DIR" "$REPORT_DIR" "$INVENTORY_DIR" || fail "Unable to create output directories"
}

run_generation() {
  local source_report
  local raw_script_report
  local git_branch
  local git_commit
  local git_status
  local scope_batch
  local scope_slug
  local -a selected_scope

  source_report="$(infer_report_for_inventory "$SOURCE_INVENTORY")"
  raw_script_report="$(infer_report_for_raw_script_inventory "$RAW_SCRIPT_INVENTORY")"
  git_branch="$(git_branch_value)"
  git_commit="$(git_commit_value)"
  git_status="$(git_status_value)"

  case "$SCOPE_NAME" in
    block1-core-platform)
      scope_batch="block1_core_platform_v0"
      scope_slug="block1_core_platform"
      mapfile -t selected_scope < <(build_block1_scope)
      ;;
    block2-admin-system-git)
      scope_batch="block2_admin_system_git_v0"
      scope_slug="block2_admin_system_git"
      mapfile -t selected_scope < <(build_block2_scope)
      ;;
    block3-infrastructure-admin)
      scope_batch="block3_infrastructure_admin_v0"
      scope_slug="block3_infrastructure_admin"
      mapfile -t selected_scope < <(build_block3_scope)
      ;;
    *)
      fail "Unsupported scope: $SCOPE_NAME"
      ;;
  esac

  if [ "${#selected_scope[@]}" -eq 0 ]; then
    fail "Scope collector found no files for: $SCOPE_NAME"
  fi

  RAW_OUT_TSV="$RAW_DIR/toolbox_script_semantics_inventory_${scope_slug}_$STAMP.tsv"
  NORMALIZED_OUT_TSV="$INVENTORY_DIR/toolbox_script_semantics_inventory_${scope_slug}_$STAMP.tsv"
  OUT_REPORT="$REPORT_DIR/toolbox_script_semantics_inventory_report_${scope_slug}_$STAMP.txt"

  python3 - "$APP_DIR" "$GENERATED_AT" "$RAW_SCRIPT_INVENTORY" "$raw_script_report" "$SOURCE_INVENTORY" "$source_report" "$RAW_OUT_TSV" "$NORMALIZED_OUT_TSV" "$OUT_REPORT" "$GENERATOR_SCRIPT" "$git_branch" "$git_commit" "$git_status" "$scope_batch" "${selected_scope[@]}" <<'PY'
from __future__ import annotations

from collections import Counter
import csv
import re
import sys
from pathlib import Path

app = Path(sys.argv[1])
generated_at = sys.argv[2]
raw_script_inventory = Path(sys.argv[3])
raw_script_report = sys.argv[4]
source_inventory = Path(sys.argv[5])
source_report = sys.argv[6]
raw_out_tsv = Path(sys.argv[7])
normalized_out_tsv = Path(sys.argv[8])
out_report = Path(sys.argv[9])
generator_script = sys.argv[10]
git_branch = sys.argv[11] or "unknown"
git_commit = sys.argv[12] or "unknown"
git_status = sys.argv[13] or "unknown"
scope_batch = sys.argv[14] or "unknown_scope"
scope_paths = list(sys.argv[15:])

semantic_schema = "toolbox_script_semantics_inventory_v0"

raw_columns = [
    "semantic_schema_version",
    "timestamp",
    "path",
    "scope_batch",
    "source_body_read",
    "source_line_count",
    "path_entity_type",
    "raw_phase",
    "raw_kind",
    "semantic_entity_type",
    "semantic_runtime",
    "semantic_automation_type",
    "source_body_summary",
    "implemented_contracts",
    "entrypoint_style",
    "argument_contract",
    "reads_paths",
    "writes_paths",
    "evidence_outputs",
    "uses_libraries",
    "calls_toolbox_commands",
    "calls_external_commands",
    "calls_git",
    "uses_run_job_contract",
    "pipeline_contract_status",
    "job_root_contract_status",
    "input_work_output_status",
    "status_file_behavior",
    "log_behavior",
    "side_effect_class",
    "confirmation_gate",
    "placeholder_status",
    "relation_candidate_types",
    "relation_candidate_targets",
    "relation_candidate_basis",
    "semantic_confidence",
    "runtime_validated",
    "runtime_validation_evidence",
    "warnings",
    "source_inventory",
    "source_report",
    "source_tsv",
    "repo_root",
    "git_commit",
    "git_status",
]

normalized_columns = [
    "inventory_schema_version",
    "timestamp",
    "domain",
    "subdomain",
    "entity_type",
    "entity_id",
    "path",
    "name",
    "semantic_entity_type",
    "semantic_runtime",
    "semantic_automation_type",
    "status",
    "placeholder_status",
    "implemented_contracts",
    "semantic_summary",
    "relation_candidate_type",
    "related_entity_type",
    "related_entity_id",
    "related_path",
    "relation_basis",
    "relation_confidence",
    "runtime_validated",
    "runtime_validation_evidence",
    "evidence_type",
    "confidence",
    "source_semantics_tsv",
    "source_semantics_report",
    "source_inventory",
    "source_report",
    "source_tsv",
    "generator_script",
    "repo_root",
    "git_branch",
    "git_commit",
    "git_status",
]

def clean(value: object) -> str:
    text = str(value)
    text = text.replace("\t", " ").replace("\r", " ").replace("\n", " ")
    text = re.sub(r"\s+", " ", text).strip()
    return text if text else "unknown"

def join_values(values: list[str]) -> str:
    seen: set[str] = set()
    filtered: list[str] = []
    for value in values:
        cleaned = clean(value)
        if cleaned == "unknown" or cleaned in seen:
            continue
        seen.add(cleaned)
        filtered.append(cleaned)
    return ";".join(filtered) if filtered else "none"

def read_tsv(path: Path, key: str) -> dict[str, dict[str, str]]:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        return {row.get(key, ""): row for row in reader if row.get(key, "")}

def path_entity_type(path: str) -> str:
    if path.startswith("bin/"):
        return "command"
    if path.startswith("scripts/pipelines/"):
        return "pipeline"
    if path.startswith("scripts/lib/"):
        return "library_module"
    if path.startswith("scripts/helpers/"):
        return "helper"
    return "script"

def output_destination_findings(text: str) -> tuple[list[str], list[str], list[str], list[str]]:
    warnings: list[str] = []
    implemented: list[str] = []
    targets: list[str] = []
    basis: list[str] = []
    if "$HOME/relatorios-disco" in text or "relatorios-disco" in text:
        warnings.append("legacy destination: $HOME/relatorios-disco")
        implemented.append("destination_policy_legacy_home_reports")
        targets.append("$HOME/relatorios-disco")
        basis.append("source_body_legacy_home_report_destination")
    if "/srv/toolbox/shared/reports/media" in text or 'reports/media' in text:
        warnings.append("provisional destination: /srv/toolbox/shared/reports/media")
        implemented.append("destination_policy_provisional_reports_media")
        targets.append("/srv/toolbox/shared/reports/media")
        basis.append("source_body_provisional_report_destination")
    if "/srv/toolbox/shared/library-db/raw" in text and "/srv/toolbox/shared/library-db/raw/system" not in text and "/srv/toolbox/shared/library-db/raw/git" not in text:
        warnings.append("provisional destination: /srv/toolbox/shared/library-db/raw")
        implemented.append("destination_policy_provisional_raw_root")
        targets.append("/srv/toolbox/shared/library-db/raw")
        basis.append("source_body_provisional_raw_destination")
    return warnings, implemented, targets, basis

def subdomain_for(path: str, raw_row: dict[str, str]) -> str:
    if raw_row.get("domain"):
        return raw_row["domain"]
    parts = path.split("/")
    if parts[0] == "bin":
        return "bin"
    if len(parts) >= 3 and parts[0] == "scripts" and parts[1] in {"admin", "media"}:
        return "/".join(parts[:3])
    if len(parts) >= 2 and parts[0] == "scripts":
        return "/".join(parts[:2])
    return "unknown"

def first_comment_summary(text: str) -> str:
    for line in text.splitlines()[:40]:
        stripped = line.strip()
        if not stripped or stripped.startswith("#!"):
            continue
        if stripped.startswith("#"):
            return stripped.lstrip("#").strip()[:180] or "unknown"
    return "unknown"

def command_paths(text: str) -> list[str]:
    matches = set(re.findall(r"/toolbox/app/bin/[A-Za-z0-9._/-]+", text))
    return sorted(matches)

def helper_paths(text: str) -> list[str]:
    matches = set(re.findall(r"/toolbox/app/(scripts/helpers/[A-Za-z0-9._/-]+\.sh)", text))
    return sorted(matches)

def run_job_pipeline_name(text: str) -> str:
    match = re.search(r"/toolbox/app/bin/run-job\s+([A-Za-z0-9._-]+)", text)
    return match.group(1) if match else ""

def sourced_libraries(text: str) -> list[str]:
    libs = set()
    for match in re.findall(r"source\s+[^'\"]*['\"]?([^'\"\n ]*scripts/lib/[A-Za-z0-9._/-]+\.sh)", text):
        libs.add(match.replace(str(app) + "/", ""))
    for match in re.findall(r"source\s+\"\$LIB_DIR/([A-Za-z0-9._-]+\.sh)\"", text):
        libs.add(f"scripts/lib/{match}")
    return sorted(libs)

def external_commands(text: str) -> list[str]:
    candidates = []
    for cmd in ["python3", "git", "find", "sort", "tail", "cut", "cp", "mkdir", "cat", "date", "hostname", "id", "wc", "sed", "head", "basename", "ls", "env", "mktemp", "mv", "exiftool", "magick", "tesseract", "pdftoppm", "pdftotext", "restic", "wipefs", "parted", "partprobe", "mkfs.ext4", "ufw", "iptables", "iptables-restore", "docker", "tailscale", "smartctl", "apt", "snap", "flatpak"]:
        if re.search(rf"(^|[^A-Za-z0-9_/-]){re.escape(cmd)}($|[^A-Za-z0-9_-])", text):
            candidates.append(cmd)
    if "google.cloud.translate_v2" in text:
        candidates.append("google.cloud.translate_v2")
    return candidates

def executable_lines(text: str) -> list[str]:
    lines: list[str] = []
    heredoc_end = ""

    for raw_line in text.splitlines():
        stripped = raw_line.strip()

        if heredoc_end:
            if stripped == heredoc_end:
                heredoc_end = ""
            continue

        heredoc_match = re.search(r"<<-?\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?", raw_line)
        if heredoc_match:
            heredoc_end = heredoc_match.group(1)
            continue

        if not stripped or stripped.startswith("#") or stripped.startswith("#!"):
            continue

        lines.append(stripped)

    return lines

def line_has_git_action(line: str, actions: set[str]) -> bool:
    escaped = "|".join(re.escape(action) for action in sorted(actions))
    match = re.search(rf"(^|[;&|(){{}}])\s*(command\s+)?git(\s+-C\s+\S+)?\s+({escaped})(\s|$)", line)
    if not match:
        return False
    action = match.group(4)
    if action == "tag" and re.search(r"(^|[;&|(){}])\s*(command\s+)?git(\s+-C\s+\S+)?\s+tag\s*(\||;|\)|$|--list|-l)", line):
        return False
    return True

def line_is_weak_text_writer(line: str) -> bool:
    return bool(re.match(r"^(printf|echo|cat\s+<<|append_cmd|append_command|append_shell|write_step|write_check|record|tsv_row|section|subsection|validate_[A-Za-z0-9_]+)\b", line))

def line_mentions_shell_profile(line: str) -> bool:
    tokens = [
        ".bashrc",
        ".profile",
        ".bash_aliases",
        ".bashrc.d",
        ".bash_aliases.d",
        "$ALIAS_DIR",
        "$DEV_FILE",
        "$ARTIFACTS_FILE",
        "$JOBS_FILE",
    ]
    return any(token in line for token in tokens)

def line_modifies_shell_profile(line: str) -> bool:
    if line_is_weak_text_writer(line) or not line_mentions_shell_profile(line):
        return False
    return bool(
        re.search(r"(^|[;&|(){}\s])(cp|mv|rm|mkdir|chmod|install|touch)\b", line)
        or re.search(r"(^|[;&|(){}\s])sed\s+-i\b", line)
        or re.search(r"(>|>>)\s*\"\$?(ALIAS_DIR|DEV_FILE|ARTIFACTS_FILE|JOBS_FILE)", line)
        or re.search(r"(>|>>)\s*.*(\.bashrc|\.profile|\.bash_aliases|\.bashrc\.d|\.bash_aliases\.d)", line)
    )

def line_checks_shell_profile(line: str) -> bool:
    return line_mentions_shell_profile(line) and not line_modifies_shell_profile(line)

def line_mentions_manpage_access(line: str) -> bool:
    tokens = ["MANPATH", "tbman", "mandb"]
    return any(token in line for token in tokens)

def line_modifies_manpage_access(line: str) -> bool:
    if line_is_weak_text_writer(line) or not line_mentions_manpage_access(line):
        return False
    return bool(
        re.search(r"(^|[;&|(){}\s])(cp|ln|chmod|mkdir|install|touch)\b", line)
        or re.search(r"(^|[;&|(){}\s])update-alternatives\b", line)
        or re.search(r"(^|[;&|(){}\s])tbman\s+.*\b(install|apply|link|enable)\b", line)
    )

def line_checks_manpage_access(line: str) -> bool:
    return line_mentions_manpage_access(line) and not line_modifies_manpage_access(line)

def line_has_host_change(line: str) -> bool:
    if line_is_weak_text_writer(line):
        return False

    patterns = [
        r"(^|[;&|(){}\s])sudo\s+apt\s+(update|install|remove|purge|autoremove)\b",
        r"(^|[;&|(){}\s])apt\s+(install|remove|purge|autoremove)\b",
        r"(^|[;&|(){}\s])pipx\s+install\b",
        r"(^|[;&|(){}\s])hostnamectl\s+set-hostname\b",
        r"(^|[;&|(){}\s])snap\s+remove\b",
    ]
    return (
        any(re.search(pattern, line) for pattern in patterns)
        or line_modifies_shell_profile(line)
        or line_modifies_manpage_access(line)
    )

def has_executable_git_action(lines: list[str], actions: set[str]) -> bool:
    return any(line_has_git_action(line, actions) and not line_is_weak_text_writer(line) for line in lines)

def has_planned_git_action(text: str, actions: set[str]) -> bool:
    if not re.search(r"(plan|planned|proposed|next commands|append_cmd|write_step|report)", text, re.IGNORECASE):
        return False
    action_re = "|".join(re.escape(action) for action in sorted(actions))
    return bool(re.search(rf"\bgit\s+({action_re})\b", text))

def actual_confirmation_gate(text: str, lines: list[str]) -> bool:
    strong_lines = [line for line in lines if not line_is_weak_text_writer(line)]
    joined = "\n".join(strong_lines)
    return bool(
        re.search(r"read\s+-r\s+\w*confirmation", joined)
        or re.search(r"\[\s*\"\$\w*(confirmation|APPLY_MODE|arg_confirmation)\w*\"\s*(!=|=)\s*\"(APPLY|COMMIT|PUSH|--apply)\"", joined)
        or re.search(r"case\s+\"\$\{?1[^\"\n]*\}?\"", joined)
        and any("--apply)" in line or "--push)" in line for line in strong_lines)
    )

def script_has_apply_behavior(name: str, lines: list[str]) -> bool:
    return name.startswith("apply-") or (
        actual_confirmation_gate("", lines)
        and any(line_has_host_change(line) or line_has_git_action(line, {"add", "rm", "reset", "commit", "tag", "push"}) for line in lines)
    )

def helper_summary(path: str, externals: list[str], text: str) -> str:
    if path.endswith("/exif.sh"):
        return "Reads image metadata with exiftool and can write a metadata-stripped output copy."
    if path.endswith("/img-convert.sh"):
        return "Converts or resizes images with ImageMagick magick and writes an explicit output file."
    if path.endswith("/ocr.sh"):
        return "Runs OCR on an image with tesseract and writes text to stdout or an output file."
    if path.endswith("/pdf-images.sh"):
        return "Extracts PDF pages to image files with pdftoppm."
    if path.endswith("/pdf-text.sh"):
        return "Extracts text from a PDF with pdftotext."
    if path.endswith("/translate.sh"):
        return "Translates text through the Google Cloud Translate Python client."
    return first_comment_summary(text)

def admin_summary(path: str, semantic_entity_type: str, text: str) -> str:
    name = Path(path).name
    comment = first_comment_summary(text)
    if semantic_entity_type == "generator":
        if "generate-toolbox-inventory" in name:
            return "Transforms raw Toolbox script inventory evidence into toolbox_inventory_v0 artifacts."
        if "generate-toolbox-script-semantics-inventory" in name:
            return "Reads bounded source-body scopes and writes raw, normalized, and report semantic inventory artifacts."
        if "diagnose-toolbox-script-inventory" in name:
            return "Scans Toolbox source files and writes raw script inventory TSV/report evidence."
    if semantic_entity_type == "validator":
        return comment if comment != "unknown" else "Validates Toolbox knowledge, documentation, policy, service, script, or shell-helper consistency and writes evidence."
    if semantic_entity_type == "diagnostic":
        return comment if comment != "unknown" else "Runs a read-oriented Toolbox or host diagnostic and writes report/TSV evidence."
    if semantic_entity_type == "plan":
        return comment if comment != "unknown" else "Produces a plan or dry-run evidence artifact without applying changes."
    if semantic_entity_type == "apply_workflow":
        return comment if comment != "unknown" else "Approval-required host-changing workflow; source body indicates apply behavior."
    if semantic_entity_type == "stage_workflow":
        return comment if comment != "unknown" else "Controlled Git index staging workflow with explicit file scope and confirmation gate."
    if semantic_entity_type == "git_workflow":
        return comment if comment != "unknown" else "Controlled Git workflow with generated report/TSV evidence and confirmation gates where required."
    if semantic_entity_type == "backup_snapshot":
        return comment if comment != "unknown" else "Creates documentation backup, snapshot, report, or TSV evidence."
    if semantic_entity_type == "audit":
        return comment if comment != "unknown" else "Audits host, repository, or Toolbox structure and writes human-readable evidence."
    if name == "collect-git-commit-context.sh":
        return "Collects Git status, recent commit context, selected diffs, and repository change evidence for review."
    if name == "git-context-report.sh":
        return "Generates Git repository context, history, diff, and dashboard reports without writing Git history."
    if name == "remove-snap-stack-safe.sh":
        return "Legacy host-changing support tool that removes selected snap packages and writes a system report."
    if name == "rename-host-homelab.sh":
        return "Legacy host-changing support tool that backs up host files and renames the host."
    return comment

def classify_block2(path: str, text: str, raw_row: dict[str, str], warnings: list[str], implemented: list[str], relation_types: list[str], relation_targets: list[str], relation_basis: list[str], reads_paths: list[str], writes_paths: list[str], evidence_outputs: list[str]) -> dict[str, str] | None:
    name = Path(path).name
    phase = raw_row.get("phase", "") or ""
    lines = executable_lines(text)
    exec_text = "\n".join(lines)

    if not (path.startswith("scripts/admin/system/") or path.startswith("scripts/admin/git/")):
        return None

    semantic_entity_type = "support_tool"
    semantic_automation_type = "support tool"
    semantic_runtime = "host"
    semantic_confidence = "source_contract_high"
    confirmation_gate = "no"
    side_effect_class = "source_read_only_analysis"
    entrypoint_style = "cli"
    argument_contract = "script-specific CLI arguments"

    if name.startswith("validate-"):
        semantic_entity_type = "validator"
        semantic_automation_type = "validator"
    elif name.startswith("diagnose-"):
        if name == "diagnose-toolbox-script-inventory.sh":
            semantic_entity_type = "generator"
            semantic_automation_type = "generator"
            implemented.append("raw_script_inventory_generator")
            relation_types.extend(["reads_scripts", "writes_report", "writes_tsv"])
            relation_targets.extend(["bin", "scripts", "/srv/toolbox/shared/reports/system", "/srv/toolbox/shared/library-db/raw/system"])
            relation_basis.extend(["source_body_scan_roots", "source_body_report_output", "source_body_tsv_output"])
        else:
            semantic_entity_type = "diagnostic"
            semantic_automation_type = "diagnostic"
    elif name.startswith("generate-"):
        semantic_entity_type = "generator"
        semantic_automation_type = "generator"
    elif name.startswith("plan-") or phase == "plan":
        semantic_entity_type = "plan"
        semantic_automation_type = "plan"
    elif name.startswith("stage-"):
        semantic_entity_type = "stage_workflow"
        semantic_automation_type = "staging workflow"
        confirmation_gate = "yes"
        implemented.append("git_index_staging_workflow")
    elif script_has_apply_behavior(name, lines):
        if path.startswith("scripts/admin/git/"):
            semantic_entity_type = "git_workflow"
            semantic_automation_type = "Git workflow"
        else:
            semantic_entity_type = "apply_workflow"
            semantic_automation_type = "apply workflow"
        confirmation_gate = "yes"
        side_effect_class = "approval_required_host_or_git_change_candidate"
        implemented.append("approval_required_apply_workflow")
    elif name.startswith("audit-"):
        semantic_entity_type = "audit"
        semantic_automation_type = "audit"
    elif name.startswith("backup-") or "SNAPSHOT" in exec_text or "snapshot" in name:
        semantic_entity_type = "backup_snapshot"
        semantic_automation_type = "backup/snapshot"
    elif name.startswith("collect-") or name.endswith("-report.sh"):
        semantic_entity_type = "support_tool"
        semantic_automation_type = "support tool"

    is_plan = semantic_entity_type == "plan" or name.startswith("plan-")
    is_diagnostic = semantic_entity_type == "diagnostic" or name.startswith("diagnose-")

    if has_executable_git_action(lines, {"add", "rm", "reset"}):
        relation_types.append("writes_git_index")
        relation_targets.append("git index")
        relation_basis.append("source_body_executable_git_index_command")
        warnings.append("Git index modification candidate")
    elif is_plan and has_planned_git_action(text, {"add", "rm", "reset"}):
        relation_types.append("plans_git_index_change")
        relation_targets.append("git index")
        relation_basis.append("source_body_plan_or_report_text")

    if has_executable_git_action(lines, {"commit", "tag"}):
        relation_types.append("writes_git_history")
        relation_targets.append("git history")
        relation_basis.append("source_body_executable_git_history_command")
        warnings.append("Git history modification candidate")
    elif is_plan and has_planned_git_action(text, {"commit", "tag"}):
        relation_types.append("plans_git_history_change")
        relation_targets.append("git history")
        relation_basis.append("source_body_plan_or_report_text")
    elif any(re.search(r"(^|[;&|(){}\s])git(\s+-C\s+\S+)?\s+(log|show|rev-parse|diff)\b", line) for line in lines):
        relation_types.append("reads_git_history")
        relation_targets.append("git history")
        relation_basis.append("source_body_git_history_read_command")

    if has_executable_git_action(lines, {"push"}):
        relation_types.append("pushes_remote")
        relation_targets.append("git remote")
        relation_basis.append("source_body_executable_git_push")
        warnings.append("Git remote push candidate")
    elif is_plan and has_planned_git_action(text, {"push"}):
        relation_types.append("plans_remote_push")
        relation_targets.append("git remote")
        relation_basis.append("source_body_plan_or_report_text")
    elif any(re.search(r"(^|[;&|(){}\s])git(\s+-C\s+\S+)?\s+(remote|ls-remote|branch|rev-parse)\b", line) for line in lines):
        relation_types.append("checks_git_remote")
        relation_targets.append("git remote")
        relation_basis.append("source_body_git_remote_check_command")

    if actual_confirmation_gate(text, lines):
        relation_types.append("requires_confirmation")
        relation_targets.append("operator confirmation")
        relation_basis.append("source_body_executable_confirmation_gate")
        confirmation_gate = "yes"

    shell_profile_modifies = any(line_modifies_shell_profile(line) for line in lines)
    shell_profile_checks = any(line_checks_shell_profile(line) for line in lines)
    shell_profile_apply_via_variable = (
        semantic_entity_type == "apply_workflow"
        and any(line_mentions_shell_profile(line) for line in lines)
        and any(re.search(r"(>|>>)\s*\"\$file\"|cp\s+-a\s+\"\$file\"|replace_marked_block\b", line) for line in lines)
    )
    manpage_modifies = any(line_modifies_manpage_access(line) for line in lines)
    manpage_checks = any(line_checks_manpage_access(line) for line in lines)
    host_change_lines = [line for line in lines if line_has_host_change(line)]
    if shell_profile_apply_via_variable:
        host_change_lines.append("shell_profile_variable_write")
    if host_change_lines and (semantic_entity_type == "apply_workflow" or name.startswith(("remove-", "rename-")) or actual_confirmation_gate(text, lines)):
        relation_types.append("touches_host_state_candidate")
        relation_targets.append("host state")
        relation_basis.append("source_body_executable_host_modification_command")
        side_effect_class = "approval_required_host_change_candidate"
        warnings.append("host-changing apply workflow candidate")
    if any(re.search(r"(^|[;&|(){}\s])sudo\s+apt\s+(update|install|remove|purge|autoremove)\b|(^|[;&|(){}\s])pipx\s+install\b", line) for line in lines):
        warnings.append("package installation candidate")
    if is_plan and any(line_mentions_shell_profile(line) for line in lines):
        relation_types.append("plans_shell_profile_change")
        relation_targets.append("shell profile or alias files")
        relation_basis.append("source_body_plan_or_report_text")
    elif shell_profile_modifies or shell_profile_apply_via_variable:
        relation_types.append("modifies_shell_profile_candidate")
        relation_targets.append("shell profile or alias files")
        relation_basis.append("source_body_executable_shell_profile_modification")
        if not is_diagnostic:
            warnings.append("shell profile modification candidate")
    elif shell_profile_checks:
        relation_types.append("checks_shell_profile")
        relation_targets.append("shell profile or alias files")
        relation_basis.append("source_body_shell_profile_check")
    if any("hostnamectl set-hostname" in line for line in lines):
        warnings.append("hostname modification candidate")
    if any(re.search(r"(^|[;&|(){}\s])snap\s+remove\b", line) for line in lines):
        warnings.append("snap modification candidate")
    if is_plan and any(line_mentions_manpage_access(line) for line in lines):
        relation_types.append("plans_manpage_access_change")
        relation_targets.append("manpage access paths")
        relation_basis.append("source_body_plan_or_report_text")
    elif manpage_modifies:
        relation_types.append("modifies_manpage_access_candidate")
        relation_targets.append("manpage access paths")
        relation_basis.append("source_body_executable_manpage_access_modification")
        if not is_diagnostic:
            warnings.append("manpage access modification candidate")
    elif manpage_checks:
        relation_types.append("checks_manpage_access")
        relation_targets.append("manpage access paths")
        relation_basis.append("source_body_manpage_access_check")

    if "/srv/toolbox/shared/reports/system" in exec_text:
        writes_paths.append("/srv/toolbox/shared/reports/system")
        evidence_outputs.append("system report")
        relation_types.append("writes_report")
        relation_targets.append("/srv/toolbox/shared/reports/system")
        relation_basis.append("source_body_report_output")
    if "/srv/toolbox/shared/library-db/raw/system" in exec_text:
        writes_paths.append("/srv/toolbox/shared/library-db/raw/system")
        evidence_outputs.append("system TSV")
        relation_types.append("writes_tsv")
        relation_targets.append("/srv/toolbox/shared/library-db/raw/system")
        relation_basis.append("source_body_tsv_output")
    if "/srv/toolbox/shared/reports/git" in exec_text:
        writes_paths.append("/srv/toolbox/shared/reports/git")
        evidence_outputs.append("git report")
        relation_types.append("writes_report")
        relation_targets.append("/srv/toolbox/shared/reports/git")
        relation_basis.append("source_body_git_report_output")
    if "/srv/toolbox/shared/library-db/raw/git" in exec_text:
        writes_paths.append("/srv/toolbox/shared/library-db/raw/git")
        evidence_outputs.append("git TSV")
        relation_types.append("writes_tsv")
        relation_targets.append("/srv/toolbox/shared/library-db/raw/git")
        relation_basis.append("source_body_git_tsv_output")
    if "/srv/toolbox/shared/inventory/toolbox" in exec_text:
        writes_paths.append("/srv/toolbox/shared/inventory/toolbox")
        evidence_outputs.append("normalized inventory TSV")
        relation_types.append("writes_inventory")
        relation_targets.append("/srv/toolbox/shared/inventory/toolbox")
        relation_basis.append("source_body_inventory_output")
    if "/srv/toolbox/shared/library-db/snapshots" in exec_text or "SNAPSHOT" in exec_text:
        relation_types.append("writes_snapshot")
        relation_targets.append("/srv/toolbox/shared/library-db/snapshots")
        relation_basis.append("source_body_snapshot_output")
        evidence_outputs.append("snapshot")

    dest_warnings, dest_contracts, dest_targets, dest_basis = output_destination_findings(exec_text)
    warnings.extend(dest_warnings)
    implemented.extend(dest_contracts)
    if dest_targets:
        relation_types.append("uses_legacy_or_provisional_destination")
        relation_targets.extend(dest_targets)
        relation_basis.extend(dest_basis)

    if "knowledge/" in exec_text:
        reads_paths.append("knowledge/")
        relation_types.append("reads_knowledge")
        relation_targets.append("knowledge/")
        relation_basis.append("source_body_knowledge_path")
    if "docs/" in exec_text:
        reads_paths.append("docs/")
        relation_types.append("reads_docs")
        relation_targets.append("docs/")
        relation_basis.append("source_body_docs_path")
    if "scripts/" in exec_text:
        reads_paths.append("scripts/")
        relation_types.append("reads_scripts")
        relation_targets.append("scripts/")
        relation_basis.append("source_body_scripts_path")
    if "toolbox_script_inventory_" in exec_text:
        reads_paths.append("toolbox_script_inventory_*.tsv")
        relation_types.append("reads_source_inventory")
        relation_targets.append("toolbox_script_inventory_*.tsv")
        relation_basis.append("source_body_source_inventory_read")

    if semantic_entity_type == "validator":
        if "knowledge/" in exec_text:
            relation_types.append("validates_knowledge")
            relation_targets.append("knowledge/")
            relation_basis.append("source_body_knowledge_validation")
        if "docs/" in exec_text:
            relation_types.append("validates_docs")
            relation_targets.append("docs/")
            relation_basis.append("source_body_docs_validation")
        if "knowledge/services" in exec_text:
            relation_types.append("validates_services")
            relation_targets.append("knowledge/services")
            relation_basis.append("source_body_services_validation")
        implemented.append("validation_report_tsv_workflow")
    if semantic_entity_type == "generator" and "toolbox_inventory_" in exec_text:
        relation_types.append("writes_inventory")
        relation_targets.append("/srv/toolbox/shared/inventory/toolbox")
        relation_basis.append("source_body_inventory_output")
        implemented.append("inventory_generator")
    if "git " in exec_text or "git\t" in exec_text or "git -C" in exec_text:
        relation_types.append("uses_git")
        relation_targets.append("git")
        relation_basis.append("source_body_git_command")

    if semantic_entity_type in {"diagnostic", "validator", "generator", "plan", "audit", "support_tool", "backup_snapshot"} and not implemented:
        implemented.append(f"{semantic_entity_type}_source_body_workflow")

    if semantic_entity_type == "apply_workflow":
        warnings.append("approval-required host-changing apply workflow")
    if semantic_entity_type == "stage_workflow":
        warnings.append("approval-required Git index staging workflow")

    summary = admin_summary(path, semantic_entity_type, text)

    return {
        "semantic_entity_type": semantic_entity_type,
        "semantic_runtime": semantic_runtime,
        "semantic_automation_type": semantic_automation_type,
        "semantic_confidence": semantic_confidence,
        "confirmation_gate": confirmation_gate,
        "side_effect_class": side_effect_class,
        "entrypoint_style": entrypoint_style,
        "argument_contract": argument_contract,
        "summary": summary,
    }

def line_is_dry_run(line: str) -> bool:
    return "--dry-run" in line or "--assumeno" in line or "dry-run" in line.lower()

def line_has_command(line: str, command_pattern: str) -> bool:
    if line_is_weak_text_writer(line):
        return False
    return bool(re.search(rf"(^|[;&|(){{}}\s]){command_pattern}\b", line))

def has_typed_confirmation(text: str, lines: list[str]) -> bool:
    joined = "\n".join(line for line in lines if not line_is_weak_text_writer(line))
    return bool(
        re.search(r"read\s+-r\s+\w+", joined)
        and re.search(r"\b(FORMATAR|APPLY|COMMIT|PUSH|DELETE|PURGE)\b", joined)
    )

def block3_summary(path: str, semantic_entity_type: str, text: str) -> str:
    name = Path(path).name
    comment = first_comment_summary(text)
    if name == "backup-homelab.sh":
        return "Runs a Restic homelab backup to the mounted backup repository and writes a legacy backup log."
    if name == "prune-backup-homelab.sh":
        return "Runs Restic retention, prune, check, and snapshot listing against the mounted backup repository."
    if name == "format-backup-drive.sh":
        return "Formats a removable backup drive after root, removable-device, and typed FORMATAR checks."
    if name == "docker-user-policy.sh":
        return "Multi-mode DOCKER-USER iptables policy tool with apply, rollback, and status modes."
    if name == "configure-ufw-homelab.sh":
        return "Applies a UFW homelab firewall policy by installing UFW, resetting rules, allowing selected ports, and enabling UFW."
    if name.startswith("diagnose-"):
        return comment if comment != "unknown" else "Runs a read-oriented infrastructure diagnostic over live host state and writes or prints evidence."
    if name.startswith("inventory-"):
        return comment if comment != "unknown" else "Generates a host infrastructure inventory report from live source-body targets."
    if name.startswith("audit-"):
        return comment if comment != "unknown" else "Audits infrastructure, package, storage, Docker, or service state and writes a legacy report."
    if name.startswith("cleanup-deleted-safe"):
        return "Analyzes deleted-vs-music TSV evidence and prepares cleanup target lists without deleting files."
    if name.startswith("cleanup-"):
        return comment if comment != "unknown" else "Runs a host cleanup workflow that may remove packages, snaps, flatpaks, or caches."
    if name.startswith("reconcile-"):
        return comment if comment != "unknown" else "Reconciles prior cleanup state and prints future manual cleanup commands without applying them."
    if semantic_entity_type == "firewall_test":
        return comment if comment != "unknown" else "Tests expected firewall and service reachability without changing firewall rules."
    return comment

def classify_block3(path: str, text: str, raw_row: dict[str, str], warnings: list[str], implemented: list[str], relation_types: list[str], relation_targets: list[str], relation_basis: list[str], reads_paths: list[str], writes_paths: list[str], evidence_outputs: list[str]) -> dict[str, str] | None:
    name = Path(path).name
    lines = executable_lines(text)
    exec_text = "\n".join(lines)

    if not path.startswith(("scripts/admin/backup/", "scripts/admin/docker/", "scripts/admin/firewall/", "scripts/admin/network/", "scripts/admin/storage/")):
        return None

    semantic_entity_type = "support_tool"
    semantic_automation_type = "support tool"
    semantic_runtime = "host"
    semantic_confidence = "source_contract_high"
    confirmation_gate = "yes" if has_typed_confirmation(text, lines) else "no"
    side_effect_class = "source_read_only_analysis"
    entrypoint_style = "cli"
    argument_contract = "script-specific CLI arguments"

    def add_relation(kind: str, target: str, basis: str) -> None:
        relation_types.append(kind)
        relation_targets.append(target)
        relation_basis.append(basis)

    def add_read(path_value: str, relation: str, target: str, basis: str) -> None:
        reads_paths.append(path_value)
        add_relation(relation, target, basis)

    if path.startswith("scripts/admin/backup/"):
        if name == "backup-homelab.sh":
            semantic_entity_type = "backup_workflow"
            semantic_automation_type = "backup workflow"
            implemented.append("restic_backup_workflow")
        elif name == "prune-backup-homelab.sh":
            semantic_entity_type = "backup_prune_workflow"
            semantic_automation_type = "backup prune workflow"
            implemented.append("restic_prune_workflow")
        elif name == "format-backup-drive.sh":
            semantic_entity_type = "disk_format_workflow"
            semantic_automation_type = "disk format workflow"
            implemented.append("removable_disk_format_workflow")
        elif name.startswith("diagnose-"):
            semantic_entity_type = "backup_diagnostic"
            semantic_automation_type = "diagnostic"
            implemented.append("backup_diagnostic_workflow")
    elif path.startswith("scripts/admin/docker/"):
        semantic_entity_type = "docker_diagnostic" if name.startswith("diagnose-") else "support_tool"
        semantic_automation_type = "diagnostic" if name.startswith("diagnose-") else "support tool"
        implemented.append("docker_diagnostic_workflow")
    elif path.startswith("scripts/admin/firewall/"):
        if name == "configure-ufw-homelab.sh":
            semantic_entity_type = "firewall_apply_workflow"
            semantic_automation_type = "firewall apply workflow"
            implemented.append("ufw_apply_workflow")
        elif name == "docker-user-policy.sh":
            semantic_entity_type = "docker_user_policy_workflow"
            semantic_automation_type = "Docker/iptables policy workflow"
            implemented.append("docker_user_apply_rollback_status_modes")
        elif name == "test-firewall-homelab.sh":
            semantic_entity_type = "firewall_test"
            semantic_automation_type = "firewall test"
            implemented.append("firewall_reachability_test")
        elif name.startswith("diagnose-"):
            semantic_entity_type = "firewall_diagnostic"
            semantic_automation_type = "diagnostic"
            implemented.append("firewall_diagnostic_workflow")
    elif path.startswith("scripts/admin/network/"):
        if name.startswith("inventory-"):
            semantic_entity_type = "network_inventory"
            semantic_automation_type = "network inventory"
            implemented.append("network_inventory_report")
        elif name.startswith("diagnose-"):
            semantic_entity_type = "network_diagnostic"
            semantic_automation_type = "diagnostic"
            implemented.append("network_diagnostic_workflow")
    elif path.startswith("scripts/admin/storage/"):
        if name == "cleanup-deleted-safe.sh":
            semantic_entity_type = "cleanup_plan"
            semantic_automation_type = "cleanup plan"
            implemented.append("cleanup_target_list_generator")
        elif name.startswith("cleanup-desktop") or name == "cleanup-light-homelab.sh":
            semantic_entity_type = "cleanup_apply_workflow"
            semantic_automation_type = "cleanup apply workflow"
            implemented.append("host_cleanup_apply_workflow")
        elif name.startswith("audit-") or name.startswith("reconcile-"):
            semantic_entity_type = "storage_audit"
            semantic_automation_type = "audit"
            implemented.append("storage_audit_workflow")
        elif name.startswith("diagnose-") or name.startswith("investigate-"):
            semantic_entity_type = "storage_diagnostic"
            semantic_automation_type = "diagnostic"
            implemented.append("storage_diagnostic_workflow")

    high_risk = False
    compact_exec = re.sub(r"\\\n\s*", " ", exec_text)
    compact_source = re.sub(r"\\\n\s*", " ", text)

    if "restic" in exec_text:
        add_relation("uses_restic", "restic", "source_body_restic_command")
    if (
        any(re.search(r"(^|[;&|(){}\s])restic\s+.*\bbackup\b", line) and not line_is_weak_text_writer(line) for line in lines)
        or re.search(r"(^|\n)\s*restic\s+.*\bbackup\b", compact_exec)
    ):
        add_relation("writes_backup_repository_candidate", "/mnt/backup-homelab/restic-repo", "source_body_restic_backup")
        warnings.append("backup repository modification candidate")
        high_risk = True
    if (
        any(re.search(r"(^|[;&|(){}\s])restic\s+.*\b(forget|prune)\b.*--prune", line) and not line_is_weak_text_writer(line) for line in lines)
        or re.search(r"(^|\n)\s*restic\s+.*\bforget\b.*--prune", compact_exec)
        or re.search(r"(^|\n)\s*restic\s+.*\bprune\b", compact_exec)
    ):
        add_relation("prunes_backup_repository_candidate", "/mnt/backup-homelab/restic-repo", "source_body_restic_forget_prune")
        warnings.append("backup prune candidate")
        high_risk = True
    if "restic" in exec_text or "/mnt/backup-homelab" in exec_text:
        add_read("/mnt/backup-homelab", "reads_backup_state", "backup mount or restic repository", "source_body_backup_mount_or_repo")

    if any(line_has_command(line, r"(sudo\s+)?(mkfs|mkfs\.ext4|wipefs|parted|partprobe)") for line in lines):
        add_relation("formats_block_device_candidate", "block device", "source_body_block_device_format_command")
        warnings.append("block device format candidate")
        high_risk = True

    if "ufw" in exec_text:
        add_relation("uses_ufw", "ufw", "source_body_ufw_command")
    if any(line_has_command(line, r"sudo\s+ufw") and re.search(r"\b(reset|enable|allow|default|deny|delete)\b", line) for line in lines):
        add_relation("modifies_firewall_candidate", "ufw firewall rules", "source_body_ufw_modification_command")
        warnings.append("firewall modification candidate")
        high_risk = True
    elif "ufw status" in exec_text:
        add_relation("reads_firewall_state", "ufw", "source_body_ufw_status")

    if "iptables" in exec_text:
        add_relation("uses_iptables", "iptables", "source_body_iptables_command")
    if any((line_has_command(line, r"sudo\s+iptables") and re.search(r"\s(-A|-F|-I|-D|-P|-N|-X|-R)\s", line)) or line_has_command(line, r"sudo\s+iptables-restore") for line in lines):
        target = "DOCKER-USER iptables chain" if "DOCKER-USER" in exec_text else "iptables firewall rules"
        add_relation("modifies_docker_user_chain_candidate" if "DOCKER-USER" in exec_text else "modifies_firewall_candidate", target, "source_body_iptables_modification_command")
        warnings.append("Docker/iptables policy modification candidate" if "DOCKER-USER" in exec_text else "firewall modification candidate")
        high_risk = True
    if any(line_has_command(line, r"sudo\s+iptables-restore") for line in lines):
        add_relation("rolls_back_iptables_candidate", "iptables rules", "source_body_iptables_restore")
        warnings.append("iptables rollback candidate")
        high_risk = True
    elif "iptables -L" in exec_text or "iptables -S" in exec_text:
        add_relation("reads_firewall_state", "iptables", "source_body_iptables_read")

    package_cleanup_lines = [
        line for line in lines
        if not line_is_weak_text_writer(line)
        and not line_is_dry_run(line)
        and re.search(r"(^|[;&|(){}\s])sudo\s+apt\s+(purge|autoremove|clean)\b", line)
    ]
    if package_cleanup_lines:
        add_relation("purges_packages_candidate", "APT package state", "source_body_apt_purge_autoremove_or_clean")
        warnings.append("package purge/autoremove candidate")
        high_risk = True
    elif "apt autoremove" in exec_text or "apt purge" in exec_text or "apt clean" in exec_text:
        add_relation("uses_apt", "apt", "source_body_apt_command")

    if any(re.search(r"(^|[;&|(){}\s])sudo\s+snap\s+remove\b", line) and not line_is_weak_text_writer(line) for line in lines):
        add_relation("removes_snap_or_flatpak_candidate", "snap package state", "source_body_snap_remove")
        warnings.append("snap/flatpak removal candidate")
        high_risk = True
    if any(re.search(r"(^|[;&|(){}\s])flatpak\s+uninstall\s+-y\b", line) and not line_is_weak_text_writer(line) and not line_is_dry_run(line) for line in lines):
        add_relation("removes_snap_or_flatpak_candidate", "flatpak package state", "source_body_flatpak_uninstall")
        warnings.append("snap/flatpak removal candidate")
        high_risk = True
    if "snap " in exec_text:
        add_relation("uses_snap", "snap", "source_body_snap_command")
    if "flatpak " in exec_text:
        add_relation("uses_flatpak", "flatpak", "source_body_flatpak_command")

    if any(re.search(r"(^|[;&|(){}\s])rm\s+-rf\s+", line) and not line_is_weak_text_writer(line) for line in lines):
        add_relation("cleans_cache_candidate", "filesystem cache or cleanup target", "source_body_rm_rf_cleanup")
        warnings.append("cache cleanup candidate")
        warnings.append("destructive cleanup candidate")
        high_risk = True
    if any(re.search(r"(^|[;&|(){}\s])sudo\s+apt\s+clean\b", line) and not line_is_weak_text_writer(line) for line in lines):
        add_relation("cleans_cache_candidate", "APT cache", "source_body_apt_clean")
        warnings.append("cache cleanup candidate")

    if "docker " in exec_text:
        add_relation("uses_docker", "docker", "source_body_docker_command")
        add_relation("reads_docker_state", "Docker runtime state", "source_body_docker_read_or_inspect")
    if "tailscale " in exec_text:
        add_relation("uses_tailscale", "tailscale", "source_body_tailscale_command")
        add_relation("reads_network_state", "Tailscale/network state", "source_body_tailscale_read")
    if "smbstatus" in exec_text or "samba" in exec_text.lower():
        add_relation("uses_samba", "samba", "source_body_samba_command_or_reference")
    if "smartctl" in exec_text:
        add_relation("uses_smartctl", "smartctl", "source_body_smartctl_command")
        add_relation("reads_storage_state", "SMART/storage state", "source_body_smartctl_or_storage_read")

    if any(token in exec_text for token in ["df ", "du ", "lsblk", "findmnt", "dmesg", "/srv", "/var/lib/docker", "/var/log", "/boot", "/usr/src", "/lib/modules"]):
        add_relation("reads_storage_state", "host storage paths", "source_body_storage_read")
    if any(token in exec_text for token in ["ip ", "ss ", "nc ", "curl ", "avahi", "/etc/hosts", "/etc/avahi"]):
        add_relation("reads_network_state", "host network state", "source_body_network_read")
    if any(token in exec_text for token in ["ufw status", "iptables -L", "iptables -S", "ss -tulpn"]):
        add_relation("reads_firewall_state", "firewall/listening port state", "source_body_firewall_read")
    if any(token in exec_text for token in ["/srv/toolbox/secrets", ".restic-password", "/srv/media", "/srv/compose", "/srv/data", "/mnt/backup-homelab"]):
        add_relation("reads_sensitive_path_candidate", "sensitive host path names", "source_body_sensitive_path_reference")
        warnings.append("reads sensitive path candidate")

    if "$HOME/relatorios-backup" in text:
        writes_paths.append("$HOME/relatorios-backup")
        add_relation("uses_legacy_or_provisional_destination", "$HOME/relatorios-backup", "source_body_legacy_backup_report_destination")
        warnings.append("legacy destination: $HOME/relatorios-backup")
    if "$HOME/relatorios-disco" in text:
        writes_paths.append("$HOME/relatorios-disco")
        add_relation("uses_legacy_or_provisional_destination", "$HOME/relatorios-disco", "source_body_legacy_disk_report_destination")
        warnings.append("legacy destination: $HOME/relatorios-disco")
    if "/home/thiago/iptables-backups" in text:
        writes_paths.append("/home/thiago/iptables-backups")
        add_relation("uses_legacy_or_provisional_destination", "/home/thiago/iptables-backups", "source_body_legacy_iptables_backup_destination")
        warnings.append("legacy destination: /home/thiago/iptables-backups")
    has_canonical_report = (
        "/srv/toolbox/shared/reports/" in text
        or re.search(r"REPORT_DIR=.*reports/[A-Za-z0-9_/$\"{}.-]*", text)
        and "SHARED_DIR" in text
    )
    has_canonical_tsv = (
        "/srv/toolbox/shared/library-db/raw/" in text
        or re.search(r"RAW_DIR=.*library-db/raw/[A-Za-z0-9_/$\"{}.-]*", text)
        and "SHARED_DIR" in text
    )
    if has_canonical_report:
        writes_paths.append("/srv/toolbox/shared/reports")
        evidence_outputs.append("canonical report")
        add_relation("writes_report", "/srv/toolbox/shared/reports", "source_body_canonical_report_output")
        add_relation("writes_canonical_report", "/srv/toolbox/shared/reports", "source_body_canonical_report_output")
    if has_canonical_tsv:
        writes_paths.append("/srv/toolbox/shared/library-db/raw")
        evidence_outputs.append("canonical TSV")
        add_relation("writes_tsv", "/srv/toolbox/shared/library-db/raw", "source_body_canonical_tsv_output")
        add_relation("writes_canonical_tsv", "/srv/toolbox/shared/library-db/raw", "source_body_canonical_tsv_output")
    if "SNAPSHOT" in exec_text or "snapshot" in exec_text.lower():
        add_relation("writes_snapshot", "snapshot or backup artifact", "source_body_snapshot_or_backup_reference")

    expects_evidence = semantic_entity_type.endswith(("diagnostic", "audit")) or semantic_entity_type in {"network_inventory", "backup_workflow", "backup_prune_workflow", "cleanup_plan", "cleanup_apply_workflow", "firewall_test", "docker_user_policy_workflow"}
    if expects_evidence and not any(rt in relation_types for rt in ["writes_report", "writes_canonical_report", "uses_legacy_or_provisional_destination"]):
        warnings.append("canonical report/TSV missing where expected")

    if high_risk:
        side_effect_class = "approval_required_host_change_candidate"
        if confirmation_gate == "yes":
            add_relation("requires_confirmation", "operator confirmation", "source_body_typed_confirmation")
        else:
            add_relation("missing_or_weak_confirmation_candidate", "operator confirmation", "source_body_high_risk_without_typed_confirmation")
            warnings.append("weak or missing typed confirmation for high-risk apply workflow")

    summary = block3_summary(path, semantic_entity_type, text)

    return {
        "semantic_entity_type": semantic_entity_type,
        "semantic_runtime": semantic_runtime,
        "semantic_automation_type": semantic_automation_type,
        "semantic_confidence": semantic_confidence,
        "confirmation_gate": confirmation_gate,
        "side_effect_class": side_effect_class,
        "entrypoint_style": entrypoint_style,
        "argument_contract": argument_contract,
        "summary": summary,
    }

def classify(path: str, text: str, exists: bool, raw_row: dict[str, str]) -> dict[str, str]:
    warnings: list[str] = []
    implemented: list[str] = []
    relation_types: list[str] = []
    relation_targets: list[str] = []
    relation_basis: list[str] = []
    reads_paths: list[str] = []
    writes_paths: list[str] = []
    evidence_outputs: list[str] = []

    line_count = len(text.splitlines()) if exists else 0
    placeholder_status = "none"
    source_body_read = "yes" if exists else "no"
    semantic_entity_type = "unknown"
    semantic_runtime = "unknown"
    semantic_automation_type = "unknown"
    entrypoint_style = "unknown"
    argument_contract = "unknown"
    side_effect_class = "source_read_only_analysis"
    confirmation_gate = "no"
    uses_run_job_contract = "no"
    pipeline_contract_status = "not_applicable"
    job_root_contract_status = "not_applicable"
    input_work_output_status = "not_applicable"
    status_file_behavior = "unknown"
    log_behavior = "unknown"
    semantic_confidence = "source_body_medium"
    runtime_validated = "no"
    runtime_validation_evidence = "none"
    summary = first_comment_summary(text)

    path_type = path_entity_type(path)
    libs = sourced_libraries(text)
    helper_cmds = helper_paths(text)
    toolbox_cmds = command_paths(text)
    externals = external_commands(text)
    executable_text = "\n".join(executable_lines(text))
    calls_git = "yes" if "git " in executable_text or "git\t" in executable_text or "git -C" in executable_text else "no"

    if not exists:
        warnings.append("scoped path missing")
        placeholder_status = "missing_file"
        semantic_entity_type = "placeholder"
        semantic_automation_type = "placeholder"
        semantic_confidence = "path_low"
        summary = "Scoped path is missing."
    elif line_count == 0:
        warnings.append("empty scoped file")
        placeholder_status = "empty_file"
        semantic_entity_type = "placeholder"
        semantic_automation_type = "placeholder"
        semantic_confidence = "source_body_medium"
        summary = "Empty scoped file; path role is not semantically implemented."
    elif path == "bin/run-job" and "/toolbox/jobs" in text and "scripts/pipelines/${JOB_TYPE}.sh" in text:
        semantic_entity_type = "run_job_entrypoint"
        semantic_runtime = "container"
        semantic_automation_type = "run-job entrypoint"
        implemented.extend(["job_directory_contract", "pipeline_dispatch_contract"])
        entrypoint_style = "cli"
        argument_contract = "PIPELINE INPUT [--env NAME=VALUE ...]"
        writes_paths.extend(["/toolbox/jobs/<job-id>/input", "/toolbox/jobs/<job-id>/work", "/toolbox/jobs/<job-id>/output", "/toolbox/jobs/<job-id>/meta.env", "/toolbox/jobs/<job-id>/status", "/toolbox/jobs/<job-id>/log.txt"])
        relation_types.append("dispatches_pipeline")
        relation_targets.append("scripts/pipelines/${JOB_TYPE}.sh")
        relation_basis.append("source_body_pipeline_dispatch")
        status_file_behavior = "writes running success failed"
        log_behavior = "captures pipeline stdout stderr to job log"
        semantic_confidence = "source_contract_high"
        summary = "Creates structured job directories, copies input, writes metadata/status, and dispatches a pipeline script by job type."
    elif path.startswith("bin/"):
        pipeline_name = run_job_pipeline_name(text)
        if pipeline_name:
            semantic_entity_type = "pipeline_launcher"
            semantic_runtime = "container"
            semantic_automation_type = "pipeline launcher"
            implemented.append("run_job_pipeline_launcher")
            entrypoint_style = "cli"
            argument_contract = "INPUT [--env NAME=VALUE ...]" if "--env" in text else "pipeline input arguments"
            relation_types.extend(["uses_run_job_entrypoint", "dispatches_pipeline"])
            relation_targets.extend(["bin/run-job", f"scripts/pipelines/{pipeline_name}.sh"])
            relation_basis.extend(["source_body_run_job_exec", "source_body_pipeline_name"])
            semantic_confidence = "source_contract_high"
            summary = f"Public command wrapper that launches the {pipeline_name} run-job pipeline."
        elif helper_cmds:
            semantic_entity_type = "command_wrapper"
            semantic_runtime = "container"
            semantic_automation_type = "wrapper to helper"
            implemented.append("public_command_wrapper")
            entrypoint_style = "cli"
            argument_contract = "passes arguments through to helper"
            relation_types.append("delegates_to_helper")
            relation_targets.append(helper_cmds[0])
            relation_basis.append("source_body_helper_exec")
            semantic_confidence = "source_contract_high"
            summary = f"Public command wrapper that delegates to {helper_cmds[0]}."
        else:
            semantic_entity_type = "command"
            semantic_runtime = "unknown"
            semantic_automation_type = "unknown"
            semantic_confidence = "static_hint_low"
            warnings.append("command path without recognized command semantics")
            summary = first_comment_summary(text)
    elif path.startswith("scripts/pipelines/"):
        has_job_root = "JOB_ROOT" in text
        has_iwo = all(token in text for token in ["INPUT_DIR", "WORK_DIR", "OUTPUT_DIR"])
        has_status = "STATUS_FILE" in text and "success" in text and "failed" in text
        has_log = "log()" in text or "LOG_FILE" in text
        if has_job_root and has_iwo and has_status and has_log:
            semantic_entity_type = "pipeline"
            semantic_runtime = "container"
            semantic_automation_type = "pipeline"
            implemented.extend(["pipeline_job_root_contract", "input_work_output_contract", "status_contract", "pipeline_logging_contract"])
            entrypoint_style = "run-job pipeline"
            argument_contract = "JOB_ROOT"
            uses_run_job_contract = "yes"
            pipeline_contract_status = "implemented"
            job_root_contract_status = "implemented"
            input_work_output_status = "implemented"
            status_file_behavior = "writes running success failed"
            log_behavior = "writes step/info/success/error messages"
            writes_paths.extend(["${JOB_ROOT}/work", "${JOB_ROOT}/output", "${JOB_ROOT}/status"])
            relation_types.extend(["uses_run_job_contract"])
            relation_targets.extend(["bin/run-job"])
            relation_basis.extend(["source_body_job_root_contract"])
            for cmd in toolbox_cmds:
                relation_types.append("uses_toolbox_command")
                relation_targets.append(cmd.replace("/toolbox/app/", ""))
                relation_basis.append("source_body_toolbox_command_call")
            semantic_confidence = "source_contract_high"
            summary = "Implements a run-job pipeline over JOB_ROOT input/work/output/status paths."
        else:
            warnings.append("pipeline path without complete pipeline contract")
            semantic_entity_type = "placeholder"
            semantic_automation_type = "placeholder"
            placeholder_status = "incomplete_pipeline_contract"
            pipeline_contract_status = "not_implemented"
            semantic_confidence = "static_hint_low"
            summary = "Pipeline path does not implement the required run-job pipeline contract."
    elif path.startswith("scripts/lib/"):
        if re.search(r"^[A-Za-z_][A-Za-z0-9_]*\(\)\s*\{", text, re.MULTILINE):
            semantic_entity_type = "library_module"
            semantic_runtime = "source_only"
            semantic_automation_type = "sourced library"
            implemented.append("sourced_function_module")
            entrypoint_style = "source"
            argument_contract = "sourced functions"
            side_effect_class = "source_time_no_side_effects_expected"
            semantic_confidence = "source_contract_high"
            summary = first_comment_summary(text)
        else:
            warnings.append("library path without function definitions")
            semantic_entity_type = "placeholder"
            semantic_automation_type = "placeholder"
            placeholder_status = "empty_or_no_functions"
            semantic_runtime = "unknown"
            semantic_confidence = "source_body_medium"
            summary = "Library path has no detected reusable function definitions."
    elif path == "scripts/helpers/job-inspect.sh":
        semantic_entity_type = "helper"
        semantic_runtime = "hybrid"
        semantic_automation_type = "helper executable"
        implemented.extend(["job_inspection_helper", "status_log_output_reader"])
        entrypoint_style = "cli"
        argument_contract = "TARGET"
        reads_paths.extend(["/toolbox/jobs/<job-id>/status", "/toolbox/jobs/<job-id>/log.txt", "/toolbox/jobs/<job-id>/output", "/srv/toolbox/jobs/<job-id>"])
        relation_types.append("inspects_job")
        relation_targets.append("/toolbox/jobs")
        relation_basis.append("source_body_job_status_log_output_reads")
        semantic_confidence = "source_contract_high"
        summary = "Inspects Toolbox job status, first log lines, and output files by job type or path."
    elif path.startswith("scripts/helpers/"):
        semantic_entity_type = "helper"
        semantic_runtime = "container"
        semantic_automation_type = "atomic helper executable"
        implemented.append("helper_executable")
        entrypoint_style = "cli"
        argument_contract = "helper-specific CLI arguments"
        semantic_confidence = "source_contract_high"
        summary = helper_summary(path, externals, text)
        if externals:
            relation_types.append("uses_external_dependency")
            relation_targets.extend(externals)
            relation_basis.append("source_body_external_command_or_import")
        if path.endswith("/exif.sh"):
            reads_paths.append("IMAGE")
            writes_paths.append("OUTPUT copy when -remove-all is used")
            implemented.append("metadata_read_write_copy_mode")
        elif path.endswith("/img-convert.sh"):
            reads_paths.append("INPUT image")
            writes_paths.append("OUTPUT image")
            implemented.append("image_conversion_helper")
        elif path.endswith("/ocr.sh"):
            reads_paths.append("IMAGE")
            writes_paths.append("optional OCR output text file")
            implemented.append("ocr_helper")
        elif path.endswith("/pdf-images.sh"):
            reads_paths.append("PDF")
            writes_paths.append("output image directory")
            implemented.append("pdf_page_image_extraction_helper")
        elif path.endswith("/pdf-text.sh"):
            reads_paths.append("PDF")
            writes_paths.append("optional text output file")
            implemented.append("pdf_text_extraction_helper")
        elif path.endswith("/translate.sh"):
            reads_paths.append("TEXT argument")
            writes_paths.append("translated text to stdout")
            implemented.append("translation_helper")
    elif path.startswith("scripts/admin/system/") or path.startswith("scripts/admin/git/"):
        block2 = classify_block2(
            path,
            text,
            raw_row,
            warnings,
            implemented,
            relation_types,
            relation_targets,
            relation_basis,
            reads_paths,
            writes_paths,
            evidence_outputs,
        )
        if block2 is None:
            semantic_entity_type = path_type
            semantic_runtime = "unknown"
            semantic_automation_type = "unknown"
            semantic_confidence = "static_hint_low"
            warnings.append("no block2 semantic rule matched")
            summary = first_comment_summary(text)
        else:
            semantic_entity_type = block2["semantic_entity_type"]
            semantic_runtime = block2["semantic_runtime"]
            semantic_automation_type = block2["semantic_automation_type"]
            semantic_confidence = block2["semantic_confidence"]
            confirmation_gate = block2["confirmation_gate"]
            side_effect_class = block2["side_effect_class"]
            entrypoint_style = block2["entrypoint_style"]
            argument_contract = block2["argument_contract"]
            summary = block2["summary"]
    elif path.startswith(("scripts/admin/backup/", "scripts/admin/docker/", "scripts/admin/firewall/", "scripts/admin/network/", "scripts/admin/storage/")):
        block3 = classify_block3(
            path,
            text,
            raw_row,
            warnings,
            implemented,
            relation_types,
            relation_targets,
            relation_basis,
            reads_paths,
            writes_paths,
            evidence_outputs,
        )
        if block3 is None:
            semantic_entity_type = path_type
            semantic_runtime = "unknown"
            semantic_automation_type = "unknown"
            semantic_confidence = "static_hint_low"
            warnings.append("no block3 semantic rule matched")
            summary = first_comment_summary(text)
        else:
            semantic_entity_type = block3["semantic_entity_type"]
            semantic_runtime = block3["semantic_runtime"]
            semantic_automation_type = block3["semantic_automation_type"]
            semantic_confidence = block3["semantic_confidence"]
            confirmation_gate = block3["confirmation_gate"]
            side_effect_class = block3["side_effect_class"]
            entrypoint_style = block3["entrypoint_style"]
            argument_contract = block3["argument_contract"]
            summary = block3["summary"]
    elif path.startswith("scripts/admin/git/"):
        semantic_entity_type = "git_workflow"
        semantic_runtime = "host"
        semantic_automation_type = "git workflow"
        implemented.append("git_workflow_with_evidence")
        entrypoint_style = "cli"
        argument_contract = "git workflow arguments"
        evidence_outputs.extend(["git report", "git TSV"])
        writes_paths.extend(["/srv/toolbox/shared/reports/git", "/srv/toolbox/shared/library-db/raw/git"])
        relation_types.extend(["uses_git", "writes_report", "writes_tsv"])
        relation_targets.extend(["git", "/srv/toolbox/shared/reports/git", "/srv/toolbox/shared/library-db/raw/git"])
        relation_basis.extend(["source_body_git_commands", "source_body_report_path", "source_body_tsv_path"])
        confirmation_gate = "yes" if "COMMIT" in text or "PUSH" in text else "no"
        semantic_confidence = "source_contract_high"
        summary = "Runs a controlled Git workflow with generated report/TSV evidence and confirmation gates where required."
    elif path == "scripts/admin/system/generate-toolbox-inventory.sh":
        semantic_entity_type = "generator"
        semantic_runtime = "host"
        semantic_automation_type = "generator"
        implemented.append("inventory_generator")
        entrypoint_style = "cli"
        argument_contract = "optional source TSV"
        reads_paths.append("/srv/toolbox/shared/library-db/raw/system/toolbox_script_inventory_*.tsv")
        writes_paths.extend(["/srv/toolbox/shared/inventory/toolbox", "/srv/toolbox/shared/reports/system"])
        evidence_outputs.extend(["normalized inventory TSV", "human report"])
        relation_types.extend(["reads_source_inventory", "writes_inventory", "writes_report"])
        relation_targets.extend(["toolbox_script_inventory_*.tsv", "/srv/toolbox/shared/inventory/toolbox", "/srv/toolbox/shared/reports/system"])
        relation_basis.extend(["source_body_source_tsv_read", "source_body_inventory_output", "source_body_report_output"])
        semantic_confidence = "source_contract_high"
        summary = "Transforms raw Toolbox script inventory TSV evidence into toolbox_inventory_v0 TSV and report artifacts."
    elif path == "scripts/admin/system/diagnose-toolbox-script-inventory.sh":
        semantic_entity_type = "diagnostic"
        semantic_runtime = "host"
        semantic_automation_type = "diagnostic"
        implemented.append("read_only_script_inventory_diagnostic")
        entrypoint_style = "cli"
        argument_contract = "none"
        reads_paths.extend(["/srv/toolbox/app/bin", "/srv/toolbox/app/scripts"])
        writes_paths.extend(["/srv/toolbox/shared/reports/system", "/srv/toolbox/shared/library-db/raw/system"])
        evidence_outputs.extend(["raw script inventory TSV", "human report"])
        relation_types.extend(["scans_source_tree", "writes_report", "writes_tsv"])
        relation_targets.extend(["bin", "scripts", "/srv/toolbox/shared/reports/system", "/srv/toolbox/shared/library-db/raw/system"])
        relation_basis.extend(["source_body_scan_roots", "source_body_report_output", "source_body_tsv_output"])
        semantic_confidence = "source_contract_high"
        summary = "Scans Toolbox bin/scripts source files and writes raw script inventory TSV and report evidence."
    else:
        semantic_entity_type = path_type
        semantic_runtime = "unknown"
        semantic_automation_type = "unknown"
        semantic_confidence = "static_hint_low"
        warnings.append("no v0 semantic rule matched")
        summary = first_comment_summary(text)

    if git_status == "dirty":
        warnings.append("git status dirty at generation time")
    elif git_status == "unknown":
        warnings.append("git status unknown at generation time")

    if libs:
        relation_types.append("sources_library")
        relation_targets.extend(libs)
        relation_basis.append("source_body_source_statement")

    calls_toolbox = [cmd.replace("/toolbox/app/", "") for cmd in toolbox_cmds]

    return {
        "source_body_read": source_body_read,
        "source_line_count": str(line_count),
        "path_entity_type": path_type,
        "raw_phase": raw_row.get("phase", "unknown") or "unknown",
        "raw_kind": raw_row.get("kind", "unknown") or "unknown",
        "semantic_entity_type": semantic_entity_type,
        "semantic_runtime": semantic_runtime,
        "semantic_automation_type": semantic_automation_type,
        "source_body_summary": summary,
        "implemented_contracts": join_values(implemented),
        "entrypoint_style": entrypoint_style,
        "argument_contract": argument_contract,
        "reads_paths": join_values(reads_paths),
        "writes_paths": join_values(writes_paths),
        "evidence_outputs": join_values(evidence_outputs),
        "uses_libraries": join_values(libs),
        "calls_toolbox_commands": join_values(calls_toolbox),
        "calls_external_commands": join_values(externals),
        "calls_git": calls_git,
        "uses_run_job_contract": uses_run_job_contract,
        "pipeline_contract_status": pipeline_contract_status,
        "job_root_contract_status": job_root_contract_status,
        "input_work_output_status": input_work_output_status,
        "status_file_behavior": status_file_behavior,
        "log_behavior": log_behavior,
        "side_effect_class": side_effect_class,
        "confirmation_gate": confirmation_gate,
        "placeholder_status": placeholder_status,
        "relation_candidate_types": join_values(relation_types),
        "relation_candidate_targets": join_values(relation_targets),
        "relation_candidate_basis": join_values(relation_basis),
        "semantic_confidence": semantic_confidence,
        "runtime_validated": runtime_validated,
        "runtime_validation_evidence": runtime_validation_evidence,
        "warnings": join_values(warnings),
    }

raw_inventory_rows = read_tsv(raw_script_inventory, "path")
source_inventory_rows = read_tsv(source_inventory, "path")

raw_rows: list[dict[str, str]] = []
normalized_rows: list[dict[str, str]] = []
errors: list[str] = []

for rel_path in scope_paths:
    source_path = app / rel_path
    exists = source_path.exists()
    if exists:
        try:
            text = source_path.read_text(encoding="utf-8", errors="replace")
        except Exception as exc:
            text = ""
            errors.append(f"{rel_path}: unable to read source body: {exc}")
    else:
        text = ""
        errors.append(f"{rel_path}: scoped path missing")

    raw_row = raw_inventory_rows.get(rel_path, {})
    semantic = classify(rel_path, text, exists, raw_row)

    raw_semantic_row = {
        "semantic_schema_version": semantic_schema,
        "timestamp": generated_at,
        "path": rel_path,
        "scope_batch": scope_batch,
        **semantic,
        "source_inventory": str(source_inventory),
        "source_report": source_report,
        "source_tsv": str(raw_script_inventory),
        "repo_root": str(app),
        "git_commit": git_commit,
        "git_status": git_status,
    }
    raw_rows.append(raw_semantic_row)

    path_type = semantic["path_entity_type"]
    subdomain = subdomain_for(rel_path, raw_row)
    status = "placeholder" if semantic["semantic_entity_type"] == "placeholder" else "present"
    relation_types = semantic["relation_candidate_types"]
    relation_targets = semantic["relation_candidate_targets"]
    relation_basis = semantic["relation_candidate_basis"]
    related_path = relation_targets.split(";")[0] if relation_targets not in {"none", "unknown"} else "unknown"
    related_entity_id = (
        f"script_semantics:{related_path}"
        if related_path.startswith(("bin/", "scripts/"))
        else "unknown"
    )

    normalized_rows.append({
        "inventory_schema_version": semantic_schema,
        "timestamp": generated_at,
        "domain": "toolbox",
        "subdomain": subdomain,
        "entity_type": "script_semantics",
        "entity_id": f"script_semantics:{rel_path}",
        "path": rel_path,
        "name": Path(rel_path).name,
        "semantic_entity_type": semantic["semantic_entity_type"],
        "semantic_runtime": semantic["semantic_runtime"],
        "semantic_automation_type": semantic["semantic_automation_type"],
        "status": status,
        "placeholder_status": semantic["placeholder_status"],
        "implemented_contracts": semantic["implemented_contracts"],
        "semantic_summary": semantic["source_body_summary"],
        "relation_candidate_type": relation_types,
        "related_entity_type": "script_semantics" if related_entity_id != "unknown" else "unknown",
        "related_entity_id": related_entity_id,
        "related_path": related_path,
        "relation_basis": relation_basis,
        "relation_confidence": semantic["semantic_confidence"],
        "runtime_validated": semantic["runtime_validated"],
        "runtime_validation_evidence": semantic["runtime_validation_evidence"],
        "evidence_type": "source_body_semantics",
        "confidence": semantic["semantic_confidence"],
        "source_semantics_tsv": str(raw_out_tsv),
        "source_semantics_report": str(out_report),
        "source_inventory": str(source_inventory),
        "source_report": source_report,
        "source_tsv": str(raw_script_inventory),
        "generator_script": generator_script,
        "repo_root": str(app),
        "git_branch": git_branch,
        "git_commit": git_commit,
        "git_status": git_status,
    })

required_raw = [
    "semantic_schema_version",
    "timestamp",
    "path",
    "source_body_read",
    "path_entity_type",
    "semantic_entity_type",
    "semantic_runtime",
    "semantic_automation_type",
    "source_body_summary",
    "semantic_confidence",
    "runtime_validated",
    "source_inventory",
    "source_report",
    "source_tsv",
    "git_commit",
    "git_status",
]

for row in raw_rows:
    for col in required_raw:
        if str(row.get(col, "")).strip() == "":
            errors.append(f"{row['path']}: required raw field is empty: {col}")

entity_ids = [row["entity_id"] for row in normalized_rows]
if len(entity_ids) != len(set(entity_ids)):
    errors.append("duplicate normalized entity IDs")

for row in raw_rows:
    if row["runtime_validated"] != "no" and row["runtime_validation_evidence"] in {"none", "unknown"}:
        errors.append(f"{row['path']}: runtime_validated without evidence")
    if row["placeholder_status"] != "none" and row["pipeline_contract_status"] == "implemented":
        errors.append(f"{row['path']}: placeholder claims pipeline contract implemented")

if errors:
    for error in errors:
        print(f"[ERRO] {error}", file=sys.stderr)
    sys.exit(1)

with raw_out_tsv.open("w", encoding="utf-8", newline="") as fh:
    writer = csv.DictWriter(fh, fieldnames=raw_columns, delimiter="\t", lineterminator="\n")
    writer.writeheader()
    writer.writerows(raw_rows)

with normalized_out_tsv.open("w", encoding="utf-8", newline="") as fh:
    writer = csv.DictWriter(fh, fieldnames=normalized_columns, delimiter="\t", lineterminator="\n")
    writer.writeheader()
    writer.writerows(normalized_rows)

entity_counts = Counter(row["semantic_entity_type"] for row in raw_rows)
runtime_counts = Counter(row["semantic_runtime"] for row in raw_rows)
automation_counts = Counter(row["semantic_automation_type"] for row in raw_rows)
confidence_counts = Counter(row["semantic_confidence"] for row in raw_rows)
placeholder_rows = [row for row in raw_rows if row["placeholder_status"] != "none"]
warning_rows = [row for row in raw_rows if row["warnings"] != "none"]
relation_rows = [row for row in raw_rows if row["relation_candidate_types"] != "none"]

with out_report.open("w", encoding="utf-8") as fh:
    fh.write("# Toolbox script semantics inventory report\n\n")
    fh.write(f"Generated at: {generated_at}\n")
    fh.write(f"Schema: {semantic_schema}\n")
    fh.write(f"Scope batch: {scope_batch}\n")
    fh.write(f"Generator script: {generator_script}\n")
    fh.write(f"Repo root: {app}\n")
    fh.write(f"Git branch: {git_branch}\n")
    fh.write(f"Git commit: {git_commit}\n")
    fh.write(f"Git status: {git_status}\n")
    fh.write(f"Source inventory: {source_inventory}\n")
    fh.write(f"Source inventory report: {source_report}\n")
    fh.write(f"Raw script inventory: {raw_script_inventory}\n")
    fh.write(f"Raw script inventory report: {raw_script_report}\n")
    fh.write(f"Raw semantics TSV: {raw_out_tsv}\n")
    fh.write(f"Normalized semantics inventory: {normalized_out_tsv}\n")
    fh.write(f"Report: {out_report}\n\n")

    fh.write("## Safety notes\n\n")
    fh.write("- This generator reads source bodies only.\n")
    fh.write("- It does not execute scoped scripts, pipelines, run-job, validators, diagnostics, or apply scripts.\n")
    fh.write("- Relation candidates are not graph edges.\n")
    fh.write("- Runtime validation is not claimed by this layer.\n\n")

    fh.write("## Summary\n\n")
    fh.write(f"Total scoped rows: {len(raw_rows)}\n")
    fh.write(f"Placeholder rows: {len(placeholder_rows)}\n")
    fh.write(f"Rows with relation candidates: {len(relation_rows)}\n")
    fh.write(f"Rows with warnings: {len(warning_rows)}\n\n")

    fh.write("## Counts by semantic entity type\n\n")
    for key in sorted(entity_counts):
        fh.write(f"- {key}: {entity_counts[key]}\n")
    fh.write("\n")

    fh.write("## Counts by runtime\n\n")
    for key in sorted(runtime_counts):
        fh.write(f"- {key}: {runtime_counts[key]}\n")
    fh.write("\n")

    fh.write("## Counts by automation type\n\n")
    for key in sorted(automation_counts):
        fh.write(f"- {key}: {automation_counts[key]}\n")
    fh.write("\n")

    fh.write("## Counts by confidence\n\n")
    for key in sorted(confidence_counts):
        fh.write(f"- {key}: {confidence_counts[key]}\n")
    fh.write("\n")

    fh.write("## Placeholder rows\n\n")
    if placeholder_rows:
        for row in placeholder_rows:
            fh.write(f"- {row['path']}: {row['placeholder_status']}\n")
    else:
        fh.write("No placeholder rows.\n")
    fh.write("\n")

    fh.write("## Warnings\n\n")
    if warning_rows:
        for row in warning_rows:
            fh.write(f"- {row['path']}: {row['warnings']}\n")
    else:
        fh.write("No warnings.\n")
    fh.write("\n")

    fh.write("## Per-script semantic summaries\n\n")
    fh.write("This section is source-body interpretation only. It explains what each script appears to implement from reading the script body. It does not mean the script was executed, runtime-validated, or safe to run. Relation candidates are not graph edges.\n\n")
    for row in raw_rows:
        fh.write(f"### {row['path']}\n\n")
        fh.write(f"- Semantic entity type: {row['semantic_entity_type']}\n")
        fh.write(f"- Runtime: {row['semantic_runtime']}\n")
        fh.write(f"- Automation type: {row['semantic_automation_type']}\n")
        fh.write(f"- Confidence: {row['semantic_confidence']}\n")
        fh.write(f"- Runtime validated: {row['runtime_validated']}\n")
        fh.write(f"- Placeholder status: {row['placeholder_status']}\n")
        fh.write(f"- Summary: {row['source_body_summary']}\n")
        fh.write(f"- Implemented contracts: {row['implemented_contracts']}\n")
        fh.write(f"- Reads: {row['reads_paths']}\n")
        fh.write(f"- Writes: {row['writes_paths']}\n")
        fh.write(f"- Evidence outputs: {row['evidence_outputs']}\n")
        fh.write(f"- Uses libraries: {row['uses_libraries']}\n")
        fh.write(f"- Calls Toolbox commands: {row['calls_toolbox_commands']}\n")
        fh.write(f"- Calls external commands: {row['calls_external_commands']}\n")
        fh.write(f"- Relation candidates: {row['relation_candidate_types']}\n")
        fh.write(f"- Relation targets: {row['relation_candidate_targets']}\n")
        fh.write(f"- Relation basis: {row['relation_candidate_basis']}\n")
        fh.write(f"- Warnings: {row['warnings']}\n\n")

    fh.write("## Graph-readiness blockers\n\n")
    fh.write("- Semantic relation candidates require graph promotion rules before graph use.\n")
    fh.write("- Runtime validation requires a separate evidence layer.\n")
    fh.write("- Placeholder rows must not become semantic pipeline graph nodes without implementation evidence.\n")

print(f"Raw semantics TSV: {raw_out_tsv}")
print(f"Normalized semantics inventory: {normalized_out_tsv}")
print(f"Report: {out_report}")
print(f"Total scoped rows: {len(raw_rows)}")
print(f"Placeholder rows: {len(placeholder_rows)}")
print(f"Rows with relation candidates: {len(relation_rows)}")
print(f"Rows with warnings: {len(warning_rows)}")
PY
}

main() {
  require_lib_contract
  parse_args "$@"
  ensure_inputs
  ensure_output_dirs
  run_generation
}

main "$@"
