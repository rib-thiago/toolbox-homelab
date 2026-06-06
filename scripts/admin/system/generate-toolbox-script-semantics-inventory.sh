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

RAW_OUT_TSV="$RAW_DIR/toolbox_script_semantics_inventory_$STAMP.tsv"
NORMALIZED_OUT_TSV="$INVENTORY_DIR/toolbox_script_semantics_inventory_$STAMP.tsv"
OUT_REPORT="$REPORT_DIR/toolbox_script_semantics_inventory_report_$STAMP.txt"

SOURCE_INVENTORY=""
RAW_SCRIPT_INVENTORY=""

# core_high_risk_v0: initial explicit source-body semantics scope.
core_high_risk_v0=(
  "scripts/admin/system/diagnose-toolbox-script-inventory.sh"
  "scripts/admin/system/generate-toolbox-inventory.sh"
  "bin/run-job"
  "scripts/pipelines/pdf-ocr.sh"
  "scripts/pipelines/image-ocr.sh"
  "scripts/pipelines/image-ocr-translate.sh"
  "scripts/pipelines/translate-text.sh"
  "scripts/lib/common.sh"
  "scripts/lib/jobs.sh"
  "scripts/lib/logging.sh"
  "scripts/lib/paths.sh"
  "scripts/lib/reports.sh"
  "scripts/lib/timestamps.sh"
  "scripts/lib/tsv.sh"
  "scripts/helpers/job-inspect.sh"
  "scripts/admin/git/apply-toolbox-git-stage-check-commit.sh"
  "scripts/admin/git/apply-toolbox-git-post-commit.sh"
)

usage() {
  cat <<'EOF'
Usage:
  generate-toolbox-script-semantics-inventory.sh
  generate-toolbox-script-semantics-inventory.sh --source-inventory PATH
  generate-toolbox-script-semantics-inventory.sh --raw-script-inventory PATH
  generate-toolbox-script-semantics-inventory.sh --source-inventory PATH --raw-script-inventory PATH
  generate-toolbox-script-semantics-inventory.sh --help

Generate toolbox_script_semantics_inventory_v0 for the core_high_risk_v0 script scope.

This generator reads source bodies only. It does not execute scoped scripts, pipelines,
run-job, validators, diagnostics, apply workflows, services, media paths, configs,
secrets, credentials, or backup repositories.

Outputs:
  /srv/toolbox/shared/library-db/raw/system/toolbox_script_semantics_inventory_YYYYMMDD-HHMMSS.tsv
  /srv/toolbox/shared/inventory/toolbox/toolbox_script_semantics_inventory_YYYYMMDD-HHMMSS.tsv
  /srv/toolbox/shared/reports/system/toolbox_script_semantics_inventory_report_YYYYMMDD-HHMMSS.txt
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

  source_report="$(infer_report_for_inventory "$SOURCE_INVENTORY")"
  raw_script_report="$(infer_report_for_raw_script_inventory "$RAW_SCRIPT_INVENTORY")"
  git_branch="$(git_branch_value)"
  git_commit="$(git_commit_value)"
  git_status="$(git_status_value)"

  python3 - "$APP_DIR" "$GENERATED_AT" "$RAW_SCRIPT_INVENTORY" "$raw_script_report" "$SOURCE_INVENTORY" "$source_report" "$RAW_OUT_TSV" "$NORMALIZED_OUT_TSV" "$OUT_REPORT" "$GENERATOR_SCRIPT" "$git_branch" "$git_commit" "$git_status" "${core_high_risk_v0[@]}" <<'PY'
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
scope_paths = list(sys.argv[14:])

semantic_schema = "toolbox_script_semantics_inventory_v0"
scope_batch = "core_high_risk_v0"

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
    filtered = [clean(v) for v in values if clean(v) != "unknown"]
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

def sourced_libraries(text: str) -> list[str]:
    libs = set()
    for match in re.findall(r"source\s+[^'\"]*['\"]?([^'\"\n ]*scripts/lib/[A-Za-z0-9._/-]+\.sh)", text):
        libs.add(match.replace(str(app) + "/", ""))
    for match in re.findall(r"source\s+\"\$LIB_DIR/([A-Za-z0-9._-]+\.sh)\"", text):
        libs.add(f"scripts/lib/{match}")
    return sorted(libs)

def external_commands(text: str) -> list[str]:
    candidates = []
    for cmd in ["python3", "git", "find", "sort", "tail", "cut", "cp", "mkdir", "cat", "date", "hostname", "id", "wc", "sed"]:
        if re.search(rf"(^|[^A-Za-z0-9_/-]){re.escape(cmd)}($|[^A-Za-z0-9_-])", text):
            candidates.append(cmd)
    return candidates

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
    toolbox_cmds = command_paths(text)
    externals = external_commands(text)
    calls_git = "yes" if "git " in text or "git\t" in text else "no"

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
